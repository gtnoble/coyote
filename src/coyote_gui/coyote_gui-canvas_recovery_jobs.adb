with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Unchecked_Deallocation;
with Ada.Directories;
with Coyote_Session_Transactions;
with Coyote_Canvas.Revisions.Recovery;
with Coyote_Process_Control;
with Interfaces.C;

package body Coyote_GUI.Canvas_Recovery_Jobs is
   use type Store.Result;
   use type Interfaces.C.int;
   package Recovery renames Rev.Recovery;
   package Tx renames Coyote_Session_Transactions;
   use type Tx.Result;
   procedure Free is new Ada.Unchecked_Deallocation (Job, Job_Access);
   procedure Free is new Ada.Unchecked_Deallocation (Worker, Worker_Access);

   F_DUPFD_CLOEXEC : constant Interfaces.C.int := 1_030;

   function C_Fcntl
     (FD, Command, Argument : Interfaces.C.int)
      return Interfaces.C.int
     with Import, Convention => C, External_Name => "fcntl";

   function C_Close (FD : Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C, External_Name => "close";

   protected body Completion is
      procedure Signal is
      begin
         Done := True;
      end Signal;

      entry Wait when Done is
      begin
         null;
      end Wait;

      function Ready return Boolean is (Done);
   end Completion;

   procedure Close_Stages (Stages : in out Tile_Stages) is
   begin
      for Id in Stages'Range loop
         if Stages (Id) >= 0 then
            declare
               Ignored : constant Interfaces.C.int := C_Close (Stages (Id));
               pragma Unreferenced (Ignored);
            begin
               Stages (Id) := -1;
            end;
         end if;
      end loop;
   end Close_Stages;

   function Has_Stages (Stages : Tile_Stages) return Boolean is
   begin
      for FD of Stages loop
         if FD >= 0 then
            return True;
         end if;
      end loop;
      return False;
   end Has_Stages;

   task body Worker is
      Accepted : Boolean := False;
   begin
      if Item.Action = Open_Store then
         declare
            Lock : Tx.Guard;
            Status : Tx.Result;
            Path : constant String := To_String (Item.Session_File);
         begin
            if Path'Length > 0 then
               Tx.Wait_For_Lock (Path, Lock, Status);
            else
               Tx.Try_Lock (To_String (Item.Parent), To_String (Item.UUID),
                            Lock, Status);
            end if;
            if Status = Tx.Acquired and then
              (Path'Length = 0 or else Ada.Directories.Exists (Path))
            then
               Coyote_Process_Control.Begin_Persistence_Write (Accepted);
               if Accepted then
                  Store.Claim (To_String (Item.Parent), To_String (Item.UUID),
                               Item.Lease, Item.Claim_Status);
                  Coyote_Process_Control.End_Persistence_Write;
                  Accepted := False;
               end if;
            end if;
            if Item.Claim_Status in Store.Ok | Store.Busy then
               Disk.Load_Locked
                 (To_String (Item.Parent), To_String (Item.UUID),
                  Item.Document, Item.Pixels, Item.Tiles, Item.Status);
            end if;
         end;
      elsif Has_Stages (Item.Stages) then
         declare
            Lock : Tx.Guard;
            Lock_Status : Tx.Result;
            Write_Status : Store.Result;
            Digest : Store.Tile_Digest;
         begin
            Tx.Try_Lock (To_String (Item.Parent), To_String (Item.UUID),
                         Lock, Lock_Status);
            if Lock_Status /= Tx.Acquired then
               Item.Status := (if Lock_Status = Tx.Busy then Store.Busy
                               else Store.IO_Error);
            else
               Coyote_Process_Control.Begin_Persistence_Write (Accepted);
               if Accepted then
                  Item.Status := Store.Ok;
                  Item.Tiles.Parent := Item.Parent;
                  Item.Tiles.UUID := Item.UUID;
                  for Id in Item.Stages'Range loop
                     if Item.Stages (Id) >= 0 then
                        Store.Write_Tile
                          (To_String (Item.Parent), To_String (Item.UUID),
                           Item.Stages (Id), Digest, Write_Status);
                        if Write_Status /= Store.Ok then
                           Item.Status :=
                             (if Write_Status = Store.Uncertain then
                                Store.IO_Error else Write_Status);
                           exit;
                        end if;
                        Item.Tiles.References (Id) :=
                          Recovery.Asset_Digest (Digest);
                     end if;
                  end loop;
                  if Item.Status = Store.Ok then
                     Disk.Save_Locked
                       (To_String (Item.Parent), To_String (Item.UUID),
                        Item.Document, Item.Pixels, Item.Tiles, Item.Status);
                  end if;
                  Coyote_Process_Control.End_Persistence_Write;
                  Accepted := False;
               else
                  Item.Status := Store.IO_Error;
               end if;
            end if;
         end;
      else
         Coyote_Process_Control.Begin_Persistence_Write (Accepted);
         if Accepted then
            Disk.Save (To_String (Item.Parent), To_String (Item.UUID),
                       Item.Document, Item.Pixels, Item.Tiles, Item.Status);
            Coyote_Process_Control.End_Persistence_Write;
            Accepted := False;
         end if;
      end if;
      Close_Stages (Item.Stages);
      Item.Completed.Signal;
   exception
      when others =>
         if Accepted then
            Coyote_Process_Control.End_Persistence_Write;
         end if;
         Close_Stages (Item.Stages);
         Item.Status := Store.IO_Error;
         Item.Completed.Signal;
   end Worker;

   procedure Start
     (Item : out Job_Access; Action : Operation; Parent, UUID : String;
      Document : Rev.Workspace; Pixels : Disk.Raster_Set;
      Tiles : Disk.Tile_Set; Session_File : String;
      Stages : Tile_Stages := NO_STAGES)
   is
   begin
      Item := null;
      Item := new Job;
      Item.Action := Action;
      Item.Parent := To_Unbounded_String (Parent);
      Item.UUID := To_Unbounded_String (UUID);
      Item.Session_File := To_Unbounded_String (Session_File);
      if Action = Save_Store then
         Recovery.Copy (Item.Document, Document);
         Item.Pixels := Pixels;
         Item.Tiles := Tiles;
      end if;
      for Id in Stages'Range loop
         if Stages (Id) >= 0 then
            Item.Stages (Id) :=
              C_Fcntl (Stages (Id), F_DUPFD_CLOEXEC, 0);
            if Item.Stages (Id) < 0 then
               raise Program_Error with "cannot duplicate staged tile";
            end if;
         end if;
      end loop;
      Item.Thread := new Worker (Item);
   exception
      when others =>
         if Item /= null then
            Close_Stages (Item.Stages);
            Free (Item);
         end if;
         raise;
   end Start;

   function Ready (Item : Job_Access) return Boolean is
     (Item /= null and then Item.Completed.Ready);

   procedure Discard (Item : in out Job_Access) is
   begin
      if Item /= null then
         Item.Completed.Wait;
         while not Item.Thread'Terminated loop
            delay 0.001;
         end loop;
         Free (Item.Thread);
         Close_Stages (Item.Stages);
         Free (Item);
      end if;
   end Discard;

   procedure Finish
     (Item : in out Job_Access; Document : in out Rev.Workspace;
      Pixels : in out Disk.Raster_Set; Tiles : in out Disk.Tile_Set;
      Lease : in out Store.Writer_Lease;
      Status, Claim_Status : out Store.Result;
      Adopt_Additions : Boolean := False)
   is
   begin
      Item.Completed.Wait;
      Status := Item.Status;
      Claim_Status := Item.Claim_Status;
      if Item.Action = Open_Store and then Status in Store.Ok | Store.Missing
      then
         if Status = Store.Ok then
            Pixels := Item.Pixels;
            Tiles := Item.Tiles;
            Recovery.Move (Document, Item.Document);
         end if;
         Store.Move (Lease, Item.Lease);
      end if;
      if Adopt_Additions and then Status in Store.Ok | Store.Uncertain then
         Pixels := Item.Pixels;
         Tiles := Item.Tiles;
         Recovery.Adopt_Added_Originals (Document, Item.Document);
      end if;
      Discard (Item);
   end Finish;
end Coyote_GUI.Canvas_Recovery_Jobs;
