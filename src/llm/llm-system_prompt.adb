--  LLM.System_Prompt body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Containers.Indefinite_Vectors;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with LLM.Agent_Defs;
with LLM.Settings;
with LLM.Skills;
with LLM.Tools;

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
      File    : Ada.Text_IO.File_Type;
      Content : Unbounded_String;
   begin
      if Path'Length = 0
        or else not Ada.Directories.Exists (Path)
        or else Ada.Directories.Kind (Path) /= Ada.Directories.Ordinary_File
      then
         return "";
      end if;

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);

      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line : constant String := Ada.Text_IO.Get_Line (File);
         begin
            Append (Content, Line);
            Append (Content, ASCII.LF);
         end;
      end loop;

      Ada.Text_IO.Close (File);
      return To_String (Content);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;

         return "";
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

   function Build_System_Prompt
     (Cwd                : String;
      No_Tools           : Boolean := False;
      Agent_Def          : String  := "";
      Custom_Prompt      : String  := "";
      Context_Sections   : String  := "";
      Skills_Section     : String  := "";
      Agent_Defs_Section : String  := "") return String
   is
      Result : Unbounded_String;
      Tools  : constant LLM.Tools.Tool_Descriptor_Vectors.Vector :=
        LLM.Tools.Built_In_Tools;
   begin
      if Agent_Def'Length = 0 then
         Append
           (Result,
            "You are an expert coding assistant operating inside coyote, a"
            & " native coding agent. You help users by reading files,"
            & " executing commands, editing code, and writing new files.");

         if not No_Tools then
            Append (Result, ASCII.LF & ASCII.LF & "Available tools:");

            for Descriptor of Tools loop
               Append
                 (Result,
                  ASCII.LF
                  & "- "
                  & To_String (Descriptor.Name)
                  & ": "
                  & To_String (Descriptor.Description));
            end loop;

            Append
              (Result,
               ASCII.LF
               & ASCII.LF
               & "Guidelines:"
               & ASCII.LF
               & "- Use bash for file operations like ls, grep, find"
               & ASCII.LF
               & "- Use read to examine files before editing. You must use"
               & " this tool instead of cat or sed."
               & ASCII.LF
               & "- Use edit for precise changes (old text must match exactly)"
               & ASCII.LF
               & "- Use write only for new files or complete rewrites"
               & ASCII.LF
               & "- When summarizing your actions, output plain text directly"
               & " - do NOT use cat or bash to display what you did"
               & ASCII.LF
               & "- Be concise in your responses"
               & ASCII.LF
               & "- Show file paths clearly when working with files"
               & ASCII.LF
               & "- Each tool batch appends a [coyote: turn=...in/...out"
               & " session=...in/...out] footer to the last result;"
               & " use this to monitor token consumption and cost");
         end if;
      else
         Append (Result, Agent_Def);
      end if;

      if Custom_Prompt'Length > 0 then
         Append (Result, ASCII.LF & ASCII.LF & Custom_Prompt);
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

      declare
         Loaded_Defs   : constant LLM.Agent_Defs.Agent_Def_Vectors.Vector :=
           LLM.Agent_Defs.Load_Agent_Defs (Cwd);
         Auto_Section  : constant String :=
           LLM.Agent_Defs.Format_Agent_Defs_For_Prompt (Loaded_Defs);
         Merged_Defs   : constant String :=
           (if Agent_Defs_Section'Length > 0 and then Auto_Section'Length > 0
            then Agent_Defs_Section & ASCII.LF & ASCII.LF & Auto_Section
            elsif Agent_Defs_Section'Length > 0 then Agent_Defs_Section
            else Auto_Section);
      begin
         if Merged_Defs'Length > 0 then
            Ada.Strings.Unbounded.Append
              (Result, ASCII.LF & ASCII.LF & Merged_Defs);
         end if;
      end;

      Append (Result, ASCII.LF & "Current date: " & Today_String);
      Append (Result, ASCII.LF & "Current working directory: " & Cwd);

      return To_String (Result);
   end Build_System_Prompt;

end LLM.System_Prompt;
