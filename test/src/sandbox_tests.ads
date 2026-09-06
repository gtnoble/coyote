--  Unit tests for LLM.Tools.Sandbox — profile discovery, loading, and
--  bwrap argument construction.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;
with Ada.Strings.Unbounded;

package Sandbox_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with record
      Temp_Home : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   overriding procedure Set_Up (T : in out Test);
   overriding procedure Tear_Down (T : in out Test);

   --  ── Profiles_Dir unit tests ─────────────────────────────────────────

   procedure Test_Profiles_Dir_Returns_Path (T : in out Test);

   --  ── Available_Profiles unit tests ────────────────────────────────────

   procedure Test_Available_Profiles_Empty   (T : in out Test);
   procedure Test_Available_Profiles_Found   (T : in out Test);

   --  ── Load_Profile unit tests ──────────────────────────────────────────

   procedure Test_Load_Profile_Found    (T : in out Test);
   procedure Test_Load_Profile_Not_Found (T : in out Test);
   procedure Test_Load_Profile_Bad_Json (T : in out Test);

   --  ── Typed profile management tests ──────────────────────────────────

   procedure Test_Profile_Name_Validation (T : in out Test);
   procedure Test_Profile_Typed_Save_Load (T : in out Test);
   procedure Test_Profile_Optional_Arrays_Default_Empty (T : in out Test);
   procedure Test_Profile_Edit_Replaces (T : in out Test);
   procedure Test_Profile_Copy_Independence_And_Collision
     (T : in out Test);
   procedure Test_Profile_Rename_Retains_Old (T : in out Test);

   --  ── Build_Bwrap_Args unit tests ──────────────────────────────────────

   procedure Test_Bbuild_Empty_Profile       (T : in out Test);
   procedure Test_Bbuild_Non_Existent_Profile (T : in out Test);
   procedure Test_Bbuild_Allow_Write          (T : in out Test);
   procedure Test_Bbuild_Deny_Write           (T : in out Test);
   procedure Test_Bbuild_Allow_Read           (T : in out Test);
   procedure Test_Bbuild_Deny_Read            (T : in out Test);
   procedure Test_Bbuild_Missing_Path_Skipped  (T : in out Test);
   procedure Test_Bbuild_Multiple_Rule_Types   (T : in out Test);
   procedure Test_Bbuild_Depth_Sorted          (T : in out Test);

   --  ── Path resolution tests ────────────────────────────────────────────

   procedure Test_Resolve_Dot_To_Cwd   (T : in out Test);
   procedure Test_Resolve_Dot_Slash    (T : in out Test);
   procedure Test_Resolve_Bare_Relative (T : in out Test);
   procedure Test_Resolve_Parent      (T : in out Test);
   procedure Test_Resolve_Parent_Slash (T : in out Test);
   procedure Test_Resolve_Mixed       (T : in out Test);
   procedure Test_Resolve_Home        (T : in out Test);
   procedure Test_Resolve_Home_Prefix  (T : in out Test);
   procedure Test_Resolve_Absolute_Untouched (T : in out Test);

   --  ── Shell + sandbox integration tests ────────────────────────────────

   procedure Test_Shell_Sandbox_Allow_Write   (T : in out Test);
   procedure Test_Shell_Sandbox_Deny_Read     (T : in out Test);
   procedure Test_Shell_Sandbox_Empty_Profile  (T : in out Test);
   procedure Test_Shell_Sandbox_Timeout         (T : in out Test);
   procedure Test_Shell_Sandbox_Abort           (T : in out Test);
   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Sandbox_Tests;
