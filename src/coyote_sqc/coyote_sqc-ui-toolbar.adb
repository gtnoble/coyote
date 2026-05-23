--  Coyote_SQC.UI.Toolbar body.
--
--  Project: coyote

with Ada.Calendar;
with Coyote_SQC.App;
with Coyote_SQC.UI.Chart_Canvas;
with Coyote_SQC.UI.Datetime_Picker;
with Glib;           use Glib;
with Gtk.Box;
with Gtk.Button;
with Gtk.Check_Button;
with Gtk.Toggle_Button;
with Gtk.Check_Menu_Item;
with Gtk.Enums;
with Gtk.Separator;

package body Coyote_SQC.UI.Toolbar is
   use type Coyote_SQC.App.App_State_Access;
   use type Gtk.Check_Menu_Item.Gtk_Check_Menu_Item;
   use type Gtk.Check_Button.Gtk_Check_Button;

   --  Module-level picker instances (heap-allocated).
   type Picker_Access is access all Coyote_SQC.UI.Datetime_Picker.Instance;
   From_Picker : Picker_Access := null;
   To_Picker   : Picker_Access := null;
   --  Module-level Run Sequence checkbox handle (set by Build).
   Run_Seq_Check : Gtk.Check_Button.Gtk_Check_Button := null;
   --  Guard to prevent recursive activation when syncing the checkbox
   --  programmatically (e.g. when the View menu item toggles the mode).
   Updating : Boolean := False;

   --  ── Callbacks ─────────────────────────────────────────────────────────

   procedure On_From_Changed (T : Ada.Calendar.Time) is
   begin
      if Coyote_SQC.App.State /= null then
         Coyote_SQC.App.State.Date_From := T;
         Coyote_SQC.UI.Chart_Canvas.Sync_X_From_Dates;
         Coyote_SQC.UI.Chart_Canvas.Queue_Redraw;
      end if;
   end On_From_Changed;

   procedure On_To_Changed (T : Ada.Calendar.Time) is
   begin
      if Coyote_SQC.App.State /= null then
         Coyote_SQC.App.State.Date_To := T;
         Coyote_SQC.UI.Chart_Canvas.Sync_X_From_Dates;
         Coyote_SQC.UI.Chart_Canvas.Queue_Redraw;
      end if;
   end On_To_Changed;

   procedure On_Show_All_Clicked
     (Button : access Gtk.Button.Gtk_Button_Record'Class)
   is
      pragma Unreferenced (Button);
      use Ada.Calendar;
   begin
      if Coyote_SQC.App.State = null
        or else Coyote_SQC.App.State.Sessions.Is_Empty
      then
         return;
      end if;
      Coyote_SQC.App.State.Date_From :=
        Coyote_SQC.App.State.Sessions.First_Element.Start_Time;
      Coyote_SQC.App.State.Date_To   :=
        Coyote_SQC.App.State.Sessions.Last_Element.Start_Time;
      Coyote_SQC.UI.Chart_Canvas.Sync_X_From_Dates;
      Sync_Pickers;
      Coyote_SQC.UI.Chart_Canvas.Queue_Redraw;
   end On_Show_All_Clicked;

   procedure On_Y_Fit_Clicked
     (Button : access Gtk.Button.Gtk_Button_Record'Class)
   is
      pragma Unreferenced (Button);
   begin
      Coyote_SQC.App.Y_Fit;
      Coyote_SQC.UI.Chart_Canvas.Queue_Redraw;
   end On_Y_Fit_Clicked;

   procedure On_Run_Sequence_Toggled
     (Self : access Gtk.Toggle_Button.Gtk_Toggle_Button_Record'Class)
   is
   begin
      if Updating then return; end if;
      if Coyote_SQC.App.State = null then return; end if;
      Coyote_SQC.UI.Chart_Canvas.Switch_X_Scale_Mode (Self.Get_Active);
      --  Keep the View menu check item in sync.
      if Coyote_SQC.App.State.Run_Sequence_Item /= null then
         Updating := True;
         Coyote_SQC.App.State.Run_Sequence_Item.Set_Active (Self.Get_Active);
         Updating := False;
      end if;
   end On_Run_Sequence_Toggled;


   --  ── Build ─────────────────────────────────────────────────────────────

   procedure Build
     (Container : not null access Gtk.Box.Gtk_Box_Record'Class)
   is
      use Gtk.Box;
      use Gtk.Button;
      use Gtk.Check_Button;
      use Gtk.Separator;
      use Gtk.Enums;

      Toolbar  : Gtk.Box.Gtk_Box;
      Sep      : Gtk.Separator.Gtk_Separator;
      Show_All : Gtk.Button.Gtk_Button;
      Y_Fit    : Gtk.Button.Gtk_Button;
      Run_Seq  : Gtk.Check_Button.Gtk_Check_Button;
   begin
      Gtk.Box.Gtk_New_Hbox (Toolbar);
      Toolbar.Set_Spacing (6);
      Toolbar.Set_Border_Width (4);

      --  From picker.
      From_Picker := new Coyote_SQC.UI.Datetime_Picker.Instance;
      Coyote_SQC.UI.Datetime_Picker.Create
        (Self      => From_Picker.all,
         Container => Toolbar,
         Label     => "From");
      From_Picker.On_Changed (On_From_Changed'Access);

      --  To picker.
      To_Picker := new Coyote_SQC.UI.Datetime_Picker.Instance;
      Coyote_SQC.UI.Datetime_Picker.Create
        (Self      => To_Picker.all,
         Container => Toolbar,
         Label     => "To");
      To_Picker.On_Changed (On_To_Changed'Access);

      --  Separator.
      Gtk.Separator.Gtk_New_Vseparator (Sep);
      Toolbar.Pack_Start (Sep, False, False, 4);

      --  Show All button.
      Gtk.Button.Gtk_New (Show_All, "Show All");
      Show_All.On_Clicked (On_Show_All_Clicked'Access);
      Toolbar.Pack_Start (Show_All, False, False, 0);

      --  Y-Fit button.
      Gtk.Button.Gtk_New (Y_Fit, "Y-Fit");
      Y_Fit.On_Clicked (On_Y_Fit_Clicked'Access);
      Toolbar.Pack_Start (Y_Fit, False, False, 0);

      --  Run Sequence checkbox.
      Gtk.Check_Button.Gtk_New (Run_Seq, "Run Sequence");
      Run_Seq.On_Toggled (On_Run_Sequence_Toggled'Access);
      Toolbar.Pack_Start (Run_Seq, False, False, 4);
      Run_Seq_Check := Run_Seq;

      Container.Pack_Start (Toolbar, False, False, 0);
   end Build;

   --  ── Sync_Pickers ──────────────────────────────────────────────────────

   procedure Sync_Pickers is
   begin
      if From_Picker /= null and then Coyote_SQC.App.State /= null then
         From_Picker.Set_Time (Coyote_SQC.App.State.Date_From);
      end if;
      if To_Picker /= null and then Coyote_SQC.App.State /= null then
         To_Picker.Set_Time (Coyote_SQC.App.State.Date_To);
      end if;
   end Sync_Pickers;

   procedure Sync_Run_Sequence_Button is
   begin
      if Run_Seq_Check /= null and then Coyote_SQC.App.State /= null then
         Updating := True;
         Run_Seq_Check.Set_Active (Coyote_SQC.App.State.Run_Sequence_Mode);
         Updating := False;
      end if;
   end Sync_Run_Sequence_Button;


end Coyote_SQC.UI.Toolbar;
