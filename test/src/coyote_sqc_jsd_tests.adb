--  Coyote_SQC_JSD_Tests body.
--
--  Project: coyote

with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Ada.Containers;
with AUnit.Assertions;
with Coyote_SQC.Charts;
with Coyote_SQC.Data_Model;
with Coyote_SQC.Metrics;
with Coyote_SQC.Statistics;
with Coyote_SQC.Statistics.JSD;

package body Coyote_SQC_JSD_Tests is

   use AUnit.Assertions;
   use Coyote_SQC.Data_Model;
   use type Ada.Containers.Count_Type;

   --  ── Token_Count tests ────────────────────────────────────────────────

   --  Tool name with no arguments produces one token per word.
   procedure Test_Token_Count_Tool_Name_Only (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (Coyote_SQC.Statistics.JSD.Token_Count ("shell", "") = 1,
              "Token_Count(""shell"","") should be 1");
   end Test_Token_Count_Tool_Name_Only;

   --  Multi-word tool name splits into multiple tokens.
   procedure Test_Token_Count_Multi_Word_Tool_Name (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (Coyote_SQC.Statistics.JSD.Token_Count ("run test", "") = 2,
              "Token_Count(""run test"","") should be 2");
   end Test_Token_Count_Multi_Word_Tool_Name;

   --  Empty tool name and empty args produce zero tokens.
   procedure Test_Token_Count_Empty (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (Coyote_SQC.Statistics.JSD.Token_Count ("", "") = 0,
              "Token_Count("""","") should be 0");
   end Test_Token_Count_Empty;

   --  ── Compute_S_Values tests ────────────────────────────────────────────

   --  Two identical calls: Result must contain 2 elements
   --  (tool_name key + 1 argument key).
   procedure Test_S_Values_Identical_Calls_Length (T : in out Test) is
      pragma Unreferenced (T);
      Result : Long_Float_Vectors.Vector;
   begin
      Coyote_SQC.Statistics.JSD.Compute_S_Values
        (Tool_Name_1 => "tool",
         Arguments_1 => "{""x"":""val""}",
         Tool_Name_2 => "tool",
         Arguments_2 => "{""x"":""val""}",
         Result      => Result);
      Assert (Result.Length = 2,
              "Identical calls: Length should be 2 (tool_name + 1 key); got "
              & Ada.Containers.Count_Type'Image (Result.Length));
   end Test_S_Values_Identical_Calls_Length;

   --  Two identical calls: each S_k = N_k = 2 (both sides have 1 token).
   --  Sum = 4.0.
   procedure Test_S_Values_Identical_Calls_Sum (T : in out Test) is
      pragma Unreferenced (T);
      Tol    : constant Long_Float := 1.0e-9;
      Result : Long_Float_Vectors.Vector;
      Total  : Long_Float := 0.0;
   begin
      Coyote_SQC.Statistics.JSD.Compute_S_Values
        (Tool_Name_1 => "tool",
         Arguments_1 => "{""x"":""val""}",
         Tool_Name_2 => "tool",
         Arguments_2 => "{""x"":""val""}",
         Result      => Result);
      for V of Result loop
         Total := Total + V;
      end loop;
      Assert (abs (Total - 4.0) <= Tol,
              "Identical calls: sum of S_k should be 4.0; got "
              & Long_Float'Image (Total));
      --  Each individual S_k should equal N_k = 2 (identical distributions).
      Assert (abs (Result.Element (1) - 2.0) <= Tol,
              "Identical calls: tool_name S_k should be 2.0; got "
              & Long_Float'Image (Result.Element (1)));
      Assert (abs (Result.Element (2) - 2.0) <= Tol,
              "Identical calls: argument S_k should be 2.0; got "
              & Long_Float'Image (Result.Element (2)));
   end Test_S_Values_Identical_Calls_Sum;

   --  Key present in one call but absent in the other: S_k = 0.
   procedure Test_S_Values_One_Side_Absent_Zero (T : in out Test) is
      pragma Unreferenced (T);
      Tol    : constant Long_Float := 1.0e-9;
      Result : Long_Float_Vectors.Vector;
   begin
      --  Call_1 has key "a", Call_2 has key "b"; neither shares the other's key.
      Coyote_SQC.Statistics.JSD.Compute_S_Values
        (Tool_Name_1 => "t",
         Arguments_1 => "{""a"":""foo""}",
         Tool_Name_2 => "t",
         Arguments_2 => "{""b"":""bar""}",
         Result      => Result);
      --  S_k for "a" (absent in Call_2) and "b" (absent in Call_1) must be 0.
      Assert (abs (Result.Element (2) - 0.0) <= Tol,
              "One-side absent key ""a"": S_k should be 0; got "
              & Long_Float'Image (Result.Element (2)));
      Assert (abs (Result.Element (3) - 0.0) <= Tol,
              "One-side absent key ""b"": S_k should be 0; got "
              & Long_Float'Image (Result.Element (3)));
   end Test_S_Values_One_Side_Absent_Zero;

   --  One-side absent keys still produce entries (Length includes them).
   procedure Test_S_Values_One_Side_Absent_Length (T : in out Test) is
      pragma Unreferenced (T);
      Result : Long_Float_Vectors.Vector;
   begin
      Coyote_SQC.Statistics.JSD.Compute_S_Values
        (Tool_Name_1 => "t",
         Arguments_1 => "{""a"":""foo""}",
         Tool_Name_2 => "t",
         Arguments_2 => "{""b"":""bar""}",
         Result      => Result);
      --  3 entries: tool_name ("t"/"t"), "a" (absent in 2), "b" (absent in 1).
      Assert (Result.Length = 3,
              "One-side absent: Length should be 3; got "
              & Ada.Containers.Count_Type'Image (Result.Length));
   end Test_S_Values_One_Side_Absent_Length;

   --  Keys whose values are non-string JSON (integer) produce N_k = 0 on
   --  both sides and must be skipped — not added to Result.
   procedure Test_S_Values_Integer_Key_Skipped (T : in out Test) is
      pragma Unreferenced (T);
      Result : Long_Float_Vectors.Vector;
   begin
      --  Both calls have an integer-valued key "n": no string content → skipped.
      Coyote_SQC.Statistics.JSD.Compute_S_Values
        (Tool_Name_1 => "f",
         Arguments_1 => "{""n"":42}",
         Tool_Name_2 => "f",
         Arguments_2 => "{""n"":99}",
         Result      => Result);
      --  Only tool_name should be appended.
      Assert (Result.Length = 1,
              "Integer-valued key must be skipped; Length should be 1, got "
              & Ada.Containers.Count_Type'Image (Result.Length));
   end Test_S_Values_Integer_Key_Skipped;

   --  Different tool names produce a lower tool_name S_k than identical
   --  tool names with the same number of tokens.
   procedure Test_S_Values_Different_Tool_Names (T : in out Test) is
      pragma Unreferenced (T);
      Result_Diff  : Long_Float_Vectors.Vector;
      Result_Same  : Long_Float_Vectors.Vector;
   begin
      --  Different tool names; identical "x" argument.
      Coyote_SQC.Statistics.JSD.Compute_S_Values
        (Tool_Name_1 => "read",
         Arguments_1 => "{""x"":""val""}",
         Tool_Name_2 => "write",
         Arguments_2 => "{""x"":""val""}",
         Result      => Result_Diff);
      --  Identical tool names; identical "x" argument.
      Coyote_SQC.Statistics.JSD.Compute_S_Values
        (Tool_Name_1 => "read",
         Arguments_1 => "{""x"":""val""}",
         Tool_Name_2 => "read",
         Arguments_2 => "{""x"":""val""}",
         Result      => Result_Same);

      --  First element is the tool_name S_k.
      Assert (Result_Diff.Element (1) < Result_Same.Element (1),
              "Different tool names must produce lower tool_name S_k than "
              & "identical tool names");
      --  Argument S_k should be the same (2.0) in both cases.
      Assert (abs (Result_Diff.Element (2) - 2.0) < 1.0e-9,
              "Argument S_k with identical values must be 2.0");
   end Test_S_Values_Different_Tool_Names;

   --  Compute_S_Values appends to Result rather than clearing it.
   procedure Test_S_Values_Appends_Not_Clears (T : in out Test) is
      pragma Unreferenced (T);
      Result : Long_Float_Vectors.Vector;
   begin
      --  First call; adds 2 elements (tool_name + "x").
      Coyote_SQC.Statistics.JSD.Compute_S_Values
        (Tool_Name_1 => "tool",
         Arguments_1 => "{""x"":""v""}",
         Tool_Name_2 => "tool",
         Arguments_2 => "{""x"":""v""}",
         Result      => Result);
      Assert (Result.Length = 2, "After first call: Length = 2");

      --  Second call on the same Result vector; should append, not replace.
      Coyote_SQC.Statistics.JSD.Compute_S_Values
        (Tool_Name_1 => "tool",
         Arguments_1 => "{""x"":""v""}",
         Tool_Name_2 => "tool",
         Arguments_2 => "{""x"":""v""}",
         Result      => Result);
      Assert (Result.Length = 4,
              "After second call: Length should be 4 (appended); got "
              & Ada.Containers.Count_Type'Image (Result.Length));
   end Test_S_Values_Appends_Not_Clears;

   --  ── Metrics JSD field tests ───────────────────────────────────────────

   --  Helper: build a Turn_Record with the given tool calls.
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

   --  Two identical tool calls in one turn:
   --  N_Consecutive_Tool_Pairs = 1, Per_Consecutive_Tool_S.Length = 2,
   --  Total_Tool_Call_JSD_S = 4.0 (both S_k values equal N_k = 2).
   procedure Test_Metrics_JSD_Two_Identical_Calls (T : in out Test) is
      pragma Unreferenced (T);
      Session : Session_Record;
      Turn    : Turn_Record;
      M       : Session_Metrics_Record;
      Tol     : constant Long_Float := 1.0e-9;
   begin
      Turn.Turn_Index := 1;
      Turn.Tool_Calls.Append (Make_TC ("tool", "{""x"":""val""}"));
      Turn.Tool_Calls.Append (Make_TC ("tool", "{""x"":""val""}"));
      Session.Turns.Append (Turn);
      Session.Session_Id := To_Unbounded_String ("j1");

      M := Coyote_SQC.Metrics.Compute (Session);

      Assert (M.N_Consecutive_Tool_Pairs = 1,
              "Two identical calls: N_Consecutive_Tool_Pairs must be 1; got "
              & Natural'Image (M.N_Consecutive_Tool_Pairs));
      Assert (M.Per_Consecutive_Tool_S.Length = 2,
              "Two identical calls: Per_Consecutive_Tool_S.Length must be 2; got "
              & Ada.Containers.Count_Type'Image
                  (M.Per_Consecutive_Tool_S.Length));
      Assert (abs (M.Total_Tool_Call_JSD_S - 4.0) <= Tol,
              "Two identical calls: Total_Tool_Call_JSD_S must be 4.0; got "
              & Long_Float'Image (M.Total_Tool_Call_JSD_S));
   end Test_Metrics_JSD_Two_Identical_Calls;

   --  Session with exactly one tool call: no consecutive pair possible.
   procedure Test_Metrics_JSD_Single_Tool_Call (T : in out Test) is
      pragma Unreferenced (T);
      Session : Session_Record;
      Turn    : Turn_Record;
      M       : Session_Metrics_Record;
   begin
      Turn.Turn_Index := 1;
      Turn.Tool_Calls.Append (Make_TC ("shell", "{""command"":""ls""}"));
      Session.Turns.Append (Turn);
      Session.Session_Id := To_Unbounded_String ("j2");

      M := Coyote_SQC.Metrics.Compute (Session);

      Assert (M.N_Consecutive_Tool_Pairs = 0,
              "Single tool call: N_Consecutive_Tool_Pairs must be 0");
      Assert (M.Per_Consecutive_Tool_S.Is_Empty,
              "Single tool call: Per_Consecutive_Tool_S must be empty");
      Assert (M.Total_Tool_Call_JSD_S = 0.0,
              "Single tool call: Total_Tool_Call_JSD_S must be 0.0");
   end Test_Metrics_JSD_Single_Tool_Call;

   --  Session with no tool calls: all JSD fields are zero/empty.
   procedure Test_Metrics_JSD_No_Tool_Calls (T : in out Test) is
      pragma Unreferenced (T);
      Session : Session_Record;
      Turn    : Turn_Record;
      M       : Session_Metrics_Record;
   begin
      Turn.Turn_Index := 1;
      Session.Turns.Append (Turn);
      Session.Session_Id := To_Unbounded_String ("j3");

      M := Coyote_SQC.Metrics.Compute (Session);

      Assert (M.N_Consecutive_Tool_Pairs = 0,
              "No tool calls: N_Consecutive_Tool_Pairs must be 0");
      Assert (M.Total_Tool_Call_JSD_S = 0.0,
              "No tool calls: Total_Tool_Call_JSD_S must be 0.0");
   end Test_Metrics_JSD_No_Tool_Calls;

   --  Total_Tool_Call_JSD_S equals the sum of Per_Consecutive_Tool_S.
   procedure Test_Metrics_JSD_Total_S_Sum (T : in out Test) is
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
      Session.Session_Id := To_Unbounded_String ("j4");

      M := Coyote_SQC.Metrics.Compute (Session);

      for V of M.Per_Consecutive_Tool_S loop
         Manual := Manual + V;
      end loop;
      Assert (abs (M.Total_Tool_Call_JSD_S - Manual) <= Tol,
              "Total_Tool_Call_JSD_S must equal sum of Per_Consecutive_Tool_S; "
              & "Total=" & Long_Float'Image (M.Total_Tool_Call_JSD_S)
              & " Manual=" & Long_Float'Image (Manual));
   end Test_Metrics_JSD_Total_S_Sum;

   --  Tool calls in different turns are treated as consecutive pairs.
   procedure Test_Metrics_JSD_Cross_Turn_Pairs (T : in out Test) is
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
      Session.Session_Id := To_Unbounded_String ("j5");

      M := Coyote_SQC.Metrics.Compute (Session);

      --  One call in turn 1, one in turn 2: still one consecutive pair.
      Assert (M.N_Consecutive_Tool_Pairs = 1,
              "Cross-turn pair: N_Consecutive_Tool_Pairs must be 1; got "
              & Natural'Image (M.N_Consecutive_Tool_Pairs));
   end Test_Metrics_JSD_Cross_Turn_Pairs;

   --  ── Estimate_Parameters for JSD sum charts ────────────────────────────

   --  Build a minimal Session_Metrics_Record with known JSD sum values.
   function Make_JSD_Metrics
     (Id    : String;
      JSD_S : Long_Float;
      Pairs : Natural) return Session_Metrics_Record
   is
      M : Session_Metrics_Record;
   begin
      M.Session_Id               := To_Unbounded_String (Id);
      M.N_Turns                  := 1;
      M.Total_Tool_Call_JSD_S    := JSD_S;
      M.N_Consecutive_Tool_Pairs := Pairs;
      return M;
   end Make_JSD_Metrics;

   --  Three sessions with known Total_Tool_Call_JSD_S values [10, 20, 30]:
   --  Grand_Mean = 20.0, Mean_MR = 10.0.
   procedure Test_Estimate_JSD_Sum_I_Grand_Mean (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Charts;
      use Coyote_SQC.Statistics;
      Metrics : Metrics_Vectors.Vector;
      Setup   : UUID_Set;
      Params  : Setup_Parameters;
      Tol     : constant Long_Float := 1.0e-6;
   begin
      Metrics.Append (Make_JSD_Metrics ("j1", 10.0, 1));
      Metrics.Append (Make_JSD_Metrics ("j2", 20.0, 1));
      Metrics.Append (Make_JSD_Metrics ("j3", 30.0, 1));

      Estimate_Parameters
        (Metrics, Setup, Session_Tool_Call_JSD_Sum_I, Parameters => Params);

      Assert (abs (Params.Grand_Mean - 20.0) <= Tol,
              "JSD Sum I: Grand_Mean should be 20.0; got "
              & Long_Float'Image (Params.Grand_Mean));
   end Test_Estimate_JSD_Sum_I_Grand_Mean;

   --  Three sessions [10, 20, 30]: Mean_MR = (10 + 10) / 2 = 10.0.
   procedure Test_Estimate_JSD_Sum_I_Mean_MR (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Charts;
      use Coyote_SQC.Statistics;
      Metrics : Metrics_Vectors.Vector;
      Setup   : UUID_Set;
      Params  : Setup_Parameters;
      Tol     : constant Long_Float := 1.0e-6;
   begin
      Metrics.Append (Make_JSD_Metrics ("j1", 10.0, 1));
      Metrics.Append (Make_JSD_Metrics ("j2", 20.0, 1));
      Metrics.Append (Make_JSD_Metrics ("j3", 30.0, 1));

      Estimate_Parameters
        (Metrics, Setup, Session_Tool_Call_JSD_Sum_I, Parameters => Params);

      Assert (abs (Params.Mean_MR - 10.0) <= Tol,
              "JSD Sum I: Mean_MR should be 10.0; got "
              & Long_Float'Image (Params.Mean_MR));
   end Test_Estimate_JSD_Sum_I_Mean_MR;

   --  Sessions with N_Consecutive_Tool_Pairs = 0 must be excluded from
   --  parameter estimation.
   procedure Test_Estimate_JSD_Sum_Excludes_No_Pairs (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Charts;
      use Coyote_SQC.Statistics;
      Metrics : Metrics_Vectors.Vector;
      Setup   : UUID_Set;
      Params  : Setup_Parameters;
      Tol     : constant Long_Float := 1.0e-6;
   begin
      --  Two eligible sessions [10, 30] plus one excluded session
      --  (Pairs=0, JSD_S=999).
      Metrics.Append (Make_JSD_Metrics ("j1", 10.0, 1));
      Metrics.Append (Make_JSD_Metrics ("j_skip", 999.0, 0));
      Metrics.Append (Make_JSD_Metrics ("j3", 30.0, 1));

      Estimate_Parameters
        (Metrics, Setup, Session_Tool_Call_JSD_Sum_I, Parameters => Params);

      --  Grand_Mean from eligible sessions only = (10+30)/2 = 20.0.
      Assert (abs (Params.Grand_Mean - 20.0) <= Tol,
              "JSD Sum I excludes Pairs=0: Grand_Mean should be 20.0; got "
              & Long_Float'Image (Params.Grand_Mean));
      --  Mean_MR: only |30-10|/1 = 20.0 (sessions j1 and j3 are consecutive
      --  after skipping j_skip).
      Assert (abs (Params.Mean_MR - 20.0) <= Tol,
              "JSD Sum I excludes Pairs=0: Mean_MR should be 20.0; got "
              & Long_Float'Image (Params.Mean_MR));
   end Test_Estimate_JSD_Sum_Excludes_No_Pairs;

end Coyote_SQC_JSD_Tests;
