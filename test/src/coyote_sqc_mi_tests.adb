--  Coyote_SQC_MI_Tests body.
--
--  Project: coyote

with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Ada.Containers;
with AUnit.Assertions;
with Coyote_SQC.Charts;
with Coyote_SQC.Data_Model;
with Coyote_SQC.Metrics;
with Coyote_SQC.Statistics;
with Coyote_SQC.Statistics.MI;

package body Coyote_SQC_MI_Tests is

   use AUnit.Assertions;
   use Coyote_SQC.Data_Model;
   use type Ada.Containers.Count_Type;

   --  Helper: build a Tool_Call_Record with the given name and args.
   function Make_TC
     (Name : String;
      Args : String) return Tool_Call_Record
   is
      TC : Tool_Call_Record;
   begin
      TC.Tool_Name  := To_Unbounded_String (Name);
      TC.Arguments  := To_Unbounded_String (Args);
      return TC;
   end Make_TC;

   --  ── Compute_MI_Values tests ───────────────────────────────────────────

   --  Two identical calls produce a positive MI value for each key.
   --  Two identical calls with longer strings produce positive MI values.
   procedure Test_MI_Identical_Calls (T : in out Test) is
      pragma Unreferenced (T);
      Result : Long_Float_Vectors.Vector;
   begin
      Coyote_SQC.Statistics.MI.Compute_MI_Values
        (Tool_Name_1 => "shell_command",
         Arguments_1 => "{""command"":""ls -la /home/user/projects""}",
         Tool_Name_2 => "shell_command",
         Arguments_2 => "{""command"":""ls -la /home/user/projects""}",
         Result      => Result);

      Assert (not Result.Is_Empty,
              "Identical calls: must produce at least one MI value");
      --  Each MI_k should be positive for identical strings of
      --  sufficient length (dictionary-preloaded compression needs
      --  enough content to overcome block-header overhead).
      for I in 1 .. Natural (Result.Length) loop
         Assert (Result.Element (I) > 0.0,
                 "Identical calls: MI_k[" & Positive'Image (I)
                 & "] must be > 0; got "
                 & Long_Float'Image (Result.Element (I)));
      end loop;
   end Test_MI_Identical_Calls;

   --  Different tool names produce lower total MI than identical tool names.
   procedure Test_MI_Different_Tool_Names (T : in out Test) is
      pragma Unreferenced (T);
      Result_Same : Long_Float_Vectors.Vector;
      Result_Diff : Long_Float_Vectors.Vector;
      Sum_Same    : Long_Float := 0.0;
      Sum_Diff    : Long_Float := 0.0;
   begin
      Coyote_SQC.Statistics.MI.Compute_MI_Values
        (Tool_Name_1 => "read",
         Arguments_1 => "{""x"":""val""}",
         Tool_Name_2 => "read",
         Arguments_2 => "{""x"":""val""}",
         Result      => Result_Same);

      Coyote_SQC.Statistics.MI.Compute_MI_Values
        (Tool_Name_1 => "read",
         Arguments_1 => "{""x"":""val""}",
         Tool_Name_2 => "write",
         Arguments_2 => "{""x"":""val""}",
         Result      => Result_Diff);

      for V of Result_Same loop Sum_Same := Sum_Same + V; end loop;
      for V of Result_Diff loop Sum_Diff := Sum_Diff + V; end loop;

      Assert (Sum_Same >= Sum_Diff,
              "Different tool names must not exceed same-name total MI; Same="
              & Long_Float'Image (Sum_Same)
              & " Diff=" & Long_Float'Image (Sum_Diff));
   end Test_MI_Different_Tool_Names;

   --  Key present on one side only: MI_k = 0.0.
   procedure Test_MI_One_Side_Absent (T : in out Test) is
      pragma Unreferenced (T);
      Result : Long_Float_Vectors.Vector;
   begin
      Coyote_SQC.Statistics.MI.Compute_MI_Values
        (Tool_Name_1 => "t",
         Arguments_1 => "{""a"":""foo""}",
         Tool_Name_2 => "t",
         Arguments_2 => "{""b"":""bar""}",
         Result      => Result);

      --  Tool-name MI_k should be > 0 (identical "t"/"t").
      --  Argument keys should be 0.0 (absent on one side).
      Assert (Result.Length >= 3,
              "One-side absent: should have 3 values (tool + 2 args); got "
              & Ada.Containers.Count_Type'Image (Result.Length));

      --  Argument keys (positions 2 and 3) should be 0.0.
      Assert (abs (Result.Element (2)) <= 1.0e-12,
              "One-side absent: arg key 'a' should be 0.0; got "
              & Long_Float'Image (Result.Element (2)));
      Assert (abs (Result.Element (3)) <= 1.0e-12,
              "One-side absent: arg key 'b' should be 0.0; got "
              & Long_Float'Image (Result.Element (3)));
   end Test_MI_One_Side_Absent;

   --  Integer-valued keys are skipped (no string content).
   --  Integer-valued keys are skipped (no string content).
   procedure Test_MI_Integer_Key_Skipped (T : in out Test) is
      pragma Unreferenced (T);
      Result : Long_Float_Vectors.Vector;
   begin
      Coyote_SQC.Statistics.MI.Compute_MI_Values
        (Tool_Name_1 => "file_read",
         Arguments_1 => "{""n"":42}",
         Tool_Name_2 => "file_read",
         Arguments_2 => "{""n"":99}",
         Result      => Result);

      --  Only tool_name key should produce a value (integer key skipped).
      Assert (Result.Length >= 1,
              "Integer-key skipped: should have at least 1 value (tool name); got "
              & Ada.Containers.Count_Type'Image (Result.Length));
      Assert (Result.Element (1) > 0.0,
              "Integer-key skipped: tool-name MI must be > 0; got "
              & Long_Float'Image (Result.Element (1)));
   end Test_MI_Integer_Key_Skipped;

   --  Both sides empty: no observation produced.
   procedure Test_MI_Both_Sides_Empty (T : in out Test) is
      pragma Unreferenced (T);
      Result : Long_Float_Vectors.Vector;
   begin
      Coyote_SQC.Statistics.MI.Compute_MI_Values
        (Tool_Name_1 => "",
         Arguments_1 => "",
         Tool_Name_2 => "",
         Arguments_2 => "",
         Result      => Result);

      --  Tool-name is empty on both sides → compressed size 0 on both → skipped.
      --  No argument keys → no additional values.
      Assert (Result.Is_Empty,
              "Both sides empty: should produce zero MI values");
   end Test_MI_Both_Sides_Empty;

   --  ── Metrics MI field tests ────────────────────────────────────────────

   --  Two identical tool calls: N_Consecutive_Tool_MI_Pairs = 1,
   --  Per_Consecutive_Tool_MI has entries, Total_Tool_Call_MI > 0.
   --  Two identical tool calls: N_Consecutive_Tool_MI_Pairs = 1,
   --  Per_Consecutive_Tool_MI has entries, Total_Tool_Call_MI > 0.
   procedure Test_Metrics_MI_Two_Identical_Calls (T : in out Test) is
      pragma Unreferenced (T);
      Session : Session_Record;
      Turn    : Turn_Record;
      M       : Session_Metrics_Record;
   begin
      Turn.Turn_Index := 1;
      Turn.Tool_Calls.Append
        (Make_TC ("shell_command", "{""command"":""ls -la /home/user""}"));
      Turn.Tool_Calls.Append
        (Make_TC ("shell_command", "{""command"":""ls -la /home/user""}"));
      Session.Turns.Append (Turn);
      Session.Session_Id := To_Unbounded_String ("mi1");

      M := Coyote_SQC.Metrics.Compute (Session, Coyote_SQC.Metrics.Pricing_Maps.Empty_Map);

      Assert (M.N_Consecutive_Tool_MI_Pairs = 1,
              "Two identical MI calls: N_Pairs must be 1; got "
              & Natural'Image (M.N_Consecutive_Tool_MI_Pairs));
      Assert (not M.Per_Consecutive_Tool_MI.Is_Empty,
              "Two identical MI calls: Per_Consecutive_Tool_MI must not be empty");
      Assert (M.Total_Tool_Call_MI > 0.0,
              "Two identical MI calls: Total_Tool_Call_MI must be > 0; got "
              & Long_Float'Image (M.Total_Tool_Call_MI));
   end Test_Metrics_MI_Two_Identical_Calls;

   --  Single tool call: no consecutive pairs.
   procedure Test_Metrics_MI_Single_Tool_Call (T : in out Test) is
      pragma Unreferenced (T);
      Session : Session_Record;
      Turn    : Turn_Record;
      M       : Session_Metrics_Record;
   begin
      Turn.Turn_Index := 1;
      Turn.Tool_Calls.Append (Make_TC ("shell", "{""command"":""ls""}"));
      Session.Turns.Append (Turn);
      Session.Session_Id := To_Unbounded_String ("mi2");

      M := Coyote_SQC.Metrics.Compute (Session, Coyote_SQC.Metrics.Pricing_Maps.Empty_Map);

      Assert (M.N_Consecutive_Tool_MI_Pairs = 0,
              "Single tool call: N_MI_Pairs must be 0");
      Assert (M.Per_Consecutive_Tool_MI.Is_Empty,
              "Single tool call: Per_Consecutive_Tool_MI must be empty");
      Assert (M.Total_Tool_Call_MI = 0.0,
              "Single tool call: Total_Tool_Call_MI must be 0.0");
   end Test_Metrics_MI_Single_Tool_Call;

   --  No tool calls: all MI fields are zero/empty.
   procedure Test_Metrics_MI_No_Tool_Calls (T : in out Test) is
      pragma Unreferenced (T);
      Session : Session_Record;
      Turn    : Turn_Record;
      M       : Session_Metrics_Record;
   begin
      Turn.Turn_Index := 1;
      Session.Turns.Append (Turn);
      Session.Session_Id := To_Unbounded_String ("mi3");

      M := Coyote_SQC.Metrics.Compute (Session, Coyote_SQC.Metrics.Pricing_Maps.Empty_Map);

      Assert (M.N_Consecutive_Tool_MI_Pairs = 0,
              "No tool calls: N_MI_Pairs must be 0");
      Assert (M.Total_Tool_Call_MI = 0.0,
              "No tool calls: Total_Tool_Call_MI must be 0.0");
   end Test_Metrics_MI_No_Tool_Calls;

   --  Total_Tool_Call_MI equals sum of Per_Consecutive_Tool_MI.
   procedure Test_Metrics_MI_Total_Sum (T : in out Test) is
      pragma Unreferenced (T);
      Session : Session_Record;
      Turn    : Turn_Record;
      M       : Session_Metrics_Record;
      Manual  : Long_Float := 0.0;
      Tol     : constant Long_Float := 1.0e-12;
   begin
      Turn.Turn_Index := 1;
      Turn.Tool_Calls.Append (Make_TC ("tool", "{""x"":""val""}"));
      Turn.Tool_Calls.Append (Make_TC ("tool", "{""x"":""val""}"));
      Session.Turns.Append (Turn);
      Session.Session_Id := To_Unbounded_String ("mi4");

      M := Coyote_SQC.Metrics.Compute (Session, Coyote_SQC.Metrics.Pricing_Maps.Empty_Map);

      for V of M.Per_Consecutive_Tool_MI loop
         Manual := Manual + V;
      end loop;
      Assert (abs (M.Total_Tool_Call_MI - Manual) <= Tol,
              "Total_Tool_Call_MI must equal sum of Per_Consecutive_Tool_MI; "
              & "Total=" & Long_Float'Image (M.Total_Tool_Call_MI)
              & " Manual=" & Long_Float'Image (Manual));
   end Test_Metrics_MI_Total_Sum;

   --  Tool calls in different turns produce consecutive pairs.
   procedure Test_Metrics_MI_Cross_Turn_Pairs (T : in out Test) is
      pragma Unreferenced (T);
      Session : Session_Record;
      Turn1   : Turn_Record;
      Turn2   : Turn_Record;
      M       : Session_Metrics_Record;
   begin
      Turn1.Turn_Index := 1;
      Turn1.Tool_Calls.Append (Make_TC ("tool", "{""x"":""val""}"));
      Turn2.Turn_Index := 2;
      Turn2.Tool_Calls.Append (Make_TC ("tool", "{""x"":""val""}"));
      Session.Turns.Append (Turn1);
      Session.Turns.Append (Turn2);
      Session.Session_Id := To_Unbounded_String ("mi5");

      M := Coyote_SQC.Metrics.Compute (Session, Coyote_SQC.Metrics.Pricing_Maps.Empty_Map);

      Assert (M.N_Consecutive_Tool_MI_Pairs = 1,
              "Cross-turn MI pair: N_MI_Pairs must be 1; got "
              & Natural'Image (M.N_Consecutive_Tool_MI_Pairs));
   end Test_Metrics_MI_Cross_Turn_Pairs;

   --  ── Estimate_Parameters for MI sum chart kinds ────────────────────────

   function Make_MI_Metrics
     (Id    : String;
      MI_Sum : Long_Float;
      Pairs : Natural) return Session_Metrics_Record
   is
      M : Session_Metrics_Record;
   begin
      M.Session_Id               := To_Unbounded_String (Id);
      M.N_Turns                  := 1;
      M.Total_Tool_Call_MI        := MI_Sum;
      M.N_Consecutive_Tool_MI_Pairs := Pairs;
      return M;
   end Make_MI_Metrics;

   --  Three sessions [10, 20, 30]: Grand_Mean = 20.0.
   procedure Test_Estimate_MI_Sum_I_Grand_Mean (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Charts;
      use Coyote_SQC.Statistics;
      Metrics : Metrics_Vectors.Vector;
      Setup   : UUID_Set;
      Params  : Setup_Parameters;
      Tol     : constant Long_Float := 1.0e-6;
   begin
      Metrics.Append (Make_MI_Metrics ("mi1", 10.0, 1));
      Metrics.Append (Make_MI_Metrics ("mi2", 20.0, 1));
      Metrics.Append (Make_MI_Metrics ("mi3", 30.0, 1));

      Estimate_Parameters
        (Metrics, Setup, Session_Tool_Call_MI_Sum_I, Parameters => Params);

      Assert (abs (Params.Grand_Mean - 20.0) <= Tol,
              "MI Sum I: Grand_Mean should be 20.0; got "
              & Long_Float'Image (Params.Grand_Mean));
   end Test_Estimate_MI_Sum_I_Grand_Mean;

   --  Three sessions [10, 20, 30]: Mean_MR = 10.0.
   procedure Test_Estimate_MI_Sum_I_Mean_MR (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Charts;
      use Coyote_SQC.Statistics;
      Metrics : Metrics_Vectors.Vector;
      Setup   : UUID_Set;
      Params  : Setup_Parameters;
      Tol     : constant Long_Float := 1.0e-6;
   begin
      Metrics.Append (Make_MI_Metrics ("mi1", 10.0, 1));
      Metrics.Append (Make_MI_Metrics ("mi2", 20.0, 1));
      Metrics.Append (Make_MI_Metrics ("mi3", 30.0, 1));

      Estimate_Parameters
        (Metrics, Setup, Session_Tool_Call_MI_Sum_I, Parameters => Params);

      Assert (abs (Params.Mean_MR - 10.0) <= Tol,
              "MI Sum I: Mean_MR should be 10.0; got "
              & Long_Float'Image (Params.Mean_MR));
   end Test_Estimate_MI_Sum_I_Mean_MR;

   --  Sessions with N_Consecutive_Tool_MI_Pairs = 0 excluded.
   procedure Test_Estimate_MI_Sum_Excludes_No_Pairs (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Charts;
      use Coyote_SQC.Statistics;
      Metrics : Metrics_Vectors.Vector;
      Setup   : UUID_Set;
      Params  : Setup_Parameters;
      Tol     : constant Long_Float := 1.0e-6;
   begin
      Metrics.Append (Make_MI_Metrics ("mi1", 10.0, 1));
      Metrics.Append (Make_MI_Metrics ("mi_skip", 999.0, 0));
      Metrics.Append (Make_MI_Metrics ("mi3", 30.0, 1));

      Estimate_Parameters
        (Metrics, Setup, Session_Tool_Call_MI_Sum_I, Parameters => Params);

      Assert (abs (Params.Grand_Mean - 20.0) <= Tol,
              "MI Sum I excludes Pairs=0: Grand_Mean should be 20.0; got "
              & Long_Float'Image (Params.Grand_Mean));
      Assert (abs (Params.Mean_MR - 20.0) <= Tol,
              "MI Sum I excludes Pairs=0: Mean_MR should be 20.0; got "
              & Long_Float'Image (Params.Mean_MR));
   end Test_Estimate_MI_Sum_Excludes_No_Pairs;

end Coyote_SQC_MI_Tests;
