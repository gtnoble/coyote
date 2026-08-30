--  Coyote_App.Frontend.Plain — line-oriented headless frontend.
--
--  The Plain frontend writes conversation output to standard output during
--  interactive execution.  One-shot execution sends presentation output to
--  standard error so that the final JSON result remains the only standard
--  output record.
--
--  Project: coyote

with Coyote_App.Frontend;

package Coyote_App.Frontend.Plain is

   type Instance is new Coyote_App.Frontend.Instance with private;

   --  Initialise the output mode.  When One_Shot is true, presentation
   --  output is written to standard error rather than standard output.
   procedure Create
     (F        : in out Instance;
      One_Shot : in Boolean := False);

   overriding
   procedure Set_Status
     (F    : in out Instance;
      Text : in     String);

   overriding
   procedure Set_Mode
     (F    : in out Instance;
      Mode : in     Coyote_App.Frontend.Run_Mode);

   overriding
   procedure Begin_Request
     (F    : in out Instance;
      Text : in     String;
      Kind : in     Coyote_App.Frontend.Request_Kind :=
        Coyote_App.Frontend.Prompt);

   overriding
   procedure Append_Text
     (F    : in out Instance;
      Text : in     String);

   overriding
   procedure End_Text_Block (F : in out Instance);

   overriding
   procedure Begin_Thinking (F : in out Instance);

   overriding
   procedure Append_Thinking
     (F    : in out Instance;
      Text : in     String);

   overriding
   procedure End_Thinking (F : in out Instance);

   overriding
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
      Call_In_Turn    : in     Positive := 1);

   overriding
   procedure End_Tool
     (F           : in out Instance;
      Tool_Id     : in     String;
      Status      : in     Coyote_App.Frontend.Tool_End_Status;
      Result_Text : in     String := "";
      Media_Type  : in     String := "");

   overriding
   procedure Append_Turn_Footer
     (F       : in out Instance;
      Text    : in     String;
      Kind    : in     Coyote_App.Frontend.Footer_Kind :=
        Coyote_App.Frontend.Final_Footer;
      Summary : in     String := "");

   overriding
   procedure Complete_Request
     (F      : in out Instance;
      Status : in     Coyote_App.Frontend.Completion_Status);

   overriding
   procedure Append_Fork_Action
     (F       : in out Instance;
      UUID    : in     String;
      Turn_N  : in     Positive;
      Step_N  : in     Natural := 0);

   overriding
   procedure Append_Notice
     (F    : in out Instance;
      Kind : in     Coyote_App.Frontend.Notice_Kind;
      Text : in     String);

   overriding
   procedure Show_Detail
     (F       : in out Instance;
      Title   : in     String;
      Content : in     String);

   overriding
   function Read_Prompt (F : in out Instance) return String;

   overriding
   procedure Shutdown (F : in out Instance);

private

   type Instance is new Coyote_App.Frontend.Instance with record
      To_Standard_Error : Boolean := False;
      Thinking_Started  : Boolean := False;
      Text_Started      : Boolean := False;
   end record;

end Coyote_App.Frontend.Plain;
