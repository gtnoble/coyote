with Ada.Command_Line;
with Ada.Text_IO;
with Math_Font_Data;

procedure Math_Font_Data_Probe is
   use Math_Font_Data;
   Checks : Natural := 0;
   Failures : Natural := 0;

   procedure Check (Condition : Boolean; Label : String) is
   begin
      Checks := Checks + 1;
      if Condition then
         Ada.Text_IO.Put_Line ("ok " & Label);
      else
         Failures := Failures + 1;
         Ada.Text_IO.Put_Line ("FAIL " & Label);
      end if;
   end Check;

   Faces_With_Data : Natural := 0;
   Total_Glyphs : Natural := 0;
begin
   for Face in Font_Face loop
         Check (Face_Stem (Face)'Length > 6, "face stem " & Face'Image);
         Check (Asset_Filename (Face) = Face_Stem (Face) & ".ttf",
           "asset filename " & Face'Image);
         declare
            Face_Glyphs : Natural := 0;
         begin
            for Point in 0 .. 16#10_FFFF# loop
               if Lookup (Face, Point).Found then
                  Face_Glyphs := Face_Glyphs + 1;
               end if;
            end loop;
            Total_Glyphs := Total_Glyphs + Face_Glyphs;
            if Face_Glyphs > 0 then
               Faces_With_Data := Faces_With_Data + 1;
            end if;
         end;
      end loop;
      Check (Font_Face'Pos (Font_Face'Last) + 1 = 20,
        "all 20 font faces enumerated");
   Check (Faces_With_Data = 18, "18 upstream metric tables present");
   Check (Total_Glyphs = 2_038, "all 2,038 glyph records available");
   Check (not Lookup (Caligraphic_Bold, 65).Found,
        "face missing from upstream data remains not-found");
   Check (not Lookup (Fraktur_Bold, 65).Found,
        "second face missing from upstream data remains not-found");
   Check (Lookup (Main_Regular, 65).Found
        and then abs (Lookup (Main_Regular, 65).Width - 0.75) < 0.000001
        and then abs (Lookup (Main_Regular, 65).Ascent - 0.68333) < 0.000001,
        "Main-Regular A width and ascent");
   Check (Lookup (Caligraphic_Regular, 65).Found
        and then abs (Lookup (Caligraphic_Regular, 65).Skew - 0.19445) < 0.000001,
        "nonzero skew preserved");
   Check (Lookup (AMS_Regular, 8592).Found
        and then Lookup (AMS_Regular, 8592).Descent < 0.0,
        "negative depth preserved as signed descent");
   Check (not Lookup (Main_Regular, 16#10_FFFF#).Found,
        "missing code point reports not-found");
   Ada.Text_IO.Put_Line
     ("ASSERTIONS " & Natural'Image (Checks) & " failures=" &
      Natural'Image (Failures));
   if Failures /= 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Math_Font_Data_Probe;
