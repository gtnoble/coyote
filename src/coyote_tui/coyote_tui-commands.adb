--  Coyote_TUI.Commands body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package body Coyote_TUI.Commands is

   --  ── Parse ─────────────────────────────────────────────────────────────

   function Parse (Str : String) return Command is
      use Ada.Strings;
      use Ada.Strings.Fixed;

      --  Trim leading/trailing spaces from the whole input.
      Trimmed : constant String := Trim (Str, Both);

      --  Split into verb and optional argument at the first space.
      Space_Pos : Natural := 0;
   begin
      for I in Trimmed'Range loop
         if Trimmed (I) = ' ' then
            Space_Pos := I;
            exit;
         end if;
      end loop;

      declare
         Verb : constant String :=
           (if Space_Pos > 0
            then Trimmed (Trimmed'First .. Space_Pos - 1)
            else Trimmed);
         Arg  : constant String :=
           (if Space_Pos > 0
            then Trim (Trimmed (Space_Pos + 1 .. Trimmed'Last), Left)
            else "");
         Kind : Command_Kind;
      begin
         if    Verb = "send"     then Kind := Send;
         elsif Verb = "help"     then Kind := Help;
         elsif Verb = "stats"    then Kind := Stats;
         elsif Verb = "models"   then Kind := Models_List;
         elsif Verb = "sessions" then Kind := Sessions_List;
         elsif Verb = "clear"    then Kind := Clear;
         elsif Verb = "q"        then Kind := Quit;
         elsif Verb = "stop"     then Kind := Stop;
         elsif Verb = "pause"    then Kind := Pause;
         elsif Verb = "resume"   then Kind := Resume;
         elsif Verb = "model"    then Kind := Set_Model;
         elsif Verb = "thinking" then Kind := Set_Thinking;
         elsif Verb = "new"      then Kind := New_Session;
         elsif Verb = "session"  then Kind := Load_Session;
         elsif Verb = "compact"  then Kind := Compact;
         else                         Kind := Unknown;
         end if;

         return (Kind     => Kind,
                 Arg      => To_Unbounded_String (Arg),
                 Is_Steer => False);
      end;
   end Parse;

   --  ── Agent_Prefix ──────────────────────────────────────────────────────

   function Agent_Prefix (Cmd : Command) return String is
      Arg : constant String := To_String (Cmd.Arg);
   begin
      case Cmd.Kind is
         when Stop         => return ":stop";
         when Pause        => return ":pause";
         when Resume       => return ":resume";
         when Set_Model    =>
            return ":model" & (if Arg'Length > 0 then " " & Arg else "");
         when Set_Thinking =>
            return ":thinking" & (if Arg'Length > 0 then " " & Arg else "");
         when New_Session  => return ":new";
         when Load_Session =>
            return ":session" & (if Arg'Length > 0 then " " & Arg else "");
         when Compact      => return ":compact";
         when others       => return "";
      end case;
   end Agent_Prefix;

end Coyote_TUI.Commands;
