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
with Coyote_SQC.Statistics.I_Chart;
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
            if Metrics.N_Tool_Call_Turns_For_Chart = 0 then
               Excluded    := True;
               Hollow_Gray := True;
            else
               N      := Metrics.N_Tool_Call_Turns_For_Chart;
               Value  := Mean_LF (Metrics.Per_Turn_Tool_Tokens);
               Single := (N = 1);
            end if;

         when Tool_Call_Tokens_S =>
            if Metrics.N_Tool_Call_Turns_For_Chart = 0 then
               Excluded    := True;
               Hollow_Gray := True;
            elsif Metrics.N_Tool_Call_Turns_For_Chart <= 1 then
               Excluded := True;
            else
               N     := Metrics.N_Tool_Call_Turns_For_Chart;
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
         when Session_Input_Tokens_I =>
            Value := Long_Float (Metrics.Total_Input_Tokens);
            N     := 1;

         when Session_Output_Tokens_I =>
            Value := Long_Float (Metrics.Total_Output_Tokens);
            N     := 1;

         when Session_Cache_Read_Tokens_I =>
            Value := Long_Float (Metrics.Total_Cache_Read_Tokens);
            N     := 1;

         when Session_Cache_Write_Tokens_I =>
            Value := Long_Float (Metrics.Total_Cache_Write_Tokens);
            N     := 1;

         when Session_Input_Tokens_MR | Session_Output_Tokens_MR
            | Session_Cache_Read_Tokens_MR | Session_Cache_Write_Tokens_MR =>
            --  Moving range requires the previous session value; the caller
            --  (Recompute_Chart) overrides Excluded and Value after this
            --  call for non-first sessions.
            Excluded := True;
      end case;
   end Compute_Session_Stat;

   --  ── Recompute_Chart ──────────────────────────────────────────────────

   procedure Recompute_Chart (Kind : Chart_Kind) is
      Props   : constant Coyote_SQC.Charts.Chart_Properties :=
        Coyote_SQC.Charts.Properties (Kind);

      CD : Chart_Data;
      --  State for moving-range (MR) chart kinds.
      Prev_Total     : Long_Float := 0.0;
      Has_Prev_Total : Boolean    := False;
      --  Box-Cox transformed tracking for MR chart kinds.
      BC_Prev_Z     : Long_Float := 0.0;
      Has_BC_Prev_Z : Boolean    := False;
   begin
      --  Estimate setup parameters.
      CD.Is_Retro := State.Workspace.Setup_Session_Ids.Is_Empty;
      Statistics.Estimate_Parameters
        (Metrics   => State.All_Metrics,
         Setup_Ids => State.Workspace.Setup_Session_Ids,
         Kind      => Kind,
         Parameters => CD.Params);

      --  Box-Cox: when enabled for I/MR chart kinds, override the
      --  Grand_Mean and Mean_MR in CD.Params with transformed-space values.
      if Props.Is_I_Chart
        and then State.Workspace.I_Chart_Box_Cox.Enabled
      then
         declare
            --  Collect setup-interval raw values in chronological order.
            Raw   : Statistics.I_Chart.Long_Float_Array
                      (1 .. Natural (State.All_Metrics.Length));
            N_Raw  : Natural := 0;
            N_Zero : Natural := 0;
            Lambda : Long_Float;
         begin
            for M of State.All_Metrics loop
               if State.Workspace.Setup_Session_Ids.Is_Empty
                 or else State.Workspace.Setup_Session_Ids.Contains
                           (M.Session_Id)
               then
                  declare
                     Val : constant Long_Float :=
                       (case Kind is
                           when Session_Input_Tokens_I
                              | Session_Input_Tokens_MR      =>
                              Long_Float (M.Total_Input_Tokens),
                           when Session_Cache_Read_Tokens_I
                              | Session_Cache_Read_Tokens_MR =>
                              Long_Float (M.Total_Cache_Read_Tokens),
                           when Session_Cache_Write_Tokens_I
                              | Session_Cache_Write_Tokens_MR =>
                              Long_Float (M.Total_Cache_Write_Tokens),
                           when others                        =>
                              Long_Float (M.Total_Output_Tokens));
                  begin
                     if Val > 0.0 then
                        N_Raw := N_Raw + 1;
                        Raw (N_Raw) := Val;
                     else
                        N_Zero := N_Zero + 1;
                     end if;
                  end;
               end if;
            end loop;

            if N_Zero > 0 then
               State.Status_Bar.Set_Text
                 (Natural'Image (N_Zero)
                  & " session(s) with zero tokens excluded from"
                  & " I/MR chart (Box-Cox requires x > 0).");
            end if;

            --  Resolve lambda.
            if State.Workspace.I_Chart_Box_Cox.Lambda_Source =
                  Data_Model.Fixed
            then
               Lambda := State.Workspace.I_Chart_Box_Cox.Fixed_Lambda;
            else
               Lambda :=
                 (if N_Raw >= 3
                  then Statistics.I_Chart.Estimate_Lambda (Raw (1 .. N_Raw))
                  else 0.0);
            end if;
            CD.Box_Cox_Lambda := Lambda;
            CD.Box_Cox_Active := True;

            --  Recompute Grand_Mean and Mean_MR in the transformed space.
            if N_Raw > 0 then
               declare
                  Sum_Z    : Long_Float := 0.0;
                  Prev_Z   : Long_Float := 0.0;
                  Has_PZ   : Boolean    := False;
                  MR_Z_Sum : Long_Float := 0.0;
                  MR_Z_Cnt : Natural    := 0;
               begin
                  for Idx in 1 .. N_Raw loop
                     declare
                        Z : constant Long_Float :=
                          Statistics.I_Chart.Box_Cox (Raw (Idx), Lambda);
                     begin
                        Sum_Z := Sum_Z + Z;
                        if Has_PZ then
                           MR_Z_Sum := MR_Z_Sum + abs (Z - Prev_Z);
                           MR_Z_Cnt := MR_Z_Cnt + 1;
                        end if;
                        Prev_Z := Z;
                        Has_PZ := True;
                     end;
                  end loop;
                  CD.Params.Grand_Mean := Sum_Z / Long_Float (N_Raw);
                  CD.Params.Mean_MR    :=
                    (if MR_Z_Cnt > 0
                     then MR_Z_Sum / Long_Float (MR_Z_Cnt)
                     else 0.0);
               end;
            end if;
         end;
      end if;


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
            --  MR chart override: compute moving range from previous session.
            if Kind in Session_Input_Tokens_MR
                      | Session_Output_Tokens_MR
                      | Session_Cache_Read_Tokens_MR
                      | Session_Cache_Write_Tokens_MR
            then
               declare
                  Cur : constant Long_Float :=
                    (case Kind is
                        when Session_Input_Tokens_MR        =>
                           Long_Float (M.Total_Input_Tokens),
                        when Session_Cache_Read_Tokens_MR   =>
                           Long_Float (M.Total_Cache_Read_Tokens),
                        when Session_Cache_Write_Tokens_MR  =>
                           Long_Float (M.Total_Cache_Write_Tokens),
                        when others                         =>
                           Long_Float (M.Total_Output_Tokens));
               begin
                  if CD.Box_Cox_Active and then Cur > 0.0 then
                     --  Box-Cox MR: differences of transformed values.
                     declare
                        Z_Cur : constant Long_Float :=
                          Statistics.I_Chart.Box_Cox (Cur, CD.Box_Cox_Lambda);
                     begin
                        if Has_BC_Prev_Z then
                           Value := abs (Z_Cur - BC_Prev_Z);
                           Excl  := False;
                        end if;
                        BC_Prev_Z     := Z_Cur;
                        Has_BC_Prev_Z := True;
                     end;
                  elsif not CD.Box_Cox_Active then
                     if Has_Prev_Total then
                        Value := abs (Cur - Prev_Total);
                        Excl  := False;
                     end if;
                  end if;
                  Prev_Total     := Cur;
                  Has_Prev_Total := True;
               end;
            end if;

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
                  when Session_Input_Tokens_I
                     | Session_Output_Tokens_I
                     | Session_Cache_Read_Tokens_I
                     | Session_Cache_Write_Tokens_I =>
                     declare
                        L_Z : constant Statistics.Limits_Record :=
                          Statistics.I_Chart.Compute_I_Limits
                            (Grand_Mean => CD.Params.Grand_Mean,
                             Mean_MR    => CD.Params.Mean_MR);
                     begin
                        if CD.Box_Cox_Active and then L_Z.Has_UCL then
                           --  Back-transform limits to original units.
                           --  CL_z and LCL_z are always within the valid
                           --  domain of Box_Cox_Inverse: all observed data
                           --  values mapped into (-inf, 1/|lambda|), so
                           --  Grand_Mean_z and any value below it are valid
                           --  inputs.  UCL_z may reach or exceed the
                           --  asymptote 1/|lambda| for negative lambda,
                           --  meaning no finite x maps to that z; the
                           --  original-space UCL is effectively +inf.
                           --  Each limit is back-transformed independently
                           --  so that a domain failure on UCL_z does not
                           --  suppress the CL and LCL.
                           declare
                              Inv_UCL     : Long_Float := 0.0;
                              Has_Inv_UCL : Boolean    := False;
                              Inv_CL      : Long_Float;
                              Inv_LCL     : Long_Float;
                           begin
                              begin
                                 Inv_UCL     :=
                                   Statistics.I_Chart.Box_Cox_Inverse
                                     (L_Z.UCL, CD.Box_Cox_Lambda);
                                 Has_Inv_UCL := True;
                              exception
                                 when Constraint_Error => null;
                              end;
                              Inv_CL  := Statistics.I_Chart.Box_Cox_Inverse
                                           (L_Z.CL, CD.Box_Cox_Lambda);
                              Inv_LCL :=
                                (if L_Z.Has_LCL
                                 then Statistics.I_Chart.Box_Cox_Inverse
                                        (L_Z.LCL, CD.Box_Cox_Lambda)
                                 else 0.0);
                              Limits :=
                                (UCL     => Inv_UCL,
                                 CL      => Inv_CL,
                                 LCL     => Inv_LCL,
                                 Has_UCL => Has_Inv_UCL,
                                 Has_LCL => L_Z.Has_LCL);
                           end;
                        else
                           Limits := L_Z;
                        end if;
                     end;
                  when Session_Input_Tokens_MR
                     | Session_Output_Tokens_MR
                     | Session_Cache_Read_Tokens_MR
                     | Session_Cache_Write_Tokens_MR =>
                     Limits := Statistics.I_Chart.Compute_MR_Limits
                       (Mean_MR => CD.Params.Mean_MR);
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
