--  Coyote_SQC.App — application state and GTK main loop entry point.
--
--  Project: coyote

with Ada.Calendar;
with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Coyote_SQC.Charts;
with Coyote_SQC.Data_Model;
with Coyote_SQC.Statistics;
with Glib;
with Gtk.Box;
with Gtk.Drawing_Area;
with Gtk.Label;
with Gtk.Menu_Item;
with Gtk.Toggle_Button;
with Gtk.Check_Menu_Item;
with Gtk.Paned;
with Gtk.Scrolled_Window;
with Gtk.Window;
with Coyote_SQC.Workspace;

package Coyote_SQC.App is

   --  ── Chart point data ─────────────────────────────────────────────────
   --
   --  A precomputed chart point for one session on one chart.

   type Chart_Point is record
      Session_Id    : Ada.Strings.Unbounded.Unbounded_String;
      Session_Index : Positive := 1;  --  index into App_State.Sessions
      Session_Time  : Ada.Calendar.Time;
      Stat_Value    : Long_Float := 0.0;
      UCL           : Long_Float := 0.0;
      CL            : Long_Float := 0.0;
      LCL           : Long_Float := 0.0;
      Excluded      : Boolean := False;  --  session excluded from this chart
      Hollow_Gray   : Boolean := False;  --  shown hollow gray (zero-thinking on thinking chart)
      Single_Turn   : Boolean := False;  --  n=1 on Xbar chart
      In_Setup      : Boolean := False;  --  session is in setup interval
      Has_Comment   : Boolean := False;  --  session has a comment
      Has_UCL       : Boolean := False;  --  UCL line should be drawn
      Has_LCL       : Boolean := False;  --  LCL line should be drawn
      Has_CL        : Boolean := False;  --  CL line should be drawn
   end record;

   package Chart_Point_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Chart_Point);

   --  Precomputed data for one chart kind.
   type Chart_Data is record
      Points  : Chart_Point_Vectors.Vector;
      Params  : Coyote_SQC.Statistics.Setup_Parameters;
      Is_Retro : Boolean := True;  --  using retrospective limits
      Transform_Active : Coyote_SQC.Data_Model.Transform_Kind :=
        Coyote_SQC.Data_Model.None;  --  active transform (None = untransformed)
      Transform_Lambda : Long_Float := 0.0;
      --  resolved Box-Cox lambda (valid when Transform_Active = Box_Cox)
      --  MR chart independent transform (λ_MR estimated independently from
      --  the setup-interval MR series).
      MR_Transform_Active : Coyote_SQC.Data_Model.Transform_Kind :=
        Coyote_SQC.Data_Model.None;
      MR_Transform_Lambda : Long_Float := 0.0;
      MR_Transform_Limits : Coyote_SQC.Statistics.Limits_Record :=
        (UCL => 0.0, CL => 0.0, LCL => 0.0,
         Has_UCL => False, Has_LCL => False);
   end record;

   type Chart_Data_Array is
     array (Coyote_SQC.Charts.Chart_Kind) of Chart_Data;

   --  ── Chart descriptor and accessors (self-contained chart computation)
   --
   --  A Chart_Descriptor fully specifies how to compute one chart kind.
   --  Recompute_Chart looks it up and proceeds without further case dispatch
   --  Recompute_Chart looks up Descriptor (Kind) and then proceeds without
   --  further case dispatch on Kind.


   --  Per-session exclusion rules for parameter estimation and chart display.
   type Exclusion_Kind is
     (No_Exclusion,
      Zero_Observation,
      Zero_Output_Tokens,
      Zero_Tool_Call_Tokens,
      Zero_Input_Tokens,
      Zero_Thinking,
      Zero_Tool_Call_Turns);

   --  Result type for a single session observation.  The Valid discriminant
   --  distinguishes "this session contributes an observation" (Valid = True)
   --  from "this session must be excluded from this chart" (Valid = False,
   --  e.g. zero denominator for a ratio chart).  Using a discriminated type
   --  prevents callers from accidentally using an exclusion signal value
   --  in arithmetic.
   type Observation_Result (Valid : Boolean := False) is record
      case Valid is
         when True  => Value : Long_Float;
         when False => null;
      end case;
   end record;

   --  Extracts a single Long_Float scalar observation from a
   --  Session_Metrics_Record.  Returns (Valid => False) when the session
   --  must be excluded from this chart (e.g. zero denominator for a ratio
   --  chart).
   type Metric_Accessor is access function
     (M : Coyote_SQC.Data_Model.Session_Metrics_Record)
     return Observation_Result;

   --  Extracts the per-turn subgroup vector from a Session_Metrics_Record.
   type Subgroup_Accessor is access function
     (M : Coyote_SQC.Data_Model.Session_Metrics_Record) return
     Coyote_SQC.Data_Model.Natural_Vectors.Vector;

   --  Extracts a Long_Float subgroup vector from a Session_Metrics_Record.
   --  Used for charts whose observations are natively Long_Float (JSD).
   type LF_Subgroup_Accessor is access function
     (M : Coyote_SQC.Data_Model.Session_Metrics_Record) return
     Coyote_SQC.Data_Model.Long_Float_Vectors.Vector;

   --  A self-contained runtime chart descriptor.
   type Chart_Descriptor is record
      Kind           : Coyote_SQC.Charts.Chart_Kind;
      Properties     : Coyote_SQC.Charts.Chart_Properties;
      Get_Observation : Metric_Accessor;
      Get_Subgroup   : Subgroup_Accessor;
      LF_Get_Subgroup : LF_Subgroup_Accessor := null;
      --  When non-null, used in place of Get_Subgroup for charts whose
      --  subgroup values are Long_Float (e.g. JSD similarity charts).
      Exclusion_Rule : Exclusion_Kind;
   end record;

   --  Return the descriptor for Kind.
   function Descriptor (Kind : Coyote_SQC.Charts.Chart_Kind)
     return Chart_Descriptor;

   --  ── Canvas interaction state ──────────────────────────────────────────

   type Screen_Point is record
      X : Long_Float := 0.0;
      Y : Long_Float := 0.0;
   end record;

   --  Margins (pixels) around the plot area.
   Margin_Left   : constant := 60;
   Margin_Right  : constant := 40;
   Margin_Top    : constant := 30;
   Margin_Bottom : constant := 50;

   type Canvas_State is record
      X_Min, X_Max : Long_Float := 0.0;
      Y_Min, Y_Max : Long_Float := 0.0;
      Width, Height : Glib.Gint := 600;
      --  Drag state
      Drag_Active             : Boolean := False;
      Drag_Start              : Screen_Point;
      Drag_X_Min, Drag_X_Max : Long_Float := 0.0;
      Drag_Y_Min, Drag_Y_Max : Long_Float := 0.0;
      --  Rubber-band
      Rubberband_Active       : Boolean := False;
      Rubberband_Start        : Screen_Point;
      Rubberband_End          : Screen_Point;
      --  Hovered point
      Hovered_Session_Id : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   --  ── App state ─────────────────────────────────────────────────────────

   type App_State is limited record
      --  Data
      Workspace    : Coyote_SQC.Data_Model.Workspace_Record;
      Sessions     : Coyote_SQC.Data_Model.Session_Vectors.Vector;
      All_Metrics  : Coyote_SQC.Data_Model.Metrics_Vectors.Vector;
      Charts       : Chart_Data_Array;
      Active_Chart : Coyote_SQC.Charts.Chart_Kind :=
        Coyote_SQC.Charts.Turn_Tokens_Xbar;
      Selection    : Coyote_SQC.Data_Model.UUID_Set;
      Set_B           : Coyote_SQC.Data_Model.UUID_Set;
      --  Set B session UUIDs for two-set comparison (§9.4).
      Edit_Set_B_Mode : Boolean := False;
      --  When True, all selection actions modify Set_B instead of
      --  Selection.  Toggled by the Edit_Set_B_Button toolbar toggle.
      Date_From    : Ada.Calendar.Time;
      Date_To      : Ada.Calendar.Time;
      --  Workspace file tracking
      Workspace_Path  : Ada.Strings.Unbounded.Unbounded_String;
      Modified        : Boolean := False;
      --  Canvas state
      Canvas_St : Canvas_State;
      --  GTK widget handles (set by Build_Main_Window)
      Main_Window      : Gtk.Window.Gtk_Window;
      Canvas           : Gtk.Drawing_Area.Gtk_Drawing_Area;
      Detail_Pane      : Gtk.Paned.Gtk_Paned;
      Detail_Box       : Gtk.Box.Gtk_Box;
      Status_Bar       : Gtk.Label.Gtk_Label;
      Recent_Menu      : Gtk.Menu_Item.Gtk_Menu_Item;
      Clear_Setup_Item : Gtk.Menu_Item.Gtk_Menu_Item;
      Set_Selection_As_Setup_Item : Gtk.Menu_Item.Gtk_Menu_Item;
      Select_Setup_Interval_Item  : Gtk.Menu_Item.Gtk_Menu_Item;
      Run_Sequence_Item : Gtk.Check_Menu_Item.Gtk_Check_Menu_Item;
      Log_Y_Item        : Gtk.Check_Menu_Item.Gtk_Check_Menu_Item;
      Edit_Set_B_Button    : Gtk.Toggle_Button.Gtk_Toggle_Button;
      Clear_Both_Sets_Item : Gtk.Menu_Item.Gtk_Menu_Item;
      Run_Sequence_Mode : Boolean := False;
      Content_Paned    : Gtk.Paned.Gtk_Paned;
      Left_Scroll      : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
   end record;

   type App_State_Access is access App_State;

   --  Package-level singleton, initialised by Run.
   State : App_State_Access := null;

   --  ── Computation ───────────────────────────────────────────────────────

   --  Reload all sessions from the workspace source directories and
   --  recompute all chart data.  Call after loading/changing a workspace.
   procedure Reload_Sessions;

   --  Recompute all chart data from the current sessions.
   procedure Recompute_Charts;

   --  Recompute chart data for a single chart kind.
   procedure Recompute_Chart (Kind : Coyote_SQC.Charts.Chart_Kind);

   --  Return the statistic value for one session on a given chart.
   --  Returns 0.0 and sets Excluded=True if the session does not contribute.
   procedure Compute_Session_Stat
     (Metrics  :     Coyote_SQC.Data_Model.Session_Metrics_Record;
      Kind     :     Coyote_SQC.Charts.Chart_Kind;
      Value    : out Long_Float;
      N        : out Positive;
      Excluded : out Boolean;
      Single      : out Boolean;
      Hollow_Gray : out Boolean);

   --  Fit Y range to all visible points in [X_Min, X_Max].
   procedure Y_Fit;

   --  Update the window title to reflect Modified state.
   procedure Update_Title;
   procedure Update_Menu_States;

   --  Return True if Session_Id has at least one comment in Workspace.
   function Has_Comment (Session_Id : String) return Boolean;

   --  ── Entry point ───────────────────────────────────────────────────────

   procedure Run (Workspace_Path : String := "");

end Coyote_SQC.App;
