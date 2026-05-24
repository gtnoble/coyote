--  Coyote_SQC.Data_Model — internal data model types.
--
--  All downstream logic (statistics, charts, UI) operates on these types,
--  not on raw session files.  Only Coyote_SQC.Session_Parser may reference
--  the raw JSONL field names.
--
--  Project: coyote

with Ada.Calendar;
with Ada.Containers.Hashed_Sets;
with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Ada.Strings.Unbounded.Hash;

package Coyote_SQC.Data_Model is
   use type Ada.Strings.Unbounded.Unbounded_String;


   --  ── Tool call ──────────────────────────────────────────────────────────

   type Tool_Call_Record is record
      Tool_Name     : Ada.Strings.Unbounded.Unbounded_String;
      Input_Tokens  : Natural := 0;
      Output_Tokens : Natural := 0;
      Failed        : Boolean := False;
   end record;

   package Tool_Call_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Tool_Call_Record);

   --  ── Turn ───────────────────────────────────────────────────────────────

   type Turn_Record is record
      Turn_Index       : Positive := 1;
      Input_Tokens     : Natural  := 0;
      Output_Tokens    : Natural  := 0;
      Thinking_Tokens  : Natural  := 0;
      Thinking_Enabled : Boolean  := False;
      Tool_Calls       : Tool_Call_Vectors.Vector;
   end record;

   package Turn_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Turn_Record);

   --  ── Session ────────────────────────────────────────────────────────────

   type Session_Record is record
      Session_Id          : Ada.Strings.Unbounded.Unbounded_String;
      Start_Time          : Ada.Calendar.Time;
      Source_Directory    : Ada.Strings.Unbounded.Unbounded_String;
      Model               : Ada.Strings.Unbounded.Unbounded_String;
      First_User_Message  : Ada.Strings.Unbounded.Unbounded_String;
      Total_Input_Tokens  : Natural := 0;
      Total_Output_Tokens : Natural := 0;
      Total_Cache_Read_Tokens  : Natural := 0;
      Total_Cache_Write_Tokens : Natural := 0;
      Turns               : Turn_Vectors.Vector;
   end record;

   package Session_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Session_Record);

   --  ── Metrics ────────────────────────────────────────────────────────────

   package Natural_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Natural);

   type Session_Metrics_Record is record
      Session_Id                 : Ada.Strings.Unbounded.Unbounded_String;
      N_Turns                    : Positive := 1;
      N_Tool_Call_Turns          : Natural  := 0;
      N_Tool_Call_Turns_For_Chart : Natural  := 0;
      N_Thinking_Turns           : Natural  := 0;
      N_Tool_Calls               : Natural  := 0;
      N_Failed_Tool_Calls        : Natural  := 0;
      Any_Thinking               : Boolean  := False;
      Per_Turn_Input_Tokens      : Natural_Vectors.Vector;
      Per_Turn_Output_Tokens     : Natural_Vectors.Vector;
      Per_Turn_Tool_Tokens       : Natural_Vectors.Vector;
      Per_Turn_Thinking_Tokens   : Natural_Vectors.Vector;
      N_Thinking_Turns_For_Chart : Natural  := 0;
      Total_Input_Tokens         : Natural  := 0;
      Total_Output_Tokens        : Natural  := 0;
      Total_Cache_Read_Tokens  : Natural  := 0;
      Total_Cache_Write_Tokens : Natural  := 0;
   end record;

   package Metrics_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Session_Metrics_Record);

   --  ── Comment ────────────────────────────────────────────────────────────

   type Comment_Record is record
      Comment_Id : Ada.Strings.Unbounded.Unbounded_String;
      Session_Id : Ada.Strings.Unbounded.Unbounded_String;
      Timestamp  : Ada.Calendar.Time;
      Text       : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   package Comment_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Comment_Record);

   --  ── UUID sets ──────────────────────────────────────────────────────────

   package UUID_Sets is new Ada.Containers.Hashed_Sets
     (Element_Type        => Ada.Strings.Unbounded.Unbounded_String,
      Hash                => Ada.Strings.Unbounded.Hash,
      Equivalent_Elements => Ada.Strings.Unbounded."=");

   subtype UUID_Set is UUID_Sets.Set;

   --  ── Box-Cox configuration ──────────────────────────────────────────────

   --  Identifies how the Box-Cox lambda parameter is determined.
   type Box_Cox_Lambda_Source is (Auto, Fixed);

   --  Box-Cox transformation configuration for Session Token I/MR charts.
   --  One shared config applies to all four I/MR charts in the workspace.
   --  The estimated lambda (when Lambda_Source = Auto) is a transient runtime
   --  value stored in Chart_Data; it is not persisted.
   type Box_Cox_Config is record
      Enabled       : Boolean                := False;
      Lambda_Source : Box_Cox_Lambda_Source  := Auto;
      Fixed_Lambda  : Long_Float             := 0.0;
      --  Lambda_Source = Auto: estimate lambda at runtime from the
      --  setup interval by MLE; the estimate is not persisted.
      --  Lambda_Source = Fixed: use Fixed_Lambda directly.
      --  Common fixed values: 0.0 (ln), 0.5 (sqrt), 1.0 (identity).
   end record;

   --  ── Workspace ──────────────────────────────────────────────────────────

   package String_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Ada.Strings.Unbounded.Unbounded_String,
      "="          => Ada.Strings.Unbounded."=");

   type Workspace_Record is record
      Workspace_Id       : Ada.Strings.Unbounded.Unbounded_String;
      Name               : Ada.Strings.Unbounded.Unbounded_String;
      Source_Directories : String_Vectors.Vector;
      Model_Filter       : String_Vectors.Vector;
      Setup_Session_Ids  : UUID_Set;
      Comments           : Comment_Vectors.Vector;
      --  Box-Cox transformation config for Session Token I/MR charts.
      --  Shared across all four I/MR chart kinds.
      --  Box-Cox transformation config for Session Token I/MR charts.
      --  One shared config applies to all eight I/MR chart kinds.
      I_Chart_Box_Cox    : Box_Cox_Config;
      --  Box-Cox transformation config for per-turn Xbar/S charts
      --  (Turn, Tool Call, and Thinking token charts).  When Lambda_Source
      --  is Auto, each chart pair (Turn/Tool/Thinking) estimates its own
      --  lambda independently from setup-interval per-turn values.
      Xbar_S_Box_Cox     : Box_Cox_Config;
      --  EWMA chart smoothing parameter and sigma multiplier.
      --  EWMA_Weight (lambda): controls how much weight is given to the most
      --  recent observation vs the running average.  Smaller values detect
      --  smaller sustained shifts; larger values make the chart more like
      --  the raw I chart.  Typical value: 0.2.  Range: (0.0, 1.0].
      --  EWMA_L: sigma multiplier for the control limits (typically 3.0).
      EWMA_Weight        : Long_Float := 0.2;
      EWMA_L             : Long_Float := 3.0;
   end record;

end Coyote_SQC.Data_Model;
