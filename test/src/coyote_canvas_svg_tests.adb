with AUnit.Assertions; use AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Coyote_Canvas.SVG;
with Coyote_Image_Decoder;
with Interfaces.C;
with System;
with System.Address_To_Access_Conversions;
with System.Storage_Elements;

package body Coyote_Canvas_SVG_Tests is
   use type Interfaces.C.int;
   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   type Byte is mod 2 ** 8;
   package Byte_Addresses is new
     System.Address_To_Access_Conversions (Byte);

   function Raw_Pixels
     (Pixbuf : Coyote_Image_Decoder.Pixbuf_Handle)
      return System.Address
     with Import, Convention => C,
       External_Name => "gdk_pixbuf_get_pixels";

   function Byte_At
     (Pixels : System.Address;
      Offset : Natural) return Byte is
      use System.Storage_Elements;
   begin
      return Byte_Addresses.To_Pointer
        (Pixels + Storage_Offset (Offset)).all;
   end Byte_At;

   function Raw_Width
     (Pixbuf : Coyote_Image_Decoder.Pixbuf_Handle)
      return Interfaces.C.int
     with Import, Convention => C,
       External_Name => "gdk_pixbuf_get_width";

   function Raw_Height
     (Pixbuf : Coyote_Image_Decoder.Pixbuf_Handle)
      return Interfaces.C.int
     with Import, Convention => C,
       External_Name => "gdk_pixbuf_get_height";

   function Raw_Rowstride
     (Pixbuf : Coyote_Image_Decoder.Pixbuf_Handle)
      return Interfaces.C.int
     with Import, Convention => C,
       External_Name => "gdk_pixbuf_get_rowstride";

   function Raw_Channels
     (Pixbuf : Coyote_Image_Decoder.Pixbuf_Handle)
      return Interfaces.C.int
     with Import, Convention => C,
       External_Name => "gdk_pixbuf_get_n_channels";

   procedure Check_Decode
     (Data     : String;
      Good     : Boolean;
      Width    : Natural := 0;
      Height   : Natural := 0;
      Sample_X : Natural := 0;
      Sample_Y : Natural := 0;
      Red      : Byte := 0;
      Green    : Byte := 0;
      Blue     : Byte := 0;
      Alpha    : Byte := 0;
      Check_Pixel : Boolean := False)
   is
      Pixels : Coyote_Image_Decoder.Pixbuf_Handle :=
        Coyote_Image_Decoder.Null_Pixbuf;
      Error  : Unbounded_String;
   begin
      Coyote_Canvas.SVG.Decode (Data, Pixels, Error);
      Assert
        ((Length (Error) = 0) = Good,
         "SVG decode status matches expectation: " & To_String (Error));
      if Good then
         Assert
           (not Coyote_Image_Decoder.Is_Null (Pixels),
            "successful SVG decode returns an owned pixbuf");
         Assert
           (Raw_Width (Pixels) = Interfaces.C.int (Width)
              and then Raw_Height (Pixels) = Interfaces.C.int (Height),
            "decoded dimensions match expected raster dimensions");
         if Check_Pixel then
            declare
               Channels : constant Natural :=
                 Natural (Raw_Channels (Pixels));
               Rowstride : constant Natural :=
                 Natural (Raw_Rowstride (Pixels));
               Offset : constant Natural := Sample_Y * Rowstride
                 + Sample_X * Channels;
               Raw : constant System.Address := Raw_Pixels (Pixels);
            begin
               Assert (Channels = 4, "SVG output retains an alpha channel");
               Assert
                 (Byte_At (Raw, Offset) = Red
                    and then Byte_At (Raw, Offset + 1) = Green
                    and then Byte_At (Raw, Offset + 2) = Blue
                    and then Byte_At (Raw, Offset + 3) = Alpha,
                  "decoded pixel has its expected RGBA samples");
            end;
         end if;
         Coyote_Image_Decoder.Release (Pixels);
      else
         Assert
           (Coyote_Image_Decoder.Is_Null (Pixels),
            "failed SVG decode returns no pixbuf");
         Assert (Length (Error) > 0, "failed decode explains the rejection");
      end if;
   end Check_Decode;

   procedure Physical_Units (T : in out Test) is
      pragma Unreferenced (T);
      Document : constant String :=
        "<svg xmlns='http://www.w3.org/2000/svg' "
        & "width='1in' height='12.7mm' viewBox='0 0 192 96'>"
        & "<rect width='192' height='96' fill='#e02040'/>"
        & "</svg>";
   begin
      Check_Decode
        (Document, True, 96, 48, 10, 10,
         16#E0#, 16#20#, 16#40#, 16#FF#, True);
   end Physical_Units;

   procedure Viewbox_Ceiling (T : in out Test) is
      pragma Unreferenced (T);
      Document : constant String :=
        "<svg xmlns='http://www.w3.org/2000/svg' "
        & "viewBox='0,0,10.2,4.01'>"
        & "<rect width='10.2' height='4.01' fill='#315a7c'/>"
        & "</svg>";
   begin
      Check_Decode
        (Document, True, 11, 5, 2, 2,
         16#31#, 16#5A#, 16#7C#, 16#FF#, True);
   end Viewbox_Ceiling;

   procedure Explicit_Dimensions_Precede_Viewbox
     (T : in out Test)
   is
      pragma Unreferenced (T);
      Document : constant String :=
        "<svg xmlns='http://www.w3.org/2000/svg' "
        & "width='24px' height='12px' viewBox='0 0 240 120'>"
        & "<rect width='240' height='120' fill='#20c060'/>"
        & "</svg>";
   begin
      Check_Decode
        (Document, True, 24, 12, 12, 6,
         16#20#, 16#C0#, 16#60#, 16#FF#, True);
   end Explicit_Dimensions_Precede_Viewbox;

   procedure Transparency_And_Known_Pixels (T : in out Test) is
      pragma Unreferenced (T);
      Document : constant String :=
        "<svg xmlns='http://www.w3.org/2000/svg' "
        & "width='4' height='2' viewBox='0 0 4 2'>"
        & "<rect width='2' height='2' fill='#ff0000'/>"
        & "</svg>";
   begin
      Check_Decode
        (Document, True, 4, 2, 0, 0,
         16#FF#, 0, 0, 16#FF#, True);
      Check_Decode
        (Document, True, 4, 2, 3, 1,
         0, 0, 0, 0, True);
   end Transparency_And_Known_Pixels;

   procedure Gradient_And_Local_Reference (T : in out Test) is
      pragma Unreferenced (T);
      Document : constant String :=
        "<svg xmlns='http://www.w3.org/2000/svg' "
        & "width='8' height='4' viewBox='0 0 8 4'>"
        & "<defs><linearGradient id='g'>"
        & "<stop offset='0' stop-color='#2468ac'/>"
        & "<stop offset='1' stop-color='#2468ac'/>"
        & "</linearGradient></defs>"
        & "<rect width='8' height='4' fill='url(#g)'/>"
        & "<use href='#shape'/>"
        & "<defs><rect id='shape' x='3' y='1' width='2' height='2' "
        & "fill='#2468ac'/></defs></svg>";
   begin
      Check_Decode
        (Document, True, 8, 4, 4, 2,
         16#24#, 16#68#, 16#AC#, 16#FF#, True);
   end Gradient_And_Local_Reference;

   procedure Reject_Unsafe_Inputs (T : in out Test) is
      pragma Unreferenced (T);
      Malformed : constant String :=
        "<svg xmlns='http://www.w3.org/2000/svg'><rect></svg>";
      External : constant String :=
        "<svg xmlns='http://www.w3.org/2000/svg' width='4' height='4'>"
        & "<use href='https://example.invalid/shape.svg#x'/></svg>";
      Script : constant String :=
        "<svg xmlns='http://www.w3.org/2000/svg' width='4' height='4'>"
        & "<script>alert(1)</script></svg>";
      Style_Element : constant String :=
        "<svg xmlns='http://www.w3.org/2000/svg' width='4' height='4'>"
        & "<style>rect { fill: red }</style></svg>";
      Style_Attribute : constant String :=
        "<svg xmlns='http://www.w3.org/2000/svg' width='4' height='4'>"
        & "<rect style='fill:red' width='4' height='4'/></svg>";
      Image : constant String :=
        "<svg xmlns='http://www.w3.org/2000/svg' width='4' height='4'>"
        & "<image href='data:image/png;base64,AAAA' width='4' "
        & "height='4'/></svg>";
      Animation : constant String :=
        "<svg xmlns='http://www.w3.org/2000/svg' width='4' height='4'>"
        & "<animate attributeName='x' from='0' to='1'/></svg>";
      DTD : constant String :=
        "<!DOCTYPE svg [<!ENTITY x SYSTEM "
        & "'file:///etc/passwd'>]><svg xmlns='http://www.w3.org/2000/svg' "
        & "width='4' height='4'><text>&x;</text></svg>";
      Missing_Dimensions : constant String :=
        "<svg xmlns='http://www.w3.org/2000/svg'><rect/></svg>";
   begin
      Check_Decode (Malformed, False);
      Check_Decode (External, False);
      Check_Decode (Script, False);
      Check_Decode (Style_Element, False);
      Check_Decode (Style_Attribute, False);
      Check_Decode (Image, False);
      Check_Decode (Animation, False);
      Check_Decode (DTD, False);
      Check_Decode (Missing_Dimensions, False);
      Check_Decode
        ("<svg xmlns='http://www.w3.org/2000/svg' width='4' height='4'>"
         & "<rect fill='url(file:///tmp/other.svg#paint)'/></svg>", False);
      Check_Decode
        ("<?xml-stylesheet href='other.css'?>"
         & "<svg xmlns='http://www.w3.org/2000/svg' width='4' height='4'/>",
         False);
   end Reject_Unsafe_Inputs;

   procedure Reject_Excessive_Size (T : in out Test) is
      pragma Unreferenced (T);
      Document : constant String :=
        "<svg xmlns='http://www.w3.org/2000/svg' "
        & "width='8193' height='1' viewBox='0 0 8193 1'>"
        & "<rect width='8193' height='1' fill='#ffffff'/></svg>";
   begin
      Check_Decode (Document, False);
   end Reject_Excessive_Size;

   package Caller is new AUnit.Test_Caller (Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test
        (Caller.Create ("Coyote_Canvas.SVG.Decode fixed 96 DPI units",
         Physical_Units'Access));
      Result.Add_Test
        (Caller.Create ("Coyote_Canvas.SVG.Decode viewBox ceiling",
         Viewbox_Ceiling'Access));
      Result.Add_Test
        (Caller.Create ("Coyote_Canvas.SVG.Decode explicit pixel dimensions",
         Explicit_Dimensions_Precede_Viewbox'Access));
      Result.Add_Test
        (Caller.Create ("Coyote_Canvas.SVG.Decode alpha and pixel samples",
         Transparency_And_Known_Pixels'Access));
      Result.Add_Test
        (Caller.Create ("Coyote_Canvas.SVG.Decode local gradient references",
         Gradient_And_Local_Reference'Access));
      Result.Add_Test
        (Caller.Create ("Coyote_Canvas.SVG.Decode unsafe input rejection",
         Reject_Unsafe_Inputs'Access));
      Result.Add_Test
        (Caller.Create ("Coyote_Canvas.SVG.Decode size rejection",
         Reject_Excessive_Size'Access));
      return Result;
   end Suite;
end Coyote_Canvas_SVG_Tests;
