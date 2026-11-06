with Ada.Strings.Unbounded;
with Ada.Containers;
with Ada.Command_Line;
with Ada.Exceptions;
with Ada.Text_IO;
with Cairo;
with Interfaces;
with Math_Layout;
with Math_Metrics;
with Math_Model;
with Math_Painter;
with Math_Paths;
with Math_Raster;
with Math_Syntax;
with Math_Work_Control;
with Math_Text_Shaping;

procedure Math_Raster_Probe is
   use type Interfaces.Unsigned_32;
   use type Ada.Containers.Count_Type;
   use type Math_Raster.Byte_Vectors.Vector;
   use type Math_Layout.Command_Kind;
   protected Monitor is
      procedure Add_Result (Condition : Boolean; Label : String);
      function Assertions return Natural;
      function Failures return Natural;
   private
      Assertion_Count : Natural := 0;
      Failure_Count : Natural := 0;
   end Monitor;

   protected body Monitor is
      procedure Add_Result (Condition : Boolean; Label : String) is
      begin
         Assertion_Count := Assertion_Count + 1;
         if Condition then
            Ada.Text_IO.Put_Line ("ok " & Label);
         else
            Failure_Count := Failure_Count + 1;
            Ada.Text_IO.Put_Line ("not ok " & Label);
         end if;
      end Add_Result;
      function Assertions return Natural is (Assertion_Count);
      function Failures return Natural is (Failure_Count);
   end Monitor;
   protected Poll_Counter is
      procedure Reset (Threshold : Positive; Stop : Math_Work_Control.Stop_Reason);
      procedure Check (Result : out Math_Work_Control.Stop_Reason);
   private
      Limit : Positive := 1;
      Current : Natural := 0;
      Stop_Reason : Math_Work_Control.Stop_Reason :=
        Math_Work_Control.Cancel_Requested;
   end Poll_Counter;
   protected body Poll_Counter is
      procedure Reset (Threshold : Positive; Stop : Math_Work_Control.Stop_Reason) is
      begin
         Limit := Threshold;
         Current := 0;
         Stop_Reason := Stop;
      end Reset;
      procedure Check (Result : out Math_Work_Control.Stop_Reason) is
      begin
         Current := Current + 1;
         Result := (if Current >= Limit then Stop_Reason
                    else Math_Work_Control.Continue_Work);
      end Check;
   end Poll_Counter;
   type Stop_Context is new Math_Work_Control.Context with null record;
   overriding function Check
     (Item : Stop_Context) return Math_Work_Control.Stop_Reason;
   overriding function Check
     (Item : Stop_Context) return Math_Work_Control.Stop_Reason is
      pragma Unreferenced (Item);
   begin
      declare
         Result : Math_Work_Control.Stop_Reason;
      begin
         Poll_Counter.Check (Result);
         return Result;
      end;
   end Check;
   Stopped : aliased Stop_Context;
   Work : constant Math_Work_Control.Context_Access :=
     Stopped'Unchecked_Access;
   Fonts : Math_Painter.Font_Set;
   Parsed : Math_Syntax.Document;
   Layout : Math_Layout.Box;
   Pmb_Layout : Math_Layout.Box;
   Foreground : constant Math_Model.Color_Value :=
     (Red => 0.08, Green => 0.12, Blue => 0.20, Alpha => 1.0);
   Full : Math_Raster.Image;
   Failed : Boolean := False;
   Font_Path : Ada.Strings.Unbounded.Unbounded_String;

   procedure Check (Condition : Boolean; Label : String) is
   begin
      Monitor.Add_Result (Condition, Label);
   end Check;

   function Hash (Item : Math_Raster.Image) return Interfaces.Unsigned_32 is
      H : Interfaces.Unsigned_32 := 16#811C_9DC5#;
   begin
      for Y in 0 .. Math_Raster.Height (Item) - 1 loop
         declare
            Row : constant Math_Raster.Byte_Vectors.Vector :=
              Math_Raster.Row_Data (Item, Y);
         begin
            for B of Row loop
               H := (H xor Interfaces.Unsigned_32 (B)) * 16#0100_0193#;
            end loop;
         end;
      end loop;
      return H;
   end Hash;

   function Has_Ink (Item : Math_Raster.Image) return Boolean is
   begin
      for Y in 0 .. Math_Raster.Height (Item) - 1 loop
         for X in 0 .. Math_Raster.Width (Item) - 1 loop
            if Interfaces.Shift_Right
              (Math_Raster.Get_Pixel (Item, X, Y), 24) > 0
            then
               return True;
            end if;
         end loop;
      end loop;
      return False;
   end Has_Ink;

   function Has_Consistent_Premultiplied_Color
     (Item : Math_Raster.Image; Color : Math_Model.Color_Value)
      return Boolean
   is
      Found_Partial : Boolean := False;
   begin
      for Y in 0 .. Math_Raster.Height (Item) - 1 loop
         for X in 0 .. Math_Raster.Width (Item) - 1 loop
            declare
               Pixel : constant Interfaces.Unsigned_32 :=
                 Math_Raster.Get_Pixel (Item, X, Y);
               Alpha : constant Interfaces.Unsigned_32 :=
                 Interfaces.Shift_Right (Pixel, 24);
               Blue : constant Interfaces.Unsigned_32 := Pixel and 16#FF#;
               Green : constant Interfaces.Unsigned_32 :=
                 Interfaces.Shift_Right (Pixel, 8) and 16#FF#;
               Red : constant Interfaces.Unsigned_32 :=
                 Interfaces.Shift_Right (Pixel, 16) and 16#FF#;
            begin
               if Alpha > 0 then
                  if Alpha > 128 then
                     return False;
                  end if;
                  if Alpha < 255 then
                     Found_Partial := True;
                  end if;
                  if abs (Long_Float (Red) -
                      Color.Red * Long_Float (Alpha)) > 2.0 or else
                    abs (Long_Float (Green) -
                      Color.Green * Long_Float (Alpha)) > 2.0 or else
                    abs (Long_Float (Blue) -
                      Color.Blue * Long_Float (Alpha)) > 2.0
                  then
                     return False;
                  end if;
               end if;
            end;
         end loop;
      end loop;
      return Found_Partial;
   end Has_Consistent_Premultiplied_Color;

   task type Renderer (Id : Positive);
   task body Renderer is
      Local : Math_Raster.Image;
      Local_Fonts : Math_Painter.Font_Set;
   begin
      Math_Painter.Load
           (Local_Fonts, Ada.Strings.Unbounded.To_String (Font_Path));
      for N in 1 .. 8 loop
         Local := Math_Raster.Render (Local_Fonts, Layout, 28.0, Foreground);
         Check (Hash (Local) = Hash (Full), "worker deterministic render");
      end loop;
   exception
      when E : others =>
         Monitor.Add_Result (False, Ada.Exceptions.Exception_Message (E));
   end Renderer;
begin
   if Ada.Command_Line.Argument_Count /= 1 then
      raise Program_Error with "usage: math_raster_probe FONT_DIRECTORY";
   end if;
   Font_Path := Ada.Strings.Unbounded.To_Unbounded_String
     (Ada.Command_Line.Argument (1));
   Math_Painter.Load (Fonts, Ada.Command_Line.Argument (1));
   begin
      declare
         Invalid_Fonts : Math_Painter.Font_Set;
      begin
         Math_Painter.Load (Invalid_Fonts, "/not/a/font/directory");
         Failed := False;
      end;
   exception
      when Math_Painter.Font_Error => Failed := True;
   end;
   Check (Failed, "reject missing font directory");
   declare
      use type Math_Model.Font_Kind;
      Expected_Scales : constant array (1 .. 6) of Natural :=
        (12, 16, 20, 24, 32, 48);
      Advance : Long_Float;
   begin
      Check
        (Math_Metrics.Lookup (Math_Model.Typewriter_Regular, 32).Width =
           0.525,
         "typewriter normalized em width remains 0.525");
      for Scale of Expected_Scales loop
         Advance := Math_Metrics.Advance
           (Math_Metrics.Advance_Source'Class (Fonts),
            Math_Model.Typewriter_Regular, 32, Long_Float (Scale));
         Ada.Text_IO.Put_Line
           ("# native typewriter-space em=" & Natural'Image (Scale) &
            " x_advance=" & Long_Float'Image (Advance));
         Check (Advance > 0.0, "native advance positive at scale" &
           Natural'Image (Scale));
      end loop;
      Advance := Math_Metrics.Advance
        (Math_Metrics.Advance_Source'Class (Fonts),
         Math_Model.Typewriter_Regular, 32, 24.0);
      Check (Advance = 13.0, "native typewriter-space advance at 24px is 13");
   end;
   declare
      Cancel_Fonts : Math_Painter.Font_Set;
   begin
      Poll_Counter.Reset (1, Math_Work_Control.Cancel_Requested);
      Failed := False;
      begin
         Math_Painter.Load (Cancel_Fonts, "", Work);
      exception
         when Math_Work_Control.Stop_Requested => Failed := True;
      end;
      Check (Failed, "font load polls before native font work");
   end;
   declare
      use type Math_Model.Font_Kind;
      Registered : constant Math_Syntax.Document :=
        Math_Syntax.Parse ("\textregistered");
      Registered_Layout : constant Math_Layout.Box :=
        Math_Layout.Build (Registered, Math_Layout.Display_Style);
      Registered_Image : Math_Raster.Image;
      Registered_Metric : constant Math_Metrics.Glyph_Metric :=
        Math_Metrics.Lookup (Math_Model.Main_Regular, 16#00AE#);
   begin
      Check (Registered_Layout.Valid and then Registered_Metric.Found,
        "registered symbol resolves pinned fallback metrics");
      Check (Math_Metrics.Font_For
        (Math_Model.Main_Regular, 16#00AE#) = Math_Model.AMS_Regular,
        "registered symbol selects exact AMS face");
      Registered_Image := Math_Raster.Render
        (Fonts, Registered_Layout, 28.0, Foreground);
      Check (Has_Ink (Registered_Image),
        "registered symbol paints from pinned fallback face");
   end;
   declare
      Samples : constant array (Positive range 1 .. 8) of
        Ada.Strings.Unbounded.Unbounded_String :=
          (Ada.Strings.Unbounded.To_Unbounded_String ("Ж"),
           Ada.Strings.Unbounded.To_Unbounded_String ("Ա"),
           Ada.Strings.Unbounded.To_Unbounded_String ("क"),
           Ada.Strings.Unbounded.To_Unbounded_String ("ა"),
           Ada.Strings.Unbounded.To_Unbounded_String ("中"),
           Ada.Strings.Unbounded.To_Unbounded_String ("한"),
           Ada.Strings.Unbounded.To_Unbounded_String ("Ł"),
           Ada.Strings.Unbounded.To_Unbounded_String ("क्ष"));
      Strict : constant Math_Syntax.Options :=
        (Strict => Math_Syntax.Strict_Error, others => <>);
      Metrics_12 : Math_Text_Shaping.Metrics;
      Metrics_24 : Math_Text_Shaping.Metrics;
      Metrics_48 : Math_Text_Shaping.Metrics;
      Source_Samples : constant array (Positive range 1 .. 2) of
        Ada.Strings.Unbounded.Unbounded_String :=
          (Ada.Strings.Unbounded.To_Unbounded_String ("Ś"),
           Ada.Strings.Unbounded.To_Unbounded_String ("Ś"));
   begin
      for Source_Sample of Source_Samples loop
         declare
            Text : constant String :=
              Ada.Strings.Unbounded.To_String (Source_Sample);
            Shaped : constant Math_Text_Shaping.Metrics :=
              Math_Text_Shaping.Measure
                (Text, Math_Model.Latin_Fallback, 24.0);
            Image : Math_Raster.Image;
         begin
            Check (Shaped.Advance > 0.0 and then Shaped.Ascent > 0.0,
              "Pango shapes actual Latin source sequence " & Text);
         end;
      end loop;
      for Sample of Samples loop
         declare
            Text : constant String :=
              Ada.Strings.Unbounded.To_String (Sample);
            Source : constant String := "\text{" & Text & "}";
            Parsed_Text : constant Math_Syntax.Document :=
              Math_Syntax.Parse (Source, Strict);
            Shaped_Layout : constant Math_Layout.Box :=
              Math_Layout.Build (Parsed_Text, Math_Layout.Display_Style);
            Image : Math_Raster.Image;
         begin
            Check (Math_Syntax.Is_Valid (Parsed_Text),
              "strict text fallback parses " & Text);
            Check (Shaped_Layout.Valid,
              "fallback layout valid " & Text);
            if Shaped_Layout.Valid then
               Check
                 (Shaped_Layout.Commands (Shaped_Layout.Commands.First_Index).Kind =
                    Math_Layout.Text_Run_Command and then
                  Ada.Strings.Unbounded.To_String
                    (Shaped_Layout.Commands
                       (Shaped_Layout.Commands.First_Index).Text_Run_Text) = Text,
                  "layout command preserves text " & Text);
               Image := Math_Raster.Render
                 (Fonts, Shaped_Layout, 24.0, Foreground);
               Check (Has_Ink (Image), "native raster ink " & Text);
            end if;
         end;
      end loop;
      Poll_Counter.Reset (1, Math_Work_Control.Cancel_Requested);
      Failed := False;
      begin
         Metrics_12 := Math_Text_Shaping.Measure
           ("Ж", Math_Model.Cyrillic_Fallback, 12.0, Work);
      exception
         when Math_Work_Control.Stop_Requested => Failed := True;
      end;
      Check (Failed, "shaping polls cancellation before native calls");
      Failed := False;
      begin
         Metrics_12 := Math_Text_Shaping.Measure
           (String'(1 => Character'Val (16#C0#)),
            Math_Model.Cyrillic_Fallback);
      exception
         when Constraint_Error => Failed := True;
      end;
      Check (Failed, "shaping rejects malformed UTF-8");
      Metrics_12 := Math_Text_Shaping.Measure
        ("Ж", Math_Model.Cyrillic_Fallback, 12.0);
      Metrics_24 := Math_Text_Shaping.Measure
        ("Ж", Math_Model.Cyrillic_Fallback, 24.0);
      Metrics_48 := Math_Text_Shaping.Measure
        ("Ж", Math_Model.Cyrillic_Fallback, 48.0);
      Check
        (Metrics_12.Advance > 0.0 and then Metrics_24.Advance > 0.0 and then
         Metrics_48.Advance > 0.0 and then
         abs (Metrics_12.Advance - Metrics_24.Advance) < 0.08 and then
         abs (Metrics_24.Advance - Metrics_48.Advance) < 0.08,
         "Pango advances normalize across requested 12/24/48 pixel em sizes");
      declare
         Combined : constant Math_Syntax.Document := Math_Syntax.Parse
           ("\text{क्ष}", Strict);
         Combined_Layout : constant Math_Layout.Box :=
           Math_Layout.Build (Combined, Math_Layout.Display_Style);
      begin
         Check (Combined_Layout.Valid, "Devanagari conjunct text shapes");
      end;
   end;
   Parsed := Math_Syntax.Parse ("x+y");
   Layout := Math_Layout.Build (Parsed, Math_Layout.Display_Style);
   Check (Layout.Valid, "parse representative formula");
   Full := Math_Raster.Render (Fonts, Layout, 28.0, Foreground);
   Check (Math_Raster.Width (Full) > 0, "full width positive");
   Check (Math_Raster.Height (Full) > 0, "full height positive");
   Check (Math_Raster.Stride (Full) >= Math_Raster.Width (Full) * 4,
     "stride includes each pixel");
   Check
     (Math_Raster.Row_Data (Full, 0).Length =
        Ada.Containers.Count_Type (Math_Raster.Stride (Full)),
     "row data is owned stride");
   Check
     (Interfaces.Shift_Right
        (Math_Raster.Get_Pixel (Full, 0, 0), 24) = 0,
      "full render background alpha is zero");
   Check (Has_Ink (Full), "full render contains foreground ink");
   Check (Hash (Full) /= 0, "render output hash nonzero");
   declare
      Box_Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
        ("\colorbox{red}{x}+y");
      Box_Layout : constant Math_Layout.Box := Math_Layout.Build (Box_Parsed);
      Box_Image : constant Math_Raster.Image := Math_Raster.Render
        (Fonts, Box_Layout, 28.0, Foreground);
      Frame_Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
        ("\fcolorbox{blue}{#ffffff}{A}");
      Frame_Layout : constant Math_Layout.Box := Math_Layout.Build (Frame_Parsed);
      Frame_Image : constant Math_Raster.Image := Math_Raster.Render
        (Fonts, Frame_Layout, 28.0, Foreground);
      Saw_Red : Boolean := False;
      Saw_Blue : Boolean := False;
      Saw_Foreground : Boolean := False;
   begin
      for Y in 0 .. Math_Raster.Height (Box_Image) - 1 loop
         for X in 0 .. Math_Raster.Width (Box_Image) - 1 loop
            declare
               Pixel : constant Interfaces.Unsigned_32 :=
                 Math_Raster.Get_Pixel (Box_Image, X, Y);
               Alpha : constant Interfaces.Unsigned_32 :=
                 Interfaces.Shift_Right (Pixel, 24);
               Red : constant Interfaces.Unsigned_32 :=
                 Interfaces.Shift_Right (Pixel, 16) and 16#FF#;
               Green : constant Interfaces.Unsigned_32 :=
                 Interfaces.Shift_Right (Pixel, 8) and 16#FF#;
               Blue : constant Interfaces.Unsigned_32 := Pixel and 16#FF#;
            begin
               Saw_Red := Saw_Red or else
                 (Alpha = 255 and then Red = 255 and then Green = 0 and then Blue = 0);
               Saw_Foreground := Saw_Foreground or else
                 (Alpha = 255 and then Red in 20 | 21 and then
                  Green in 30 | 31 and then Blue in 50 | 51);
            end;
         end loop;
      end loop;
      for Y in 0 .. Math_Raster.Height (Frame_Image) - 1 loop
         for X in 0 .. Math_Raster.Width (Frame_Image) - 1 loop
            declare
               Pixel : constant Interfaces.Unsigned_32 :=
                 Math_Raster.Get_Pixel (Frame_Image, X, Y);
               Alpha : constant Interfaces.Unsigned_32 :=
                 Interfaces.Shift_Right (Pixel, 24);
               Red : constant Interfaces.Unsigned_32 :=
                 Interfaces.Shift_Right (Pixel, 16) and 16#FF#;
               Green : constant Interfaces.Unsigned_32 :=
                 Interfaces.Shift_Right (Pixel, 8) and 16#FF#;
               Blue : constant Interfaces.Unsigned_32 := Pixel and 16#FF#;
            begin
               Saw_Blue := Saw_Blue or else
                 (Alpha = 255 and then Red = 0 and then Green = 0 and then Blue = 255);
            end;
         end loop;
      end loop;
      Check (Box_Layout.Valid and then Frame_Layout.Valid,
        "colorbox layouts are valid");
      Check (Saw_Red, "opaque red colorbox background pixel is present");
      Check (Saw_Blue, "opaque blue fcolorbox border pixel is present");
      Check (Saw_Foreground,
        "box painting preserves configured foreground on glyph and sibling");
   end;
   declare
      Shadow_Color : constant Math_Model.Color_Value :=
        (Red => 0.80, Green => 0.20, Blue => 0.10, Alpha => 0.50);
      Colored_Shadow : Math_Raster.Image;
   begin
      Parsed := Math_Syntax.Parse ("\pmb{g}");
      Pmb_Layout := Math_Layout.Build (Parsed, Math_Layout.Display_Style);
      for Index in Pmb_Layout.Commands.First_Index ..
        Pmb_Layout.Commands.Last_Index
      loop
         declare
            Command : Math_Layout.Draw_Command :=
              Pmb_Layout.Commands (Index);
         begin
            if Command.Kind = Math_Layout.Glyph_Command then
               Command.Has_Shadow := True;
               Command.Shadow_X := 0.75;
               Command.Shadow_Y := 0.75;
               Command.Shadow_Blur_Px := 2.0;
               Pmb_Layout.Commands.Replace_Element (Index, Command);
            end if;
         end;
      end loop;
      Colored_Shadow := Math_Raster.Render
        (Fonts, Pmb_Layout, 28.0, Shadow_Color);
      Check (Has_Consistent_Premultiplied_Color
        (Colored_Shadow, Shadow_Color),
        "translucent shadow preserves source color and alpha");
   end;
   Parsed := Math_Syntax.Parse ("\pmb{g}");
   Pmb_Layout := Math_Layout.Build (Parsed, Math_Layout.Display_Style);
   Check (Pmb_Layout.Valid, "build poor-man bold glyph");
   for Index in Pmb_Layout.Commands.First_Index ..
     Pmb_Layout.Commands.Last_Index
   loop
      declare
         Command : Math_Layout.Draw_Command :=
           Pmb_Layout.Commands (Index);
      begin
         if Command.Has_Shadow then
            Command.Shadow_X := 0.75;
            Command.Shadow_Y := 0.75;
            Pmb_Layout.Commands.Replace_Element (Index, Command);
         end if;
      end;
   end loop;
   declare
      Shadowed : constant Math_Raster.Image := Math_Raster.Render
        (Fonts, Pmb_Layout, 28.0, Foreground);
      Plain_Layout : Math_Layout.Box := Pmb_Layout;
      Plain : Math_Raster.Image;
   begin
      for Index in Plain_Layout.Commands.First_Index ..
        Plain_Layout.Commands.Last_Index
      loop
         declare
            Command : Math_Layout.Draw_Command :=
              Plain_Layout.Commands (Index);
         begin
            Command.Has_Shadow := False;
            Plain_Layout.Commands.Replace_Element (Index, Command);
         end;
      end loop;
      Plain := Math_Raster.Render (Fonts, Plain_Layout, 28.0, Foreground);
      Check (Hash (Shadowed) /= Hash (Plain),
        "poor-man bold shadow changes glyph pixels");
      Check
        (Math_Raster.Width (Shadowed) >
           Natural'Max
             (1, Natural (Long_Float'Ceiling
               (Pmb_Layout.Width * 28.0))),
         "shadow reserves right overflow pixels");
      Check
        (Math_Raster.Height (Shadowed) >
           Natural'Max
             (1, Natural (Long_Float'Ceiling
               ((Pmb_Layout.Ascent + Pmb_Layout.Descent) * 28.0))),
         "shadow reserves bottom overflow pixels");
      declare
         Extra_Ink : Boolean := False;
      begin
         for Y in 0 .. Math_Raster.Height (Shadowed) - 1 loop
            for X in 0 .. Math_Raster.Width (Shadowed) - 1 loop
               if (X >= Natural'Max
                     (1, Natural (Long_Float'Ceiling
                       (Pmb_Layout.Width * 28.0))) or else
                   Y >= Natural'Max
                     (1, Natural (Long_Float'Ceiling
                       ((Pmb_Layout.Ascent + Pmb_Layout.Descent) * 28.0))))
                 and then Interfaces.Shift_Right
                   (Math_Raster.Get_Pixel (Shadowed, X, Y), 24) > 0
               then
                  Extra_Ink := True;
               end if;
            end loop;
         end loop;
         Check (Extra_Ink, "shadow ink is retained outside logical bounds");
      end;
      declare
         Whole_Tile : constant Math_Raster.Image := Math_Raster.Render_Tile
           (Fonts, Pmb_Layout, 28.0, Foreground, 0, 0,
            Math_Raster.Width (Shadowed), Math_Raster.Height (Shadowed));
      begin
         Check (Hash (Whole_Tile) = Hash (Shadowed),
           "shadowed whole tile matches full render");
      end;
   end;
   declare
      Invalid : Math_Layout.Box := Pmb_Layout;
      Ignore : Math_Raster.Image;
   begin
      declare
         Command : Math_Layout.Draw_Command :=
           Invalid.Commands (Invalid.Commands.First_Index);
      begin
         Command.Shadow_X := Long_Float'Last;
         Invalid.Commands.Replace_Element
           (Invalid.Commands.First_Index, Command);
      end;
      begin
         Ignore := Math_Raster.Render (Fonts, Invalid, 28.0, Foreground);
         Failed := False;
      exception
         when Math_Painter.Font_Error | Math_Raster.Raster_Error =>
            Failed := True;
      end;
      Check (Failed, "reject invalid glyph shadow offset");
   end;
   declare
      Tile : constant Math_Raster.Image := Math_Raster.Render_Tile
        (Fonts, Layout, 28.0, Foreground, 0, 0,
         Math_Raster.Width (Full), Math_Raster.Height (Full));
   begin
      Check (Hash (Tile) = Hash (Full), "whole viewport matches full render");
      Check
        (Interfaces.Shift_Right
           (Math_Raster.Get_Pixel (Tile, 0, 0), 24) = 0,
         "tile background alpha is zero");
      Check (Has_Ink (Tile), "tile render contains foreground ink");
   end;
   declare
      Right : constant Natural := Math_Raster.Width (Full) / 2;
      Bottom : constant Natural := Math_Raster.Height (Full) / 2;
      A : constant Math_Raster.Image := Math_Raster.Render_Tile
        (Fonts, Layout, 28.0, Foreground, 0, 0, Right, Bottom);
      B : constant Math_Raster.Image := Math_Raster.Render_Tile
        (Fonts, Layout, 28.0, Foreground, Right, 0,
         Math_Raster.Width (Full) - Right, Bottom);
      C : constant Math_Raster.Image := Math_Raster.Render_Tile
        (Fonts, Layout, 28.0, Foreground, 0, Bottom, Right,
         Math_Raster.Height (Full) - Bottom);
      D : constant Math_Raster.Image := Math_Raster.Render_Tile
        (Fonts, Layout, 28.0, Foreground, Right, Bottom,
         Math_Raster.Width (Full) - Right,
         Math_Raster.Height (Full) - Bottom);
   begin
      Check (Math_Raster.Get_Pixel (A, 0, 0) =
        Math_Raster.Get_Pixel (Full, 0, 0), "tile top-left aligned");
      Check (Math_Raster.Get_Pixel (B, 0, 0) =
        Math_Raster.Get_Pixel (Full, Right, 0), "tile horizontal origin");
      Check (Math_Raster.Get_Pixel (C, 0, 0) =
        Math_Raster.Get_Pixel (Full, 0, Bottom), "tile vertical origin");
      Check (Math_Raster.Get_Pixel (D, 0, 0) =
        Math_Raster.Get_Pixel (Full, Right, Bottom), "tile combined origin");
   end;
   declare
      Workers : array (1 .. 2) of Renderer (1);
      pragma Unreferenced (Workers);
   begin
      Check (True, "two concurrent independent render tasks");
   end;
   begin
      declare
         Ignore : constant Math_Raster.Image := Math_Raster.Render
           (Fonts, Layout, 0.0, Foreground);
         pragma Unreferenced (Ignore);
      begin
         Failed := False;
      end;
   exception
      when Math_Raster.Raster_Error => Failed := True;
   end;
   Check (Failed, "reject zero em scale");
   begin
      declare
         Ignore : constant Math_Raster.Image := Math_Raster.Render
           (Fonts, Layout, Long_Float'Last, Foreground);
         pragma Unreferenced (Ignore);
      begin
         Failed := False;
      end;
   exception
      when Math_Raster.Raster_Error => Failed := True;
   end;
   Check (Failed, "reject excessive em scale");
   declare
      Width_At_Limit : Math_Layout.Box := Pmb_Layout;
      Width_Over_Limit : Math_Layout.Box := Pmb_Layout;
      Height_At_Limit : Math_Layout.Box := Pmb_Layout;
      Height_Over_Limit : Math_Layout.Box := Pmb_Layout;
      Boundary_Image : Math_Raster.Image;
   begin
      Width_At_Limit.Width := 8191.2;
      Width_At_Limit.Ascent := 0.0;
      Width_At_Limit.Descent := 0.0;
      Width_Over_Limit.Width := 8191.2;
      Width_Over_Limit.Ascent := 0.0;
      Width_Over_Limit.Descent := 0.0;
      Height_At_Limit.Width := 0.0;
      Height_At_Limit.Ascent := 4095.2;
      Height_At_Limit.Descent := 0.0;
      Height_Over_Limit.Width := 0.0;
      Height_Over_Limit.Ascent := 4095.2;
      Height_Over_Limit.Descent := 0.0;
      for Index in Pmb_Layout.Commands.First_Index ..
        Pmb_Layout.Commands.Last_Index
      loop
         declare
            Command : constant Math_Layout.Draw_Command :=
              Pmb_Layout.Commands (Index);
         begin
            if Command.Kind = Math_Layout.Glyph_Command then
               declare
                  Width_Command : Math_Layout.Draw_Command := Command;
               begin
                  Width_Command.Has_Shadow := True;
                  Width_Command.Shadow_X := 0.0;
                  Width_Command.Shadow_Y := 0.0;
                  Width_Command.Shadow_Blur_Px := 0.7;
                  Width_At_Limit.Commands.Replace_Element
                    (Index, Width_Command);
                  Width_Over_Limit.Commands.Replace_Element
                    (Index, Width_Command);
               end;
               declare
                  Height_Command : Math_Layout.Draw_Command := Command;
               begin
                  Height_Command.Has_Shadow := True;
                  Height_Command.Shadow_X := 0.0;
                  Height_Command.Shadow_Y := 0.0;
                  Height_Command.Shadow_Blur_Px := 0.7;
                  Height_At_Limit.Commands.Replace_Element
                    (Index, Height_Command);
                  Height_Over_Limit.Commands.Replace_Element
                    (Index, Height_Command);
               end;
            end if;
         end;
      end loop;
      Boundary_Image := Math_Raster.Render
        (Fonts, Width_At_Limit, 1.0, Foreground);
      Check (Math_Raster.Width (Boundary_Image) = 8192 and then
        Math_Raster.Height (Boundary_Image) = 1,
        "fractional width and overflow ceil combined to 8192");
      Boundary_Image := Math_Raster.Render
        (Fonts, Height_At_Limit, 1.0, Foreground);
      Check (Math_Raster.Width (Boundary_Image) <= 8192 and then
        Math_Raster.Height (Boundary_Image) = 4096,
        "fractional height and overflow ceil combined to 4096");
      Width_Over_Limit.Width := 8191.31;
      Height_Over_Limit.Ascent := 4095.31;
      begin
         Boundary_Image := Math_Raster.Render
           (Fonts, Width_Over_Limit, 1.0, Foreground);
         Failed := False;
      exception
         when Math_Raster.Raster_Error => Failed := True;
      end;
      Check (Failed, "reject combined full width above 8192");
      begin
         Boundary_Image := Math_Raster.Render
           (Fonts, Height_Over_Limit, 1.0, Foreground);
         Failed := False;
      exception
         when Math_Raster.Raster_Error => Failed := True;
      end;
      Check (Failed, "reject combined full height above 4096");
   end;
   begin
      declare
         Bad_Color : constant Math_Model.Color_Value :=
           (Red => 2.0, Green => 0.0, Blue => 0.0, Alpha => 1.0);
         Ignore : constant Math_Raster.Image := Math_Raster.Render
           (Fonts, Layout, 28.0, Bad_Color);
         pragma Unreferenced (Ignore);
      begin
         Failed := False;
      end;
   exception
      when Math_Raster.Raster_Error => Failed := True;
   end;
   Check (Failed, "reject out-of-range color");
   begin
      declare
         Ignore : constant Math_Raster.Image := Math_Raster.Render_Tile
           (Fonts, Layout, 28.0, Foreground, 0, 0, 257, 1);
         pragma Unreferenced (Ignore);
      begin
         Failed := False;
      end;
   exception
      when Math_Raster.Raster_Error => Failed := True;
   end;
   Check (Failed, "reject oversized tile");
   declare
      Invalid : Math_Layout.Box := Layout;
      Ignore : Math_Raster.Image;
   begin
      Invalid.Valid := False;
      begin
         Ignore := Math_Raster.Render (Fonts, Invalid, 28.0, Foreground);
         Failed := False;
      exception
         when Math_Raster.Raster_Error => Failed := True;
      end;
      Check (Failed, "reject invalid layout");
   end;
   declare
      Transparent : constant Math_Model.Color_Value :=
        (Red => 1.0, Green => 0.0, Blue => 0.0, Alpha => 0.0);
      Clear : constant Math_Raster.Image := Math_Raster.Render
        (Fonts, Layout, 28.0, Transparent);
   begin
      Check (Math_Raster.Get_Pixel (Clear, 0, 0) = 0,
        "transparent background is clear");
   end;
   Poll_Counter.Reset
     (Natural (Layout.Commands.Length) + 5,
      Math_Work_Control.Cancel_Requested);
   Failed := False;
   begin
      declare
         Cancelled_Image : constant Math_Raster.Image := Math_Raster.Render
           (Fonts, Layout, 28.0, Foreground, Work);
         pragma Unreferenced (Cancelled_Image);
      begin
         null;
      end;
   exception
      when Math_Work_Control.Stop_Requested => Failed := True;
   end;
   Check (Failed, "painter partial draw propagates cancellation");
   declare
      Path_Layout : Math_Layout.Box :=
        (Valid => True, Width => 1.0, Ascent => 1.0, others => <>);
      Path_Command : Math_Layout.Draw_Command;
      Cancelled_Path : Boolean := False;
   begin
      Path_Command.Kind := Math_Layout.Path_Command;
      for Index in 1 .. 512 loop
         Path_Command.Path_Data.Append
           (Math_Paths.Segment'
              (Kind => Math_Paths.Line_To,
               First => (X => 0.5, Y => 0.5), others => <>));
      end loop;
      Path_Layout.Commands.Append (Path_Command);
      Poll_Counter.Reset (9, Math_Work_Control.Cancel_Requested);
      begin
         declare
            Ignore : constant Math_Raster.Image := Math_Raster.Render
              (Fonts, Path_Layout, 8.0, Foreground, Work);
            pragma Unreferenced (Ignore);
         begin
            null;
         end;
      exception
         when Math_Work_Control.Stop_Requested => Cancelled_Path := True;
      end;
      Check (Cancelled_Path,
        "painter polls cancellation during a multi-segment path");
   end;
   Poll_Counter.Reset
     (Natural (Layout.Commands.Length) * 2 + 8,
      Math_Work_Control.Deadline_Reached);
   Failed := False;
   begin
      declare
         Cancelled_Image : constant Math_Raster.Image := Math_Raster.Render
           (Fonts, Layout, 28.0, Foreground, Work);
         pragma Unreferenced (Cancelled_Image);
      begin
         null;
      end;
   exception
      when Math_Work_Control.Deadline_Expired => Failed := True;
   end;
   Check (Failed, "raster copy deadline propagates");
   Check (Math_Raster.Width (Full) <= 8192, "full width within cap");
   Check (Math_Raster.Height (Full) <= 4096, "full height within cap");
   Check (Math_Raster.Get_Pixel (Full, 0, 0) =
     Math_Raster.Get_Pixel (Full, 0, 0), "pixel access is repeatable");
   if Monitor.Failures = 0 then
      Ada.Text_IO.Put_Line
        ("# assertions=" & Natural'Image (Monitor.Assertions) & " failures=0");
   else
      Ada.Text_IO.Put_Line
        ("# assertions=" & Natural'Image (Monitor.Assertions) & " failures=" &
         Natural'Image (Monitor.Failures));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
exception
   when E : others =>
      Ada.Text_IO.Put_Line (Ada.Exceptions.Exception_Information (E));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Math_Raster_Probe;
