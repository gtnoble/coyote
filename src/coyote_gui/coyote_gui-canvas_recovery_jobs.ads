with Ada.Strings.Unbounded;
with Coyote_Canvas.Revisions;
with Coyote_Canvas.Store.Workspaces;

--  Each Canvas may own one job at a time. Workers never retain GTK objects.
package Coyote_GUI.Canvas_Recovery_Jobs is
   package Disk renames Coyote_Canvas.Store.Workspaces;
   package Store renames Coyote_Canvas.Store;
   package Rev renames Coyote_Canvas.Revisions;

   type Job is limited private;
   type Job_Access is access Job;
   type Operation is (Open_Store, Save_Store);
   procedure Start
     (Item : out Job_Access; Action : Operation; Parent, UUID : String;
      Document : Rev.Workspace; Pixels : Disk.Raster_Set;
      Session_File : String);
   function Ready (Item : Job_Access) return Boolean;
   procedure Finish
     (Item : in out Job_Access; Document : in out Rev.Workspace;
      Pixels : in out Disk.Raster_Set; Lease : in out Store.Writer_Lease;
      Status, Claim_Status : out Store.Result;
      Adopt_Additions : Boolean := False);
   procedure Discard (Item : in out Job_Access);

private
   protected type Completion is
      procedure Signal;
      entry Wait;
      function Ready return Boolean;
   private
      Done : Boolean := False;
   end Completion;

   task type Worker (Item : not null Job_Access);
   type Worker_Access is access Worker;

   type Job is limited record
      Action : Operation;
      Parent, UUID, Session_File : Ada.Strings.Unbounded.Unbounded_String;
      Document : Rev.Workspace;
      Pixels : Disk.Raster_Set;
      Lease : Store.Writer_Lease;
      Status, Claim_Status : Store.Result := Store.IO_Error;
      Completed : Completion;
      Thread : Worker_Access;
   end record;
end Coyote_GUI.Canvas_Recovery_Jobs;
