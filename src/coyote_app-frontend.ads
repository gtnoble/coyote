--  Coyote_App.Frontend — abstract frontend interface.
--
--  All rendering of LLM agent events is routed through this interface.
--  Concrete implementations are the GTK graphical and Plain line-oriented
--  frontends.
--
--  Project: coyote
--  For revision history, see the project version-control log.

package Coyote_App.Frontend is

   type Instance is abstract tagged limited null record;
   type Instance_Access is access all Instance'Class;

   --  Update the persistent one-line status display in the GUI.  Text is
   --  already formatted by Coyote_App.Dispatch.Format_Status.
   procedure Set_Status
     (F    : in out Instance;
      Text : in     String) is abstract;

   type Run_Mode is (Idle, Running, Armed, Paused);

   --  Reflect the current agent lifecycle phase in the frontend.
   procedure Set_Mode
     (F    : in out Instance;
      Mode : in     Run_Mode) is abstract;

   type Request_Kind is (Prompt, Steer);

   --  Identify the semantic start of a submitted request.
   procedure Begin_Request
     (F    : in out Instance;
      Text : in     String;
      Kind : in     Request_Kind := Prompt) is null;

   --  Stream assistant text. A complete block ends at End_Text_Block.
   procedure Append_Text
     (F    : in out Instance;
      Text : in     String) is abstract;

   procedure End_Text_Block (F : in out Instance) is abstract;

   --  Stream a thinking block as flowing frontend text.
   procedure Begin_Thinking   (F : in out Instance) is abstract;

   procedure Append_Thinking
     (F    : in out Instance;
      Text : in     String) is abstract;

   procedure End_Thinking     (F : in out Instance) is abstract;

   --  Tool execution lifecycle. Session_Id and Tool_Id identify the tool
   --  segment for replay and detail presentation.
   type Tool_End_Status is (Success, Error, Cancelled);

   procedure Begin_Tool
     (F               : in out Instance;
      Name            : in     String;
      Args_Json       : in     String;
      Session_Id      : in     String;
      Tool_Id         : in     String;
      Model           : in     String := "";
      Source_Directory : in     String := "";
      Session_Start   : in     String := "";
      Turn_Index      : in     Positive := 1;
      Call_In_Turn    : in     Positive := 1) is abstract;

   procedure End_Tool
     (F           : in out Instance;
      Tool_Id     : in     String;
      Status      : in     Tool_End_Status;
      Result_Text : in     String := "";
      Media_Type  : in     String := "") is abstract;

   type Footer_Kind is (Step_Footer, Final_Footer);

   --  Append a formatted turn footer.
   procedure Append_Turn_Footer
     (F       : in out Instance;
      Text    : in     String;
      Kind    : in     Footer_Kind := Final_Footer;
      Summary : in     String := "") is abstract;

   type Completion_Status is (Completed, Aborted, Failed);

   --  Explicitly close the active request.
   procedure Complete_Request
     (F      : in out Instance;
      Status : in     Completion_Status) is null;

   --  Append a frontend-specific fork action. Plain implementations may
   --  ignore this action; the GUI presents it as a clickable control.
   procedure Append_Fork_Action
     (F       : in out Instance;
      UUID    : in     String;
      Turn_N  : in     Positive;
      Step_N  : in     Natural := 0) is abstract;

   type Notice_Kind is (Info, Warning, Error);

   --  Append a system notice outside the assistant message stream.
   procedure Append_Notice
     (F    : in out Instance;
      Kind : in     Notice_Kind;
      Text : in     String) is abstract;

   --  Show a named block of content outside the main conversation view.
   procedure Show_Detail
     (F       : in out Instance;
      Title   : in     String;
      Content : in     String) is abstract;

   --  Return the next prompt, or "" when the frontend is closed.
   function Read_Prompt
     (F : in out Instance) return String is abstract;

   --  Signal the frontend to close and release resources.
   procedure Shutdown (F : in out Instance) is abstract;

end Coyote_App.Frontend;
