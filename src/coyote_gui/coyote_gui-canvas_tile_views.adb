with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Unchecked_Deallocation;
with Coyote_Canvas.Composite;
with Coyote_Canvas.Revisions.Recovery;
with Coyote_Canvas.Store;
with Coyote_Canvas.Tile_Render;
with Coyote_Canvas.Tiles;
with System.Address_To_Access_Conversions;

package body Coyote_GUI.Canvas_Tile_Views is
   use type Cairo.Cairo_Surface;
   use type Interfaces.C.int;
   package Comp renames Coyote_Canvas.Composite;
   package Recovery renames Rev.Recovery;
   package Store renames Coyote_Canvas.Store;
   package Tile renames Coyote_Canvas.Tile_Render;
   package Tiles renames Coyote_Canvas.Tiles;
   use type Store.Result;
   use type Tiles.Result;
   use type Doc.Rectangle;

   procedure Free is new Ada.Unchecked_Deallocation (Job, Job_Access);
   procedure Free is new Ada.Unchecked_Deallocation (Worker, Worker_Access);

   procedure Clear (Cache : in out Level_Cache) is
   begin
      for FD of Cache.FDs loop
         Store.Close_Tile (FD);
      end loop;
   end Clear;

   procedure Move (From, Into : in out Level_Cache) is
   begin
      Clear (Into);
      Into.FDs := From.FDs;
      From.FDs := (others => -1);
   end Move;

   protected body Completion is
      procedure Signal is
      begin
         Done := True;
      end Signal;

      procedure Cancel (Keep_Levels : Boolean) is
      begin
         Cancelled := True;
         Stop_Build := Stop_Build or else not Keep_Levels;
      end Cancel;

      entry Wait when Done is
      begin
         null;
      end Wait;

      function Is_Ready return Boolean is (Done);
      function Is_Cancelled return Boolean is (Cancelled);
      function Stop_Levels return Boolean is (Stop_Build);
   end Completion;

   package Completion_Pointers is new System.Address_To_Access_Conversions
     (Completion);

   function Stop (User : System.Address) return Interfaces.C.int
     with Convention => C;
   function Stop (User : System.Address) return Interfaces.C.int is
     (if Completion_Pointers.To_Pointer (User).Stop_Levels then 1 else 0);

   task body Worker is
      FD, Stage, Input : Interfaces.C.int := -1;
      Status : Store.Result;
      Reduced : Tiles.Result;
   begin
      if Item.Resolution = 0 or else Item.Cache.FDs (1) < 0 or else
        Rev.Extent (Item.Workspace, Item.Revision) /=
          Rev.Extent (Item.Workspace,
                      Rev.Background (Item.Workspace, Item.Revision))
      then
         Store.Open_Validated_Tile
           (To_String (Item.Parent), To_String (Item.UUID),
            To_String (Item.Digest), FD, Status);
         if Status /= Store.Ok then
            raise Comp.Render_Error with "Cannot open Canvas Original";
         end if;
      end if;
      Input := FD;
      Build_Levels : for L in 1 .. Item.Resolution loop
         exit Build_Levels when Item.Completed.Stop_Levels;
         if Item.Cache.FDs (L) < 0 then
            Stage := Tiles.Stage;
            if Stage < 0 then
               raise Comp.Render_Error with "Cannot stage Canvas level";
            end if;
            Tiles.Reduce (Input, Stage, Reduced, Stop'Access,
                          Item.Completed'Address);
            exit Build_Levels when Reduced = Tiles.Cancelled;
            if Reduced /= Tiles.Success then
               raise Comp.Render_Error with "Cannot reduce Canvas level";
            end if;
            Item.Cache.FDs (L) := Stage;
            Stage := -1;
         end if;
         Input := Item.Cache.FDs (L);
      end loop Build_Levels;
      if not Item.Completed.Is_Cancelled then
         if Item.Resolution = 0 then
            declare
               Image : Comp.Image;
            begin
               Tile.Render
                 (Input, Item.Workspace, Item.Revision, Item.Region,
                  Image, Item.Include_Ink);
               if not Item.Completed.Is_Cancelled then
                  Item.Result := Comp.Display_Surface (Image);
               end if;
            end;
         else
            Item.Result := Tile.Display_Level
              (Input, FD, Item.Workspace, Item.Revision, Item.Region,
               2 ** Item.Resolution, Item.Include_Ink);
         end if;
      end if;
      Store.Close_Tile (Stage);
      Store.Close_Tile (FD);
      Item.Completed.Signal;
   exception
      when others =>
         Store.Close_Tile (Stage);
         Store.Close_Tile (FD);
         Item.Completed.Signal;
   end Worker;

   procedure Start
     (Item : out Job_Access;
      Parent, UUID, Digest : String;
      W : Rev.Workspace;
      Id : Rev.Revision_Id;
      Region : Doc.Rectangle;
      Include_Ink : Boolean; Resolution : Level;
      Cache : in out Level_Cache)
   is
   begin
      Item := new Job;
      Item.Parent := To_Unbounded_String (Parent);
      Item.UUID := To_Unbounded_String (UUID);
      Item.Digest := To_Unbounded_String (Digest);
      Recovery.Copy (Item.Workspace, W);
      Item.Revision := Id;
      Item.Region := Region;
      Item.Include_Ink := Include_Ink;
      Item.Resolution := Resolution;
      Move (Cache, Item.Cache);
      Item.Thread := new Worker (Item);
   exception
      when others =>
         if Item /= null then
            Clear (Item.Cache);
            Free (Item);
         end if;
         raise;
   end Start;

   function Ready (Item : Job_Access) return Boolean is
     (Item /= null and then Item.Completed.Is_Ready);

   procedure Cancel (Item : Job_Access; Keep_Levels : Boolean := False) is
   begin
      if Item /= null then
         Item.Completed.Cancel (Keep_Levels);
      end if;
   end Cancel;

   procedure Discard (Item : in out Job_Access) is
   begin
      if Item /= null then
         Item.Completed.Cancel (Keep_Levels => False);
         Item.Completed.Wait;
         while not Item.Thread'Terminated loop
            delay 0.001;
         end loop;
         if Item.Result /= Cairo.Null_Surface then
            Cairo.Surface_Destroy (Item.Result);
            Item.Result := Cairo.Null_Surface;
         end if;
         Clear (Item.Cache);
         Free (Item.Thread);
         Free (Item);
      end if;
   end Discard;

   procedure Finish
     (Item : in out Job_Access;
      Cache : in out Level_Cache; Surface : out Cairo.Cairo_Surface)
   is
   begin
      Surface := Cairo.Null_Surface;
      if Item /= null then
         Item.Completed.Wait;
         Move (Item.Cache, Cache);
         if not Item.Completed.Is_Cancelled then
            Surface := Item.Result;
            Item.Result := Cairo.Null_Surface;
         end if;
         Discard (Item);
      end if;
   end Finish;
end Coyote_GUI.Canvas_Tile_Views;
