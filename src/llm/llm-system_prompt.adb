--  LLM.System_Prompt body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Containers.Indefinite_Vectors;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with LLM.Settings;
with LLM.Skills;
with LLM.Tools;
with LLM.Tools.Shell;
with Coyote_Utils;

package body LLM.System_Prompt is

   use type Ada.Directories.File_Kind;

   package Path_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type   => Positive,
      Element_Type => Unbounded_String);

   package Name_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type   => Positive,
      Element_Type => String);

   function Today_String return String is
      Raw : constant String :=
        Ada.Calendar.Formatting.Image
          (Ada.Calendar.Clock,
           Include_Time_Fraction => False);
   begin
      if Raw'Length >= 10 then
         return Raw (Raw'First .. Raw'First + 9);
      else
         return Raw;
      end if;
   end Today_String;

   function Read_File (Path : String) return String is
   begin
      if Path'Length = 0
        or else not Ada.Directories.Exists (Path)
        or else Ada.Directories.Kind (Path) /= Ada.Directories.Ordinary_File
      then
         return "";
      end if;

      return Coyote_Utils.Read_Whole_File (Path);
   end Read_File;

   function Is_Markdown_File (Name : String) return Boolean is
   begin
      return Name'Length >= 3
        and then Ada.Strings.Fixed.Index
          (Source  => Name,
           Pattern => ".md",
           From    => Name'Length - 2) = Name'Length - 2;
   end Is_Markdown_File;

   procedure Sort_Names (Names : in out Name_Vectors.Vector) is
   begin
      if Names.Is_Empty then
         return;
      end if;

      declare
         First : constant Positive := Names.First_Index;
      begin
         for I in First + 1 .. Names.Last_Index loop
            declare
               Key : constant String := Names (I);
               J   : Integer := I - 1;
            begin
               while J >= Integer (First)
                 and then Names (Positive (J)) > Key
               loop
                  Names.Replace_Element
                    (Positive (J + 1), Names (Positive (J)));
                  J := J - 1;
               end loop;

               Names.Replace_Element (Positive (J + 1), Key);
            end;
         end loop;
      end;
   end Sort_Names;

   procedure Collect_Directory_Context
     (Directory_Path : String;
      Paths          : in out Path_Vectors.Vector)
   is
      Search   : Ada.Directories.Search_Type;
      Started  : Boolean := False;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Names    : Name_Vectors.Vector;
   begin
      if Directory_Path'Length = 0
        or else not Ada.Directories.Exists (Directory_Path)
        or else Ada.Directories.Kind (Directory_Path)
                  /= Ada.Directories.Directory
      then
         return;
      end if;

      Ada.Directories.Start_Search
        (Search,
         Directory => Directory_Path,
         Pattern   => "*",
         Filter    => (Ada.Directories.Ordinary_File => True,
                       others => False));
      Started := True;

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Dir_Entry);

         declare
            Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
         begin
            if Is_Markdown_File (Name) then
               Names.Append (Name);
            end if;
         end;
      end loop;

      Ada.Directories.End_Search (Search);
      Started := False;

      Sort_Names (Names);

      for Name of Names loop
         Paths.Append
           (To_Unbounded_String
              (Ada.Directories.Full_Name (Directory_Path & "/" & Name)));
      end loop;
   exception
      when others =>
         if Started then
            Ada.Directories.End_Search (Search);
         end if;
   end Collect_Directory_Context;

   function Load_Context_Sections (Cwd : String) return String is
      Agent_Dir  : constant String := LLM.Settings.Agent_Dir;
      Global_Dir : constant String :=
        (if Agent_Dir'Length > 0 then Agent_Dir & "/context" else "");
      Project_Dir : constant String :=
        (if Cwd'Length > 0 then Cwd & "/.coyote/context" else "");
      Agents_Path : constant String :=
        (if Cwd'Length > 0 then Cwd & "/AGENTS.md" else "");
      Paths      : Path_Vectors.Vector;
      Sections   : Unbounded_String;
   begin
      Collect_Directory_Context (Global_Dir, Paths);
      Collect_Directory_Context (Project_Dir, Paths);

      if Agents_Path'Length > 0
        and then Ada.Directories.Exists (Agents_Path)
        and then Ada.Directories.Kind (Agents_Path)
                  = Ada.Directories.Ordinary_File
      then
         Paths.Append
           (To_Unbounded_String (Ada.Directories.Full_Name (Agents_Path)));
      end if;

      if Paths.Is_Empty then
         return "";
      end if;

      for Path of Paths loop
         declare
            Full_Path : constant String := To_String (Path);
            Content   : constant String := Read_File (Full_Path);
         begin
            Append
              (Sections,
               "## "
               & Full_Path
               & ASCII.LF
               & ASCII.LF
               & Content
               & ASCII.LF);
         end;
      end loop;

      return "# Project Context"
        & ASCII.LF
        & ASCII.LF
        & "Project-specific instructions and guidelines:"
        & ASCII.LF
        & ASCII.LF
        & To_String (Sections);
   exception
      when others =>
         return "";
   end Load_Context_Sections;

   function Build_Reminder_Instructions
     (Has_Tools : Boolean := False) return String
   is
      Result : Unbounded_String;
   begin
      Append
        (Result,
         "# Reminders"
         & ASCII.LF
         & ASCII.LF
         & "- Persist until the task is completely resolved before ending"
         & " the turn -- do not stop at a natural pause point if work"
         & " remains.");

      if Has_Tools then
         Append
           (Result,
            ASCII.LF
            & "- Report progress after every 3 to 5 tool calls with a"
            & " varied, concise 1-to-2-sentence update on what was"
            & " accomplished and what remains."
            & ASCII.LF
            & "- Preface each tool batch with a one-sentence preamble"
            & " stating why, what, and the expected outcome.");
      end if;

      Append
        (Result,
         ASCII.LF
         & "- Do not repeat verbatim plans or task lists across turns;"
         & " if you need to recall the plan, summarise it in one sentence"
         & " rather than reprinting the full list.");

      return To_String (Result);
   end Build_Reminder_Instructions;

   function Prompt_File_Path return String is
      Base      : constant String := LLM.Skills.Install_Base;
      Candidate : constant String :=
        (if Base'Length > 0
         then Base & "/share/coyote/system-prompt.md"
         else "");
   begin
      if Candidate'Length > 0
        and then Ada.Directories.Exists (Candidate)
        and then Ada.Directories.Kind (Candidate) =
          Ada.Directories.Ordinary_File
      then
         return Candidate;
      end if;

      --  Test executables use a nested test/bin layout.  Permit the
      --  containing checkout prefix without weakening installed lookup.
      if Base'Length > 0 then
         declare
            Parent : constant String :=
              Ada.Directories.Containing_Directory (Base);
            Parent_Candidate : constant String :=
              Parent & "/share/coyote/system-prompt.md";
         begin
            if Ada.Directories.Exists (Parent_Candidate)
              and then Ada.Directories.Kind (Parent_Candidate) =
                Ada.Directories.Ordinary_File
            then
               return Parent_Candidate;
            end if;
         end;
      end if;

      return Candidate;
   end Prompt_File_Path;

   function Load_Static_Prompt return String is
      Path    : constant String := Prompt_File_Path;
      Content : constant String := Coyote_Utils.Read_Whole_File (Path);
   begin
      if Path'Length = 0 or else Content'Length = 0 then
         raise System_Prompt_Error;
      end if;

      return Content;
   end Load_Static_Prompt;

   function Replace_All
     (Source : String;
      Marker : String;
      Value  : String) return String
   is
      Result : Unbounded_String;
      Start  : Positive;
      Match  : Natural;
   begin
      if Source'Length = 0 or else Marker'Length = 0 then
         return Source;
      end if;

      Start := Source'First;
      loop
         Match := Ada.Strings.Fixed.Index
           (Source  => Source,
            Pattern => Marker,
            From    => Start);
         exit when Match = 0;

         if Match > Start then
            Append (Result, Source (Start .. Match - 1));
         end if;
         Append (Result, Value);
         Start := Match + Marker'Length;
         exit when Start > Source'Last;
      end loop;

      if Match = 0 and then Start <= Source'Last then
         Append (Result, Source (Start .. Source'Last));
      end if;

      return To_String (Result);
   end Replace_All;

   function Remove_Section
     (Source       : String;
      Begin_Marker : String;
      End_Marker   : String) return String
   is
      Begin_Pos : constant Natural :=
        Ada.Strings.Fixed.Index (Source, Begin_Marker);
      End_Pos : Natural;
      Result : Unbounded_String;
   begin
      if Begin_Pos = 0 then
         return Source;
      end if;

      End_Pos :=
        Ada.Strings.Fixed.Index
          (Source, End_Marker, Begin_Pos + Begin_Marker'Length);
      if End_Pos = 0 then
         raise System_Prompt_Error;
      end if;

      if Begin_Pos > Source'First then
         Append (Result, Source (Source'First .. Begin_Pos - 1));
      end if;
      End_Pos := End_Pos + End_Marker'Length;
      if End_Pos <= Source'Last then
         Append (Result, Source (End_Pos .. Source'Last));
      end if;
      return To_String (Result);
   end Remove_Section;

   function Unwrap_Section
     (Source       : String;
      Begin_Marker : String;
      End_Marker   : String) return String
   is
      Result : constant String :=
        Replace_All (Source, Begin_Marker, "");
   begin
      return Replace_All (Result, End_Marker, "");
   end Unwrap_Section;

   function Render_Static_Prompt
     (No_Tools          : Boolean;
      Has_Editing_Tools : Boolean;
      Coordinator_Mode  : Boolean;
      Tools_Text        : String;
      Subagent_Command  : String) return String
   is
      Result : Unbounded_String :=
        To_Unbounded_String (Load_Static_Prompt);

      procedure Replace (Marker, Value : String) is
      begin
         Result :=
           To_Unbounded_String
             (Replace_All (To_String (Result), Marker, Value));
      end Replace;

      procedure Remove (Begin_Marker, End_Marker : String) is
      begin
         Result :=
           To_Unbounded_String
             (Remove_Section (To_String (Result), Begin_Marker, End_Marker));
      end Remove;

      procedure Unwrap (Begin_Marker, End_Marker : String) is
      begin
         Result :=
           To_Unbounded_String
             (Unwrap_Section (To_String (Result), Begin_Marker, End_Marker));
      end Unwrap;
   begin
      Replace ("{{SHELL_TOOL}}", Tools_Text);
      Replace ("{{SUBAGENT_COMMAND}}", Subagent_Command);

      if No_Tools then
         Remove ("{{TOOLS_BEGIN}}", "{{TOOLS_END}}");
         Remove ("{{TOOL_POLICY_BEGIN}}", "{{TOOL_POLICY_END}}");
         Remove ("{{COORDINATOR_BEGIN}}", "{{COORDINATOR_END}}");
      else
         Unwrap ("{{TOOLS_BEGIN}}", "{{TOOLS_END}}");
         Unwrap ("{{TOOL_POLICY_BEGIN}}", "{{TOOL_POLICY_END}}");
         if Has_Editing_Tools then
            Remove ("{{TERMINAL_TOOLS_BEGIN}}", "{{TERMINAL_TOOLS_END}}");
            Unwrap ("{{EDITING_TOOLS_BEGIN}}", "{{EDITING_TOOLS_END}}");
         else
            Remove ("{{EDITING_TOOLS_BEGIN}}", "{{EDITING_TOOLS_END}}");
            Unwrap ("{{TERMINAL_TOOLS_BEGIN}}", "{{TERMINAL_TOOLS_END}}");
         end if;

         if Coordinator_Mode then
            Unwrap ("{{COORDINATOR_BEGIN}}", "{{COORDINATOR_END}}");
         else
            Remove ("{{COORDINATOR_BEGIN}}", "{{COORDINATOR_END}}");
         end if;
      end if;

      if Ada.Strings.Fixed.Index (To_String (Result), "{{") > 0 then
         raise System_Prompt_Error;
      end if;

      return To_String (Result);
   end Render_Static_Prompt;

   function Build_System_Prompt
     (Cwd                : String;
      No_Tools           : Boolean := False;
      Has_Editing_Tools  : Boolean := False;
      Agent              : String  := "";
      Context_Sections   : String  := "";
      Skills_Section     : String  := "";
      Memory_Block       : String  := "";
      Executable_Path    : String  := "";
      Coordinator_Mode   : Boolean := False) return String
   is
      Result : Unbounded_String;
      Descriptor : constant LLM.Tools.Tool_Descriptor :=
        LLM.Tools.Shell.Descriptor;
      Active_Path : constant String :=
        (if Executable_Path'Length > 0
         then Executable_Path
         else Coyote_Utils.Active_Executable_Path);
      Subagent_Command : constant String :=
        Coyote_Utils.Shell_Quote (Active_Path) & " --subagent";
   begin
      Result :=
        To_Unbounded_String
          (Render_Static_Prompt
             (No_Tools          => No_Tools,
              Has_Editing_Tools => Has_Editing_Tools,
              Coordinator_Mode  => Coordinator_Mode,
              Tools_Text        => To_String (Descriptor.Name)
                & ": " & To_String (Descriptor.Description),
              Subagent_Command  => Subagent_Command));

      if Agent'Length > 0 then
         Append (Result, ASCII.LF & ASCII.LF & Agent);
      end if;

      --  Append the settings-based appendSystemPrompt value (step 4b).
      declare
         S_Val : constant String :=
           Ada.Strings.Unbounded.To_String
             (LLM.Settings.Load_Settings.Append_System_Prompt);
      begin
         if S_Val'Length > 0 then
            Ada.Strings.Unbounded.Append
              (Result, ASCII.LF & ASCII.LF & S_Val);
         end if;
      end;

      --  Memory block (REQ-CORE-180..183).
      if Memory_Block'Length > 0 then
         Ada.Strings.Unbounded.Append
           (Result, ASCII.LF & ASCII.LF & Memory_Block);
      end if;

      --  Merge the explicit Context_Sections parameter with the auto-loaded
      --  sections from disk. The explicit parameter (used in tests) takes
      --  precedence and appears first; the disk-loaded sections follow.
      declare
         Loaded : constant String := Load_Context_Sections (Cwd);
         Merged : constant String :=
           (if Context_Sections'Length > 0 and then Loaded'Length > 0
            then Context_Sections & ASCII.LF & ASCII.LF & Loaded
            elsif Context_Sections'Length > 0 then Context_Sections
            else Loaded);
      begin
         if Merged'Length > 0 then
            Ada.Strings.Unbounded.Append
              (Result, ASCII.LF & ASCII.LF & Merged);
         end if;
      end;

      declare
         Loaded_Skills : constant LLM.Skills.Skill_Vectors.Vector :=
           LLM.Skills.Load_Skills (Cwd);
         Auto_Section  : constant String :=
           LLM.Skills.Format_Skills_For_Prompt (Loaded_Skills);
         Merged_Skills : constant String :=
           (if Skills_Section'Length > 0 and then Auto_Section'Length > 0
            then Skills_Section & ASCII.LF & ASCII.LF & Auto_Section
            elsif Skills_Section'Length > 0 then Skills_Section
            else Auto_Section);
      begin
         if Merged_Skills'Length > 0 then
            Ada.Strings.Unbounded.Append
              (Result, ASCII.LF & ASCII.LF & Merged_Skills);
         end if;
      end;

      Append (Result, ASCII.LF & "Current date: " & Today_String);
      Append (Result, ASCII.LF & "Current working directory: " & Cwd);
      Append
        (Result,
         ASCII.LF
         & "Current shell: "
         & Ada.Environment_Variables.Value ("SHELL", "/bin/sh"));

      return To_String (Result);
   end Build_System_Prompt;

end LLM.System_Prompt;
