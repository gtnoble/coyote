--  LLM.Agent_Defs body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with LLM.Settings;

package body LLM.Agent_Defs is

   use type Ada.Directories.File_Kind;

   --  ── Frontmatter parsing helpers ──────────────────────────────────────

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

   --  ── Parse one AGENT.md file into an Agent_Def ────────────────────────

   procedure Parse_Agent_File
     (Path    :     String;
      D       : out Agent_Def;
      Success : out Boolean)
   is
      File                    : Ada.Text_IO.File_Type;
      Opening_Delimiter_Found : Boolean := False;
      Closing_Delimiter_Found : Boolean := False;
      Name_Value              : Unbounded_String;
      Description_Value       : Unbounded_String;
   begin
      D := (Name        => To_Unbounded_String (""),
            Description => To_Unbounded_String (""),
            Location    => To_Unbounded_String (Path));
      Success := False;

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);

      --  Locate the opening "---" delimiter.
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

      --  Read frontmatter fields until the closing "---" delimiter.
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
         D := (Name        => Name_Value,
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
   end Parse_Agent_File;

   --  ── Shadowing upsert ─────────────────────────────────────────────────

   --  Insert Item into Result.  When an entry with the same name already
   --  exists it is replaced, implementing project-local shadowing of
   --  global definitions.
   procedure Upsert_By_Name
     (Result : in out Agent_Def_Vectors.Vector;
      Item   :        Agent_Def)
   is
   begin
      for I in Result.First_Index .. Result.Last_Index loop
         if Result.Element (I).Name = Item.Name then
            Result.Replace_Element (I, Item);
            return;
         end if;
      end loop;

      Result.Append (Item);
   end Upsert_By_Name;

   --  ── Root scanning ────────────────────────────────────────────────────

   procedure Collect_Agent_Defs_From_Root
     (Root   :        String;
      Result : in out Agent_Def_Vectors.Vector)
   is
      procedure Process_Entry
        (Directory_Entry : Ada.Directories.Directory_Entry_Type);

      procedure Process_Entry
        (Directory_Entry : Ada.Directories.Directory_Entry_Type)
      is
         Entry_Name : constant String :=
           Ada.Directories.Simple_Name (Directory_Entry);
         Candidate  : constant String :=
           Ada.Directories.Full_Name (Directory_Entry) & "/AGENT.md";
         Parsed     : Agent_Def;
         Success    : Boolean;
      begin
         if Entry_Name = "." or else Entry_Name = ".." then
            return;
         end if;

         if Ada.Directories.Exists (Candidate)
           and then Ada.Directories.Kind (Candidate)
                     = Ada.Directories.Ordinary_File
         then
            Parse_Agent_File
              (Path    => Ada.Directories.Full_Name (Candidate),
               D       => Parsed,
               Success => Success);

            if Success then
               Upsert_By_Name (Result, Parsed);
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
   end Collect_Agent_Defs_From_Root;

   --  ── Public subprograms ───────────────────────────────────────────────

   function Load_Agent_Defs
     (Cwd : String) return Agent_Def_Vectors.Vector
   is
      Result              : Agent_Def_Vectors.Vector;
      Agent_Dir           : constant String := LLM.Settings.Agent_Dir;
      Home                : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Global_Coyote_Root  : constant String :=
        (if Agent_Dir'Length > 0 then Agent_Dir & "/agents" else "");
      Global_Agents_Root  : constant String :=
        (if Home'Length > 0 then Home & "/.agents/agents" else "");
      Project_Coyote_Root : constant String :=
        (if Cwd'Length > 0 then Cwd & "/.coyote/agents" else "");
      Project_Agents_Root : constant String :=
        (if Cwd'Length > 0 then Cwd & "/.agents/agents" else "");
   begin
      Collect_Agent_Defs_From_Root (Global_Coyote_Root, Result);
      Collect_Agent_Defs_From_Root (Global_Agents_Root, Result);
      Collect_Agent_Defs_From_Root (Project_Coyote_Root, Result);
      Collect_Agent_Defs_From_Root (Project_Agents_Root, Result);
      return Result;
   end Load_Agent_Defs;

   function Resolve_Agent_Def
     (Name : String;
      Defs : Agent_Def_Vectors.Vector) return String
   is
      Target_Location : Unbounded_String;
      Found           : Boolean := False;
   begin
      for D of Defs loop
         if To_String (D.Name) = Name then
            Target_Location := D.Location;
            Found           := True;
         end if;
      end loop;

      if not Found then
         raise Agent_Not_Found with
           "agent definition not found: """ & Name & """";
      end if;

      declare
         Path            : constant String := To_String (Target_Location);
         File            : Ada.Text_IO.File_Type;
         Body_Text       : Unbounded_String;
         Delimiters_Seen : Natural := 0;
      begin
         Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);

         Read_Body_Loop :
         while not Ada.Text_IO.End_Of_File (File) loop
            declare
               Line : constant String := Ada.Text_IO.Get_Line (File);
            begin
               if Delimiters_Seen < 2 then
                  if Ada.Strings.Fixed.Trim (Line, Ada.Strings.Both)
                       = "---"
                  then
                     Delimiters_Seen := Delimiters_Seen + 1;
                  end if;
               else
                  Append (Body_Text, Line);
                  Append (Body_Text, ASCII.LF);
               end if;
            end;
         end loop Read_Body_Loop;

         Ada.Text_IO.Close (File);
         return To_String (Body_Text);
      exception
         when others =>
            if Ada.Text_IO.Is_Open (File) then
               Ada.Text_IO.Close (File);
            end if;

            raise Agent_Not_Found with
              "could not read agent definition file: " & Path;
      end;
   end Resolve_Agent_Def;

   function Format_Agent_Defs_For_Prompt
     (Defs : Agent_Def_Vectors.Vector) return String
   is
      Result : Unbounded_String;
   begin
      if Defs.Is_Empty then
         return "";
      end if;

      Append
        (Result,
         "The following agent definitions are available for use with"
         & " spawn_subagent."
         & ASCII.LF
         & "Pass the agent name to the agent field."
         & ASCII.LF
         & "Use the location to access resources packaged alongside"
         & " the definition."
         & ASCII.LF
         & ASCII.LF
         & "<available_agents>");

      for D of Defs loop
         Append
           (Result,
            ASCII.LF
            & "  <agent>"
            & ASCII.LF
            & "    <name>"
            & To_String (D.Name)
            & "</name>"
            & ASCII.LF
            & "    <description>"
            & To_String (D.Description)
            & "</description>"
            & ASCII.LF
            & "    <location>"
            & To_String (D.Location)
            & "</location>"
            & ASCII.LF
            & "  </agent>");
      end loop;

      Append (Result, ASCII.LF & "</available_agents>");
      return To_String (Result);
   end Format_Agent_Defs_For_Prompt;

end LLM.Agent_Defs;
