--  Coyote_SQC_Workspace_Tests body.
--
--  Project: coyote

with Ada.Calendar;
with Ada.Containers;
with Ada.Directories;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Ada.Text_IO;
with AUnit.Assertions;
with Coyote_SQC.Data_Model;
with Coyote_SQC.Workspace;

package body Coyote_SQC_Workspace_Tests is

   use AUnit.Assertions;
   use type Ada.Containers.Count_Type;
   use Coyote_SQC.Data_Model;

   --  ── Round-trip test ───────────────────────────────────────────────────

   procedure Test_Round_Trip (T : in out Test) is
      pragma Unreferenced (T);
      Path   : constant String :=
        Ada.Directories.Current_Directory & "/fixtures/sqc/tmp_workspace.sqcw";
      W_Out  : Workspace_Record;
      W_In   : Workspace_Record;
   begin
      W_Out.Workspace_Id := To_Unbounded_String ("test-ws-001");
      W_Out.Name         := To_Unbounded_String ("My Test Workspace");
      W_Out.Source_Directories.Append
        (To_Unbounded_String ("/home/user/project"));
      W_Out.Model_Filter.Append
        (To_Unbounded_String ("anthropic/claude-sonnet-4-5"));
      W_Out.Setup_Session_Ids.Include
        (To_Unbounded_String ("session-uuid-aaa"));
      W_Out.Setup_Session_Ids.Include
        (To_Unbounded_String ("session-uuid-bbb"));
      --  Add a comment to test round-trip.
      W_Out.Comments.Append
        ((Comment_Id => To_Unbounded_String ("cmt-001"),
          Session_Id => To_Unbounded_String ("session-uuid-aaa"),
          Timestamp  => Ada.Calendar.Time_Of (2025, 1, 15, 43200.0),
          Text       => To_Unbounded_String ("Test comment text")));

      Coyote_SQC.Workspace.Save (Path, W_Out);
      declare VF_Unused : Natural; begin Coyote_SQC.Workspace.Load (Path, W_In, VF_Unused); end;

      Assert
        (To_String (W_In.Workspace_Id) = "test-ws-001",
         "Workspace_Id round-trip failed");
      Assert
        (To_String (W_In.Name) = "My Test Workspace",
         "Name round-trip failed");
      Assert
        (W_In.Source_Directories.Length = 1,
         "Source_Directories length mismatch");
      Assert
        (To_String (W_In.Source_Directories.Element (1)) = "/home/user/project",
         "Source_Directories[1] round-trip failed");
      Assert
        (W_In.Model_Filter.Length = 1,
         "Model_Filter length mismatch");
      Assert
        (W_In.Setup_Session_Ids.Length = 2,
         "Setup_Session_Ids should have 2 elements");
      Assert
        (W_In.Setup_Session_Ids.Contains
           (To_Unbounded_String ("session-uuid-aaa")),
         "session-uuid-aaa missing from loaded setup interval");
      Assert
        (W_In.Setup_Session_Ids.Contains
           (To_Unbounded_String ("session-uuid-bbb")),
         "session-uuid-bbb missing from loaded setup interval");

      Assert
        (W_In.Comments.Length = 1,
         "Comments length should be 1 after round-trip");
      Assert
        (To_String (W_In.Comments.Element (1).Comment_Id) = "cmt-001",
         "Comment_Id round-trip failed");
      Assert
        (To_String (W_In.Comments.Element (1).Text) = "Test comment text",
         "Comment text round-trip failed");
      Assert
        (To_String (W_In.Comments.Element (1).Session_Id) = "session-uuid-aaa",
         "Comment session_id round-trip failed");
      Ada.Directories.Delete_File (Path);
   end Test_Round_Trip;

   --  ── Version too high ──────────────────────────────────────────────────

   procedure Test_Version_Too_High (T : in out Test) is
      pragma Unreferenced (T);
      Path    : constant String :=
        Ada.Directories.Current_Directory
        & "/fixtures/sqc/tmp_version_high.sqcw";
      W       : Workspace_Record;
      Raised  : Boolean := False;

      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put_Line
        (File, "{""version"":99,""workspaceId"":"""",""name"":"""","
         & """sourceDirectories"":[],""modelFilter"":[],"
         & """setupSessionIds"":[],""comments"":[]}");
      Ada.Text_IO.Close (File);

      begin
         declare VF_Unused : Natural; begin Coyote_SQC.Workspace.Load (Path, W, VF_Unused); end;
      exception
         when Coyote_SQC.Workspace.Workspace_Error => Raised := True;
      end;

      Ada.Directories.Delete_File (Path);
      Assert (Raised, "Load should raise Workspace_Error for version > 2");
   end Test_Version_Too_High;

   --  ── Missing version ───────────────────────────────────────────────────

   procedure Test_Missing_Version (T : in out Test) is
      pragma Unreferenced (T);
      Path    : constant String :=
        Ada.Directories.Current_Directory
        & "/fixtures/sqc/tmp_version_missing.sqcw";
      W       : Workspace_Record;
      Raised  : Boolean := False;

      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put_Line
        (File, "{""workspaceId"":""x"",""name"":""y"","
         & """sourceDirectories"":[],""modelFilter"":[],"
         & """setupSessionIds"":[],""comments"":[]}");
      Ada.Text_IO.Close (File);

      --  Missing version: should load without raising (best-effort).
      begin
         declare VF_Unused : Natural; begin Coyote_SQC.Workspace.Load (Path, W, VF_Unused); end;
      exception
         when Coyote_SQC.Workspace.Workspace_Error => Raised := True;
      end;

      Ada.Directories.Delete_File (Path);
      --  Spec §9.3: version absent → load with warning, no exception.
      Assert
        (not Raised,
         "Load should not raise for a workspace without a version field");
   end Test_Missing_Version;

   --  ── UUID deduplication ────────────────────────────────────────────────

   procedure Test_UUID_Deduplication (T : in out Test) is
      pragma Unreferenced (T);
      Path    : constant String :=
        Ada.Directories.Current_Directory
        & "/fixtures/sqc/tmp_dedup.sqcw";
      W       : Workspace_Record;

      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put_Line
        (File,
         "{""version"":1,""workspaceId"":"""",""name"":"""","
         & """sourceDirectories"":[],""modelFilter"":[],"
         & """setupSessionIds"":[""aaa"",""aaa"",""bbb""],"
         & """comments"":[]}");
      Ada.Text_IO.Close (File);

      declare VF_Unused : Natural; begin Coyote_SQC.Workspace.Load (Path, W, VF_Unused); end;
      Ada.Directories.Delete_File (Path);

      Assert
        (W.Setup_Session_Ids.Length = 2,
         "Duplicate UUID should be deduplicated; got "
         & Ada.Containers.Count_Type'Image (W.Setup_Session_Ids.Length));
   end Test_UUID_Deduplication;

   --  ── New_UUID ──────────────────────────────────────────────────────────

   procedure Test_New_UUID_Format (T : in out Test) is
      pragma Unreferenced (T);
      ID : constant String := Coyote_SQC.Workspace.New_UUID;
   begin
      Assert (ID'Length = 36, "UUID must be 36 characters long");
      Assert (ID (9) = '-', "UUID hyphen at position 9 missing");
      Assert (ID (14) = '-', "UUID hyphen at position 14 missing");
      Assert (ID (19) = '-', "UUID hyphen at position 19 missing");
      Assert (ID (24) = '-', "UUID hyphen at position 24 missing");
      Assert (ID (15) = '4', "UUID version nibble must be '4'");
      Assert
        (ID (20) = '8' or else ID (20) = '9'
         or else ID (20) = 'a' or else ID (20) = 'b',
         "UUID variant bits must be 8, 9, a, or b");
   end Test_New_UUID_Format;

   procedure Test_New_UUID_Unique (T : in out Test) is
      pragma Unreferenced (T);
      ID1 : constant String := Coyote_SQC.Workspace.New_UUID;
      ID2 : constant String := Coyote_SQC.Workspace.New_UUID;
   begin
      Assert (ID1 /= ID2, "Two New_UUID calls should not return the same value");
   end Test_New_UUID_Unique;


   --  ── Box-Cox configuration round-trip ──────────────────────────────────

   --  Saving a workspace with Box-Cox enabled (auto) and loading it back
   --  should preserve all fields exactly.
   procedure Test_Box_Cox_Round_Trip (T : in out Test) is
      pragma Unreferenced (T);
      Path  : constant String :=
        Ada.Directories.Current_Directory
        & "/fixtures/sqc/tmp_bc_roundtrip.sqcw";
      W_Out : Workspace_Record;
      W_In  : Workspace_Record;
   begin
      W_Out.Workspace_Id := To_Unbounded_String ("bc-ws-001");
      W_Out.Name         := To_Unbounded_String ("BC Test Workspace");
      W_Out.I_Chart_Box_Cox :=
        (Enabled       => True,
         Lambda_Source => Coyote_SQC.Data_Model.Fixed,
         Fixed_Lambda  => 0.31);
      W_Out.Xbar_S_Box_Cox :=
        (Enabled       => True,
         Lambda_Source => Coyote_SQC.Data_Model.Auto,
         Fixed_Lambda  => 0.0);

      Coyote_SQC.Workspace.Save (Path, W_Out);
      declare VF_Unused : Natural;
      begin
         Coyote_SQC.Workspace.Load (Path, W_In, VF_Unused);
      end;
      Ada.Directories.Delete_File (Path);

      Assert
        (W_In.I_Chart_Box_Cox.Enabled,
         "Box_Cox.Enabled should be True after round-trip");
      Assert
        (W_In.I_Chart_Box_Cox.Lambda_Source =
           Coyote_SQC.Data_Model.Fixed,
         "Lambda_Source should be Fixed after round-trip");
      Assert
        (abs (W_In.I_Chart_Box_Cox.Fixed_Lambda - 0.31) < 0.001,
         "Fixed_Lambda should be 0.31 after round-trip; got "
         & Long_Float'Image (W_In.I_Chart_Box_Cox.Fixed_Lambda));
      Assert
        (W_In.Xbar_S_Box_Cox.Enabled,
         "Xbar_S_Box_Cox.Enabled should be True after round-trip");
      Assert
        (W_In.Xbar_S_Box_Cox.Lambda_Source =
           Coyote_SQC.Data_Model.Auto,
         "Xbar_S_Box_Cox.Lambda_Source should be Auto after round-trip");
   end Test_Box_Cox_Round_Trip;

   --  Robust_Auto lambda source survives a save/load round-trip.
   procedure Test_Robust_Auto_Round_Trip (T : in out Test) is
      pragma Unreferenced (T);
      Path  : constant String :=
        Ada.Directories.Current_Directory
        & "/fixtures/sqc/tmp_robust_auto_roundtrip.sqcw";
      W_Out : Workspace_Record;
      W_In  : Workspace_Record;
   begin
      W_Out.Workspace_Id := To_Unbounded_String ("robust-ws-001");
      W_Out.Name         := To_Unbounded_String ("Robust Auto Test");
      W_Out.I_Chart_Box_Cox :=
        (Enabled       => True,
         Lambda_Source => Coyote_SQC.Data_Model.Robust_Auto,
         Fixed_Lambda  => 0.0);
      W_Out.Xbar_S_Box_Cox :=
        (Enabled       => True,
         Lambda_Source => Coyote_SQC.Data_Model.Robust_Auto,
         Fixed_Lambda  => 0.0);
      W_Out.Turn_Count_Box_Cox :=
        (Enabled       => True,
         Lambda_Source => Coyote_SQC.Data_Model.Robust_Auto,
         Fixed_Lambda  => 0.0);

      Coyote_SQC.Workspace.Save (Path, W_Out);
      declare VF_Unused : Natural;
      begin
         Coyote_SQC.Workspace.Load (Path, W_In, VF_Unused);
      end;
      Ada.Directories.Delete_File (Path);

      Assert
        (W_In.I_Chart_Box_Cox.Lambda_Source =
           Coyote_SQC.Data_Model.Robust_Auto,
         "I_Chart_Box_Cox.Lambda_Source should be Robust_Auto after "
         & "round-trip");
      Assert
        (W_In.Xbar_S_Box_Cox.Lambda_Source =
           Coyote_SQC.Data_Model.Robust_Auto,
         "Xbar_S_Box_Cox.Lambda_Source should be Robust_Auto after "
         & "round-trip");
      Assert
        (W_In.Turn_Count_Box_Cox.Lambda_Source =
           Coyote_SQC.Data_Model.Robust_Auto,
         "Turn_Count_Box_Cox.Lambda_Source should be Robust_Auto after "
         & "round-trip");
   end Test_Robust_Auto_Round_Trip;


   --  Loading a v1 workspace (no iChartBoxCox field) should give
   --  Box-Cox disabled by default.
   procedure Test_V1_Loads_Box_Cox_Disabled (T : in out Test) is
      pragma Unreferenced (T);
      Path  : constant String :=
        Ada.Directories.Current_Directory
        & "/fixtures/sqc/tmp_v1_bc_default.sqcw";
      W     : Workspace_Record;
      File  : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put_Line
        (File,
         "{""version"":1,""workspaceId"":""x"",""name"":""y"","
         & """sourceDirectories"":[],""modelFilter"":[],"
         & """setupSessionIds"":[],""comments"":[]}");
      Ada.Text_IO.Close (File);

      declare VF_Unused : Natural;
      begin
         Coyote_SQC.Workspace.Load (Path, W, VF_Unused);
      end;
      Ada.Directories.Delete_File (Path);

      Assert
        (not W.I_Chart_Box_Cox.Enabled,
         "Box-Cox should default to disabled when loading a v1 workspace");
   end Test_V1_Loads_Box_Cox_Disabled;


   --  Round-trip: EWMA_Weight and EWMA_L survive save/load.
   procedure Test_EWMA_Round_Trip (T : in out Test) is
      pragma Unreferenced (T);
      Path  : constant String :=
        Ada.Directories.Current_Directory
        & "/fixtures/sqc/tmp_ewma_roundtrip.sqcw";
      W_Out : Workspace_Record;
      W_In  : Workspace_Record;
      VF    : Natural;
   begin
      W_Out.Workspace_Id := To_Unbounded_String ("ewma-ws-id");
      W_Out.Name         := To_Unbounded_String ("EWMA Test");
      W_Out.EWMA_Weight  := 0.15;
      W_Out.EWMA_L       := 2.75;

      Coyote_SQC.Workspace.Save (Path, W_Out);
      Coyote_SQC.Workspace.Load (Path, W_In, VF);
      Ada.Directories.Delete_File (Path);

      Assert
        (abs (W_In.EWMA_Weight - 0.15) < 0.001,
         "EWMA_Weight wrong after round-trip; got "
         & Long_Float'Image (W_In.EWMA_Weight));
      Assert
        (abs (W_In.EWMA_L - 2.75) < 0.001,
         "EWMA_L wrong after round-trip; got "
         & Long_Float'Image (W_In.EWMA_L));
      Assert (VF = 6, "Version should be 6; got " & Natural'Image (VF));
   end Test_EWMA_Round_Trip;

   --  Loading a v3 workspace (no ewmaWeight/ewmaL fields) should give
   --  default values (0.2 and 3.0).
   procedure Test_V3_Loads_EWMA_Defaults (T : in out Test) is
      pragma Unreferenced (T);
      Path : constant String :=
        Ada.Directories.Current_Directory
        & "/fixtures/sqc/tmp_v3_ewma_default.sqcw";
      W    : Workspace_Record;
      File : Ada.Text_IO.File_Type;
      VF   : Natural;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put_Line
        (File,
         "{""version"":3,""workspaceId"":""x"",""name"":""y"","
         & """sourceDirectories"":[],""modelFilter"":[],"
         & """setupSessionIds"":[],""comments"":[]}");
      Ada.Text_IO.Close (File);

      Coyote_SQC.Workspace.Load (Path, W, VF);
      Ada.Directories.Delete_File (Path);

      Assert
        (abs (W.EWMA_Weight - 0.2) < 0.001,
         "EWMA_Weight should default to 0.2 for v3 workspace; got "
         & Long_Float'Image (W.EWMA_Weight));
      Assert
        (abs (W.EWMA_L - 3.0) < 0.001,
         "EWMA_L should default to 3.0 for v3 workspace; got "
         & Long_Float'Image (W.EWMA_L));
   end Test_V3_Loads_EWMA_Defaults;

   --  Round-trip: Turn_Count_Box_Cox config survives save/load.
   procedure Test_Turn_Count_Box_Cox_Round_Trip (T : in out Test) is
      pragma Unreferenced (T);
      Path  : constant String :=
        Ada.Directories.Current_Directory
        & "/fixtures/sqc/tmp_tc_roundtrip.sqcw";
      W_Out : Workspace_Record;
      W_In  : Workspace_Record;
      VF    : Natural;
   begin
      W_Out.Workspace_Id := To_Unbounded_String ("tc-ws-id");
      W_Out.Name         := To_Unbounded_String ("TC Test");
      W_Out.Turn_Count_Box_Cox :=
        (Enabled       => True,
         Lambda_Source => Fixed,
         Fixed_Lambda  => 0.5);

      Coyote_SQC.Workspace.Save (Path, W_Out);
      Coyote_SQC.Workspace.Load (Path, W_In, VF);
      Ada.Directories.Delete_File (Path);

      Assert
        (W_In.Turn_Count_Box_Cox.Enabled,
         "Turn_Count_Box_Cox.Enabled should be True after round-trip");
      Assert
        (W_In.Turn_Count_Box_Cox.Lambda_Source = Fixed,
         "Turn_Count_Box_Cox.Lambda_Source should be Fixed after round-trip");
      Assert
        (abs (W_In.Turn_Count_Box_Cox.Fixed_Lambda - 0.5) < 0.001,
         "Turn_Count_Box_Cox.Fixed_Lambda should be 0.5; got "
         & Long_Float'Image (W_In.Turn_Count_Box_Cox.Fixed_Lambda));
      Assert
        (VF = 6, "Version should be 6; got " & Natural'Image (VF));
   end Test_Turn_Count_Box_Cox_Round_Trip;

   --  Loading a v4 workspace (no turnCountBoxCox field) should give
   --  default (disabled, auto, fixed_lambda=0.0).
   procedure Test_V4_Loads_Turn_Count_Defaults (T : in out Test) is
      pragma Unreferenced (T);
      Path : constant String :=
        Ada.Directories.Current_Directory
        & "/fixtures/sqc/tmp_v4_tc_default.sqcw";
      W    : Workspace_Record;
      File : Ada.Text_IO.File_Type;
      VF   : Natural;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put_Line
        (File,
         "{""version"":4,""workspaceId"":""x"",""name"":""y"","
         & """sourceDirectories"":[],""modelFilter"":[],"
         & """setupSessionIds"":[],""comments"":[],"
         & """ewmaWeight"":0.2,""ewmaL"":3.0}");
      Ada.Text_IO.Close (File);

      Coyote_SQC.Workspace.Load (Path, W, VF);
      Ada.Directories.Delete_File (Path);

      Assert
        (not W.Turn_Count_Box_Cox.Enabled,
         "Turn_Count_Box_Cox.Enabled should default to False "
         & "for v4 workspace");
      Assert
        (W.Turn_Count_Box_Cox.Lambda_Source = Auto,
         "Turn_Count_Box_Cox.Lambda_Source should default to Auto "
         & "for v4 workspace");
      Assert
        (abs (W.Turn_Count_Box_Cox.Fixed_Lambda - 0.0) < 0.001,
         "Turn_Count_Box_Cox.Fixed_Lambda should default to 0.0 "
         & "for v4 workspace; got "
         & Long_Float'Image (W.Turn_Count_Box_Cox.Fixed_Lambda));
   end Test_V4_Loads_Turn_Count_Defaults;



   --  Round-trip: Estimation_Method = Robust_Median survives save/load.
   procedure Test_Estimation_Method_Round_Trip (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Data_Model;
      Path : constant String :=
        Ada.Directories.Current_Directory
        & "/fixtures/sqc/tmp_estimation_rt.sqcw";
      W_Out, W_In : Workspace_Record;
      VF          : Natural;
   begin
      W_Out.Workspace_Id :=
        Ada.Strings.Unbounded.To_Unbounded_String ("test-est-rt");
      W_Out.Name := Ada.Strings.Unbounded.To_Unbounded_String ("est-test");
      W_Out.Estimation_Method := Robust_Median;

      Coyote_SQC.Workspace.Save (Path, W_Out);
      Coyote_SQC.Workspace.Load (Path, W_In, VF);
      Ada.Directories.Delete_File (Path);

      Assert
        (W_In.Estimation_Method = Robust_Median,
         "Estimation_Method should survive save/load as Robust_Median");
      Assert
        (VF = 6, "Version should be 6; got " & Natural'Image (VF));
   end Test_Estimation_Method_Round_Trip;

   --  Loading a v5 workspace (no estimationMethod field) should give
   --  default Classical.
   procedure Test_V5_Loads_Classical_Default (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Data_Model;
      Path : constant String :=
        Ada.Directories.Current_Directory
        & "/fixtures/sqc/tmp_v5_est_default.sqcw";
      W    : Workspace_Record;
      File : Ada.Text_IO.File_Type;
      VF   : Natural;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put_Line
        (File,
         "{""version"":5,""workspaceId"":""x"",""name"":""y"","
         & """sourceDirectories"":[],""modelFilter"":[],"
         & """setupSessionIds"":[],""comments"":[],"
         & """ewmaWeight"":0.2,""ewmaL"":3.0,"
         & """iChartBoxCox"":{""enabled"":false,"
         & """lambdaSource"":""auto"",""fixedLambda"":0.0},"
         & """xbarSBoxCox"":{""enabled"":false,"
         & """lambdaSource"":""auto"",""fixedLambda"":0.0},"
         & """turnCountBoxCox"":{""enabled"":false,"
         & """lambdaSource"":""auto"",""fixedLambda"":0.0}}");
      Ada.Text_IO.Close (File);

      Coyote_SQC.Workspace.Load (Path, W, VF);
      Ada.Directories.Delete_File (Path);

      Assert
        (W.Estimation_Method = Classical,
         "Estimation_Method should default to Classical "
         & "for v5 workspace (missing field)");
   end Test_V5_Loads_Classical_Default;

end Coyote_SQC_Workspace_Tests;
