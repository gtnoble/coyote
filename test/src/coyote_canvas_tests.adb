with AUnit.Assertions; use AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Ada.Streams; use Ada.Streams;
with Coyote_Canvas.Document;
with Coyote_Canvas.Images;

package body Coyote_Canvas_Tests is

   use Coyote_Canvas.Document;
   use Coyote_Canvas.Images;

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Exact_Entry (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (From_Fields (8, 6, 1, 1, 9, 7) = (8, 6, 9, 7),
              "last pixel is included");
      Assert (From_Fields (0, 0, 9, 7, 9, 7) = Full_Extent (9, 7),
              "full extent is valid");
      Assert (From_Fields (-1, 0, 1, 1, 9, 7) = EMPTY_RECTANGLE,
              "negative field is not clamped");
      Assert (From_Fields (0, 0, 0, 1, 9, 7) = EMPTY_RECTANGLE,
              "zero width is rejected");
      Assert (From_Fields (0, 7, 1, 1, 9, 7) = EMPTY_RECTANGLE,
              "one row beyond bounds is rejected");
      Assert
        (From_Fields (Integer'Last, 0, 7, 1, 9, 7) = EMPTY_RECTANGLE,
         "extreme numeric input does not add overflowing edges");
   end Exact_Entry;

   procedure Drag_And_Move (T : in out Test) is
      pragma Unreferenced (T);
      Region : constant Rectangle := (1, 2, 5, 6);
   begin
      Assert (From_Drag (4.5, 5.5, 0.5, 1.5, 9, 7) = Region,
              "reverse drag rounds ties to larger coordinates");
      Assert (From_Drag (-10.0, 99.0, 20.0, -2.0, 9, 7) = (0, 0, 9, 7),
              "drag clamps to image edges");
      Assert (From_Drag (0.4, 0.0, 0.0, 1.0, 9, 7) = EMPTY_RECTANGLE,
              "subpixel collapsed drag is empty");
      Assert (Move (Region, -5, Integer'Last, 9, 7) = (0, 3, 4, 7),
              "move clamps without changing dimensions");
      Assert (Move ((0, 0, 10, 6), 0, 0, 9, 7) = EMPTY_RECTANGLE,
              "move does not salvage an invalid region");
   end Drag_And_Move;

   procedure Source_Phase (T : in out Test) is
      pragma Unreferenced (T);
      Current : constant Rectangle := (3, 2, 9, 7);
   begin
      Assert (Source_Extent (Current, (0, 0, 6, 5)) = Current,
              "identity crop preserves source extent");
      Assert (Source_Extent (Current, (2, 1, 6, 5)) = (5, 3, 9, 7),
              "nested crop retains original source coordinates");
      Assert (Source_Extent (Current, (2, 1, 7, 5)) = EMPTY_RECTANGLE,
              "crop cannot recover excluded pixels");
      Assert (Source_Extent (EMPTY_RECTANGLE, Current) = EMPTY_RECTANGLE,
              "invalid current extent is rejected");
   end Source_Phase;

   --  Two distinct rows, with padding only after the first. Include
   --  nonzero RGB under zero alpha and low-alpha colors.
   Fixture : constant Stream_Element_Array (-3 .. 22) :=
     (10, 20, 30, 255, 201, 51, 79, 0, 202, 21, 15, 1,
      99, 98,
      17, 27, 37, 5, 12, 31, 48, 77, 255, 17, 0, 240);

   procedure Exact_Pixels (T : in out Test) is
      pragma Unreferenced (T);
      Output : Stream_Element_Array (9 .. 24);
      Final_Pixel : Stream_Element_Array (0 .. 3);
   begin
      Assert (Packed_Byte_Count (2, 2) = 16, "RGBA is tightly packed");
      Copy_RGBA (Fixture, 3, 2, 14, (1, 0, 3, 2), Output);
      Assert
        (Output = (201, 51, 79, 0, 202, 21, 15, 1,
                   12, 31, 48, 77, 255, 17, 0, 240),
         "all RGBA bytes retained with stride and nonstandard bounds");
      Copy_RGBA (Fixture, 3, 2, 14, (2, 1, 3, 2), Final_Pixel);
      Assert (Final_Pixel = (255, 17, 0, 240), "last pixel at both edges");
   end Exact_Pixels;

   procedure Bad_Sizes (T : in out Test) is
      pragma Unreferenced (T);
      Output : Stream_Element_Array (0 .. 3);

      procedure Reject
        (Bytes : Stream_Element_Array;
         Stride : Positive;
         Region : Rectangle;
         Why    : String)
      is
      begin
         Copy_RGBA (Bytes, 3, 2, Stride, Region, Output);
         Assert (False, Why);
      exception
         when Invalid_Buffer => null;
      end Reject;

      procedure Reject_Count (Width, Height : Positive) is
      begin
         Assert
           (False, "unexpected packed size"
            & Positive'Image (Packed_Byte_Count (Width, Height)));
      exception
         when Invalid_Buffer => null;
      end Reject_Count;
   begin
      Reject (Fixture, 11, (0, 0, 1, 1), "short stride accepted");
      Reject (Fixture, 14, (0, 0, 2, 1), "wrong destination size accepted");
      Reject (Fixture, 14, (3, 0, 4, 1), "out-of-bounds region accepted");
      Reject (Fixture, 14, EMPTY_RECTANGLE, "empty crop accepted");
      Reject (Fixture (-3 .. 21), 14, (0, 0, 1, 1), "truncation accepted");
      Reject (Fixture, Positive'Last, (0, 0, 1, 1),
              "overflowing stride accepted");
      Reject_Count (Positive'Last, 1);
      Reject_Count (2, Positive'Last);
   end Bad_Sizes;

   package Caller is new AUnit.Test_Caller (Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (Caller.Create
        ("Coyote.Canvas exact crop fields", Exact_Entry'Access));
      Result.Add_Test (Caller.Create
        ("Coyote.Canvas pointer crop and move", Drag_And_Move'Access));
      Result.Add_Test (Caller.Create
        ("Coyote.Canvas nested source extents", Source_Phase'Access));
      Result.Add_Test (Caller.Create
        ("Coyote.Canvas exact RGBA crop", Exact_Pixels'Access));
      Result.Add_Test (Caller.Create
        ("Coyote.Canvas rejects invalid RGBA buffers", Bad_Sizes'Access));
      return Result;
   end Suite;

end Coyote_Canvas_Tests;
