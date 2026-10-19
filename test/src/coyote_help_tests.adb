with AUnit.Test_Caller;
--  Coyote_Help_Tests body.
--
--  Project: coyote

with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Coyote_Utils;

with GNATCOLL.OS.Process;
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
        (Coyote_Help.Help_Data_Directory (Executable => "/usr/local/coyote")
         = "",
         "Help data should be empty for a non-standard executable path");
   end Test_Help_Data_Directory;

   procedure Test_Yelp_Is_Available (T : in out Test) is
      pragma Unreferenced (T);
      package Env renames Ada.Environment_Variables;
      Had_Path : constant Boolean := Env.Exists ("PATH");
      Old_Path : constant String := Env.Value ("PATH", "");

      procedure Restore_Path is
      begin
         if Had_Path then
            Env.Set ("PATH", Old_Path);
         else
            Env.Clear ("PATH");
         end if;
      end Restore_Path;
   begin
      --  A regular file cannot contain a Yelp executable.  Unlike an empty
      --  PATH this cannot accidentally find a viewer in the current folder.
      Env.Set ("PATH", "/dev/null");
      Assert (not Coyote_Help.Yelp_Available,
              "Yelp detection must respect the controlled PATH");
      Restore_Path;
   exception
      when others =>
         Restore_Path;
         raise;
   end Test_Yelp_Is_Available;

   procedure Test_Area_Topics (T : in out Test) is
      pragma Unreferenced (T);

      procedure Check (Area : String; Topic : String) is
      begin
         Assert (Coyote_Help.Topic_For_Area (Area) = Topic,
                 "contextual Help mapping for: " & Area);
      end Check;
   begin
      Check ("menu", "ui-menu");
      Check ("prompt", "ui-prompt");
      Check ("controls", "ui-controls");
      Check ("status", "ui-status");
      Check ("conversation", "ui-conversation");
      Check ("", "ui-conversation");
      Check ("unknown-area", "ui-conversation");
   end Test_Area_Topics;

   procedure Run_Launch_Probe (Mode : String) is
      use GNATCOLL.OS.Process;
      Bin : constant String := Ada.Directories.Containing_Directory
        (Coyote_Utils.Active_Executable_Path);
      Test_Root : constant String :=
        Ada.Directories.Containing_Directory (Bin);
      Args : Argument_List;
      Status : Integer;
   begin
      Args.Append ("timeout");
      Args.Append ("10");
      Args.Append ("/bin/sh");
      Args.Append (Test_Root & "/tools/check-help-launch.sh");
      Args.Append (Bin & "/help_test_worker");
      Args.Append (Mode);
      declare
         Output : constant Ada.Strings.Unbounded.Unbounded_String :=
           Run (Args, Status => Status, Strip => False);
      begin
         Assert (Status = 0,
                 "Help launch probe " & Mode & ": "
                 & Ada.Strings.Unbounded.To_String (Output));
      end;
   end Run_Launch_Probe;

   procedure Test_Launch_Existing_XDG (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Run_Launch_Probe ("existing");
   end Test_Launch_Existing_XDG;

   procedure Test_Launch_Empty_XDG (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Run_Launch_Probe ("empty");
   end Test_Launch_Empty_XDG;

   procedure Test_Launch_Unset_XDG (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Run_Launch_Probe ("unset");
   end Test_Launch_Unset_XDG;

   procedure Test_Launch_Root (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Run_Launch_Probe ("root");
   end Test_Launch_Root;

   procedure Test_Launch_Without_Data (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Run_Launch_Probe ("no-data");
   end Test_Launch_Without_Data;

   procedure Test_Launch_Without_Yelp (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Run_Launch_Probe ("missing");
   end Test_Launch_Without_Yelp;

   procedure Test_Product_Information_Text (T : in out Test) is
      pragma Unreferenced (T);
      Text : constant String := Coyote_Help.Product_Information_Text;
   begin
      Assert
        (Ada.Strings.Fixed.Index (Text, "coyote") > 0,
         "Product Information names the application");
      Assert
        (Ada.Strings.Fixed.Index (Text, Coyote_Config.Crate_Version) > 0,
         "Product Information includes the crate version");
      Assert
        (Ada.Strings.Fixed.Index (Text, "License") > 0,
         "Product Information includes the license");
   end Test_Product_Information_Text;

   package Coyote_Help_Caller is new AUnit.Test_Caller
     (Coyote_Help_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test
        (Coyote_Help_Caller.Create
           ("Coyote.Help root URI", Coyote_Help_Tests.Test_Root_URI'Access));
      Result.Add_Test
        (Coyote_Help_Caller.Create
           ("Coyote.Help topic URI", Coyote_Help_Tests.Test_Topic_URI'Access));
      Result.Add_Test
        (Coyote_Help_Caller.Create
           ("Coyote.Help data directory follows executable prefix",
            Coyote_Help_Tests.Test_Help_Data_Directory'Access));
      Result.Add_Test
        (Coyote_Help_Caller.Create
           ("Coyote.Help detects Yelp",
            Coyote_Help_Tests.Test_Yelp_Is_Available'Access));
      Result.Add_Test
        (Coyote_Help_Caller.Create
           ("Coyote.Help product information text",
            Coyote_Help_Tests.Test_Product_Information_Text'Access));

      Result.Add_Test
        (Coyote_Help_Caller.Create
           ("Coyote.Help area topics", Test_Area_Topics'Access));
      Result.Add_Test
        (Coyote_Help_Caller.Create
           ("Coyote.Help launch preserves existing XDG",
            Test_Launch_Existing_XDG'Access));
      Result.Add_Test
        (Coyote_Help_Caller.Create
           ("Coyote.Help launch preserves empty XDG",
            Test_Launch_Empty_XDG'Access));
      Result.Add_Test
        (Coyote_Help_Caller.Create
           ("Coyote.Help launch preserves unset XDG",
            Test_Launch_Unset_XDG'Access));
      Result.Add_Test
        (Coyote_Help_Caller.Create
           ("Coyote.Help launch root URI", Test_Launch_Root'Access));
      Result.Add_Test
        (Coyote_Help_Caller.Create
           ("Coyote.Help launch without bundled data",
            Test_Launch_Without_Data'Access));
      Result.Add_Test
        (Coyote_Help_Caller.Create
           ("Coyote.Help launch without Yelp",
            Test_Launch_Without_Yelp'Access));
      return Result;
   end Suite;

end Coyote_Help_Tests;
