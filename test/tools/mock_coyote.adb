--  mock_coyote — Test double for the real coyote binary.
--
--  Accepts the same subset of flags as coyote's --one-shot mode and
--  emits a JSON result line to stdout, so spawn_subagent tool tests
--  can exercise the full output-parsing path without a live LLM.
--
--  Accepted flags:
--    --prompt VAL   Prompt text.
--    --model  VAL   Model identifier.
--    --agent  VAL   Agent file.
--    --name   VAL   Session label.
--    --one-shot     Required; marks a one-shot invocation.
--    --no-session   Accepted but ignored; session creation is now
--                   suppressed via the COYOTE_NO_SESSION environment
--                   variable instead.
--
--  Exit status 0  : success (both required flags present)
--  Exit status 1  : --one-shot absent (--no-session is accepted but not required)
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Command_Line;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;

procedure Mock_Coyote is

   use Ada.Command_Line;
   use Ada.Text_IO;

   Prompt          : Unbounded_String;
   Model           : Unbounded_String;
   Agent           : Unbounded_String;
   Name            : Unbounded_String;
   Have_One_Shot   : Boolean := False;
   I               : Positive := 1;

begin
   while I <= Argument_Count loop
      declare
         Arg : constant String := Argument (I);
      begin
         if Arg = "--prompt" and then I < Argument_Count then
            I      := I + 1;
            Prompt := To_Unbounded_String (Argument (I));
         elsif Arg = "--model" and then I < Argument_Count then
            I     := I + 1;
            Model := To_Unbounded_String (Argument (I));
         elsif Arg = "--agent" and then I < Argument_Count then
            I     := I + 1;
            Agent := To_Unbounded_String (Argument (I));
         elsif Arg = "--name" and then I < Argument_Count then
            I    := I + 1;
            Name := To_Unbounded_String (Argument (I));
         elsif Arg = "--one-shot" then
            Have_One_Shot := True;
         end if;
      end;
      I := I + 1;
   end loop;

   if not Have_One_Shot then
      Put_Line ("{""error"": ""missing required flags""}");
      Set_Exit_Status (Failure);
      return;
   end if;

   Put_Line ("noise before json");
   Put_Line
     ("{""session_id"": ""123"", ""output"": """
      & To_String (Prompt) & "|"
      & To_String (Model)  & "|"
      & To_String (Agent)  & "|"
      & To_String (Name)   & """}");

end Mock_Coyote;
