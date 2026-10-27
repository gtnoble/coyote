with Ada.Command_Line;
with Ada.Real_Time;
with Ada.Containers;
with Ada.Text_IO;
with Interfaces;
with Math_Raster;
with Coyote_Math_Jobs;
with Math_Layout;
with Math_Syntax;
with Math_Semantics;
procedure Math_Jobs_Probe is
   package Jobs renames Coyote_Math_Jobs;
   use type Jobs.Job_Status;
   use type Jobs.Request_Id;
   use type Jobs.View_Generation;
   use type Jobs.Result_Access;
   use type Ada.Containers.Count_Type;
   use type Interfaces.Unsigned_32;
   use type Ada.Real_Time.Time;

   function Has_Red_Ink (Result : Jobs.Result_Access) return Boolean is
   begin
      for Y in 0 .. Jobs.Raster_Height (Result.all) - 1 loop
         for X in 0 .. Jobs.Raster_Width (Result.all) - 1 loop
            declare
               Pixel : constant Interfaces.Unsigned_32 :=
                 Jobs.Raster_Pixel (Result.all, X, Y);
               Alpha : constant Interfaces.Unsigned_32 :=
                 Interfaces.Shift_Right (Pixel, 24);
               Red : constant Interfaces.Unsigned_32 :=
                 Interfaces.Shift_Right (Pixel, 16) and 16#FF#;
               Green : constant Interfaces.Unsigned_32 :=
                 Interfaces.Shift_Right (Pixel, 8) and 16#FF#;
               Blue : constant Interfaces.Unsigned_32 := Pixel and 16#FF#;
            begin
               if Alpha > 0 and then Red > Green and then Red > Blue then
                  return True;
               end if;
            end;
         end loop;
      end loop;
      return False;
   end Has_Red_Ink;

   Checks : Natural := 0;
   Failures : Natural := 0;

   procedure Check (Value : Boolean; Label : String) is
   begin
      Checks := Checks + 1;
      if not Value then
         Failures := Failures + 1;
         Ada.Text_IO.Put_Line ("FAIL " & Label);
      end if;
      Ada.Text_IO.Flush;
   end Check;

   Ids : array (1 .. Jobs.Queue_Capacity) of Jobs.Request_Id :=
     (others => 0);
   S : Jobs.Job_Status;
   R : Jobs.Result_Access;
   Timing_Value : Jobs.Job_Timing;
   Timing_Found : Boolean;
   Late_Invalid_Source : String (1 .. Math_Syntax.Max_Source_Bytes) :=
     (others => 'x');
   Overflow_Id : Jobs.Request_Id;
   Abandoned_Id : Jobs.Request_Id;
   Abandoned_Generation : constant Jobs.View_Generation := 99;
   Font_Directory : constant String :=
     (if Ada.Command_Line.Argument_Count = 1
      then Ada.Command_Line.Argument (1) else "");
begin
   Check (Font_Directory'Length > 0, "trusted font directory supplied");
   Jobs.Start (Paused => True);
   declare
      Red_Id : Jobs.Request_Id;
      Bad_Id : Jobs.Request_Id;
      Plain_Id : Jobs.Request_Id;
      Plain_Result : Jobs.Result_Access;
      Plain_Status : Jobs.Job_Status;
      Red_Result : Jobs.Result_Access;
      Red_Status : Jobs.Job_Status;
      Bad_Status : Jobs.Job_Status;
      Has_Red : Boolean := False;
      Has_Blue : Boolean := False;
   begin
      Jobs.Submit ("x+\textcolor{blue}{y}", Red_Id, 301,
        Math_Layout.Text_Style,
        Color_Enabled => True,
        Color => (Red => 1.0, Green => 0.0, Blue => 0.0, Alpha => 1.0),
        Status => Red_Status);
      Check (Red_Status = Jobs.Pending, "colored request queued");
      Jobs.Submit ("x", Plain_Id, 302, Math_Layout.Text_Style,
        Color_Enabled => True,
        Color => (Red => 1.0, Green => 0.0, Blue => 0.0, Alpha => 1.0),
        Status => Plain_Status);
      Check (Plain_Status = Jobs.Pending, "fallback-only request queued");
      Jobs.Submit ("x", Bad_Id, 301, Math_Layout.Text_Style,
        Color_Enabled => True,
        Color => (Red => 1.5, Green => 0.0,
          Blue => 0.0, Alpha => 1.0), Status => Bad_Status);
      Check (Bad_Status = Jobs.Invalid and Bad_Id = 0,
        "out-of-range fallback color rejected explicitly");
      Jobs.Resume;
      for Wait in 1 .. 400 loop
         Jobs.Poll (Red_Id, 301, Red_Status, Red_Result);
         exit when Red_Status /= Jobs.Pending;
         delay 0.005;
      end loop;
      Check (Red_Status = Jobs.Valid and Red_Result /= null,
        "colored request completes successfully");
      if Red_Result /= null then
         for I in Jobs.Layout (Red_Result.all).Commands.First_Index ..
           Jobs.Layout (Red_Result.all).Commands.Last_Index
         loop
            declare
               Command : constant Math_Layout.Draw_Command :=
                 Jobs.Layout (Red_Result.all).Commands (I);
            begin
               if Command.Has_Color and then Command.Red = 1.0 and then
                 Command.Green = 0.0 and then Command.Blue = 0.0
               then
                  Has_Red := True;
               elsif Command.Has_Color and then Command.Red = 0.0 and then
                 Command.Green = 0.0 and then Command.Blue = 1.0
               then
                  Has_Blue := True;
               end if;
            end;
         end loop;
         Check (Has_Red, "fallback red reaches uncolored draw commands");
         Check (Has_Blue, "explicit nested blue remains unchanged");
         Jobs.Release (Red_Result);
      end if;
      for Wait in 1 .. 400 loop
         Jobs.Poll (Plain_Id, 302, Plain_Status, Plain_Result);
         exit when Plain_Status /= Jobs.Pending;
         delay 0.005;
      end loop;
      Check (Plain_Status = Jobs.Valid and Plain_Result /= null,
        "fallback-only request completes successfully");
      if Plain_Result /= null then
         for I in Jobs.Layout (Plain_Result.all).Commands.First_Index ..
           Jobs.Layout (Plain_Result.all).Commands.Last_Index
         loop
            declare
               Command : constant Math_Layout.Draw_Command :=
                 Jobs.Layout (Plain_Result.all).Commands (I);
            begin
               if Command.Has_Color and then Command.Red = 1.0 and then
                 Command.Green = 0.0 and then Command.Blue = 0.0
               then
                  Has_Red := True;
               end if;
            end;
         end loop;
         Check (Has_Red, "fallback red reaches uncolored draw commands");
         Jobs.Release (Plain_Result);
      end if;
   end;
   declare
      Raster_Id : Jobs.Request_Id;
      Raster_Status : Jobs.Job_Status;
      Raster_Result : Jobs.Result_Access;
      Raster_Has_Color : Boolean := False;
      Bad_Scale_Id : Jobs.Request_Id;
      Bad_Scale_Status : Jobs.Job_Status;
      Missing_Font_Id : Jobs.Request_Id;
      Missing_Font_Status : Jobs.Job_Status;
   begin
      Jobs.Submit ("x+y", Raster_Id, 303, Math_Layout.Display_Style,
        Color_Enabled => True,
        Color => (Red => 0.2, Green => 0.1, Blue => 0.05, Alpha => 1.0),
        Status => Raster_Status, Request_Raster => True,
        Em_Pixels => 24.0, Font_Directory => Font_Directory);
      Check (Raster_Status = Jobs.Pending, "raster request queued");
      Jobs.Submit ("x", Bad_Scale_Id, 304, Math_Layout.Text_Style,
        Status => Bad_Scale_Status, Request_Raster => True,
        Em_Pixels => 257.0, Font_Directory => Font_Directory);
      Check (Bad_Scale_Status = Jobs.Invalid and Bad_Scale_Id = 0,
        "scale above 256 rejected synchronously");
      Jobs.Submit ("x", Missing_Font_Id, 305, Math_Layout.Text_Style,
        Status => Missing_Font_Status, Request_Raster => True,
        Em_Pixels => 16.0);
      Check (Missing_Font_Status = Jobs.Invalid and Missing_Font_Id = 0,
        "raster request requires trusted font directory");
      for Wait in 1 .. 400 loop
         Jobs.Poll (Raster_Id, 303, Raster_Status, Raster_Result);
         exit when Raster_Status /= Jobs.Pending;
         delay 0.005;
      end loop;
      Check (Raster_Status = Jobs.Valid and Raster_Result /= null,
        "requested raster completes valid");
      if Raster_Result /= null then
         Check (Jobs.Has_Raster (Raster_Result.all),
           "owned raster reported available");
         Check (Jobs.Raster_Width (Raster_Result.all) > 0 and
           Jobs.Raster_Height (Raster_Result.all) > 0,
           "raster dimensions positive");
         Check (Jobs.Raster_Width (Raster_Result.all) <= 8192 and
           Jobs.Raster_Height (Raster_Result.all) <= 4096,
           "raster dimensions respect full-render caps");
         Check (Jobs.Raster_Baseline (Raster_Result.all) <=
           Jobs.Raster_Height (Raster_Result.all),
           "raster baseline metadata is in bounds");
         Check (Has_Red_Ink (Raster_Result),
           "raster contains requested red-dominant foreground ink");
         for I in Jobs.Layout (Raster_Result.all).Commands.First_Index ..
           Jobs.Layout (Raster_Result.all).Commands.Last_Index
         loop
            declare
               Command : constant Math_Layout.Draw_Command :=
                 Jobs.Layout (Raster_Result.all).Commands (I);
            begin
               Raster_Has_Color := Raster_Has_Color or else
                 (Command.Has_Color and then Command.Red = 0.2 and then
                  Command.Green = 0.1 and then Command.Blue = 0.05);
            end;
         end loop;
         Check (Raster_Has_Color,
           "requested raster layout retains caller foreground");
         Jobs.Release (Raster_Result);
      end if;
   end;
   Jobs.Shutdown;
   Jobs.Submit ("prestart", Ids (1), 77, Math_Layout.Text_Style,
     Status => S);
   Check (S = Jobs.Busy and Ids (1) = 0,
     "pre-start request rejected");
   Jobs.Start (Paused => True);
   for I in Ids'Range loop
      Jobs.Submit ("x+" & Integer'Image (I), Ids (I), 77,
        Math_Layout.Text_Style, Status => S);
      Check (S = Jobs.Pending, "paused request accepted" & I'Image);
   end loop;
   Jobs.Submit ("overflow", Overflow_Id, 77, Math_Layout.Text_Style,
     Status => S);
   Check (S = Jobs.Busy, "ninth pending request rejected");

   Jobs.Cancel (Ids (Ids'Last), 77);
   Jobs.Poll (Ids (Ids'Last), 77, S, R);
   Check (S = Jobs.Cancelled and R = null,
     "queued cancellation consumed");
   Jobs.Abandon (Ids (1), 77);
   Jobs.Submit ("abandon frees queued slot", Abandoned_Id,
     Abandoned_Generation, Math_Layout.Text_Style, Status => S);
   Check (S = Jobs.Pending, "abandon frees queued capacity");
   Jobs.Abandon (Abandoned_Id, Abandoned_Generation);
   Jobs.Poll (Abandoned_Id, Abandoned_Generation, S, R);
   Check (S = Jobs.Unknown and R = null, "abandoned queued job removed");

   Jobs.Timing (Ids (2), 77, Timing_Value, Timing_Found);
   Check (not Timing_Found,
     "unfinished timing is not reported as finalized");
   Jobs.Timing (Ids (2), 77, Timing_Value, Timing_Found);
   Check (not Timing_Found,
     "timing query does not consume queued job");
   delay 0.3;
   Jobs.Resume;
   for I in 2 .. Ids'Last - 1 loop
      Timing_Found := False;
      for Wait in 1 .. 400 loop
         Jobs.Timing (Ids (I), 77, Timing_Value, Timing_Found);
         exit when Timing_Found;
         delay 0.005;
      end loop;
      Jobs.Poll (Ids (I), 77, S, R);
      Check (S in Jobs.Expired | Jobs.Cancelled,
        "intentionally overdue queued request terminal status" & I'Image);
      if I = 2 then
         Check (Timing_Found and
           Timing_Value.Queue_Milliseconds >= Jobs.Budget_Milliseconds and
           Timing_Value.Total_Milliseconds >= Jobs.Budget_Milliseconds,
           "queue and total timing include paused wait");
      end if;
      if R /= null then
         Check (Jobs.Id (R.all) = Ids (I), "result request id");
         Check (Jobs.Generation (R.all) = 77, "result generation");
         Check (Jobs.Source (R.all) = "x+" & Integer'Image (I),
           "exact source retained");
         Check (Math_Syntax.Is_Valid (Jobs.Parse_Document (R.all)),
           "parsed document retained");
         Check (Jobs.Layout (R.all).Valid and then
           Jobs.Layout (R.all).Commands.Length > 0,
           "layout output retained");
         Check (Math_Semantics.Is_Valid (Jobs.Semantics (R.all)),
           "successful result has valid semantic projection");
         Check (Math_Semantics.Source (Jobs.Semantics (R.all)) =
           Jobs.Source (R.all), "semantic source matches request");
         Check (Math_Syntax.Source (Jobs.Parse_Document (R.all)) =
           Jobs.Source (R.all), "parsed source matches request");
         Jobs.Release (R);
         Check (R = null, "release clears result ownership");
      end if;
      Jobs.Poll (Ids (I), 77, S, R);
      Check (S = Jobs.Unknown and R = null, "poll consumes once");
   end loop;

   Jobs.Shutdown;
   Jobs.Start (Paused => True);
   Late_Invalid_Source (Late_Invalid_Source'Last) := '}';
   Jobs.Submit (Late_Invalid_Source, Ids (1), 93,
     Math_Layout.Text_Style, Status => S);
   delay 0.3;
   Jobs.Resume;
   Timing_Found := False;
   for Wait in 1 .. 400 loop
      Jobs.Timing (Ids (1), 93, Timing_Value, Timing_Found);
      exit when Timing_Found;
      delay 0.005;
   end loop;
   Check (Timing_Found and
     Timing_Value.Queue_Milliseconds >= Jobs.Budget_Milliseconds and
     Timing_Value.Cleanup_Milliseconds <= Timing_Value.Total_Milliseconds,
     "expired invalid outcome retains finalized timing metadata");
   Jobs.Poll (Ids (1), 93, S, R);
   Check (S = Jobs.Expired and R /= null,
     "invalid parse completed after deadline expires");
   if R /= null then
      Jobs.Release (R);
   end if;
   Jobs.Timing (Ids (1), 93, Timing_Value, Timing_Found);
   Check (not Timing_Found,
     "timing metadata follows existing poll-consumption lifetime");

   Jobs.Start;
   Jobs.Submit ("done", Abandoned_Id, Abandoned_Generation,
     Math_Layout.Text_Style, Status => S);
   Check (S = Jobs.Pending, "orphan cleanup request accepted");
   delay 0.1;
   Jobs.Shutdown;
   Jobs.Poll (Abandoned_Id, Abandoned_Generation, S, R);
   Check (S = Jobs.Unknown and R = null,
     "shutdown drains completed orphan result");
   Jobs.Start (Paused => True);
   Jobs.Submit ("x", Ids (1), 88, Math_Layout.Text_Style,
     Status => S);
   Check (S = Jobs.Pending, "post-completion submission accepted");
   Jobs.Poll (Ids (1), 89, S, R);
   Check (S = Jobs.Unknown, "stale generation cannot receive result");
   Jobs.Cancel (Ids (1), 88);
   Jobs.Poll (Ids (1), 88, S, R);
   Check (S = Jobs.Cancelled, "queued cancellation after stale poll");

   Jobs.Shutdown;
   Jobs.Start (Paused => True);
   Jobs.Submit ((1 => Character'Val (16#FF#)), Ids (1), 90,
     Math_Layout.Text_Style, Status => S);
   Check (S = Jobs.Pending, "invalid UTF-8 accepted asynchronously");
   Jobs.Shutdown;
   Jobs.Poll (Ids (1), 90, S, R);
   Check (S = Jobs.Unknown and R = null,
     "shutdown drains cancelled queued request");

   Jobs.Start;
   Jobs.Submit ("x", Ids (1), 91, Math_Layout.Text_Style,
     Status => S);
   Check (S = Jobs.Pending, "restart accepts request");
   Jobs.Shutdown;
   Jobs.Poll (Ids (1), 91, S, R);
   Check (S = Jobs.Unknown and R = null,
     "shutdown joins and drains worker result");
   Jobs.Start (Paused => True);
   Jobs.Submit ("fresh", Ids (1), 92, Math_Layout.Text_Style,
     Status => S);
   Check (S = Jobs.Pending, "restart after drain accepts fresh request");
   Jobs.Shutdown;
   Jobs.Poll (Ids (1), 92, S, R);
   Check (S = Jobs.Unknown and R = null, "restart shutdown drains slot");


   declare
      Corpus_Size : constant Positive := 2_000;
      Cases_Per_Iteration : constant Positive := 200;
      Iterations : constant Positive := 10;
      type Samples is array (Positive range <>) of Natural;
      Queue_Samples : Samples (1 .. Corpus_Size);
      Execution_Samples : Samples (1 .. Corpus_Size);
      Cleanup_Samples : Samples (1 .. Corpus_Size);
      Total_Samples : Samples (1 .. Corpus_Size);
      Request_Samples : Samples (1 .. Corpus_Size);
      Accepted : array (1 .. Jobs.Queue_Capacity) of Jobs.Request_Id;
      Accepted_Count : Natural := 0;
      Corpus_Valid : Natural := 0;
      Busy_Count : Natural := 0;

      procedure Sort (Values : in out Samples) is
      begin
         for I in Values'First + 1 .. Values'Last loop
            declare
               Value : constant Natural := Values (I);
               Position : Natural := I;
            begin
               while Position > Values'First and then
                 Values (Position - 1) > Value
               loop
                  Values (Position) := Values (Position - 1);
                  Position := Position - 1;
               end loop;
               Values (Position) := Value;
            end;
         end loop;
      end Sort;

      function P95 (Values : Samples) return Natural is
         Index : constant Positive := (Values'Length * 95 + 99) / 100;
      begin
         return Values (Values'First + Index - 1);
      end P95;

      function Maximum (Values : Samples) return Natural is
         Result : Natural := 0;
      begin
         for Value of Values loop
            Result := Natural'Max (Result, Value);
         end loop;
         return Result;
      end Maximum;

      function Formula (Index : Positive) return String is
      begin
         case Index mod 20 is
            when 0 => return "x+y";
            when 1 => return "\frac{a}{b}";
            when 2 => return "\sqrt{x+1}";
            when 3 => return "x_1^2";
            when 4 => return "\left(a+b\right)";
            when 5 => return "\sum_{i=1}^{n} i";
            when 6 => return "\int_0^1 x dx";
            when 7 => return "\alpha+\beta";
            when 8 => return "\text{warm sample}";
            when 9 => return "a\cdot b";
            when 10 => return "\frac{x^2+1}{y}";
            when 11 => return "\log(x)";
            when 12 => return "\sin(\theta)";
            when 13 => return "\lim_{x\to 0} x";
            when 14 => return "\overline{AB}";
            when 15 => return "\vec{v}";
            when 16 => return "\begin{matrix}a&b\\c&d\end{matrix}";
            when 17 => return "\binom{n}{k}";
            when 18 => return "\textcolor{red}{x}";
            when others => return "\underbrace{x+y}_{z}";
---
         end case;
      end Formula;

      Started_At : Ada.Real_Time.Time;
      Id : Jobs.Request_Id;
      Result : Jobs.Result_Access;
      Status : Jobs.Job_Status;
      Timing : Jobs.Job_Timing;
      Found : Boolean;
   begin
      Jobs.Start;
      for I in 1 .. Iterations * Cases_Per_Iteration loop
         Started_At := Ada.Real_Time.Clock;
         Jobs.Submit
           (Formula ((I - 1) mod Cases_Per_Iteration + 1) & "+x_" &
              Integer'Image ((I - 1) mod Cases_Per_Iteration + 1),
            Id, 94, Math_Layout.Display_Style, Status => Status);
         if Status = Jobs.Pending then
            Found := False;
            for Wait in 1 .. 1_000 loop
               Jobs.Timing (Id, 94, Timing, Found);
               exit when Found;
               delay 0.001;
            end loop;
            if Found then
               Queue_Samples (I) := Timing.Queue_Milliseconds;
               Execution_Samples (I) := Timing.Execution_Milliseconds;
               Cleanup_Samples (I) := Timing.Cleanup_Milliseconds;
               Total_Samples (I) := Timing.Total_Milliseconds;
               Jobs.Poll (Id, 94, Status, Result);
               Request_Samples (I) := Natural
                 (Ada.Real_Time.To_Duration
                    (Ada.Real_Time.Clock - Started_At) * 1_000.0);
               if Status = Jobs.Valid and then Result /= null then
                  Corpus_Valid := Corpus_Valid + 1;
               else
                  Ada.Text_IO.Put_Line
                    ("WARM_INVALID index=" & I'Image & " status=" &
                     Jobs.Job_Status'Image (Status) & " source=[" &
                     Formula ((I - 1) mod Cases_Per_Iteration + 1) &
                     "+x_" & Integer'Image
                       ((I - 1) mod Cases_Per_Iteration + 1) & "]");
                  if Result /= null then
                     Ada.Text_IO.Put_Line
                       ("WARM_INVALID_ERROR=" &
                        Math_Syntax.Error (Jobs.Parse_Document (Result.all)));
                  end if;
               end if;
               if Result /= null then
                  Jobs.Release (Result);
               end if;
            else
               Queue_Samples (I) := Natural'Last;
               Execution_Samples (I) := Natural'Last;
               Cleanup_Samples (I) := Natural'Last;
               Total_Samples (I) := Natural'Last;
               Request_Samples (I) := Natural'Last;
            end if;
         else
            Queue_Samples (I) := Natural'Last;
            Execution_Samples (I) := Natural'Last;
            Cleanup_Samples (I) := Natural'Last;
            Total_Samples (I) := Natural'Last;
            Request_Samples (I) := Natural'Last;
         end if;
      end loop;
      Sort (Queue_Samples);
      Sort (Execution_Samples);
      Sort (Cleanup_Samples);
      Sort (Total_Samples);
      Sort (Request_Samples);
      Ada.Text_IO.Put_Line
        ("WARM cases=200 iterations=10 requests=2000 valid=" &
         Natural'Image (Corpus_Valid) &
         " request_ms_p95=" & Natural'Image (P95 (Request_Samples)) &
         " request_ms_max=" & Natural'Image (Maximum (Request_Samples)));
      Ada.Text_IO.Put_Line
        ("WARM job_queue_ms_p95=" & Natural'Image (P95 (Queue_Samples)) &
         " max=" & Natural'Image (Maximum (Queue_Samples)) &
         " execution_ms_p95=" & Natural'Image (P95 (Execution_Samples)) &
         " max=" & Natural'Image (Maximum (Execution_Samples)) &
         " cleanup_ms_p95=" & Natural'Image (P95 (Cleanup_Samples)) &
         " max=" & Natural'Image (Maximum (Cleanup_Samples)) &
         " total_ms_p95=" & Natural'Image (P95 (Total_Samples)) &
         " max=" & Natural'Image (Maximum (Total_Samples)));
      Check (Corpus_Valid = Corpus_Size,
        "all warm representative jobs return valid results");
      Check (P95 (Request_Samples) <= 50 and
        Maximum (Request_Samples) <= 250 and
        P95 (Queue_Samples) <= 50 and Maximum (Queue_Samples) <= 250 and
        P95 (Execution_Samples) <= 50 and
        Maximum (Execution_Samples) <= 250 and
        P95 (Cleanup_Samples) <= 50 and
        Maximum (Cleanup_Samples) <= 250 and
        P95 (Total_Samples) <= 50 and Maximum (Total_Samples) <= 250,
        "warm corpus job timing and request latency within target");
      Check (Maximum (Queue_Samples) /= Natural'Last and
        Maximum (Execution_Samples) /= Natural'Last and
        Maximum (Cleanup_Samples) /= Natural'Last and
        Maximum (Total_Samples) /= Natural'Last,
        "warm corpus has finalized job timing records");
      Jobs.Shutdown;

      Jobs.Start (Paused => True);
      for I in Accepted'Range loop
         Jobs.Submit ("x+" & Integer'Image (I), Accepted (I), 95,
           Math_Layout.Text_Style, Status => Status);
         if Status = Jobs.Pending then
            Accepted_Count := Accepted_Count + 1;
         end if;
      end loop;
      for I in 1 .. Jobs.Worker_Count loop
         Jobs.Submit ("saturated" & Integer'Image (I), Id, 95,
           Math_Layout.Text_Style, Status => Status);
         if Status = Jobs.Busy then
            Busy_Count := Busy_Count + 1;
         end if;
      end loop;
      Ada.Text_IO.Put_Line
        ("SATURATION accepted=" & Natural'Image (Accepted_Count) &
         " busy=" & Natural'Image (Busy_Count) &
         " requested=10 workers=" & Natural'Image (Jobs.Worker_Count));
      Check (Accepted_Count = Jobs.Queue_Capacity and Busy_Count = 2,
        "eight queued jobs accepted and two excess jobs rejected");
      Jobs.Resume;
      for I in Accepted'Range loop
         Found := False;
         for Wait in 1 .. 1_000 loop
            Jobs.Timing (Accepted (I), 95, Timing, Found);
            exit when Found;
            delay 0.001;
         end loop;
         Jobs.Poll (Accepted (I), 95, Status, Result);
         if Result /= null then
            Jobs.Release (Result);
         end if;
         Check (Found and Status = Jobs.Valid,
           "saturated request completes with finalized timing" & I'Image);
      end loop;
      Jobs.Shutdown;
   end;

   Ada.Text_IO.Put_Line ("ASSERTIONS" & Natural'Image (Checks) &
     " failures=" & Natural'Image (Failures));
---
   if Checks < 63 or Failures /= 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Math_Jobs_Probe;
