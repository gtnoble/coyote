with Ada.Streams;
with Ada.Unchecked_Deallocation;
with Coyote_Canvas.Images;
with Coyote_Canvas.Rasters;
with Coyote_Canvas.Tiles;
with Interfaces;
with Interfaces.C;

package body Coyote_Canvas.Tile_Render is
   use Ada.Streams;
   use type Document.Rectangle;

   type Pixel_Buffer is access Stream_Element_Array;
   procedure Free is new Ada.Unchecked_Deallocation
     (Stream_Element_Array, Pixel_Buffer);

   TILE_BYTES : constant := Coyote_Canvas.Tiles.Tile_Side ** 2 * 4;
   MAX_REGION_PIXELS : constant := 16 * 1_024 * 1_024;

   function Read_Region
     (FD : Interfaces.C.int; Region : Document.Rectangle;
      Source_Width, Source_Height : Positive) return Pixel_Buffer
   is
      use type Coyote_Canvas.Tiles.Result;
      use type Interfaces.Unsigned_32;
      use Coyote_Canvas.Tiles;
      Status : Tiles.Result;
      Size, Extent : Dimensions;
      Tile : Tile_Buffer (1 .. TILE_BYTES);
      Bytes : Pixel_Buffer;
      Left : constant Natural := Region.Left;
      Top : constant Natural := Region.Top;
      Right : constant Natural := Region.Right;
      Bottom : constant Natural := Region.Bottom;
      Width, Height : Positive;
      Tile_Left, Tile_Top : Natural;
      Copy_Left, Copy_Top, Copy_Right, Copy_Bottom : Natural;
   begin
      Inspect (FD, Status, Size);
      if Status /= Success or else Natural (Size.Width) /= Source_Width
        or else Natural (Size.Height) /= Source_Height
        or else not Document.Is_Within
          (Region, Document.Full_Extent (Source_Width, Source_Height))
      then
         raise Composite.Render_Error with "Invalid tiled Canvas source";
      end if;
      Width := Right - Left;
      Height := Bottom - Top;
      if Width > Rasters.MAX_SIDE or else Height > Rasters.MAX_SIDE or else
        Height > MAX_REGION_PIXELS / Width
      then
         raise Composite.Render_Error with "Tile render region exceeds bounds";
      end if;
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
      return Bytes;
   exception
      when others =>
         Free (Bytes);
         raise;
   end Read_Region;

   procedure Render
     (FD : Interfaces.C.int; W : Revisions.Workspace;
      Id : Revisions.Revision_Id; Region : Document.Rectangle;
      Result : in out Composite.Image; Include_Ink : Boolean := True)
   is
      Original, Revision, Requested : Document.Rectangle;
      Background : Revisions.Revision_Id;
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
      if not Document.Is_Within (Region, Original) then
         raise Composite.Render_Error with "Invalid tile render region";
      end if;
      Revision := Revisions.Extent (W, Id);
      Requested :=
        (Natural'Max (Region.Left, Revision.Left),
         Natural'Max (Region.Top, Revision.Top),
         Natural'Min (Region.Right, Revision.Right),
         Natural'Min (Region.Bottom, Revision.Bottom));
      Bytes := Read_Region (FD, Requested, Original.Right, Original.Bottom);
      Composite.Render (W, Id, Bytes.all, Requested, Result, Include_Ink);
      Free (Bytes);
   exception
      when others =>
         Free (Bytes);
         raise;
   end Render;

   function Display_Level
     (FD, Original_FD : Interfaces.C.int; W : Revisions.Workspace;
      Id : Revisions.Revision_Id; Region : Document.Rectangle;
      Step : Positive; Include_Ink : Boolean) return Cairo.Cairo_Surface
   is
      Original : constant Document.Rectangle :=
        Revisions.Extent (W, Revisions.Background (W, Id));
      Bytes : Pixel_Buffer;
      Surface : Cairo.Cairo_Surface;
      Extent : constant Document.Rectangle := Revisions.Extent (W, Id);
      Width : constant Natural := Region.Right - Region.Left;

      --  Whole level cells already contain the right filtered pixels.
      --  Re-sample only the strip of cells cut by a crop edge. A native
      --  center sample there avoids bleeding discarded pixels into the
      --  crop, and is bounded even for a very thin cropped image.
      procedure Fix_Crop_Edges is
         use Coyote_Canvas.Tiles;
         use type Tiles.Result;
         Tile : Tile_Buffer (1 .. TILE_BYTES);
         Size : Dimensions;
         Status : Tiles.Result;
         Prior_X, Prior_Y : Natural := Natural'Last;
         Edge_X : constant Boolean := Extent.Left mod Step /= 0 or else
           Extent.Right mod Step /= 0;
         Edge_Y : constant Boolean := Extent.Top mod Step /= 0 or else
           Extent.Bottom mod Step /= 0;

         procedure Sample (X, Y : Natural) is
            Left : constant Natural := Natural'Max (Extent.Left, X * Step);
            Right : constant Natural := Natural'Min
              (Extent.Right, (X + 1) * Step);
            Top : constant Natural := Natural'Max (Extent.Top, Y * Step);
            Bottom : constant Natural := Natural'Min
              (Extent.Bottom, (Y + 1) * Step);
            PX : constant Natural := Left + (Right - Left - 1) / 2;
            PY : constant Natural := Top + (Bottom - Top - 1) / 2;
            TX : constant Natural := PX / Tile_Side;
            TY : constant Natural := PY / Tile_Side;
            Src : Natural;
            Dst : constant Natural :=
              ((Y - Region.Top) * Width + X - Region.Left) * 4;
         begin
            if TX /= Prior_X or else TY /= Prior_Y then
               Read_Tile (Original_FD, Interfaces.Unsigned_32 (TX),
                          Interfaces.Unsigned_32 (TY), Tile, Status, Size);
               if Status /= Success then
                  raise Composite.Render_Error with "Cannot read crop edge";
               end if;
               Prior_X := TX;
               Prior_Y := TY;
            end if;
            Src := ((PY mod Tile_Side) * Natural (Size.Width) +
                    PX mod Tile_Side) * 4;
            for C in 1 .. 4 loop
               Bytes (Stream_Element_Offset (Dst + C)) :=
                 Stream_Element (Tile (Src + C));
            end loop;
         end Sample;

         procedure Column (X : Natural) is
         begin
            if X in Region.Left .. Region.Right - 1 then
               for Y in Region.Top .. Region.Bottom - 1 loop
                  Sample (X, Y);
               end loop;
            end if;
         end Column;

         procedure Row (Y : Natural) is
         begin
            if Y in Region.Top .. Region.Bottom - 1 then
               for X in Region.Left .. Region.Right - 1 loop
                  Sample (X, Y);
               end loop;
            end if;
         end Row;
      begin
         if Edge_X then
            if Extent.Left mod Step /= 0 then
               Column (Extent.Left / Step);
            end if;
            if Extent.Right < Original.Right and then
              Extent.Right mod Step /= 0
            then
               Column (Extent.Right / Step);
            end if;
         end if;
         if Edge_Y then
            if Extent.Top mod Step /= 0 then
               Row (Extent.Top / Step);
            end if;
            if Extent.Bottom < Original.Bottom and then
              Extent.Bottom mod Step /= 0
            then
               Row (Extent.Bottom / Step);
            end if;
         end if;
      end Fix_Crop_Edges;
   begin
      Bytes := Read_Region
        (FD, Region, (Original.Right + Step - 1) / Step,
         (Original.Bottom + Step - 1) / Step);
      if Extent /= Original then
         Fix_Crop_Edges;
      end if;
      Surface := Composite.Level_Surface
        (W, Id, Bytes.all, Region.Right - Region.Left,
         Region.Bottom - Region.Top, Step,
         Region.Left * Step, Region.Top * Step, Include_Ink);
      Free (Bytes);
      return Surface;
   exception
      when others =>
         Free (Bytes);
         raise;
   end Display_Level;
end Coyote_Canvas.Tile_Render;
