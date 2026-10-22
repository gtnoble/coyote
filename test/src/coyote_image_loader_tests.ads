--  Coyote_Image_Loader_Tests — synchronous image-loader policy coverage.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;
with Ada.Strings.Unbounded;

package Coyote_Image_Loader_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with record
      Root : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   overriding procedure Set_Up (T : in out Test);
   overriding procedure Tear_Down (T : in out Test);

   procedure Test_Valid_Images_And_Uris (T : in out Test);
   procedure Test_Rejects_Uris_And_Escapes (T : in out Test);
   procedure Test_Rejects_Unsupported_And_Corrupt_Images (T : in out Test);
   procedure Test_Rejects_Path_Escapes_And_Special_Files (T : in out Test);
   procedure Test_Enforces_Source_Limits (T : in out Test);
   procedure Test_Scales_Without_Upscaling (T : in out Test);
   procedure Test_Fits_Within_Width_And_Height (T : in out Test);
   procedure Test_Repeated_Errors_Do_Not_Leak_Descriptors (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Coyote_Image_Loader_Tests;
