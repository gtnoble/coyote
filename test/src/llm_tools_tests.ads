with AUnit;
with AUnit.Test_Fixtures;

package LLM_Tools_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Shell_Success (T : in out Test);
   procedure Test_Shell_Failure (T : in out Test);
   procedure Test_Shell_Stdin_Piped           (T : in out Test);
   procedure Test_Shell_Stdin_Empty_Ignored   (T : in out Test);
   procedure Test_Shell_Stdin_Absent_Dev_Null (T : in out Test);
   procedure Test_Read (T : in out Test);
   procedure Test_Write (T : in out Test);
   procedure Test_Edit_Unique (T : in out Test);
   procedure Test_Edit_Non_Unique (T : in out Test);
   procedure Test_Edit_Missing (T : in out Test);
   procedure Test_Find (T : in out Test);
   procedure Test_Built_In_Tools_Include_Spawn_Subagent
     (T : in out Test);
   procedure Test_Spawn_Subagent_Success (T : in out Test);
   procedure Test_Spawn_Subagent_Requires_Prompt (T : in out Test);

   --  ── Pause_Flag unit tests ─────────────────────────────────────────────

   --  Both Is_Armed and Is_Paused start False.
   procedure Test_Pause_Flag_Initial_State         (T : in out Test);

   --  Arm sets Is_Armed; Is_Paused stays False.
   procedure Test_Pause_Flag_Arm_Sets_Armed         (T : in out Test);

   --  Arm then Unarm: both flags remain/return to False.
   procedure Test_Pause_Flag_Unarm_Cancels_Arm      (T : in out Test);

   --  Arm then Fire: Armed clears, Paused becomes True.
   procedure Test_Pause_Flag_Fire_Transitions        (T : in out Test);

   --  Fire without prior Arm is a no-op.
   procedure Test_Pause_Flag_Fire_No_Op_When_Not_Armed
     (T : in out Test);

   --  After Arm+Fire, Release clears Paused.
   procedure Test_Pause_Flag_Release_Clears_Paused  (T : in out Test);

   --  Release also clears Armed (e.g. when Stop is clicked while armed).
   procedure Test_Pause_Flag_Release_Clears_Armed   (T : in out Test);

end LLM_Tools_Tests;
