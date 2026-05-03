with AUnit.Assertions;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with LLM.Tools;
with LLM.Tools.Spawn_Subagent;

package body LLM_Spawn_Subagent_Tests is

   use AUnit.Assertions;

   function Contains (Text : String; Pattern : String) return Boolean is
   begin
      return Ada.Strings.Fixed.Index (Text, Pattern) > 0;
   end Contains;

   procedure Restore_Env (Name : String; Was_Set : Boolean; Value : String) is
   begin
      if Was_Set then
         Ada.Environment_Variables.Set (Name, Value);
      else
         Ada.Environment_Variables.Clear (Name);
      end if;
   end Restore_Env;

   procedure Test_Bad_Json (T : in out Test) is
      pragma Unreferenced (T);

      Result   : Unbounded_String;
      Is_Error : Boolean;
   begin
      LLM.Tools.Spawn_Subagent.Execute
        (Args_Json => "{",
         Result    => Result,
         Is_Error  => Is_Error);

      Assert (Is_Error, "spawn_subagent should reject malformed JSON");
      Assert
        (Contains (To_String (Result), "invalid JSON"),
         "spawn_subagent should report invalid JSON arguments");
   end Test_Bad_Json;

   procedure Test_Empty_Prompt (T : in out Test) is
      pragma Unreferenced (T);

      Result   : Unbounded_String;
      Is_Error : Boolean;
   begin
      LLM.Tools.Spawn_Subagent.Execute
        (Args_Json => "{""prompt"":""""}",
         Result    => Result,
         Is_Error  => Is_Error);

      Assert (Is_Error, "spawn_subagent should reject an empty prompt");
      Assert
        (Contains (To_String (Result), "prompt"),
         "spawn_subagent should mention the invalid prompt field");
   end Test_Empty_Prompt;

   procedure Test_Binary_Not_Found (T : in out Test) is
      pragma Unreferenced (T);

      Env_Name  : constant String := "COYOTE_BIN";
      Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists (Env_Name);
      Old_Value : constant String :=
        Ada.Environment_Variables.Value (Env_Name, "");
      Result    : Unbounded_String;
      Is_Error  : Boolean;
   begin
      Ada.Environment_Variables.Set (Env_Name, "/nonexistent/path/coyote");

      LLM.Tools.Spawn_Subagent.Execute
        (Args_Json => "{""prompt"":""hello""}",
         Result    => Result,
         Is_Error  => Is_Error);

      Assert (Is_Error, "spawn_subagent should fail when coyote is missing");
      Assert
        (Length (Result) > 0,
         "spawn_subagent should return a non-empty error message");

      Restore_Env (Env_Name, Was_Set, Old_Value);
   exception
      when others =>
         Restore_Env (Env_Name, Was_Set, Old_Value);
         raise;
   end Test_Binary_Not_Found;

   procedure Test_Abort_Before_Spawn (T : in out Test) is
      pragma Unreferenced (T);

      Env_Name  : constant String := "COYOTE_BIN";
      Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists (Env_Name);
      Old_Value : constant String :=
        Ada.Environment_Variables.Value (Env_Name, "");
      Abort_Flg : aliased LLM.Tools.Abort_Flag;
      Result    : Unbounded_String;
      Is_Error  : Boolean;
   begin
      Abort_Flg.Set;
      Ada.Environment_Variables.Set (Env_Name, "/nonexistent/path/coyote");

      LLM.Tools.Spawn_Subagent.Execute
        (Args_Json => "{""prompt"":""hello""}",
         Result    => Result,
         Is_Error  => Is_Error,
         Abort_Flg => Abort_Flg'Access);

      Assert
        (Is_Error,
         "spawn_subagent should return an error when already aborted");

      Restore_Env (Env_Name, Was_Set, Old_Value);
   exception
      when others =>
         Restore_Env (Env_Name, Was_Set, Old_Value);
         raise;
   end Test_Abort_Before_Spawn;

end LLM_Spawn_Subagent_Tests;
