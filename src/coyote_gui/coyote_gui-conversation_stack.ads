--  Coyote_GUI.Conversation_Stack — native GTK conversation presentation.
--
--  Owns one outer scrolled window and one vertical exchange host.  All
--  operations are called from the GTK main-loop thread.
--
--  Project: coyote

with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Vectors;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded;
with Coyote_GUI;
with Coyote_GUI.Conversation;
with Gtk.Box;
with Gtk.Frame;
with Gtk.Button;
with Gtk.Label;
with Gtk.Scrolled_Window;
with Gtk.Separator;
with Gtk.Text_Buffer;
with Gtk.Text_View;
with Gtk.Window;
with Pango.Font;

package Coyote_GUI.Conversation_Stack is

   use type Gtk.Box.Gtk_Box;
   use type Gtk.Frame.Gtk_Frame;

   type Instance is tagged limited private;

   procedure Create
     (C           : in out Instance;
      Main_Window : not null access Gtk.Window.Gtk_Window_Record'Class);
   function Widget (C : Instance)
     return Gtk.Scrolled_Window.Gtk_Scrolled_Window;
   procedure Clear (C : in out Instance);

   --  Callback invoked by a native Fork button on the GTK main-loop thread.
   type Fork_Handler is access procedure
     (UUID   : String;
      Turn_N : Positive;
      Step_N : Natural);

   --  Register the callback used by native fork buttons.
   procedure Set_Fork_Handler
     (C       : in out Instance;
      Handler : Fork_Handler);

   procedure Begin_Request
     (C    : in out Instance;
      Text : String;
      Kind : Coyote_GUI.Request_Kind);

   procedure Append_Text (C : in out Instance; Text : String);
   procedure End_Text_Block (C : in out Instance);
   procedure Begin_Thinking (C : in out Instance);
   procedure Append_Thinking (C : in out Instance; Text : String);
   procedure End_Thinking (C : in out Instance);

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
      Call_In_Turn    : Positive := 1);

   procedure End_Tool
     (C          : in out Instance;
      Tool_Id    : String;
      Status     : Coyote_GUI.Tool_End_Status;
      Result     : String;
      Media_Type : String := "");

   procedure Append_Notice
     (C    : in out Instance;
      Kind : Coyote_GUI.Notice_Kind;
      Text : String);

   --  Text is retained for the accessibility transcript and Summary is the
   --  typed status text used by the native footer label.
   procedure Append_Turn_Footer
     (C       : in out Instance;
      Text    : String;
      Kind    : Coyote_GUI.Footer_Kind;
      Summary : String := "");

   procedure Append_Fork_Action
     (C       : in out Instance;
      Label   : String;
      UUID    : String;
      Turn_N  : Positive;
      Step_N  : Natural);

   procedure Complete_Request
     (C      : in out Instance;
      Status : Coyote_GUI.Completion_Status);

   function Transcript_Text (C : Instance) return String;

   --  Return the compact summary rendered for Tool_Id.
   function Tool_Summary
     (C       : Instance;
      Tool_Id : String) return String;

   --  Return the complete detail payload retained for Tool_Id.
   function Tool_Detail
     (C       : Instance;
      Tool_Id : String) return Coyote_GUI.Conversation.Tool_Info;

   --  Keep the active exchange at the bottom of the outer host.
   procedure Scroll_To_End (C : in out Instance);

   function Has_Selection (C : Instance) return Boolean;
   procedure Copy_Selection (C : in out Instance);
   procedure Select_All (C : in out Instance);
   procedure Clear_Selection (C : in out Instance);

   procedure Set_Font
     (C    : in out Instance;
      Desc : Pango.Font.Pango_Font_Description);

   procedure Set_Debug_Logging (C : in out Instance; Enabled : Boolean);

private

   type Tool_Entry is record
      Summary_Text : Ada.Strings.Unbounded.Unbounded_String;
      Status       : Gtk.Label.Gtk_Label;
      Details      : Gtk.Button.Gtk_Button;
      Info         : Coyote_GUI.Conversation.Tool_Info;
      Completed    : Boolean := False;
   end record;

   package Tool_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Tool_Entry,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   package Exchange_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Gtk.Box.Gtk_Box);

   package Frame_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Gtk.Frame.Gtk_Frame);

   type Instance is tagged limited record
      Scroll            : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Main_Window       : Gtk.Window.Gtk_Window;
      Host              : Gtk.Box.Gtk_Box;
      Exchange          : Gtk.Box.Gtk_Box;
      Exchanges         : Exchange_Vectors.Vector;
      Step_Frame        : Gtk.Frame.Gtk_Frame;
      Step_Box          : Gtk.Box.Gtk_Box;
      Step_Frames       : Frame_Vectors.Vector;
      Active_Text       : Gtk.Text_Buffer.Gtk_Text_Buffer;
      Active_View       : Gtk.Text_View.Gtk_Text_View;
      Thinking          : Gtk.Text_Buffer.Gtk_Text_Buffer;
      Thinking_View     : Gtk.Text_View.Gtk_Text_View;
      Tools             : Tool_Maps.Map;
      Transcript        : Ada.Strings.Unbounded.Unbounded_String;
      Has_Exchange      : Boolean := False;
      Step_Open         : Boolean := False;
      Footer_Pending    : Boolean := False;
      Step_Number       : Natural := 0;
      Text_Open         : Boolean := False;
      Thinking_Open     : Boolean := False;
      Completed         : Boolean := False;
      Last_Status       : Coyote_GUI.Completion_Status := Coyote_GUI.Completed;
      Debug_Logging     : Boolean := False;
      Fork_Callback     : Fork_Handler;
      Footer_Separator  : Gtk.Separator.Gtk_Separator;
      Footer_Label      : Gtk.Label.Gtk_Label;
      Fork_Button       : Gtk.Button.Gtk_Button;
   end record;
end Coyote_GUI.Conversation_Stack;
