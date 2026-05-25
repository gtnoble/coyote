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
with Gtk.Check_Menu_Item;
with Gtk.Paned;
with Gtk.Scrolled_Window;
with Gtk.Window;

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
   end record;

   package Chart_Point_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Chart_Point);

   --  Precomputed data for one chart kind.
   type Chart_Data is record
      Points  : Chart_Point_Vectors.Vector;
      Params  : Coyote_SQC.Statistics.Setup_Parameters;
      Is_Retro : Boolean := True;  --  using retrospective limits
      Box_Cox_Active : Boolean    := False;   --  Box-Cox is active for this chart
      Box_Cox_Lambda : Long_Float := 0.0;    --  resolved lambda (valid when Box_Cox_Active)
      --  MR chart independent Box-Cox transformation (λ_MR estimated from
      --  the setup-interval MR series; independent of λ_I).
      MR_BC_Active : Boolean    := False;
      MR_BC_Lambda : Long_Float := 0.0;
      MR_BC_Limits : Coyote_SQC.Statistics.Limits_Record :=
        (UCL => 0.0, CL => 0.0, LCL => 0.0,
         Has_UCL => False, Has_LCL => False);
   end record;

   type Chart_Data_Array is
     array (Coyote_SQC.Charts.Chart_Kind) of Chart_Data;

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
