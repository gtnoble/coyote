with Ada.Containers;
with System.Address_To_Access_Conversions;
with System.Storage_Elements;
with Cairo;
with Cairo.Image_Surface;
with Cairo.Surface;
with Glib;
with Math_Painter;
with Math_Metrics;
with Math_Paths;
with Math_Work_Control;

package body Math_Raster is
   use type Cairo.Cairo_Status;
   use type Cairo.Cairo_Context;
   use type Cairo.Cairo_Surface;
   use type Math_Layout.Command_Kind;
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
      Result : out Image;
      Work : Math_Work_Control.Context_Access) is
      Surface : Cairo.Cairo_Surface := Cairo.Null_Surface;
      Context : Cairo.Cairo_Context := Cairo.Null_Context;
      W : Natural := View_Width;
      H : Natural := View_Height;
      Full_Width : Natural;
      Full_Height : Natural;
      Right_Overflow : Long_Float := 0.0;
      Bottom_Overflow : Long_Float := 0.0;
      Glyph_Bottom_Overflow : Long_Float := 0.0;
      Rule_Bottom_Overflow : Long_Float := 0.0;
      S : Natural;
      Data : System.Address;
      procedure Path_Ink_Bounds
        (Command : Math_Layout.Draw_Command;
         Logical_Width, Logical_Height : Long_Float) is
         Min_X : Long_Float := Long_Float'Last;
         Max_X : Long_Float := -Long_Float'Last;
         Min_Y : Long_Float := Long_Float'Last;
         Max_Y : Long_Float := -Long_Float'Last;
         procedure Include (X, Y : Long_Float) is
         begin
            Min_X := Long_Float'Min (Min_X, X);
            Max_X := Long_Float'Max (Max_X, X);
            Min_Y := Long_Float'Min (Min_Y, Y);
            Max_Y := Long_Float'Max (Max_Y, Y);
         end Include;
      begin
         if Command.Path_Data.Is_Empty then
            return;
         end if;
         for Segment of Command.Path_Data loop
            Math_Work_Control.Poll (Work);
            case Segment.Kind is
               when Math_Paths.Move_To | Math_Paths.Line_To =>
                  Include (Segment.First.X, Segment.First.Y);
               when Math_Paths.Cubic_To =>
                  Include (Segment.First.X, Segment.First.Y);
                  Include (Segment.Second.X, Segment.Second.Y);
                  Include (Segment.Third.X, Segment.Third.Y);
               when Math_Paths.Close_Path =>
                  null;
            end case;
         end loop;
         if Command.Has_Clip then
            Min_X := Long_Float'Max (Min_X, Command.Clip_X);
            Max_X := Long_Float'Min
              (Max_X, Command.Clip_X + Command.Clip_W);
            Min_Y := Long_Float'Max (Min_Y, Command.Clip_Y);
            Max_Y := Long_Float'Min
              (Max_Y, Command.Clip_Y + Command.Clip_H);
         end if;
         if Min_X <= Max_X and then Min_Y <= Max_Y then
            Right_Overflow := Long_Float'Max
              (Right_Overflow,
               (Command.X + Max_X) * Em_Scale - Logical_Width);
            Bottom_Overflow := Long_Float'Max
              (Bottom_Overflow,
               (Layout.Ascent + Command.Y + Max_Y) * Em_Scale -
                 Logical_Height);
         end if;
      end Path_Ink_Bounds;
   begin
      Math_Work_Control.Poll (Work);
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
      declare
         Logical_Width : constant Long_Float := Layout.Width * Em_Scale;
         Logical_Height : constant Long_Float :=
           (Layout.Ascent + Layout.Descent) * Em_Scale;
      begin
         if not Logical_Width'Valid or else not Logical_Height'Valid then
            raise Raster_Error with "invalid scaled layout dimensions";
         end if;
         if not Is_Tile then
            if Logical_Width > 8192.0 or else Logical_Height > 4096.0 then
               raise Raster_Error with
                 "full raster dimension limit exceeded";
            end if;
            Full_Width := Natural'Max
              (1, Natural (Long_Float'Ceiling (Logical_Width)));
            Full_Height := Natural'Max
              (1, Natural (Long_Float'Ceiling (Logical_Height)));
         end if;
         for Index in Layout.Commands.First_Index ..
           Layout.Commands.Last_Index
         loop
            Math_Work_Control.Poll (Work);
            declare
               Command : constant Math_Layout.Draw_Command :=
                 Layout.Commands (Index);
            begin
               if Command.Kind = Math_Layout.Glyph_Command and then
                 not Command.Has_Clip
               then
                  declare
                     Metric : constant Math_Metrics.Glyph_Metric :=
                       Math_Metrics.Lookup
                         (Command.Font, Command.Code_Point);
                     Ink_Bottom : Long_Float;
                  begin
                     if Metric.Found then
                        Ink_Bottom :=
                          (Layout.Ascent + Command.Y +
                           Metric.Descent * Command.Scale) * Em_Scale;
                        Glyph_Bottom_Overflow := Long_Float'Max
                          (Glyph_Bottom_Overflow,
                           Ink_Bottom -
                             (Layout.Ascent + Layout.Descent) * Em_Scale);
                     end if;
                  end;
               end if;
               if Command.Kind = Math_Layout.Rule_Command and then
                 not Command.Has_Clip and then
                 not Command.Has_Shadow
               then
                  Rule_Bottom_Overflow := Long_Float'Max
                    (Rule_Bottom_Overflow,
                     (Command.Y + Command.Height - Layout.Descent) *
                       Em_Scale);
               end if;
               if Command.Kind = Math_Layout.Path_Command then
                  Path_Ink_Bounds (Command, Logical_Width, Logical_Height);
               end if;
               if Command.Has_Shadow then
                  if not Command.Shadow_X'Valid or else
                    not Command.Shadow_Y'Valid or else
                    not Command.Shadow_Blur_Px'Valid or else
                    Command.Shadow_X < 0.0 or else
                    Command.Shadow_X > 256.0 or else
                    Command.Shadow_Y < 0.0 or else
                    Command.Shadow_Y > 256.0 or else
                    Command.Shadow_Blur_Px < 0.0 or else
                    Command.Shadow_Blur_Px > 256.0
                  then
                     raise Raster_Error with
                       "unsupported or invalid shadow bounds";
                  end if;
                  Right_Overflow := Long_Float'Max
                    (Right_Overflow, Command.Shadow_X * Em_Scale +
                     Command.Shadow_Blur_Px);
                  Bottom_Overflow := Long_Float'Max
                    (Bottom_Overflow, Command.Shadow_Y * Em_Scale +
                     Command.Shadow_Blur_Px);
               end if;
            end;
         end loop;
         if Right_Overflow > 8192.0 or else Bottom_Overflow > 4096.0 then
            raise Raster_Error with "shadow overflow exceeds raster limit";
         end if;
         if Is_Tile then
            null;
         else
            W := Natural'Max
              (1, Natural (Long_Float'Ceiling
                (Logical_Width + Right_Overflow)));
            declare
               Ink_Raster_Height : constant Natural := Natural'Max
                 (1, Natural (Long_Float'Ceiling
                   (Logical_Height + Long_Float'Max
                      (Bottom_Overflow, Long_Float'Max
                         (0.0, Long_Float'Max
                            (Glyph_Bottom_Overflow,
                             Rule_Bottom_Overflow))))));
            begin
               H := Ink_Raster_Height;
            end;
            if W > 8192 or else H > 4096 then
               raise Raster_Error with
                 "full raster dimension limit exceeded";
            end if;
         end if;
      end;
      if Is_Tile and then (W = 0 or else H = 0 or else W > 256 or else
        H > 256)
      then
         raise Raster_Error with "tile dimensions exceed 256 x 256";
      end if;
      S := W * 4;
      if Long_Float (S) * Long_Float (H) * 2.0 > 268_435_456.0 then
         raise Raster_Error with "raster workspace exceeds 256 MiB";
      end if;
      if Is_Tile
        and then (Long_Float (Left) >
          Layout.Width * Em_Scale + Right_Overflow or else
          Long_Float (Top) >
            (Layout.Ascent + Layout.Descent) * Em_Scale + Bottom_Overflow)
      then
         raise Raster_Error with "viewport origin outside layout";
      end if;
      Math_Work_Control.Poll (Work);
      Surface := Cairo.Image_Surface.Create
        (Cairo.Image_Surface.Cairo_Format_ARGB32,
         Glib.Gint (W), Glib.Gint (H));
      Math_Work_Control.Poll (Work);
      if Cairo.Surface.Status (Surface) /= Cairo.Cairo_Status_Success then
         raise Raster_Error with "cannot create Cairo image surface";
      end if;
      Context := Cairo.Create (Surface);
      Math_Work_Control.Poll (Work);
      if Cairo.Status (Context) /= Cairo.Cairo_Status_Success then
         raise Raster_Error with "cannot create Cairo context";
      end if;
      Cairo.Set_Source_Rgba
        (Context, Glib.Gdouble (Color.Red), Glib.Gdouble (Color.Green),
         Glib.Gdouble (Color.Blue), Glib.Gdouble (Color.Alpha));
      Math_Painter.Draw
        (Fonts, Context, Layout, -Long_Float (Left),
         Layout.Ascent * Em_Scale - Long_Float (Top), Em_Scale, Work);
      Math_Work_Control.Poll (Work);
      Cairo.Destroy (Context);
      Context := Cairo.Null_Context;
      Cairo.Surface.Flush (Surface);
      Math_Work_Control.Poll (Work);
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
      for Row in 0 .. H - 1 loop
         Math_Work_Control.Poll (Work);
         for Start in 0 .. (S - 1) / 128 loop
            Math_Work_Control.Poll (Work);
            declare
               First : constant Natural := Start * 128;
               Last : constant Natural := Natural'Min (S - 1, First + 127);
            begin
               for Column in First .. Last loop
                  declare
                     Index : constant Natural := Row * S + Column;
                  begin
                     Result.Pixels.Append
                       (Byte_Addresses.To_Pointer
                         (Data + System.Storage_Elements.Storage_Offset
                           (Index)).all);
                  end;
               end loop;
            end;
         end loop;
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
      Color : Math_Model.Color_Value;
      Work : Math_Work_Control.Context_Access := null) return Image is
      Result : Image;
   begin
      Paint (Fonts, Layout, Em_Scale, Color, 0, 0, 0, 0, False, Result, Work);
      return Result;
   end Render;

   function Render_Tile
     (Fonts : Math_Painter.Font_Set;
      Layout : Math_Layout.Box;
      Em_Scale : Long_Float;
      Color : Math_Model.Color_Value;
      Viewport_X, Viewport_Y, Tile_Width, Tile_Height : Natural;
      Work : Math_Work_Control.Context_Access := null) return Image is
      Result : Image;
   begin
      Paint (Fonts, Layout, Em_Scale, Color, Viewport_X, Viewport_Y,
        Tile_Width, Tile_Height, True, Result, Work);
      return Result;
   end Render_Tile;
end Math_Raster;
