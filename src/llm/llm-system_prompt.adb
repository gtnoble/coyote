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

   --  Personality definition for the agent (REQ-CORE-170).
   Personality_Definition : constant String :=
     "# Communication Style"
     & ASCII.LF
     & ASCII.LF
     & "- Be terse, direct, and pragmatic."
     & ASCII.LF
     & "- No cheerleading, motivational language, or artificial"
     & " reassurance."
     & ASCII.LF
     & "- No conversational interjections as response openers -- never"
     & " start a response with ""Done --"", ""Got it"", ""Great question"","
     & " ""Sure!"", ""Absolutely"", or similar."
     & ASCII.LF
     & "- When providing a final answer, state the result directly"
     & " without a preamble."
     & ASCII.LF
     & "- Between tool calls, give concise progress updates: 1--2"
     & " sentences stating what was done and what comes next."
     & ASCII.LF
     & "- Vary your progress-update phrasing across turns; never repeat"
     & " the same template verbatim.";

   --  Presentation MathML display-math guidance (REQ-CORE-173).
   Display_Math_Guidance : constant String :=
     "# Display Math"
     & ASCII.LF
     & ASCII.LF
     & "When writing standalone display mathematics intended for the coyote"
     & " GUI, output Presentation MathML inside a `$$` block."
     & ASCII.LF
     & "- Put the opening and closing `$$` delimiters on standalone lines."
     & ASCII.LF
     & "- Between the delimiters, output one complete `<math>` document"
     & " with the namespace"
     & " `http://www.w3.org/1998/Math/MathML`."
     & ASCII.LF
     & "- Use Presentation MathML elements such as `<mrow>`, `<mi>`,"
     & " `<mo>`, `<mn>`, `<mfrac>`, and `<msup>`; do not output LaTeX"
     & " commands or Content MathML."
     & ASCII.LF
     & "- Escape XML special characters in text and operators: use `&lt;`,"
     & " `&gt;`, and `&amp;` where required."
     & ASCII.LF
     & "- If an expression cannot be represented reliably in Presentation"
     & " MathML, keep it readable as plain text rather than inventing"
     & " markup."
     & ASCII.LF
     & ASCII.LF
     & "# Inline Math"
     & ASCII.LF
     & ASCII.LF
     & "When writing inline mathematics, use Unicode math symbols directly"
     & " (for example, Unicode comparison, multiplication, root, arrow, and"
     & " Greek-letter symbols) rather than LaTeX"
     & " notation or backslash commands."
     & ASCII.LF
     & "- Keep inline mathematics readable in ordinary text; do not use"
     & " LaTeX-style inline delimiters or commands.";

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
      Append
        (Result,
         "You are an expert coding assistant operating inside coyote, a"
         & " native coding agent. You help users by reading files,"
         & " executing commands, editing code, and writing new files.");

      --  Personality definition (REQ-CORE-170).
      Append (Result, ASCII.LF & ASCII.LF & Personality_Definition);

      --  Presentation MathML display-math guidance (REQ-CORE-173).
      Append (Result, ASCII.LF & ASCII.LF & Display_Math_Guidance);
      if not No_Tools then
         Append (Result, ASCII.LF & ASCII.LF & "Available tools:");

         Append
           (Result,
            ASCII.LF
            & "- "
            & To_String (Descriptor.Name)
            & ": "
            & To_String (Descriptor.Description));

         Append
           (Result,
            ASCII.LF
            & ASCII.LF
            & "Guidelines:"
            & ASCII.LF
            & "- Always use the stdin field instead of heredocs when"
            & " passing multi-line content to a command;"
            & " never use <<EOF or <<'EOF' heredoc syntax"
            & ASCII.LF
            & "- Read files: cat path (full file),"
            & " sed -n 'N,Mp' path (line range), head/tail"
            & ASCII.LF
            & "- Write new files or complete rewrites:"
            & " command=""cat > path"","
            & " stdin=""<file content>"""
            & ASCII.LF
            & "- Edit files precisely with aged, sed, or perl"
            & " (pass the script via the stdin field;"
            & " use perl -0777 -i -pe for multi-line patterns)"
            & ASCII.LF
            & "- Edit files with aged: `aged FILE OLD NEW` for exact"
            & " string replacement, or `aged -d DELIM FILE` to read"
            & " OLD and NEW from stdin separated by a DELIM line"
            & ASCII.LF
            & "- For non-trivial sed/perl/awk scripts, pass the script"
            & " body via the stdin field rather than embedding it in"
            & " the command argument to avoid shell-quoting issues"
            & ASCII.LF
            & "- Never pass code to an interpreter via inline flags when"
            & " stdin is available; always supply the script body through"
            & " the stdin field instead (e.g. never use perl -e '...'"
            & " or perl -E '...'; invoke perl without inline code arguments"
            & " and pass the script via stdin)"
            & ASCII.LF
            & "- Find files: find path -name pattern;"
            & " search content: grep -r pattern path (or rg)"
            & ASCII.LF
            & "- Set a wall-clock timeout on shell commands by adding a"
            & " `timeout` integer field (seconds). A timed-out command"
            & " returns partial output with a ""[command timed out"" notice."
            & " Omit the field (or use 0) for no time limit."
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
            & " use this to monitor token consumption and cost"
            & ASCII.LF);
      end if;

      --  Conditional tool-use instructions (REQ-CORE-171).
      if not No_Tools then
         if Has_Editing_Tools then
            Append
              (Result,
               ASCII.LF
               & "# Tool Use Policy"
               & ASCII.LF
               & ASCII.LF
               & "Editing tools are available.  Use them to make changes"
               & " directly in files rather than printing code blocks for"
               & " the user to copy-paste.  When you would otherwise print"
               & " a code block as a suggestion, apply the edit instead"
               & " and report what you changed.");
         else
            Append
              (Result,
               ASCII.LF
               & "# Tool Use Policy"
               & ASCII.LF
               & ASCII.LF
               & "Terminal tools are available -- run commands rather than"
               & " printing them for the user to execute."
               & ASCII.LF
               & "When no editing tools are available, print code blocks"
               & " as suggestions for the user to apply.");
         end if;
      end if;

      Append
        (Result,
         ASCII.LF
         & ASCII.LF
         & "# Parallel Delegation (Subagents)"
         & ASCII.LF
         & ASCII.LF
         & "For complex multi-phase tasks, spawn subagents to"
         & " parallelize independent work.  Do NOT do everything"
         & " sequentially inline when work can be delegated."
         & ASCII.LF
         & ASCII.LF
         & "**PREFER spawning a subagent when:**"
         & ASCII.LF
         & "- Codebase exploration: BEFORE making edits, spawn a"
         & " subagent to search, grep, or read files while you"
         & " plan your approach.  Delegating exploration is faster"
         & " than doing all searching inline, turn by turn."
         & ASCII.LF
         & "- Independent subtasks: when a request splits into"
         & " unrelated pieces (e.g. ""fix bug A"" and ""refactor"
         & " module B""), spawn a subagent for each in parallel."
         & ASCII.LF
         & "- Heavy computation: offload build runs, test suites,"
         & " or large-scale searches to subagents while you"
         & " continue editing or planning."
         & ASCII.LF
         & "- Skill-specific work: when a skill in"
         & " &lt;available_skills&gt; matches the task, spawn a"
         & " subagent with `--agent @path/to/SKILL.md` so it"
         & " has the specialised instructions."
         & ASCII.LF
         & ASCII.LF
         & "**Do NOT spawn subagents for:**"
         & ASCII.LF
         & "- Sequential dependent work (step 2 needs step 1)"
         & ASCII.LF
         & "- Trivial single-file fixes or one-shot questions"
         & ASCII.LF
         & "- Simple commands with no exploration needed"
         & ASCII.LF
         & ASCII.LF
         & "**Invocation:** use the shell tool with"
         & " `" & Subagent_Command & " --prompt -`, piping the task"
         & " prompt to stdin.  The call returns quickly with empty"
         & " output; coordinator-launched workers use the headless RPC"
         & " presentation channel, while standalone workers use Plain;"
         & " each runs one turn.  Pass `--model PROVIDER/ID`,"
         & " `--agent @path`, and `--name LABEL`.  Session"
         & " lineage is auto-linked via COYOTE_SESSION_ID."
         & ASCII.LF
         & ASCII.LF
         & "Example:"
         & " `printf 'Search all callers of Init()\n'"
         & " | " & Subagent_Command
         & " --agent @~/.coyote/skills/ada-style-guide/SKILL.md"
         & " --name ""search-init"" --prompt -`");

      --  Coordinator mode guidance (REQ-CORE-190..192).
      if Coordinator_Mode and then not No_Tools then
         Append
           (Result,
            ASCII.LF
            & ASCII.LF
            & "# Coordinator Subagent Orchestration"
            & ASCII.LF
            & ASCII.LF
            & "When spawning subagents, act as a coordinator:"
            & ASCII.LF
            & ASCII.LF
            & "- **Launch independent subagents in parallel** whenever"
            & " possible -- do not serialise unrelated tasks."
            & ASCII.LF
            & "- **Never delegate understanding.**  Read all worker results"
            & " and synthesise them before writing follow-up prompts."
            & ASCII.LF
            & "- **Write specific worker prompts** with exact file paths and"
            & " line numbers rather than vague ""based on your findings"""
            & " directives."
            & ASCII.LF
            & "- **Do not fabricate or predict subagent results** before"
            & " they arrive.  When asked about an in-flight subagent,"
            & " report its status only -- never guess at its findings."
            & ASCII.LF
            & ASCII.LF
            & "## Subagent Result Format"
            & ASCII.LF
            & ASCII.LF
            & "Subagent results include a structured summary block:"
            & ASCII.LF
            & "- **Task status:** completed, failed, or killed"
            & ASCII.LF
            & "- **Human-readable summary** of what was done"
            & ASCII.LF
            & "- **Final text response** from the worker agent"
            & ASCII.LF
            & "- **Usage statistics:** token count, tool-use count,"
            & " wall-clock duration"
            & ASCII.LF
            & ASCII.LF
            & "Use this structured format to distinguish worker completion"
            & " notifications from user messages.");
      end if;

      Append
        (Result,
         ASCII.LF
         & ASCII.LF
         & "# Editing Discipline"
         & ASCII.LF
         & ASCII.LF
         & "Before making any code edits:"
         & ASCII.LF
         & ASCII.LF
         & "1. **Map every affected site first.** Identify all call"
         & " sites, declaration sites, and test files that will need"
         & " changing. Read enough context at each site to confirm the"
         & " surrounding scope (which procedure, which package, what"
         & " indentation) before writing a single edit."
         & ASCII.LF
         & ASCII.LF
         & "2. **Verify structural assumptions explicitly.** Never assume"
         & " a variable declared in one procedure is visible at a call"
         & " site in another. Grep for the containing procedure of each"
         & " call site and confirm it matches expectations."
         & ASCII.LF
         & ASCII.LF
         & "3. **Watch for irregular formatting.** Source files may"
         & " contain mis-indented or otherwise non-standard constructs"
         & " that defeat pattern-matching greps. If a grep returns fewer"
         & " hits than expected, investigate before proceeding."
         & ASCII.LF
         & ASCII.LF
         & "4. **Plan all changes before executing any.** Collect the"
         & " full list of edits -- including every call site, declaration,"
         & " spec, and test -- then execute them in one coherent pass"
         & " (bottom-to-top when inserting lines to keep line numbers"
         & " stable), rather than making incremental edits that shift"
         & " line numbers and require re-greps.");

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
