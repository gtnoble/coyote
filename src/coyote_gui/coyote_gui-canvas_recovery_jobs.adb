with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Unchecked_Deallocation;
with Ada.Directories;
with Coyote_Session_Transactions;
with Coyote_Canvas.Revisions.Recovery;
with Coyote_Process_Control;

package body Coyote_GUI.Canvas_Recovery_Jobs is
   use type Store.Result;
   package Recovery renames Rev.Recovery;
   package Tx renames Coyote_Session_Transactions;
   use type Tx.Result;
   procedure Free is new Ada.Unchecked_Deallocation (Job, Job_Access);
   procedure Free is new Ada.Unchecked_Deallocation (Worker, Worker_Access);

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
         end;
         if Item.Claim_Status in Store.Ok | Store.Busy then
            Disk.Load (To_String (Item.Parent), To_String (Item.UUID),
                       Item.Document, Item.Pixels, Item.Status);
         end if;
      else
         Coyote_Process_Control.Begin_Persistence_Write (Accepted);
         if Accepted then
            Disk.Save (To_String (Item.Parent), To_String (Item.UUID),
                       Item.Document, Item.Pixels, Item.Status);
            Coyote_Process_Control.End_Persistence_Write;
            Accepted := False;
         end if;
      end if;
      Item.Completed.Signal;
   exception
      when others =>
         if Accepted then
            Coyote_Process_Control.End_Persistence_Write;
         end if;
         Item.Status := Store.IO_Error;
         Item.Completed.Signal;
   end Worker;

   procedure Start
     (Item : out Job_Access; Action : Operation; Parent, UUID : String;
      Document : Rev.Workspace; Pixels : Disk.Raster_Set;
      Session_File : String)
   is
   begin
      Item := new Job;
      Item.Action := Action;
      Item.Parent := To_Unbounded_String (Parent);
      Item.UUID := To_Unbounded_String (UUID);
      Item.Session_File := To_Unbounded_String (Session_File);
      if Action = Save_Store then
         Recovery.Copy (Item.Document, Document);
         Item.Pixels := Pixels;
      end if;
      Item.Thread := new Worker (Item);
   exception
      when others =>
         Free (Item);
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
         Free (Item);
      end if;
   end Discard;

   procedure Finish
     (Item : in out Job_Access; Document : in out Rev.Workspace;
      Pixels : in out Disk.Raster_Set; Lease : in out Store.Writer_Lease;
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
            Recovery.Move (Document, Item.Document);
         end if;
         Store.Move (Lease, Item.Lease);
      end if;
      if Adopt_Additions and then Status in Store.Ok | Store.Uncertain then
         Pixels := Item.Pixels;
         Recovery.Adopt_Added_Originals (Document, Item.Document);
      end if;
      Discard (Item);
   end Finish;
end Coyote_GUI.Canvas_Recovery_Jobs;
