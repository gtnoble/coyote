with Ada.Command_Line;
with Ada.Exceptions;
with Ada.Text_IO;
with Cairo;
with Cairo.Image_Surface;
with Interfaces;
with Math_Model;
with Math_Text_Shaping;

procedure Math_Shaping_Lifecycle_Probe is
   use type Cairo.Cairo_Context;
   use type Cairo.Cairo_Surface;
   use type Interfaces.Unsigned_64;

   procedure Reset_Cairo_Caches
     with Import, Convention => C,
       External_Name => "cairo_debug_reset_static_data";
   procedure Finish_Fontconfig
     with Import, Convention => C, External_Name => "FcFini";

   Count          : Natural := 1;
   Mode           : constant String :=
     (if Ada.Command_Line.Argument_Count >= 2 then
         Ada.Command_Line.Argument (2)
      else
         "");
   Draw_Enabled   : Boolean := False;
   Teardown       : Boolean := False;
   Checksum       : Long_Float := 0.0;
   Metric_Hash    : Interfaces.Unsigned_64 := 1_469_598_103_934_665_603;
   Last_Metrics   : Math_Text_Shaping.Metrics;
   Surface        : Cairo.Cairo_Surface := Cairo.Null_Surface;
   Context        : Cairo.Cairo_Context := Cairo.Null_Context;

   procedure Release_Cairo_Owners is
   begin
      if Context /= Cairo.Null_Context then
         Cairo.Destroy (Context);
         Context := Cairo.Null_Context;
      end if;
      if Surface /= Cairo.Null_Surface then
         Cairo.Surface_Destroy (Surface);
         Surface := Cairo.Null_Surface;
      end if;
   end Release_Cairo_Owners;

   procedure Run_Shaping is
   begin
      for Iteration in 1 .. Count loop
         Last_Metrics := Math_Text_Shaping.Measure
           ("Ж", Math_Model.Cyrillic_Fallback);
         if Last_Metrics.Advance <= 0.0 or else
           Last_Metrics.Ascent <= 0.0 or else Last_Metrics.Descent < 0.0
         then
            raise Program_Error with "unexpected Cyrillic metrics";
         end if;
         Checksum := Checksum + Last_Metrics.Advance +
           Last_Metrics.Ascent + Last_Metrics.Descent;
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
   end Run_Shaping;

begin
   if Ada.Command_Line.Argument_Count < 2 or else
     Ada.Command_Line.Argument_Count > 4
   then
      raise Constraint_Error with
        "usage: probe COUNT baseline|measure|draw [teardown]";
   end if;
   Count := Natural'Value (Ada.Command_Line.Argument (1));
   if Count = 0 or else Count > 1_000 then
      raise Constraint_Error with "COUNT must be in 1 .. 1000";
   end if;
   if Mode /= "baseline" and then Mode /= "measure" and then Mode /= "draw" then
      raise Constraint_Error with "mode must be baseline, measure, or draw";
   end if;
   if Ada.Command_Line.Argument_Count >= 3 then
      if Ada.Command_Line.Argument (3) /= "teardown" then
         raise Constraint_Error with "optional mode must be teardown";
      end if;
      Teardown := True;
   end if;
   if Ada.Command_Line.Argument_Count = 4 then
      raise Constraint_Error with "too many arguments";
   end if;
   Draw_Enabled := Mode = "draw";
   if Mode /= "baseline" then
      Surface := Cairo.Image_Surface.Create
        (Cairo.Image_Surface.Cairo_Format_ARGB32, 32, 32);
      Context := Cairo.Create (Surface);
      Run_Shaping;
   end if;
   Release_Cairo_Owners;
   if Teardown then
      --  Test-only global cleanup; never use in production or concurrent clients.
      Reset_Cairo_Caches;
      Finish_Fontconfig;
   end if;
   Ada.Text_IO.Put_Line
     ("LIFECYCLE_SUMMARY,iterations=" & Natural'Image (Count) &
      ",mode=" & Mode & ",teardown=" & Boolean'Image (Teardown) &
      ",text_bytes=" & (if Mode = "baseline" then "0" else "2") &
      ",metric_hash=" & Interfaces.Unsigned_64'Image (Metric_Hash) &
      ",checksum=" & Long_Float'Image (Checksum));
exception
   when Error : others =>
      Release_Cairo_Owners;
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         Ada.Exceptions.Exception_Information (Error));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Math_Shaping_Lifecycle_Probe;
