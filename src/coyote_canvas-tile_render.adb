with Ada.Streams;
with Ada.Unchecked_Deallocation;
with Coyote_Canvas.Images;
with Coyote_Canvas.Rasters;
with Coyote_Canvas.Tiles;
with Interfaces;
with Interfaces.C;

package body Coyote_Canvas.Tile_Render is
   use Ada.Streams;

   type Pixel_Buffer is access Stream_Element_Array;
   procedure Free is new Ada.Unchecked_Deallocation
     (Stream_Element_Array, Pixel_Buffer);

   TILE_BYTES : constant := Coyote_Canvas.Tiles.Tile_Side ** 2 * 4;
   MAX_REGION_PIXELS : constant := 16 * 1_024 * 1_024;

   procedure Render
     (FD : Interfaces.C.int;
      W : Revisions.Workspace;
      Id : Revisions.Revision_Id;
      Region : Document.Rectangle;
      Result : in out Composite.Image;
      Include_Ink : Boolean := True)
   is
      use type Interfaces.Unsigned_32;
      use type Coyote_Canvas.Tiles.Result;
      Status : Coyote_Canvas.Tiles.Result;
      Size : Coyote_Canvas.Tiles.Dimensions;
      Extent : Coyote_Canvas.Tiles.Dimensions;
      Tile : aliased Coyote_Canvas.Tiles.Tile_Buffer
        (1 .. TILE_BYTES);
      Original : Document.Rectangle;
      Background : Revisions.Revision_Id;
      Left : Natural;
      Top : Natural;
      Right : Natural;
      Bottom : Natural;
      Width, Height : Positive;
      Bytes : Pixel_Buffer;
   begin
      if Id > Revisions.Count (W) then
         raise Composite.Render_Error with "Canvas revision is unavailable";
      end if;
      Background := Revisions.Background (W, Id);
      if Background = Revisions.NO_REVISION then
         raise Composite.Render_Error with "Canvas has no tiled background";
      end if;
      Original := Revisions.Extent (W, Background);
      Coyote_Canvas.Tiles.Inspect (FD, Status, Size);
      if Status /= Coyote_Canvas.Tiles.Success or else
        Size.Width = 0 or else Size.Height = 0 or else
        Natural (Size.Width) /= Original.Right or else
        Natural (Size.Height) /= Original.Bottom
      then
         raise Composite.Render_Error with "Invalid tiled Canvas source";
      end if;
      if not Document.Is_Nonempty (Region) or else
        not Document.Is_Within (Region, Original)
      then
         raise Composite.Render_Error with "Invalid tile render region";
      end if;
      declare
         Revision : constant Document.Rectangle := Revisions.Extent (W, Id);
      begin
         Left := Natural'Max (Region.Left, Revision.Left);
         Top := Natural'Max (Region.Top, Revision.Top);
         Right := Natural'Min (Region.Right, Revision.Right);
         Bottom := Natural'Min (Region.Bottom, Revision.Bottom);
      end;
      if Left >= Right or else Top >= Bottom then
         raise Composite.Render_Error with "Region misses Canvas revision";
      end if;
      Width := Right - Left;
      Height := Bottom - Top;
      if Width > Rasters.MAX_SIDE or else Height > Rasters.MAX_SIDE or else
        Height > MAX_REGION_PIXELS / Width
      then
         raise Composite.Render_Error with "Tile render region exceeds bounds";
      end if;
      declare
         Requested : constant Document.Rectangle :=
           (Left => Left, Top => Top, Right => Right, Bottom => Bottom);
         Tile_Left : Natural;
         Tile_Top : Natural;
         Copy_Left, Copy_Top, Copy_Right, Copy_Bottom : Natural;
      begin
         Bytes := new Stream_Element_Array
           (1 .. Stream_Element_Offset
             (Coyote_Canvas.Images.Packed_Byte_Count (Width, Height)));
         for Tile_Y in Top / Coyote_Canvas.Tiles.Tile_Side ..
           (Bottom - 1) / Coyote_Canvas.Tiles.Tile_Side
         loop
            for Tile_X in Left / Coyote_Canvas.Tiles.Tile_Side ..
              (Right - 1) / Coyote_Canvas.Tiles.Tile_Side
            loop
               Coyote_Canvas.Tiles.Read_Tile
                 (FD, Interfaces.Unsigned_32 (Tile_X),
                  Interfaces.Unsigned_32 (Tile_Y), Tile, Status, Extent);
               if Status /= Coyote_Canvas.Tiles.Success then
                  raise Composite.Render_Error with "Cannot read Canvas tile";
               end if;
               Tile_Left := Tile_X * Coyote_Canvas.Tiles.Tile_Side;
               Tile_Top := Tile_Y * Coyote_Canvas.Tiles.Tile_Side;
               Copy_Left := Natural'Max (Left, Tile_Left);
               Copy_Top := Natural'Max (Top, Tile_Top);
               Copy_Right := Natural'Min
                 (Right, Tile_Left + Natural (Extent.Width));
               Copy_Bottom := Natural'Min
                 (Bottom, Tile_Top + Natural (Extent.Height));
               if Copy_Left >= Copy_Right or else Copy_Top >= Copy_Bottom then
                  raise Composite.Render_Error with "Invalid Canvas tile edge";
               end if;
               for Y in Copy_Top .. Copy_Bottom - 1 loop
                  for X in Copy_Left .. Copy_Right - 1 loop
                     declare
                        Src : constant Natural :=
                          ((Y - Tile_Top) * Natural (Extent.Width) +
                           X - Tile_Left) * 4;
                        Dst : constant Natural :=
                          ((Y - Top) * Width + X - Left) * 4;
                     begin
                        for Channel in 0 .. 3 loop
                           Bytes (Bytes'First + Stream_Element_Offset
                             (Dst + Channel)) := Stream_Element
                               (Tile (Tile'First + Src + Channel));
                        end loop;
                     end;
                  end loop;
               end loop;
            end loop;
         end loop;
         Composite.Render
           (W, Id, Bytes.all, Requested, Result, Include_Ink);
         Free (Bytes);
      end;
   exception
      when others =>
         Free (Bytes);
         raise;
   end Render;
end Coyote_Canvas.Tile_Render;
