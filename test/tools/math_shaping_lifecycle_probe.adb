with Ada.Command_Line;
with Ada.Exceptions;
with Ada.Text_IO;
with Cairo;
with Cairo.Image_Surface;
with Interfaces;
with Math_Model;
with Math_Text_Shaping;

procedure Math_Shaping_Lifecycle_Probe is
   use type Interfaces.Unsigned_64;
   Count : Natural := 1;
   Draw_Enabled : Boolean := False;
   Checksum : Long_Float := 0.0;
   Metric_Hash : Interfaces.Unsigned_64 := 1_469_598_103_934_665_603;
   Last_Metrics : Math_Text_Shaping.Metrics;
   Surface : Cairo.Cairo_Surface := Cairo.Image_Surface.Create
     (Cairo.Image_Surface.Cairo_Format_ARGB32, 32, 32);
   Context : Cairo.Cairo_Context := Cairo.Create (Surface);
begin
   if Ada.Command_Line.Argument_Count < 1 or else
     Ada.Command_Line.Argument_Count > 2
   then
      raise Constraint_Error with "usage: probe COUNT [draw]";
   end if;
   Count := Natural'Value (Ada.Command_Line.Argument (1));
   if Count = 0 or else Count > 1_000 then
      raise Constraint_Error with "COUNT must be in 1 .. 1000";
   end if;
   if Ada.Command_Line.Argument_Count = 2 then
      if Ada.Command_Line.Argument (2) /= "draw" then
         raise Constraint_Error with "optional mode must be draw";
      end if;
      Draw_Enabled := True;
   end if;

   for Iteration in 1 .. Count loop
      Last_Metrics := Math_Text_Shaping.Measure
        ("Ж", Math_Model.Cyrillic_Fallback);
      if Last_Metrics.Advance <= 0.0 or else
        Last_Metrics.Ascent <= 0.0 or else Last_Metrics.Descent < 0.0
      then
         raise Program_Error with "unexpected Cyrillic metrics";
      end if;
      Checksum := Checksum + Last_Metrics.Advance + Last_Metrics.Ascent +
        Last_Metrics.Descent;
      Metric_Hash := Metric_Hash * 1_099_511_628_211 +
        Interfaces.Unsigned_64 (Last_Metrics.Advance * 1_000_000.0) +
        Interfaces.Unsigned_64 (Last_Metrics.Ascent * 1_000_000.0) * 3 +
        Interfaces.Unsigned_64 (Last_Metrics.Descent * 1_000_000.0) * 7;
      if Draw_Enabled then
         Math_Text_Shaping.Draw
           (Context, "Ж", Math_Model.Cyrillic_Fallback,
            1.0, 20.0, 16.0, 1.0);
      end if;
   end loop;

   Ada.Text_IO.Put_Line
     ("iterations=" & Natural'Image (Count) &
      " draw=" & Boolean'Image (Draw_Enabled) &
      " text_bytes=2 glyph_width=" & Long_Float'Image
        (Last_Metrics.Advance) & " ascent=" & Long_Float'Image
        (Last_Metrics.Ascent) & " descent=" & Long_Float'Image
        (Last_Metrics.Descent) & " metric_hash=" &
        Interfaces.Unsigned_64'Image (Metric_Hash) & " checksum=" &
        Long_Float'Image (Checksum));
   Cairo.Destroy (Context);
   Cairo.Surface_Destroy (Surface);
exception
   when Error : others =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error, Ada.Exceptions.Exception_Information
           (Error));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Math_Shaping_Lifecycle_Probe;
