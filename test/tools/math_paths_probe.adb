with Ada.Command_Line;
with Ada.Text_IO;
with Math_Paths;
with Math_Stretchy;

use type Math_Paths.Command_Kind;
use type Math_Paths.Path;
use type Math_Stretchy.Part_Align;

procedure Math_Paths_Probe is
   Checks : Natural := 0;
   Failures : Natural := 0;

   procedure Check (Condition : Boolean; Name : String) is
   begin
      Checks := Checks + 1;
      if not Condition then
         Failures := Failures + 1;
         Ada.Text_IO.Put_Line ("FAIL " & Name);
      end if;
   end Check;

   procedure Expect_Valid (Data : String; Name : String) is
      Item : constant Math_Paths.Path := Math_Paths.Parse (Data);
   begin
      Check (Math_Paths.Is_Valid (Item), Name);
   end Expect_Valid;

   procedure Reject (Data : String; Name : String) is
      Item : constant Math_Paths.Path := Math_Paths.Parse (Data);
   begin
      Check (not Math_Paths.Is_Valid (Item), Name);
   end Reject;

   Item : Math_Paths.Path;
   Box : Math_Paths.Bounds;
   Moved : Math_Paths.Path;
   Invalid_Transform : Math_Paths.Path;
   Long_Input : String (1 .. 40_000) := (others => ' ');
   Overflow_Input : String (1 .. 32_770) := (others => ' ');
   Kata_Path : constant String :=
     "M95,622 c-2.7,0,-7.17,-2.7,-13.5,-8c-5.8,-5.3,-9.5,-10,-9.5,-14" &
     "c0,-2,0.3,-3.3,1,-4c1.3,-2.7,23.83,-20.7,67.5,-54" &
     "c44.2,-33.3,65.8,-50.3,66.5,-51c1.3,-1.3,3,-2,5,-2c4.7,0,8.7,3.3,12,10" &
     "s173,378,173,378c0.7,0,35.3,-71,104,-213c68.7,-142,137.5,-285,206.5,-429" &
     "c69,-144,104.5,-217.7,106.5,-221l0 -0c5.3,-9.3,12,-14,20,-14" &
     "H400000v40H845.2724s-225.272,467,-225.272,467" &
     "s-235,486,-235,486c-2.7,4.7,-9,7,-19,7c-6,0,-10,-1,-12,-3" &
     "s-194,-422,-194,-422s-65,47,-65,47zM834 0h400000v40h-400000z";
begin
   Expect_Valid ("M0 0 L10 10", "absolute line");
   Expect_Valid ("m1 2 3 4 5 6", "repeated relative moveto");
   Expect_Valid ("M.5 -.25", "leading decimal");
   Expect_Valid ("M1. 2.", "trailing decimal");
   Expect_Valid ("M1e2 -2E-1", "exponents");
   Expect_Valid ("M0 0H2h3V4v-1", "horizontal vertical");
   Expect_Valid ("M0,0L1,1Z", "comma close");
   Expect_Valid ("M0 0C1 2 3 4 5 6", "absolute cubic");
   Expect_Valid ("m1 2c3 4 5 6 7 8", "relative cubic");
   Expect_Valid ("M0 0C1 2 3 4 5 6S8 9 10 11", "smooth cubic");
   Expect_Valid ("M0 0Q3 6 6 0", "quadratic");
   Expect_Valid ("M0 0q3 6 6 0", "relative quadratic");
   Expect_Valid ("M0 0Q3 6 6 0T12 0", "smooth quadratic");
   Expect_Valid ("M0 0L1 1m2 2l3 3", "multiple subpaths");
   Expect_Valid ("M0 0C1 2 3 4 5 6z", "closed cubic");
   Expect_Valid ("M0 0S1 2 3 4", "initial smooth cubic");
   Expect_Valid ("M0 0T2 3", "initial smooth quadratic");
   Expect_Valid ("M0 0L1e-3 2e+2", "signed exponent");
   Expect_Valid ("M0 0L1-2", "implicit sign separator");
   Expect_Valid ("M0 0L1.5.25", "adjacent decimals");
   Expect_Valid ("m0 0h1v2z", "relative polyline");
   Expect_Valid ("M0 0L1 2L3 4", "repeated line pairs");
   Expect_Valid ("M0 0C1 2 3 4 5 6c1 1 2 2 3 3", "repeated cubic");
   Expect_Valid ("M0 0Q1 2 3 4q1 1 2 2", "repeated quadratic");
   Expect_Valid ("M0 0L1 1Z M2 2L3 3", "close then move");
   Expect_Valid ("M0 0L1 1z", "lowercase close");
   Expect_Valid ("M0 0L1 1S2 3 4 5", "smooth after line");
   Expect_Valid ("M0 0Q1 2 3 4L4 5T6 7", "smooth reset");
   Expect_Valid ("M0 0L+1 +2", "explicit positive");
   Expect_Valid ("M0 0L1e-200 2", "small finite exponent");
   Expect_Valid ("M0 0L1e6 2", "large finite exponent");
   Expect_Valid (Kata_Path, "pinned KaTeX sqrtMain path");
   Check (Math_Paths.Count (Math_Paths.Parse (Kata_Path)) > 20,
     "KaTeX sqrt path normalized segments");
   Check (Math_Paths.Error (Math_Paths.Parse (Kata_Path)) = "",
     "valid path has empty diagnostic");
   Check (Math_Paths.Error (Math_Paths.Parse ("M0")) /= "",
     "invalid path has diagnostic");
   Reject ("M0 0,,L1 2", "duplicate comma");
   Reject ("M0 0,L1 2", "comma before command");
   Reject ("M0 0L1 2,", "trailing comma");

   Reject ("", "empty");
   Reject ("A1 2 3 4 5 6 7", "arc unsupported");
   Reject ("M0 0A1 2 3 4 5 6 7", "inline arc unsupported");
   Reject ("M0", "truncated move");
   Reject ("M0 0L1", "truncated line");
   Reject ("M0 0C1 2 3 4", "truncated cubic");
   Reject ("M0 0Q1 2", "truncated quadratic");
   Reject ("M0 0LNaN 1", "NaN");
   Reject ("M0 0LInfinity 1", "infinity");
   Reject ("M0 0L1e9999 2", "huge exponent");
   Reject ("M0 0L1e 2", "truncated exponent");
   Reject ("M0 0L1..2 3", "bad decimal");
   Reject ("M0 0R1 2", "unknown command");
   Reject ("M0 0L1000001 1", "coordinate cap");
   Reject ("M0 0L1 2 3", "extra coordinate");
   Reject ("M0 0L", "missing pair");
   Reject ("M0 0L1 2 A", "arc unsupported after line");
   Reject ("M0 0Q1 2T", "truncated smooth quadratic");
   Reject ("M0 0S1 2", "truncated smooth cubic");

   Item := Math_Paths.Parse ("M0 0Q3 6 6 0");
   Check (Math_Paths.Count (Item) = 2, "quadratic normalized to cubic");
   Check (Math_Paths.Element (Item, 2).Kind = Math_Paths.Cubic_To,
     "cubic segment enum");
   Box := Math_Paths.Extent (Item);
   Check (Box.Valid and Box.Min_X = 0.0 and Box.Max_X = 6.0,
     "path bounds endpoints and controls");
   Check (Box.Max_Y >= 4.0, "conservative control bound");
   Moved := Math_Paths.Transform
     (Item, 2.0, 0.0, 0.0, 3.0, 4.0, -1.0);
   Box := Math_Paths.Extent (Moved);
   Check (Box.Min_X = 4.0 and Box.Max_X = 16.0,
     "affine transformed bounds");
   Check (Box.Min_Y = -1.0 and Box.Max_Y = 11.0,
     "affine transformed vertical bounds");
   Check (not Math_Paths.Is_Valid
     (Math_Paths.Transform (Item, 0.0, 0.0, 0.0, 0.0, 1.0e308, 0.0)),
     "out of range transformed path");
   Invalid_Transform := Math_Paths.Transform
     (Item, 1.0e308, 0.0, 0.0, 1.0, 0.0, 0.0);
   Check (not Math_Paths.Is_Valid (Invalid_Transform),
     "non-finite-range transform coefficient rejected");
   Invalid_Transform := Math_Paths.Transform
     (Math_Paths.Parse ("M0 0L999999 0"), 2.0, 0.0, 0.0, 1.0, 0.0, 0.0);
   Check (not Math_Paths.Is_Valid (Invalid_Transform) and then
     Math_Paths.Count (Invalid_Transform) = 0,
     "late transform failure returns no partial path");

   Long_Input (1 .. 2) := "M0";
   Long_Input (3 .. Long_Input'Last) := (others => ' ');
   Reject (Long_Input, "oversized input safely rejected");
   Overflow_Input (1 .. 2) := "M0";
   for I in 1 .. 16_384 loop
      Overflow_Input (I * 2 - 1 .. I * 2) := "L0";
   end loop;
   Reject (Overflow_Input, "oversized command stream");

   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("doubleleftarrow")),
     "stretchy geometry doubleleftarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("doublerightarrow")),
     "stretchy geometry doublerightarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("leftarrow")),
     "stretchy geometry leftarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("leftbrace")),
     "stretchy geometry leftbrace");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("leftbraceunder")),
     "stretchy geometry leftbraceunder");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("leftgroup")),
     "stretchy geometry leftgroup");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("leftgroupunder")),
     "stretchy geometry leftgroupunder");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("leftharpoon")),
     "stretchy geometry leftharpoon");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("leftharpoonplus")),
     "stretchy geometry leftharpoonplus");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("leftharpoondown")),
     "stretchy geometry leftharpoondown");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("leftharpoondownplus")),
     "stretchy geometry leftharpoondownplus");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("lefthook")),
     "stretchy geometry lefthook");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("leftlinesegment")),
     "stretchy geometry leftlinesegment");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("leftmapsto")),
     "stretchy geometry leftmapsto");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("leftToFrom")),
     "stretchy geometry leftToFrom");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("longequal")),
     "stretchy geometry longequal");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("midbrace")),
     "stretchy geometry midbrace");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("midbraceunder")),
     "stretchy geometry midbraceunder");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("oiintSize1")),
     "stretchy geometry oiintSize1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("oiintSize2")),
     "stretchy geometry oiintSize2");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("oiiintSize1")),
     "stretchy geometry oiiintSize1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("oiiintSize2")),
     "stretchy geometry oiiintSize2");
   Check (Math_Stretchy.PartCount ("overrightarrow") = 1,
     "registration parts overrightarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("overrightarrow", 1)),
     "registration path overrightarrow/1");
   Check (Math_Stretchy.PartCount ("overleftarrow") = 1,
     "registration parts overleftarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("overleftarrow", 1)),
     "registration path overleftarrow/1");
   Check (Math_Stretchy.PartCount ("underrightarrow") = 1,
     "registration parts underrightarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("underrightarrow", 1)),
     "registration path underrightarrow/1");
   Check (Math_Stretchy.PartCount ("underleftarrow") = 1,
     "registration parts underleftarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("underleftarrow", 1)),
     "registration path underleftarrow/1");
   Check (Math_Stretchy.PartCount ("xrightarrow") = 1,
     "registration parts xrightarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xrightarrow", 1)),
     "registration path xrightarrow/1");
   Check (Math_Stretchy.PartCount ("cdrightarrow") = 1,
     "registration parts cdrightarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("cdrightarrow", 1)),
     "registration path cdrightarrow/1");
   Check (Math_Stretchy.PartCount ("xleftarrow") = 1,
     "registration parts xleftarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xleftarrow", 1)),
     "registration path xleftarrow/1");
   Check (Math_Stretchy.PartCount ("cdleftarrow") = 1,
     "registration parts cdleftarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("cdleftarrow", 1)),
     "registration path cdleftarrow/1");
   Check (Math_Stretchy.PartCount ("Overrightarrow") = 1,
     "registration parts Overrightarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("Overrightarrow", 1)),
     "registration path Overrightarrow/1");
   Check (Math_Stretchy.PartCount ("xRightarrow") = 1,
     "registration parts xRightarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xRightarrow", 1)),
     "registration path xRightarrow/1");
   Check (Math_Stretchy.PartCount ("xLeftarrow") = 1,
     "registration parts xLeftarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xLeftarrow", 1)),
     "registration path xLeftarrow/1");
   Check (Math_Stretchy.PartCount ("overleftharpoon") = 1,
     "registration parts overleftharpoon");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("overleftharpoon", 1)),
     "registration path overleftharpoon/1");
   Check (Math_Stretchy.PartCount ("xleftharpoonup") = 1,
     "registration parts xleftharpoonup");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xleftharpoonup", 1)),
     "registration path xleftharpoonup/1");
   Check (Math_Stretchy.PartCount ("xleftharpoondown") = 1,
     "registration parts xleftharpoondown");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xleftharpoondown", 1)),
     "registration path xleftharpoondown/1");
   Check (Math_Stretchy.PartCount ("overrightharpoon") = 1,
     "registration parts overrightharpoon");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("overrightharpoon", 1)),
     "registration path overrightharpoon/1");
   Check (Math_Stretchy.PartCount ("xrightharpoonup") = 1,
     "registration parts xrightharpoonup");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xrightharpoonup", 1)),
     "registration path xrightharpoonup/1");
   Check (Math_Stretchy.PartCount ("xrightharpoondown") = 1,
     "registration parts xrightharpoondown");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xrightharpoondown", 1)),
     "registration path xrightharpoondown/1");
   Check (Math_Stretchy.PartCount ("xlongequal") = 1,
     "registration parts xlongequal");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xlongequal", 1)),
     "registration path xlongequal/1");
   Check (Math_Stretchy.PartCount ("cdlongequal") = 1,
     "registration parts cdlongequal");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("cdlongequal", 1)),
     "registration path cdlongequal/1");
   Check (Math_Stretchy.PartCount ("xtwoheadleftarrow") = 1,
     "registration parts xtwoheadleftarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xtwoheadleftarrow", 1)),
     "registration path xtwoheadleftarrow/1");
   Check (Math_Stretchy.PartCount ("xtwoheadrightarrow") = 1,
     "registration parts xtwoheadrightarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xtwoheadrightarrow", 1)),
     "registration path xtwoheadrightarrow/1");
   Check (Math_Stretchy.PartCount ("overleftrightarrow") = 2,
     "registration parts overleftrightarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("overleftrightarrow", 1)),
     "registration path overleftrightarrow/1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("overleftrightarrow", 2)),
     "registration path overleftrightarrow/2");
   Check (Math_Stretchy.PartCount ("overbrace") = 3,
     "registration parts overbrace");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("overbrace", 1)),
     "registration path overbrace/1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("overbrace", 2)),
     "registration path overbrace/2");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("overbrace", 3)),
     "registration path overbrace/3");
   Check (Math_Stretchy.PartCount ("underbrace") = 3,
     "registration parts underbrace");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("underbrace", 1)),
     "registration path underbrace/1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("underbrace", 2)),
     "registration path underbrace/2");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("underbrace", 3)),
     "registration path underbrace/3");
   Check (Math_Stretchy.PartCount ("underleftrightarrow") = 2,
     "registration parts underleftrightarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("underleftrightarrow", 1)),
     "registration path underleftrightarrow/1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("underleftrightarrow", 2)),
     "registration path underleftrightarrow/2");
   Check (Math_Stretchy.PartCount ("xleftrightarrow") = 2,
     "registration parts xleftrightarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xleftrightarrow", 1)),
     "registration path xleftrightarrow/1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xleftrightarrow", 2)),
     "registration path xleftrightarrow/2");
   Check (Math_Stretchy.PartCount ("xLeftrightarrow") = 2,
     "registration parts xLeftrightarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xLeftrightarrow", 1)),
     "registration path xLeftrightarrow/1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xLeftrightarrow", 2)),
     "registration path xLeftrightarrow/2");
   Check (Math_Stretchy.PartCount ("xrightleftharpoons") = 2,
     "registration parts xrightleftharpoons");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xrightleftharpoons", 1)),
     "registration path xrightleftharpoons/1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xrightleftharpoons", 2)),
     "registration path xrightleftharpoons/2");
   Check (Math_Stretchy.PartCount ("xleftrightharpoons") = 2,
     "registration parts xleftrightharpoons");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xleftrightharpoons", 1)),
     "registration path xleftrightharpoons/1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xleftrightharpoons", 2)),
     "registration path xleftrightharpoons/2");
   Check (Math_Stretchy.PartCount ("xhookleftarrow") = 2,
     "registration parts xhookleftarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xhookleftarrow", 1)),
     "registration path xhookleftarrow/1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xhookleftarrow", 2)),
     "registration path xhookleftarrow/2");
   Check (Math_Stretchy.PartCount ("xhookrightarrow") = 2,
     "registration parts xhookrightarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xhookrightarrow", 1)),
     "registration path xhookrightarrow/1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xhookrightarrow", 2)),
     "registration path xhookrightarrow/2");
   Check (Math_Stretchy.PartCount ("overlinesegment") = 2,
     "registration parts overlinesegment");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("overlinesegment", 1)),
     "registration path overlinesegment/1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("overlinesegment", 2)),
     "registration path overlinesegment/2");
   Check (Math_Stretchy.PartCount ("underlinesegment") = 2,
     "registration parts underlinesegment");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("underlinesegment", 1)),
     "registration path underlinesegment/1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("underlinesegment", 2)),
     "registration path underlinesegment/2");
   Check (Math_Stretchy.PartCount ("overgroup") = 2,
     "registration parts overgroup");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("overgroup", 1)),
     "registration path overgroup/1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("overgroup", 2)),
     "registration path overgroup/2");
   Check (Math_Stretchy.PartCount ("undergroup") = 2,
     "registration parts undergroup");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("undergroup", 1)),
     "registration path undergroup/1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("undergroup", 2)),
     "registration path undergroup/2");
   Check (Math_Stretchy.PartCount ("xmapsto") = 2,
     "registration parts xmapsto");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xmapsto", 1)),
     "registration path xmapsto/1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xmapsto", 2)),
     "registration path xmapsto/2");
   Check (Math_Stretchy.PartCount ("xtofrom") = 2,
     "registration parts xtofrom");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xtofrom", 1)),
     "registration path xtofrom/1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xtofrom", 2)),
     "registration path xtofrom/2");
   Check (Math_Stretchy.PartCount ("xrightleftarrows") = 2,
     "registration parts xrightleftarrows");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xrightleftarrows", 1)),
     "registration path xrightleftarrows/1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xrightleftarrows", 2)),
     "registration path xrightleftarrows/2");
   Check (Math_Stretchy.PartCount ("xrightequilibrium") = 2,
     "registration parts xrightequilibrium");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xrightequilibrium", 1)),
     "registration path xrightequilibrium/1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xrightequilibrium", 2)),
     "registration path xrightequilibrium/2");
   Check (Math_Stretchy.PartCount ("xleftequilibrium") = 2,
     "registration parts xleftequilibrium");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xleftequilibrium", 1)),
     "registration path xleftequilibrium/1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xleftequilibrium", 2)),
     "registration path xleftequilibrium/2");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("rightarrow")),
     "stretchy geometry rightarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("rightbrace")),
     "stretchy geometry rightbrace");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("rightbraceunder")),
     "stretchy geometry rightbraceunder");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("rightgroup")),
     "stretchy geometry rightgroup");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("rightgroupunder")),
     "stretchy geometry rightgroupunder");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("rightharpoon")),
     "stretchy geometry rightharpoon");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("rightharpoonplus")),
     "stretchy geometry rightharpoonplus");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("rightharpoondown")),
     "stretchy geometry rightharpoondown");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("rightharpoondownplus")),
     "stretchy geometry rightharpoondownplus");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("righthook")),
     "stretchy geometry righthook");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("rightlinesegment")),
     "stretchy geometry rightlinesegment");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("rightToFrom")),
     "stretchy geometry rightToFrom");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("twoheadleftarrow")),
     "stretchy geometry twoheadleftarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("twoheadrightarrow")),
     "stretchy geometry twoheadrightarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("tilde1")),
     "stretchy geometry tilde1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("tilde2")),
     "stretchy geometry tilde2");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("tilde3")),
     "stretchy geometry tilde3");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("tilde4")),
     "stretchy geometry tilde4");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("vec")),
     "stretchy geometry vec");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("widehat1")),
     "stretchy geometry widehat1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("widehat2")),
     "stretchy geometry widehat2");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("widehat3")),
     "stretchy geometry widehat3");
   Item := Math_Stretchy.Geometry_For ("widehat4");
   Check (Math_Paths.Is_Valid (Item), "stretchy geometry widehat4");
   Check (Math_Paths.Element (Item, 3).Kind = Math_Paths.Line_To and then
     Math_Paths.Element (Item, 3).First.X = 2_354.0 and then
     Math_Paths.Element (Item, 3).First.Y = 296.0,
     "widehat4 second segment line endpoint");
   Check (abs (Math_Paths.Element (Item, 3).First.Y / 340.0 -
     0.8705882352941176) < 1.0e-15,
     "widehat4 normalized second segment endpoint");
   Box := Math_Paths.Extent (Item);
   Check (Box.Valid and then Box.Max_Y = 340.0,
     "widehat4 control hull vertical extent");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("widecheck1")),
     "stretchy geometry widecheck1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("widecheck2")),
     "stretchy geometry widecheck2");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("widecheck3")),
     "stretchy geometry widecheck3");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("widecheck4")),
     "stretchy geometry widecheck4");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("baraboveleftarrow")),
     "stretchy geometry baraboveleftarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("rightarrowabovebar")),
     "stretchy geometry rightarrowabovebar");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("baraboveshortleftharpoon")),
     "stretchy geometry baraboveshortleftharpoon");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("rightharpoonaboveshortbar")),
     "stretchy geometry rightharpoonaboveshortbar");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("shortbaraboveleftharpoon")),
     "stretchy geometry shortbaraboveleftharpoon");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("shortrightharpoonabovebar")),
     "stretchy geometry shortrightharpoonabovebar");
   Check (Math_Stretchy.PartCount ("overrightarrow") = 1,
     "registration parts overrightarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("overrightarrow", 1)),
     "registration path overrightarrow/1");
   Check (Math_Stretchy.PartCount ("overleftarrow") = 1,
     "registration parts overleftarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("overleftarrow", 1)),
     "registration path overleftarrow/1");
   Check (Math_Stretchy.PartCount ("underrightarrow") = 1,
     "registration parts underrightarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("underrightarrow", 1)),
     "registration path underrightarrow/1");
   Check (Math_Stretchy.PartCount ("underleftarrow") = 1,
     "registration parts underleftarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("underleftarrow", 1)),
     "registration path underleftarrow/1");
   Check (Math_Stretchy.PartCount ("xrightarrow") = 1,
     "registration parts xrightarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xrightarrow", 1)),
     "registration path xrightarrow/1");
   Check (Math_Stretchy.PartCount ("cdrightarrow") = 1,
     "registration parts cdrightarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("cdrightarrow", 1)),
     "registration path cdrightarrow/1");
   Check (Math_Stretchy.PartCount ("xleftarrow") = 1,
     "registration parts xleftarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xleftarrow", 1)),
     "registration path xleftarrow/1");
   Check (Math_Stretchy.PartCount ("cdleftarrow") = 1,
     "registration parts cdleftarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("cdleftarrow", 1)),
     "registration path cdleftarrow/1");
   Check (Math_Stretchy.PartCount ("Overrightarrow") = 1,
     "registration parts Overrightarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("Overrightarrow", 1)),
     "registration path Overrightarrow/1");
   Check (Math_Stretchy.PartCount ("xRightarrow") = 1,
     "registration parts xRightarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xRightarrow", 1)),
     "registration path xRightarrow/1");
   Check (Math_Stretchy.PartCount ("xLeftarrow") = 1,
     "registration parts xLeftarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xLeftarrow", 1)),
     "registration path xLeftarrow/1");
   Check (Math_Stretchy.PartCount ("overleftharpoon") = 1,
     "registration parts overleftharpoon");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("overleftharpoon", 1)),
     "registration path overleftharpoon/1");
   Check (Math_Stretchy.PartCount ("xleftharpoonup") = 1,
     "registration parts xleftharpoonup");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xleftharpoonup", 1)),
     "registration path xleftharpoonup/1");
   Check (Math_Stretchy.PartCount ("xleftharpoondown") = 1,
     "registration parts xleftharpoondown");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xleftharpoondown", 1)),
     "registration path xleftharpoondown/1");
   Check (Math_Stretchy.PartCount ("overrightharpoon") = 1,
     "registration parts overrightharpoon");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("overrightharpoon", 1)),
     "registration path overrightharpoon/1");
   Check (Math_Stretchy.PartCount ("xrightharpoonup") = 1,
     "registration parts xrightharpoonup");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xrightharpoonup", 1)),
     "registration path xrightharpoonup/1");
   Check (Math_Stretchy.PartCount ("xrightharpoondown") = 1,
     "registration parts xrightharpoondown");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xrightharpoondown", 1)),
     "registration path xrightharpoondown/1");
   Check (Math_Stretchy.PartCount ("xlongequal") = 1,
     "registration parts xlongequal");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xlongequal", 1)),
     "registration path xlongequal/1");
   Check (Math_Stretchy.PartCount ("cdlongequal") = 1,
     "registration parts cdlongequal");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("cdlongequal", 1)),
     "registration path cdlongequal/1");
   Check (Math_Stretchy.PartCount ("xtwoheadleftarrow") = 1,
     "registration parts xtwoheadleftarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xtwoheadleftarrow", 1)),
     "registration path xtwoheadleftarrow/1");
   Check (Math_Stretchy.PartCount ("xtwoheadrightarrow") = 1,
     "registration parts xtwoheadrightarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xtwoheadrightarrow", 1)),
     "registration path xtwoheadrightarrow/1");
   Check (Math_Stretchy.PartCount ("overleftrightarrow") = 2,
     "registration parts overleftrightarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("overleftrightarrow", 1)),
     "registration path overleftrightarrow/1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("overleftrightarrow", 2)),
     "registration path overleftrightarrow/2");
   Check (Math_Stretchy.PartCount ("overbrace") = 3,
     "registration parts overbrace");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("overbrace", 1)),
     "registration path overbrace/1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("overbrace", 2)),
     "registration path overbrace/2");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("overbrace", 3)),
     "registration path overbrace/3");
   Check (Math_Stretchy.PartCount ("underbrace") = 3,
     "registration parts underbrace");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("underbrace", 1)),
     "registration path underbrace/1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("underbrace", 2)),
     "registration path underbrace/2");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("underbrace", 3)),
     "registration path underbrace/3");
   Check (Math_Stretchy.PartCount ("underleftrightarrow") = 2,
     "registration parts underleftrightarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("underleftrightarrow", 1)),
     "registration path underleftrightarrow/1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("underleftrightarrow", 2)),
     "registration path underleftrightarrow/2");
   Check (Math_Stretchy.PartCount ("xleftrightarrow") = 2,
     "registration parts xleftrightarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xleftrightarrow", 1)),
     "registration path xleftrightarrow/1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xleftrightarrow", 2)),
     "registration path xleftrightarrow/2");
   Check (Math_Stretchy.PartCount ("xLeftrightarrow") = 2,
     "registration parts xLeftrightarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xLeftrightarrow", 1)),
     "registration path xLeftrightarrow/1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xLeftrightarrow", 2)),
     "registration path xLeftrightarrow/2");
   Check (Math_Stretchy.PartCount ("xrightleftharpoons") = 2,
     "registration parts xrightleftharpoons");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xrightleftharpoons", 1)),
     "registration path xrightleftharpoons/1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xrightleftharpoons", 2)),
     "registration path xrightleftharpoons/2");
   Check (Math_Stretchy.PartCount ("xleftrightharpoons") = 2,
     "registration parts xleftrightharpoons");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xleftrightharpoons", 1)),
     "registration path xleftrightharpoons/1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xleftrightharpoons", 2)),
     "registration path xleftrightharpoons/2");
   Check (Math_Stretchy.PartCount ("xhookleftarrow") = 2,
     "registration parts xhookleftarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xhookleftarrow", 1)),
     "registration path xhookleftarrow/1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xhookleftarrow", 2)),
     "registration path xhookleftarrow/2");
   Check (Math_Stretchy.PartCount ("xhookrightarrow") = 2,
     "registration parts xhookrightarrow");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xhookrightarrow", 1)),
     "registration path xhookrightarrow/1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xhookrightarrow", 2)),
     "registration path xhookrightarrow/2");
   Check (Math_Stretchy.PartCount ("overlinesegment") = 2,
     "registration parts overlinesegment");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("overlinesegment", 1)),
     "registration path overlinesegment/1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("overlinesegment", 2)),
     "registration path overlinesegment/2");
   Check (Math_Stretchy.PartCount ("underlinesegment") = 2,
     "registration parts underlinesegment");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("underlinesegment", 1)),
     "registration path underlinesegment/1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("underlinesegment", 2)),
     "registration path underlinesegment/2");
   Check (Math_Stretchy.PartCount ("overgroup") = 2,
     "registration parts overgroup");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("overgroup", 1)),
     "registration path overgroup/1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("overgroup", 2)),
     "registration path overgroup/2");
   Check (Math_Stretchy.PartCount ("undergroup") = 2,
     "registration parts undergroup");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("undergroup", 1)),
     "registration path undergroup/1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("undergroup", 2)),
     "registration path undergroup/2");
   Check (Math_Stretchy.PartCount ("xmapsto") = 2,
     "registration parts xmapsto");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xmapsto", 1)),
     "registration path xmapsto/1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xmapsto", 2)),
     "registration path xmapsto/2");
   Check (Math_Stretchy.PartCount ("xtofrom") = 2,
     "registration parts xtofrom");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xtofrom", 1)),
     "registration path xtofrom/1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xtofrom", 2)),
     "registration path xtofrom/2");
   Check (Math_Stretchy.PartCount ("xrightleftarrows") = 2,
     "registration parts xrightleftarrows");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xrightleftarrows", 1)),
     "registration path xrightleftarrows/1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xrightleftarrows", 2)),
     "registration path xrightleftarrows/2");
   Check (Math_Stretchy.PartCount ("xrightequilibrium") = 2,
     "registration parts xrightequilibrium");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xrightequilibrium", 1)),
     "registration path xrightequilibrium/1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xrightequilibrium", 2)),
     "registration path xrightequilibrium/2");
   Check (Math_Stretchy.PartCount ("xleftequilibrium") = 2,
     "registration parts xleftequilibrium");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xleftequilibrium", 1)),
     "registration path xleftequilibrium/1");
   Check (Math_Paths.Is_Valid (Math_Stretchy.PartPath ("xleftequilibrium", 2)),
     "registration path xleftequilibrium/2");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("rightarrow")),
     "right arrow geometry");
   Check (Math_Paths.Is_Valid (Math_Stretchy.Geometry_For ("widecheck4")),
     "widecheck geometry");
   Check (not Math_Paths.Is_Valid
     (Math_Stretchy.Geometry_For ("unknown-path")),
     "unknown geometry rejected");
   Check (Math_Stretchy.PartCount ("xleftrightharpoons") = 2,
     "mhchem arrow has two pieces");
   Check (Math_Stretchy.PartCount ("overbrace") = 3,
     "brace keeps three pieces");
   Check (Math_Stretchy.ViewBoxHeightFor ("xrightequilibrium") = 716.0,
     "equilibrium viewBox height");
   Check (Math_Stretchy.MinWidthFor ("xrightarrow") = 1.469,
     "arrow minimum width");
   Check (Math_Stretchy.PartAlignFor ("xrightarrow", 1) =
     Math_Stretchy.Max_Align, "single arrow tail alignment");
   Check (Math_Stretchy.PartAlignFor ("xleftrightharpoons", 1) =
     Math_Stretchy.Min_Align and then
     Math_Stretchy.PartAlignFor ("xleftrightharpoons", 2) =
     Math_Stretchy.Max_Align, "two-piece arrow alignments");
   Check (Math_Stretchy.PartAlignFor ("overbrace", 2) =
     Math_Stretchy.Mid_Align, "three-piece center alignment");
   for I in 1 .. 3 loop
      Item := Math_Stretchy.PartPath ("overbrace", I);
      Check (Math_Paths.Is_Valid (Item), "overbrace part path" & Natural'Image (I));
   end loop;
   Item := Math_Stretchy.Path_For (Math_Stretchy.Wide_Hat, 1_000.0);
   Check (Math_Paths.Is_Valid (Item), "widehat dynamic choice retained");
   Check (Math_Stretchy.Brace_Part_For
     (Math_Stretchy.Under_Brace, Math_Stretchy.Middle_Part) =
     Math_Stretchy.PartPath ("underbrace", 2),
     "legacy brace API preserved");

   Check (Checks >= 52, "at least 52 test cases");
   Ada.Text_IO.Put_Line
     (Natural'Image (Checks) & " checks;" & Natural'Image (Failures) &
      " failures");
   if Failures /= 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Math_Paths_Probe;
