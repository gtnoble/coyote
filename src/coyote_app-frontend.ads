--  Coyote_App.Frontend — abstract frontend interface.
--
--  All rendering of LLM agent events is routed through this interface.
--  Concrete implementations are the GTK graphical and Plain line-oriented
--  frontends.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded;

package Coyote_App.Frontend is

   type Instance is abstract tagged limited null record;

   type Control_Command_Kind is
     (Control_Stop,
      Control_Pause,
      Control_Resume,
      Control_Set_Sandbox,
      Control_Shutdown);

   type Control_Command is record
      Kind           : Control_Command_Kind := Control_Stop;
      Sandbox_Profile : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   function Has_Control_Channel (F : Instance) return Boolean is (False);
   function Read_Control
     (F       : in out Instance;
      Command : out Control_Command) return Boolean is (False);

   type Instance_Access is access all Instance'Class;

   --  Update the persistent one-line status display in the GUI.  Text is
   --  already formatted by Coyote_App.Dispatch.Format_Status.
   procedure Set_Status
     (F    : in out Instance;
      Text :      String) is abstract;

   type Run_Mode is (Idle, Running, Armed, Paused);

   --  Reflect the current agent lifecycle phase in the frontend.
   procedure Set_Mode
     (F    : in out Instance;
      Mode :      Run_Mode) is abstract;

   type Request_Kind is (Prompt, Steer);

   --  Identify the semantic start of a submitted request.
   procedure Begin_Request
     (F    : in out Instance;
      Text :      String;
      Kind :      Request_Kind := Prompt) is null;

   --  Stream assistant text. A complete block ends at End_Text_Block.
   procedure Append_Text
     (F    : in out Instance;
      Text :      String) is abstract;

   procedure End_Text_Block (F : in out Instance) is abstract;

   --  Stream a thinking block as flowing frontend text.
   procedure Begin_Thinking   (F : in out Instance) is abstract;

   procedure Append_Thinking
     (F    : in out Instance;
      Text :      String) is abstract;

   procedure End_Thinking     (F : in out Instance) is abstract;

   --  Tool execution lifecycle. Session_Id and Tool_Id identify the tool
   --  segment for replay and detail presentation.
   type Tool_End_Status is (Success, Error, Cancelled);

   procedure Begin_Tool
     (F               : in out Instance;
      Name            :      String;
      Args_Json       :      String;
      Session_Id      :      String;
      Tool_Id         :      String;
      Model           :      String := "";
      Source_Directory :      String := "";
      Session_Start   :      String := "";
      Turn_Index      :      Positive := 1;
      Call_In_Turn    :      Positive := 1) is abstract;

   procedure End_Tool
     (F           : in out Instance;
      Tool_Id     :      String;
      Status      :      Tool_End_Status;
      Result_Text :      String := "";
      Media_Type  :      String := "") is abstract;

   type Footer_Kind is (Step_Footer, Final_Footer);

   --  Append a formatted turn footer.
   procedure Append_Turn_Footer
     (F       : in out Instance;
      Text    :      String;
      Kind    :      Footer_Kind := Final_Footer;
      Summary :      String := "") is abstract;

   type Completion_Status is (Completed, Aborted, Failed);

   --  Explicitly close the active request.
   procedure Complete_Request
     (F      : in out Instance;
      Status :      Completion_Status) is null;

   --  Append a frontend-specific fork action. Plain implementations may
   --  ignore this action; the GUI presents it as a clickable control.
   procedure Append_Fork_Action
     (F       : in out Instance;
      UUID    :      String;
      Turn_N  :      Positive;
      Step_N  :      Natural := 0) is abstract;

   type Notice_Kind is (Info, Warning, Error);

   --  Append a system notice outside the assistant message stream.
   procedure Append_Notice
     (F    : in out Instance;
      Kind :      Notice_Kind;
      Text :      String) is abstract;

   --  Show a named block of content outside the main conversation view.
   procedure Show_Detail
     (F       : in out Instance;
      Title   :      String;
      Content :      String) is abstract;

   --  Return the next prompt, or "" when the frontend is closed.
   function Read_Prompt
     (F : in out Instance) return String is abstract;

   --  Signal the frontend to close and release resources.
   procedure Shutdown (F : in out Instance) is abstract;

end Coyote_App.Frontend;
