--  Coyote_GUI.Conversation_Stack body.
--
--  Project: coyote

with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Ada.Text_IO;
with Coyote_App.Utils;       use Coyote_App.Utils;
with Coyote_GUI;
with Coyote_GUI.Tool_Detail_Window;
with Glib;                   use Glib;
with Gtk.Adjustment;
with Gtk.Handlers;
with GNATCOLL.JSON;
with Gtk.Box;
with Gtk.Button;
with Gtk.Clipboard;
with Gtk.Enums;
with Gtk.Frame;
with Gtk.Grid;
with Gtk.Label;
with Gtk.Scrolled_Window;
with Gtk.Separator;
with Gtk.Text_Buffer;
with Gtk.Text_Iter;
with Gtk.Text_View;
with Pango.Font;

package body Coyote_GUI.Conversation_Stack is

   use type Gtk.Box.Gtk_Box;
   use type Gtk.Scrolled_Window.Gtk_Scrolled_Window;
   use type Gtk.Text_Buffer.Gtk_Text_Buffer;
   use type Gtk.Text_View.Gtk_Text_View;
   use type Gtk.Window.Gtk_Window;

   type Instance_Access is access all Instance;

   type Detail_Context is record
      Stack   : Instance_Access;
      Tool_Id : Unbounded_String;
   end record;

   package Detail_Callback is new Gtk.Handlers.User_Callback
     (Gtk.Button.Gtk_Button_Record, Detail_Context);

   type Fork_Context is record
      Handler : Coyote_GUI.Conversation_Stack.Fork_Handler;
      UUID    : Unbounded_String;
      Turn_N  : Positive;
      Step_N  : Natural;
   end record;

   package Fork_Callback is new Gtk.Handlers.User_Callback
     (Gtk.Button.Gtk_Button_Record, Fork_Context);

   procedure On_Detail_Clicked
     (Button : access Gtk.Button.Gtk_Button_Record'Class;
      Data   : Detail_Context);

   procedure On_Fork_Clicked
     (Button : access Gtk.Button.Gtk_Button_Record'Class;
      Data   : Fork_Context);

   procedure On_Fork_Clicked
     (Button : access Gtk.Button.Gtk_Button_Record'Class;
      Data   : Fork_Context)
   is
      pragma Unreferenced (Button);
   begin
      if Data.Handler /= null then
         Data.Handler.all
           (To_String (Data.UUID), Data.Turn_N, Data.Step_N);
      end if;
   end On_Fork_Clicked;

   procedure Log (C : Instance; Text : String) is
   begin
      if C.Debug_Logging then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error, "[conversation-stack] " & Text);
      end if;
   end Log;

   procedure Append_Buffer
     (Buffer : not null access Gtk.Text_Buffer.Gtk_Text_Buffer_Record'Class;
      Text   : String)
   is
      Iter : Gtk.Text_Iter.Gtk_Text_Iter;
   begin
      Buffer.Get_End_Iter (Iter);
      Buffer.Insert (Iter, Text);
   end Append_Buffer;

   procedure Configure_Text_View
     (View : not null access Gtk.Text_View.Gtk_Text_View_Record'Class)
   is
   begin
      View.Set_Editable (False);
      View.Set_Cursor_Visible (False);
      View.Set_Wrap_Mode (Gtk.Enums.Wrap_Word_Char);
      View.Set_Accepts_Tab (False);
      View.Set_Left_Margin (8);
      View.Set_Right_Margin (8);
      View.Set_Pixels_Above_Lines (2);
      View.Set_Pixels_Below_Lines (2);
   end Configure_Text_View;

   procedure Show_Contents (C : in Instance) is
   begin
      if C.Scroll /= null then
         C.Scroll.Show_All;
      end if;
   end Show_Contents;

   function Tool_Status_Text
     (Status  : Coyote_GUI.Tool_End_Status;
      Result  : String;
      Running : Boolean) return String
   is
      Detail : constant String :=
        Sanitize_UTF8
          ((if Result'Length > 80
            then Result (Result'First .. Result'First + 79)
            else Result));
      Text : Unbounded_String;
   begin
      if Running then
         return "Running";
      end if;
      case Status is
         when Coyote_GUI.Success =>
            return "Completed";
         when Coyote_GUI.Error =>
            Text := To_Unbounded_String ("Error");
            if Detail'Length > 0 then
               Append (Text, " - " & Detail);
            end if;
            return To_String (Text);
         when Coyote_GUI.Cancelled =>
            return "Cancelled";
      end case;
   end Tool_Status_Text;

   function Compact_Tool_Value (Value : String) return String is
   begin
      if Value'Length > 80 then
         return Sanitize_UTF8
           (Value (Value'First .. Value'First + 76) & UC_ELLIP);
      end if;
      return Sanitize_UTF8 (Value);
   end Compact_Tool_Value;

   function Format_Tool_Summary
     (Name    : String;
      Args    : String;
      Status  : Coyote_GUI.Tool_End_Status;
      Result  : String;
      Running : Boolean) return String
   is
      use type GNATCOLL.JSON.JSON_Value_Type;
      Parsed : constant GNATCOLL.JSON.Read_Result :=
        GNATCOLL.JSON.Read (Args);
      Args_Val : constant GNATCOLL.JSON.JSON_Value :=
        (if Parsed.Success
         then Parsed.Value
         else GNATCOLL.JSON.JSON_Null);
      Summary : Unbounded_String;
   begin
      Append (Summary, Name);
      if Args_Val.Kind = GNATCOLL.JSON.JSON_Object_Type then
         declare
            procedure Add_Argument
              (Field_Name  : GNATCOLL.JSON.UTF8_String;
               Field_Value : GNATCOLL.JSON.JSON_Value)
            is
            begin
               Append
                 (Summary,
                  ASCII.LF & String (Field_Name) & ": "
                  & Compact_Tool_Value (JSON_Scalar_Image (Field_Value)));
            end Add_Argument;
         begin
            Args_Val.Map_JSON_Object (Add_Argument'Access);
         end;
      end if;
      Append
        (Summary,
         ASCII.LF & "Status: "
         & Tool_Status_Text (Status, Result, Running));
      return To_String (Summary);
   end Format_Tool_Summary;

   procedure Finalize_Active_Step (C : in out Instance) is
   begin
      C.Step_Frame     := null;
      C.Step_Box       := null;
      C.Step_Open      := False;
      C.Footer_Pending := False;
      C.Text_Open      := False;
      C.Thinking_Open  := False;
   end Finalize_Active_Step;

   procedure Ensure_Active_Step (C : in out Instance) is
   begin
      if C.Footer_Pending then
         Finalize_Active_Step (C);
      end if;
      if not C.Step_Open then
         C.Step_Number := C.Step_Number + 1;
         Gtk.Frame.Gtk_New
           (C.Step_Frame, "Step " & Natural_Image (C.Step_Number));
         C.Step_Frame.Set_Shadow_Type (Gtk.Enums.Shadow_In);
         Gtk.Box.Gtk_New_Vbox
           (C.Step_Box, Homogeneous => False, Spacing => 3);
         C.Step_Box.Set_Border_Width (6);
         C.Step_Frame.Add (C.Step_Box);
         C.Exchange.Pack_Start
           (C.Step_Frame, Expand => False, Fill => True, Padding => 4);
         C.Step_Frames.Append (C.Step_Frame);
         C.Step_Open := True;
         Show_Contents (C);
         Log (C, "began step frame");
      end if;
   end Ensure_Active_Step;

   procedure Add_Text_Element
     (C       : in out Instance;
      Parent  : not null access Gtk.Box.Gtk_Box_Record'Class;
      Caption : String;
      Text    : String;
      Buffer  : out Gtk.Text_Buffer.Gtk_Text_Buffer;
      View    : out Gtk.Text_View.Gtk_Text_View)
   is
      Section : Gtk.Box.Gtk_Box;
      Label   : Gtk.Label.Gtk_Label;
   begin
      Gtk.Box.Gtk_New_Vbox (Section, Homogeneous => False, Spacing => 2);
      Gtk.Label.Gtk_New (Label, Caption);
      Label.Set_Xalign (0.0);
      Label.Set_Selectable (True);
      Section.Pack_Start (Label, Expand => False, Fill => False, Padding => 2);
      Gtk.Text_Buffer.Gtk_New (Buffer);
      Gtk.Text_View.Gtk_New (View, Buffer);
      Configure_Text_View (View);
      if Text'Length > 0 then
         Buffer.Set_Text (Text);
      end if;
      Section.Pack_Start (View, Expand => False, Fill => True, Padding => 2);
      Parent.Pack_Start (Section, Expand => False, Fill => True, Padding => 4);
      Show_Contents (C);
   end Add_Text_Element;

   procedure Create
     (C           : in out Instance;
      Main_Window : not null access Gtk.Window.Gtk_Window_Record'Class)
   is
   begin
      if C.Scroll /= null then
         return;
      end if;
      C.Main_Window := Gtk.Window.Gtk_Window (Main_Window);
      Gtk.Scrolled_Window.Gtk_New (C.Scroll);
      C.Scroll.Set_Policy
        (Gtk.Enums.Policy_Never, Gtk.Enums.Policy_Automatic);
      Gtk.Box.Gtk_New_Vbox (C.Host, Homogeneous => False, Spacing => 6);
      C.Scroll.Add (C.Host);
      Log (C, "created outer scroll host");
   end Create;

   procedure On_Detail_Clicked
     (Button : access Gtk.Button.Gtk_Button_Record'Class;
      Data   : Detail_Context)
   is
      pragma Unreferenced (Button);
   begin
      if Data.Stack /= null
        and then Data.Stack.Main_Window /= null
      then
         Coyote_GUI.Tool_Detail_Window.Show
           (Tool_Detail (Data.Stack.all, To_String (Data.Tool_Id)),
            Data.Stack.Main_Window.all'Access);
      end if;
   end On_Detail_Clicked;

   function Widget (C : Instance)
     return Gtk.Scrolled_Window.Gtk_Scrolled_Window
   is
   begin
      return C.Scroll;
   end Widget;

   procedure Set_Fork_Handler
     (C       : in out Instance;
      Handler : Fork_Handler)
   is
   begin
      C.Fork_Callback := Handler;
   end Set_Fork_Handler;

   procedure Clear (C : in out Instance) is
   begin
      if not C.Exchanges.Is_Empty then
         for Exchange_Index in reverse C.Exchanges.First_Index
           .. C.Exchanges.Last_Index
         loop
            C.Host.Remove (C.Exchanges (Exchange_Index));
         end loop;
      end if;
      C.Exchanges.Clear;
      C.Step_Frames.Clear;
      C.Tools.Clear;
      C.Exchange       := null;
      C.Step_Frame     := null;
      C.Step_Box       := null;
      C.Active_Text    := null;
      C.Active_View    := null;
      C.Thinking       := null;
      C.Thinking_View  := null;
      C.Transcript     := Null_Unbounded_String;
      C.Has_Exchange   := False;
      C.Step_Open      := False;
      C.Footer_Pending := False;
      C.Step_Number    := 0;
      C.Text_Open      := False;
      C.Thinking_Open  := False;
      C.Completed      := False;
      C.Last_Status      := Coyote_GUI.Completed;
      C.Footer_Separator := null;
      C.Footer_Label     := null;
      C.Fork_Button      := null;
      Log (C, "cleared stack and invalidated callbacks");
   end Clear;

   procedure Begin_Request
     (C    : in out Instance;
      Text : String;
      Kind : Coyote_GUI.Request_Kind)
   is
      Caption : constant String :=
        (if Kind = Coyote_GUI.Steer then "Steer" else "Request");
   begin
      Create (C, C.Main_Window.all'Access);
      Gtk.Box.Gtk_New_Vbox (C.Exchange, Homogeneous => False, Spacing => 3);
      C.Host.Pack_Start
        (C.Exchange, Expand => False, Fill => True, Padding => 4);
      C.Exchanges.Append (C.Exchange);
      C.Step_Frames.Clear;
      C.Tools.Clear;
      Add_Text_Element
        (C, C.Exchange, Caption, Text, C.Active_Text, C.Active_View);
      Append (C.Transcript, Text & ASCII.LF);
      C.Has_Exchange   := True;
      C.Step_Open      := False;
      C.Footer_Pending := False;
      C.Step_Number    := 0;
      C.Text_Open      := False;
      C.Thinking_Open  := False;
      C.Completed      := False;
      C.Last_Status    := Coyote_GUI.Completed;
      Log (C, "began exchange");
   end Begin_Request;

   procedure Append_Text (C : in out Instance; Text : String) is
   begin
      if not C.Has_Exchange then
         Begin_Request (C, "", Coyote_GUI.Prompt);
      end if;
      Ensure_Active_Step (C);
      if not C.Text_Open then
         Add_Text_Element
           (C, C.Step_Box, "Response", "", C.Active_Text, C.Active_View);
         C.Text_Open := True;
      end if;
      Append_Buffer (C.Active_Text, Text);
      Append (C.Transcript, Text);
   end Append_Text;

   procedure End_Text_Block (C : in out Instance) is
   begin
      if C.Text_Open then
         Append_Buffer (C.Active_Text, ASCII.LF & ASCII.LF);
         Append (C.Transcript, ASCII.LF & ASCII.LF);
         C.Text_Open := False;
      end if;
   end End_Text_Block;

   procedure Begin_Thinking (C : in out Instance) is
   begin
      if not C.Has_Exchange then
         Begin_Request (C, "", Coyote_GUI.Prompt);
      end if;
      Ensure_Active_Step (C);
      if not C.Thinking_Open then
         Add_Text_Element
           (C, C.Step_Box, "Thinking", "", C.Thinking, C.Thinking_View);
         C.Thinking_Open := True;
      end if;
   end Begin_Thinking;

   procedure Append_Thinking (C : in out Instance; Text : String) is
   begin
      if not C.Thinking_Open then
         Begin_Thinking (C);
      end if;
      Append_Buffer (C.Thinking, Text);
      Append (C.Transcript, Text);
   end Append_Thinking;

   procedure End_Thinking (C : in out Instance) is
   begin
      if C.Thinking_Open then
         Append_Buffer (C.Thinking, ASCII.LF & ASCII.LF);
         Append (C.Transcript, ASCII.LF & ASCII.LF);
         C.Thinking_Open := False;
      end if;
   end End_Thinking;

   procedure Add_Tool_Argument
     (Grid        : not null access Gtk.Grid.Gtk_Grid_Record'Class;
      Row         : Glib.Gint;
      Field_Name  : String;
      Field_Value : String)
   is
      Key   : Gtk.Label.Gtk_Label;
      Value : Gtk.Label.Gtk_Label;
   begin
      Gtk.Label.Gtk_New (Key, Field_Name);
      Key.Set_Xalign (0.0);
      Grid.Attach (Key, 0, Row);

      Gtk.Label.Gtk_New (Value, Field_Value);
      Value.Set_Xalign (0.0);
      Value.Set_Line_Wrap (True);
      Value.Set_Max_Width_Chars (80);
      Value.Set_Selectable (True);
      Grid.Attach (Value, 1, Row);
   end Add_Tool_Argument;

   procedure Begin_Tool
     (C               : in out Instance;
      Name            : String;
      Args            : String;
      Session_Id      : String;
      Tool_Id         : String;
      Model           : String := "";
      Source_Directory : String := "";
      Session_Start   : String := "";
      Turn_Index      : Positive := 1;
      Call_In_Turn    : Positive := 1)
   is
      Frame        : Gtk.Frame.Gtk_Frame;
      Box          : Gtk.Box.Gtk_Box;
      Header       : Gtk.Label.Gtk_Label;
      Status       : Gtk.Label.Gtk_Label;
      Arguments    : Gtk.Grid.Gtk_Grid;
      Details      : Gtk.Button.Gtk_Button;
      Info         : Coyote_GUI.Conversation.Tool_Info;
      Summary_Text : constant String :=
        Format_Tool_Summary
          (Name, Args, Coyote_GUI.Success, "", Running => True);
   begin
      if not C.Has_Exchange then
         Begin_Request (C, "", Coyote_GUI.Prompt);
      end if;
      Ensure_Active_Step (C);
      if C.Tools.Contains (Tool_Id) then
         return;
      end if;

      Info.Name             := To_Unbounded_String (Name);
      Info.Args             := To_Unbounded_String (Args);
      Info.Model            := To_Unbounded_String (Model);
      Info.Source_Directory := To_Unbounded_String (Source_Directory);
      Info.Session_Start    := To_Unbounded_String (Session_Start);
      Info.Turn_Index       := Turn_Index;
      Info.Call_In_Turn     := Call_In_Turn;

      Gtk.Frame.Gtk_New (Frame, "Tool call");
      Gtk.Box.Gtk_New_Vbox (Box, Homogeneous => False, Spacing => 4);
      Box.Set_Border_Width (6);
      Frame.Add (Box);

      Gtk.Label.Gtk_New (Header, Name);
      Header.Set_Xalign (0.0);
      Box.Pack_Start (Header, Expand => False, Fill => False, Padding => 0);

      Gtk.Label.Gtk_New
        (Status, "Status: "
         & Tool_Status_Text
             (Coyote_GUI.Success, "", Running => True));
      Status.Set_Xalign (0.0);
      Box.Pack_Start (Status, Expand => False, Fill => False, Padding => 0);

      Gtk.Grid.Gtk_New (Arguments);
      Arguments.Set_Column_Spacing (12);
      Arguments.Set_Row_Spacing (3);
      declare
         use type GNATCOLL.JSON.JSON_Value_Type;
         Parsed : constant GNATCOLL.JSON.Read_Result :=
           GNATCOLL.JSON.Read (Args);
         Args_Val : constant GNATCOLL.JSON.JSON_Value :=
           (if Parsed.Success
            then Parsed.Value
            else GNATCOLL.JSON.JSON_Null);
         Row : Glib.Gint := 0;
      begin
         if Args_Val.Kind = GNATCOLL.JSON.JSON_Object_Type then
            declare
               procedure Add_Argument
                 (Field_Name  : GNATCOLL.JSON.UTF8_String;
                  Field_Value : GNATCOLL.JSON.JSON_Value)
               is
               begin
                  Add_Tool_Argument
                    (Arguments.all'Access,
                     Row,
                     String (Field_Name),
                     Compact_Tool_Value (JSON_Scalar_Image (Field_Value)));
                  Row := Row + 1;
               end Add_Argument;
            begin
               Args_Val.Map_JSON_Object (Add_Argument'Access);
            end;
         end if;
         if Row > 0 then
            Box.Pack_Start
              (Arguments, Expand => False, Fill => True, Padding => 0);
         end if;
      end;

      Gtk.Button.Gtk_New (Details, "View Details");
      Details.Set_Can_Focus (True);
      Details.Set_Sensitive (False);
      Details.Set_Tooltip_Text ("View complete tool call details");
      Detail_Callback.Connect
        (Details,
         Gtk.Button.Signal_Clicked,
         On_Detail_Clicked'Access,
         (Stack   => C'Unchecked_Access,
          Tool_Id => To_Unbounded_String (Tool_Id)));
      Box.Pack_Start (Details, Expand => False, Fill => False, Padding => 0);
      C.Step_Box.Pack_Start (Frame, Expand => False, Fill => True, Padding => 4);
      Show_Contents (C);
      C.Tools.Insert
        (Tool_Id,
         (Summary_Text => To_Unbounded_String (Summary_Text),
          Status       => Status,
          Details      => Details,
          Info         => Info,
          Completed    => False));
      Append (C.Transcript, ASCII.LF & Summary_Text & ASCII.LF);
   end Begin_Tool;

   procedure End_Tool
     (C          : in out Instance;
      Tool_Id    : String;
      Status     : Coyote_GUI.Tool_End_Status;
      Result     : String;
      Media_Type : String := "")
   is
      Tool_Value : Tool_Entry;
   begin
      if not C.Tools.Contains (Tool_Id) then
         return;
      end if;
      Tool_Value := C.Tools.Element (Tool_Id);
      Tool_Value.Info.Result_Text   := To_Unbounded_String (Result);
      Tool_Value.Info.Media_Type    := To_Unbounded_String (Media_Type);
      Tool_Value.Info.Result_Status :=
        Coyote_GUI.Conversation.Tool_End_Status'Val
          (Coyote_GUI.Tool_End_Status'Pos (Status));
      Tool_Value.Summary_Text :=
        To_Unbounded_String
          (Format_Tool_Summary
             (To_String (Tool_Value.Info.Name),
              To_String (Tool_Value.Info.Args),
              Status,
              Result,
              Running => False));
      Tool_Value.Status.Set_Text
        ("Status: "
         & Tool_Status_Text (Status, Result, Running => False));
      Tool_Value.Details.Set_Sensitive (True);
      Tool_Value.Completed := True;
      C.Tools.Replace (Tool_Id, Tool_Value);
      Append
        (C.Transcript,
         (case Status is
             when Coyote_GUI.Success   => "ok",
             when Coyote_GUI.Error     => "error",
             when Coyote_GUI.Cancelled => "cancelled")
         & ASCII.LF);
   end End_Tool;

   procedure Append_Notice
     (C    : in out Instance;
      Kind : Coyote_GUI.Notice_Kind;
      Text : String)
   is
      Label : Gtk.Label.Gtk_Label;
      Prefix : constant String :=
        (case Kind is
            when Coyote_GUI.Info    => "Info: ",
            when Coyote_GUI.Warning => "Warning: ",
            when Coyote_GUI.Error   => "Error: ");
   begin
      if not C.Has_Exchange then
         Begin_Request (C, "", Coyote_GUI.Prompt);
      end if;
      Gtk.Label.Gtk_New (Label, Prefix & Text);
      Label.Set_Xalign (0.0);
      Label.Set_Line_Wrap (True);
      Label.Set_Selectable (True);
      C.Exchange.Pack_Start (Label, Expand => False, Fill => True, Padding => 2);
      Show_Contents (C);
      Append (C.Transcript, Prefix & Text & ASCII.LF);
   end Append_Notice;

   procedure Append_Turn_Footer
     (C       : in out Instance;
      Text    : String;
      Kind    : Coyote_GUI.Footer_Kind;
      Summary : String := "")
   is
      Footer_Box : Gtk.Box.Gtk_Box;
      Prefix     : constant String :=
        (if Kind = Coyote_GUI.Step_Footer then "Step " else "Turn ");
   begin
      if not C.Has_Exchange then
         return;
      end if;
      Ensure_Active_Step (C);

      Gtk.Box.Gtk_New_Vbox (Footer_Box, Homogeneous => False, Spacing => 4);
      Footer_Box.Set_Border_Width (4);
      Gtk.Separator.Gtk_New_Hseparator (C.Footer_Separator);
      Footer_Box.Pack_Start
        (C.Footer_Separator, Expand => False, Fill => True, Padding => 0);

      Gtk.Label.Gtk_New (C.Footer_Label, Summary);
      C.Footer_Label.Set_Xalign (0.0);
      C.Footer_Label.Set_Line_Wrap (True);
      C.Footer_Label.Set_Selectable (False);
      C.Footer_Label.Set_Tooltip_Text
        ("Token, context, cost, and completion information for " & Prefix
         & Natural_Image (C.Step_Number));
      Footer_Box.Pack_Start
        (C.Footer_Label, Expand => False, Fill => True, Padding => 0);
      C.Step_Box.Pack_Start
        (Footer_Box, Expand => False, Fill => True, Padding => 2);
      Show_Contents (C);
      Append (C.Transcript, (if Summary'Length > 0 then Summary else Text)
              & ASCII.LF);
      C.Footer_Pending := True;
   end Append_Turn_Footer;

   procedure Append_Fork_Action
     (C       : in out Instance;
      Label   : String;
      UUID    : String;
      Turn_N  : Positive;
      Step_N  : Natural)
   is
      pragma Unreferenced (Label);
      Action_Box : Gtk.Box.Gtk_Box;
      Point      : Gtk.Label.Gtk_Label;
   begin
      if not C.Has_Exchange or else not C.Step_Open then
         return;
      end if;
      Gtk.Box.Gtk_New_Hbox (Action_Box, Homogeneous => False, Spacing => 6);
      Gtk.Label.Gtk_New
        (Point, "Fork point: turn " & Natural_Image (Turn_N)
         & (if Step_N > 0
            then ", step " & Natural_Image (Step_N)
            else ""));
      Point.Set_Xalign (0.0);
      Action_Box.Pack_Start
        (Point, Expand => True, Fill => True, Padding => 0);
      Gtk.Button.Gtk_New (C.Fork_Button, "Fork");
      C.Fork_Button.Set_Can_Focus (True);
      C.Fork_Button.Set_Tooltip_Text
        ("Create a new session from turn " & Natural_Image (Turn_N)
         & (if Step_N > 0 then ", step " & Natural_Image (Step_N) else ""));
      Fork_Callback.Connect
        (C.Fork_Button,
         Gtk.Button.Signal_Clicked,
         On_Fork_Clicked'Access,
         (Handler => C.Fork_Callback,
          UUID    => To_Unbounded_String (UUID),
          Turn_N  => Turn_N,
          Step_N  => Step_N));
      Action_Box.Pack_End
        (C.Fork_Button, Expand => False, Fill => False, Padding => 0);
      C.Step_Box.Pack_Start
        (Action_Box, Expand => False, Fill => True, Padding => 0);
      Show_Contents (C);
      Append (C.Transcript, "Fork" & ASCII.LF);
      if C.Footer_Pending then
         Finalize_Active_Step (C);
      end if;
   end Append_Fork_Action;

   procedure Complete_Request
     (C      : in out Instance;
      Status : Coyote_GUI.Completion_Status)
   is
      Text : constant String :=
        (case Status is
            when Coyote_GUI.Completed => "completed",
            when Coyote_GUI.Aborted   => "aborted",
            when Coyote_GUI.Failed    => "failed");
   begin
      if not C.Has_Exchange or else C.Completed then
         return;
      end if;
      --  The footer and lifecycle status area already carry normal completion
      --  currency; do not append a second standalone status widget.
      Append (C.Transcript, Text & ASCII.LF);
      C.Last_Status := Status;
      C.Completed := True;
      Finalize_Active_Step (C);
   end Complete_Request;

   function Transcript_Text (C : Instance) return String is
   begin
      return To_String (C.Transcript);
   end Transcript_Text;

   function Tool_Summary
     (C       : Instance;
      Tool_Id : String) return String
   is
      Tool_Value : Tool_Entry;
   begin
      if not C.Tools.Contains (Tool_Id) then
         return "";
      end if;
      Tool_Value := C.Tools.Element (Tool_Id);
      return To_String (Tool_Value.Summary_Text);
   end Tool_Summary;

   function Tool_Detail
     (C       : Instance;
      Tool_Id : String) return Coyote_GUI.Conversation.Tool_Info
   is
      Tool_Value : Tool_Entry;
   begin
      if C.Tools.Contains (Tool_Id) then
         Tool_Value := C.Tools.Element (Tool_Id);
         return Tool_Value.Info;
      end if;
      return (others => <>);
   end Tool_Detail;

   procedure Scroll_To_End (C : in out Instance) is
   begin
      if C.Scroll = null then
         return;
      end if;
      declare
         Adjustment : constant Gtk.Adjustment.Gtk_Adjustment :=
           C.Scroll.Get_Vadjustment;
      begin
         Adjustment.Set_Value
           (Gdouble'Max
              (Adjustment.Get_Upper - Adjustment.Get_Page_Size, 0.0));
      end;
   end Scroll_To_End;

   function Has_Selection (C : Instance) return Boolean is
   begin
      return C.Active_Text /= null
        and then C.Active_Text.Get_Has_Selection;
   end Has_Selection;

   procedure Copy_Selection (C : in out Instance) is
   begin
      if Has_Selection (C) then
         C.Active_Text.Copy_Clipboard (Gtk.Clipboard.Get);
      end if;
   end Copy_Selection;

   procedure Select_All (C : in out Instance) is
      Start_Iter : Gtk.Text_Iter.Gtk_Text_Iter;
      End_Iter   : Gtk.Text_Iter.Gtk_Text_Iter;
   begin
      if C.Active_Text = null then
         return;
      end if;
      C.Active_Text.Get_Start_Iter (Start_Iter);
      C.Active_Text.Get_End_Iter (End_Iter);
      C.Active_Text.Select_Range (Start_Iter, End_Iter);
   end Select_All;

   procedure Clear_Selection (C : in out Instance) is
      Insert_Iter : Gtk.Text_Iter.Gtk_Text_Iter;
   begin
      if C.Active_Text = null then
         return;
      end if;
      C.Active_Text.Get_Iter_At_Mark
        (Insert_Iter, C.Active_Text.Get_Insert);
      C.Active_Text.Place_Cursor (Insert_Iter);
   end Clear_Selection;

   procedure Set_Font
     (C    : in out Instance;
      Desc : Pango.Font.Pango_Font_Description)
   is
   begin
      if C.Active_View /= null then
         C.Active_View.Modify_Font (Desc);
      end if;
      if C.Thinking_View /= null then
         C.Thinking_View.Modify_Font (Desc);
      end if;
   end Set_Font;

   procedure Set_Debug_Logging (C : in out Instance; Enabled : Boolean) is
   begin
      C.Debug_Logging := Enabled;
   end Set_Debug_Logging;

end Coyote_GUI.Conversation_Stack;
