with Ada.Command_Line;
with Ada.Real_Time;
with Ada.Containers;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Ada.Unchecked_Conversion;
with Interfaces;
with Math_Raster;
with Math_Raster_Budget;
with Math_Memory_Budget;
with Math_Source;
with Math_Tokens;
with Coyote_Math_Jobs;
with Math_Layout;
with Math_Syntax;
with Math_Semantics;
with Math_Painter;
procedure Math_Jobs_Probe is
   function Long_Float_From_Bits is new Ada.Unchecked_Conversion
     (Interfaces.Unsigned_64, Long_Float);
   package Jobs renames Coyote_Math_Jobs;
   use type Jobs.Job_Status;
   use type Jobs.Request_Id;
   use type Jobs.View_Generation;
   use type Jobs.Result_Access;
   use type Ada.Containers.Count_Type;
   use type Interfaces.Unsigned_32;
   use type Ada.Real_Time.Time;

   function Expansion_Request return String is
      use Ada.Strings.Unbounded;
      Result : Unbounded_String;
      Previous : Character := 'a';
   begin
      Append (Result, "\def\a{x}");
      for Index in 1 .. 7 loop
         declare
            Current : constant Character := Character'Val
              (Character'Pos ('a') + Index);
         begin
            Append (Result, "\def\" & Current & "{\" & Previous &
              "\" & Previous & "}");
            Previous := Current;
         end;
      end loop;
      Append (Result, "\" & Previous);
      return To_String (Result);
   end Expansion_Request;

   function Lexical_Charge_Bound (Text : String) return Natural is
      Width : constant Positive := Math_Tokens.Token'Size / 8;
      Map_Bound : constant Natural := Math_Source.Map_Storage_Bound
        (Natural'Max (1, Text'Length));
      Token_Bound : constant Natural :=
        Math_Tokens.Transformation_Token_Bound (Text'Length);
   begin
      return 2 * Map_Bound + (3 * Token_Bound + 1) * Width;
   end Lexical_Charge_Bound;

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

   function Matches_Raster
     (Result : Jobs.Result_Access; Reference : Math_Raster.Image)
      return Boolean
   is
      Matches : Boolean :=
        Jobs.Raster_Width (Result.all) = Math_Raster.Width (Reference) and
        Jobs.Raster_Height (Result.all) = Math_Raster.Height (Reference);
   begin
      if Matches then
         for Y in 0 .. Math_Raster.Height (Reference) - 1 loop
            for X in 0 .. Math_Raster.Width (Reference) - 1 loop
               Matches := Matches and then
                 Jobs.Raster_Pixel (Result.all, X, Y) =
                   Math_Raster.Get_Pixel (Reference, X, Y);
            end loop;
         end loop;
      end if;
      return Matches;
   end Matches_Raster;

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
   declare
      First_Lease : Math_Raster_Budget.Lease;
      Second_Lease : Math_Raster_Budget.Lease;
      First_Accepted : Boolean;
      Second_Accepted : Boolean;
   begin
      Math_Raster_Budget.Reserve (100, First_Lease, First_Accepted);
      Math_Raster_Budget.Reserve (200, Second_Lease, Second_Accepted);
      Check (First_Accepted and Second_Accepted,
        "distinct raster leases reserve independently");
      Math_Raster_Budget.Release (First_Lease);
      Math_Raster_Budget.Release (First_Lease);
      Check (Math_Raster_Budget.Used = 200,
        "duplicate release leaves another owner's charge intact");
      Math_Raster_Budget.Release (Second_Lease);
      Check (Math_Raster_Budget.Used = 0,
        "all lease owners release to baseline");
   end;
   Check (Font_Directory'Length > 0, "trusted font directory supplied");
   Jobs.Start (Paused => True);
   declare
      Failed_Font_Id : Jobs.Request_Id;
      Recovery_Id : Jobs.Request_Id;
      Failed_Font_Status : Jobs.Job_Status;
      Recovery_Status : Jobs.Job_Status;
      Failed_Font_Result : Jobs.Result_Access;
      Recovery_Result : Jobs.Result_Access;
      Missing_Font_Directory : constant String :=
        "/tmp/coyote-parser-budget-jobs-missing-fonts";
   begin
      Jobs.Submit ("x+y", Failed_Font_Id, 300,
        Math_Layout.Display_Style, Status => Failed_Font_Status,
        Request_Raster => True, Em_Pixels => 24.0,
        Font_Directory => Missing_Font_Directory);
      Check (Failed_Font_Status = Jobs.Pending,
        "missing-font request queues after valid request checks");
      Jobs.Resume;
      for Wait in 1 .. 400 loop
         Jobs.Poll
           (Failed_Font_Id, 300, Failed_Font_Status, Failed_Font_Result);
         exit when Failed_Font_Status /= Jobs.Pending;
         delay 0.005;
      end loop;
      Check (Failed_Font_Status = Jobs.Failed and
        Failed_Font_Result /= null,
        "post-parse font load failure returns failed result");
      if Failed_Font_Result /= null then
         Check (Jobs.Parse_Workspace_Peak_Bytes
           (Failed_Font_Result.all) > 0,
           "font-load failure preserves parser workspace peak");
         Check (Jobs.Raster_Workspace_Peak_Bytes
           (Failed_Font_Result.all) = 0 and
           Jobs.Pipeline_Workspace_Peak_Bytes
             (Failed_Font_Result.all) =
               Jobs.Parse_Workspace_Peak_Bytes
                 (Failed_Font_Result.all),
           "font-load failure reports parse-only pipeline peak");
         Check (not Jobs.Has_Raster (Failed_Font_Result.all) and
           Jobs.Raster_Width (Failed_Font_Result.all) = 0 and
           Jobs.Raster_Height (Failed_Font_Result.all) = 0 and
           Jobs.Raster_Retained_Bytes (Failed_Font_Result.all) = 0 and
           Math_Raster_Budget.Used = 0,
           "font-load failure retains no pixels or raster charge");
         Jobs.Release (Failed_Font_Result);
      end if;
      Jobs.Submit ("x+y", Recovery_Id, 300,
        Math_Layout.Display_Style, Status => Recovery_Status,
        Request_Raster => True, Em_Pixels => 24.0,
        Font_Directory => Font_Directory);
      Check (Recovery_Status = Jobs.Pending,
        "valid font recovery request queues");
      for Wait in 1 .. 400 loop
         Jobs.Poll (Recovery_Id, 300, Recovery_Status, Recovery_Result);
         exit when Recovery_Status /= Jobs.Pending;
         delay 0.005;
      end loop;
      Check (Recovery_Status = Jobs.Valid and Recovery_Result /= null,
        "valid raster job recovers after font-load failure");
      if Recovery_Result /= null then
         Jobs.Release (Recovery_Result);
      end if;
      Check (Math_Raster_Budget.Used = 0,
        "font failure and recovery leave raster ledger empty");
   end;
   declare
      Expansion_Id : Jobs.Request_Id;
      Expansion_Status : Jobs.Job_Status;
      Expansion_Result : Jobs.Result_Access;
      Expansion_Text : constant String := Expansion_Request;
      Direct_Memory : aliased Math_Memory_Budget.Budget;
      Direct_Options : constant Math_Syntax.Options :=
        (Display_Mode => True, others => <>);
      Direct_Document : constant Math_Syntax.Document := Math_Syntax.Parse
        (Expansion_Text, Direct_Options,
         Memory => Direct_Memory'Unchecked_Access);
      Direct_Peak : constant Natural :=
        Math_Memory_Budget.Peak (Direct_Memory);
   begin
      Check (Math_Syntax.Is_Valid (Direct_Document) and
        Math_Syntax.Count (Direct_Document) >= 128,
        "direct macro expansion produces a valid 128-glyph AST");
      Check (Direct_Peak > Lexical_Charge_Bound (Expansion_Text),
        "direct parser peak exceeds conservative lexical bound");
      Jobs.Submit (Expansion_Text, Expansion_Id, 300,
        Math_Layout.Display_Style, Status => Expansion_Status,
        Request_Raster => False);
      Check (Expansion_Status = Jobs.Pending,
        "non-raster expansion request queues");
      for Wait in 1 .. 400 loop
         Jobs.Poll
           (Expansion_Id, 300, Expansion_Status, Expansion_Result);
         exit when Expansion_Status /= Jobs.Pending;
         delay 0.005;
      end loop;
      Check (Expansion_Status = Jobs.Valid and Expansion_Result /= null,
        "non-raster macro expansion completes successfully");
      if Expansion_Result /= null then
         Check (Math_Syntax.Is_Valid
           (Jobs.Parse_Document (Expansion_Result.all)) and
           Math_Syntax.Count (Jobs.Parse_Document (Expansion_Result.all)) >=
             128,
           "worker returns valid 128-glyph AST");
         Check (Jobs.Parse_Workspace_Peak_Bytes
           (Expansion_Result.all) = Direct_Peak,
           "worker parser peak matches direct parse peak");
         Check (Jobs.Pipeline_Workspace_Peak_Bytes
           (Expansion_Result.all) =
             Jobs.Parse_Workspace_Peak_Bytes (Expansion_Result.all) and
           Jobs.Raster_Workspace_Peak_Bytes (Expansion_Result.all) = 0,
           "non-raster pipeline reports parse peak and no raster workspace");
         Check (not Jobs.Has_Raster (Expansion_Result.all) and
           Jobs.Raster_Retained_Bytes (Expansion_Result.all) = 0 and
           Math_Raster_Budget.Used = 0,
           "non-raster expansion retains no raster charge");
         Jobs.Release (Expansion_Result);
      end if;
   end;
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
      Mixed_Source : Ada.Strings.Unbounded.Unbounded_String;
   begin
      for Glyph_Group in 1 .. 120 loop
         Ada.Strings.Unbounded.Append
           (Mixed_Source, "x+\textcolor{blue}{y}");
      end loop;
      for Iteration in 1 .. 3 loop
         declare
            Mixed_Id : Jobs.Request_Id;
            Mixed_Status : Jobs.Job_Status;
            Mixed_Result : Jobs.Result_Access;
            Expected_Red : constant Long_Float :=
              (if Iteration mod 2 = 1 then 1.0 else 0.0);
            Expected_Green : constant Long_Float :=
              (if Iteration mod 2 = 1 then 0.0 else 1.0);
            Fallback_Count : Natural := 0;
            Blue_Count : Natural := 0;
            Uncolored_Count : Natural := 0;
         begin
            Jobs.Submit
              (Ada.Strings.Unbounded.To_String (Mixed_Source), Mixed_Id,
               Jobs.View_Generation (310 + Iteration),
               Math_Layout.Text_Style,
               Color_Enabled => True,
               Color =>
                 (Red => Expected_Red, Green => Expected_Green,
                  Blue => 0.0, Alpha => 1.0),
               Status => Mixed_Status, Request_Raster => False);
            Check (Mixed_Status = Jobs.Pending,
              "large mixed-color non-raster request queued" &
                Iteration'Image);
            for Wait in 1 .. 400 loop
               if Mixed_Status = Jobs.Pending then
                  Jobs.Poll (Mixed_Id,
                    Jobs.View_Generation (310 + Iteration), Mixed_Status,
                    Mixed_Result);
               end if;
               exit when Mixed_Status /= Jobs.Pending;
               delay 0.005;
            end loop;
            Check (Mixed_Status = Jobs.Valid and Mixed_Result /= null,
              "large mixed-color worker result valid" & Iteration'Image);
            if Mixed_Result /= null then
               for I in Jobs.Layout (Mixed_Result.all).Commands.First_Index ..
                 Jobs.Layout (Mixed_Result.all).Commands.Last_Index
               loop
                  declare
                     Command : constant Math_Layout.Draw_Command :=
                       Jobs.Layout (Mixed_Result.all).Commands (I);
                  begin
                     if not Command.Has_Color then
                        Uncolored_Count := Uncolored_Count + 1;
                     elsif Command.Red = Expected_Red and then
                       Command.Green = Expected_Green and then
                       Command.Blue = 0.0 and then Command.Alpha = 1.0
                     then
                        Fallback_Count := Fallback_Count + 1;
                     elsif Command.Red = 0.0 and then
                       Command.Green = 0.0 and then
                       Command.Blue = 1.0 and then Command.Alpha = 1.0
                     then
                        Blue_Count := Blue_Count + 1;
                     end if;
                  end;
               end loop;
               Check (Jobs.Layout (Mixed_Result.all).Commands.Length = 360 and
                 Fallback_Count = 240 and Blue_Count = 120 and
                 Uncolored_Count = 0,
                 "all 360 commands retain fallback/explicit colors" &
                   Iteration'Image);
               Check (Jobs.Source (Mixed_Result.all) =
                 Ada.Strings.Unbounded.To_String (Mixed_Source),
                 "large mixed-color result preserves exact source" &
                   Iteration'Image);
               Check (not Jobs.Has_Raster (Mixed_Result.all) and
                 Jobs.Raster_Width (Mixed_Result.all) = 0 and
                 Jobs.Raster_Height (Mixed_Result.all) = 0 and
                 Jobs.Raster_Retained_Bytes (Mixed_Result.all) = 0 and
                 Math_Raster_Budget.Used = 0,
                 "non-raster color integration retains no raster storage" &
                   Iteration'Image);
               Jobs.Release (Mixed_Result);
               Check (Mixed_Result = null,
                 "mixed-color result release clears access" &
                   Iteration'Image);
            end if;
            Check (Math_Raster_Budget.Used = 0,
              "repeated mixed-color request leaves raster ledger empty" &
                Iteration'Image);
         end;
      end loop;
   end;
   declare
      Raster_Id : Jobs.Request_Id;
      Inline_Id : Jobs.Request_Id;
      Default_Id : Jobs.Request_Id;
      Inline_Result : Jobs.Result_Access;
      Default_Result : Jobs.Result_Access;
      Inline_Status : Jobs.Job_Status;
      Default_Status : Jobs.Job_Status;
      Raster_Status : Jobs.Job_Status;
      Raster_Result : Jobs.Result_Access;
      Raster_Has_Color : Boolean := False;
      Bad_Scale_Id : Jobs.Request_Id;
      Bad_Scale_Status : Jobs.Job_Status;
      Missing_Font_Id : Jobs.Request_Id;
      Missing_Font_Status : Jobs.Job_Status;
   begin
      if Long_Float'Size = 64 and then
        Long_Float'Machine_Radix = 2 and then
        Long_Float'Machine_Mantissa = 53 and then
        Long_Float'Machine_Emax = 1024
      then
         declare
            Scale_Bits : constant array (Positive range 1 .. 3) of
              Interfaces.Unsigned_64 :=
                (16#7FF8_0000_0000_0001#,
                 16#7FF0_0000_0000_0000#,
                 16#FFF0_0000_0000_0000#);
            Scale_Names : constant array (Scale_Bits'Range) of
              String (1 .. 8) :=
              ("NaN     ", "+Inf    ", "-Inf    ");
         begin
            --  IEEE-754 binary64 fixtures: quiet NaN, positive and negative
            --  infinity. Pin GNAT validity behavior on this binary64 host.
            for I in Scale_Bits'Range loop
               declare
                  Scale : constant Long_Float :=
                    Long_Float_From_Bits (Scale_Bits (I));
               begin
                  Check (not Scale'Valid,
                    "binary64 " & Scale_Names (I) & " is invalid scalar");
                  Jobs.Submit ("x", Bad_Scale_Id, 304,
                    Math_Layout.Text_Style, Status => Bad_Scale_Status,
                    Request_Raster => True, Em_Pixels => Scale,
                    Font_Directory => Font_Directory);
                  Check (Bad_Scale_Status = Jobs.Invalid and
                    Bad_Scale_Id = 0 and Math_Raster_Budget.Used = 0,
                    "binary64 " & Scale_Names (I) &
                      " rejected synchronously without reservation");
               end;
            end loop;
         end;
      else
         Ada.Text_IO.Put_Line
           ("SKIP IEEE binary64 scale fixtures: incompatible Long_Float");
      end if;
      declare
         Boundary_Scales : constant array (Positive range 1 .. 4) of
           Long_Float := (0.0, -1.0, 256.0001, 257.0);
      begin
         for Scale of Boundary_Scales loop
            Jobs.Submit ("x", Bad_Scale_Id, 304, Math_Layout.Text_Style,
              Status => Bad_Scale_Status, Request_Raster => True,
              Em_Pixels => Scale, Font_Directory => Font_Directory);
            Check (Bad_Scale_Status = Jobs.Invalid and Bad_Scale_Id = 0 and
              Math_Raster_Budget.Used = 0,
              "non-positive or above-256 raster scale rejected synchronously");
         end loop;
      end;
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
      Jobs.Submit ("x+y", Raster_Id, 303, Math_Layout.Display_Style,
        Color_Enabled => True,
        Color => (Red => 0.2, Green => 0.1, Blue => 0.05, Alpha => 1.0),
        Status => Raster_Status, Request_Raster => True,
        Em_Pixels => 24.0, Font_Directory => Font_Directory,
        Fleqn => True);
      Check (Raster_Status = Jobs.Pending, "raster request queued");
      Jobs.Submit ("x+y", Default_Id, 303, Math_Layout.Display_Style,
        Status => Default_Status);
      Jobs.Submit ("x+y", Inline_Id, 303, Math_Layout.Text_Style,
        Status => Inline_Status, Fleqn => True);
      for Wait in 1 .. 400 loop
         Jobs.Poll (Raster_Id, 303, Raster_Status, Raster_Result);
         exit when Raster_Status /= Jobs.Pending;
         delay 0.005;
      end loop;
      Check (Raster_Status = Jobs.Valid and Raster_Result /= null,
        "requested raster completes valid");
      if Raster_Result /= null then
         declare
            Fleqn_Box : constant Math_Layout.Box :=
              Jobs.Layout (Raster_Result.all);
         begin
            Check (Fleqn_Box.Left_Aligned and Fleqn_Box.Left_Indent = 2.0,
              "display Fleqn carries two-em immutable alignment metadata");
            Check (Fleqn_Box.Width > 0.0,
              "display Fleqn preserves nonzero formula width");
         end;
         Check (Jobs.Has_Raster (Raster_Result.all),
           "owned raster reported available");
         Check (Jobs.Raster_Retained_Bytes (Raster_Result.all) > 0,
           "result retention records rendered raster storage");
         Check (Math_Raster_Budget.Used =
           Jobs.Raster_Retained_Bytes (Raster_Result.all),
           "published raster result remains charged");
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
         Check (Math_Raster_Budget.Used = 0,
           "result release returns retained raster bytes to baseline");
      end if;
      for Wait in 1 .. 400 loop
         Jobs.Poll (Default_Id, 303, Default_Status, Default_Result);
         Jobs.Poll (Inline_Id, 303, Inline_Status, Inline_Result);
         exit when Default_Status /= Jobs.Pending and
           Inline_Status /= Jobs.Pending;
         delay 0.005;
      end loop;
      Check (Default_Status = Jobs.Valid and Default_Result /= null,
        "default display job remains valid");
      Check (Inline_Status = Jobs.Valid and Inline_Result /= null,
        "inline request remains valid with Fleqn requested");
      Jobs.Submit ("x+y", Raster_Id, 306, Math_Layout.Display_Style,
        Status => Raster_Status, Request_Raster => True,
        Em_Pixels => 24.0, Font_Directory => Font_Directory);
      for Wait in 1 .. 400 loop
         if Raster_Status = Jobs.Pending then
            Jobs.Poll (Raster_Id, 306, Raster_Status, Raster_Result);
         end if;
         exit when Raster_Status /= Jobs.Pending;
         delay 0.005;
      end loop;
      Check (Raster_Status = Jobs.Valid and then
        Raster_Result /= null and then Jobs.Has_Raster (Raster_Result.all),
        "ordinary raster recovers after invalid-scale rejection");
      if Raster_Result /= null then
         Jobs.Release (Raster_Result);
      end if;
      Check (Math_Raster_Budget.Used = 0,
        "scale rejection and valid recovery leave empty raster ledger");
      if Default_Result /= null then
         Check (not Jobs.Layout (Default_Result.all).Left_Aligned and
           Jobs.Layout (Default_Result.all).Left_Indent = 0.0,
           "default display alignment metadata remains centered");
         Jobs.Release (Default_Result);
      end if;
      if Inline_Result /= null then
         Check (not Jobs.Layout (Inline_Result.all).Left_Aligned and
           Jobs.Layout (Inline_Result.all).Left_Indent = 0.0,
           "inline Fleqn request does not change alignment");
         Jobs.Release (Inline_Result);
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
     "cancel-before-resume consumes without worker result");
   Jobs.Submit ("overflow", Overflow_Id, 77, Math_Layout.Text_Style,
     Status => S);
   Check (S = Jobs.Pending,
     "exact prior Busy request retries after cancelled slot is consumed");
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
   Jobs.Resume;
   for I in 2 .. Ids'Last - 1 loop
      Timing_Found := False;
      for Wait in 1 .. 400 loop
         Jobs.Timing (Ids (I), 77, Timing_Value, Timing_Found);
         exit when Timing_Found;
         delay 0.005;
      end loop;
      Jobs.Poll (Ids (I), 77, S, R);
      Check (S = Jobs.Valid and R /= null,
        "resumed queued request completes successfully" & I'Image);
      if I = 2 then
         Check (Timing_Found,
           "completed queue timing is available after resume");
      end if;
      if R /= null then
         Check (Jobs.Id (R.all) = Ids (I), "result request id");
         Check (Jobs.Generation (R.all) = 77, "result generation");
         Check (Jobs.Source (R.all) = "x+" & Integer'Image (I),
           "exact source retained");
         Check (Math_Syntax.Is_Valid (Jobs.Parse_Document (R.all)),
           "parsed document retained");
         Check (Jobs.Parse_Workspace_Peak_Bytes (R.all) > 0,
           "non-raster job reports parser workspace peak");
         Check (Jobs.Pipeline_Workspace_Peak_Bytes (R.all) =
           Jobs.Parse_Workspace_Peak_Bytes (R.all),
           "non-raster pipeline peak equals parser-only peak");
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
   Timing_Found := False;
   for Wait in 1 .. 400 loop
      Jobs.Timing (Overflow_Id, 77, Timing_Value, Timing_Found);
      exit when Timing_Found;
      delay 0.001;
   end loop;
   Jobs.Poll (Overflow_Id, 77, S, R);
   Check (Timing_Found and then S = Jobs.Valid and then R /= null and then
     Jobs.Source (R.all) = "overflow",
     "retried Busy request completes with exact source and timing");
   if R /= null then
      Jobs.Release (R);
   end if;

   Jobs.Shutdown;
   Jobs.Start (Paused => True);
   Late_Invalid_Source (Late_Invalid_Source'Last) := '}';
   Jobs.Submit (Late_Invalid_Source, Ids (1), 93,
     Math_Layout.Text_Style, Status => S);
   Check (S = Jobs.Pending, "paused invalid expiry request accepted");
   Jobs.Submit ("x+1", Ids (2), 93, Math_Layout.Text_Style, Status => S);
   Check (S = Jobs.Pending, "paused valid expiry request accepted");
   delay 0.3;
   Jobs.Resume;
   for I in 1 .. 2 loop
      Timing_Found := False;
      for Wait in 1 .. 400 loop
         Jobs.Timing (Ids (I), 93, Timing_Value, Timing_Found);
         exit when Timing_Found;
         delay 0.005;
      end loop;
      Check (Timing_Found and
        Timing_Value.Queue_Milliseconds >= Jobs.Budget_Milliseconds and
        Timing_Value.Cleanup_Milliseconds <= Timing_Value.Total_Milliseconds,
        "expired queued outcome retains finalized timing metadata" & I'Image);
      Jobs.Poll (Ids (I), 93, S, R);
      Check (S = Jobs.Expired and R = null,
        "overdue queued request skipped before parse" & I'Image);
   end loop;
   Jobs.Timing (Ids (1), 93, Timing_Value, Timing_Found);
   Check (not Timing_Found,
     "timing metadata follows existing poll-consumption lifetime");

   Jobs.Start;
   declare
      Large_Source : String (1 .. Math_Syntax.Max_Source_Bytes) :=
        (others => 'x');
   begin
      Jobs.Submit (Large_Source, Ids (1), 94,
        Math_Layout.Text_Style, Status => S);
   end;
   Check (S = Jobs.Pending,
     "large-source cancellation request accepted");
   Jobs.Cancel (Ids (1), 94);
   R := null;
   for Wait in 1 .. 400 loop
      Jobs.Poll (Ids (1), 94, S, R);
      exit when S /= Jobs.Pending;
      delay 0.005;
   end loop;
   Check (S = Jobs.Cancelled and R = null,
     "cancelled large-source work publishes no result");
   Jobs.Release (R);

   Jobs.Start;
   declare
      Horizontal_Id : Jobs.Request_Id;
      Vertical_Id : Jobs.Request_Id;
      Horizontal_Status : Jobs.Job_Status;
      Vertical_Status : Jobs.Job_Status;
      Horizontal_Result : Jobs.Result_Access;
      Vertical_Result : Jobs.Result_Access;
      Fonts : aliased Math_Painter.Font_Set;
      Horizontal_Layout : Math_Layout.Box;
      Vertical_Layout : Math_Layout.Box;
      Horizontal_Bounds : Math_Raster.Raster_Bounds;
      Vertical_Bounds : Math_Raster.Raster_Bounds;
      Settings : Math_Layout.Layout_Settings := (others => <>);
   begin
      Jobs.Submit ("\cancel{TT}", Horizontal_Id, 96,
        Math_Layout.Text_Style, Status => Horizontal_Status,
        Request_Raster => True, Em_Pixels => 48.0,
        Font_Directory => Font_Directory);
      Jobs.Submit ("\cancel{T}", Vertical_Id, 96,
        Math_Layout.Text_Style, Status => Vertical_Status,
        Request_Raster => True, Em_Pixels => 48.0,
        Font_Directory => Font_Directory);
      Check (Horizontal_Status = Jobs.Pending and
        Vertical_Status = Jobs.Pending,
        "horizontal and vertical cancel raster jobs queued");
      for Wait in 1 .. 400 loop
         if Horizontal_Status = Jobs.Pending then
            Jobs.Poll
              (Horizontal_Id, 96, Horizontal_Status, Horizontal_Result);
         end if;
         if Vertical_Status = Jobs.Pending then
            Jobs.Poll (Vertical_Id, 96, Vertical_Status, Vertical_Result);
         end if;
         exit when Horizontal_Status /= Jobs.Pending and
           Vertical_Status /= Jobs.Pending;
         delay 0.005;
      end loop;
      Check (Horizontal_Status = Jobs.Valid and
        Horizontal_Result /= null,
        "double-T cancellation raster completes");
      Check (Vertical_Status = Jobs.Valid and Vertical_Result /= null,
        "single-T cancellation raster completes");
      Math_Painter.Load (Fonts, Font_Directory);
      Settings.Pixel_Em := 48.0;
      Settings.Advance_Source := Fonts'Unchecked_Access;
      Horizontal_Layout := Math_Layout.Build
        (Math_Syntax.Parse ("\cancel{TT}"), Math_Layout.Text_Style,
         Settings);
      Vertical_Layout := Math_Layout.Build
        (Math_Syntax.Parse ("\cancel{T}"), Math_Layout.Text_Style,
         Settings);
      Horizontal_Bounds := Math_Raster.Measure
        (Horizontal_Layout, 48.0);
      Vertical_Bounds := Math_Raster.Measure (Vertical_Layout, 48.0);
      Check (Horizontal_Layout.Valid and Vertical_Layout.Valid,
        "measured cancellation reference layouts are valid");
      if Horizontal_Result /= null then
         declare
            Reference : constant Math_Raster.Image := Math_Raster.Render
              (Fonts, Horizontal_Layout, 48.0,
               (Red => 0.0, Green => 0.0, Blue => 0.0, Alpha => 1.0));
         begin
            Check (Matches_Raster (Horizontal_Result, Reference),
              "double-T worker pixels exactly match direct render");
         end;
         Check (Jobs.Layout (Horizontal_Result.all).Width =
           Horizontal_Layout.Width and
           Jobs.Layout (Horizontal_Result.all).Ascent =
             Horizontal_Layout.Ascent and
           Jobs.Layout (Horizontal_Result.all).Descent =
             Horizontal_Layout.Descent,
           "double-T returned geometry matches direct measured layout");
         Check (Jobs.Raster_Origin_X (Horizontal_Result.all) > 0,
           "double-T cancellation independently exercises positive X origin");
         Check (Jobs.Raster_Origin_X (Horizontal_Result.all) =
           Horizontal_Bounds.Origin_X and
           Jobs.Raster_Origin_Y (Horizontal_Result.all) =
             Horizontal_Bounds.Origin_Y and
           Jobs.Raster_Width (Horizontal_Result.all) =
             Horizontal_Bounds.Width and
           Jobs.Raster_Height (Horizontal_Result.all) =
             Horizontal_Bounds.Height,
           "double-T origins and dimensions match measured returned geometry");
         Check (Jobs.Raster_Baseline (Horizontal_Result.all) =
           Horizontal_Bounds.Origin_Y + Natural
             (Long_Float'Ceiling
                (Jobs.Layout (Horizontal_Result.all).Ascent * 48.0)),
           "double-T baseline uses measured Y origin and ceiled ascent");
      end if;
      if Vertical_Result /= null then
         declare
            Reference : constant Math_Raster.Image := Math_Raster.Render
              (Fonts, Vertical_Layout, 48.0,
               (Red => 0.0, Green => 0.0, Blue => 0.0, Alpha => 1.0));
         begin
            Check (Matches_Raster (Vertical_Result, Reference),
              "single-T worker pixels exactly match direct render");
         end;
         Check (Jobs.Layout (Vertical_Result.all).Width =
           Vertical_Layout.Width and
           Jobs.Layout (Vertical_Result.all).Ascent =
             Vertical_Layout.Ascent and
           Jobs.Layout (Vertical_Result.all).Descent = Vertical_Layout.Descent,
           "single-T returned geometry matches direct measured layout");
         Check (Jobs.Raster_Origin_Y (Vertical_Result.all) > 0,
           "single-T cancellation independently exercises positive Y origin");
         Check (Jobs.Raster_Origin_X (Vertical_Result.all) =
           Vertical_Bounds.Origin_X and
           Jobs.Raster_Origin_Y (Vertical_Result.all) =
             Vertical_Bounds.Origin_Y and
           Jobs.Raster_Width (Vertical_Result.all) = Vertical_Bounds.Width and
           Jobs.Raster_Height (Vertical_Result.all) = Vertical_Bounds.Height,
           "single-T origins and dimensions match measured returned geometry");
         Check (Jobs.Raster_Baseline (Vertical_Result.all) =
           Vertical_Bounds.Origin_Y + Natural
             (Long_Float'Ceiling
                (Jobs.Layout (Vertical_Result.all).Ascent * 48.0)),
           "single-T baseline uses measured Y origin and ceiled ascent");
      end if;
      if Horizontal_Result /= null and Vertical_Result /= null then
         Check (Jobs.Raster_Retained_Bytes (Horizontal_Result.all) > 0 and
           Jobs.Raster_Retained_Bytes (Vertical_Result.all) > 0 and
           Jobs.Raster_Retained_Bytes (Horizontal_Result.all) +
             Jobs.Raster_Retained_Bytes (Vertical_Result.all) =
               Math_Raster_Budget.Used,
           "both raster leases remain charged by actual retained storage");
         Check (Jobs.Raster_Retained_Bytes (Horizontal_Result.all) >=
           Jobs.Raster_Width (Horizontal_Result.all) * 4 *
             Jobs.Raster_Height (Horizontal_Result.all) and
           Jobs.Raster_Retained_Bytes (Vertical_Result.all) >=
             Jobs.Raster_Width (Vertical_Result.all) * 4 *
               Jobs.Raster_Height (Vertical_Result.all),
           "raster charges cover dimensions and minimum row storage");
         Jobs.Release (Horizontal_Result);
         Jobs.Release (Vertical_Result);
         Check (Math_Raster_Budget.Used = 0,
           "releasing independent cancel rasters restores empty budget");
      else
         if Horizontal_Result /= null then
            Jobs.Release (Horizontal_Result);
         end if;
         if Vertical_Result /= null then
            Jobs.Release (Vertical_Result);
         end if;
      end if;
   end;
   declare
      Color_Id : Jobs.Request_Id;
      Color_Status : Jobs.Job_Status;
      Color_Result : Jobs.Result_Access;
      Fonts : aliased Math_Painter.Font_Set;
      Settings : Math_Layout.Layout_Settings := (others => <>);
      Layout : Math_Layout.Box;
      Color : constant Jobs.Math_Color :=
        (Red => 0.75, Green => 0.2, Blue => 0.1, Alpha => 0.6);
   begin
      Jobs.Start;
      Jobs.Submit ("\textcolor{blue}{x+y}", Color_Id, 97,
        Math_Layout.Text_Style, Color_Enabled => True, Color => Color,
        Status => Color_Status, Request_Raster => True, Em_Pixels => 40.0,
        Font_Directory => Font_Directory);
      Check (Color_Status = Jobs.Pending,
        "explicit-color alpha raster job queued");
      for Wait in 1 .. 400 loop
         if Color_Status = Jobs.Pending then
            Jobs.Poll (Color_Id, 97, Color_Status, Color_Result);
         end if;
         exit when Color_Status /= Jobs.Pending;
         delay 0.005;
      end loop;
      Check (Color_Status = Jobs.Valid and Color_Result /= null,
        "explicit-color alpha raster job completes");
      Math_Painter.Load (Fonts, Font_Directory);
      Settings.Pixel_Em := 40.0;
      Settings.Advance_Source := Fonts'Unchecked_Access;
      Layout := Math_Layout.Build
        (Math_Syntax.Parse ("\textcolor{blue}{x+y}"),
         Math_Layout.Text_Style, Settings);
      for I in Layout.Commands.First_Index .. Layout.Commands.Last_Index loop
         declare
            Command : Math_Layout.Draw_Command := Layout.Commands (I);
         begin
            if not Command.Has_Color then
               Command.Has_Color := True;
               Command.Red := Color.Red;
               Command.Green := Color.Green;
               Command.Blue := Color.Blue;
               Command.Alpha := Color.Alpha;
               Layout.Commands.Replace_Element (I, Command);
            end if;
         end;
      end loop;
      if Color_Result /= null then
         declare
            Reference : constant Math_Raster.Image := Math_Raster.Render
              (Fonts, Layout, 40.0,
               (Red => Color.Red, Green => Color.Green, Blue => Color.Blue,
                Alpha => Color.Alpha));
         begin
            Check (Layout.Valid and
              Matches_Raster (Color_Result, Reference),
              "colored alpha worker pixels exactly match direct render");
         end;
         Check (Jobs.Raster_Baseline (Color_Result.all) =
           Jobs.Raster_Origin_Y (Color_Result.all) + Natural
             (Long_Float'Ceiling
                (Jobs.Layout (Color_Result.all).Ascent * 40.0)),
           "colored alpha raster baseline includes measured top origin");
         Check (Jobs.Raster_Retained_Bytes (Color_Result.all) > 0 and
           Math_Raster_Budget.Used =
             Jobs.Raster_Retained_Bytes (Color_Result.all),
           "colored alpha raster retains its charged storage");
         Jobs.Release (Color_Result);
         Check (Math_Raster_Budget.Used = 0,
           "colored alpha raster release restores empty budget");
      end if;
   end;
   declare
      function Macro_Failure_Text return String is
      begin
         return "\def\grow#1{#1#1}\grow{" &
           (1 .. 60_000 => 'x') & "}";
      end Macro_Failure_Text;
      function Array_Failure_Text return String is
         use Ada.Strings.Unbounded;
         Result : Unbounded_String := To_Unbounded_String
           ("\begin{matrix}x");
      begin
         for Column in 2 .. 65 loop
            Append (Result, "&x");
         end loop;
         Append (Result, "\end{matrix}");
         return To_String (Result);
      end Array_Failure_Text;
      function Abuse_Source (Index : Positive) return String is
      begin
         return (if Index = 1 then Macro_Failure_Text
                 else Array_Failure_Text);
      end Abuse_Source;
      Abuse_Id : Jobs.Request_Id;
      Recovery_Id : Jobs.Request_Id;
      Abuse_Status : Jobs.Job_Status;
      Recovery_Status : Jobs.Job_Status;
      Abuse_Result : Jobs.Result_Access;
      Recovery_Result : Jobs.Result_Access;
   begin
      Jobs.Start;
      for Iteration in 1 .. 3 loop
         for Case_Index in 1 .. 2 loop
            Jobs.Submit (Abuse_Source (Case_Index), Abuse_Id,
              Jobs.View_Generation (500 + Iteration),
              Math_Layout.Display_Style, Status => Abuse_Status,
              Request_Raster => True, Em_Pixels => 24.0,
              Font_Directory => Font_Directory);
            Check (Abuse_Status = Jobs.Pending,
              "pathological worker request queues" & Case_Index'Image);
            for Wait in 1 .. 400 loop
               if Abuse_Status = Jobs.Pending then
                  Jobs.Poll (Abuse_Id,
                    Jobs.View_Generation (500 + Iteration), Abuse_Status,
                    Abuse_Result);
               end if;
               exit when Abuse_Status /= Jobs.Pending;
               delay 0.005;
            end loop;
            Check (Abuse_Status = Jobs.Invalid and Abuse_Result /= null,
              "pathological input returns Invalid result");
            if Abuse_Result /= null then
               declare
                  Expected_Error : constant String :=
                    (if Case_Index = 1 then
                       "macro expansion: TOKEN_LIMIT"
                     else "array column limit exceeded");
               begin
                  Check (Jobs.Error (Abuse_Result.all)'Length >=
                    Expected_Error'Length and then
                    Jobs.Error (Abuse_Result.all)
                      (1 .. Expected_Error'Length) = Expected_Error,
                    "pathological input reports specific rejection cause");
               end;
               Check (Jobs.Source (Abuse_Result.all) =
                 Abuse_Source (Case_Index) and
                 not Jobs.Has_Raster (Abuse_Result.all) and
                 Jobs.Raster_Width (Abuse_Result.all) = 0 and
                 Jobs.Raster_Height (Abuse_Result.all) = 0 and
                 Jobs.Raster_Retained_Bytes (Abuse_Result.all) = 0 and
                 Math_Raster_Budget.Used = 0,
                 "rejected source retained without pixels or charge");
               Jobs.Release (Abuse_Result);
            end if;
            Jobs.Submit ("x+y", Recovery_Id,
              Jobs.View_Generation (500 + Iteration),
              Math_Layout.Display_Style, Status => Recovery_Status,
              Request_Raster => True, Em_Pixels => 24.0,
              Font_Directory => Font_Directory);
            Check (Recovery_Status = Jobs.Pending,
              "normal raster recovery queues after pathological rejection");
            for Wait in 1 .. 400 loop
               if Recovery_Status = Jobs.Pending then
                  Jobs.Poll (Recovery_Id,
                    Jobs.View_Generation (500 + Iteration), Recovery_Status,
                    Recovery_Result);
               end if;
               exit when Recovery_Status /= Jobs.Pending;
               delay 0.005;
            end loop;
            Check (Recovery_Status = Jobs.Valid and then
              Recovery_Result /= null and then
              Jobs.Source (Recovery_Result.all) = "x+y" and then
              Jobs.Has_Raster (Recovery_Result.all) and then
              Jobs.Raster_Retained_Bytes (Recovery_Result.all) > 0,
              "ordinary raster result follows pathological rejection");
            if Recovery_Result /= null then
               Jobs.Release (Recovery_Result);
            end if;
            Check (Math_Raster_Budget.Used = 0,
              "pathological rejection recovery releases raster charge");
         end loop;
      end loop;
   end;
   declare
      Fonts : aliased Math_Painter.Font_Set;
      Settings : Math_Layout.Layout_Settings := (others => <>);
      Wide_Source : constant String :=
        "\fcolorbox{red}{blue}{\xcancel{\rule{40em}{1em}}}";
      Tall_Source : constant String :=
        "\fcolorbox{red}{blue}{\xcancel{\rule{1em}{20em}}}";

      procedure Exercise
        (Source : String; Wide : Boolean; Generation : Natural) is
         Options : constant Math_Syntax.Options :=
           (Display_Mode => True, others => <>);
         Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
           (Source, Options);
         Geometry : constant Math_Layout.Box := Math_Layout.Build
           (Parsed, Math_Layout.Display_Style, Settings);
         Bounds : constant Math_Raster.Raster_Bounds :=
           Math_Raster.Measure (Geometry, 256.0);
         Needed : constant Natural := Bounds.Width * 4 * Bounds.Height;
         Failure_Id : Jobs.Request_Id;
         Failure_Status : Jobs.Job_Status;
         Failure_Result : Jobs.Result_Access;
         Recovery_Id : Jobs.Request_Id;
         Recovery_Status : Jobs.Job_Status;
         Recovery_Result : Jobs.Result_Access;
         Control_Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
           (Source, Options);
         Control_Settings : Math_Layout.Layout_Settings := Settings;
         Control_Geometry : Math_Layout.Box;
         Control_Bounds : Math_Raster.Raster_Bounds;
      begin
         Control_Settings.Pixel_Em := 24.0;
         Control_Geometry := Math_Layout.Build
           (Control_Parsed, Math_Layout.Display_Style, Control_Settings);
         Control_Bounds := Math_Raster.Measure (Control_Geometry, 24.0);
         Check (Source'Length < 256 and Math_Syntax.Is_Valid (Parsed) and
           Geometry.Valid,
           "composed dimension fixture parses and lays out: " & Source);
         Check
           ((if Wide
             then Bounds.Width > 8192 and Bounds.Height < 4096
             else Bounds.Height > 4096 and Bounds.Width < 8192) and
            Needed > 0 and Needed < Math_Raster_Budget.Capacity,
            "composed fixture crosses only requested raster dimension: " &
              Source);
         Check (Math_Syntax.Is_Valid (Control_Parsed) and
           Control_Geometry.Valid and
           Control_Bounds.Width <= 8192 and
           Control_Bounds.Height <= 4096,
           "composed fixture has valid 24px recovery geometry: " & Source);

         Jobs.Submit (Source, Failure_Id, Jobs.View_Generation (Generation),
           Math_Layout.Display_Style, Status => Failure_Status,
           Request_Raster => True, Em_Pixels => 256.0,
           Font_Directory => Font_Directory);
         Check (Failure_Status = Jobs.Pending,
           "composed oversized request queues: " & Source);
         Ada.Text_IO.Put_Line
           ("COMPOSED_BOUNDS width=" & Bounds.Width'Image &
            " height=" & Bounds.Height'Image &
            " needed=" & Needed'Image & " source=" & Source);
         for Wait in 1 .. 400 loop
            if Failure_Status = Jobs.Pending then
               Jobs.Poll
                 (Failure_Id, Jobs.View_Generation (Generation),
                  Failure_Status, Failure_Result);
            end if;
            exit when Failure_Status /= Jobs.Pending;
            delay 0.005;
         end loop;
         if Failure_Status = Jobs.Pending then
            Jobs.Abandon
              (Failure_Id, Jobs.View_Generation (Generation));
            Check (False,
              "composed request poll watchdog expired: " & Source);
            return;
         end if;
         Check (Failure_Status = Jobs.Failed and Failure_Result /= null,
           "composed oversized raster fails after worker request: " & Source);
         if Failure_Result /= null then
            Check (Jobs.Error (Failure_Result.all) =
              "full raster dimension limit exceeded" and
              Jobs.Source (Failure_Result.all) = Source and
              Math_Syntax.Is_Valid
                (Jobs.Parse_Document (Failure_Result.all)) and
              Jobs.Layout (Failure_Result.all).Valid and
              not Jobs.Has_Raster (Failure_Result.all) and
              Jobs.Raster_Width (Failure_Result.all) = 0 and
              Jobs.Raster_Height (Failure_Result.all) = 0 and
              Jobs.Raster_Retained_Bytes (Failure_Result.all) = 0 and
              Jobs.Raster_Workspace_Peak_Bytes (Failure_Result.all) = 0 and
              Math_Raster_Budget.Used = 0,
              "dimension failure diagnostic and output cleanup: " & Source);
            Jobs.Release (Failure_Result);
         end if;
         Check (Math_Raster_Budget.Used = 0,
           "composed dimension failure releases reservation: " & Source);

         Jobs.Submit (Source, Recovery_Id,
           Jobs.View_Generation (Generation + 1),
           Math_Layout.Display_Style, Status => Recovery_Status,
           Request_Raster => True, Em_Pixels => 24.0,
           Font_Directory => Font_Directory);
         Check (Recovery_Status = Jobs.Pending,
           "composed low-scale recovery request queues: " & Source);
         for Wait in 1 .. 400 loop
            if Recovery_Status = Jobs.Pending then
               Jobs.Poll
                 (Recovery_Id, Jobs.View_Generation (Generation + 1),
                  Recovery_Status, Recovery_Result);
            end if;
            exit when Recovery_Status /= Jobs.Pending;
            delay 0.005;
         end loop;
         if Recovery_Status = Jobs.Pending then
            Jobs.Abandon
              (Recovery_Id, Jobs.View_Generation (Generation + 1));
            Check (False,
              "composed recovery poll watchdog expired: " & Source);
            return;
         end if;
         Check (Recovery_Status = Jobs.Valid and Recovery_Result /= null,
           "same-source low-scale raster recovers after dimension failure: " &
             Source);
         if Recovery_Result /= null then
            Check (Jobs.Source (Recovery_Result.all) = Source and
              Jobs.Has_Raster (Recovery_Result.all) and
              Jobs.Raster_Width (Recovery_Result.all) =
                Control_Bounds.Width and
              Jobs.Raster_Height (Recovery_Result.all) =
                Control_Bounds.Height and
              Jobs.Raster_Width (Recovery_Result.all) <= 8192 and
              Jobs.Raster_Height (Recovery_Result.all) <= 4096 and
              Jobs.Raster_Retained_Bytes (Recovery_Result.all) > 0 and
              Math_Raster_Budget.Used =
                Jobs.Raster_Retained_Bytes (Recovery_Result.all),
              "same-source recovery returns bounded retained raster: " &
                Source);
            Jobs.Release (Recovery_Result);
         end if;
         Check (Math_Raster_Budget.Used = 0,
           "composed recovery returns raster ledger to baseline: " & Source);
      end Exercise;
   begin
      Check (Math_Raster_Budget.Used = 0,
        "composed dimension probes begin with empty raster ledger");
      Math_Painter.Load (Fonts, Font_Directory);
      Settings.Pixel_Em := 256.0;
      Settings.Advance_Source := Fonts'Unchecked_Access;
      for Iteration in 1 .. 2 loop
         Exercise (Wide_Source, True, 410 + 2 * Iteration);
         Exercise (Tall_Source, False, 411 + 2 * Iteration);
      end loop;
      Check (Math_Raster_Budget.Used = 0,
        "repeated composed probes leave raster ledger empty");
   end;
   declare
      Tiny_Id : Jobs.Request_Id;
      Exact_Id : Jobs.Request_Id;
      Full_Id : Jobs.Request_Id;
      Wide_Id : Jobs.Request_Id;
      Recovery_Id : Jobs.Request_Id;
      Tiny_Status : Jobs.Job_Status;
      Exact_Status : Jobs.Job_Status;
      Full_Status : Jobs.Job_Status;
      Wide_Status : Jobs.Job_Status;
      Recovery_Status : Jobs.Job_Status;
      Tiny_Result : Jobs.Result_Access;
      Exact_Result : Jobs.Result_Access;
      Full_Result : Jobs.Result_Access;
      Wide_Result : Jobs.Result_Access;
      Recovery_Result : Jobs.Result_Access;
      Fonts : aliased Math_Painter.Font_Set;
      Settings : Math_Layout.Layout_Settings := (others => <>);
      Tiny_Layout : Math_Layout.Box;
      Tiny_Bounds : Math_Raster.Raster_Bounds;
      Wide_Layout : Math_Layout.Box;
      Wide_Bounds : Math_Raster.Raster_Bounds;
      Blocking_Lease : Math_Raster_Budget.Lease;
      Blocking_Accepted : Boolean;
      Needed : Natural;
   begin
      Check (Math_Raster_Budget.Used = 0,
        "admission tests begin with no retained raster leases");
      Math_Painter.Load (Fonts, Font_Directory);
      Settings.Pixel_Em := 24.0;
      Settings.Advance_Source := Fonts'Unchecked_Access;
      Tiny_Layout := Math_Layout.Build
        (Math_Syntax.Parse ("x+y"), Math_Layout.Display_Style, Settings);
      Tiny_Bounds := Math_Raster.Measure (Tiny_Layout, 24.0);
      Needed := Tiny_Bounds.Width * 4 * Tiny_Bounds.Height;
      Check (Tiny_Layout.Valid and Needed > 0 and
        Needed < Math_Raster_Budget.Capacity,
        "tiny raster request has bounded measured ARGB32 storage");

      Math_Raster_Budget.Reserve
        (Math_Raster_Budget.Capacity - Needed + 1,
         Blocking_Lease, Blocking_Accepted);
      Check (Blocking_Accepted and
        Math_Raster_Budget.Used = Math_Raster_Budget.Capacity - Needed + 1,
        "one-byte-short admission blocker fills ledger to boundary");
      Jobs.Submit ("x+y", Tiny_Id, 401, Math_Layout.Display_Style,
        Status => Tiny_Status, Request_Raster => True, Em_Pixels => 24.0,
        Font_Directory => Font_Directory);
      for Wait in 1 .. 400 loop
         if Tiny_Status = Jobs.Pending then
            Jobs.Poll (Tiny_Id, 401, Tiny_Status, Tiny_Result);
         end if;
         exit when Tiny_Status /= Jobs.Pending;
         delay 0.005;
      end loop;
      Check (Tiny_Status = Jobs.Failed and Tiny_Result /= null,
        "one-byte-short raster admission is rejected");
      if Tiny_Result /= null then
         Check (Jobs.Error (Tiny_Result.all) =
           "retained raster budget exceeded" and
           not Jobs.Has_Raster (Tiny_Result.all) and
           Jobs.Raster_Width (Tiny_Result.all) = 0 and
           Jobs.Raster_Height (Tiny_Result.all) = 0 and
           Jobs.Raster_Retained_Bytes (Tiny_Result.all) = 0 and
           Jobs.Raster_Workspace_Peak_Bytes (Tiny_Result.all) = 0,
           "rejected result publishes no pixels, dimensions, or charge");
         Check (Math_Raster_Budget.Used =
           Math_Raster_Budget.Capacity - Needed + 1,
           "rejected result adds no charge before its release");
         Jobs.Release (Tiny_Result);
      end if;
      Math_Raster_Budget.Release (Blocking_Lease);
      Check (Math_Raster_Budget.Used = 0,
        "one-byte-short blocker releases to baseline");

      Math_Raster_Budget.Reserve
        (Math_Raster_Budget.Capacity - Needed,
         Blocking_Lease, Blocking_Accepted);
      Check (Blocking_Accepted and
        Math_Raster_Budget.Used = Math_Raster_Budget.Capacity - Needed,
        "exact-fit blocker leaves precisely measured request capacity");
      Jobs.Submit ("x+y", Exact_Id, 402, Math_Layout.Display_Style,
        Status => Exact_Status, Request_Raster => True, Em_Pixels => 24.0,
        Font_Directory => Font_Directory);
      for Wait in 1 .. 400 loop
         if Exact_Status = Jobs.Pending then
            Jobs.Poll (Exact_Id, 402, Exact_Status, Exact_Result);
         end if;
         exit when Exact_Status /= Jobs.Pending;
         delay 0.005;
      end loop;
      Check (Exact_Status = Jobs.Valid and Exact_Result /= null,
        "exact-capacity raster request succeeds");
      if Exact_Result /= null then
         Check (Jobs.Raster_Workspace_Peak_Bytes (Exact_Result.all) =
           Needed * 2,
           "worker accounts overlapping Cairo and exported pixels");
         Check (Jobs.Pipeline_Workspace_Peak_Bytes (Exact_Result.all) =
           Natural'Max
             (Jobs.Parse_Workspace_Peak_Bytes (Exact_Result.all),
              Jobs.Raster_Workspace_Peak_Bytes (Exact_Result.all)),
           "tiny raster pipeline peak is the max of isolated phase peaks");
         Check (Jobs.Has_Raster (Exact_Result.all) and
           Jobs.Raster_Width (Exact_Result.all) = Tiny_Bounds.Width and
           Jobs.Raster_Height (Exact_Result.all) = Tiny_Bounds.Height and
           Jobs.Raster_Retained_Bytes (Exact_Result.all) = Needed and
           Math_Raster_Budget.Used = Math_Raster_Budget.Capacity,
           "exact-fit raster retains measured bytes at full capacity");
         Jobs.Release (Exact_Result);
      end if;
      Check (Math_Raster_Budget.Used =
        Math_Raster_Budget.Capacity - Needed,
        "releasing exact-fit result leaves only blocker charge");
      Math_Raster_Budget.Release (Blocking_Lease);
      Check (Math_Raster_Budget.Used = 0,
        "exact-fit blocker release restores empty budget");

      Math_Raster_Budget.Reserve
        (Math_Raster_Budget.Capacity, Blocking_Lease, Blocking_Accepted);
      Check (Blocking_Accepted and
        Math_Raster_Budget.Used = Math_Raster_Budget.Capacity,
        "full-ledger blocker reserves complete capacity");
      Jobs.Submit ("x+y", Full_Id, 403, Math_Layout.Display_Style,
        Status => Full_Status, Request_Raster => True, Em_Pixels => 24.0,
        Font_Directory => Font_Directory);
      for Wait in 1 .. 400 loop
         if Full_Status = Jobs.Pending then
            Jobs.Poll (Full_Id, 403, Full_Status, Full_Result);
         end if;
         exit when Full_Status /= Jobs.Pending;
         delay 0.005;
      end loop;
      Check (Full_Status = Jobs.Failed and Full_Result /= null,
        "full retained-raster ledger rejects raster request");
      if Full_Result /= null then
         Check (Jobs.Error (Full_Result.all) =
           "retained raster budget exceeded" and
           not Jobs.Has_Raster (Full_Result.all) and
           Jobs.Raster_Width (Full_Result.all) = 0 and
           Jobs.Raster_Height (Full_Result.all) = 0 and
           Jobs.Raster_Retained_Bytes (Full_Result.all) = 0 and
           Math_Raster_Budget.Used = Math_Raster_Budget.Capacity,
           "full-ledger rejection keeps pixels and charge unpublished");
         Jobs.Release (Full_Result);
      end if;
      Math_Raster_Budget.Release (Blocking_Lease);
      Check (Math_Raster_Budget.Used = 0,
        "full-ledger blocker releases to baseline");

      Settings.Pixel_Em := 100.0;
      Wide_Layout := Math_Layout.Build
        (Math_Syntax.Parse ("\rule{100em}{1em}"),
         Math_Layout.Display_Style, Settings);
      Wide_Bounds := Math_Raster.Measure (Wide_Layout, 100.0);
      Needed := Wide_Bounds.Width * 4 * Wide_Bounds.Height;
      Check (Wide_Layout.Valid and Wide_Bounds.Width > 8192 and
        Needed < Math_Raster_Budget.Capacity,
        "wide valid layout reserves below capacity before raster limits");
      Jobs.Submit ("\rule{100em}{1em}", Wide_Id, 404,
        Math_Layout.Display_Style, Status => Wide_Status,
        Request_Raster => True, Em_Pixels => 100.0,
        Font_Directory => Font_Directory);
      for Wait in 1 .. 400 loop
         if Wide_Status = Jobs.Pending then
            Jobs.Poll (Wide_Id, 404, Wide_Status, Wide_Result);
         end if;
         exit when Wide_Status /= Jobs.Pending;
         delay 0.005;
      end loop;
      Check (Wide_Status = Jobs.Failed and Wide_Result /= null,
        "post-reservation raster dimension error fails request");
      if Wide_Result /= null then
         Check (not Jobs.Has_Raster (Wide_Result.all) and
           Jobs.Raster_Width (Wide_Result.all) = 0 and
           Jobs.Raster_Height (Wide_Result.all) = 0 and
           Jobs.Raster_Retained_Bytes (Wide_Result.all) = 0 and
           Math_Raster_Budget.Used = 0,
           "failed render drops pixels and reservation before publication");
         Jobs.Release (Wide_Result);
      end if;
      Check (Math_Raster_Budget.Used = 0,
        "failed oversized render leaves budget at baseline");

      Jobs.Submit ("x+y", Recovery_Id, 405, Math_Layout.Display_Style,
        Status => Recovery_Status, Request_Raster => True, Em_Pixels => 24.0,
        Font_Directory => Font_Directory);
      for Wait in 1 .. 400 loop
         if Recovery_Status = Jobs.Pending then
            Jobs.Poll (Recovery_Id, 405, Recovery_Status, Recovery_Result);
         end if;
         exit when Recovery_Status /= Jobs.Pending;
         delay 0.005;
      end loop;
      Check (Recovery_Status = Jobs.Valid and Recovery_Result /= null,
        "successful raster request recovers after render failure");
      if Recovery_Result /= null then
         Check (Jobs.Raster_Retained_Bytes (Recovery_Result.all) =
           Tiny_Bounds.Width * 4 * Tiny_Bounds.Height and
           Math_Raster_Budget.Used =
             Jobs.Raster_Retained_Bytes (Recovery_Result.all),
           "recovery request owns exactly measured raster storage");
         Jobs.Release (Recovery_Result);
      end if;
      Check (Math_Raster_Budget.Used = 0,
        "admission and recovery tests release all raster charges");
   end;
   Jobs.Start;
   Jobs.Submit ("x+y", Abandoned_Id, Abandoned_Generation,
     Math_Layout.Display_Style, Status => S, Request_Raster => True,
     Em_Pixels => 24.0, Font_Directory => Font_Directory);
   Check (S = Jobs.Pending, "unpolled raster request accepted");
   delay 0.1;
   Check (Math_Raster_Budget.Used > 0,
     "completed unpolled raster remains charged in its queue slot");
   Jobs.Shutdown;
   Check (Math_Raster_Budget.Used = 0,
     "shutdown releases unpolled raster result charge");
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
