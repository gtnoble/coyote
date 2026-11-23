with Coyote_Session_Transactions;
with Ada.Strings.Unbounded.Aux;
with Coyote_Canvas.Document;
with Coyote_Canvas.Images;
with Coyote_Canvas.Rasters;
with Coyote_Canvas.Revisions.Recovery;
with GNAT.SHA256;
with GNATCOLL.JSON;
with Coyote_Process_Control;
with Coyote_Canvas.Tiles;
with Interfaces.C;

package body Coyote_Canvas.Store.Workspaces is
   use Ada.Strings.Unbounded;
   use type Interfaces.C.int;
   package Rev renames Coyote_Canvas.Revisions;
   package Recovery renames Rev.Recovery;
   package Tx renames Coyote_Session_Transactions;

   procedure Try_Guard
     (Parent, UUID : String; Lock : in out Tx.Guard; Status : out Result)
   is
      Locked : Tx.Result;
   begin
      if not Tx.Canonical_UUID (UUID) then
         Status := Invalid;
         return;
      end if;
      Tx.Try_Lock (Parent, UUID, Lock, Locked);
      Status := (case Locked is when Tx.Acquired => Ok,
                 when Tx.Busy => Busy, when Tx.Unavailable => IO_Error);
   end Try_Guard;

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

   procedure Open_Original_Tile
     (Assets : Tile_Set; Digest : Recovery.Asset_Digest;
      E : Document.Rectangle; FD : out Interfaces.C.int; Status : out Result)
   is
      use type Interfaces.Unsigned_32;
      use type Coyote_Canvas.Tiles.Result;
      Info : Coyote_Canvas.Tiles.Dimensions;
      Checked : Coyote_Canvas.Tiles.Result;
   begin
      Open_Tile (To_String (Assets.Parent), To_String (Assets.UUID),
                 Digest, FD, Status);
      if Status = Missing then
         Status := Invalid;
      elsif Status = Ok then
         Coyote_Canvas.Tiles.Inspect (FD, Checked, Info);
         if Checked /= Coyote_Canvas.Tiles.Success
           or else E.Left /= 0 or else E.Top /= 0
           or else Info.Width /= Interfaces.Unsigned_32 (E.Right)
           or else Info.Height /= Interfaces.Unsigned_32 (E.Bottom)
         then
            Close_Tile (FD);
            Status := Invalid;
         end if;
      end if;
   end Open_Original_Tile;

   procedure Save_Internal
     (Parent, UUID : String; W : Rev.Workspace; Assets : Raster_Set;
      Tiles : Tile_Set; Status : out Result; Already_Locked : Boolean)
   is
      Refs : Recovery.Asset_References := (others => Recovery.NO_ASSET);
      Used : Natural := 0;
   begin
      Status := Invalid;
      for Id in Assets'Range loop
         if Tiles.References (Id) /= Recovery.NO_ASSET then
            if Id > Rev.Count (W) or else Rev.Background (W, Id) /= Id
              or else Length (Assets (Id)) /= 0
            then
               return;
            end if;
         elsif Id <= Rev.Count (W) and then Rev.Background (W, Id) = Id then
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
         Manifest : constant String := Recovery.Encode (W, Refs, Tiles.References);
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
            if Tiles.References (Id) /= Recovery.NO_ASSET then
               declare
                  Digest : constant Recovery.Asset_Digest :=
                    Tiles.References (Id);
                  FD : Interfaces.C.int := -1;
                  Copied : Tile_Digest;
               begin
                  Open_Original_Tile (Tiles, Digest, Rev.Extent (W, Id),
                                      FD, Status);
                  if Status = Ok and then
                    (Tiles.Parent /= Parent or else Tiles.UUID /= UUID)
                  then
                     Write_Tile (Parent, UUID, FD, Copied, Status);
                     if Status = Ok and then Copied /= Digest then
                        Status := Invalid;
                     end if;
                  end if;
                  Close_Tile (FD);
                  if Status /= Ok then
                     if Status = Uncertain then
                        Status := IO_Error;
                     end if;
                     return;
                  end if;
               exception
                  when others =>
                     Close_Tile (FD);
                     raise;
               end;
            elsif Refs (Id) /= Recovery.NO_ASSET then
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
      Save (Parent, UUID, W, Assets, (others => <>), Status);
   end Save;

   procedure Save
     (Parent, UUID : String; W : Rev.Workspace; Assets : Raster_Set;
      Tiles : Tile_Set; Status : out Result)
   is
   begin
      Save_Internal (Parent, UUID, W, Assets, Tiles, Status,
                     Already_Locked => False);
   end Save;

   procedure Save_Locked
     (Parent, UUID : String; W : Rev.Workspace; Assets : Raster_Set;
      Status : out Result)
   is
   begin
      Save_Locked (Parent, UUID, W, Assets, (others => <>), Status);
   end Save_Locked;

   procedure Save_Locked
     (Parent, UUID : String; W : Rev.Workspace; Assets : Raster_Set;
      Tiles : Tile_Set; Status : out Result)
   is
   begin
      Save_Internal (Parent, UUID, W, Assets, Tiles, Status,
                     Already_Locked => True);
   end Save_Locked;

   procedure Load_Internal
     (Parent, UUID : String; W : in out Rev.Workspace;
      Assets : in out Raster_Set; Tiles : in out Tile_Set;
      Status : out Result; Requested : Recovery.References;
      Select_Only, With_Tiles : Boolean;
      Manifest : out Unbounded_String; Refs : out Recovery.Asset_References)
   is
      Candidate : Rev.Workspace;
      Pixels    : Raster_Set;
      Tile_Refs : Recovery.Tile_References := (others => Recovery.NO_ASSET);
      Restored  : Tile_Set;
      Source_Ids : Recovery.Revision_Mapping;
      Used      : Natural := 0;
   begin
      Read (Parent, UUID, Manifest, Status);
      if Status /= Ok then
         return;
      end if;
      if With_Tiles then
         Recovery.Decode (To_String (Manifest), Candidate, Refs, Tile_Refs);
         Restored.Parent := To_Unbounded_String (Parent);
         Restored.UUID := To_Unbounded_String (UUID);
      else
         Recovery.Decode (To_String (Manifest), Candidate, Refs);
      end if;
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
         if Tile_Refs (Source_Ids (Id)) /= Recovery.NO_ASSET then
            declare
               Digest : constant Recovery.Asset_Digest :=
                 Tile_Refs (Source_Ids (Id));
               FD : Interfaces.C.int;
            begin
               Open_Original_Tile (Restored, Digest,
                                   Rev.Extent (Candidate, Id), FD, Status);
               Close_Tile (FD);
               if Status /= Ok then
                  return;
               end if;
               Restored.References (Id) := Digest;
            end;
         elsif Refs (Source_Ids (Id)) /= Recovery.NO_ASSET then
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
      Tiles := Restored;
      Recovery.Move (W, Candidate);
   exception
      when Recovery.Invalid_Snapshot =>
         Status := Invalid;
   end Load_Internal;

   procedure Load
     (Parent, UUID : String; W : in out Rev.Workspace;
      Assets : in out Raster_Set; Status : out Result)
   is
      Lock : Tx.Guard;
   begin
      Try_Guard (Parent, UUID, Lock, Status);
      if Status = Ok then
         Load_Locked (Parent, UUID, W, Assets, Status);
      end if;
   end Load;

   procedure Load
     (Parent, UUID : String; W : in out Rev.Workspace;
      Assets : in out Raster_Set; Tiles : in out Tile_Set; Status : out Result)
   is
      Lock : Tx.Guard;
   begin
      Try_Guard (Parent, UUID, Lock, Status);
      if Status = Ok then
         Load_Locked (Parent, UUID, W, Assets, Tiles, Status);
      end if;
   end Load;

   procedure Load_Locked
     (Parent, UUID : String; W : in out Rev.Workspace;
      Assets : in out Raster_Set; Status : out Result)
   is
      Manifest : Unbounded_String;
      Refs : Recovery.Asset_References;
      Ignored : Tile_Set;
   begin
      Load_Internal (Parent, UUID, W, Assets, Ignored, Status, (1 .. 0 => <>),
                     Select_Only => False, With_Tiles => False,
                     Manifest => Manifest, Refs => Refs);
   end Load_Locked;

   procedure Load_Locked
     (Parent, UUID : String; W : in out Rev.Workspace;
      Assets : in out Raster_Set; Tiles : in out Tile_Set; Status : out Result)
   is
      Manifest : Unbounded_String;
      Refs : Recovery.Asset_References;
   begin
      Load_Internal (Parent, UUID, W, Assets, Tiles, Status, (1 .. 0 => <>),
                     Select_Only => False, With_Tiles => True,
                     Manifest => Manifest, Refs => Refs);
   end Load_Locked;

   procedure Load_Selection
     (Parent, UUID : String; Requested : Recovery.References;
      W : in out Rev.Workspace; Assets : in out Raster_Set;
      Status : out Result)
   is
      Manifest : Unbounded_String;
      Refs : Recovery.Asset_References;
      Ignored : Tile_Set;
   begin
      Load_Internal (Parent, UUID, W, Assets, Ignored, Status, Requested,
                     Select_Only => True, With_Tiles => False,
                     Manifest => Manifest, Refs => Refs);
   end Load_Selection;

   procedure Load_Selection
     (Parent, UUID : String; Requested : Recovery.References;
      W : in out Rev.Workspace; Assets : in out Raster_Set;
      Tiles : in out Tile_Set; Status : out Result)
   is
      Manifest : Unbounded_String;
      Refs : Recovery.Asset_References;
   begin
      Load_Internal (Parent, UUID, W, Assets, Tiles, Status, Requested,
                     Select_Only => True, With_Tiles => True,
                     Manifest => Manifest, Refs => Refs);
   end Load_Selection;

   function Matching_Header (Header, UUID : String) return Boolean is
      use GNATCOLL.JSON;
      --  Headers have no deep structure. Avoid passing unbounded nesting
      --  from an invalid file to the general JSON parser.
      Depth : Natural := 0;
      Quoted, Escaped : Boolean := False;
   begin
      for Ch of Header loop
         if Escaped then
            Escaped := False;
         elsif Quoted then
            case Ch is
               when '\' => Escaped := True;
               when '"' => Quoted := False;
               when others => null;
            end case;
         else
            case Ch is
               when '"' => Quoted := True;
               when '{' | '[' =>
                  Depth := Depth + 1;
                  if Depth > 16 then
                     return False;
                  end if;
               when '}' | ']' =>
                  if Depth = 0 then
                     return False;
                  end if;
                  Depth := Depth - 1;
               when others => null;
            end case;
         end if;
      end loop;
      declare
         Parsed : constant Read_Result := Read (Header);
      begin
         if not Parsed.Success or else Parsed.Value.Kind /= JSON_Object_Type
           or else Parsed.Value.Get ("id").Kind /= JSON_String_Type
           or else Parsed.Value.Get ("version").Kind /= JSON_Int_Type
         then
            return False;
         end if;
         declare
            Id : constant String := Parsed.Value.Get ("id").Get;
            Version : constant Long_Long_Integer :=
              Parsed.Value.Get ("version").Get;
         begin
            return Id = UUID and then Version in 1 | 3;
         end;
      end;
   end Matching_Header;

   procedure Reclaim
     (Parent, UUID : String; Orphan, Apply : Boolean;
      Report : out Reclaim_Report; Status : out Result)
   is
      use Coyote_Process_Control;
      Lock : Tx.Guard;
      Header, Manifest, Keep : Unbounded_String;
      Accepted : Boolean := False;
   begin
      Report := (Files => 0, Bytes => 0);
      Try_Guard (Parent, UUID, Lock, Status);
      if Status /= Ok then
         return;
      end if;
      Reclaim_Header (Parent, UUID, Orphan, Header, Status);
      if Status /= Ok then
         return;
      end if;
      if not Orphan then
         if not Matching_Header (To_String (Header), UUID) then
            Status := Invalid;
            return;
         end if;
         declare
            W : Rev.Workspace;
            Assets : Raster_Set;
            Tiles : Tile_Set;
            Refs : Recovery.Asset_References;
         begin
            Load_Internal (Parent, UUID, W, Assets, Tiles, Status,
                           (1 .. 0 => <>), Select_Only => False,
                           With_Tiles => True, Manifest => Manifest,
                           Refs => Refs);
            if Status /= Ok then
               return;
            end if;
            for Digest of Refs loop
               if Digest /= Recovery.NO_ASSET then
                  Append (Keep, Digest & ".rgba");
               end if;
            end loop;
            for Digest of Tiles.References loop
               if Digest /= Recovery.NO_ASSET then
                  Append (Keep, Digest & ".tile");
               end if;
            end loop;
         end;
      end if;
      if Apply then
         Begin_Persistence_Write (Accepted);
         if not Accepted then
            Status := Busy;
            return;
         end if;
      end if;
      Reclaim_Checked (Parent, UUID, To_String (Manifest), To_String (Keep),
                       Orphan, Apply, Report, Status);
      if Accepted then
         End_Persistence_Write;
      end if;
   exception
      when others =>
         if Accepted then
            End_Persistence_Write;
         end if;
         raise;
   end Reclaim;
end Coyote_Canvas.Store.Workspaces;
