--  coyote_open — open a tool-call detail window in acme.
--
--  Usage: coyote_open coyote-session+UUID/tool/TOKEN
--
--  Parses the argument, locates the session JSONL file, extracts the
--  matching tool call and result, and opens a formatted acme window
--  named /+coyote-session/UUID8/tool/NAME-TOKEN.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Command_Line;
with Ada.Exceptions;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNAT.SHA256;
with GNATCOLL.JSON;          use GNATCOLL.JSON;
with Acme.Window;
with Nine_P.Client;
with Session_Lister;

procedure Coyote_Open is

   --  Unicode display constants (matching Coyote_App.Utils).

   UC_GEAR  : constant String :=  --  ⚙  U+2699
     Character'Val (16#E2#) & Character'Val (16#9A#) & Character'Val (16#99#);
   UC_CHECK : constant String :=  --  ✓  U+2713
     Character'Val (16#E2#) & Character'Val (16#9C#) & Character'Val (16#93#);
   UC_CROSS : constant String :=  --  ✗  U+2717
     Character'Val (16#E2#) & Character'Val (16#9C#) & Character'Val (16#97#);
   UC_DBL_H : constant String :=  --  ═  U+2550
     Character'Val (16#E2#) & Character'Val (16#95#) & Character'Val (16#90#);
   UC_HORIZ : constant String :=  --  ─  U+2500
     Character'Val (16#E2#) & Character'Val (16#94#) & Character'Val (16#80#);

   TOOL_PREFIX : constant String := "coyote-session+";
   TOOL_SEP    : constant String := "/tool/";

   --  Repeat Text exactly N times.
   function Str_Repeat (Text : String; N : Positive) return String is
      Result : String (1 .. Text'Length * N);
   begin
      for I in 0 .. N - 1 loop
         Result (I * Text'Length + 1 .. (I + 1) * Text'Length) := Text;
      end loop;
      return Result;
   end Str_Repeat;

   SEPARATOR : constant String := Str_Repeat (UC_DBL_H, 60);

   --  Return the string value of Field from Val, or "" if absent.
   function Get_Str
     (Val : JSON_Value; Field : UTF8_String) return String
   is
   begin
      if Val.Has_Field (Field)
        and then Val.Get (Field).Kind = JSON_String_Type
      then
         return Val.Get (Field).Get;
      end if;
      return "";
   end Get_Str;

   --  Return the direct message object from a JSONL line.
   --  Handles both direct {"role":...} and wrapped
   --  {"type":"message","message":{...}} forms.
   function Message_Object (Val : JSON_Value) return JSON_Value is
      Role : constant String := Get_Str (Val, "role");
   begin
      if Role = "user"
        or else Role = "assistant"
        or else Role = "toolResult"
      then
         return Val;
      end if;
      if Get_Str (Val, "type") = "message"
        and then Val.Has_Field ("message")
        and then Val.Get ("message").Kind = JSON_Object_Type
      then
         return Val.Get ("message");
      end if;
      return JSON_Null;
   end Message_Object;

   --  Format a JSON value for display in the tool window.
   --  Strings are returned raw; all other types use JSON serialisation.
   function Format_Value (Val : JSON_Value) return String is
   begin
      if Val.Kind = JSON_String_Type then
         return Val.Get;
      else
         return Val.Write;
      end if;
   end Format_Value;

   --  ── Scanning state (read and written by Process_Line below) ───────────

   Token        : Unbounded_String;
   Tool_Name    : Unbounded_String;
   Tool_Call_Id : Unbounded_String;
   Args_Val     : JSON_Value    := JSON_Null;
   Result_Text  : Unbounded_String;
   Is_Error     : Boolean       := False;
   Found_Call   : Boolean       := False;
   Found_Result : Boolean       := False;

   --  Inspect one JSONL line and update the scanning state.
   --  Searches for an assistant toolCall whose SHA-256 token matches
   --  Token, then for its corresponding toolResult.
   procedure Process_Line (Line_S : String) is
      Parse : constant Read_Result := Read (Line_S);
   begin
      if not Parse.Success then
         return;
      end if;
      declare
         Obj  : constant JSON_Value := Parse.Value;
         Msg  : constant JSON_Value := Message_Object (Obj);
         Role : constant String     :=
           (if Msg.Kind = JSON_Object_Type
            then Get_Str (Msg, "role")
            else "");
      begin
         if Role = "assistant"
           and then not Found_Call
           and then Msg.Has_Field ("content")
           and then
             Msg.Get ("content").Kind = JSON_Array_Type
         then
            declare
               Content : constant JSON_Array := Msg.Get ("content");
            begin
               Tool_Search :
               for I in 1 .. Length (Content) loop
                  declare
                     Block : constant JSON_Value := Get (Content, I);
                  begin
                     if Block.Kind = JSON_Object_Type
                       and then
                         Get_Str (Block, "type") = "toolCall"
                     then
                        declare
                           Call_Id : constant String :=
                             Get_Str (Block, "id");
                           Hash    : constant String :=
                             GNAT.SHA256.Digest (Call_Id) (1 .. 16);
                        begin
                           if Call_Id'Length > 0
                             and then Hash = To_String (Token)
                           then
                              Found_Call   := True;
                              Tool_Name    :=
                                To_Unbounded_String
                                  (Get_Str (Block, "name"));
                              Tool_Call_Id :=
                                To_Unbounded_String (Call_Id);
                              if Block.Has_Field ("arguments") then
                                 Args_Val :=
                                   Block.Get ("arguments");
                              end if;
                              exit Tool_Search;
                           end if;
                        end;
                     end if;
                  end;
               end loop Tool_Search;
            end;

         elsif Role = "toolResult"
           and then Found_Call
           and then not Found_Result
           and then
             Get_Str (Msg, "toolCallId") = To_String (Tool_Call_Id)
         then
            if Msg.Has_Field ("isError")
              and then
                Msg.Get ("isError").Kind = JSON_Boolean_Type
            then
               Is_Error := Msg.Get ("isError").Get;
            end if;
            if Msg.Has_Field ("content")
              and then
                Msg.Get ("content").Kind = JSON_Array_Type
            then
               declare
                  Content : constant JSON_Array :=
                    Msg.Get ("content");
               begin
                  for I in 1 .. Length (Content) loop
                     declare
                        Block : constant JSON_Value :=
                          Get (Content, I);
                     begin
                        if Block.Kind = JSON_Object_Type
                          and then
                            Get_Str (Block, "type") = "text"
                        then
                           declare
                              Text : constant String :=
                                Get_Str (Block, "text");
                           begin
                              if Length (Result_Text) > 0 then
                                 Append (Result_Text, ASCII.LF);
                              end if;
                              Append (Result_Text, Text);
                           end;
                        end if;
                     end;
                  end loop;
               end;
            end if;
            Found_Result := True;
         end if;
      end;
   end Process_Line;

   UUID : Unbounded_String;
   FS   : aliased Nine_P.Client.Fs;

begin
   --  Validate argument count.
   if Ada.Command_Line.Argument_Count /= 1 then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "usage: coyote_open coyote-session+UUID/tool/TOKEN");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   --  Parse UUID and TOKEN from the plumb argument.
   declare
      Arg : constant String := Ada.Command_Line.Argument (1);
   begin
      if Arg'Length <= TOOL_PREFIX'Length
        or else
          Arg (Arg'First .. Arg'First + TOOL_PREFIX'Length - 1)
          /= TOOL_PREFIX
      then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "coyote_open: argument must start with '"
            & TOOL_PREFIX & "'");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;
      declare
         Rest    : constant String :=
           Arg (Arg'First + TOOL_PREFIX'Length .. Arg'Last);
         Sep_Pos : Natural          := 0;
      begin
         Find_Sep :
         for I in Rest'First .. Rest'Last - TOOL_SEP'Length + 1 loop
            if Rest (I .. I + TOOL_SEP'Length - 1) = TOOL_SEP then
               Sep_Pos := I;
               exit Find_Sep;
            end if;
         end loop Find_Sep;
         if Sep_Pos = 0
           or else Sep_Pos = Rest'First
           or else Sep_Pos + TOOL_SEP'Length > Rest'Last
         then
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "coyote_open: malformed token: '" & Arg & "'");
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
            return;
         end if;
         UUID  :=
           To_Unbounded_String (Rest (Rest'First .. Sep_Pos - 1));
         Token :=
           To_Unbounded_String
             (Rest (Sep_Pos + TOOL_SEP'Length .. Rest'Last));
      end;
   end;

   --  Locate the session JSONL file.
   declare
      Session_Path : constant String :=
        Session_Lister.Find_Session_File (To_String (UUID));
   begin
      if Session_Path'Length = 0 then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "coyote_open: session not found: " & To_String (UUID));
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;

      --  Scan JSONL lines for the matching tool call and result.
      declare
         File   : Ada.Text_IO.File_Type;
         Line_N : Natural := 0;
      begin
         Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Session_Path);
         Scan_Loop :
         while not Ada.Text_IO.End_Of_File (File) loop
            declare
               Line_S : constant String :=
                 Ada.Text_IO.Get_Line (File);
            begin
               Line_N := Line_N + 1;
               if Line_N > 1 and then Line_S'Length > 0 then
                  Process_Line (Line_S);
               end if;
            end;
            exit Scan_Loop when Found_Result;
         end loop Scan_Loop;
         Ada.Text_IO.Close (File);
      exception
         when Ex : others =>
            if Ada.Text_IO.Is_Open (File) then
               Ada.Text_IO.Close (File);
            end if;
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "coyote_open: error reading session: "
               & Ada.Exceptions.Exception_Information (Ex));
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
            return;
      end;
   end;

   --  Report token not found.
   if not Found_Call then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "coyote_open: token not found in session: "
         & To_String (Token));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   --  Build the window body and open the acme window.
   declare
      UUID_S   : constant String := To_String (UUID);
      Token_S  : constant String := To_String (Token);
      Name_S   : constant String := To_String (Tool_Name);
      Arg_S    : constant String := Ada.Command_Line.Argument (1);
      UUID8    : constant String :=
        (if UUID_S'Length >= 8
         then UUID_S (UUID_S'First .. UUID_S'First + 7)
         else UUID_S);
      Win_Name : constant String :=
        "/+coyote-session/" & UUID8 & "/tool/"
        & Name_S & "-" & Token_S;
      Win_Body     : Unbounded_String;
   begin
      --  Line 1: gear icon, tool name, status symbol.
      Append
        (Win_Body,
         UC_GEAR & " " & Name_S & "  "
         & (if Is_Error
            then UC_CROSS & " error"
            else UC_CHECK & " ok")
         & ASCII.LF);

      --  Line 2: the plumb token (button-3 to re-open this window).
      Append (Win_Body, Arg_S & ASCII.LF);

      --  Separator rule.
      Append (Win_Body, SEPARATOR & ASCII.LF);

      --  One labelled section per argument key.
      if Args_Val.Kind = JSON_Object_Type then
         declare
            procedure Append_Arg
              (Field_Name  : UTF8_String;
               Field_Value : JSON_Value)
            is
            begin
               Append
                 (Win_Body,
                  ASCII.LF
                  & UC_HORIZ & UC_HORIZ & " " & Field_Name
                  & " " & UC_HORIZ & UC_HORIZ
                  & ASCII.LF
                  & Format_Value (Field_Value)
                  & ASCII.LF);
            end Append_Arg;
         begin
            Args_Val.Map_JSON_Object (Append_Arg'Access);
         end;
      elsif Args_Val.Kind /= JSON_Null_Type then
         Append
           (Win_Body,
            ASCII.LF
            & UC_HORIZ & UC_HORIZ & " arguments "
            & UC_HORIZ & UC_HORIZ
            & ASCII.LF
            & Format_Value (Args_Val)
            & ASCII.LF);
      end if;

      --  Result section.
      Append
        (Win_Body,
         ASCII.LF
         & UC_HORIZ & UC_HORIZ & " result " & UC_HORIZ & UC_HORIZ
         & ASCII.LF
         & (if Found_Result
            then To_String (Result_Text)
            else "(no result)")
         & ASCII.LF);

      --  Connect to acme and open the window.
      Nine_P.Client.Connect (FS, "acme");
      declare
         W : Acme.Window.Win := Acme.Window.New_Win (FS'Access);
      begin
         Acme.Window.Set_Name (W, FS'Access, Win_Name);
         Acme.Window.Append (W, FS'Access, To_String (Win_Body));
         Acme.Window.Ctl (W, FS'Access, "clean");
      end;
   exception
      when Ex : others =>
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "coyote_open: acme error: "
            & Ada.Exceptions.Exception_Information (Ex));
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
   end;

   Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);

end Coyote_Open;
