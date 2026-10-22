with AUnit.Assertions;
with AUnit.Test_Caller;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Coyote_GUI;
with Coyote_GUI.Tool_Detail_Window;
with Glib;
with Gtk.Adjustment;
with Gtk.Container;
with Gtk.Clipboard;
with Gtk.Enums;
with Gtk.Image;
with Gtk.Label;
with Gtk.Main;
with Gtk.Menu;
with Gtk.Menu_Item;
with Gtk.Menu_Bar;
with Gtk.Paned;
with Gtk.Scrolled_Window;
with Gtk.Text_Buffer;
with Gtk.Text_Iter;
with Gtk.Text_View;
with Gtk.Widget;
with Pango.Layout;

package body Coyote_GUI_Tool_Detail_Window_Tests is

   use AUnit.Assertions;
   use type Glib.Gint;
   use type Gtk.Adjustment.Gtk_Adjustment;
   use type Glib.Gdouble;
   use type Gtk.Widget.Widget_List.Glist;
   use type Gtk.Paned.Gtk_Paned;
   use type Gtk.Label.Gtk_Label;
   use type Pango.Layout.Pango_Ellipsize_Mode;
   use type Gtk.Enums.Gtk_Orientation;
   use type Gtk.Menu.Gtk_Menu;
   use type Gtk.Menu_Item.Gtk_Menu_Item;
   use type Gtk.Widget.Gtk_Widget;
   use type Gtk.Window.Gtk_Window;

   function Display_Detected return Boolean is
   begin
      return Ada.Environment_Variables.Exists ("DISPLAY")
        or else Ada.Environment_Variables.Exists ("WAYLAND_DISPLAY");
   exception
      when others =>
         return False;
   end Display_Detected;

   procedure Drain_Events is
      Quit : Boolean;
      pragma Unreferenced (Quit);
   begin
      while Gtk.Main.Events_Pending loop
         Quit := Gtk.Main.Main_Iteration;
      end loop;
   end Drain_Events;

   procedure Pump_Frames is
   begin
      for Frame in 1 .. 6 loop
         delay 0.02;
         Drain_Events;
      end loop;
   end Pump_Frames;

   function Find_Widget
     (Root : Gtk.Widget.Gtk_Widget;
      Name : String) return Gtk.Widget.Gtk_Widget
   is
      Children : Gtk.Widget.Widget_List.Glist;
      Node     : Gtk.Widget.Widget_List.Glist;
      Found    : Gtk.Widget.Gtk_Widget;
   begin
      if Root = null then
         return null;
      elsif Root.Get_Name = Name then
         return Root;
      elsif Root.all not in Gtk.Container.Gtk_Container_Record'Class then
         return null;
      end if;

      Children := Gtk.Container.Get_Children
        (Gtk.Container.Gtk_Container (Root));
      Node := Gtk.Widget.Widget_List.First (Children);
      while Node /= Gtk.Widget.Widget_List.Null_List loop
         Found := Find_Widget (Gtk.Widget.Widget_List.Get_Data (Node), Name);
         if Found /= null then
            Gtk.Widget.Widget_List.Free (Children);
            return Found;
         end if;
         Node := Gtk.Widget.Widget_List.Next (Node);
      end loop;
      Gtk.Widget.Widget_List.Free (Children);
      return null;
   end Find_Widget;

   function Find_Window
     (Except_Window : Gtk.Window.Gtk_Window := null)
      return Gtk.Window.Gtk_Window
   is
      Windows : Gtk.Widget.Widget_List.Glist := Gtk.Window.List_Toplevels;
      Node    : Gtk.Widget.Widget_List.Glist :=
        Gtk.Widget.Widget_List.First (Windows);
      Found   : Gtk.Window.Gtk_Window;
   begin
      while Node /= Gtk.Widget.Widget_List.Null_List loop
         declare
            Widget : constant Gtk.Widget.Gtk_Widget :=
              Gtk.Widget.Widget_List.Get_Data (Node);
         begin
            if Widget /= null
              and then Widget.Get_Name = "tool-detail-window"
              and then Widget /= Gtk.Widget.Gtk_Widget (Except_Window)
            then
               Found := Gtk.Window.Gtk_Window (Widget);
               Gtk.Widget.Widget_List.Free (Windows);
               return Found;
            end if;
         end;
         Node := Gtk.Widget.Widget_List.Next (Node);
      end loop;
      Gtk.Widget.Widget_List.Free (Windows);
      return null;
   end Find_Window;

   function View_Text (Widget : Gtk.Widget.Gtk_Widget) return String is
      View   : constant Gtk.Text_View.Gtk_Text_View :=
        Gtk.Text_View.Gtk_Text_View (Widget);
      Buffer : constant Gtk.Text_Buffer.Gtk_Text_Buffer := View.Get_Buffer;
      First  : Gtk.Text_Iter.Gtk_Text_Iter;
      Last   : Gtk.Text_Iter.Gtk_Text_Iter;
   begin
      Buffer.Get_Start_Iter (First);
      Buffer.Get_End_Iter (Last);
      return Buffer.Get_Text (First, Last);
   end View_Text;

   function Menu_Item_At
     (Root  : Gtk.Widget.Gtk_Widget;
      Index : Natural) return Gtk.Menu_Item.Gtk_Menu_Item
   is
      Children : Gtk.Widget.Widget_List.Glist;
      Node     : Gtk.Widget.Widget_List.Glist;
      Current  : Natural := 0;
      Result   : Gtk.Menu_Item.Gtk_Menu_Item;
   begin
      Children := Gtk.Container.Get_Children
        (Gtk.Container.Gtk_Container (Root));
      Node := Gtk.Widget.Widget_List.First (Children);
      while Node /= Gtk.Widget.Widget_List.Null_List loop
         if Current = Index then
            Result := Gtk.Menu_Item.Gtk_Menu_Item
              (Gtk.Widget.Widget_List.Get_Data (Node));
            exit;
         end if;
         Current := Current + 1;
         Node := Gtk.Widget.Widget_List.Next (Node);
      end loop;
      Gtk.Widget.Widget_List.Free (Children);
      return Result;
   end Menu_Item_At;

   function Count_Scrollers (Root : Gtk.Widget.Gtk_Widget) return Natural is
      Children : Gtk.Widget.Widget_List.Glist;
      Node     : Gtk.Widget.Widget_List.Glist;
      Count    : Natural := 0;
   begin
      if Root = null then
         return 0;
      end if;
      if Root.all in Gtk.Scrolled_Window.Gtk_Scrolled_Window_Record'Class then
         Count := 1;
      end if;
      if Root.all in Gtk.Container.Gtk_Container_Record'Class then
         Children := Gtk.Container.Get_Children
           (Gtk.Container.Gtk_Container (Root));
         Node := Gtk.Widget.Widget_List.First (Children);
         while Node /= Gtk.Widget.Widget_List.Null_List loop
            Count := Count + Count_Scrollers
              (Gtk.Widget.Widget_List.Get_Data (Node));
            Node := Gtk.Widget.Widget_List.Next (Node);
         end loop;
         Gtk.Widget.Widget_List.Free (Children);
      end if;
      return Count;
   end Count_Scrollers;

   overriding procedure Set_Up (T : in out Test) is
   begin
      T.Display_Available := False;
      if Display_Detected then
         Gtk.Main.Init;
         T.Display_Available := True;
         Gtk.Window.Gtk_New (T.Main_Window, Gtk.Enums.Window_Toplevel);
      end if;
   end Set_Up;

   overriding procedure Tear_Down (T : in out Test) is
      Window : Gtk.Window.Gtk_Window;
   begin
      if not T.Display_Available then
         return;
      end if;
      Window := Find_Window;
      while Window /= null loop
         Window.Destroy;
         Drain_Events;
         Window := Find_Window;
      end loop;
      if T.Main_Window /= null then
         T.Main_Window.Destroy;
         T.Main_Window := null;
      end if;
      Drain_Events;
   end Tear_Down;

   procedure Show_Sample
     (Main_Window : Gtk.Window.Gtk_Window;
      Args        : String;
      Result      : String;
      Media_Type  : String := "";
      Tool_Name   : String := "sample-tool";
      Completed   : Boolean := True;
      Status      : Coyote_GUI.Tool_Status := Coyote_GUI.Success)
   is
      Info : Coyote_GUI.Tool_Info;
   begin
      Info.Name := To_Unbounded_String (Tool_Name);
      Info.Args := To_Unbounded_String (Args);
      Info.Result_Text := To_Unbounded_String (Result);
      Info.Media_Type := To_Unbounded_String (Media_Type);
      Info.Model := To_Unbounded_String ("model-" & (1 .. 180 => 'm'));
      Info.Source_Directory :=
        To_Unbounded_String ("/tmp/" & (1 .. 180 => 'd'));
      Info.Session_Start := To_Unbounded_String ("2026-10-21T12:00:00Z");
      Info.Turn_Index := 3;
      Info.Call_In_Turn := 2;
      Info.Completed := Completed;
      Info.Result_Status := Status;
      Coyote_GUI.Tool_Detail_Window.Show (Info, Main_Window.all'Access);
   end Show_Sample;

   procedure Test_Stable_Layout_And_Snapshots (T : in out Test) is
      Window       : Gtk.Window.Gtk_Window;
      Header       : Gtk.Widget.Gtk_Widget;
      Menu         : Gtk.Widget.Gtk_Widget;
      Actions      : Gtk.Widget.Gtk_Widget;
      Paned        : Gtk.Paned.Gtk_Vpaned;
      Arguments    : Gtk.Widget.Gtk_Widget;
      Result       : Gtk.Widget.Gtk_Widget;
      Model        : Gtk.Label.Gtk_Label;
      Allocation   : Gtk.Widget.Gtk_Allocation;
      First_Window : Gtk.Window.Gtk_Window;
      Payload      : constant String :=
        (1 .. 100 => 'a') & ASCII.LF
        & (1 .. 100 => 'b') & ASCII.LF
        & (1 .. 100 => 'c') & ASCII.LF
        & (1 .. 100 => 'd') & ASCII.LF
        & (1 .. 100 => 'e') & ASCII.LF
        & (1 .. 100 => 'f') & ASCII.LF
        & (1 .. 100 => 'g') & ASCII.LF
        & (1 .. 100 => 'h') & ASCII.LF
        & (1 .. 100 => 'i') & ASCII.LF
        & (1 .. 100 => 'j') & ASCII.LF
        & (1 .. 100 => 'k') & ASCII.LF
        & (1 .. 100 => 'l') & ASCII.LF
        & (1 .. 100 => 'm') & ASCII.LF
        & (1 .. 100 => 'n') & ASCII.LF
        & (1 .. 100 => 'o') & ASCII.LF
        & (1 .. 100 => 'p') & ASCII.LF
        & (1 .. 100 => 'q') & ASCII.LF
        & (1 .. 100 => 'r') & ASCII.LF
        & (1 .. 100 => 's') & ASCII.LF
        & (1 .. 100 => 't') & ASCII.LF;
      First_Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Second_Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      First_Adjustment : Gtk.Adjustment.Gtk_Adjustment;
      Second_Adjustment : Gtk.Adjustment.Gtk_Adjustment;
      Saved_Position : Glib.Gint;
      Menu_Bar     : Gtk.Menu_Bar.Gtk_Menu_Bar;
      File_Menu    : Gtk.Menu.Gtk_Menu;
      Edit_Menu    : Gtk.Menu.Gtk_Menu;
      Select_All   : Gtk.Menu_Item.Gtk_Menu_Item;
      Copy_Item    : Gtk.Menu_Item.Gtk_Menu_Item;
      First_Buffer : Gtk.Text_Buffer.Gtk_Text_Buffer;
      Start_Iter   : Gtk.Text_Iter.Gtk_Text_Iter;
      End_Iter     : Gtk.Text_Iter.Gtk_Text_Iter;
      Has_Selection : Boolean;
   begin
      if not T.Display_Available then
         return;
      end if;
      Show_Sample (T.Main_Window, "{""command"":""run""}", Payload);
      Window := Find_Window;
      Assert (Window /= null, "Show creates named detail toplevel");
      Pump_Frames;
      Window.Get_Allocation (Allocation);
      Assert (Allocation.Width = 760 and then Allocation.Height = 600,
              "default mapped allocation is 760 by 600");
      Header := Find_Widget
        (Gtk.Widget.Gtk_Widget (Window), "tool-detail-header");
      Menu := Find_Widget
        (Gtk.Widget.Gtk_Widget (Window), "tool-detail-menu");
      Actions := Find_Widget
        (Gtk.Widget.Gtk_Widget (Window), "tool-detail-actions");
      Paned := Gtk.Paned.Gtk_Vpaned
        (Find_Widget (Gtk.Widget.Gtk_Widget (Window), "tool-detail-panes"));
      Arguments := Find_Widget
        (Gtk.Widget.Gtk_Widget (Window), "tool-detail-arguments");
      Result := Find_Widget
        (Gtk.Widget.Gtk_Widget (Window), "tool-detail-result");
      Assert
        (Header /= null and then Menu /= null
         and then Actions /= null and then Paned /= null,
         "stable menu, header, panes, and actions are present");
      Assert
        (Gtk.Paned.Get_Orientation (Paned) = Gtk.Enums.Orientation_Vertical,
         "detail panes are vertically oriented");
      Assert (Arguments /= null and then Result /= null,
              "argument and result are text views");
      Assert (Count_Scrollers (Gtk.Widget.Gtk_Widget (Window)) = 2,
              "one independent scroller is used for each pane");
      Assert (View_Text (Arguments) = "command:" & ASCII.LF & "run"
                & ASCII.LF & ASCII.LF,
              "argument values are arranged in a text buffer");
      Assert (View_Text (Result) = Payload,
              "multi-line result retains the complete snapshot");
      First_Scroll := Gtk.Scrolled_Window.Gtk_Scrolled_Window
        (Arguments.Get_Parent);
      Second_Scroll := Gtk.Scrolled_Window.Gtk_Scrolled_Window
        (Result.Get_Parent);
      Assert
        (not Header.Is_Ancestor (First_Scroll)
         and then not Header.Is_Ancestor (Second_Scroll)
         and then not Menu.Is_Ancestor (First_Scroll)
         and then not Menu.Is_Ancestor (Second_Scroll)
         and then not Actions.Is_Ancestor (First_Scroll)
         and then not Actions.Is_Ancestor (Second_Scroll),
         "metadata, menus, and actions are outside both scrolling regions");
      First_Adjustment := First_Scroll.Get_Vadjustment;
      Second_Adjustment := Second_Scroll.Get_Vadjustment;
      Assert (First_Adjustment /= Second_Adjustment,
              "argument and result scrolling adjustments are independent");
      Assert
        (Gtk.Adjustment.Get_Upper (Second_Adjustment)
         > Gtk.Adjustment.Get_Page_Size (Second_Adjustment),
         "long multi-line result has a vertical scroll range");
      Gtk.Adjustment.Set_Value
        (Second_Adjustment,
         Gtk.Adjustment.Get_Upper (Second_Adjustment)
         - Gtk.Adjustment.Get_Page_Size (Second_Adjustment));
      Pump_Frames;
      Assert (Gtk.Adjustment.Get_Value (First_Adjustment) = 0.0,
              "scrolling result leaves argument position unchanged");

      Model := Gtk.Label.Gtk_Label
        (Find_Widget (Gtk.Widget.Gtk_Widget (Window), "tool-detail-Model"));
      Assert (Model /= null and then Gtk.Label.Get_Text (Model)'Length > 100,
              "metadata label retains long model text");
      Assert
        (Gtk.Widget.Get_Tooltip_Text (Gtk.Widget.Gtk_Widget (Model))
         = Gtk.Label.Get_Text (Model),
              "metadata tooltip retains full value");
      Assert (Gtk.Label.Get_Selectable (Model)
                and then Gtk.Label.Get_Single_Line_Mode (Model),
              "metadata label is selectable and single line");
      Assert (Gtk.Label.Get_Ellipsize (Model) = Pango.Layout.Ellipsize_End,
              "metadata label ellipsizes at end");

      Paned.Get_Allocation (Allocation);
      Assert (Gtk.Paned.Get_Position (Paned) > 0
                and then Gtk.Paned.Get_Position (Paned) < Allocation.Height,
              "splitter initializes inside the allocated pane");
      Assert (Gtk.Paned.Get_Position (Paned) * 100 / Allocation.Height
                in 35 .. 45,
              "initial sash gives arguments about forty percent");
      Window.Resize (600, 400);
      Pump_Frames;
      Window.Get_Allocation (Allocation);
      Assert (Allocation.Width = 600 and then Allocation.Height = 400,
              "long metadata and payload fit the minimum window size");
      Gtk.Paned.Set_Position (Paned, 1);
      Pump_Frames;
      Paned.Get_Allocation (Allocation);
      Saved_Position := Gtk.Paned.Get_Position (Paned);
      Assert (Saved_Position >= 36
                and then Allocation.Height - Saved_Position >= 36,
              "both panes retain their usable minimum after sash movement");
      Window.Resize (900, 720);
      Pump_Frames;
      Paned.Get_Allocation (Allocation);
      Assert (Gtk.Paned.Get_Position (Paned) >= 36
                and then Allocation.Height
                  - Gtk.Paned.Get_Position (Paned) >= 36,
              "resizing keeps both panes usable");
      Saved_Position := Gtk.Paned.Get_Position (Paned);
      Paned.Hide;
      Paned.Show;
      Pump_Frames;
      Assert (Gtk.Paned.Get_Position (Paned) = Saved_Position,
              "remapping does not reset the user's divider position");
      Window.Get_Allocation (Allocation);
      Assert (Allocation.Width >= 600 and then Allocation.Height >= 400,
              "resized window remains above requested minimum");
      Assert
        (Find_Widget
           (Gtk.Widget.Gtk_Widget (Window), "tool-detail-header") /= null
         and then Find_Widget
           (Gtk.Widget.Gtk_Widget (Window), "tool-detail-menu") /= null
         and then Find_Widget
           (Gtk.Widget.Gtk_Widget (Window), "tool-detail-actions") /= null,
              "header, menu, and actions remain present after resizing");

      Menu_Bar := Gtk.Menu_Bar.Gtk_Menu_Bar (Menu);
      File_Menu := Gtk.Menu.Gtk_Menu
        (Gtk.Menu_Item.Get_Submenu
           (Menu_Item_At
              (Gtk.Widget.Gtk_Widget (Menu_Bar), 0).all'Access));
      Edit_Menu := Gtk.Menu.Gtk_Menu
        (Gtk.Menu_Item.Get_Submenu
           (Menu_Item_At
              (Gtk.Widget.Gtk_Widget (Menu_Bar), 1).all'Access));
      Assert (File_Menu /= null and then Edit_Menu /= null,
              "File and Edit entries expose their submenus");
      Copy_Item := Menu_Item_At (Gtk.Widget.Gtk_Widget (Edit_Menu), 0);
      Select_All := Menu_Item_At (Gtk.Widget.Gtk_Widget (Edit_Menu), 1);
      Gtk.Window.Set_Focus (Window, Arguments);
      Gtk.Menu_Item.Activate (Select_All);
      First_Buffer := Gtk.Text_View.Get_Buffer
        (Gtk.Text_View.Gtk_Text_View (Arguments));
      Gtk.Text_Buffer.Get_Selection_Bounds
        (First_Buffer, Start_Iter, End_Iter, Has_Selection);
      Assert (Has_Selection,
              "Edit > Select All selects the focused argument buffer");
      Gtk.Menu_Item.Activate (Copy_Item);
      Assert
        (Gtk.Clipboard.Wait_For_Text (Gtk.Clipboard.Get)
         = View_Text (Arguments),
         "Edit > Copy places the selected argument text on the clipboard");
      Gtk.Window.Set_Focus (Window, Gtk.Widget.Gtk_Widget (Model));
      Gtk.Menu_Item.Activate (Select_All);
      declare
         First, Last : Glib.Gint;
         Selected    : Boolean;
      begin
         Model.Get_Selection_Bounds (First, Last, Selected);
         Assert (Selected and then First = 0 and then Last = 186,
                 "full metadata selection: " & First'Image & Last'Image);
      end;
      Gtk.Menu_Item.Activate (Copy_Item);
      Assert
        (Gtk.Clipboard.Wait_For_Text (Gtk.Clipboard.Get)
         = Gtk.Label.Get_Text (Model),
         "metadata Select All and Copy includes the full ellipsized value");
      Show_Sample
        (T.Main_Window, "{""second"":""value""}", "second snapshot",
         Tool_Name => "second-tool");
      Pump_Frames;
      First_Window := Window;
      Window := Find_Window (Except_Window => First_Window);
      Assert (Window /= null and then Window /= First_Window,
              "a second detail call creates an independent window");
      Assert
        (View_Text
           (Find_Widget
              (Gtk.Widget.Gtk_Widget (First_Window), "tool-detail-result"))
         = Payload,
              "opening a second detail window leaves first result unchanged");
      Assert
        (View_Text
           (Find_Widget
              (Gtk.Widget.Gtk_Widget (Window), "tool-detail-result"))
         = "second snapshot",
              "second window retains its own result snapshot");
      Menu_Bar := Gtk.Menu_Bar.Gtk_Menu_Bar
        (Find_Widget (Gtk.Widget.Gtk_Widget (Window), "tool-detail-menu"));
      File_Menu := Gtk.Menu.Gtk_Menu
        (Gtk.Menu_Item.Get_Submenu
           (Menu_Item_At
              (Gtk.Widget.Gtk_Widget (Menu_Bar), 0).all'Access));
      Gtk.Menu_Item.Activate
        (Menu_Item_At (Gtk.Widget.Gtk_Widget (File_Menu), 0));
      Pump_Frames;
      Assert
        (Find_Widget
           (Gtk.Widget.Gtk_Widget (First_Window), "tool-detail-header")
         /= null,
         "File > Close in the second window preserves the first snapshot");
      Assert (Find_Window = First_Window,
              "File > Close closes only the selected detail window");
   end Test_Stable_Layout_And_Snapshots;

   procedure Test_Argument_Formatting_And_Empty_Values (T : in out Test) is
      Window    : Gtk.Window.Gtk_Window;
      Arguments : Gtk.Widget.Gtk_Widget;
   begin
      if not T.Display_Available then
         return;
      end if;
      Show_Sample
        (T.Main_Window,
         "{""count"":7,""stdin"":null,""run_group"":0}", "ok");
      Window := Find_Window;
      Pump_Frames;
      Arguments := Find_Widget
        (Gtk.Widget.Gtk_Widget (Window), "tool-detail-arguments");
      Assert (Arguments /= null, "structured arguments have a named view");
      Assert (Ada.Strings.Fixed.Index (View_Text (Arguments), "count:") > 0,
              "non-string argument values are rendered");
      Assert (Ada.Strings.Fixed.Index (View_Text (Arguments), "7") > 0,
              "numeric argument value is preserved");
      Assert
        (Ada.Strings.Fixed.Index (View_Text (Arguments), "run_group:") = 0
         and then Ada.Strings.Fixed.Index
           (View_Text (Arguments), "stdin:") = 0,
         "hidden orchestration arguments are filtered");
      Window.Destroy;
      Show_Sample (T.Main_Window, "", "empty");
      Window := Find_Window;
      Arguments := Find_Widget
        (Gtk.Widget.Gtk_Widget (Window), "tool-detail-arguments");
      Assert (View_Text (Arguments) = "(no arguments)",
              "empty arguments use the explicit text-buffer placeholder");
      Window.Destroy;
      Show_Sample (T.Main_Window, "not-json payload", "raw");
      Window := Find_Window;
      Arguments := Find_Widget
        (Gtk.Widget.Gtk_Widget (Window), "tool-detail-arguments");
      Assert (Arguments /= null, "non-object arguments use raw text");
      Assert (View_Text (Arguments) = "not-json payload",
              "non-object raw argument text is preserved");
      Window.Destroy;
      Show_Sample (T.Main_Window, "[]", "array arguments");
      Window := Find_Window;
      Arguments := Find_Widget
        (Gtk.Widget.Gtk_Widget (Window), "tool-detail-arguments");
      Assert (View_Text (Arguments) = "[]",
              "valid non-object JSON remains raw argument text");
      Window.Destroy;
      Show_Sample (T.Main_Window, "{""run_group"":0,""stdin"":null}",
                   "all filtered");
      Window := Find_Window;
      Arguments := Find_Widget
        (Gtk.Widget.Gtk_Widget (Window), "tool-detail-arguments");
      Assert (View_Text (Arguments) = "(no arguments)",
              "all-hidden arguments use the empty placeholder");
   end Test_Argument_Formatting_And_Empty_Values;

   procedure Test_Image_Failure_Fallback (T : in out Test) is
      Window : Gtk.Window.Gtk_Window;
      Result : Gtk.Widget.Gtk_Widget;
   begin
      if not T.Display_Available then
         return;
      end if;
      Show_Sample (T.Main_Window, "{}", "not base64 image", "image/png");
      Window := Find_Window;
      Pump_Frames;
      Assert (Window /= null, "image result detail window is created");
      Result := Find_Widget
        (Gtk.Widget.Gtk_Widget (Window), "tool-detail-result");
      Assert (Result /= null and then Result.all in
                Gtk.Text_View.Gtk_Text_View_Record'Class,
              "image failure is represented by a text view");
      Assert
        (View_Text (Result) = "[ image result could not be decoded ]",
         "invalid image data produces the decode fallback text");
   end Test_Image_Failure_Fallback;

   procedure Test_Running_Snapshot_Is_Stable (T : in out Test) is
      Window       : Gtk.Window.Gtk_Window;
      Other_Window : Gtk.Window.Gtk_Window;
      Status       : Gtk.Label.Gtk_Label;
      Result       : Gtk.Widget.Gtk_Widget;
   begin
      if not T.Display_Available then
         return;
      end if;
      Show_Sample
        (T.Main_Window, "{}", "discarded live result",
         Completed => False, Status => Coyote_GUI.Running);
      Window := Find_Window;
      Pump_Frames;
      Status := Gtk.Label.Gtk_Label
        (Find_Widget (Gtk.Widget.Gtk_Widget (Window), "tool-detail-Status"));
      Result := Find_Widget
        (Gtk.Widget.Gtk_Widget (Window), "tool-detail-result");
      Assert (Gtk.Label.Get_Text (Status) = "Running",
              "active snapshot reports its captured running status");
      Assert
        (View_Text (Result)
         = "No result is available while the tool is running.",
         "active snapshot does not expose an in-flight result");
      Show_Sample
        (T.Main_Window, "{}", "later completed result",
         Completed => True, Status => Coyote_GUI.Success);
      Pump_Frames;
      Assert
        (View_Text (Find_Widget
           (Gtk.Widget.Gtk_Widget (Window), "tool-detail-result"))
         = "No result is available while the tool is running.",
         "reopening a completed call does not mutate the active snapshot");
      Other_Window := Find_Window (Except_Window => Window);
      Assert (Other_Window /= null,
              "completed call opens as a separate detail snapshot");
      Assert
        (View_Text (Find_Widget
           (Gtk.Widget.Gtk_Widget (Other_Window), "tool-detail-result"))
         = "later completed result",
         "completed snapshot displays the result captured when reopened");
   end Test_Running_Snapshot_Is_Stable;

   procedure Test_Successful_Image_Layout (T : in out Test) is
      Image_Data : constant String :=
        "iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFElEQVR4nGP4"
        & "z8DAAMIg4j8QMAAAM94G+lX/f/AAAAAASUVORK5CYII=";
      Window : Gtk.Window.Gtk_Window;
      Image  : Gtk.Widget.Gtk_Widget;
   begin
      if not T.Display_Available then
         return;
      end if;
      Show_Sample
        (T.Main_Window, "{}", Image_Data, "image/png");
      Window := Find_Window;
      Pump_Frames;
      Image := Find_Widget
        (Gtk.Widget.Gtk_Widget (Window), "tool-detail-result-image");
      Assert
        (Image /= null and then Image.all in
           Gtk.Image.Gtk_Image_Record'Class,
         "valid PNG result renders as an image widget");
      Assert
        (Count_Scrollers (Gtk.Widget.Gtk_Widget (Window)) = 2,
         "successful image layout has exactly "
         & "the argument and result scrollers");
      Assert
        (Find_Widget (Gtk.Widget.Gtk_Widget (Window), "tool-detail-result")
         = null,
         "successful image result has no text-view scroller");
   end Test_Successful_Image_Layout;

   package Caller is new AUnit.Test_Caller (Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (Caller.Create
        ("Coyote.GUI tool detail stable layout and snapshots",
         Test_Stable_Layout_And_Snapshots'Access));
      Result.Add_Test (Caller.Create
        ("Coyote.GUI tool detail argument formatting",
         Test_Argument_Formatting_And_Empty_Values'Access));
      Result.Add_Test (Caller.Create
        ("Coyote.GUI tool detail image fallback",
         Test_Image_Failure_Fallback'Access));
      Result.Add_Test (Caller.Create
        ("Coyote.GUI tool detail running snapshot stability",
         Test_Running_Snapshot_Is_Stable'Access));
      Result.Add_Test (Caller.Create
        ("Coyote.GUI tool detail successful image layout",
         Test_Successful_Image_Layout'Access));
      return Result;
   end Suite;

end Coyote_GUI_Tool_Detail_Window_Tests;
