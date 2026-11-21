with Coyote_Session_Transactions;
with Ada.Strings.Unbounded.Aux;
with Coyote_Canvas.Document;
with Coyote_Canvas.Images;
with Coyote_Canvas.Rasters;
with Coyote_Canvas.Revisions.Recovery;
with GNAT.SHA256;

package body Coyote_Canvas.Store.Workspaces is
   use Ada.Strings.Unbounded;
   package Rev renames Coyote_Canvas.Revisions;
   package Recovery renames Rev.Recovery;
   package Tx renames Coyote_Session_Transactions;

   function Byte_Count (E : Document.Rectangle) return Positive is
   begin
      if E.Left /= 0 or else E.Top /= 0 or else not Document.Is_Nonempty (E)
        or else E.Right > Rasters.MAX_SIDE or else E.Bottom > Rasters.MAX_SIDE
        or else E.Bottom > Rasters.MAX_PIXELS / E.Right
      then
         raise Recovery.Invalid_Snapshot with "Invalid Canvas asset extent";
      end if;
      return Images.Packed_Byte_Count (E.Right, E.Bottom);
   end Byte_Count;

   function Key
     (E : Document.Rectangle; Bytes : String) return Recovery.Asset_Digest
   is
      Ctx : GNAT.SHA256.Context := GNAT.SHA256.Initial_Context;
   begin
      --  Domain-separate the storage encoding and bind the row layout as
      --  well as the bytes. Equal byte counts need not mean equal shapes.
      GNAT.SHA256.Update
        (Ctx, "coyote-rgba8-v1:" & Natural'Image (E.Right) & ":"
         & Natural'Image (E.Bottom) & ASCII.LF);
      GNAT.SHA256.Update (Ctx, Bytes);
      return GNAT.SHA256.Digest (Ctx);
   end Key;

   procedure Save_Internal
     (Parent, UUID : String; W : Rev.Workspace; Assets : Raster_Set;
      Status : out Result; Already_Locked : Boolean)
   is
      Refs : Recovery.Asset_References := (others => Recovery.NO_ASSET);
      Used : Natural := 0;
   begin
      Status := Invalid;
      for Id in Assets'Range loop
         if Id <= Rev.Count (W) and then Rev.Background (W, Id) = Id then
            declare
               E : constant Document.Rectangle := Rev.Extent (W, Id);
               N : constant Positive := Byte_Count (E);
               Bytes : Aux.Big_String_Access;
               Size  : Natural;
            begin
               Aux.Get_String (Assets (Id), Bytes, Size);
               if Size /= N or else N > MAX_RASTER_BYTES - Used then
                  return;
               end if;
               Used := Used + N;
               Refs (Id) := Key (E, Bytes (1 .. Size));
            end;
         elsif Length (Assets (Id)) /= 0 then
            return;
         elsif Id <= Rev.Count (W) and then Rev.Parent (W, Id) = 0 then
            --  A blank Original still has to be within the recoverable grid.
            declare
               N : constant Positive := Byte_Count (Rev.Extent (W, Id));
               pragma Unreferenced (N);
            begin
               null;
            end;
         end if;
      end loop;
      declare
         Manifest : constant String := Recovery.Encode (W, Refs);
         Lock : Tx.Guard;
         Locked : Tx.Result;
      begin
         if Manifest'Length > MAX_MANIFEST_BYTES then
            return;
         end if;
         if not Already_Locked then
            Tx.Try_Lock (Parent, UUID, Lock, Locked);
            case Locked is
               when Tx.Busy =>
                  Status := Busy;
                  return;
               when Tx.Unavailable =>
                  Status := IO_Error;
                  return;
               when Tx.Acquired => null;
            end case;
         end if;
         for Id in 1 .. Rev.Count (W) loop
            if Refs (Id) /= Recovery.NO_ASSET then
               declare
                  Bytes : Aux.Big_String_Access;
                  Size  : Natural;
               begin
                  Aux.Get_String (Assets (Id), Bytes, Size);
                  Write_Asset (Parent, UUID, Refs (Id), Bytes (1 .. Size), Status);
                  if Status /= Ok then
                     if Status = Uncertain then
                        Status := IO_Error;
                     end if;
                     return;
                  end if;
               end;
            end if;
         end loop;
         Write (Parent, UUID, Manifest, Status);
      end;
   exception
      when Recovery.Invalid_Snapshot =>
         Status := Invalid;
   end Save_Internal;

   procedure Save
     (Parent, UUID : String; W : Rev.Workspace; Assets : Raster_Set;
      Status : out Result)
   is
   begin
      Save_Internal (Parent, UUID, W, Assets, Status, Already_Locked => False);
   end Save;

   procedure Save_Locked
     (Parent, UUID : String; W : Rev.Workspace; Assets : Raster_Set;
      Status : out Result)
   is
   begin
      Save_Internal (Parent, UUID, W, Assets, Status, Already_Locked => True);
   end Save_Locked;

   procedure Load_Internal
     (Parent, UUID : String; W : in out Rev.Workspace;
      Assets : in out Raster_Set; Status : out Result;
      Requested : Recovery.References; Select_Only : Boolean)
   is
      Manifest  : Unbounded_String;
      Candidate : Rev.Workspace;
      Pixels    : Raster_Set;
      Refs      : Recovery.Asset_References;
      Source_Ids : Recovery.Revision_Mapping;
      Used      : Natural := 0;
   begin
      Read (Parent, UUID, Manifest, Status);
      if Status /= Ok then
         return;
      end if;
      Recovery.Decode (To_String (Manifest), Candidate, Refs);
      if Select_Only then
         declare
            Subset : Rev.Workspace;
         begin
            Recovery.Select_Revisions
              (Candidate, Requested, Subset, Source_Ids);
            Recovery.Move (Candidate, Subset);
         end;
      else
         for Id in Source_Ids'Range loop
            Source_Ids (Id) := Id;
         end loop;
      end if;
      for Id in 1 .. Rev.Count (Candidate) loop
         if Refs (Source_Ids (Id)) /= Recovery.NO_ASSET then
            declare
               Digest : constant Recovery.Asset_Digest :=
                 Refs (Source_Ids (Id));
               E : constant Document.Rectangle := Rev.Extent (Candidate, Id);
               N : constant Positive := Byte_Count (E);
               Bytes : Aux.Big_String_Access;
               Size  : Natural;
            begin
               if N > MAX_RASTER_BYTES - Used then
                  Status := Invalid;
                  return;
               end if;
               Used := Used + N;
               Read_Asset (Parent, UUID, Digest, N, Pixels (Id), Status);
               if Status /= Ok then
                  if Status = Missing then
                     Status := Invalid;
                  end if;
                  return;
               end if;
               Aux.Get_String (Pixels (Id), Bytes, Size);
               if Key (E, Bytes (1 .. Size)) /= Digest then
                  Status := Invalid;
                  return;
               end if;
            end;
         end if;
      end loop;
      Assets := Pixels;
      Recovery.Move (W, Candidate);
   exception
      when Recovery.Invalid_Snapshot =>
         Status := Invalid;
   end Load_Internal;

   procedure Load
     (Parent, UUID : String; W : in out Rev.Workspace;
      Assets : in out Raster_Set; Status : out Result)
   is
   begin
      Load_Internal (Parent, UUID, W, Assets, Status,
                     (1 .. 0 => <>), Select_Only => False);
   end Load;

   procedure Load_Selection
     (Parent, UUID : String; Requested : Recovery.References;
      W : in out Rev.Workspace; Assets : in out Raster_Set;
      Status : out Result)
   is
   begin
      Load_Internal (Parent, UUID, W, Assets, Status,
                     Requested, Select_Only => True);
   end Load_Selection;
end Coyote_Canvas.Store.Workspaces;
