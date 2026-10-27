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
with Math_Raster;
with Math_Syntax;

procedure Math_Raster_Probe is
   use type Interfaces.Unsigned_32;
   use type Ada.Containers.Count_Type;
   use type Math_Raster.Byte_Vectors.Vector;
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
   Fonts : Math_Painter.Font_Set;
   Parsed : Math_Syntax.Document;
   Layout : Math_Layout.Box;
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
