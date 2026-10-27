with Ada.Command_Line;
with Ada.Text_IO;
with Math_Paths;
with Math_Radical_Paths;

procedure Math_Radical_Path_Probe is
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
   procedure Run (Size : Natural; Extra : Long_Float; Width : Long_Float) is
      Item : constant Math_Paths.Path :=
        Math_Radical_Paths.Build (Size, Extra, Width);
      Box : constant Math_Paths.Bounds := Math_Paths.Extent (Item);
      Other_Width : constant Math_Paths.Path :=
        Math_Radical_Paths.Build (Size, Extra, (if Width = 4.0 then 1.0 else 4.0));
      Other_Box : constant Math_Paths.Bounds := Math_Paths.Extent (Other_Width);
   begin
      Check (Math_Paths.Is_Valid (Item), "valid path size" & Natural'Image (Size));
      Check (Math_Paths.Count (Item) > 20, "segment count size" & Natural'Image (Size));
      Check (Box.Valid, "valid bounds size" & Natural'Image (Size));
      Check (Box.Min_X >= -1_000_000.0 and Box.Max_X <= 1_000_000.0,
        "signed x bounds size" & Natural'Image (Size));
      Check (Box.Max_X = Other_Box.Max_X, "width does not rewrite raw path");
      Check (Box.Max_X >= 400_000.0, "preserve long raw horizontal tail");
      if Size = 0 then
         Check (Box.Max_X = 400_834.0, "size-zero H tail begins at x=834");
      end if;
      Check (Box.Min_Y >= -1_000_000.0 and Box.Max_Y <= 1_000_000.0,
        "signed y bounds size" & Natural'Image (Size));
   end Run;
begin
   for Size in 0 .. 4 loop
      Run (Size, 0.0, 4.0);
      Run (Size, 0.1, 1.0);
   end loop;
   Check (not Math_Paths.Is_Valid (Math_Radical_Paths.Build (5, 0.0, 1.0)),
     "reject invalid size");
   Check (not Math_Paths.Is_Valid (Math_Radical_Paths.Build (0, -0.1, 1.0)),
     "reject negative thickness");
   Ada.Text_IO.Put_Line
     ("checks=" & Natural'Image (Checks) & " failures=" & Natural'Image (Failures));
   if Failures /= 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Math_Radical_Path_Probe;
