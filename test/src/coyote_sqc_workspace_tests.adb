with AUnit.Test_Caller;
--  Coyote_SQC_Workspace_Tests body.
--
--  Project: coyote

with Ada.Calendar;
with Ada.Containers;
with Ada.Directories;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Ada.Text_IO;
with AUnit.Assertions;
with Coyote_SQC.Charts;
with Coyote_SQC.Data_Model;
with Coyote_SQC.Workspace;

package body Coyote_SQC_Workspace_Tests is

   use AUnit.Assertions;
   use type Ada.Containers.Count_Type;
   use Coyote_SQC.Data_Model;

   procedure Load_All_Ignored
     (Path      :     String;
      Workspace : out Workspace_Record)
   is
      VF       : Natural;
      Migrated : Boolean;
   begin
      Coyote_SQC.Workspace.Load (Path, Workspace, VF, Migrated);
   end Load_All_Ignored;

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
      Load_All_Ignored (Path, W_In);

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
      Migrated : Boolean;
      VF       : Natural;

      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put_Line
        (File, "{""version"":99,""workspaceId"":"""",""name"":"""","
         & """sourceDirectories"":[],""modelFilter"":[],"
         & """setupSessionIds"":[],""comments"":[]}");
      Ada.Text_IO.Close (File);

      begin
         Coyote_SQC.Workspace.Load (Path, W, VF, Migrated);
      exception
         when Coyote_SQC.Workspace.Workspace_Error => Raised := True;
      end;

      Ada.Directories.Delete_File (Path);
      Assert (Raised, "Load should raise Workspace_Error for version > 7");
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
         Load_All_Ignored (Path, W);
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

      Load_All_Ignored (Path, W);
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

   --  ── Per-chart Box-Cox configuration round-trip ────────────────────────
   --
   --  Saving a workspace with Box-Cox enabled on Session_Input_Tokens_I and
   --  loading it back should preserve all fields exactly.

   procedure Test_Box_Cox_Round_Trip (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Charts;
      Path  : constant String :=
        Ada.Directories.Current_Directory
        & "/fixtures/sqc/tmp_bc_roundtrip.sqcw";
      W_Out : Workspace_Record;
      W_In  : Workspace_Record;
      Cfg   : Chart_Settings_Record;
   begin
      W_Out.Workspace_Id := To_Unbounded_String ("bc-ws-001");
      W_Out.Name         := To_Unbounded_String ("BC Test Workspace");

      --  Enable Box-Cox (Fixed, λ=0.31) on Session_Input_Tokens_I.
      Cfg.Transform :=
        (Kind          => Box_Cox,
         Lambda_Source => Fixed,
         Fixed_Lambda  => 0.31);
      W_Out.Chart_Settings.Include (Session_Input_Tokens_I, Cfg);

      --  Enable Box-Cox (Auto) on Turn_Tokens_Xbar.
      Cfg := (others => <>);
      Cfg.Transform :=
        (Kind          => Box_Cox,
         Lambda_Source => Auto,
         Fixed_Lambda  => 0.0);
      W_Out.Chart_Settings.Include (Turn_Tokens_Xbar, Cfg);

      Coyote_SQC.Workspace.Save (Path, W_Out);
      Load_All_Ignored (Path, W_In);
      Ada.Directories.Delete_File (Path);

      declare
         I_Cfg : constant Chart_Settings_Record :=
           Coyote_SQC.Workspace.Chart_Settings (W_In, Session_Input_Tokens_I);
         X_Cfg : constant Chart_Settings_Record :=
           Coyote_SQC.Workspace.Chart_Settings (W_In, Turn_Tokens_Xbar);
      begin
         Assert
           (I_Cfg.Transform.Kind /= None,
            "Session_Input_Tokens_I Transform.Kind should be Box_Cox");
         Assert
           (I_Cfg.Transform.Lambda_Source = Fixed,
            "Session_Input_Tokens_I Lambda_Source should be Fixed");
         Assert
           (abs (I_Cfg.Transform.Fixed_Lambda - 0.31) < 0.001,
            "Session_Input_Tokens_I Fixed_Lambda should be 0.31; got "
            & Long_Float'Image (I_Cfg.Transform.Fixed_Lambda));
         Assert
           (X_Cfg.Transform.Kind /= None,
            "Turn_Tokens_Xbar Transform.Kind should be Box_Cox");
         Assert
           (X_Cfg.Transform.Lambda_Source = Auto,
            "Turn_Tokens_Xbar Lambda_Source should be Auto");
      end;
   end Test_Box_Cox_Round_Trip;

   --  Robust_Auto lambda source survives a save/load round-trip.
   procedure Test_Robust_Auto_Round_Trip (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Charts;
      Path  : constant String :=
        Ada.Directories.Current_Directory
        & "/fixtures/sqc/tmp_robust_auto_roundtrip.sqcw";
      W_Out : Workspace_Record;
      W_In  : Workspace_Record;
      Cfg   : Chart_Settings_Record;
   begin
      W_Out.Workspace_Id := To_Unbounded_String ("robust-ws-001");
      W_Out.Name         := To_Unbounded_String ("Robust Auto Test");

      Cfg.Transform :=
        (Kind          => Box_Cox,
         Lambda_Source => Robust_Auto,
         Fixed_Lambda  => 0.0);
      W_Out.Chart_Settings.Include (Session_Input_Tokens_I, Cfg);
      W_Out.Chart_Settings.Include (Turn_Tokens_Xbar, Cfg);
      W_Out.Chart_Settings.Include (Session_Turn_Count_I, Cfg);

      Coyote_SQC.Workspace.Save (Path, W_Out);
      Load_All_Ignored (Path, W_In);
      Ada.Directories.Delete_File (Path);

      Assert
        (Coyote_SQC.Workspace.Chart_Settings
           (W_In, Session_Input_Tokens_I).Transform.Lambda_Source =
           Robust_Auto,
         "Session_Input_Tokens_I.Lambda_Source should be Robust_Auto");
      Assert
        (Coyote_SQC.Workspace.Chart_Settings
           (W_In, Turn_Tokens_Xbar).Transform.Lambda_Source = Robust_Auto,
         "Turn_Tokens_Xbar.Lambda_Source should be Robust_Auto");
      Assert
        (Coyote_SQC.Workspace.Chart_Settings
           (W_In, Session_Turn_Count_I).Transform.Lambda_Source = Robust_Auto,
         "Session_Turn_Count_I.Lambda_Source should be Robust_Auto");
   end Test_Robust_Auto_Round_Trip;

   --  Loading a v1 workspace (no iChartBoxCox field) should give
   --  Box-Cox disabled for all charts by default (empty chart settings map).
   procedure Test_V1_Loads_Box_Cox_Disabled (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Charts;
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

      Load_All_Ignored (Path, W);
      Ada.Directories.Delete_File (Path);

      --  Migration from v1: no iChartBoxCox → chart settings map empty
      --  (disabled Box-Cox is the default, not written).
      Assert
        (Coyote_SQC.Workspace.Chart_Settings
           (W, Session_Input_Tokens_I).Transform.Kind = None,
         "Transform should default to None when loading a v1 workspace");
   end Test_V1_Loads_Box_Cox_Disabled;

   --  Round-trip: per-chart EWMA_Weight and EWMA_L survive save/load.
   procedure Test_EWMA_Round_Trip (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Charts;
      Path  : constant String :=
        Ada.Directories.Current_Directory
        & "/fixtures/sqc/tmp_ewma_roundtrip.sqcw";
      W_Out : Workspace_Record;
      W_In  : Workspace_Record;
      VF    : Natural;
      Migrated : Boolean;
      Cfg   : Chart_Settings_Record;
   begin
      W_Out.Workspace_Id := To_Unbounded_String ("ewma-ws-id");
      W_Out.Name         := To_Unbounded_String ("EWMA Test");

      --  Set non-default EWMA params on Session_Input_Tokens_EWMA.
      Cfg.EWMA_Weight := 0.15;
      Cfg.EWMA_L      := 2.75;
      W_Out.Chart_Settings.Include (Session_Input_Tokens_EWMA, Cfg);

      Coyote_SQC.Workspace.Save (Path, W_Out);
      Coyote_SQC.Workspace.Load (Path, W_In, VF, Migrated);
      Ada.Directories.Delete_File (Path);

      declare
         E_Cfg : constant Chart_Settings_Record :=
           Coyote_SQC.Workspace.Chart_Settings
             (W_In, Session_Input_Tokens_EWMA);
      begin
         Assert
           (abs (E_Cfg.EWMA_Weight - 0.15) < 0.001,
            "EWMA_Weight wrong after round-trip; got "
            & Long_Float'Image (E_Cfg.EWMA_Weight));
         Assert
           (abs (E_Cfg.EWMA_L - 2.75) < 0.001,
            "EWMA_L wrong after round-trip; got "
            & Long_Float'Image (E_Cfg.EWMA_L));
      end;
      Assert (VF = 10, "Version should be 10; got " & Natural'Image (VF));
   end Test_EWMA_Round_Trip;

   --  Loading a v3 workspace (no ewmaWeight/ewmaL fields) should give
   --  default EWMA_Weight=0.2 and EWMA_L=3.0 for all EWMA charts.
   procedure Test_V3_Loads_EWMA_Defaults (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Charts;
      Path : constant String :=
        Ada.Directories.Current_Directory
        & "/fixtures/sqc/tmp_v3_ewma_default.sqcw";
      W    : Workspace_Record;
      File : Ada.Text_IO.File_Type;
      VF   : Natural;
      Migrated : Boolean;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put_Line
        (File,
         "{""version"":3,""workspaceId"":""x"",""name"":""y"","
         & """sourceDirectories"":[],""modelFilter"":[],"
         & """setupSessionIds"":[],""comments"":[]}");
      Ada.Text_IO.Close (File);

      Coyote_SQC.Workspace.Load (Path, W, VF, Migrated);
      Ada.Directories.Delete_File (Path);

      --  v3 had no ewmaWeight/ewmaL: defaults are 0.2 and 3.0.
      --  After migration, no entries are written (defaults don't get entries).
      declare
         E_Cfg : constant Chart_Settings_Record :=
           Coyote_SQC.Workspace.Chart_Settings
             (W, Session_Input_Tokens_EWMA);
      begin
         Assert
           (abs (E_Cfg.EWMA_Weight - 0.2) < 0.001,
            "EWMA_Weight should default to 0.2 for v3 workspace; got "
            & Long_Float'Image (E_Cfg.EWMA_Weight));
         Assert
           (abs (E_Cfg.EWMA_L - 3.0) < 0.001,
            "EWMA_L should default to 3.0 for v3 workspace; got "
            & Long_Float'Image (E_Cfg.EWMA_L));
      end;
   end Test_V3_Loads_EWMA_Defaults;

   --  Round-trip: per-chart Turn Count Box-Cox config survives save/load.
   procedure Test_Turn_Count_Box_Cox_Round_Trip (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Charts;
      Path  : constant String :=
        Ada.Directories.Current_Directory
        & "/fixtures/sqc/tmp_tc_roundtrip.sqcw";
      W_Out : Workspace_Record;
      W_In  : Workspace_Record;
      VF    : Natural;
      Migrated : Boolean;
      Cfg   : Chart_Settings_Record;
   begin
      W_Out.Workspace_Id := To_Unbounded_String ("tc-ws-id");
      W_Out.Name         := To_Unbounded_String ("TC Test");

      Cfg.Transform :=
        (Kind          => Box_Cox,
         Lambda_Source => Fixed,
         Fixed_Lambda  => 0.5);
      W_Out.Chart_Settings.Include (Session_Turn_Count_I, Cfg);

      Coyote_SQC.Workspace.Save (Path, W_Out);
      Coyote_SQC.Workspace.Load (Path, W_In, VF, Migrated);
      Ada.Directories.Delete_File (Path);

      declare
         TC_Cfg : constant Chart_Settings_Record :=
           Coyote_SQC.Workspace.Chart_Settings (W_In, Session_Turn_Count_I);
      begin
         Assert
           (TC_Cfg.Transform.Kind /= None,
            "Session_Turn_Count_I Transform.Kind should be Box_Cox");
         Assert
           (TC_Cfg.Transform.Lambda_Source = Fixed,
            "Session_Turn_Count_I Lambda_Source should be Fixed");
         Assert
           (abs (TC_Cfg.Transform.Fixed_Lambda - 0.5) < 0.001,
            "Session_Turn_Count_I Fixed_Lambda should be 0.5; got "
            & Long_Float'Image (TC_Cfg.Transform.Fixed_Lambda));
      end;
      Assert (VF = 10, "Version should be 10; got " & Natural'Image (VF));
   end Test_Turn_Count_Box_Cox_Round_Trip;

   --  Loading a v4 workspace (no turnCountBoxCox field) should give
   --  per-chart default (disabled, auto, fixed_lambda=0.0).
   procedure Test_V4_Loads_Turn_Count_Defaults (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Charts;
      Path : constant String :=
        Ada.Directories.Current_Directory
        & "/fixtures/sqc/tmp_v4_tc_default.sqcw";
      W    : Workspace_Record;
      File : Ada.Text_IO.File_Type;
      VF   : Natural;
      Migrated : Boolean;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put_Line
        (File,
         "{""version"":4,""workspaceId"":""x"",""name"":""y"","
         & """sourceDirectories"":[],""modelFilter"":[],"
         & """setupSessionIds"":[],""comments"":[],"
         & """ewmaWeight"":0.2,""ewmaL"":3.0}");
      Ada.Text_IO.Close (File);

      Coyote_SQC.Workspace.Load (Path, W, VF, Migrated);
      Ada.Directories.Delete_File (Path);

      --  v4 had no turnCountBoxCox → migration leaves Turn Count charts
      --  at default (disabled = not in map).
      declare
         TC_Cfg : constant Chart_Settings_Record :=
           Coyote_SQC.Workspace.Chart_Settings (W, Session_Turn_Count_I);
      begin
         Assert
           (TC_Cfg.Transform.Kind = None,
            "Session_Turn_Count_I Transform.Kind should default to False "
            & "for v4 workspace");
         Assert
           (TC_Cfg.Transform.Lambda_Source = Auto,
            "Session_Turn_Count_I Lambda_Source should default to Auto "
            & "for v4 workspace");
         Assert
           (abs (TC_Cfg.Transform.Fixed_Lambda - 0.0) < 0.001,
            "Session_Turn_Count_I Fixed_Lambda should default to 0.0; got "
            & Long_Float'Image (TC_Cfg.Transform.Fixed_Lambda));
      end;
   end Test_V4_Loads_Turn_Count_Defaults;

   --  Round-trip: per-chart Estimation_Method = Robust_Median survives
   --  save/load.
   procedure Test_Estimation_Method_Round_Trip (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Charts;
      Path : constant String :=
        Ada.Directories.Current_Directory
        & "/fixtures/sqc/tmp_estimation_rt.sqcw";
      W_Out, W_In : Workspace_Record;
      VF          : Natural;
      Migrated    : Boolean;
      Cfg         : Chart_Settings_Record;
   begin
      W_Out.Workspace_Id := To_Unbounded_String ("test-est-rt");
      W_Out.Name         := To_Unbounded_String ("est-test");

      Cfg.Estimation_Method := Robust_Median;
      W_Out.Chart_Settings.Include (Session_Input_Tokens_I, Cfg);

      Coyote_SQC.Workspace.Save (Path, W_Out);
      Coyote_SQC.Workspace.Load (Path, W_In, VF, Migrated);
      Ada.Directories.Delete_File (Path);

      Assert
        (Coyote_SQC.Workspace.Chart_Settings
           (W_In, Session_Input_Tokens_I).Estimation_Method = Robust_Median,
         "Estimation_Method should survive save/load as Robust_Median");
      Assert (VF = 10, "Version should be 10; got " & Natural'Image (VF));
   end Test_Estimation_Method_Round_Trip;

   --  Loading a v5 workspace (no estimationMethod field) should give
   --  default Classical for all charts (empty chart settings map).
   procedure Test_V5_Loads_Classical_Default (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Charts;
      Path : constant String :=
        Ada.Directories.Current_Directory
        & "/fixtures/sqc/tmp_v5_est_default.sqcw";
      W    : Workspace_Record;
      File : Ada.Text_IO.File_Type;
      VF   : Natural;
      Migrated : Boolean;
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

      Coyote_SQC.Workspace.Load (Path, W, VF, Migrated);
      Ada.Directories.Delete_File (Path);

      --  v5 with no estimationMethod field → Classical default →
      --  empty chart settings map after migration.
      Assert
        (Coyote_SQC.Workspace.Chart_Settings
           (W, Session_Input_Tokens_I).Estimation_Method = Classical,
         "Estimation_Method should default to Classical "
         & "for v5 workspace (missing field)");
   end Test_V5_Loads_Classical_Default;

   --  Anscombe transform config round-trips through workspace save/load.
   procedure Test_Anscombe_Transform_Round_Trip (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Charts;
      Path  : constant String :=
        Ada.Directories.Current_Directory
        & "/fixtures/sqc/tmp_anscombe_roundtrip.sqcw";
      W_Out : Workspace_Record;
      W_In  : Workspace_Record;
      Cfg   : Chart_Settings_Record;
      VF    : Natural;
      Migrated : Boolean;
   begin
      W_Out.Workspace_Id := To_Unbounded_String ("anscombe-ws-001");
      W_Out.Name         := To_Unbounded_String ("Anscombe Test");

      Cfg.Transform := (Kind => Anscombe, others => <>);
      W_Out.Chart_Settings.Include (Session_Input_Tokens_I, Cfg);

      Coyote_SQC.Workspace.Save (Path, W_Out);
      Coyote_SQC.Workspace.Load (Path, W_In, VF, Migrated);
      Ada.Directories.Delete_File (Path);

      Assert (VF = 10, "Version should be 10; got " & Natural'Image (VF));
      Assert
        (not Migrated,
         "No migration expected for a v8 workspace");
      declare
         I_Cfg : constant Chart_Settings_Record :=
           Coyote_SQC.Workspace.Chart_Settings (W_In, Session_Input_Tokens_I);
      begin
         Assert
           (I_Cfg.Transform.Kind = Anscombe,
            "Session_Input_Tokens_I Transform.Kind should be Anscombe; got "
            & Coyote_SQC.Data_Model.Transform_Kind'Image
                (I_Cfg.Transform.Kind));
      end;
   end Test_Anscombe_Transform_Round_Trip;

   --  Log_Y_Mode boolean field round-trips through workspace save/load.
   procedure Test_Log_Y_Mode_Round_Trip (T : in out Test) is
      pragma Unreferenced (T);
      Path  : constant String :=
        Ada.Directories.Current_Directory
        & "/fixtures/sqc/tmp_log_y_roundtrip.sqcw";
      W_Out : Workspace_Record;
      W_In  : Workspace_Record;
      VF    : Natural;
      Migrated : Boolean;
   begin
      W_Out.Workspace_Id := To_Unbounded_String ("log-y-ws-001");
      W_Out.Name         := To_Unbounded_String ("Log Y Test");
      W_Out.Log_Y_Mode   := True;

      Coyote_SQC.Workspace.Save (Path, W_Out);
      Coyote_SQC.Workspace.Load (Path, W_In, VF, Migrated);
      Ada.Directories.Delete_File (Path);

      Assert (VF = 10, "Version should be 10; got " & Natural'Image (VF));
      Assert (not Migrated, "No migration expected for a v9 workspace");
      Assert (W_In.Log_Y_Mode,
              "Log_Y_Mode should be True after round-trip");

      --  Also verify False round-trips (the default).
      declare
         W_Out2 : Workspace_Record;
         W_In2  : Workspace_Record;
         VF2    : Natural;
         Mig2   : Boolean;
      begin
         W_Out2.Workspace_Id := To_Unbounded_String ("log-y-ws-002");
         W_Out2.Name         := To_Unbounded_String ("Log Y False Test");
         W_Out2.Log_Y_Mode   := False;

         Coyote_SQC.Workspace.Save (Path, W_Out2);
         Coyote_SQC.Workspace.Load (Path, W_In2, VF2, Mig2);
         Ada.Directories.Delete_File (Path);

         Assert (not W_In2.Log_Y_Mode,
                 "Log_Y_Mode should be False after round-trip (default)");
      end;
   end Test_Log_Y_Mode_Round_Trip;

   --  Analyze_All_Directories boolean field round-trips through save/load.
   procedure Test_Analyze_All_Directories_Round_Trip (T : in out Test) is
      pragma Unreferenced (T);
      Path  : constant String :=
        Ada.Directories.Current_Directory
        & "/fixtures/sqc/tmp_analyze_all_roundtrip.sqcw";
      W_Out : Workspace_Record;
      W_In  : Workspace_Record;
      VF    : Natural;
      Migrated : Boolean;
   begin
      --  True case.
      W_Out.Workspace_Id              := To_Unbounded_String ("aad-ws-001");
      W_Out.Name                      := To_Unbounded_String ("All Dirs Test");
      W_Out.Analyze_All_Directories   := True;

      Coyote_SQC.Workspace.Save (Path, W_Out);
      Coyote_SQC.Workspace.Load (Path, W_In, VF, Migrated);
      Ada.Directories.Delete_File (Path);

      Assert (VF = 10, "Version should be 10; got " & Natural'Image (VF));
      Assert (not Migrated, "No migration expected");
      Assert (W_In.Analyze_All_Directories,
              "Analyze_All_Directories should be True after round-trip");

      --  False case (the default).
      declare
         W_Out2 : Workspace_Record;
         W_In2  : Workspace_Record;
         VF2    : Natural;
         Mig2   : Boolean;
      begin
         W_Out2.Workspace_Id              :=
           To_Unbounded_String ("aad-ws-002");
         W_Out2.Name                      :=
           To_Unbounded_String ("All Dirs False Test");
         W_Out2.Analyze_All_Directories   := False;

         Coyote_SQC.Workspace.Save (Path, W_Out2);
         Coyote_SQC.Workspace.Load (Path, W_In2, VF2, Mig2);
         Ada.Directories.Delete_File (Path);

         Assert (not W_In2.Analyze_All_Directories,
                 "Analyze_All_Directories should be False after round-trip");
      end;
   end Test_Analyze_All_Directories_Round_Trip;

   procedure Test_Quantile_Bonferroni_Round_Trip (T : in out Test) is
      pragma Unreferenced (T);
      Path   : constant String :=
        Ada.Directories.Current_Directory & "/fixtures/sqc/tmp_bonf.sqcw";
      W_Out  : Workspace_Record;
      W_In   : Workspace_Record;
      VF     : Natural;
      Mig    : Boolean;
   begin
      W_Out.Workspace_Id := To_Unbounded_String ("bonf-ws-001");
      W_Out.Name         := To_Unbounded_String ("Bonferroni Round-Trip");
      W_Out.Quantile_Bonferroni := False;
      Coyote_SQC.Workspace.Save (Path, W_Out);
      Coyote_SQC.Workspace.Load (Path, W_In, VF, Mig);
      Ada.Directories.Delete_File (Path);
      Assert (not W_In.Quantile_Bonferroni,
              "Quantile_Bonferroni should be False after round-trip");
      --  Default (True) round-trip.
      declare
         W_Out2 : Workspace_Record;
         W_In2  : Workspace_Record;
         VF2    : Natural;
         Mig2   : Boolean;
      begin
         W_Out2.Workspace_Id := To_Unbounded_String ("bonf-ws-002");
         W_Out2.Name         := To_Unbounded_String ("Bonferroni Default Test");
         --  Leave Quantile_Bonferroni at default (True).
         Coyote_SQC.Workspace.Save (Path, W_Out2);
         Coyote_SQC.Workspace.Load (Path, W_In2, VF2, Mig2);
         Ada.Directories.Delete_File (Path);
         Assert (W_In2.Quantile_Bonferroni,
                 "Quantile_Bonferroni should default to True");
      end;
   end Test_Quantile_Bonferroni_Round_Trip;

   procedure Test_Quantile_Bonferroni_Default (T : in out Test) is
      pragma Unreferenced (T);
      Path : constant String :=
        Ada.Directories.Current_Directory & "/fixtures/sqc/tmp_bonf_default.sqcw";
   begin
      --  Write a minimal workspace file without the quantileBonferroni field.
      declare
         File : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
         Ada.Text_IO.Put_Line (File, "{"
           & """version"": 10,"
           & """workspaceId"": ""bonf-def-001"","
           & """name"": ""No Bonferroni Field""}");
         Ada.Text_IO.Close (File);
      end;
      declare
         W_In   : Workspace_Record;
         VF     : Natural;
         Mig    : Boolean;
      begin
         Coyote_SQC.Workspace.Load (Path, W_In, VF, Mig);
         Ada.Directories.Delete_File (Path);
         Assert (W_In.Quantile_Bonferroni,
                 "Quantile_Bonferroni should default to True"
                 & " when field absent from workspace file");
      end;
   end Test_Quantile_Bonferroni_Default;

   package SQC_Workspace_Caller is
     new AUnit.Test_Caller (Coyote_SQC_Workspace_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("SQC: workspace round-trip serialisation",
         Coyote_SQC_Workspace_Tests.Test_Round_Trip'Access));
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("SQC: workspace version > 2 raises Workspace_Error",
         Coyote_SQC_Workspace_Tests.Test_Version_Too_High'Access));
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("SQC: workspace missing version loads without error",
         Coyote_SQC_Workspace_Tests.Test_Missing_Version'Access));
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("SQC: duplicate setup session IDs are deduplicated on load",
         Coyote_SQC_Workspace_Tests.Test_UUID_Deduplication'Access));
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("SQC: New_UUID returns valid RFC 4122 v4 format",
         Coyote_SQC_Workspace_Tests.Test_New_UUID_Format'Access));
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("SQC: New_UUID returns unique values",
         Coyote_SQC_Workspace_Tests.Test_New_UUID_Unique'Access));
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("Box-Cox config round-trip",
         Coyote_SQC_Workspace_Tests.Test_Box_Cox_Round_Trip'Access));
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("Robust_Auto lambda source round-trip",
         Coyote_SQC_Workspace_Tests.Test_Robust_Auto_Round_Trip'Access));
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("v1 workspace loads with Box-Cox disabled",
         Coyote_SQC_Workspace_Tests.Test_V1_Loads_Box_Cox_Disabled'Access));
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("EWMA: weight and L round-trip through workspace",
         Coyote_SQC_Workspace_Tests.Test_EWMA_Round_Trip'Access));
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("EWMA: v3 workspace loads default weight=0.2, L=3.0",
         Coyote_SQC_Workspace_Tests.Test_V3_Loads_EWMA_Defaults'Access));
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("Turn Count Box-Cox: config round-trips through workspace",
         Coyote_SQC_Workspace_Tests.Test_Turn_Count_Box_Cox_Round_Trip'Access));
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("Turn Count Box-Cox: v4 workspace loads default (disabled)",
         Coyote_SQC_Workspace_Tests.Test_V4_Loads_Turn_Count_Defaults'Access));
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("Robust estimation: Robust_Median survives workspace round-trip",
         Coyote_SQC_Workspace_Tests.Test_Estimation_Method_Round_Trip'Access));
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("Robust estimation: v5 workspace loads Classical default",
         Coyote_SQC_Workspace_Tests.Test_V5_Loads_Classical_Default'Access));
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("SQC workspace: Anscombe transform round-trips through save/load",
         Coyote_SQC_Workspace_Tests
           .Test_Anscombe_Transform_Round_Trip'Access));
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("SQC workspace: logYMode round-trips through workspace save/load",
         Coyote_SQC_Workspace_Tests
           .Test_Log_Y_Mode_Round_Trip'Access));
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("SQC workspace: Analyze_All_Directories round-trips through save/load",
         Coyote_SQC_Workspace_Tests
           .Test_Analyze_All_Directories_Round_Trip'Access));
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("Quantile_Bonferroni round-trip",
         Coyote_SQC_Workspace_Tests
           .Test_Quantile_Bonferroni_Round_Trip'Access));
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("Quantile_Bonferroni defaults to True when absent",
         Coyote_SQC_Workspace_Tests
           .Test_Quantile_Bonferroni_Default'Access));

      return Result;
   end Suite;

end Coyote_SQC_Workspace_Tests;
