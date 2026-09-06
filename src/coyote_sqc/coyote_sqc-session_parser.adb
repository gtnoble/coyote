--  Coyote_SQC.Session_Parser body.
--
--  Project: coyote

with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Calendar.Time_Zones;
with Ada.Containers.Hashed_Maps;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Ada.Strings.Unbounded.Hash;
with Ada.Text_IO;
with GNAT.OS_Lib;
with GNATCOLL.JSON;

package body Coyote_SQC.Session_Parser is
   use type Ada.Calendar.Time;

   use Coyote_SQC.Data_Model;
   use GNATCOLL.JSON;

   --  ── Low-level JSON helpers ────────────────────────────────────────────

   function Get_String_Field
     (Value : JSON_Value; Field : String) return String
   is
   begin
      if Value.Kind = JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind = JSON_String_Type
      then
         return Value.Get (Field).Get;
      end if;
      return "";
   end Get_String_Field;

   function Get_Bool_Field
     (Value : JSON_Value; Field : String) return Boolean
   is
   begin
      if Value.Kind = JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind = JSON_Boolean_Type
      then
         return Value.Get (Field).Get;
      end if;
      return False;
   end Get_Bool_Field;

   function Get_Natural_Field
     (Value : JSON_Value; Field : String) return Natural
   is
      Raw : Long_Integer;
   begin
      if Value.Kind = JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind = JSON_Int_Type
      then
         Raw := Value.Get (Field).Get;
         if Raw >= 0 then
            return Natural (Raw);
         end if;
      end if;
      return 0;
   end Get_Natural_Field;

   --  Convert Unix milliseconds (UTC) to Ada.Calendar.Time (local).
   function Ms_To_Time (Ms : Long_Integer) return Ada.Calendar.Time is
      use Ada.Calendar;
      use Ada.Calendar.Time_Zones;
      --  UTC epoch represented in Ada.Calendar local time.
      Epoch_UTC : constant Time :=
        Ada.Calendar.Formatting.Value
          ("1970-01-01 00:00:00", Time_Zone => Time_Offset (0));
   begin
      return Epoch_UTC + Duration (Long_Float (Ms) / 1000.0);
   end Ms_To_Time;

   --  Parse "YYYY-MM-DDThh:mm:ss[.sss]Z".  Returns Unix epoch on error.
   --  Parse "YYYY-MM-DDThh:mm:ss[.sss]Z" (UTC) → Ada.Calendar.Time (local).
   function Parse_ISO8601 (S : String) return Ada.Calendar.Time is
      use Ada.Calendar;
      use Ada.Calendar.Time_Zones;
      Epoch_UTC : constant Time :=
        Ada.Calendar.Formatting.Value
          ("1970-01-01 00:00:00", Time_Zone => Time_Offset (0));
   begin
      if S'Length < 19
        or else (S'Length > 10 and then S (S'First + 10) /= 'T')
      then
         return Epoch_UTC;
      end if;
      declare
         --  Build "YYYY-MM-DD HH:MM:SS" from "YYYY-MM-DDThh:mm:ss..."
         Img : String (1 .. 19);
      begin
         Img (1 .. 10) := S (S'First .. S'First + 9);
         Img (11)      := ' ';
         Img (12 .. 19) := S (S'First + 11 .. S'First + 18);
         return Ada.Calendar.Formatting.Value (Img, Time_Zone => Time_Offset (0));
      end;
   exception
      when others =>
         return Epoch_UTC;
   end Parse_ISO8601;

   --  Strip "[Model → ...]\n?" prefix and collapse interior whitespace.
   function Clean_User_Message (S : String) return String is
      use Ada.Strings.Fixed;
      Start : Positive := S'First;
   begin
      if S'Length > 1 and then S (S'First) = '[' then
         declare
            Close : constant Natural := Index (S, "]");
         begin
            if Close > S'First then
               Start := Close + 1;
               if Start <= S'Last and then S (Start) = ASCII.LF then
                  Start := Start + 1;
               end if;
            end if;
         end;
      end if;

      declare
         Out_S    : Unbounded_String;
         In_Space : Boolean := False;
      begin
         for I in Start .. S'Last loop
            if S (I) = ' ' or else S (I) = ASCII.LF
              or else S (I) = ASCII.CR or else S (I) = ASCII.HT
            then
               if not In_Space then
                  Append (Out_S, ' ');
                  In_Space := True;
               end if;
            else
               Append (Out_S, S (I));
               In_Space := False;
            end if;
         end loop;
         return To_String (Out_S);
      end;
   end Clean_User_Message;

   --  ── Encode_Cwd ────────────────────────────────────────────────────────

   function Encode_Cwd (Cwd : String) return String is
      Start : constant Positive :=
        (if Cwd'Length > 0 and then Cwd (Cwd'First) = '/'
         then Cwd'First + 1 else Cwd'First);
      Slug  : String := Cwd (Start .. Cwd'Last);
   begin
      for I in Slug'Range loop
         if Slug (I) = '/' then
            Slug (I) := '-';
         end if;
      end loop;
      return "--" & Slug & "--";
   end Encode_Cwd;

   --  ── Parse_File ────────────────────────────────────────────────────────

   --  Map: tool call ID → index in the last turn's Tool_Calls vector.
   package TC_Index_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type        => Unbounded_String,
      Element_Type    => Positive,
      Hash            => Ada.Strings.Unbounded.Hash,
      Equivalent_Keys => Ada.Strings.Unbounded."=");

   procedure Parse_File
     (Path    :     String;
      Session : out Session_Record;
      Ok      : out Boolean)
   is
      use Ada.Calendar;

      Epoch : constant Ada.Calendar.Time :=
        Ada.Calendar.Time_Of (1970, 1, 1, 0.0);

      File    : Ada.Text_IO.File_Type;
      Line    : String (1 .. 65536);
      Last    : Natural;
      Is_V3   : Boolean := False;
      Has_Hdr : Boolean := False;
      Got_User : Boolean := False;

      Last_Model : Unbounded_String;
      TC_Map     : TC_Index_Maps.Map;

      procedure Process_Assistant_Msg (Msg : JSON_Value) is
         Turn      : Turn_Record;
         Usage_Obj : JSON_Value;
         Thinking_Char_Sum : Natural := 0;
      begin
         if Msg.Kind /= JSON_Object_Type then
            return;
         end if;
         TC_Map.Clear;
         Usage_Obj := (if Msg.Has_Field ("usage")
                       then Msg.Get ("usage") else JSON_Null);
         Turn.Turn_Index      := Natural (Session.Turns.Length) + 1;
         Turn.Input_Tokens    := Get_Natural_Field (Usage_Obj, "input");
         Turn.Output_Tokens   := Get_Natural_Field (Usage_Obj, "output");
         Turn.Thinking_Tokens := Get_Natural_Field (Usage_Obj, "thinking");

         if Msg.Has_Field ("content")
           and then Msg.Get ("content").Kind = JSON_Array_Type
         then
            declare
               Content : constant JSON_Array := Msg.Get ("content");
            begin
               for I in 1 .. GNATCOLL.JSON.Length (Content) loop
                  declare
                     Block      : constant JSON_Value :=
                       GNATCOLL.JSON.Get (Content, I);
                     Block_Type : constant String :=
                       Get_String_Field (Block, "type");
                  begin
                     if Block_Type = "thinking" then
                        Turn.Thinking_Enabled := True;
                        Thinking_Char_Sum     :=
                          Thinking_Char_Sum
                          + Get_String_Field (Block, "thinking")'Length;
                     elsif Block_Type = "toolCall" then
                        declare
                           TC_Id : constant String :=
                             Get_String_Field (Block, "id");
                           TC    : Tool_Call_Record;
                        begin
                           TC.Tool_Name :=
                             To_Unbounded_String
                               (Get_String_Field (Block, "name"));
                           declare
                              Arguments : constant JSON_Value :=
                                (if Block.Has_Field ("arguments")
                                 then Block.Get ("arguments")
                                 else JSON_Null);
                              Args_Str  : constant String :=
                                (if Arguments.Kind = JSON_Object_Type
                                 then Write (Arguments)
                                 elsif Arguments.Kind = JSON_String_Type
                                 then String'(Arguments.Get)
                                 else "{}");
                           begin
                              TC.Input_Tokens := Args_Str'Length / 4;
                              TC.Arguments := To_Unbounded_String (Args_Str);
                           end;
                           Turn.Tool_Calls.Append (TC);
                           if TC_Id'Length > 0 then
                              TC_Map.Include
                                (To_Unbounded_String (TC_Id),
                                 Positive (Turn.Tool_Calls.Length));
                           end if;
                        end;
                     end if;
                  end;
               end loop;
            end;
         end if;

         --  If the usage object had no thinking-token count (e.g. sessions
         --  from the pi agent), estimate from the accumulated thinking-text
         --  length using the same 4-chars-per-token heuristic as the
         --  Anthropic streaming provider.
         if Turn.Thinking_Tokens = 0 and then Thinking_Char_Sum > 0 then
            Turn.Thinking_Tokens := Natural'Max (1, Thinking_Char_Sum / 4);
         end if;

         declare
            Turn_Cache_Read  : constant Natural :=
              Get_Natural_Field (Usage_Obj, "cacheRead");
            Turn_Cache_Write : constant Natural :=
              Get_Natural_Field (Usage_Obj, "cacheWrite");
         begin
            --  Normalise Input_Tokens to total context window tokens.
            --  Anthropic reports input_tokens as the non-cached fraction
            --  only; OpenAI's prompt_tokens already includes cached tokens.
            --  Adding cacheRead + cacheWrite for Anthropic makes both
            --  providers use the same definition: total tokens submitted to
            --  the model's context window.
            if Index (Last_Model, "anthropic/") = 1
               or else Turn_Cache_Read > Turn.Input_Tokens
            then
               Turn.Input_Tokens :=
                 Turn.Input_Tokens + Turn_Cache_Read + Turn_Cache_Write;
            end if;
            Turn.Cache_Read_Tokens  := Turn_Cache_Read;
            Turn.Cache_Write_Tokens := Turn_Cache_Write;
            Session.Total_Input_Tokens  :=
              Session.Total_Input_Tokens  + Turn.Input_Tokens;
            Session.Total_Output_Tokens :=
              Session.Total_Output_Tokens + Turn.Output_Tokens;
            Session.Total_Cache_Read_Tokens  :=
              Session.Total_Cache_Read_Tokens + Turn_Cache_Read;
            Session.Total_Cache_Write_Tokens :=
              Session.Total_Cache_Write_Tokens + Turn_Cache_Write;
            --  Uncached input = total context - cache hits - cache fills.
            Session.Total_Uncached_Input_Tokens :=
              Session.Total_Uncached_Input_Tokens
              + (if Turn.Input_Tokens >= Turn_Cache_Read + Turn_Cache_Write
                 then Turn.Input_Tokens - Turn_Cache_Read - Turn_Cache_Write
                 else 0);
         end;
         Session.Turns.Append (Turn);
      end Process_Assistant_Msg;

      procedure Process_Tool_Result (Msg : JSON_Value) is
         TC_Id    : constant Unbounded_String :=
           To_Unbounded_String (Get_String_Field (Msg, "toolCallId"));
         Is_Error : constant Boolean := Get_Bool_Field (Msg, "isError");
         Cursor   : TC_Index_Maps.Cursor;
      begin
         if Session.Turns.Is_Empty then
            return;
         end if;

         --  Estimate output tokens from the total length of text content.
         declare
            Result_Char_Sum : Natural := 0;
         begin
            if Msg.Has_Field ("content")
              and then Msg.Get ("content").Kind = JSON_Array_Type
            then
               declare
                  Content : constant JSON_Array := Msg.Get ("content");
               begin
                  for I in 1 .. GNATCOLL.JSON.Length (Content) loop
                     declare
                        Block : constant JSON_Value :=
                          GNATCOLL.JSON.Get (Content, I);
                     begin
                        if Get_String_Field (Block, "type") = "text" then
                           Result_Char_Sum :=
                             Result_Char_Sum
                             + Get_String_Field (Block, "text")'Length;
                        end if;
                     end;
                  end loop;
               end;
            end if;

            Cursor := TC_Map.Find (TC_Id);
            if TC_Index_Maps.Has_Element (Cursor) then
               declare
                  Last_Idx  : constant Positive := Session.Turns.Last_Index;
                  Last_Turn : Turn_Record :=
                    Session.Turns.Element (Last_Idx);
                  TC_Idx    : constant Positive :=
                    TC_Index_Maps.Element (Cursor);
                  TC        : Tool_Call_Record :=
                    Last_Turn.Tool_Calls.Element (TC_Idx);
               begin
                  TC.Output_Tokens := Result_Char_Sum / 4;
                  if Is_Error then
                     TC.Failed := True;
                  end if;
                  Last_Turn.Tool_Calls.Replace_Element (TC_Idx, TC);
                  Session.Turns.Replace_Element (Last_Idx, Last_Turn);
               end;
            end if;
         end;
      end Process_Tool_Result;

      procedure Process_User_Msg (Msg : JSON_Value) is
      begin
         if Got_User then
            return;
         end if;
         if not Msg.Has_Field ("content") then
            return;
         end if;
         if Msg.Get ("content").Kind = JSON_String_Type then
            Session.First_User_Message :=
              To_Unbounded_String
                (Clean_User_Message (Msg.Get ("content").Get));
            Got_User := True;
            return;
         end if;
         if Msg.Get ("content").Kind = JSON_Array_Type then
            declare
               Content : constant JSON_Array := Msg.Get ("content");
            begin
               for I in 1 .. GNATCOLL.JSON.Length (Content) loop
                  declare
                     Block : constant JSON_Value :=
                       GNATCOLL.JSON.Get (Content, I);
                  begin
                     if Get_String_Field (Block, "type") = "text"
                       and then Block.Has_Field ("text")
                     then
                        Session.First_User_Message :=
                          To_Unbounded_String
                            (Clean_User_Message
                               (Get_String_Field (Block, "text")));
                        Got_User := True;
                        return;
                     end if;
                  end;
               end loop;
            end;
         end if;
      end Process_User_Msg;

      procedure Process_Message (Msg : JSON_Value) is
         Role : constant String := Get_String_Field (Msg, "role");
      begin
         if    Role = "assistant"  then Process_Assistant_Msg (Msg);
         elsif Role = "toolResult" then Process_Tool_Result (Msg);
         elsif Role = "user"       then Process_User_Msg (Msg);
         end if;
      end Process_Message;

      procedure Process_Line (Raw : String) is
         Root : JSON_Value;
      begin
         if Raw'Length = 0 then
            return;
         end if;
         Root := Read (Raw);
         if Root.Kind /= JSON_Object_Type then
            return;
         end if;

         if not Has_Hdr then
            Has_Hdr := True;
            if Root.Has_Field ("type")
              and then Get_String_Field (Root, "type") = "session"
            then
               Is_V3 := True;
               Session.Session_Id :=
                 To_Unbounded_String (Get_String_Field (Root, "id"));
               if Root.Has_Field ("timestamp") then
                  Session.Start_Time :=
                    Parse_ISO8601 (Root.Get ("timestamp").Get);
               end if;
               Session.Source_Directory :=
                 To_Unbounded_String (Get_String_Field (Root, "cwd"));
            else
               Session.Session_Id :=
                 To_Unbounded_String (Get_String_Field (Root, "id"));
               if Root.Has_Field ("createdAt")
                 and then Root.Get ("createdAt").Kind = JSON_Int_Type
               then
                  Session.Start_Time :=
                    Ms_To_Time (Root.Get ("createdAt").Get);
               end if;
               Session.Source_Directory :=
                 To_Unbounded_String (Get_String_Field (Root, "workDir"));
            end if;
            return;
         end if;

         if Is_V3 then
            declare
               Rec_Type : constant String := Get_String_Field (Root, "type");
            begin
               if Rec_Type = "model_change" then
                  declare
                     Provider : constant String :=
                       Get_String_Field (Root, "provider");
                     Model_Id : constant String :=
                       Get_String_Field (Root, "modelId");
                  begin
                     if Provider'Length > 0 or else Model_Id'Length > 0 then
                        Last_Model :=
                          To_Unbounded_String (Provider & "/" & Model_Id);
                     end if;
                  end;
               elsif Rec_Type = "message"
                 and then Root.Has_Field ("message")
               then
                  Process_Message (Root.Get ("message"));
               end if;
            end;
         else
            if Root.Has_Field ("type")
              and then Get_String_Field (Root, "type") = "model_change"
            then
               declare
                  Provider : constant String :=
                    Get_String_Field (Root, "provider");
                  Model_Id : constant String :=
                    Get_String_Field (Root, "modelId");
               begin
                  if Provider'Length > 0 or else Model_Id'Length > 0 then
                     Last_Model :=
                       To_Unbounded_String (Provider & "/" & Model_Id);
                  end if;
               end;
            else
               Process_Message (Root);
            end if;
         end if;
      end Process_Line;

   begin
      Ok      := False;
      Session :=
        (Start_Time          => Epoch,
         Session_Id          => Null_Unbounded_String,
         Source_Directory    => Null_Unbounded_String,
         Model               => Null_Unbounded_String,
         First_User_Message  => Null_Unbounded_String,
         Total_Input_Tokens  => 0,
         Total_Output_Tokens      => 0,
         Total_Cache_Read_Tokens  => 0,
         Total_Cache_Write_Tokens => 0,
         Total_Uncached_Input_Tokens => 0,
         Turns               => Turn_Vectors.Empty_Vector,
         File_Path           => Null_Unbounded_String,
         File_Mtime          => Epoch);

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Full_Line : Unbounded_String;
         begin
            loop
               Ada.Text_IO.Get_Line (File, Line, Last);
               Append (Full_Line, Line (1 .. Last));
               exit when Last < Line'Last;
            end loop;
            begin
               Process_Line (To_String (Full_Line));
            exception
               when E : others =>
                  Ada.Text_IO.Put_Line
                    (Ada.Text_IO.Standard_Error,
                     "coyote_sqc: skipping malformed JSONL line in "
                     & Path & ": "
                     & Ada.Exceptions.Exception_Information (E));
            end;
         end;
      end loop;
      Ada.Text_IO.Close (File);

      Session.Model := Last_Model;
      Ok            := not Session.Turns.Is_Empty;
      if Ok then
         Session.File_Path  := To_Unbounded_String (Path);
         Session.File_Mtime := Ada.Directories.Modification_Time (Path);
      end if;
   exception
      when Ada.Text_IO.Name_Error =>
         Ok := False;
   end Parse_File;

   procedure Load_Sessions
     (Source_Directories      : String_Vectors.Vector;
      Model_Filter            : String_Vectors.Vector;
      Sessions                : in out Session_Vectors.Vector;
      Analyze_All_Directories : Boolean := False;
      Previous_Sessions       :  Session_Vectors.Vector :=
        Session_Vectors.Empty_Vector)
   is
      use Ada.Directories;

      Home          : constant String := GNAT.OS_Lib.Getenv ("HOME").all;
      Sessions_Root : constant String := Home & "/.coyote/sessions/";

      --  Map from file path to index in Previous_Sessions for fast lookup.
      package Path_Maps is new Ada.Containers.Hashed_Maps
        (Key_Type        => Unbounded_String,
         Element_Type    => Positive,
         Hash            => Ada.Strings.Unbounded.Hash,
         Equivalent_Keys => Ada.Strings.Unbounded."=");

      Path_Map : Path_Maps.Map;

      --  Scan all *.jsonl files in Dir, appending matching sessions.
      procedure Scan_Dir (Dir : String) is
      begin
         if Exists (Dir) and then Kind (Dir) = Directory then
            declare
               Search : Search_Type;
               Dirent : Directory_Entry_Type;
            begin
               Start_Search (Search, Dir, "*.jsonl",
                             (Ordinary_File => True, others => False));
               while More_Entries (Search) loop
                  Get_Next_Entry (Search, Dirent);
                  declare
                     File_Path_S  : constant String :=
                       Full_Name (Dirent);
                     File_Mtime_V : constant Ada.Calendar.Time :=
                       Modification_Time (File_Path_S);
                     Path_US      : constant Unbounded_String :=
                       To_Unbounded_String (File_Path_S);
                     Cursor       : constant Path_Maps.Cursor :=
                       Path_Map.Find (Path_US);
                     Appended     : Boolean := False;
                  begin
                     --  Reuse cached session when file is unchanged.
                     if Path_Maps.Has_Element (Cursor) then
                        declare
                           Old : constant Session_Record :=
                             Previous_Sessions
                               (Path_Maps.Element (Cursor));
                        begin
                           if Old.File_Mtime = File_Mtime_V then
                              if Model_Filter.Is_Empty then
                                 Sessions.Append (Old);
                                 Appended := True;
                              else
                                 for F of Model_Filter loop
                                    if To_String (F) =
                                       To_String (Old.Model)
                                    then
                                       Sessions.Append (Old);
                                       Appended := True;
                                       exit;
                                    end if;
                                 end loop;
                              end if;
                           end if;
                        end;
                     end if;
                     --  Parse the file only when not reused from cache.
                     if not Appended then
                        declare
                           Session : Session_Record;
                           Ok      : Boolean;
                        begin
                           Parse_File (File_Path_S, Session, Ok);
                           if Ok then
                              if Model_Filter.Is_Empty then
                                 Sessions.Append (Session);
                              else
                                 for F of Model_Filter loop
                                    if To_String (F) =
                                       To_String (Session.Model)
                                    then
                                       Sessions.Append (Session);
                                       exit;
                                    end if;
                                 end loop;
                              end if;
                           end if;
                        end;
                     end if;
                  end;
               end loop;
               End_Search (Search);
            end;
         end if;
      exception
         when E : others =>
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "coyote_sqc: error scanning session directory "
               & Dir & ": "
               & Ada.Exceptions.Exception_Information (E));
      end Scan_Dir;

   begin
      --  Build file-path → index map from Previous_Sessions for O(1) lookup.
      for I in Previous_Sessions.First_Index .. Previous_Sessions.Last_Index loop
         Path_Map.Include
           (Previous_Sessions (I).File_Path, I);
      end loop;

      if Analyze_All_Directories then
         --  Enumerate every slug subdirectory under ~/.coyote/sessions/.
         if Exists (Sessions_Root)
           and then Kind (Sessions_Root) = Directory
         then
            declare
               Search : Search_Type;
               Dirent : Directory_Entry_Type;
            begin
               Start_Search (Search, Sessions_Root, "",
                             (Directory => True, others => False));
               while More_Entries (Search) loop
                  Get_Next_Entry (Search, Dirent);
                  declare
                     Sub : constant String := Simple_Name (Dirent);
                  begin
                     --  Skip the "." and ".." entries.
                     if Sub /= "." and then Sub /= ".." then
                        Scan_Dir (Full_Name (Dirent));
                     end if;
                  end;
               end loop;
               End_Search (Search);
            exception
               when E : others =>
                  Ada.Text_IO.Put_Line
                    (Ada.Text_IO.Standard_Error,
                     "coyote_sqc: error enumerating session root "
                     & Sessions_Root & ": "
                     & Ada.Exceptions.Exception_Information (E));
            end;
         end if;
      else
         --  Scan only the explicitly listed source directories.
         for Cwd_US of Source_Directories loop
            declare
               Cwd : constant String := To_String (Cwd_US);
               Dir : constant String :=
                 Sessions_Root & Encode_Cwd (Cwd) & "/";
            begin
               Scan_Dir (Dir);
            end;
         end loop;
      end if;

      --  Sort sessions by Start_Time ascending.
      declare
         function Before (A, B : Session_Record) return Boolean is
           (A.Start_Time < B.Start_Time);
         package Sess_Sort is new Session_Vectors.Generic_Sorting
           ("<" => Before);
      begin
         Sess_Sort.Sort (Sessions);
      end;
   end Load_Sessions;

end Coyote_SQC.Session_Parser;
