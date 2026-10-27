with Ada.Containers;
with System.Address_To_Access_Conversions;
with System.Storage_Elements;
with Cairo;
with Cairo.Image_Surface;
with Cairo.Surface;
with Glib;
with Math_Painter;

package body Math_Raster is
   use type Cairo.Cairo_Status;
   use type Cairo.Cairo_Context;
   use type Cairo.Cairo_Surface;
   use type System.Address;
   use type Interfaces.Unsigned_32;
   use type System.Storage_Elements.Storage_Offset;
   package Byte_Addresses is new System.Address_To_Access_Conversions (Byte);

   function Width (Item : Image) return Natural is (Item.Pixel_Width);
   function Height (Item : Image) return Natural is (Item.Pixel_Height);
   function Stride (Item : Image) return Natural is (Item.Pixel_Stride);

   function Get_Pixel
     (Item : Image; X, Y : Natural) return Interfaces.Unsigned_32 is
      Offset : constant Natural := Y * Item.Pixel_Stride + X * 4;
   begin
      if X >= Item.Pixel_Width or else Y >= Item.Pixel_Height then
         raise Constraint_Error with "pixel coordinate outside raster";
      end if;
      return Interfaces.Unsigned_32
        (Item.Pixels.Element (Positive (Offset + 1)))
        or Interfaces.Shift_Left
          (Interfaces.Unsigned_32
             (Item.Pixels.Element (Positive (Offset + 2))), 8)
        or Interfaces.Shift_Left
          (Interfaces.Unsigned_32
             (Item.Pixels.Element (Positive (Offset + 3))), 16)
        or Interfaces.Shift_Left
          (Interfaces.Unsigned_32
             (Item.Pixels.Element (Positive (Offset + 4))), 24);
   end Get_Pixel;

   function Row_Data (Item : Image; Y : Natural) return Byte_Vectors.Vector is
      Result : Byte_Vectors.Vector;
      First : constant Natural := Y * Item.Pixel_Stride;
   begin
      if Y >= Item.Pixel_Height then
         raise Constraint_Error with "row outside raster";
      end if;
      for Offset in 1 .. Item.Pixel_Stride loop
         Result.Append (Item.Pixels (First + Offset));
      end loop;
      return Result;
   end Row_Data;

   procedure Paint
     (Fonts : Math_Painter.Font_Set;
      Layout : Math_Layout.Box;
      Em_Scale : Long_Float;
      Color : Math_Model.Color_Value;
      Left, Top, View_Width, View_Height : Natural;
      Is_Tile : Boolean;
      Result : out Image) is
      Surface : Cairo.Cairo_Surface := Cairo.Null_Surface;
      Context : Cairo.Cairo_Context := Cairo.Null_Context;
      W : Natural := View_Width;
      H : Natural := View_Height;
      S : Natural;
      Data : System.Address;
   begin
      if not Layout.Valid then
         raise Raster_Error with "layout is invalid";
      end if;
      if not Em_Scale'Valid or else Em_Scale <= 0.0
        or else Em_Scale > 256.0
        or else not Color.Red'Valid or else not Color.Green'Valid
        or else not Color.Blue'Valid or else not Color.Alpha'Valid
        or else Color.Red < 0.0 or else Color.Red > 1.0
        or else Color.Green < 0.0 or else Color.Green > 1.0
        or else Color.Blue < 0.0 or else Color.Blue > 1.0
        or else Color.Alpha < 0.0 or else Color.Alpha > 1.0
      then
         raise Raster_Error with "invalid scale or color";
      end if;
      if not Layout.Width'Valid or else not Layout.Ascent'Valid
        or else not Layout.Descent'Valid or else Layout.Width < 0.0
        or else Layout.Ascent < 0.0 or else Layout.Descent < 0.0
        or else Layout.Width > 8192.0 or else Layout.Ascent > 4096.0
        or else Layout.Descent > 4096.0
      then
         raise Raster_Error with "invalid layout bounds";
      end if;
      if Is_Tile then
         if W = 0 or else H = 0 or else W > 256 or else H > 256 then
            raise Raster_Error with "tile dimensions exceed 256 x 256";
         end if;
      else
         declare
            FW : constant Long_Float := Layout.Width * Em_Scale;
            FH : constant Long_Float :=
              (Layout.Ascent + Layout.Descent) * Em_Scale;
         begin
            if not FW'Valid or else not FH'Valid or else FW > 8192.0
              or else FH > 4096.0 then
               raise Raster_Error with "full raster dimension limit exceeded";
            end if;
            W := Natural'Max (1, Natural (Long_Float'Ceiling (FW)));
            H := Natural'Max (1, Natural (Long_Float'Ceiling (FH)));
         end;
      end if;
      S := W * 4;
      if Long_Float (S) * Long_Float (H) * 2.0 > 268_435_456.0 then
         raise Raster_Error with "raster workspace exceeds 256 MiB";
      end if;
      if Is_Tile
        and then (Long_Float (Left) > Layout.Width * Em_Scale
          or else Long_Float (Top) >
            (Layout.Ascent + Layout.Descent) * Em_Scale)
      then
         raise Raster_Error with "viewport origin outside layout";
      end if;
      Surface := Cairo.Image_Surface.Create
        (Cairo.Image_Surface.Cairo_Format_ARGB32,
         Glib.Gint (W), Glib.Gint (H));
      if Cairo.Surface.Status (Surface) /= Cairo.Cairo_Status_Success then
         raise Raster_Error with "cannot create Cairo image surface";
      end if;
      Context := Cairo.Create (Surface);
      if Cairo.Status (Context) /= Cairo.Cairo_Status_Success then
         raise Raster_Error with "cannot create Cairo context";
      end if;
      Cairo.Set_Source_Rgba
        (Context, Glib.Gdouble (Color.Red), Glib.Gdouble (Color.Green),
         Glib.Gdouble (Color.Blue), Glib.Gdouble (Color.Alpha));
      Math_Painter.Draw
        (Fonts, Context, Layout, -Long_Float (Left),
         Layout.Ascent * Em_Scale - Long_Float (Top), Em_Scale);
      Cairo.Destroy (Context);
      Context := Cairo.Null_Context;
      Cairo.Surface.Flush (Surface);
      if Cairo.Surface.Status (Surface) /= Cairo.Cairo_Status_Success then
         raise Raster_Error with "Cairo image flush failed";
      end if;
      S := Natural (Cairo.Image_Surface.Get_Stride (Surface));
      if S < W * 4 then
         raise Raster_Error with "invalid Cairo image stride";
      end if;
      Data := Cairo.Image_Surface.Get_Data_Generic (Surface);
      if Data = System.Null_Address then
         raise Raster_Error with "Cairo image data unavailable";
      end if;
      Result.Pixel_Width := W;
      Result.Pixel_Height := H;
      Result.Pixel_Stride := S;
      Result.Pixels.Reserve_Capacity (Ada.Containers.Count_Type (S * H));
      for Index in 0 .. S * H - 1 loop
         Result.Pixels.Append
           (Byte_Addresses.To_Pointer
              (Data + System.Storage_Elements.Storage_Offset (Index)).all);
      end loop;
      Cairo.Surface.Destroy (Surface);
   exception
      when others =>
         if Context /= Cairo.Null_Context then
            Cairo.Destroy (Context);
         end if;
         if Surface /= Cairo.Null_Surface then
            Cairo.Surface.Destroy (Surface);
         end if;
         raise;
   end Paint;

   function Render
     (Fonts : Math_Painter.Font_Set;
      Layout : Math_Layout.Box;
      Em_Scale : Long_Float;
      Color : Math_Model.Color_Value) return Image is
      Result : Image;
   begin
      Paint (Fonts, Layout, Em_Scale, Color, 0, 0, 0, 0, False, Result);
      return Result;
   end Render;

   function Render_Tile
     (Fonts : Math_Painter.Font_Set;
      Layout : Math_Layout.Box;
      Em_Scale : Long_Float;
      Color : Math_Model.Color_Value;
      Viewport_X, Viewport_Y, Tile_Width, Tile_Height : Natural)
      return Image is
      Result : Image;
   begin
      Paint (Fonts, Layout, Em_Scale, Color, Viewport_X, Viewport_Y,
        Tile_Width, Tile_Height, True, Result);
      return Result;
   end Render_Tile;
end Math_Raster;
