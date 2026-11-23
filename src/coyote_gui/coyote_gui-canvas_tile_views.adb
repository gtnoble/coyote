with Ada.Streams;
with Ada.Unchecked_Conversion;
with Ada.Unchecked_Deallocation;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Cairo.Image_Surface;
with Cairo.Surface;
with Coyote_Canvas.Composite;
with Coyote_Canvas.Rasters;
with Coyote_Canvas.Revisions.Recovery;
with Coyote_Canvas.Store;
with Coyote_Canvas.Tile_Render;
with Coyote_Canvas.Tiles;
with Interfaces.C;
with Glib;
with System;
with System.Storage_Elements;

package body Coyote_GUI.Canvas_Tile_Views is
   use type Cairo.Cairo_Surface;
   use type Cairo.Cairo_Status;
   use type Coyote_Canvas.Store.Result;
   use type Ada.Streams.Stream_Element_Offset;
   use type Interfaces.C.int;
   use type System.Address;
   use type System.Storage_Elements.Integer_Address;
   package Comp renames Coyote_Canvas.Composite;
   package Recovery renames Coyote_Canvas.Revisions.Recovery;
   package Store renames Coyote_Canvas.Store;
   package Tile renames Coyote_Canvas.Tile_Render;

   MAX_PREVIEW_SIDE : constant Positive := 512;
   type Pixel_Access is access all Cairo.Image_Surface.ARGB32_Data;
   function To_Pixel_Access is new Ada.Unchecked_Conversion
     (System.Address, Pixel_Access);
   procedure Free is new Ada.Unchecked_Deallocation (Job, Job_Access);
   procedure Free is new Ada.Unchecked_Deallocation (Worker, Worker_Access);

   protected body Completion is
      procedure Signal is
      begin
         Done := True;
      end Signal;

      procedure Cancel is
      begin
         Cancelled := True;
      end Cancel;

      entry Wait when Done is
      begin
         null;
      end Wait;

      function Is_Ready return Boolean is (Done);
      function Is_Cancelled return Boolean is (Cancelled);
   end Completion;

   procedure Render_Preview
     (Item : not null Job_Access; FD : Interfaces.C.int)
   is
      Extent : constant Doc.Rectangle := Rev.Extent
        (Item.Workspace, Item.Revision);
      Left : constant Natural := Natural'Max
        (Extent.Left, Item.Region.Left);
      Top : constant Natural := Natural'Max
        (Extent.Top, Item.Region.Top);
      Right : constant Natural := Natural'Min
        (Extent.Right, Item.Region.Right);
      Bottom : constant Natural := Natural'Min
        (Extent.Bottom, Item.Region.Bottom);
      Source_Width : constant Positive := Positive (Right - Left);
      Source_Height : constant Positive := Positive (Bottom - Top);
      Scale : constant Long_Float := Long_Float'Min
        (1.0, Long_Float'Min
           (Long_Float (MAX_PREVIEW_SIDE) / Long_Float (Source_Width),
            Long_Float (MAX_PREVIEW_SIDE) / Long_Float (Source_Height)));
      Out_Width : constant Positive := Positive'Max
        (1, Natural (Long_Float (Source_Width) * Scale));
      Out_Height : constant Positive := Positive'Max
        (1, Natural (Long_Float (Source_Height) * Scale));
      Surface : Cairo.Cairo_Surface := Cairo.Null_Surface;
      Data : System.Address;
      Stride : Natural;
      Tile_Side : constant Natural := Coyote_Canvas.Tiles.Tile_Side;
      X_Chunk : constant Natural := 4_096;
   begin
      if not Doc.Is_Nonempty (Item.Region) or else
        not Doc.Is_Within (Item.Region, Rev.Extent (Item.Workspace,
          Rev.Background (Item.Workspace, Item.Revision)))
      then
         raise Comp.Render_Error with "Invalid preview region";
      end if;
      if Left >= Right or else Top >= Bottom then
         raise Comp.Render_Error with "Preview region misses revision";
      end if;
      Surface := Cairo.Image_Surface.Create
        (Cairo.Image_Surface.Cairo_Format_ARGB32,
         Glib.Gint (Out_Width), Glib.Gint (Out_Height));
      if Cairo.Surface.Status (Surface) /= Cairo.Cairo_Status_Success then
         raise Comp.Render_Error with "Cannot allocate Canvas preview";
      end if;
      Data := Cairo.Image_Surface.Get_Data_Generic (Surface);
      Stride := Natural (Cairo.Image_Surface.Get_Stride (Surface));
      if Data = System.Null_Address then
         raise Comp.Render_Error with "Cannot access Canvas preview pixels";
      end if;

      declare
         Band_Top : Natural := Top;
      begin
         Band_Loop : while Band_Top < Bottom loop
            exit Band_Loop when Item.Completed.Is_Cancelled;
            declare
               Band_Bottom : constant Natural := Natural'Min
                 (Bottom, (Band_Top / Tile_Side + 1) * Tile_Side);
            begin
                  declare
                     Block_Left : Natural := Left;
                  begin
                     Block_Loop : while Block_Left < Right loop
                        exit Block_Loop when Item.Completed.Is_Cancelled;
                        declare
                           Block_Right : constant Natural := Natural'Min
                             (Right, (Block_Left / X_Chunk + 1) * X_Chunk);
                           Area : constant Doc.Rectangle :=
                             (Left => Block_Left, Top => Band_Top,
                              Right => Block_Right, Bottom => Band_Bottom);
                           Image : Comp.Image;
                        begin
                           Tile.Render
                             (FD, Item.Workspace, Item.Revision, Area,
                              Image, Item.Include_Ink);
                           declare
                              Bytes : constant
                                Ada.Streams.Stream_Element_Array :=
                                  Comp.Pixels (Image);
                              Image_Width : constant Positive :=
                                Positive (Comp.Width (Image));
                           begin
                              for Out_Y in 0 .. Out_Height - 1 loop
                                 declare
                                    Src_Y : constant Natural := Top + Natural
                                      ((Long_Long_Integer (2 * Out_Y + 1) *
                                        Long_Long_Integer (Source_Height)) /
                                       Long_Long_Integer (2 * Out_Height));
                                 begin
                                    if Src_Y >= Band_Top and then
                                      Src_Y < Band_Bottom
                                    then
                                       for Out_X in 0 .. Out_Width - 1 loop
                                          declare
                                             Src_X : constant Natural := Left +
                                               Natural
                                                 ((Long_Long_Integer
                                                   (2 * Out_X + 1) *
                                                   Long_Long_Integer
                                                     (Source_Width)) /
                                                  Long_Long_Integer
                                                    (2 * Out_Width));
                                          begin
                                             if Src_X >= Block_Left and then
                                               Src_X < Block_Right
                                             then
                                                declare
                                                   Offset : constant Natural :=
                                                     ((Src_Y - Band_Top) *
                                                       Image_Width +
                                                      Src_X - Block_Left) * 4;
                                                   Alpha : constant Natural :=
                                                     Natural
                                                       (Bytes (Bytes'First +
                                                        Ada.Streams.Stream_Element_Offset
                                                         (Offset + 3)));
                                                   Red : constant Natural :=
                                                     Natural
                                                       (Bytes (Bytes'First +
                                                        Ada.Streams.Stream_Element_Offset
                                                         (Offset)));
                                                   Green : constant Natural :=
                                                     Natural
                                                       (Bytes (Bytes'First +
                                                        Ada.Streams.Stream_Element_Offset
                                                         (Offset + 1)));
                                                   Blue : constant Natural :=
                                                     Natural
                                                       (Bytes (Bytes'First +
                                                        Ada.Streams.Stream_Element_Offset
                                                         (Offset + 2)));
                                                   Pixel : constant
                                                     Pixel_Access :=
                                                       To_Pixel_Access
                                                         (System.Storage_Elements.To_Address
                                                           (System.Storage_Elements.To_Integer
                                                              (Data) +
                                                            System.Storage_Elements.Integer_Address
                                                              (Out_Y * Stride +
                                                               Out_X * 4)));
                                                begin
                                                   Pixel.Alpha :=
                                                     Cairo.Image_Surface.Byte
                                                       (Alpha);
                                                   Pixel.Red :=
                                                     Cairo.Image_Surface.Byte
                                                       ((Red * Alpha + 127) /
                                                        255);
                                                   Pixel.Green :=
                                                     Cairo.Image_Surface.Byte
                                                       ((Green * Alpha + 127) /
                                                        255);
                                                   Pixel.Blue :=
                                                     Cairo.Image_Surface.Byte
                                                       ((Blue * Alpha + 127) /
                                                        255);
                                                end;
                                             end if;
                                          end;
                                       end loop;
                                    end if;
                                 end;
                              end loop;
                           end;
                           Block_Left := Block_Right;
                        end;
                     end loop Block_Loop;
                  end;
               Band_Top := Band_Bottom;
            end;
         end loop Band_Loop;
      end;
      if Item.Completed.Is_Cancelled then
         Cairo.Surface_Destroy (Surface);
      else
         Cairo.Surface.Mark_Dirty (Surface);
         Item.Result := Surface;
      end if;
   exception
      when others =>
         if Surface /= Cairo.Null_Surface then
            Cairo.Surface_Destroy (Surface);
         end if;
         raise;
   end Render_Preview;

   task body Worker is
      FD : Interfaces.C.int := -1;
      Status : Store.Result := Store.IO_Error;
   begin
      Store.Open_Validated_Tile
        (To_String (Item.Parent), To_String (Item.UUID),
         To_String (Item.Digest), FD, Status);
      if Status = Store.Ok and then not Item.Completed.Is_Cancelled then
         if Item.Preview then
            Render_Preview (Item, FD);
         else
            declare
               Image : Comp.Image;
            begin
               Tile.Render
                 (FD, Item.Workspace, Item.Revision, Item.Region, Image,
                  Item.Include_Ink);
               if not Item.Completed.Is_Cancelled then
                  Item.Result := Comp.Display_Surface (Image);
               end if;
            end;
         end if;
      end if;
      Store.Close_Tile (FD);
      Item.Completed.Signal;
   exception
      when others =>
         Store.Close_Tile (FD);
         Item.Completed.Signal;
   end Worker;

   procedure Start
     (Item : out Job_Access;
      Parent, UUID, Digest : String;
      W : Rev.Workspace;
      Id : Rev.Revision_Id;
      Region : Doc.Rectangle;
      Include_Ink : Boolean;
      Preview : Boolean)
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
      Item.Preview := Preview;
      Item.Thread := new Worker (Item);
   exception
      when others =>
         Free (Item);
         raise;
   end Start;

   function Ready (Item : Job_Access) return Boolean is
     (Item /= null and then Item.Completed.Is_Ready);

   procedure Cancel (Item : Job_Access) is
   begin
      if Item /= null then
         Item.Completed.Cancel;
      end if;
   end Cancel;

   procedure Discard (Item : in out Job_Access) is
   begin
      if Item /= null then
         Item.Completed.Cancel;
         Item.Completed.Wait;
         while not Item.Thread'Terminated loop
            delay 0.001;
         end loop;
         if Item.Result /= Cairo.Null_Surface then
            Cairo.Surface_Destroy (Item.Result);
            Item.Result := Cairo.Null_Surface;
         end if;
         Free (Item.Thread);
         Free (Item);
      end if;
   end Discard;

   procedure Finish
     (Item : in out Job_Access;
      Surface : out Cairo.Cairo_Surface)
   is
   begin
      Surface := Cairo.Null_Surface;
      if Item /= null then
         Item.Completed.Wait;
         if not Item.Completed.Is_Cancelled then
            Surface := Item.Result;
            Item.Result := Cairo.Null_Surface;
         end if;
         Discard (Item);
      end if;
   end Finish;
end Coyote_GUI.Canvas_Tile_Views;
