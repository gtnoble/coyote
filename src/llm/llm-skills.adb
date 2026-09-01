--  LLM.Skills body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with Coyote_Utils;
with LLM.Settings;

package body LLM.Skills is

   use type Ada.Directories.File_Kind;

   function Has_Prefix (Source : String; Prefix : String) return Boolean is
   begin
      return Source'Length >= Prefix'Length
        and then Source (Source'First .. Source'First + Prefix'Length - 1)
                   = Prefix;
   end Has_Prefix;

   function Extract_Value (Line : String) return String is
      Trimmed_Line : constant String :=
        Ada.Strings.Fixed.Trim (Line, Ada.Strings.Both);
      Colon_Pos    : constant Natural :=
        Ada.Strings.Fixed.Index (Trimmed_Line, ":");
   begin
      if Colon_Pos = 0 or else Colon_Pos = Trimmed_Line'Last then
         return "";
      end if;

      declare
         Raw_Value : constant String :=
           Ada.Strings.Fixed.Trim
             (Trimmed_Line (Colon_Pos + 1 .. Trimmed_Line'Last),
              Ada.Strings.Both);
      begin
         if Raw_Value'Length >= 2
           and then Raw_Value (Raw_Value'First) = '"'
           and then Raw_Value (Raw_Value'Last) = '"'
         then
            if Raw_Value'Length = 2 then
               return "";
            else
               return Raw_Value
                 (Raw_Value'First + 1 .. Raw_Value'Last - 1);
            end if;
         else
            return Raw_Value;
         end if;
      end;
   end Extract_Value;

   procedure Parse_Skill_File
     (Path    :     String;
      S       : out Skill;
      Success : out Boolean)
   is
      File                     : Ada.Text_IO.File_Type;
      Opening_Delimiter_Found  : Boolean := False;
      Closing_Delimiter_Found  : Boolean := False;
      Name_Value               : Unbounded_String;
      Description_Value        : Unbounded_String;
   begin
      S := (Name        => To_Unbounded_String (""),
            Description => To_Unbounded_String (""),
            Location    => To_Unbounded_String (Path));
      Success := False;

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);

      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line : constant String := Ada.Text_IO.Get_Line (File);
         begin
            if Ada.Strings.Fixed.Trim (Line, Ada.Strings.Both) = "---" then
               Opening_Delimiter_Found := True;
               exit;
            end if;
         end;
      end loop;

      if not Opening_Delimiter_Found then
         Ada.Text_IO.Close (File);
         return;
      end if;

      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line         : constant String := Ada.Text_IO.Get_Line (File);
            Trimmed_Line : constant String :=
              Ada.Strings.Fixed.Trim (Line, Ada.Strings.Both);
         begin
            if Trimmed_Line = "---" then
               Closing_Delimiter_Found := True;
               exit;
            elsif Has_Prefix (Trimmed_Line, "name:") then
               Name_Value :=
                 To_Unbounded_String (Extract_Value (Trimmed_Line));
            elsif Has_Prefix (Trimmed_Line, "description:") then
               Description_Value :=
                 To_Unbounded_String (Extract_Value (Trimmed_Line));
            end if;
         end;
      end loop;

      Ada.Text_IO.Close (File);

      if Closing_Delimiter_Found
        and then Length (Name_Value) > 0
        and then Length (Description_Value) > 0
      then
         S := (Name        => Name_Value,
               Description => Description_Value,
               Location    => To_Unbounded_String (Path));
         Success := True;
      end if;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;

         Success := False;
   end Parse_Skill_File;

   procedure Collect_Skills_From_Root
     (Root   : String;
      Skills : in out Skill_Vectors.Vector)
   is
      procedure Process_Entry
        (Directory_Entry : Ada.Directories.Directory_Entry_Type);

      procedure Process_Entry
        (Directory_Entry : Ada.Directories.Directory_Entry_Type)
      is
         Entry_Name : constant String :=
           Ada.Directories.Simple_Name (Directory_Entry);
         Candidate  : constant String :=
           Ada.Directories.Full_Name (Directory_Entry) & "/SKILL.md";
         Parsed     : Skill;
         Success    : Boolean;
      begin
         if Entry_Name = "." or else Entry_Name = ".." then
            return;
         end if;

         if Ada.Directories.Exists (Candidate)
           and then Ada.Directories.Kind (Candidate)
                     = Ada.Directories.Ordinary_File
         then
            Parse_Skill_File
              (Path    => Ada.Directories.Full_Name (Candidate),
               S       => Parsed,
               Success => Success);

            if Success then
               Skills.Append (Parsed);
            end if;
         end if;
      end Process_Entry;
   begin
      if Root'Length = 0
        or else not Ada.Directories.Exists (Root)
        or else Ada.Directories.Kind (Root) /= Ada.Directories.Directory
      then
         return;
      end if;

      Ada.Directories.Search
        (Directory => Root,
         Pattern   => "",
         Filter    => (Ada.Directories.Directory => True,
                       others => False),
         Process   => Process_Entry'Access);
   exception
      when others =>
         null;
   end Collect_Skills_From_Root;

   function Install_Base (Executable : String := "") return String is
      Exe : constant String :=
        (if Executable'Length > 0
         then Ada.Directories.Full_Name (Executable)
         else Coyote_Utils.Active_Executable_Path);
      Bin : constant String := Ada.Directories.Containing_Directory (Exe);
   begin
      if Bin'Length = 0
        or else Ada.Directories.Simple_Name (Bin) /= "bin"
      then
         return "";
      end if;

      declare
         Base : constant String :=
           Ada.Directories.Containing_Directory (Bin);
      begin
         if Base'Length = 0 then
            return "";
         end if;

         return Base;
      end;
   end Install_Base;

   function Installation_Skills_Base
     (Executable : String := "") return String
   is
      Base : constant String := Install_Base (Executable);
   begin
      if Base'Length > 0 then
         return Base & "/share/agents/skills";
      end if;

      return "";
   end Installation_Skills_Base;

   function Load_Skills (Cwd : String) return Skill_Vectors.Vector is
      Result              : Skill_Vectors.Vector;
      Settings_Value      : constant LLM.Settings.Settings :=
        LLM.Settings.Load_Settings;
      Agent_Dir           : constant String := LLM.Settings.Agent_Dir;
      Home                : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Global_Coyote_Root  : constant String :=
        (if Agent_Dir'Length > 0 then Agent_Dir & "/skills" else "");
      Global_Agents_Root  : constant String :=
        (if Home'Length > 0 then Home & "/.agents/skills" else "");
      Install_Root        : constant String := Installation_Skills_Base;
      Project_Coyote_Root : constant String :=
        (if Cwd'Length > 0 then Cwd & "/.coyote/skills" else "");
      Project_Agents_Root : constant String :=
        (if Cwd'Length > 0 then Cwd & "/.agents/skills" else "");

      procedure Add_Skill (Candidate : Skill) is
      begin
         if not Result.Is_Empty then
            for Index in Result.First_Index .. Result.Last_Index loop
               if Result.Element (Index).Name = Candidate.Name then
                  Result.Replace_Element (Index, Candidate);
                  return;
               end if;
            end loop;
         end if;
         Result.Append (Candidate);
      end Add_Skill;

      procedure Collect_Root (Root : String) is
         Found : Skill_Vectors.Vector;
      begin
         Collect_Skills_From_Root (Root, Found);
         for Candidate of Found loop
            Add_Skill (Candidate);
         end loop;
      end Collect_Root;
   begin
      Collect_Root (Global_Coyote_Root);
      Collect_Root (Global_Agents_Root);
      Collect_Root (Install_Root);
      for Root of Settings_Value.Skill_Paths loop
         Collect_Root (Root);
      end loop;
      Collect_Root (Project_Coyote_Root);
      Collect_Root (Project_Agents_Root);
      return Result;
   end Load_Skills;

   function Format_Skills_For_Prompt
     (Skills : Skill_Vectors.Vector) return String
   is
      Result : Unbounded_String;
   begin
      if Skills.Is_Empty then
         return "";
      end if;

      Append
        (Result,
         "The following skills provide specialized instructions for"
         & " specific tasks."
         & ASCII.LF
         & "Use the read tool to load a skill's file when the task"
         & " matches its description."
         & ASCII.LF
         & "When a skill file references a relative path, resolve it"
         & " against the skill directory (parent of SKILL.md / dirname"
         & " of the path) and use that absolute path in tool commands."
         & ASCII.LF
         & ASCII.LF
         & "<available_skills>");

      for S of Skills loop
         Append
           (Result,
            ASCII.LF
            & "  <skill>"
            & ASCII.LF
            & "    <name>"
            & To_String (S.Name)
            & "</name>"
            & ASCII.LF
            & "    <description>"
            & To_String (S.Description)
            & "</description>"
            & ASCII.LF
            & "    <location>"
            & To_String (S.Location)
            & "</location>"
            & ASCII.LF
            & "  </skill>");
      end loop;

      Append (Result, ASCII.LF & "</available_skills>");
      return To_String (Result);
   end Format_Skills_For_Prompt;

end LLM.Skills;
