with AUnit.Test_Caller;
--  Coyote_GUI_Mnemonics_Tests body.
--
--  Project: coyote

with AUnit.Assertions;
with Coyote_GUI.Mnemonics;

package body Coyote_GUI_Mnemonics_Tests is

   use AUnit.Assertions;
   use Coyote_GUI.Mnemonics;

   procedure Test_Extracts_First_Mnemonic (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (Key ("New _Session") = 's',
              "the first underscore mnemonic is extracted and normalized");
      Assert (Key ("Plain label") = Character'Val (0),
              "labels without an underscore have no mnemonic");
   end Test_Extracts_First_Mnemonic;

   procedure Test_Ignores_Escaped_Underscores (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (Key ("File __name _Open") = 'o',
              "escaped underscores are not mnemonic markers");
      Assert (Key ("Trailing_") = Character'Val (0),
              "a trailing underscore has no mnemonic");
   end Test_Ignores_Escaped_Underscores;

   procedure Test_Rejects_Duplicate_Context_Key (T : in out Test) is
      pragma Unreferenced (T);
      Context : Registry;
      Rejected : Boolean := False;
   begin
      Reserve (Context, "_Save", "Preferences");
      begin
         Reserve (Context, "_Sandbox", "Preferences");
      exception
         when Program_Error =>
            Rejected := True;
      end;
      Assert (Rejected,
              "a duplicate mnemonic is rejected within one context");
   end Test_Rejects_Duplicate_Context_Key;

   procedure Test_Allows_Key_In_Separate_Context (T : in out Test) is
      pragma Unreferenced (T);
      First_Context  : Registry;
      Second_Context : Registry;
   begin
      Reserve (First_Context, "_Save", "File menu");
      Reserve (Second_Context, "_Save", "Preferences");
      Assert (Key ("_Save") = 's',
              "the same key remains valid in a separate context");
   end Test_Allows_Key_In_Separate_Context;

   procedure Test_Current_UI_Context_Allocations (T : in out Test) is
      pragma Unreferenced (T);
      Agent_Context       : Registry;
      Sandbox_File        : Registry;
      Preferences_Context : Registry;
   begin
      Reserve (Agent_Context, "_Thinking Level", "Agent menu");
      Reserve (Agent_Context, "Sess_ion Stats", "Agent menu");
      Reserve (Sandbox_File, "Cance_l", "Sandbox File menu");
      Reserve (Sandbox_File, "_Close", "Sandbox File menu");
      Reserve (Preferences_Context, "_Save", "Preferences");
      Reserve (Preferences_Context, "_Default model:", "Preferences");
      Reserve
        (Preferences_Context, "Default subagent _model:", "Preferences");
      Reserve (Preferences_Context, "Default sandbo_x:", "Preferences");
      Reserve (Preferences_Context, "Remo_ve Selected", "Preferences");
      Reserve (Preferences_Context, "Move dow_n", "Preferences");
      Assert (Key ("Sess_ion Stats") = 'i',
              "Session Stats uses a unique Agent-menu key");
      Assert (Key ("Cance_l") = 'l',
              "Sandbox Cancel uses a unique File-menu key");
   end Test_Current_UI_Context_Allocations;

   package Coyote_GUI_Mnemonics_Caller is
     new AUnit.Test_Caller (Coyote_GUI_Mnemonics_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (Coyote_GUI_Mnemonics_Caller.Create
        ("Coyote.GUI.Mnemonics extracts first key",
         Coyote_GUI_Mnemonics_Tests.Test_Extracts_First_Mnemonic'Access));
      Result.Add_Test (Coyote_GUI_Mnemonics_Caller.Create
        ("Coyote.GUI.Mnemonics ignores escaped underscores",
         Coyote_GUI_Mnemonics_Tests.Test_Ignores_Escaped_Underscores'Access));
      Result.Add_Test (Coyote_GUI_Mnemonics_Caller.Create
        ("Coyote.GUI.Mnemonics rejects duplicate context key",
         Coyote_GUI_Mnemonics_Tests
           .Test_Rejects_Duplicate_Context_Key'Access));
      Result.Add_Test (Coyote_GUI_Mnemonics_Caller.Create
        ("Coyote.GUI.Mnemonics separates contexts",
         Coyote_GUI_Mnemonics_Tests
           .Test_Allows_Key_In_Separate_Context'Access));
      Result.Add_Test (Coyote_GUI_Mnemonics_Caller.Create
        ("Coyote.GUI.Mnemonics protects current UI allocations",
         Coyote_GUI_Mnemonics_Tests
           .Test_Current_UI_Context_Allocations'Access));
      return Result;
   end Suite;

end Coyote_GUI_Mnemonics_Tests;
