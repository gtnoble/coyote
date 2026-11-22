with AUnit.Assertions; use AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Cairo;
with Cairo.Image_Surface;
with Ada.Streams;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Coyote_Canvas.Composite;
with Coyote_Canvas.Document;
with Coyote_Canvas.Images;
with Coyote_Canvas.Rasters;
with Coyote_Canvas.Revisions;
with Coyote_Canvas.Revisions.Recovery;
with Coyote_Image_Decoder;
with Interfaces.C;
with System;
with System.Address_To_Access_Conversions;
with System.Storage_Elements;


package body Coyote_Canvas_Composite_Tests is
   use Ada.Streams;
   use type Cairo.Cairo_Surface;
   use type System.Address;
   use Coyote_Canvas.Composite;
   use Coyote_Canvas.Document;
   use Coyote_Canvas.Images;
   use Coyote_Canvas.Revisions;

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   type Pixel_Byte is mod 2 ** 8;
   package Byte_Addresses is new
     System.Address_To_Access_Conversions (Pixel_Byte);

   function Raw_Pixels
     (Pixbuf : Coyote_Image_Decoder.Pixbuf_Handle)
      return System.Address
     with Import, Convention => C,
       External_Name => "gdk_pixbuf_get_pixels";

   function Raw_Rowstride
     (Pixbuf : Coyote_Image_Decoder.Pixbuf_Handle)
      return Interfaces.C.int
     with Import, Convention => C,
       External_Name => "gdk_pixbuf_get_rowstride";

   function Byte_At
     (Pixels : System.Address;
      Offset : Natural) return Stream_Element is
      use System.Storage_Elements;
   begin
      return Stream_Element
        (Byte_Addresses.To_Pointer
           (Pixels + Storage_Offset (Offset)).all);
   end Byte_At;

   function Bytes_Of (Item : Image) return Stream_Element_Array is
   begin
      return Pixels (Item);
   end Bytes_Of;

   procedure Check_PNG
     (Data : String; Width, Height : Positive;
      Expected : Stream_Element_Array)
   is
      Decoded : Coyote_Image_Decoder.Pixbuf_Handle :=
        Coyote_Image_Decoder.Null_Pixbuf;
      Got_Width  : Natural;
      Got_Height : Natural;
      Error      : Unbounded_String;
   begin
      Coyote_Canvas.Rasters.Decode
        (Data, Coyote_Canvas.Rasters.PNG, Decoded,
         Got_Width, Got_Height, Error);
      Assert (Length (Error) = 0, "encoded PNG decodes");
      Assert
        (Got_Width = Width and then Got_Height = Height,
         "PNG dimensions match the composite");
      declare
         Stride : constant Natural := Natural (Raw_Rowstride (Decoded));
         Raw    : constant System.Address := Raw_Pixels (Decoded);
      begin
         for Y in 0 .. Height - 1 loop
            for Byte in 0 .. Width * 4 - 1 loop
               Assert
                 (Byte_At (Raw, Y * Stride + Byte) =
                    Expected (Expected'First +
                      Stream_Element_Offset (Y * Width * 4 + Byte)),
                  "PNG preserves every straight-alpha pixel byte");
            end loop;
         end loop;
      end;
      Coyote_Image_Decoder.Release (Decoded);
   exception
      when others =>
         Coyote_Image_Decoder.Release (Decoded);
         raise;
   end Check_PNG;

   procedure Assert_Surface_Equals
     (Actual : Cairo.Cairo_Surface; Expected : Image; Message : String)
   is
      Data : constant System.Address :=
        Cairo.Image_Surface.Get_Data_Generic (Actual);
      Stride : constant Natural :=
        Natural (Cairo.Image_Surface.Get_Stride (Actual));
      Pixels : constant Stream_Element_Array := Bytes_Of (Expected);
   begin
      Assert (Data /= System.Null_Address, Message & " data exists");
      for Y in 0 .. Height (Expected) - 1 loop
         for X in 0 .. Width (Expected) - 1 loop
            declare
               Index : constant Natural := (Y * Stride) + X * 4;
               Offset : constant Natural := (Y * Width (Expected) + X) * 4;
               Alpha : constant Natural :=
                 Natural (Pixels (Pixels'First + Stream_Element_Offset
                   (Offset + 3)));
            begin
               Assert
                 (Byte_At (Data, Index) = Stream_Element
                    ((Natural (Pixels (Pixels'First + Stream_Element_Offset
                      (Offset + 2))) * Alpha + 127) / 255),
                  Message & " blue premultiplication");
               Assert
                 (Byte_At (Data, Index + 1) = Stream_Element
                    ((Natural (Pixels (Pixels'First + Stream_Element_Offset
                      (Offset + 1))) * Alpha + 127) / 255),
                  Message & " green premultiplication");
               Assert
                 (Byte_At (Data, Index + 2) = Stream_Element
                    ((Natural (Pixels (Pixels'First + Stream_Element_Offset
                      (Offset))) * Alpha + 127) / 255),
                  Message & " red premultiplication");
               Assert (Byte_At (Data, Index + 3) = Stream_Element (Alpha),
                       Message & " alpha");
            end;
         end loop;
      end loop;
   end Assert_Surface_Equals;

   procedure Erase_Preview_Incremental (T : in out Test) is
      pragma Unreferenced (T);
      W : Workspace;
      Original : Revision_Id;
      Source : Stream_Element_Array (1 .. 10 * 8 * 4);
      Paint, Eraser : Samples.Vector;
      Preview : Erase_Preview;
      Canonical : Image;
      First_Point : constant Sample := (1.4, 2.2, 3.5);
      Second_Point : constant Sample := (6.9, 3.6, 4.0);
      Third_Point : constant Sample := (6.0, 5.8, 2.7);
   begin
      for I in Source'Range loop
         Source (I) := (if I mod 12 = 0 then 0
                        else Stream_Element ((I * 17) mod 251));
      end loop;
      Add_Originals (W, (1 => (10, 8)), Original);
      Edit (W, Original);
      Paint.Append ((0.5, 3.0, 3.8));
      Paint.Append ((8.8, 3.0, 4.2));
      Add_Stroke (W, Paint, Color => 16#E0_20_40#);
      declare
         Overlap : Samples.Vector;
      begin
         Overlap.Append ((3.0, 3.1, 2.8));
         Overlap.Append ((7.0, 3.4, 2.8));
         Add_Stroke (W, Overlap, Color => 16#20_70_E0#);
      end;
      Crop (W, (2, 1, 9, 7));
      Save (W);
      Original := Base (W);
      Render (W, Original, Source, 40, True, Canonical);
      Check_Colored_PNG : declare
         Actual : constant Stream_Element_Array := Pixels (Canonical);
         Offset : constant Stream_Element_Offset := 4 * (2 * 7 + 2) + 1;
      begin
         Assert (Actual (Offset .. Offset + 3) = (32, 112, 224, 255),
                 "Last opaque stroke supplies the overlap color");
         Check_PNG (To_String (Encode_PNG (Canonical)), 7, 6, Actual);
      end Check_Colored_PNG;
      Eraser.Append (First_Point);
      Update_Erase (Preview, W, Original, Eraser, Source, 40, True);
      Add_Stroke (W, Eraser, Erase);
      Render (W, NO_REVISION, Source, 40, True, Canonical);
      Assert_Surface_Equals (Surface (Preview), Canonical,
                             "first incremental erase matches canonical");

      Eraser.Append (Second_Point);
      Update_Erase (Preview, W, Original, Eraser, Source, 40, True);
      Undo (W);
      Add_Stroke (W, Eraser, Erase);
      Render (W, NO_REVISION, Source, 40, True, Canonical);
      Assert_Surface_Equals (Surface (Preview), Canonical,
                             "second incremental erase matches canonical");

      Eraser.Append (Third_Point);
      Update_Erase (Preview, W, Original, Eraser, Source, 40, True);
      Undo (W);
      Add_Stroke (W, Eraser, Erase);
      Render (W, NO_REVISION, Source, 40, True, Canonical);
      Assert_Surface_Equals (Surface (Preview), Canonical,
                             "third overlapping erase matches canonical");
      Update_Erase (Preview, W, Original, Eraser, Source, 40, True);
      Assert_Surface_Equals (Surface (Preview), Canonical,
                             "redraw does not reapply existing samples");
      Clear (Preview);
      Assert (Surface (Preview) = Cairo.Null_Surface,
              "clear releases preview surface");
      Update_Erase (Preview, W, Original, Eraser, Source, 40, True);
      Assert_Surface_Equals (Surface (Preview), Canonical,
                             "batched first frame matches canonical");
   end Erase_Preview_Incremental;

   procedure Blank_And_Imported_Bytes (T : in out Test) is
      pragma Unreferenced (T);
      W        : Workspace;
      Blank_W  : Workspace;
      Blank    : Image;
      Imported : Image;
      Original : Revision_Id;
      Blank_Id : Revision_Id;
      Sizes    : constant Image_Sizes :=
        (1 => (Width => 2, Height => 2));
      Source  : constant Stream_Element_Array (-5 .. 10) :=
        (10, 20, 30, 255, 201, 51, 79, 0,
         202, 21, 15, 1, 91, 92, 17, 27);
      Expected : constant Stream_Element_Array :=
        (10, 20, 30, 255, 201, 51, 79, 0,
         202, 21, 15, 1, 91, 92, 17, 27);
      Encoded : Unbounded_String;
   begin
      New_Drawing (Blank_W, 2, 2);
      Save (Blank_W);
      Blank_Id := Base (Blank_W);
      Render (Blank_W, Blank_Id, Blank);
      Assert (Width (Blank) = 2 and then Height (Blank) = 2,
              "blank retains its native dimensions");
      Add_Originals (W, Sizes, Original);
      Assert
        (Bytes_Of (Blank) =
           (255, 255, 255, 255, 255, 255, 255, 255,
            255, 255, 255, 255, 255, 255, 255, 255),
         "blank Original renders solid white");

      Render (W, Original, Source, 8, True, Imported);
      Assert (Bytes_Of (Imported) = Expected,
              "offset RGBA source retains hidden and low-alpha RGB");
      Encoded := Encode_PNG (Imported);
      Check_PNG (To_String (Encoded), 2, 2, Expected);
   end Blank_And_Imported_Bytes;

   procedure RGB_Stride_And_Offset (T : in out Test) is
      pragma Unreferenced (T);
      W        : Workspace;
      Original : Revision_Id;
      Sizes    : constant Image_Sizes :=
        (1 => (Width => 2, Height => 2));
      Source   : constant Stream_Element_Array (17 .. 32) :=
        (31, 41, 51, 61, 62, 71, 72, 81,
         91, 101, 111, 121, 131, 141, 151, 161);
      Result   : Image;
   begin
      Add_Originals (W, Sizes, Original);
      Render (W, Original, Source, 7, False, Result);
      Assert
        (Bytes_Of (Result) =
           (31, 41, 51, 255, 61, 62, 71, 255,
            81, 91, 101, 255, 111, 121, 131, 255),
         "RGB rows honor padded stride and receive opaque alpha");
   end RGB_Stride_And_Offset;

   procedure Crop_And_History (T : in out Test) is
      pragma Unreferenced (T);
      W          : Workspace;
      Original   : Revision_Id;
      Sizes      : constant Image_Sizes :=
        (1 => (Width => 8, Height => 7));
      Source     : Stream_Element_Array (1 .. 8 * 7 * 4);
      Full       : Image;
      Nested     : Image;
      Restored   : Image;
      Parent_Expected : Stream_Element_Array (1 .. 6 * 5 * 4);
      Nested_Expected : Stream_Element_Array (1 .. 3 * 4 * 4);
      Has_Coverage    : Boolean := False;
      Has_Ink         : Boolean := False;
      Background_Crop : Stream_Element_Array (1 .. 3 * 4 * 4);
   begin
      for Index in 0 .. 6 loop
         for X in 0 .. 7 loop
            declare
               Offset : constant Natural := (Index * 8 + X) * 4;
            begin
               Source (Stream_Element_Offset (Offset + 1)) :=
                 Stream_Element (X * 17 + Index);
               Source (Stream_Element_Offset (Offset + 2)) :=
                 Stream_Element (Index * 19 + X);
               Source (Stream_Element_Offset (Offset + 3)) :=
                 Stream_Element (X + Index * 3);
               Source (Stream_Element_Offset (Offset + 4)) := 0;
            end;
         end loop;
      end loop;
      Add_Originals (W, Sizes, Original);
      Render (W, Original, Source, 32, True, Full);
      Copy_RGBA
        (Bytes_Of (Full), 8, 7, 32, (3, 2, 6, 6), Background_Crop);

      Edit (W, Original);
      declare
         Stroke : Samples.Vector;
      begin
         Stroke.Append ((X => 0.35, Y => 2.4, Width => 2.5));
         Stroke.Append ((X => 7.7, Y => 3.4, Width => 4.0));
         Add_Stroke (W, Stroke);
         Save (W);
      end;
      Render (W, Base (W), Source, 32, True, Full);
      Crop (W, (1, 1, 7, 6));
      Crop (W, (2, 1, 5, 5));
      Undo (W);
      Redo (W);
      Save (W);
      Render (W, Base (W), Source, 32, True, Nested);
      Copy_RGBA
        (Bytes_Of (Full), 8, 7, 32, (3, 2, 6, 6), Nested_Expected);
      Assert (Width (Nested) = 3 and then Height (Nested) = 4
              and then Bytes_Of (Nested) = Nested_Expected,
              "nested crop preserves every source-grid byte");
      Check_PNG (To_String (Encode_PNG (Nested)), 3, 4, Nested_Expected);
      for Pixel in 0 .. 3 * 4 - 1 loop
         declare
            Alpha : constant Stream_Element :=
              Nested_Expected (Stream_Element_Offset (4 * Pixel + 4));
         begin
            Has_Coverage := Has_Coverage or else Alpha in 1 .. 254;
         end;
      end loop;
      Assert (Has_Coverage, "comparison crop includes partial alpha");
      for Index in Nested_Expected'Range loop
         Has_Ink := Has_Ink or else
           Nested_Expected (Index) /= Background_Crop (Index);
      end loop;
      Assert (Has_Ink, "comparison crop includes rendered stroke coverage");

      Undo (W);
      Render (W, NO_REVISION, Source, 32, True, Restored);
      Copy_RGBA
        (Bytes_Of (Full), 8, 7, 32, (1, 1, 7, 6), Parent_Expected);
      Assert (Bytes_Of (Restored) = Parent_Expected,
              "undo restores the prior crop pixel grid");
      Redo (W);
      Render (W, NO_REVISION, Source, 32, True, Nested);
      Copy_RGBA
        (Bytes_Of (Full), 8, 7, 32, (3, 2, 6, 6), Nested_Expected);
      Assert (Bytes_Of (Nested) = Nested_Expected,
              "redo restores nested crop pixel grid");
   end Crop_And_History;

   procedure Erase_Ink (T : in out Test) is
      pragma Unreferenced (T);
      package Recovery renames Coyote_Canvas.Revisions.Recovery;
      W, Restored, Forked : Workspace;
      Original, Before, After : Revision_Id;
      Stroke, Eraser : Samples.Vector;
      Source : Stream_Element_Array (1 .. 12 * 8 * 4);
      Painted, Erased, Actual : Image;
      Mapping : Recovery.Revision_Mapping;
      Rejected : Boolean := False;
      Left : constant Stream_Element_Offset := (4 * 12 + 2) * 4 + 1;
      Right : constant Stream_Element_Offset := (4 * 12 + 9) * 4 + 1;
   begin
      for I in Source'Range loop
         Source (I) := (if I mod 4 = 0 then 0 else Stream_Element (I mod 199));
      end loop;
      Add_Originals (W, (1 => (12, 8)), Original);
      Edit (W, Original);
      Stroke.Append ((2.5, 4.5, 3.0));
      Stroke.Append ((9.5, 4.5, 3.0));
      Add_Stroke (W, Stroke);
      Save (W);
      Before := Base (W);
      Render (W, Before, Source, 48, True, Painted);
      Eraser.Append ((2.5, 4.5, 5.0));
      Add_Stroke (W, Eraser, Erase);
      Render (W, NO_REVISION, Source, 48, True, Erased);
      Assert (Pixels (Erased) (Left .. Left + 3) = Source (Left .. Left + 3),
              "erase restores all four source bytes including hidden RGB");
      Assert (Pixels (Erased) (Right .. Right + 3) =
                Pixels (Painted) (Right .. Right + 3),
              "uncovered ink remains bit-exact");
      Undo (W);
      Render (W, NO_REVISION, Source, 48, True, Actual);
      Assert (Pixels (Actual) = Pixels (Painted), "undo restores prior ink");
      Redo (W);
      Render (W, NO_REVISION, Source, 48, True, Actual);
      Assert (Pixels (Actual) = Pixels (Erased), "redo restores erasure");
      Save (W);
      After := Base (W);
      Assert (Parent (W, After) = Before, "erase checkpoint is a child");
      Render (W, Before, Source, 48, True, Actual);
      Assert (Pixels (Actual) = Pixels (Painted), "parent remains immutable");
      Recovery.Decode (Recovery.Encode (W), Restored);
      Render (Restored, After, Source, 48, True, Actual);
      Assert (Pixels (Actual) = Pixels (Erased), "recovery preserves erasure");
      Recovery.Select_Revisions
        (Restored, (1 => (Drawing_Key (W, After), Revision_Key (W, After))),
         Forked, Mapping);
      Render (Forked, Base (Forked), Source, 48, True, Actual);
      Assert (Pixels (Actual) = Pixels (Erased), "fork preserves erasure");
      Check_PNG (To_String (Encode_PNG (Actual)), 12, 8, Pixels (Erased));
      declare
         Cropped : Stream_Element_Array (1 .. 7 * 5 * 4);
      begin
         Crop (W, (2, 1, 9, 6));
         Render (W, NO_REVISION, Source, 48, True, Actual);
         Copy_RGBA (Pixels (Erased), 12, 8, 48, (2, 1, 9, 6), Cropped);
         Assert (Pixels (Actual) = Cropped, "crop keeps erase edge phase");
      end;
      Add_Stroke (W, Eraser);
      Render (W, NO_REVISION, Source, 48, True, Actual);
      Undo (W);
      Render (W, NO_REVISION, Source, 48, True, Erased);
      Assert (Pixels (Actual) /= Pixels (Erased), "paint after erase remains");
      declare
         Text : String := Recovery.Encode (W);
      begin
         for I in Text'First .. Text'Last - 10 loop
            if Text (I .. I + 10) = """version"":3" then
               Text (I + 10) := '2';
               exit;
            end if;
         end loop;
         begin
            Recovery.Decode (Text, Restored);
         exception
            when Recovery.Invalid_Snapshot => Rejected := True;
         end;
      end;
      Assert (Rejected, "legacy v2 must reject an erase marker");
   end Erase_Ink;

   procedure Partial_Alpha_Source_Over (T : in out Test) is
      pragma Unreferenced (T);
      W          : Workspace;
      Original   : Revision_Id;
      Sizes      : constant Image_Sizes := (1 => (6, 5));
      Clear_Ink  : Image;
      Combined   : Image;
      Stroke     : Samples.Vector;
      Background : Stream_Element_Array (1 .. 6 * 5 * 4);
      Partial    : Boolean := False;
   begin
      Add_Originals (W, Sizes, Original);
      Edit (W, Original);
      Stroke.Append ((2.6, 2.25, 2.7));
      Add_Stroke (W, Stroke);
      Background := (others => 0);
      Render (W, NO_REVISION, Background, 24, True, Clear_Ink);
      for P in 0 .. 6 * 5 - 1 loop
         Background (Stream_Element_Offset (4 * P + 1) ..
                     Stream_Element_Offset (4 * P + 4)) := (48, 141, 220, 93);
      end loop;
      Render (W, NO_REVISION, Background, 24, True, Combined);
      declare
         Ink_Only : constant Stream_Element_Array := Pixels (Clear_Ink);
         Actual   : constant Stream_Element_Array := Pixels (Combined);
      begin
         for P in 0 .. 6 * 5 - 1 loop
            declare
               Start   : constant Stream_Element_Offset :=
                 Stream_Element_Offset (4 * P + 1);
               Mask    : constant Stream_Element := Ink_Only (Start + 3);
               A_Ink   : constant Long_Float := Long_Float (Mask) / 255.0;
               A_Back  : constant Long_Float := (93.0 / 255.0) * (1.0 - A_Ink);
               A_Total : constant Long_Float := A_Ink + A_Back;
            begin
               Partial := Partial or else Mask in 1 .. 254;
               Assert (Actual (Start + 3) = Stream_Element (A_Total * 255.0),
                       "source-over uses combined coverage for alpha");
               for J in Start .. Start + 2 loop
                  declare
                     Expected : constant Integer := Integer
                       ((13.0 * A_Ink +
                         Long_Float (Background (J)) * A_Back) / A_Total);
                  begin
                     Assert
                       (abs (Integer (Actual (J)) - Expected) <= 1,
                        "source-over color differs by at most one channel");
                  end;
               end loop;
            end;
         end loop;
      end;
      Assert (Partial, "rounding fixture exercises partial ink coverage");
   end Partial_Alpha_Source_Over;

   procedure Rejects_Preserve_Result (T : in out Test) is
      pragma Unreferenced (T);
      W          : Workspace;
      Original   : Revision_Id;
      Sizes      : constant Image_Sizes :=
        (1 => (Width => 2, Height => 2));
      Valid      : constant Stream_Element_Array (1 .. 16) :=
        (others => 77);
      Too_Short  : constant Stream_Element_Array (1 .. 15) :=
        (others => 1);
      Result     : Image;
      Before     : Stream_Element_Array (1 .. 16);
      Rejected   : Boolean;
   begin
      Add_Originals (W, Sizes, Original);
      Render (W, Original, Valid, 8, True, Result);
      Before := Bytes_Of (Result);
      Rejected := False;
      begin
         Render (W, Original, Too_Short, 8, True, Result);
      exception
         when Invalid_Buffer => Rejected := True;
      end;
      Assert (Rejected, "truncated source raises Invalid_Buffer");
      Assert (Bytes_Of (Result) = Before,
              "failed render does not replace prior image");

      Rejected := False;
      begin
         Render (W, Original, Valid, 7, True, Result);
      exception
         when Invalid_Buffer => Rejected := True;
      end;
      Assert (Rejected, "short source stride raises Invalid_Buffer");
      Assert (Bytes_Of (Result) = Before,
              "invalid stride preserves prior image");

      Rejected := False;
      begin
         Render (W, Original, Valid, 5, False, Result);
      exception
         when Invalid_Buffer => Rejected := True;
      end;
      Assert (Rejected, "mismatched RGB layout raises Invalid_Buffer");
      Assert (Bytes_Of (Result) = Before,
              "layout rejection preserves prior image");

      Render (W, Original, Valid, 8, True, Result, False);
      Assert (Bytes_Of (Result) = Before,
              "valid Include_Ink false render retains imported pixels");

      declare
         Blank_Workspace : Workspace;
         Blank_Id        : Revision_Id;
      begin
         New_Drawing (Blank_Workspace, 2, 2);
         Save (Blank_Workspace);
         Blank_Id := Base (Blank_Workspace);
         Render (Blank_Workspace, Blank_Id, Result);
         Before := Bytes_Of (Result);
         Rejected := False;
         begin
            Render
              (Blank_Workspace, Blank_Id, Valid, 8, True, Result);
         exception
            when Invalid_Buffer => Rejected := True;
         end;
         Assert (Rejected, "imported source rejected for blank Original");
         Assert (Bytes_Of (Result) = Before,
                 "kind rejection preserves blank image result");
      end;
   end Rejects_Preserve_Result;

   procedure PNG_Limits (T : in out Test) is
      pragma Unreferenced (T);
      W        : Workspace;
      Original : Revision_Id;
      Sizes    : constant Image_Sizes :=
        (1 => (Width => 1, Height => 1));
      Source   : constant Stream_Element_Array (1 .. 4) :=
        (12, 34, 56, 255);
      Result   : Image;
      Data     : Unbounded_String;
      Rejected : Boolean := False;
   begin
      Add_Originals (W, Sizes, Original);
      Render (W, Original, Source, 4, True, Result);
      Data := Encode_PNG (Result);
      Assert (Length (Data) > 1, "one-pixel PNG has encoded bytes");
      begin
         declare
            Too_Small : constant Unbounded_String :=
              Encode_PNG (Result, Positive (Length (Data) - 1));
         begin
            if Length (Too_Small) > 0 then
               Assert (False, "PNG cap below exact size was accepted");
            end if;
         end;
      exception
         when PNG_Limit_Error => Rejected := True;
      end;
      Assert (Rejected, "PNG limit exception is raised below exact size");
      Assert
        (Length (Encode_PNG (Result, Positive (Length (Data)))) =
           Length (Data),
         "PNG succeeds at its exact byte limit");
   end PNG_Limits;

   procedure Empty_And_Invalid (T : in out Test) is
      pragma Unreferenced (T);
      Empty : Image;
      Data  : Unbounded_String;
      W     : Workspace;
      Rejected : Boolean := False;
   begin
      Assert (Width (Empty) = 0 and then Height (Empty) = 0,
              "default image is empty");
      begin
         Data := Encode_PNG (Empty);
      exception
         when Invalid_Buffer => Rejected := True;
      end;
      Assert (Rejected, "PNG encode rejects an empty image");

      Rejected := False;
      begin
         Render (W, NO_REVISION, Empty);
      exception
         when Invalid_Buffer => Rejected := True;
      end;
      Assert (Rejected, "render rejects a nonexistent revision");
   end Empty_And_Invalid;

   package Caller is new AUnit.Test_Caller (Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (Caller.Create
        ("Canvas composite blank and exact PNG bytes",
         Blank_And_Imported_Bytes'Access));
      Result.Add_Test (Caller.Create
        ("Canvas composite RGB stride and buffer offset",
         RGB_Stride_And_Offset'Access));
      Result.Add_Test (Caller.Create
        ("Canvas composite crop grid and history",
         Crop_And_History'Access));
      Result.Add_Test (Caller.Create
        ("Canvas composite erases ink only across recovery and forks",
         Erase_Ink'Access));
      Result.Add_Test (Caller.Create
        ("Canvas composite incremental erase preview",
         Erase_Preview_Incremental'Access));
      Result.Add_Test (Caller.Create
        ("Canvas composite partial-alpha source-over",
         Partial_Alpha_Source_Over'Access));
      Result.Add_Test (Caller.Create
        ("Canvas composite rejects invalid buffers atomically",
         Rejects_Preserve_Result'Access));
      Result.Add_Test (Caller.Create
        ("Canvas composite PNG output limits",
         PNG_Limits'Access));
      Result.Add_Test (Caller.Create
        ("Canvas composite empty and invalid extents",
         Empty_And_Invalid'Access));
      return Result;
   end Suite;
end Coyote_Canvas_Composite_Tests;
