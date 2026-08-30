--  Coyote_App.Frontend.Plain body.
--
--  Project: coyote

with Ada.Text_IO;
with Coyote_App.Utils; use Coyote_App.Utils;

package body Coyote_App.Frontend.Plain is

   procedure Put
     (F    : in out Instance;
      Text : in     String)
   is
   begin
      if F.To_Standard_Error then
         Ada.Text_IO.Put (Ada.Text_IO.Standard_Error, Text);
      else
         Ada.Text_IO.Put (Text);
      end if;
   end Put;

   procedure Put_Line
     (F    : in out Instance;
      Text : in     String)
   is
   begin
      Put (F, Text & ASCII.LF);
   end Put_Line;

   procedure Create
     (F        : in out Instance;
      One_Shot : in Boolean := False)
   is
   begin
      F.To_Standard_Error := One_Shot;
      F.Thinking_Started := False;
      F.Text_Started := False;
   end Create;

   overriding
   procedure Set_Status
     (F    : in out Instance;
      Text : in     String)
   is
   begin
      Put_Line (F, UC_BULLET & " " & Text);
   end Set_Status;

   overriding
   procedure Set_Mode
     (F    : in out Instance;
      Mode : in     Coyote_App.Frontend.Run_Mode)
   is
      pragma Unreferenced (F, Mode);
   begin
      null;
   end Set_Mode;

   overriding
   procedure Begin_Request
     (F    : in out Instance;
      Text : in     String;
      Kind : in     Coyote_App.Frontend.Request_Kind :=
        Coyote_App.Frontend.Prompt)
   is
      Label : constant String :=
        (if Kind = Coyote_App.Frontend.Steer then "steer" else "prompt");
   begin
      Put_Line (F, UC_TRI_R & " " & Label & ": " & Text);
   end Begin_Request;

   overriding
   procedure Append_Text
     (F    : in out Instance;
      Text : in     String)
   is
   begin
      F.Text_Started := True;
      Put (F, Text);
   end Append_Text;

   overriding
   procedure End_Text_Block (F : in out Instance) is
   begin
      if F.Text_Started then
         Put (F, "" & ASCII.LF);
         F.Text_Started := False;
      end if;
   end End_Text_Block;

   overriding
   procedure Begin_Thinking (F : in out Instance) is
   begin
      if F.Thinking_Started then
         Put (F, "" & ASCII.LF);
      end if;
      Put (F, "[thinking] ");
      F.Thinking_Started := True;
   end Begin_Thinking;

   overriding
   procedure Append_Thinking
     (F    : in out Instance;
      Text : in     String)
   is
   begin
      Put (F, Text);
   end Append_Thinking;

   overriding
   procedure End_Thinking (F : in out Instance) is
   begin
      if F.Thinking_Started then
         Put (F, "" & ASCII.LF);
         F.Thinking_Started := False;
      end if;
   end End_Thinking;

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
      Call_In_Turn    : in     Positive := 1)
   is
      pragma Unreferenced
        (Session_Id, Tool_Id, Model, Source_Directory, Session_Start,
         Turn_Index, Call_In_Turn);
   begin
      Put_Line (F, "[tool] " & Name & " " & Args_Json);
   end Begin_Tool;

   overriding
   procedure End_Tool
     (F           : in out Instance;
      Tool_Id     : in     String;
      Status      : in     Coyote_App.Frontend.Tool_End_Status;
      Result_Text : in     String := "";
      Media_Type  : in     String := "")
   is
      pragma Unreferenced (Tool_Id, Media_Type);
      Label : constant String :=
        (case Status is
            when Coyote_App.Frontend.Success   => "ok",
            when Coyote_App.Frontend.Error     => "error",
            when Coyote_App.Frontend.Cancelled => "cancelled");
   begin
      Put_Line (F, "[tool " & Label & "]");
      if Status = Coyote_App.Frontend.Error
        and then Result_Text'Length > 0
      then
         Put_Line (F, Result_Text);
      end if;
   end End_Tool;

   overriding
   procedure Append_Turn_Footer
     (F       : in out Instance;
      Text    : in     String;
      Kind    : in     Coyote_App.Frontend.Footer_Kind :=
        Coyote_App.Frontend.Final_Footer;
      Summary : in     String := "")
   is
      pragma Unreferenced (Summary);
      Label : constant String :=
        (if Kind = Coyote_App.Frontend.Step_Footer
         then "[step] "
         else "[turn] ");
   begin
      Put_Line (F, Label & Text);
   end Append_Turn_Footer;

   overriding
   procedure Complete_Request
     (F      : in out Instance;
      Status : in     Coyote_App.Frontend.Completion_Status)
   is
      pragma Unreferenced (Status);
   begin
      End_Thinking (F);
      End_Text_Block (F);
   end Complete_Request;

   overriding
   procedure Append_Fork_Action
     (F       : in out Instance;
      UUID    : in     String;
      Turn_N  : in     Positive;
      Step_N  : in     Natural := 0)
   is
      pragma Unreferenced (UUID, Turn_N, Step_N);
   begin
      null;
   end Append_Fork_Action;

   overriding
   procedure Append_Notice
     (F    : in out Instance;
      Kind : in     Coyote_App.Frontend.Notice_Kind;
      Text : in     String)
   is
      Label : constant String :=
        (case Kind is
            when Coyote_App.Frontend.Info    => "info",
            when Coyote_App.Frontend.Warning => "warning",
            when Coyote_App.Frontend.Error   => "error");
   begin
      Put_Line (F, "[" & Label & "] " & Text);
   end Append_Notice;

   overriding
   procedure Show_Detail
     (F       : in out Instance;
      Title   : in     String;
      Content : in     String)
   is
   begin
      Put_Line (F, "[" & Title & "]");
      Put_Line (F, Content);
   end Show_Detail;

   overriding
   function Read_Prompt (F : in out Instance) return String is
      pragma Unreferenced (F);
   begin
      if Ada.Text_IO.End_Of_File then
         return "";
      end if;
      return Ada.Text_IO.Get_Line;
   end Read_Prompt;

   overriding
   procedure Shutdown (F : in out Instance) is
   begin
      End_Thinking (F);
      End_Text_Block (F);
   end Shutdown;

end Coyote_App.Frontend.Plain;
