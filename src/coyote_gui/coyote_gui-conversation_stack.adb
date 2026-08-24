--  Coyote_GUI.Conversation_Stack body.
--
--  Project: coyote

with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Ada.Text_IO;
with Coyote_App.Utils;       use Coyote_App.Utils;
with Coyote_GUI;
with Glib;                   use Glib;
with Gtk.Adjustment;
with Gtk.Box;
with Gtk.Button;
with Gtk.Clipboard;
with Gtk.Enums;
with Gtk.Frame;
with Gtk.Label;
with Gtk.Scrolled_Window;
with Gtk.Text_Buffer;
with Gtk.Text_Iter;
with Gtk.Text_View;
with Pango.Font;

package body Coyote_GUI.Conversation_Stack is

   use type Gtk.Box.Gtk_Box;
   use type Gtk.Scrolled_Window.Gtk_Scrolled_Window;
   use type Gtk.Text_Buffer.Gtk_Text_Buffer;
   use type Gtk.Text_View.Gtk_Text_View;

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

   procedure Add_Text_Element
     (C       : in out Instance;
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
      C.Exchange.Pack_Start (Section, Expand => False, Fill => True, Padding => 4);
      Show_Contents (C);
   end Add_Text_Element;

   procedure Create (C : in out Instance) is
   begin
      if C.Scroll /= null then
         return;
      end if;
      Gtk.Scrolled_Window.Gtk_New (C.Scroll);
      C.Scroll.Set_Policy
        (Gtk.Enums.Policy_Never, Gtk.Enums.Policy_Automatic);
      Gtk.Box.Gtk_New_Vbox (C.Host, Homogeneous => False, Spacing => 6);
      C.Scroll.Add (C.Host);
      Log (C, "created outer scroll host");
   end Create;

   function Widget (C : Instance)
     return Gtk.Scrolled_Window.Gtk_Scrolled_Window
   is
   begin
      return C.Scroll;
   end Widget;

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
      C.Tools.Clear;
      C.Exchange       := null;
      C.Active_Text    := null;
      C.Active_View    := null;
      C.Thinking       := null;
      C.Thinking_View  := null;
      C.Transcript     := Null_Unbounded_String;
      C.Has_Exchange   := False;
      C.Text_Open      := False;
      C.Thinking_Open  := False;
      C.Completed      := False;
      C.Last_Status    := Coyote_GUI.Completed;
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
      Create (C);
      Gtk.Box.Gtk_New_Vbox (C.Exchange, Homogeneous => False, Spacing => 3);
      C.Host.Pack_Start
        (C.Exchange, Expand => False, Fill => True, Padding => 4);
      C.Exchanges.Append (C.Exchange);
      C.Tools.Clear;
      Add_Text_Element
        (C, Caption, Text, C.Active_Text, C.Active_View);
      Append (C.Transcript, Text & ASCII.LF);
      C.Has_Exchange  := True;
      C.Text_Open     := False;
      C.Thinking_Open := False;
      C.Completed     := False;
      C.Last_Status   := Coyote_GUI.Completed;
      Log (C, "began exchange");
   end Begin_Request;

   procedure Append_Text (C : in out Instance; Text : String) is
   begin
      if not C.Has_Exchange then
         Begin_Request (C, "", Coyote_GUI.Prompt);
      end if;
      if not C.Text_Open then
         Add_Text_Element (C, "Response", "", C.Active_Text, C.Active_View);
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
      if not C.Thinking_Open then
         Add_Text_Element
           (C, "Thinking", "", C.Thinking, C.Thinking_View);
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
      pragma Unreferenced
        (Session_Id, Model, Source_Directory, Session_Start,
         Turn_Index, Call_In_Turn);
      Frame       : Gtk.Frame.Gtk_Frame;
      Box         : Gtk.Box.Gtk_Box;
      Header      : Gtk.Button.Gtk_Button;
      Status      : Gtk.Label.Gtk_Label;
      Args_Buffer : Gtk.Text_Buffer.Gtk_Text_Buffer;
      Args_View   : Gtk.Text_View.Gtk_Text_View;
      Result_Buf  : Gtk.Text_Buffer.Gtk_Text_Buffer;
      Result_View : Gtk.Text_View.Gtk_Text_View;
   begin
      if not C.Has_Exchange then
         Begin_Request (C, "", Coyote_GUI.Prompt);
      end if;
      if C.Tools.Contains (Tool_Id) then
         return;
      end if;
      Gtk.Frame.Gtk_New (Frame, "Tool: " & Name);
      Gtk.Box.Gtk_New_Vbox (Box, Homogeneous => False, Spacing => 2);
      Frame.Add (Box);
      Gtk.Button.Gtk_New (Header, Name & " " & UC_ELLIP & " running");
      Header.Set_Can_Focus (True);
      Box.Pack_Start (Header, Expand => False, Fill => False, Padding => 2);
      Gtk.Label.Gtk_New (Status, "running");
      Status.Set_Xalign (0.0);
      Status.Set_Selectable (True);
      Box.Pack_Start (Status, Expand => False, Fill => False, Padding => 2);
      Gtk.Text_Buffer.Gtk_New (Args_Buffer);
      Gtk.Text_View.Gtk_New (Args_View, Args_Buffer);
      Configure_Text_View (Args_View);
      Args_Buffer.Set_Text (Args);
      Box.Pack_Start (Args_View, Expand => False, Fill => True, Padding => 2);
      Gtk.Text_Buffer.Gtk_New (Result_Buf);
      Gtk.Text_View.Gtk_New (Result_View, Result_Buf);
      Configure_Text_View (Result_View);
      Box.Pack_Start (Result_View, Expand => False, Fill => True, Padding => 2);
      C.Exchange.Pack_Start (Frame, Expand => False, Fill => True, Padding => 4);
      Show_Contents (C);
      C.Tools.Insert
        (Tool_Id,
         (Header    => Header,
          Status    => Status,
          Arguments => Args_Buffer,
          Result    => Result_Buf));
      Append (C.Transcript, ASCII.LF & "Tool: " & Name & ASCII.LF);
   end Begin_Tool;

   procedure End_Tool
     (C          : in out Instance;
      Tool_Id    : String;
      Status     : Coyote_GUI.Tool_End_Status;
      Result     : String;
      Media_Type : String := "")
   is
      pragma Unreferenced (Media_Type);
      Tool_Value : Tool_Entry;
      Label : constant String :=
        (case Status is
            when Coyote_GUI.Success   => "ok",
            when Coyote_GUI.Error     => "error",
            when Coyote_GUI.Cancelled => "cancelled");
   begin
      if not C.Tools.Contains (Tool_Id) then
         return;
      end if;
      Tool_Value := C.Tools.Element (Tool_Id);
      Tool_Value.Status.Set_Text (Label);
      Tool_Value.Header.Set_Label ("tool " & UC_ELLIP & " " & Label);
      Tool_Value.Result.Set_Text (Result);
      C.Tools.Replace (Tool_Id, Tool_Value);
      Append (C.Transcript, Label & ASCII.LF);
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
     (C    : in out Instance;
      Text : String;
      Kind : Coyote_GUI.Footer_Kind)
   is
      Label : Gtk.Label.Gtk_Label;
      Prefix : constant String :=
        (if Kind = Coyote_GUI.Step_Footer then "Step: " else "Turn: ");
   begin
      if not C.Has_Exchange then
         return;
      end if;
      Gtk.Label.Gtk_New (Label, Prefix & Text);
      Label.Set_Xalign (0.0);
      Label.Set_Selectable (True);
      C.Exchange.Pack_Start (Label, Expand => False, Fill => True, Padding => 2);
      Show_Contents (C);
      Append (C.Transcript, Prefix & Text & ASCII.LF);
   end Append_Turn_Footer;

   procedure Append_Fork_Action
     (C       : in out Instance;
      Label   : String;
      UUID    : String;
      Turn_N  : Positive;
      Step_N  : Natural)
   is
      pragma Unreferenced (UUID, Turn_N, Step_N);
      Button : Gtk.Button.Gtk_Button;
   begin
      if not C.Has_Exchange then
         return;
      end if;
      Gtk.Button.Gtk_New (Button, Label);
      Button.Set_Can_Focus (True);
      C.Exchange.Pack_Start
        (Button, Expand => False, Fill => False, Padding => 2);
      Show_Contents (C);
      Append (C.Transcript, Label & ASCII.LF);
   end Append_Fork_Action;

   procedure Complete_Request
     (C      : in out Instance;
      Status : Coyote_GUI.Completion_Status)
   is
      Label : Gtk.Label.Gtk_Label;
      Text  : constant String :=
        (case Status is
            when Coyote_GUI.Completed => "completed",
            when Coyote_GUI.Aborted   => "aborted",
            when Coyote_GUI.Failed    => "failed");
   begin
      if not C.Has_Exchange or else C.Completed then
         return;
      end if;
      Gtk.Label.Gtk_New (Label, Text);
      Label.Set_Xalign (0.0);
      Label.Set_Selectable (True);
      C.Exchange.Pack_Start
        (Label, Expand => False, Fill => False, Padding => 2);
      Show_Contents (C);
      Append (C.Transcript, Text & ASCII.LF);
      C.Last_Status := Status;
      C.Completed := True;
      C.Text_Open := False;
      C.Thinking_Open := False;
   end Complete_Request;

   function Transcript_Text (C : Instance) return String is
   begin
      return To_String (C.Transcript);
   end Transcript_Text;

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
