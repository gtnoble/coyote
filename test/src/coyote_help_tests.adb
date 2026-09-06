with AUnit.Test_Caller;
--  Coyote_Help_Tests body.
--
--  Project: coyote

with Ada.Strings.Fixed;
with AUnit.Assertions;
with Coyote_Config;
with Coyote_Help;

package body Coyote_Help_Tests is

   use AUnit.Assertions;

   procedure Test_Root_URI (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert
        (Coyote_Help.Help_URI = "help:coyote",
         "the help root URI should use the coyote application ID");
   end Test_Root_URI;

   procedure Test_Topic_URI (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert
        (Coyote_Help.Help_URI ("send-prompt") = "help:coyote/send-prompt",
         "topic URIs should append the Mallard topic ID");
   end Test_Topic_URI;

   procedure Test_Help_Data_Directory (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert
        (Coyote_Help.Help_Data_Directory
           (Executable => "/opt/coyote/bin/coyote")
         = "/opt/coyote/share",
         "Help data should be relative to the installation prefix");
      Assert
        (Coyote_Help.Help_Data_Directory
           (Executable => "/usr/local/coyote")
         = "",
         "Help data should be empty for a non-standard executable path");
   end Test_Help_Data_Directory;

   procedure Test_Yelp_Is_Available (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert
        (Coyote_Help.Yelp_Available,
         "Yelp is a required runtime dependency for Help");
   end Test_Yelp_Is_Available;

   procedure Test_Product_Information_Text (T : in out Test) is
      pragma Unreferenced (T);
      Text : constant String := Coyote_Help.Product_Information_Text;
   begin
      Assert
        (Ada.Strings.Fixed.Index (Text, "coyote") > 0,
         "Product Information names the application");
      Assert
        (Ada.Strings.Fixed.Index
           (Text, Coyote_Config.Crate_Version) > 0,
         "Product Information includes the crate version");
      Assert
        (Ada.Strings.Fixed.Index (Text, "License") > 0,
         "Product Information includes the license");
   end Test_Product_Information_Text;

   package Coyote_Help_Caller is
     new AUnit.Test_Caller (Coyote_Help_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (Coyote_Help_Caller.Create
        ("Coyote.Help root URI",
         Coyote_Help_Tests.Test_Root_URI'Access));
      Result.Add_Test (Coyote_Help_Caller.Create
        ("Coyote.Help topic URI",
         Coyote_Help_Tests.Test_Topic_URI'Access));
      Result.Add_Test (Coyote_Help_Caller.Create
        ("Coyote.Help data directory follows executable prefix",
         Coyote_Help_Tests.Test_Help_Data_Directory'Access));
      Result.Add_Test (Coyote_Help_Caller.Create
        ("Coyote.Help detects Yelp",
         Coyote_Help_Tests.Test_Yelp_Is_Available'Access));
      Result.Add_Test (Coyote_Help_Caller.Create
        ("Coyote.Help product information text",
         Coyote_Help_Tests.Test_Product_Information_Text'Access));

      return Result;
   end Suite;

end Coyote_Help_Tests;
