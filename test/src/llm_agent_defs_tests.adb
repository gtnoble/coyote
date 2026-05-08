--  LLM_Agent_Defs_Tests body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with AUnit.Assertions;
with LLM.Agent_Defs;

package body LLM_Agent_Defs_Tests is

   use AUnit.Assertions;

   --  ── Filesystem helpers ───────────────────────────────────────────────

   procedure Make_Dir (Path : String) is
   begin
      if not Ada.Directories.Exists (Path) then
         Ada.Directories.Create_Directory (Path);
      end if;
   end Make_Dir;

   procedure Write_File (Path : String; Content : String) is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (File, Content);
      Ada.Text_IO.Close (File);
   end Write_File;

   procedure Remove_Tree (Path : String) is
   begin
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_Tree (Path);
      end if;
   end Remove_Tree;

   --  Build a minimal valid AGENT.md with the given name, description,
   --  and body text.
   function Agent_Md
     (Name        : String;
      Description : String;
      Body_Text   : String := "You are a test agent.") return String
   is
   begin
      return "---" & ASCII.LF
        & "name: " & Name & ASCII.LF
        & "description: " & Description & ASCII.LF
        & "---" & ASCII.LF
        & Body_Text & ASCII.LF;
   end Agent_Md;

   --  ── Tests ────────────────────────────────────────────────────────────

   procedure Test_Empty_When_No_Roots (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String := "/tmp/coyote_agent_defs_test_1";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Remove_Tree (Home);
      Make_Dir (Home);
      Ada.Environment_Variables.Set ("HOME", Home);

      declare
         Defs : constant LLM.Agent_Defs.Agent_Def_Vectors.Vector :=
           LLM.Agent_Defs.Load_Agent_Defs ("/tmp/nonexistent_cwd_xyz");
      begin
         Assert (Defs.Is_Empty, "expected empty vector when no roots exist");
      end;

      if Home_Was_Set then
         Ada.Environment_Variables.Set ("HOME", Old_Home);
      end if;
      Remove_Tree (Home);
   exception
      when others =>
         if Home_Was_Set then
            Ada.Environment_Variables.Set ("HOME", Old_Home);
         end if;
         Remove_Tree (Home);
         raise;
   end Test_Empty_When_No_Roots;

   procedure Test_Loads_Valid_Agent_Def (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String := "/tmp/coyote_agent_defs_test_2";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Remove_Tree (Home);
      Make_Dir (Home);
      Make_Dir (Home & "/.coyote");
      Make_Dir (Home & "/.coyote/agents");
      Make_Dir (Home & "/.coyote/agents/helper");
      Write_File
        (Home & "/.coyote/agents/helper/AGENT.md",
         Agent_Md ("helper", "A helpful assistant."));
      Ada.Environment_Variables.Set ("HOME", Home);

      declare
         Defs : constant LLM.Agent_Defs.Agent_Def_Vectors.Vector :=
           LLM.Agent_Defs.Load_Agent_Defs ("/tmp/nonexistent_cwd_xyz");
      begin
         Assert
           (not Defs.Is_Empty,
            "expected one agent definition to be loaded");
         Assert
           (Ada.Strings.Unbounded.To_String (Defs.First_Element.Name)
              = "helper",
            "expected name 'helper'");
         Assert
           (Ada.Strings.Unbounded.To_String
              (Defs.First_Element.Description)
              = "A helpful assistant.",
            "expected description 'A helpful assistant.'");
      end;

      if Home_Was_Set then
         Ada.Environment_Variables.Set ("HOME", Old_Home);
      end if;
      Remove_Tree (Home);
   exception
      when others =>
         if Home_Was_Set then
            Ada.Environment_Variables.Set ("HOME", Old_Home);
         end if;
         Remove_Tree (Home);
         raise;
   end Test_Loads_Valid_Agent_Def;

   procedure Test_Skips_Missing_Frontmatter (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String := "/tmp/coyote_agent_defs_test_3";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Remove_Tree (Home);
      Make_Dir (Home);
      Make_Dir (Home & "/.coyote");
      Make_Dir (Home & "/.coyote/agents");
      Make_Dir (Home & "/.coyote/agents/bad");
      Write_File
        (Home & "/.coyote/agents/bad/AGENT.md",
         "No frontmatter here." & ASCII.LF);
      Ada.Environment_Variables.Set ("HOME", Home);

      declare
         Defs : constant LLM.Agent_Defs.Agent_Def_Vectors.Vector :=
           LLM.Agent_Defs.Load_Agent_Defs ("/tmp/nonexistent_cwd_xyz");
      begin
         Assert (Defs.Is_Empty, "expected entry missing frontmatter skipped");
      end;

      if Home_Was_Set then
         Ada.Environment_Variables.Set ("HOME", Old_Home);
      end if;
      Remove_Tree (Home);
   exception
      when others =>
         if Home_Was_Set then
            Ada.Environment_Variables.Set ("HOME", Old_Home);
         end if;
         Remove_Tree (Home);
         raise;
   end Test_Skips_Missing_Frontmatter;

   procedure Test_Skips_Missing_Name (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String := "/tmp/coyote_agent_defs_test_4";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Remove_Tree (Home);
      Make_Dir (Home);
      Make_Dir (Home & "/.coyote");
      Make_Dir (Home & "/.coyote/agents");
      Make_Dir (Home & "/.coyote/agents/noname");
      Write_File
        (Home & "/.coyote/agents/noname/AGENT.md",
         "---" & ASCII.LF
         & "description: Missing name field." & ASCII.LF
         & "---" & ASCII.LF
         & "Body." & ASCII.LF);
      Ada.Environment_Variables.Set ("HOME", Home);

      declare
         Defs : constant LLM.Agent_Defs.Agent_Def_Vectors.Vector :=
           LLM.Agent_Defs.Load_Agent_Defs ("/tmp/nonexistent_cwd_xyz");
      begin
         Assert (Defs.Is_Empty, "expected entry missing name field skipped");
      end;

      if Home_Was_Set then
         Ada.Environment_Variables.Set ("HOME", Old_Home);
      end if;
      Remove_Tree (Home);
   exception
      when others =>
         if Home_Was_Set then
            Ada.Environment_Variables.Set ("HOME", Old_Home);
         end if;
         Remove_Tree (Home);
         raise;
   end Test_Skips_Missing_Name;

   procedure Test_Skips_Missing_Description (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String := "/tmp/coyote_agent_defs_test_5";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Remove_Tree (Home);
      Make_Dir (Home);
      Make_Dir (Home & "/.coyote");
      Make_Dir (Home & "/.coyote/agents");
      Make_Dir (Home & "/.coyote/agents/nodesc");
      Write_File
        (Home & "/.coyote/agents/nodesc/AGENT.md",
         "---" & ASCII.LF
         & "name: nodesc" & ASCII.LF
         & "---" & ASCII.LF
         & "Body." & ASCII.LF);
      Ada.Environment_Variables.Set ("HOME", Home);

      declare
         Defs : constant LLM.Agent_Defs.Agent_Def_Vectors.Vector :=
           LLM.Agent_Defs.Load_Agent_Defs ("/tmp/nonexistent_cwd_xyz");
      begin
         Assert
           (Defs.Is_Empty,
            "expected entry missing description field skipped");
      end;

      if Home_Was_Set then
         Ada.Environment_Variables.Set ("HOME", Old_Home);
      end if;
      Remove_Tree (Home);
   exception
      when others =>
         if Home_Was_Set then
            Ada.Environment_Variables.Set ("HOME", Old_Home);
         end if;
         Remove_Tree (Home);
         raise;
   end Test_Skips_Missing_Description;

   procedure Test_Project_Local_Shadows_Global (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String := "/tmp/coyote_agent_defs_test_6";
      Cwd          : constant String := "/tmp/coyote_agent_defs_test_6_cwd";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Remove_Tree (Home);
      Remove_Tree (Cwd);
      Make_Dir (Home);
      Make_Dir (Cwd);

      Make_Dir (Home & "/.coyote");
      Make_Dir (Home & "/.coyote/agents");
      Make_Dir (Home & "/.coyote/agents/helper");
      Write_File
        (Home & "/.coyote/agents/helper/AGENT.md",
         Agent_Md ("helper", "Global helper."));

      Make_Dir (Cwd & "/.coyote");
      Make_Dir (Cwd & "/.coyote/agents");
      Make_Dir (Cwd & "/.coyote/agents/helper");
      Write_File
        (Cwd & "/.coyote/agents/helper/AGENT.md",
         Agent_Md ("helper", "Project helper."));

      Ada.Environment_Variables.Set ("HOME", Home);

      declare
         Defs : constant LLM.Agent_Defs.Agent_Def_Vectors.Vector :=
           LLM.Agent_Defs.Load_Agent_Defs (Cwd);
      begin
         Assert
           (Natural (Defs.Length) = 1,
            "expected exactly one entry after shadowing");
         Assert
           (Ada.Strings.Unbounded.To_String
              (Defs.First_Element.Description) = "Project helper.",
            "expected project-local definition to shadow global");
      end;

      if Home_Was_Set then
         Ada.Environment_Variables.Set ("HOME", Old_Home);
      end if;
      Remove_Tree (Home);
      Remove_Tree (Cwd);
   exception
      when others =>
         if Home_Was_Set then
            Ada.Environment_Variables.Set ("HOME", Old_Home);
         end if;
         Remove_Tree (Home);
         Remove_Tree (Cwd);
         raise;
   end Test_Project_Local_Shadows_Global;

   procedure Test_Resolve_Returns_Body (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String := "/tmp/coyote_agent_defs_test_7";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Remove_Tree (Home);
      Make_Dir (Home);
      Make_Dir (Home & "/.coyote");
      Make_Dir (Home & "/.coyote/agents");
      Make_Dir (Home & "/.coyote/agents/poet");
      Write_File
        (Home & "/.coyote/agents/poet/AGENT.md",
         Agent_Md ("poet", "Writes haiku.", "You are a haiku poet."));
      Ada.Environment_Variables.Set ("HOME", Home);

      declare
         Defs : constant LLM.Agent_Defs.Agent_Def_Vectors.Vector :=
           LLM.Agent_Defs.Load_Agent_Defs ("/tmp/nonexistent_cwd_xyz");
         Body_Text : constant String :=
           LLM.Agent_Defs.Resolve_Agent_Def ("poet", Defs);
      begin
         Assert
           (Ada.Strings.Fixed.Index (Body_Text, "You are a haiku poet.") > 0,
            "expected body text to contain the agent content");
      end;

      if Home_Was_Set then
         Ada.Environment_Variables.Set ("HOME", Old_Home);
      end if;
      Remove_Tree (Home);
   exception
      when others =>
         if Home_Was_Set then
            Ada.Environment_Variables.Set ("HOME", Old_Home);
         end if;
         Remove_Tree (Home);
         raise;
   end Test_Resolve_Returns_Body;

   procedure Test_Resolve_Raises_When_Not_Found (T : in out Test) is
      pragma Unreferenced (T);

      Defs    : LLM.Agent_Defs.Agent_Def_Vectors.Vector;
      Raised  : Boolean := False;
   begin
      begin
         declare
            Result : constant String :=
              LLM.Agent_Defs.Resolve_Agent_Def ("nonexistent", Defs);
            pragma Unreferenced (Result);
         begin
            null;
         end;
      exception
         when LLM.Agent_Defs.Agent_Not_Found =>
            Raised := True;
      end;

      Assert (Raised, "expected Agent_Not_Found to be raised");
   end Test_Resolve_Raises_When_Not_Found;

   procedure Test_Format_Empty_Returns_Empty (T : in out Test) is
      pragma Unreferenced (T);

      Defs   : LLM.Agent_Defs.Agent_Def_Vectors.Vector;
      Result : constant String :=
        LLM.Agent_Defs.Format_Agent_Defs_For_Prompt (Defs);
   begin
      Assert (Result = "", "expected empty string for empty vector");
   end Test_Format_Empty_Returns_Empty;

   procedure Test_Format_Includes_Name (T : in out Test) is
      pragma Unreferenced (T);

      Defs : LLM.Agent_Defs.Agent_Def_Vectors.Vector;
   begin
      Defs.Append
        ((Name        =>
            Ada.Strings.Unbounded.To_Unbounded_String ("my-agent"),
          Description =>
            Ada.Strings.Unbounded.To_Unbounded_String ("Does things."),
          Location    =>
            Ada.Strings.Unbounded.To_Unbounded_String ("/path/AGENT.md")));

      declare
         Result : constant String :=
           LLM.Agent_Defs.Format_Agent_Defs_For_Prompt (Defs);
      begin
         Assert
           (Ada.Strings.Fixed.Index (Result, "my-agent") > 0,
            "formatted output should include the agent name");
      end;
   end Test_Format_Includes_Name;

   procedure Test_Format_Includes_Description (T : in out Test) is
      pragma Unreferenced (T);

      Defs : LLM.Agent_Defs.Agent_Def_Vectors.Vector;
   begin
      Defs.Append
        ((Name        =>
            Ada.Strings.Unbounded.To_Unbounded_String ("my-agent"),
          Description =>
            Ada.Strings.Unbounded.To_Unbounded_String ("Does things."),
          Location    =>
            Ada.Strings.Unbounded.To_Unbounded_String ("/path/AGENT.md")));

      declare
         Result : constant String :=
           LLM.Agent_Defs.Format_Agent_Defs_For_Prompt (Defs);
      begin
         Assert
           (Ada.Strings.Fixed.Index (Result, "Does things.") > 0,
            "formatted output should include the agent description");
      end;
   end Test_Format_Includes_Description;

   procedure Test_Format_Includes_Location (T : in out Test) is
      pragma Unreferenced (T);

      Defs : LLM.Agent_Defs.Agent_Def_Vectors.Vector;
   begin
      Defs.Append
        ((Name        =>
            Ada.Strings.Unbounded.To_Unbounded_String ("my-agent"),
          Description =>
            Ada.Strings.Unbounded.To_Unbounded_String ("Does things."),
          Location    =>
            Ada.Strings.Unbounded.To_Unbounded_String ("/path/AGENT.md")));

      declare
         Result : constant String :=
           LLM.Agent_Defs.Format_Agent_Defs_For_Prompt (Defs);
      begin
         Assert
           (Ada.Strings.Fixed.Index (Result, "/path/AGENT.md") > 0,
            "formatted output should include the agent location");
      end;
   end Test_Format_Includes_Location;

end LLM_Agent_Defs_Tests;
