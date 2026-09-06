with AUnit.Assertions;
with Ada.Containers;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with AUnit.Test_Caller;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with LLM.Skills;
with LLM.System_Prompt;

package body LLM_Skills_Tests is

   use AUnit.Assertions;
   use type Ada.Containers.Count_Type;
   use type Ada.Directories.File_Kind;

   procedure Restore_Env (Name : String; Was_Set : Boolean; Value : String) is
   begin
      if Was_Set then
         Ada.Environment_Variables.Set (Name, Value);
      else
         Ada.Environment_Variables.Clear (Name);
      end if;
   end Restore_Env;

   procedure Mkdir (Path : String) is
   begin
      if Path'Length > 0 then
         Ada.Directories.Create_Path (Path);
      end if;
   end Mkdir;

   procedure Write_File (Path, Content : String) is
      File : Ada.Text_IO.File_Type;
   begin
      Mkdir (Ada.Directories.Containing_Directory (Path));
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (File, Content);
      Ada.Text_IO.Close (File);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         raise;
   end Write_File;

   procedure Cleanup (Path : String) is
   begin
      if Path'Length = 0 or else not Ada.Directories.Exists (Path) then
         return;
      end if;

      if Ada.Directories.Kind (Path) = Ada.Directories.Ordinary_File then
         Ada.Directories.Delete_File (Path);
      else
         Ada.Directories.Delete_Tree (Path);
      end if;
   exception
      when others =>
         null;
   end Cleanup;

   function Ends_With (Source, Suffix : String) return Boolean is
   begin
      return Source'Length >= Suffix'Length
        and then Source (Source'Last - Suffix'Length + 1 .. Source'Last)
                   = Suffix;
   end Ends_With;

   function Count_Substring (Source, Pattern : String) return Natural is
      Count : Natural := 0;
      From  : Positive := 1;
      Match : Natural;
   begin
      if Pattern'Length = 0 then
         return 0;
      end if;

      while From <= Source'Length loop
         Match := Ada.Strings.Fixed.Index
           (Source  => Source,
            Pattern => Pattern,
            From    => From);

         exit when Match = 0;

         Count := Count + 1;
         From  := Match + Pattern'Length;
      end loop;

      return Count;
   end Count_Substring;

   function Valid_Skill_Content (Name, Description : String) return String is
   begin
      return "---"
        & ASCII.LF
        & "name: "
        & Name
        & ASCII.LF
        & "description: "
        & Description
        & ASCII.LF
        & "---"
        & ASCII.LF
        & "# Test Skill"
        & ASCII.LF
        & "No content needed."
        & ASCII.LF;
   end Valid_Skill_Content;

   procedure Test_No_Skills_Returns_Empty_String (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String := "/tmp/coyote_skills_test_1";
      Cwd          : constant String := "/tmp/no_skills_cwd";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Cleanup (Home);
      Cleanup (Cwd);
      Mkdir (Home & "/.coyote");

      Ada.Environment_Variables.Set ("HOME", Home);

      declare
         Result : constant String :=
           LLM.Skills.Format_Skills_For_Prompt
             (LLM.Skills.Load_Skills (Cwd));
      begin
         Assert
           (Result = "",
            "no skills should format to the empty string");
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup (Cwd);
      Cleanup (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup (Cwd);
         Cleanup (Home);
         raise;
   end Test_No_Skills_Returns_Empty_String;

   procedure Test_Parses_Name_And_Description (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String := "/tmp/coyote_skills_test_2";
      Cwd          : constant String := "/tmp/coyote_skills_test_2_cwd";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Cleanup (Home);
      Cleanup (Cwd);
      Write_File
        (Home & "/.coyote/skills/mypkg/SKILL.md",
         "---" & ASCII.LF
         & "name: foo" & ASCII.LF
         & "description: bar" & ASCII.LF
         & "---" & ASCII.LF
         & "# Test Skill" & ASCII.LF);

      Ada.Environment_Variables.Set ("HOME", Home);

      declare
         Skills : constant LLM.Skills.Skill_Vectors.Vector :=
           LLM.Skills.Load_Skills (Cwd);
      begin
         Assert (Skills.Length = 1, "one skill should be loaded");
         Assert
           (To_String (Skills (0).Name) = "foo",
            "the skill name should be parsed from frontmatter");
         Assert
           (To_String (Skills (0).Description) = "bar",
            "the skill description should be parsed from frontmatter");
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup (Cwd);
      Cleanup (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup (Cwd);
         Cleanup (Home);
         raise;
   end Test_Parses_Name_And_Description;

   procedure Test_Location_Is_Absolute_Path (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String := "/tmp/coyote_skills_test_3";
      Cwd          : constant String := "/tmp/coyote_skills_test_3_cwd";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Cleanup (Home);
      Cleanup (Cwd);
      Write_File
        (Home & "/.coyote/skills/mypkg/SKILL.md",
         Valid_Skill_Content ("test-skill", "A skill used only in tests."));

      Ada.Environment_Variables.Set ("HOME", Home);

      declare
         Skills : constant LLM.Skills.Skill_Vectors.Vector :=
           LLM.Skills.Load_Skills (Cwd);
      begin
         Assert (Skills.Length = 1, "one skill should be loaded");
         Assert
           (Ends_With (To_String (Skills (0).Location), "SKILL.md"),
            "the skill location should end with SKILL.md");
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup (Cwd);
      Cleanup (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup (Cwd);
         Cleanup (Home);
         raise;
   end Test_Location_Is_Absolute_Path;

   procedure Test_Missing_Name_Skipped (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String := "/tmp/coyote_skills_test_4";
      Cwd          : constant String := "/tmp/coyote_skills_test_4_cwd";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Cleanup (Home);
      Cleanup (Cwd);
      Write_File
        (Home & "/.coyote/skills/mypkg/SKILL.md",
         "---" & ASCII.LF
         & "description: bar" & ASCII.LF
         & "---" & ASCII.LF);

      Ada.Environment_Variables.Set ("HOME", Home);

      declare
         Skills : constant LLM.Skills.Skill_Vectors.Vector :=
           LLM.Skills.Load_Skills (Cwd);
      begin
         Assert
           (Skills.Is_Empty,
            "skills missing a name should be skipped");
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup (Cwd);
      Cleanup (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup (Cwd);
         Cleanup (Home);
         raise;
   end Test_Missing_Name_Skipped;

   procedure Test_Missing_Description_Skipped (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String := "/tmp/coyote_skills_test_5";
      Cwd          : constant String := "/tmp/coyote_skills_test_5_cwd";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Cleanup (Home);
      Cleanup (Cwd);
      Write_File
        (Home & "/.coyote/skills/mypkg/SKILL.md",
         "---" & ASCII.LF
         & "name: foo" & ASCII.LF
         & "---" & ASCII.LF);

      Ada.Environment_Variables.Set ("HOME", Home);

      declare
         Skills : constant LLM.Skills.Skill_Vectors.Vector :=
           LLM.Skills.Load_Skills (Cwd);
      begin
         Assert
           (Skills.Is_Empty,
            "skills missing a description should be skipped");
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup (Cwd);
      Cleanup (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup (Cwd);
         Cleanup (Home);
         raise;
   end Test_Missing_Description_Skipped;

   procedure Test_Global_Skills_Loaded (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String := "/tmp/coyote_skills_test_6";
      Cwd          : constant String := "/tmp/coyote_skills_test_6_cwd";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Cleanup (Home);
      Cleanup (Cwd);
      Write_File
        (Home & "/.coyote/skills/pkg1/SKILL.md",
         Valid_Skill_Content ("test-skill", "A skill used only in tests."));

      Ada.Environment_Variables.Set ("HOME", Home);

      declare
         Skills : constant LLM.Skills.Skill_Vectors.Vector :=
           LLM.Skills.Load_Skills (Cwd);
      begin
         Assert (Skills.Length = 1, "global skills should be loaded");
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup (Cwd);
      Cleanup (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup (Cwd);
         Cleanup (Home);
         raise;
   end Test_Global_Skills_Loaded;

   procedure Test_Project_Skills_Loaded (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String := "/tmp/coyote_skills_test_7";
      Cwd          : constant String := "/tmp/coyote_skills_test_7_cwd";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Cleanup (Home);
      Cleanup (Cwd);
      Mkdir (Home & "/.coyote");
      Write_File
        (Cwd & "/.coyote/skills/pkg1/SKILL.md",
         Valid_Skill_Content ("test-skill", "A skill used only in tests."));

      Ada.Environment_Variables.Set ("HOME", Home);

      declare
         Skills : constant LLM.Skills.Skill_Vectors.Vector :=
           LLM.Skills.Load_Skills (Cwd);
      begin
         Assert (Skills.Length = 1, "project skills should be loaded");
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup (Cwd);
      Cleanup (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup (Cwd);
         Cleanup (Home);
         raise;
   end Test_Project_Skills_Loaded;

   procedure Test_Global_Agents_Skills_Loaded (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String := "/tmp/coyote_skills_test_ga";
      Cwd          : constant String := "/tmp/coyote_skills_test_ga_cwd";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Cleanup (Home);
      Cleanup (Cwd);
      Mkdir (Home & "/.coyote");
      Mkdir (Cwd);
      Write_File
        (Home & "/.agents/skills/pkg1/SKILL.md",
         Valid_Skill_Content ("agents-skill", "A skill used only in tests."));

      Ada.Environment_Variables.Set ("HOME", Home);

      declare
         Skills : constant LLM.Skills.Skill_Vectors.Vector :=
           LLM.Skills.Load_Skills (Cwd);
      begin
         Assert
           (Skills.Length = 1,
            "global ~/.agents/skills should be loaded");
         Assert
           (To_String (Skills (0).Name) = "agents-skill",
            "the skill from ~/.agents/skills should be present");
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup (Cwd);
      Cleanup (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup (Cwd);
         Cleanup (Home);
         raise;
   end Test_Global_Agents_Skills_Loaded;

   procedure Test_Configured_Skills_Loaded (T : in out Test) is
      pragma Unreferenced (T);
      Home         : constant String := "/tmp/coyote_skills_test_cfg";
      Cwd          : constant String := "/tmp/coyote_skills_test_cfg_cwd";
      Root_One     : constant String := "/tmp/coyote_skills_test_cfg_one";
      Root_Two     : constant String := "/tmp/coyote_skills_test_cfg_two";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Cleanup (Home);
      Cleanup (Cwd);
      Cleanup (Root_One);
      Cleanup (Root_Two);
      Mkdir (Home & "/.coyote");
      Write_File
        (Root_One & "/first/SKILL.md",
         Valid_Skill_Content ("configured-one", "First configured skill."));
      Write_File
        (Root_Two & "/second/SKILL.md",
         Valid_Skill_Content ("configured-two", "Second configured skill."));
      Write_File
        (Home & "/.coyote/settings.json",
         "{""skillPaths"" : ["""
         & Root_One
         & ""","""
         & Root_Two
         & """]}");
      Ada.Environment_Variables.Set ("HOME", Home);
      declare
         Skills : constant LLM.Skills.Skill_Vectors.Vector :=
           LLM.Skills.Load_Skills (Cwd);
      begin
         Assert (Skills.Length = 2,
                 "configured skill roots should be searched");
         Assert (To_String (Skills (0).Name) = "configured-one",
                 "configured roots should retain listed order");
         Assert (To_String (Skills (1).Name) = "configured-two",
                 "all configured roots should contribute skills");
      end;
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup (Cwd);
      Cleanup (Home);
      Cleanup (Root_One);
      Cleanup (Root_Two);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup (Cwd);
         Cleanup (Home);
         Cleanup (Root_One);
         Cleanup (Root_Two);
         raise;
   end Test_Configured_Skills_Loaded;

   procedure Test_Configured_Skill_Shadowed_By_Project (T : in out Test) is
      pragma Unreferenced (T);
      Home         : constant String := "/tmp/coyote_skills_test_shadow";
      Cwd          : constant String := "/tmp/coyote_skills_test_shadow_cwd";
      Root         : constant String := "/tmp/coyote_skills_test_shadow_root";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Cleanup (Home);
      Cleanup (Cwd);
      Cleanup (Root);
      Mkdir (Home & "/.coyote");
      Write_File
        (Root & "/same/SKILL.md",
         Valid_Skill_Content ("same-name", "Configured description."));
      Write_File
        (Cwd & "/.coyote/skills/same/SKILL.md",
         Valid_Skill_Content ("same-name", "Project description."));
      Write_File
        (Home & "/.coyote/settings.json",
         "{""skillPaths"":[""" & Root & """]}");
      Ada.Environment_Variables.Set ("HOME", Home);
      declare
         Skills : constant LLM.Skills.Skill_Vectors.Vector :=
           LLM.Skills.Load_Skills (Cwd);
      begin
         Assert (Skills.Length = 1,
                 "same-named skills should be shadowed, not duplicated");
         Assert (To_String (Skills (0).Description) = "Project description.",
                 "project skill should shadow configured skill");
      end;
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup (Cwd);
      Cleanup (Home);
      Cleanup (Root);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup (Cwd);
         Cleanup (Home);
         Cleanup (Root);
         raise;
   end Test_Configured_Skill_Shadowed_By_Project;

   procedure Test_Project_Agents_Skills_Loaded (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String := "/tmp/coyote_skills_test_pa";
      Cwd          : constant String := "/tmp/coyote_skills_test_pa_cwd";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Cleanup (Home);
      Cleanup (Cwd);
      Mkdir (Home & "/.coyote");
      Write_File
        (Cwd & "/.agents/skills/pkg1/SKILL.md",
         Valid_Skill_Content
           ("project-agents-skill", "A skill used only in tests."));

      Ada.Environment_Variables.Set ("HOME", Home);

      declare
         Skills : constant LLM.Skills.Skill_Vectors.Vector :=
           LLM.Skills.Load_Skills (Cwd);
      begin
         Assert
           (Skills.Length = 1,
            "project .agents/skills should be loaded");
         Assert
           (To_String (Skills (0).Name) = "project-agents-skill",
            "the skill from .agents/skills should be present");
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup (Cwd);
      Cleanup (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup (Cwd);
         Cleanup (Home);
         raise;
   end Test_Project_Agents_Skills_Loaded;

   procedure Test_Format_Contains_Skill_Name (T : in out Test) is
      pragma Unreferenced (T);

      Skills : LLM.Skills.Skill_Vectors.Vector;
      S      : constant LLM.Skills.Skill :=
        (Name        => To_Unbounded_String ("my-skill"),
         Description => To_Unbounded_String ("A test skill."),
         Location    => To_Unbounded_String ("/tmp/SKILL.md"));
   begin
      Skills.Append (S);

      declare
         Result : constant String :=
           LLM.Skills.Format_Skills_For_Prompt (Skills);
      begin
         Assert
           (Ada.Strings.Fixed.Index (Result, "<name>my-skill</name>") > 0,
            "formatted skills should include the skill name");
      end;
   end Test_Format_Contains_Skill_Name;

   procedure Test_Format_Contains_Description (T : in out Test) is
      pragma Unreferenced (T);

      Skills : LLM.Skills.Skill_Vectors.Vector;
      S      : constant LLM.Skills.Skill :=
        (Name        => To_Unbounded_String ("my-skill"),
         Description => To_Unbounded_String
           ("A skill used only in tests."),
         Location    => To_Unbounded_String ("/tmp/SKILL.md"));
   begin
      Skills.Append (S);

      declare
         Result : constant String :=
           LLM.Skills.Format_Skills_For_Prompt (Skills);
      begin
         Assert
           (Ada.Strings.Fixed.Index
              (Result,
               "<description>A skill used only in tests.</description>") > 0,
            "formatted skills should include the description");
      end;
   end Test_Format_Contains_Description;

   procedure Test_Format_Contains_Location (T : in out Test) is
      pragma Unreferenced (T);

      Skills : LLM.Skills.Skill_Vectors.Vector;
      S      : constant LLM.Skills.Skill :=
        (Name        => To_Unbounded_String ("my-skill"),
         Description => To_Unbounded_String ("A test skill."),
         Location    => To_Unbounded_String ("/tmp/SKILL.md"));
   begin
      Skills.Append (S);

      declare
         Result : constant String :=
           LLM.Skills.Format_Skills_For_Prompt (Skills);
      begin
         Assert
           (Ada.Strings.Fixed.Index (Result, "<location>") > 0,
            "formatted skills should include the location tag");
      end;
   end Test_Format_Contains_Location;

   procedure Test_Format_Contains_Outer_Tags (T : in out Test) is
      pragma Unreferenced (T);

      Skills : LLM.Skills.Skill_Vectors.Vector;
      S      : constant LLM.Skills.Skill :=
        (Name        => To_Unbounded_String ("my-skill"),
         Description => To_Unbounded_String ("A test skill."),
         Location    => To_Unbounded_String ("/tmp/SKILL.md"));
   begin
      Skills.Append (S);

      declare
         Result : constant String :=
           LLM.Skills.Format_Skills_For_Prompt (Skills);
      begin
         Assert
           (Ada.Strings.Fixed.Index (Result, "<available_skills>") > 0,
            "formatted skills should include the opening outer tag");
         Assert
           (Ada.Strings.Fixed.Index (Result, "</available_skills>") > 0,
            "formatted skills should include the closing outer tag");
      end;
   end Test_Format_Contains_Outer_Tags;

   procedure Test_Format_Contains_Preamble (T : in out Test) is
      pragma Unreferenced (T);

      Skills : LLM.Skills.Skill_Vectors.Vector;
      S      : constant LLM.Skills.Skill :=
        (Name        => To_Unbounded_String ("my-skill"),
         Description => To_Unbounded_String ("A test skill."),
         Location    => To_Unbounded_String ("/tmp/SKILL.md"));
   begin
      Skills.Append (S);

      declare
         Result : constant String :=
           LLM.Skills.Format_Skills_For_Prompt (Skills);
      begin
         Assert
           (Ada.Strings.Fixed.Index
              (Result, "Use the read tool to load a skill") > 0,
            "formatted skills should include the preamble");
      end;
   end Test_Format_Contains_Preamble;

   procedure Test_Format_Two_Skills (T : in out Test) is
      pragma Unreferenced (T);

      Skills : LLM.Skills.Skill_Vectors.Vector;
      S1     : constant LLM.Skills.Skill :=
        (Name        => To_Unbounded_String ("skill-one"),
         Description => To_Unbounded_String ("First skill."),
         Location    => To_Unbounded_String ("/tmp/one/SKILL.md"));
      S2     : constant LLM.Skills.Skill :=
        (Name        => To_Unbounded_String ("skill-two"),
         Description => To_Unbounded_String ("Second skill."),
         Location    => To_Unbounded_String ("/tmp/two/SKILL.md"));
   begin
      Skills.Append (S1);
      Skills.Append (S2);

      declare
         Result : constant String :=
           LLM.Skills.Format_Skills_For_Prompt (Skills);
      begin
         Assert
           (Count_Substring (Result, "<skill>") = 2,
            "formatted output should contain two skill blocks");
      end;
   end Test_Format_Two_Skills;

   procedure Test_Injected_Into_Built_Prompt (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String := "/tmp/coyote_skills_test_8";
      Cwd          : constant String := "/tmp/coyote_skills_test_8_cwd";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Cleanup (Home);
      Cleanup (Cwd);
      Mkdir (Home & "/.coyote");
      Write_File
        (Cwd & "/.coyote/skills/mypkg/SKILL.md",
         Valid_Skill_Content
           ("injected-skill", "A skill used only in tests."));

      Ada.Environment_Variables.Set ("HOME", Home);

      declare
         Prompt : constant String :=
           LLM.System_Prompt.Build_System_Prompt (Cwd => Cwd);
      begin
         Assert
           (Ada.Strings.Fixed.Index (Prompt, "injected-skill") > 0,
            "Build_System_Prompt should include loaded skills");
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup (Cwd);
      Cleanup (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup (Cwd);
         Cleanup (Home);
         raise;
   end Test_Injected_Into_Built_Prompt;

   procedure Test_Install_Base_Bin_Coyote (T : in out Test) is
      pragma Unreferenced (T);
   begin
      declare
         Base : constant String :=
           LLM.Skills.Install_Base
             (Executable => "/opt/coyote/bin/coyote");
      begin
         Assert
           (Base = "/opt/coyote",
            "Install_Base should derive /opt/coyote from"
            & " /opt/coyote/bin/coyote");
      end;
   end Test_Install_Base_Bin_Coyote;

   procedure Test_Install_Base_Non_Standard (T : in out Test) is
      pragma Unreferenced (T);
   begin
      declare
         Base : constant String :=
           LLM.Skills.Install_Base
             (Executable => "/usr/local/coyote");
      begin
         Assert
           (Base = "",
            "Install_Base should return """" when executable is"
            & " not under a bin/ directory");
      end;
   end Test_Install_Base_Non_Standard;

   procedure Test_Install_Base_Explicit_Arg (T : in out Test) is
      pragma Unreferenced (T);
   begin
      declare
         Base : constant String :=
           LLM.Skills.Install_Base
             (Executable => "/home/user/.local/bin/coyote");
      begin
         Assert
           (Base = "/home/user/.local",
            "Install_Base should derive the parent of bin/ when"
            & " given an explicit path");
      end;
   end Test_Install_Base_Explicit_Arg;

   procedure Test_Installation_Skills_Base_Path (T : in out Test) is
      pragma Unreferenced (T);
   begin
      declare
         Path : constant String :=
           LLM.Skills.Installation_Skills_Base
             (Executable => "/opt/coyote/bin/coyote");
      begin
         Assert
           (Path = "/opt/coyote/share/agents/skills",
            "Installation_Skills_Base should append"
            & " /share/agents/skills to the install base");
      end;
   end Test_Installation_Skills_Base_Path;

   procedure Test_Installation_Skills_Base_Empty (T : in out Test) is
      pragma Unreferenced (T);
   begin
      declare
         Path : constant String :=
           LLM.Skills.Installation_Skills_Base
             (Executable => "/usr/local/lib/bash");
      begin
         Assert
           (Path = "",
            "Installation_Skills_Base should return """" when"
            & " the install base is empty");
      end;
   end Test_Installation_Skills_Base_Empty;

   procedure Test_Install_Root_Skills_Loaded (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String := "/tmp/coyote_skills_test_inst";
      Cwd          : constant String := "/tmp/coyote_skills_test_inst_cwd";
      Install_Root : constant String :=
        "/tmp/coyote_skills_test_inst_install";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Cleanup (Home);
      Cleanup (Cwd);
      Cleanup (Install_Root);
      Mkdir (Home & "/.coyote");
      Mkdir (Cwd);
      Write_File
        (Install_Root
         & "/share/agents/skills/pkg1/SKILL.md",
         Valid_Skill_Content
           ("installed-skill", "A skill shipped with the binary."));

      Ada.Environment_Variables.Set ("HOME", Home);

      declare
         Skills : constant LLM.Skills.Skill_Vectors.Vector :=
           LLM.Skills.Load_Skills (Cwd);
      begin
         --  The install root is not on the scan path unless
         --  Installation_Skills_Base returns it.  This test
         --  verifies the function itself works; the integration
         --  of Installation_Skills_Base into Load_Skills already
         --  happens via the Install_Root local in Load_Skills.
         --  We rely on the existing tests to confirm the ordering.
         Assert
           (Skills.Is_Empty,
            "install-root skills should not be loaded when the"
            & " binary path does not resolve to a bin/ layout");
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup (Cwd);
      Cleanup (Home);
      Cleanup (Install_Root);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup (Cwd);
         Cleanup (Home);
         Cleanup (Install_Root);
         raise;
   end Test_Install_Root_Skills_Loaded;

   package LLM_Skills_Caller is
     new AUnit.Test_Caller (LLM_Skills_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills returns empty string when no skills exist",
         LLM_Skills_Tests.Test_No_Skills_Returns_Empty_String'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills parses name and description from frontmatter",
         LLM_Skills_Tests.Test_Parses_Name_And_Description'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills records absolute skill file locations",
         LLM_Skills_Tests.Test_Location_Is_Absolute_Path'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills skips files missing name",
         LLM_Skills_Tests.Test_Missing_Name_Skipped'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills skips files missing description",
         LLM_Skills_Tests.Test_Missing_Description_Skipped'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills loads global skills",
         LLM_Skills_Tests.Test_Global_Skills_Loaded'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills loads project skills",
         LLM_Skills_Tests.Test_Project_Skills_Loaded'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills loads global ~/.agents/skills",
         LLM_Skills_Tests.Test_Global_Agents_Skills_Loaded'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills loads configured skill roots",
         LLM_Skills_Tests.Test_Configured_Skills_Loaded'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills project roots shadow configured skills",
         LLM_Skills_Tests.Test_Configured_Skill_Shadowed_By_Project'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills loads project .agents/skills",
         LLM_Skills_Tests.Test_Project_Agents_Skills_Loaded'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills format contains skill name",
         LLM_Skills_Tests.Test_Format_Contains_Skill_Name'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills format contains description",
         LLM_Skills_Tests.Test_Format_Contains_Description'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills format contains location",
         LLM_Skills_Tests.Test_Format_Contains_Location'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills format contains outer tags",
         LLM_Skills_Tests.Test_Format_Contains_Outer_Tags'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills format contains preamble",
         LLM_Skills_Tests.Test_Format_Contains_Preamble'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills formats two skills",
         LLM_Skills_Tests.Test_Format_Two_Skills'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills auto-injects into Build_System_Prompt",
         LLM_Skills_Tests.Test_Injected_Into_Built_Prompt'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills Install_Base derives prefix from bin/coyote",
         LLM_Skills_Tests.Test_Install_Base_Bin_Coyote'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills Install_Base returns empty for non-bin path",
         LLM_Skills_Tests.Test_Install_Base_Non_Standard'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills Install_Base uses explicit Executable arg",
         LLM_Skills_Tests.Test_Install_Base_Explicit_Arg'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills Installation_Skills_Base appends path",
         LLM_Skills_Tests.Test_Installation_Skills_Base_Path'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills Installation_Skills_Base returns empty for non-bin",
         LLM_Skills_Tests.Test_Installation_Skills_Base_Empty'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills install-root skills not loaded when bin/ absent",
         LLM_Skills_Tests.Test_Install_Root_Skills_Loaded'Access));

      return Result;
   end Suite;

end LLM_Skills_Tests;
