--  Coyote_SQC.App body.
--
--  Project: coyote

with Ada.Exceptions;
with Ada.Calendar;
with Ada.Numerics.Long_Elementary_Functions;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Coyote_SQC.Metrics;
with Coyote_SQC.Session_Parser;
with Coyote_SQC.Statistics.C4;
with Coyote_SQC.Statistics.P_Chart;
with Coyote_SQC.Statistics.S_Chart;
with Coyote_SQC.Statistics.Xbar;
with Gtk.Main;
with Gtk.Widget;

--  Forward declaration — UI builder lives in Coyote_SQC.UI.
with Coyote_SQC.Config;
with Coyote_SQC.Statistics;
with Coyote_SQC.Workspace;
with Coyote_SQC.UI;
with Coyote_SQC.UI.Dialogs;
with Coyote_SQC.UI.Toolbar;
with Coyote_SQC.UI.Chart_Canvas;

package body Coyote_SQC.App is
   use type Ada.Calendar.Time;
   use type Gtk.Window.Gtk_Window;

   use Ada.Numerics.Long_Elementary_Functions;
   use Coyote_SQC.Charts;
   use Coyote_SQC.Data_Model;

   --  ── Helper: sample mean of a Natural vector ───────────────────────────

   function Mean_LF (V : Natural_Vectors.Vector) return Long_Float is
      N : constant Natural := Natural (V.Length);
   begin
      if N = 0 then return 0.0; end if;
      declare
         S : Long_Float := 0.0;
      begin
         for X of V loop
            S := S + Long_Float (X);
         end loop;
         return S / Long_Float (N);
      end;
   end Mean_LF;

   function StdDev_LF (V : Natural_Vectors.Vector) return Long_Float is
      N : constant Natural := Natural (V.Length);
   begin
      if N < 2 then return 0.0; end if;
      declare
         M    : constant Long_Float := Mean_LF (V);
         Sum2 : Long_Float := 0.0;
      begin
         for X of V loop
            declare D : constant Long_Float := Long_Float (X) - M;
            begin Sum2 := Sum2 + D * D; end;
         end loop;
         return Sqrt (Sum2 / Long_Float (N - 1));
      end;
   end StdDev_LF;

   --  ── Compute_Session_Stat ─────────────────────────────────────────────

   procedure Compute_Session_Stat
     (Metrics    :     Session_Metrics_Record;
      Kind       :     Chart_Kind;
      Value      : out Long_Float;
      N          : out Positive;
      Excluded   : out Boolean;
      Single     : out Boolean;
      Hollow_Gray: out Boolean)
   is
   begin
      Value       := 0.0;
      N           := 1;
      Excluded    := False;
      Single      := False;
      Hollow_Gray := False;
      case Kind is
         when Turn_Tokens_Xbar =>
            N := Metrics.N_Turns;
            Value  := Mean_LF (Metrics.Per_Turn_Output_Tokens);
            Single := (N = 1);

         when Turn_Tokens_S =>
            N := Metrics.N_Turns;
            if N = 1 then
               Excluded := True;
            else
               Value := StdDev_LF (Metrics.Per_Turn_Output_Tokens);
            end if;

         when Tool_Call_Tokens_Xbar =>
            N := Metrics.N_Turns;
            Value  := Mean_LF (Metrics.Per_Turn_Tool_Tokens);
            Single := (N = 1);

         when Tool_Call_Tokens_S =>
            N := Metrics.N_Turns;
            if N = 1 then
               Excluded := True;
            else
               Value := StdDev_LF (Metrics.Per_Turn_Tool_Tokens);
            end if;

         when Thinking_Tokens_Xbar =>
            if not Metrics.Any_Thinking then
               Excluded    := True;
               Hollow_Gray := True;
            else
               N      := Metrics.N_Thinking_Turns_For_Chart;
               Value  := Mean_LF (Metrics.Per_Turn_Thinking_Tokens);
               Single := (N = 1);
            end if;

         when Thinking_Tokens_S =>
            if not Metrics.Any_Thinking then
               Excluded    := True;
               Hollow_Gray := True;
            elsif Metrics.N_Thinking_Turns_For_Chart <= 1 then
               Excluded := True;
            else
               N     := Metrics.N_Thinking_Turns_For_Chart;
               Value := StdDev_LF (Metrics.Per_Turn_Thinking_Tokens);
            end if;

         when Tool_Call_Failure_Rate =>
            if Metrics.N_Tool_Calls = 0 then
               Excluded := True;
            else
               N     := Metrics.N_Tool_Calls;
               Value := Long_Float (Metrics.N_Failed_Tool_Calls)
                        / Long_Float (Metrics.N_Tool_Calls);
            end if;

         when Fraction_Tool_Call_Turns =>
            N     := Metrics.N_Turns;
            Value := Long_Float (Metrics.N_Tool_Call_Turns)
                     / Long_Float (N);

         when Fraction_Thinking_Turns =>
            N     := Metrics.N_Turns;
            Value := Long_Float (Metrics.N_Thinking_Turns)
                     / Long_Float (N);
      end case;
   end Compute_Session_Stat;

   --  ── Recompute_Chart ──────────────────────────────────────────────────

   procedure Recompute_Chart (Kind : Chart_Kind) is
      Props   : constant Coyote_SQC.Charts.Chart_Properties :=
        Coyote_SQC.Charts.Properties (Kind);
      pragma Unreferenced (Props);

      CD : Chart_Data;
   begin
      --  Estimate setup parameters.
      CD.Is_Retro := State.Workspace.Setup_Session_Ids.Is_Empty;
      Statistics.Estimate_Parameters
        (Metrics   => State.All_Metrics,
         Setup_Ids => State.Workspace.Setup_Session_Ids,
         Kind      => Kind,
         Parameters => CD.Params);

      --  Compute one point per session.
      for I in 1 .. Natural (State.Sessions.Length) loop
         declare
            Sess  : constant Session_Record :=
              State.Sessions.Element (I);
            M     : constant Session_Metrics_Record :=
              State.All_Metrics.Element (I);
            Value    : Long_Float;
            N        : Positive;
            Excl     : Boolean;
            Single   : Boolean;
            HGray    : Boolean;
            Limits   : Statistics.Limits_Record;
            In_Setup : constant Boolean :=
              State.Workspace.Setup_Session_Ids.Contains (Sess.Session_Id);
         begin
            Compute_Session_Stat (M, Kind, Value, N, Excl, Single, HGray);

            if Excl then
               Limits := (UCL => 0.0, CL => 0.0, LCL => 0.0,
                          Has_UCL => False,
                          Has_LCL => False);
            else
               case Kind is
                  when Turn_Tokens_Xbar
                     | Tool_Call_Tokens_Xbar
                     | Thinking_Tokens_Xbar =>
                     Limits := Statistics.Xbar.Compute_Limits
                       (Grand_Mean => CD.Params.Grand_Mean,
                        Pooled_S   => CD.Params.Pooled_S,
                        N          => N);
                  when Turn_Tokens_S
                     | Tool_Call_Tokens_S
                     | Thinking_Tokens_S =>
                     Limits := Statistics.S_Chart.Compute_Limits
                       (Pooled_S => CD.Params.Pooled_S,
                        N        => N);
                  when Tool_Call_Failure_Rate
                     | Fraction_Tool_Call_Turns
                     | Fraction_Thinking_Turns =>
                     Limits := Statistics.P_Chart.Compute_Limits
                       (Grand_P => CD.Params.Grand_P,
                        N       => N);
               end case;
            end if;

            CD.Points.Append
              ((Session_Id    => Sess.Session_Id,
                Session_Index => I,
                Session_Time  => Sess.Start_Time,
                Stat_Value    => Value,
                UCL           => Limits.UCL,
                CL            => (if Single then Value else Limits.CL),
                LCL           => Limits.LCL,
                Has_UCL       => Limits.Has_UCL,
                Has_LCL       => Limits.Has_LCL,
                Excluded      => Excl,
                Single_Turn   => Single,
                In_Setup      => In_Setup,
                Hollow_Gray   => HGray,
                Has_Comment   => Has_Comment
                                   (To_String (Sess.Session_Id))));
         end;
      end loop;

      State.Charts (Kind) := CD;
   end Recompute_Chart;

   procedure Recompute_Charts is
   begin
      for K in Chart_Kind loop
         Recompute_Chart (K);
      end loop;
      Update_Menu_States;
   end Recompute_Charts;

   --  ── Reload_Sessions ──────────────────────────────────────────────────

   procedure Reload_Sessions is
      Epoch : constant Ada.Calendar.Time :=
        Ada.Calendar.Time_Of (1970, 1, 1, 0.0);
   begin
      State.Sessions.Clear;
      State.All_Metrics.Clear;

      Coyote_SQC.Session_Parser.Load_Sessions
        (Source_Directories => State.Workspace.Source_Directories,
         Model_Filter       => State.Workspace.Model_Filter,
         Sessions           => State.Sessions);

      --  Compute metrics for each loaded session.
      for Sess of State.Sessions loop
         State.All_Metrics.Append
           (Coyote_SQC.Metrics.Compute (Sess));
      end loop;

      --  Set initial date range.
      if not State.Sessions.Is_Empty then
         State.Date_From := State.Sessions.First_Element.Start_Time;
         State.Date_To   := State.Sessions.Last_Element.Start_Time;
      else
         State.Date_From := Epoch;
         State.Date_To   := Epoch;
      end if;

      Recompute_Charts;
      Coyote_SQC.UI.Chart_Canvas.Reset_View;
      Coyote_SQC.UI.Toolbar.Sync_Pickers;
   end Reload_Sessions;

   --  ── Y_Fit ────────────────────────────────────────────────────────────

   procedure Y_Fit is
      use Ada.Calendar;
      CS  : Canvas_State renames State.Canvas_St;
      CD  : Chart_Data renames State.Charts (State.Active_Chart);
      Y1  : Long_Float :=  Long_Float'Last;
      Y2  : Long_Float := -Long_Float'Last;
      Any : Boolean := False;
   begin
      for P of CD.Points loop
         if (not P.Excluded or else P.Hollow_Gray)
           and then P.Session_Time >= State.Date_From
           and then P.Session_Time <= State.Date_To
         then
            if P.Stat_Value < Y1 then Y1 := P.Stat_Value; end if;
            if P.Stat_Value > Y2 then Y2 := P.Stat_Value; end if;
            if not P.Excluded and then not P.Single_Turn then
               if P.Has_UCL then
                  if P.UCL > Y2 then Y2 := P.UCL; end if;
                  if P.LCL < Y1 then Y1 := P.LCL; end if;
               end if;
            end if;
            Any := True;
         end if;
      end loop;

      if not Any then return; end if;

      declare
         Margin : constant Long_Float := (Y2 - Y1) * 0.1;
         M      : constant Long_Float :=
           (if Margin > 0.0 then Margin else 1.0);
      begin
         CS.Y_Min := Y1 - M;
         CS.Y_Max := Y2 + M;
      end;
   end Y_Fit;

   --  ── Update_Title ─────────────────────────────────────────────────────

   procedure Update_Menu_States is
      use type Gtk.Menu_Item.Gtk_Menu_Item;
   begin
      if State = null then return; end if;
      if State.Clear_Setup_Item /= null then
         State.Clear_Setup_Item.Set_Sensitive
           (not State.Workspace.Setup_Session_Ids.Is_Empty);
      end if;
   end Update_Menu_States;

   procedure Update_Title is
      Name : constant String := To_String (State.Workspace.Name);
      Title : constant String :=
        "coyote_sqc"
        & (if Name'Length > 0 then " - " & Name else "")
        & (if State.Modified then " *" else "");
   begin
      if State.Main_Window /= null then
         State.Main_Window.Set_Title (Title);
      end if;
   end Update_Title;

   --  ── Has_Comment ──────────────────────────────────────────────────────

   function Has_Comment (Session_Id : String) return Boolean is
   begin
      for C of State.Workspace.Comments loop
         if To_String (C.Session_Id) = Session_Id then
            return True;
         end if;
      end loop;
      return False;
   end Has_Comment;

   --  ── Run ──────────────────────────────────────────────────────────────

   procedure Run (Workspace_Path : String := "") is
      Epoch : constant Ada.Calendar.Time :=
        Ada.Calendar.Time_Of (1970, 1, 1, 0.0);
      --  Version found during workspace load (0 = no version field).
      WS_Version_Found : Natural := 1;
      --  Error from workspace load (empty = no error).
      WS_Load_Error : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;
   begin
      --  Allocate application state.
      State := new App_State;
      State.Date_From      := Epoch;
      State.Date_To        := Epoch;

      --  Load workspace if requested.
      if Workspace_Path'Length > 0 then
         begin
            Coyote_SQC.Workspace.Load
              (Workspace_Path, State.Workspace, WS_Version_Found);
            State.Workspace_Path :=
              To_Unbounded_String (Workspace_Path);
            Coyote_SQC.Config.Record_Open
              (To_String (State.Workspace.Name), Workspace_Path);
         exception
            when E : Coyote_SQC.Workspace.Workspace_Error =>
               WS_Load_Error := Ada.Strings.Unbounded.To_Unbounded_String
                 (Ada.Exceptions.Exception_Message (E));
            when others => null;
         end;
      end if;

      --  Initialise GTK.
      Gtk.Main.Init;

      --  Build the main window.
      Coyote_SQC.UI.Build_Main_Window;

      --  §9.3: show error when workspace version is too high.
      if Ada.Strings.Unbounded.Length (WS_Load_Error) > 0 then
         Coyote_SQC.UI.Dialogs.Error
           (State.Main_Window,
            "Workspace Error",
            Ada.Strings.Unbounded.To_String (WS_Load_Error));
      end if;

      --  §9.3: show warning when version field is absent.
      if Workspace_Path'Length > 0 and then WS_Version_Found = 0 then
         Coyote_SQC.UI.Dialogs.Info
           (State.Main_Window,
            "Workspace Warning",
            "Workspace file has no version field; some data may be missing.");
      end if;

      --  Load sessions if workspace has source directories.
      if not State.Workspace.Source_Directories.Is_Empty then
         Reload_Sessions;
      end if;
      Update_Title;

      --  Kick off the GTK event loop.
      Gtk.Main.Main;
   end Run;

end Coyote_SQC.App;
