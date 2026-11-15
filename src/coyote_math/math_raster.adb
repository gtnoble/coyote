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

   procedure Clear (Item : in out Image) is
      Empty : Byte_Vectors.Vector;
   begin
      --  Move an empty vector to free capacity, not merely erase elements.
      Byte_Vectors.Move (Target => Item.Pixels, Source => Empty);
      Item.Pixel_Width := 0;
      Item.Pixel_Height := 0;
      Item.Pixel_Stride := 0;
      Item.Logical_X := 0;
      Item.Logical_Y := 0;
   end Clear;

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

   function Origin_X (Item : Image) return Integer is (Item.Logical_X);
   function Origin_Y (Item : Image) return Integer is (Item.Logical_Y);

   function Measure
     (Layout : Math_Layout.Box; Em_Scale : Long_Float;
      Work : Math_Work_Control.Context_Access := null) return Raster_Bounds
   is
      Logical_Width, Logical_Height : Long_Float;
      Min_X, Min_Y : Long_Float := 0.0;
      Max_X, Max_Y : Long_Float;
      Result : Raster_Bounds;

      procedure Include
        (Command : Math_Layout.Draw_Command;
         Left, Top, Right, Bottom : Long_Float)
      is
         X1 : Long_Float := Left;
         Y1 : Long_Float := Top;
         X2 : Long_Float := Right;
         Y2 : Long_Float := Bottom;
      begin
         if Command.Has_Clip then
            X1 := Long_Float'Max (X1, Command.Clip_X);
            Y1 := Long_Float'Max (Y1, Command.Clip_Y);
            X2 := Long_Float'Min (X2, Command.Clip_X + Command.Clip_W);
            Y2 := Long_Float'Min (Y2, Command.Clip_Y + Command.Clip_H);
         end if;
         if X1 <= X2 and then Y1 <= Y2 then
            Min_X := Long_Float'Min
              (Min_X, (Command.X + X1) * Em_Scale);
            Max_X := Long_Float'Max
              (Max_X, (Command.X + X2) * Em_Scale);
            Min_Y := Long_Float'Min
              (Min_Y, (Layout.Ascent + Command.Y + Y1) * Em_Scale);
            Max_Y := Long_Float'Max
              (Max_Y, (Layout.Ascent + Command.Y + Y2) * Em_Scale);
         end if;
      end Include;

      function Finite_Geometry (Value : Long_Float) return Boolean is
        (Value'Valid and then abs Value <= 16_777_216.0);
   begin
      Math_Work_Control.Poll (Work);
      if not Layout.Valid or else not Em_Scale'Valid or else
        Em_Scale <= 0.0 or else Em_Scale > 256.0 or else
        not Layout.Width'Valid or else not Layout.Ascent'Valid or else
        not Layout.Descent'Valid or else Layout.Width < 0.0 or else
        Layout.Ascent < 0.0 or else Layout.Descent < 0.0 or else
        Layout.Width > 8192.0 or else Layout.Ascent > 4096.0 or else
        Layout.Descent > 4096.0
      then
         raise Raster_Error with "invalid layout bounds or scale";
      end if;
      Logical_Width := Layout.Width * Em_Scale;
      Logical_Height := (Layout.Ascent + Layout.Descent) * Em_Scale;
      Max_X := Logical_Width;
      Max_Y := Logical_Height;
      for Command of Layout.Commands loop
         Math_Work_Control.Poll (Work);
         if not Finite_Geometry (Command.X) or else
           not Finite_Geometry (Command.Y) or else
           not Finite_Geometry (Command.Width) or else
           not Finite_Geometry (Command.Height) or else
           not Command.Scale'Valid or else Command.Scale <= 0.0 or else
           Command.Scale > 256.0 or else Command.Width < 0.0 or else
           Command.Height < 0.0
         then
            raise Raster_Error with "invalid drawing geometry";
         end if;
         if Command.Has_Clip and then
           (not Finite_Geometry (Command.Clip_X) or else
            not Finite_Geometry (Command.Clip_Y) or else
            not Finite_Geometry (Command.Clip_W) or else
            not Finite_Geometry (Command.Clip_H) or else
            Command.Clip_W < 0.0 or else Command.Clip_H < 0.0)
         then
            raise Raster_Error with "invalid drawing clip";
         end if;
         case Command.Kind is
            when Math_Layout.Path_Command =>
               declare
                  X1, Y1 : Long_Float := Long_Float'Last;
                  X2, Y2 : Long_Float := -Long_Float'Last;
                  procedure Point (P : Math_Paths.Point) is
                  begin
                     if not Finite_Geometry (P.X) or else
                       not Finite_Geometry (P.Y)
                     then
                        raise Raster_Error with "invalid path point";
                     end if;
                     X1 := Long_Float'Min (X1, P.X);
                     X2 := Long_Float'Max (X2, P.X);
                     Y1 := Long_Float'Min (Y1, P.Y);
                     Y2 := Long_Float'Max (Y2, P.Y);
                  end Point;
               begin
                  for Segment of Command.Path_Data loop
                     Math_Work_Control.Poll (Work);
                     case Segment.Kind is
                        when Math_Paths.Move_To | Math_Paths.Line_To =>
                           Point (Segment.First);
                        when Math_Paths.Cubic_To =>
                           Point (Segment.First);
                           Point (Segment.Second);
                           Point (Segment.Third);
                        when Math_Paths.Close_Path =>
                           null;
                     end case;
                  end loop;
                  --  The control-point hull conservatively bounds curves.
                  if X1 <= X2 and then Y1 <= Y2 then
                     Include (Command, X1, Y1, X2, Y2);
                  end if;
               end;
            when Math_Layout.Rule_Command =>
               Include (Command, 0.0, 0.0, Command.Width, Command.Height);
            when Math_Layout.Glyph_Command =>
               declare
                  Metric : constant Math_Metrics.Glyph_Metric :=
                    Math_Metrics.Lookup (Command.Font, Command.Code_Point);
               begin
                  if Metric.Found then
                     Include (Command, 0.0, -Metric.Ascent * Command.Scale,
                       Metric.Width * Command.Scale,
                       Metric.Descent * Command.Scale);
                  end if;
               end;
            when Math_Layout.Text_Run_Command =>
               --  Reference glyph bounds do not describe shaped-run ink.
               --  Its layout envelope remains the current admission bound.
               null;
         end case;
         if Command.Has_Shadow then
            if not Command.Shadow_X'Valid or else
              not Command.Shadow_Y'Valid or else
              not Command.Shadow_Blur_Px'Valid or else
              Command.Shadow_X < 0.0 or else Command.Shadow_X > 256.0 or else
              Command.Shadow_Y < 0.0 or else Command.Shadow_Y > 256.0 or else
              Command.Shadow_Blur_Px < 0.0 or else
              Command.Shadow_Blur_Px > 256.0
            then
               raise Raster_Error with "unsupported or invalid shadow bounds";
            end if;
            --  Preserve the conservative trailing shadow reservation. The
            --  Gaussian taps may also cross the leading edge of a glyph.
            Max_X := Long_Float'Max (Max_X, Logical_Width +
              Command.Shadow_X * Em_Scale + Command.Shadow_Blur_Px);
            Max_Y := Long_Float'Max (Max_Y, Logical_Height +
              Command.Shadow_Y * Em_Scale + Command.Shadow_Blur_Px);
            if Command.Kind = Math_Layout.Glyph_Command then
               declare
                  Metric : constant Math_Metrics.Glyph_Metric :=
                    Math_Metrics.Lookup (Command.Font, Command.Code_Point);
                  Blur : constant Long_Float :=
                    Command.Shadow_Blur_Px / Em_Scale;
               begin
                  if Metric.Found then
                     Include (Command,
                       Command.Shadow_X - Blur,
                       -Metric.Ascent * Command.Scale +
                         Command.Shadow_Y - Blur,
                       Metric.Width * Command.Scale +
                         Command.Shadow_X + Blur,
                       Metric.Descent * Command.Scale +
                         Command.Shadow_Y + Blur);
                  end if;
               end;
            end if;
         end if;
      end loop;
      --  Integer leading padding preserves the original subpixel placement.
      --  Keep addition before the trailing ceil to avoid double rounding.
      if -Min_X > Long_Float (Integer'Last / 2) or else
        -Min_Y > Long_Float (Integer'Last / 2) or else
        Max_X - Min_X > Long_Float (Integer'Last / 2) or else
        Max_Y - Min_Y > Long_Float (Integer'Last / 2)
      then
         raise Raster_Error with "raster bounds overflow";
      end if;
      Result.Origin_X := Natural (Long_Float'Ceiling (-Min_X));
      Result.Origin_Y := Natural (Long_Float'Ceiling (-Min_Y));
      Result.Width := Positive'Max
        (1, Integer (Long_Float'Ceiling (Max_X)) + Result.Origin_X);
      Result.Height := Positive'Max
        (1, Integer (Long_Float'Ceiling (Max_Y)) + Result.Origin_Y);
      return Result;
   end Measure;

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
      Bounds : Raster_Bounds;
      S : Natural;
      Data : System.Address;
   begin
      Math_Work_Control.Poll (Work);
      if not Color.Red'Valid or else not Color.Green'Valid or else
        not Color.Blue'Valid or else not Color.Alpha'Valid or else
        Color.Red < 0.0 or else Color.Red > 1.0 or else
        Color.Green < 0.0 or else Color.Green > 1.0 or else
        Color.Blue < 0.0 or else Color.Blue > 1.0 or else
        Color.Alpha < 0.0 or else Color.Alpha > 1.0
      then
         raise Raster_Error with "invalid color";
      end if;
      Bounds := Measure (Layout, Em_Scale, Work);
      if Is_Tile then
         if W = 0 or else H = 0 or else W > 256 or else H > 256 then
            raise Raster_Error with "tile dimensions exceed 256 x 256";
         end if;
         if Left >= Bounds.Width or else Top >= Bounds.Height then
            raise Raster_Error with "viewport origin outside raster";
         end if;
      else
         W := Bounds.Width;
         H := Bounds.Height;
         if W > 8192 or else H > 4096 then
            raise Raster_Error with "full raster dimension limit exceeded";
         end if;
      end if;
      S := W * 4;
      if Long_Float (S) * Long_Float (H) * 2.0 > 268_435_456.0 then
         raise Raster_Error with "raster workspace exceeds 256 MiB";
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
        (Fonts, Context, Layout,
         Long_Float (Bounds.Origin_X) - Long_Float (Left),
         Long_Float (Bounds.Origin_Y) + Layout.Ascent * Em_Scale -
           Long_Float (Top), Em_Scale, Work);
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
      Result.Logical_X := Integer (Bounds.Origin_X) - Integer (Left);
      Result.Logical_Y := Integer (Bounds.Origin_Y) - Integer (Top);
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
