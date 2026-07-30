--  Unit tests for LLM.Tools.Sandbox — profile discovery, loading, and
--  bwrap argument construction.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with AUnit;
with AUnit.Test_Fixtures;
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
   procedure Test_Resolve_Home_Prefix  (T : in out Test);
   procedure Test_Resolve_Absolute_Untouched (T : in out Test);

   --  ── Shell + sandbox integration tests ────────────────────────────────

   procedure Test_Shell_Sandbox_Allow_Write   (T : in out Test);
   procedure Test_Shell_Sandbox_Deny_Read     (T : in out Test);
   procedure Test_Shell_Sandbox_Empty_Profile  (T : in out Test);

end Sandbox_Tests;
