with AUnit.Assertions;
with Ada.Containers;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
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

end LLM_Skills_Tests;
