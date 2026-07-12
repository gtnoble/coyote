--  LLM.Memory body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with LLM.Settings;
with Coyote_Utils;

package body LLM.Memory is

   use type Ada.Directories.File_Kind;

   function Load_Single_Memory_File (Path : String) return String is
      Raw       : constant String := Coyote_Utils.Read_Whole_File (Path);
      Capped    : Unbounded_String;
      Truncated : Boolean := False;
   begin
      if Raw'Length = 0 then
         return "";
      end if;

      --  Cap by bytes first.
      if Raw'Length > Max_Memory_Bytes then
         Capped := To_Unbounded_String
           (Raw (Raw'First .. Raw'First + Max_Memory_Bytes - 1));
         Truncated := True;
      else
         Capped := To_Unbounded_String (Raw);
      end if;

      --  Cap by lines: find the first Max_Memory_Lines + 1 line breaks.
      declare
         Capped_Str : constant String := To_String (Capped);
         LF_Pos     : Natural := Capped_Str'First - 1;
      begin
         for I in 1 .. Max_Memory_Lines loop
            declare
               Next_LF : constant Natural :=
                 Ada.Strings.Fixed.Index
                   (Capped_Str (LF_Pos + 1 .. Capped_Str'Last),
                    "" & ASCII.LF);
            begin
               exit when Next_LF = 0;
               LF_Pos := Next_LF + (LF_Pos - Capped_Str'First + 1);
            end;
         end loop;

         if LF_Pos >= Capped_Str'First
           and then LF_Pos < Capped_Str'Last
         then
            Capped := To_Unbounded_String
              (Capped_Str (Capped_Str'First .. LF_Pos));
            Truncated := True;
         end if;
      end;

      if Truncated then
         Append
           (Capped,
            ASCII.LF
            & ASCII.LF
            & "<!-- MEMORY.md content truncated (exceeded 200 lines"
            & " or 25 000 bytes) -->"
            & ASCII.LF);
      end if;

      return To_String (Capped);
   end Load_Single_Memory_File;

   function Load_Memory_Index (Cwd : String) return String is
      Agent_Dir  : constant String := LLM.Settings.Agent_Dir;
      Global_Path : constant String :=
        (if Agent_Dir'Length > 0
         then Agent_Dir & "/memory/MEMORY.md"
         else "");
      Project_Path : constant String :=
        (if Cwd'Length > 0
         then Cwd & "/.coyote/MEMORY.md"
         else "");
      Result : Unbounded_String;
   begin
      if Global_Path'Length > 0
        and then Ada.Directories.Exists (Global_Path)
        and then Ada.Directories.Kind (Global_Path)
                  = Ada.Directories.Ordinary_File
      then
         declare
            Content : constant String :=
              Load_Single_Memory_File (Global_Path);
         begin
            if Content'Length > 0 then
               Append
                 (Result,
                  "# User Memory (global)"
                  & ASCII.LF
                  & ASCII.LF
                  & Content
                  & ASCII.LF);
            end if;
         end;
      end if;

      if Project_Path'Length > 0
        and then Ada.Directories.Exists (Project_Path)
        and then Ada.Directories.Kind (Project_Path)
                  = Ada.Directories.Ordinary_File
      then
         declare
            Content : constant String :=
              Load_Single_Memory_File (Project_Path);
         begin
            if Content'Length > 0 then
               Append
                 (Result,
                  "# Project Memory"
                  & ASCII.LF
                  & ASCII.LF
                  & Content
                  & ASCII.LF);
            end if;
         end;
      end if;

      return To_String (Result);
   end Load_Memory_Index;

   function Format_Memory_Taxonomy_For_Prompt return String is
   begin
      return
        "# Memory System"
        & ASCII.LF
        & ASCII.LF
        & "You have access to a structured memory system. Memories are"
        & " stored as individual Markdown files in ~/.coyote/memory/."
        & " The index file MEMORY.md lists topic files and their purposes."
        & ASCII.LF
        & ASCII.LF
        & "## Memory Types"
        & ASCII.LF
        & ASCII.LF
        & "### user"
        & ASCII.LF
        & "- **What:** Who the user is -- role, preferences, skills,"
        & " communication style, constraints they operate under."
        & ASCII.LF
        & "- **When to save:** When you learn something new about the user"
        & " that changes how you should interact with them."
        & ASCII.LF
        & "- **How to use:** Apply user preferences and constraints to every"
        & " interaction -- tone, level of detail, preferred tools and"
        & " workflows."
        & ASCII.LF
        & ASCII.LF
        & "### feedback"
        & ASCII.LF
        & "- **What:** Corrections and confirmations the user gives you about"
        & " your work. Each entry must include a **Why:** line capturing the"
        & " reason behind the correction, so future instances can judge"
        & " edge cases rather than blindly following the rule."
        & ASCII.LF
        & "- **When to save:** After every user correction or explicit"
        & " confirmation of a design/implementation choice."
        & ASCII.LF
        & "- **How to use:** Apply corrections as constraints; use the Why:"
        & " rationale to determine scope and exceptions."
        & ASCII.LF
        & ASCII.LF
        & "### project"
        & ASCII.LF
        & "- **What:** Ongoing work, goals, bugs, architectural decisions --"
        & " information not derivable from reading the code alone. Dates"
        & " must be absolute (e.g. 2026-07-12), never relative (e.g."
        & " 'Thursday')."
        & ASCII.LF
        & "- **When to save:** After completing a task, making a significant"
        & " design decision, or discovering a project-level constraint."
        & ASCII.LF
        & "- **How to use:** Review project memories at the start of each"
        & " session and before undertaking major changes."
        & ASCII.LF
        & ASCII.LF
        & "### reference"
        & ASCII.LF
        & "- **What:** Pointers to external systems, APIs, documentation"
        & " URLs, and non-obvious configuration details."
        & ASCII.LF
        & "- **When to save:** When you discover a non-obvious external"
        & " dependency or reference that will be needed again."
        & ASCII.LF
        & "- **How to use:** Consult reference memories when working with"
        & " external systems."
        & ASCII.LF
        & ASCII.LF
        & "## Rules"
        & ASCII.LF
        & ASCII.LF
        & "- **Search before writing.** Before saving a new memory, check"
        & " whether an existing memory already covers the topic.  Update"
        & " existing topic files rather than creating duplicates."
        & ASCII.LF
        & "- **Maintain the index.** When you create or update a topic file,"
        & " update ~/.coyote/memory/MEMORY.md with the file name and a"
        & " one-line description of its purpose."
        & ASCII.LF
        & "- **Write topic files, not monolithic memories.**  Each distinct"
        & " topic gets its own .md file in ~/.coyote/memory/."
        & ASCII.LF
        & "- **Use absolute dates.** Never write 'last Tuesday' or"
        & " 'yesterday'; always write the full date (YYYY-MM-DD).";
   end Format_Memory_Taxonomy_For_Prompt;

end LLM.Memory;
