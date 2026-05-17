--  Coyote_App.History body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Containers.Vectors;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNATCOLL.JSON;          use GNATCOLL.JSON;
with Coyote_App.Utils;      use Coyote_App.Utils;
with Session_Lister;         use Session_Lister;

package body Coyote_App.History is

   --  ── Session history replay types ──────────────────────────────────────
   --
   --  Used by Render_Session_History to map tool-call IDs to their results
   --  during the first (collection) pass over a session JSONL file.

   type Tool_Result_Entry is record
      Id     : Unbounded_String;
      Text   : Unbounded_String;
      Is_Err : Boolean := False;
   end record;

   package TR_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Tool_Result_Entry);

   --  ── Read_Line ─────────────────────────────────────────────────────────
   --
   --  Read one complete line from File into an Unbounded_String.
   --  Unlike the Ada.Text_IO.Get_Line function form, this never overflows
   --  the stack on very long lines: it uses the fixed-buffer procedure form
   --  in a loop and simply appends each chunk to the result.

   function Read_Line
     (File : Ada.Text_IO.File_Type) return Unbounded_String
   is
      Chunk  : String (1 .. 65_536);   --  64 KiB per iteration
      Last   : Natural;
      Result : Unbounded_String;
   begin
      loop
         Ada.Text_IO.Get_Line (File, Chunk, Last);
         Append (Result, Chunk (1 .. Last));
         exit when Last < Chunk'Last;
      end loop;
      return Result;
   end Read_Line;

   --  ── Render_Session_History ────────────────────────────────────────────
   --
   --  Read the JSONL file for UUID and replay the full conversation history
   --  through Frontend.  Two passes are made over the file:
   --
   --    Pass 1 — collect toolResult entries (id, text, isError) so that
   --             each toolCall block can display its outcome inline.
   --
   --    Pass 2 — render all events in order: model_change, compaction,
   --             user messages, assistant messages (thinking, text, tools).
   --
   --  On return, State.Turn_Count and State.Turn_Tokens are updated from
   --  the replayed history so subsequent live turns are numbered correctly.

   procedure Render_Session_History
     (UUID     : String;
      Frontend : in out Coyote_App.Frontend.Instance'Class;
      State    : in out App_State;
      PID      : String := "")
   is
      Path         : constant String :=
        Find_Session_File (UUID);
      Tool_Results : TR_Vectors.Vector;
      Last_Input   : Natural         := 0;
      Last_Output  : Natural         := 0;
      Turn_Input   : Natural         := 0;
      Turn_Output  : Natural         := 0;
      Cur_Model    : Unbounded_String :=
        To_Unbounded_String (State.Current_Model);
      Turns_Rendered : Natural         := 0;
      In_Turn        : Boolean         := False;
      Saw_Asst_Text  : Boolean         := False;

      --  Flush any accumulated thinking content through the frontend.
      procedure Flush_Thinking
        (Thinking_Parts : in out Unbounded_String)
      is
      begin
         if Length (Thinking_Parts) > 0 then
            Frontend.Begin_Thinking;
            Frontend.Append_Thinking (To_String (Thinking_Parts));
            Frontend.End_Thinking;
            Thinking_Parts := Null_Unbounded_String;
         end if;
      end Flush_Thinking;

      --  Return the Tool_Result_Entry whose Id matches, or a blank entry.
      function Find_TR (Id : String) return Tool_Result_Entry is
      begin
         for TR of Tool_Results loop
            if To_String (TR.Id) = Id then
               return TR;
            end if;
         end loop;
         return (Id     => Null_Unbounded_String,
                 Text   => Null_Unbounded_String,
                 Is_Err => False);
      end Find_TR;

      --  Return the direct message object for either supported session
      --  format, or JSON_Null for non-message lines.
      function Message_Object (Value : JSON_Value) return JSON_Value is
         Role : constant String := Get_String (Value, "role");
      begin
         if Role = "user"
           or else Role = "assistant"
           or else Role = "toolResult"
         then
            return Value;
         end if;

         if Get_String (Value, "type") = "message" then
            return Get_Object (Value, "message");
         end if;

         return JSON_Null;
      end Message_Object;

   begin
      if Path'Length = 0 then
         Frontend.Append_Notice
           (Coyote_App.Frontend.Error,
            "session file not found for " & UUID);
         return;
      end if;

      --  ── Pass 1: collect tool results ──────────────────────────────────
      declare
         File : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
         while not Ada.Text_IO.End_Of_File (File) loop
            declare
               Line  : constant String      := To_String (Read_Line (File));
               Parse : constant Read_Result := Read (Line);
            begin
               if Parse.Success then
                  declare
                     Ev  : constant JSON_Value := Parse.Value;
                     Msg : constant JSON_Value := Message_Object (Ev);
                     Role : constant String :=
                       (if Msg.Kind = JSON_Object_Type
                        then Get_String (Msg, "role")
                        else "");
                  begin
                     if Msg.Kind = JSON_Object_Type
                       and then Role = "toolResult"
                     then
                        declare
                           Tid    : constant String  :=
                             Get_String (Msg, "toolCallId");
                           Is_Err : constant Boolean :=
                             Get_Boolean (Msg, "isError");
                           Parts  : Unbounded_String;
                        begin
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
                                           Get_String (Block, "type") = "text"
                                       then
                                          if Length (Parts) > 0 then
                                             Append (Parts, ASCII.LF);
                                          end if;
                                          Append
                                            (Parts,
                                             Get_String (Block, "text"));
                                       end if;
                                    end;
                                 end loop;
                              end;
                           end if;
                           if Tid'Length > 0 then
                              Tool_Results.Append
                                ((Id     => To_Unbounded_String (Tid),
                                  Text   => Parts,
                                  Is_Err => Is_Err));
                           end if;
                        end;
                     end if;
                  end;
               end if;
            end;
         end loop;
         Ada.Text_IO.Close (File);
      exception
         when Ex : others =>
            if Ada.Text_IO.Is_Open (File) then
               Ada.Text_IO.Close (File);
            end if;
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "[!] could not read session file: "
               & Ada.Exceptions.Exception_Message (Ex));
            Frontend.Append_Notice
              (Coyote_App.Frontend.Error,
               "could not read session file: "
               & Ada.Exceptions.Exception_Message (Ex));
            return;
      end;

      --  ── Pass 2: render conversation history ───────────────────────────
      declare
         File : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
         while not Ada.Text_IO.End_Of_File (File) loop
            declare
               Line  : constant String      := To_String (Read_Line (File));
               Parse : constant Read_Result := Read (Line);
            begin
               if Parse.Success then
                  declare
                     Ev : constant JSON_Value := Parse.Value;
                     Kind : constant String := Get_String (Ev, "type");
                     Msg : constant JSON_Value := Message_Object (Ev);
                     Role : constant String :=
                       (if Msg.Kind = JSON_Object_Type
                        then Get_String (Msg, "role")
                        else "");
                  begin

                     --  ── model_change ──────────────────────────────────
                     if Kind = "model_change" then
                        declare
                           Provider  : constant String :=
                             Get_String (Ev, "provider");
                           Model_Id  : constant String :=
                             Get_String (Ev, "modelId");
                        begin
                           if Provider'Length > 0
                             and then Model_Id'Length > 0
                           then
                              declare
                                 New_Model : constant String :=
                                   Provider & "/" & Model_Id;
                              begin
                                 if New_Model /= To_String (Cur_Model) then
                                    Cur_Model :=
                                      To_Unbounded_String (New_Model);
                                    Frontend.Append_Notice
                                      (Coyote_App.Frontend.Info,
                                       ASCII.LF
                                       & "[Model " & UC_TRI_R & " "
                                       & New_Model & "]" & ASCII.LF);
                                 end if;
                              end;
                           end if;
                        end;

                     --  ── compaction ────────────────────────────────────
                     elsif Kind = "compaction" then
                        declare
                           Summary : constant String :=
                             Get_String (Ev, "summary");
                           Start   : Natural         :=
                             Summary'First;
                           Compact_Buf : Unbounded_String;
                        begin
                           if Summary'Length > 0 then
                              Append
                                (Compact_Buf,
                                 ASCII.LF
                                 & UC_HORIZ & UC_HORIZ & " Compacted "
                                 & Str_Repeat (UC_HORIZ, 47)
                                 & ASCII.LF);
                              for I in Summary'Range loop
                                 if Summary (I) = ASCII.LF then
                                    Append
                                      (Compact_Buf,
                                       UC_BOX_V & " "
                                       & Summary (Start .. I - 1)
                                       & ASCII.LF);
                                    Start := I + 1;
                                 end if;
                              end loop;
                              if Start <= Summary'Last then
                                 Append
                                   (Compact_Buf,
                                    UC_BOX_V & " "
                                    & Summary (Start .. Summary'Last)
                                    & ASCII.LF);
                              end if;
                              Append
                                (Compact_Buf,
                                 UC_HORIZ & UC_HORIZ & " "
                                 & Str_Repeat (UC_HORIZ, 57)
                                 & ASCII.LF);
                              Frontend.Append_Notice
                                (Coyote_App.Frontend.Info,
                                 To_String (Compact_Buf));
                           end if;
                        end;

                     --  ── message ───────────────────────────────────────
                     elsif Msg.Kind = JSON_Object_Type then

                        --  User turn
                        if Role = "user" then
                           --  If the previous turn was complete, emit its
                           --  footer before this user message.
                           if In_Turn and then Saw_Asst_Text then
                              Turns_Rendered := Turns_Rendered + 1;
                              Frontend.Append_Turn_Footer
                                (Format_Turn_Footer
                                   (Turn_N        => Turns_Rendered,
                                    UUID          => UUID,
                                    PID           => PID,
                                    Input_Tokens  => Turn_Input,
                                    Output_Tokens => Turn_Output,
                                    Ctx_Window    =>
                                      State.Context_Window,
                                    Model_Text    =>
                                      To_String (Cur_Model)));
                           end if;
                           In_Turn       := True;
                           Saw_Asst_Text := False;
                           Turn_Input    := 0;
                           Turn_Output   := 0;
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
                                           Get_String (Block, "type") = "text"
                                       then
                                          declare
                                             Text    : constant String :=
                                               Get_String (Block, "text");
                                             Trimmed : constant String :=
                                               Ada.Strings.Fixed.Trim
                                                 (Text, Ada.Strings.Both);
                                          begin
                                             if Trimmed'Length > 0 then
                                                Frontend.Append_Notice
                                                  (Coyote_App.Frontend.Info,
                                                   ASCII.LF
                                                   & UC_TRI_R & " "
                                                   & Trimmed
                                                   & ASCII.LF);
                                             end if;
                                          end;
                                       end if;
                                    end;
                                 end loop;
                              end;
                           end if;

                        --  Assistant turn
                        elsif Role = "assistant" then
                           declare
                              Provider : constant String :=
                                Get_String (Msg, "provider");
                              Model_Id : constant String :=
                                Get_String (Msg, "model");
                              Usage    : constant JSON_Value :=
                                Get_Object (Msg, "usage");
                           begin
                              if Provider'Length > 0
                                and then Model_Id'Length > 0
                              then
                                 Cur_Model :=
                                   To_Unbounded_String
                                     (Provider & "/" & Model_Id);
                              end if;
                              --  Capture token usage for context restore.
                              if Usage.Kind /= JSON_Null_Type then
                                 declare
                                    Input_Count  : constant Natural :=
                                      Get_Integer (Usage, "input")
                                      + Get_Integer (Usage, "cacheRead")
                                      + Get_Integer (Usage, "cacheWrite");
                                    Output_Count : constant Natural :=
                                      Get_Integer (Usage, "output");
                                 begin
                                    Turn_Input  := Input_Count;
                                    Turn_Output := Output_Count;
                                    if Input_Count > 0
                                      or else Output_Count > 0
                                    then
                                       Last_Input  := Input_Count;
                                       Last_Output := Output_Count;
                                    end if;
                                 end;
                              end if;
                           end;
                           --  Render content blocks.
                           if Msg.Has_Field ("content")
                             and then
                               Msg.Get ("content").Kind = JSON_Array_Type
                           then
                              declare
                                 Content        : constant JSON_Array :=
                                   Msg.Get ("content");
                                 Thinking_Parts : Unbounded_String;
                              begin
                                 for I in 1 .. Length (Content) loop
                                    declare
                                       Block : constant JSON_Value :=
                                         Get (Content, I);
                                       BType : constant String    :=
                                         Get_String (Block, "type");
                                    begin
                                       --  thinking block — accumulate
                                       if BType = "thinking" then
                                          declare
                                             Th : constant String :=
                                               Ada.Strings.Fixed.Trim
                                                 (Get_String
                                                    (Block, "thinking"),
                                                  Ada.Strings.Both);
                                          begin
                                             if Length (Thinking_Parts) > 0
                                             then
                                                Append
                                                  (Thinking_Parts,
                                                   "" & ASCII.LF & ASCII.LF);
                                             end if;
                                             Append (Thinking_Parts, Th);
                                          end;

                                       --  text block
                                       elsif BType = "text" then
                                          declare
                                             Text : constant String :=
                                               Get_String (Block, "text");
                                          begin
                                             if Text'Length > 0 then
                                                Flush_Thinking
                                                  (Thinking_Parts);
                                                Frontend.Append_Text (Text);
                                                Frontend.End_Text_Block;
                                                Saw_Asst_Text := True;
                                             end if;
                                          end;

                                       --  toolCall block
                                       elsif BType = "toolCall" then
                                          Flush_Thinking (Thinking_Parts);
                                          declare
                                             Tool_Id   : constant String :=
                                               Get_String (Block, "id");
                                             Tool_Name : constant String :=
                                               Get_String (Block, "name");
                                             Args      : constant JSON_Value :=
                                               Get_Object
                                                 (Block, "arguments");
                                             TR        : constant
                                               Tool_Result_Entry :=
                                                 Find_TR (Tool_Id);
                                             Args_Json : constant String :=
                                               (if Args.Kind
                                                   = JSON_Object_Type
                                                then Write (Args)
                                                else "{}");
                                             Status    :
                                               Coyote_App.Frontend
                                                 .Tool_End_Status :=
                                                   Coyote_App.Frontend
                                                     .Success;
                                          begin
                                             if TR.Is_Err then
                                                Status :=
                                                  Coyote_App.Frontend.Error;
                                             end if;
                                             Frontend.Append_Text
                                               ("" & ASCII.LF);
                                             Frontend.Begin_Tool
                                               (Name       => Tool_Name,
                                                Args_Json  => Args_Json,
                                                Session_Id => UUID,
                                                Tool_Id    => Tool_Id);
                                             Frontend.End_Tool
                                               (Tool_Id     => Tool_Id,
                                                Status      => Status,
                                                Result_Text =>
                                                  To_String (TR.Text));
                                          end;
                                       end if;
                                    end;
                                 end loop;
                                 --  Flush any trailing thinking block.
                                 Flush_Thinking (Thinking_Parts);
                              end;
                           end if;
                        end if;
                        --  toolResult role: skip (consumed in pass 1).
                     end if;
                  end;
               end if;
            end;
         end loop;
         Ada.Text_IO.Close (File);
      exception
         when Ex : others =>
            if Ada.Text_IO.Is_Open (File) then
               Ada.Text_IO.Close (File);
            end if;
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "[!] error rendering session history: "
               & Ada.Exceptions.Exception_Message (Ex));
            Frontend.Append_Notice
              (Coyote_App.Frontend.Error,
               "error rendering session history: "
               & Ada.Exceptions.Exception_Message (Ex));
            return;
      end;

      --  Emit footer for the final rendered turn (if any).
      if In_Turn and then Saw_Asst_Text then
         Turns_Rendered := Turns_Rendered + 1;
         Frontend.Append_Turn_Footer
           (Format_Turn_Footer
              (Turn_N        => Turns_Rendered,
               UUID          => UUID,
               PID           => PID,
               Input_Tokens  => Turn_Input,
               Output_Tokens => Turn_Output,
               Ctx_Window    => State.Context_Window,
               Model_Text    => To_String (Cur_Model)));
      end if;
      --  Restore turn count so subsequent live turns are numbered correctly.
      State.Set_Turn_Count (Turns_Rendered);
      if Last_Input > 0 or else Last_Output > 0 then
         State.Set_Turn_Tokens (Last_Input, Last_Output);
      end if;
   end Render_Session_History;

end Coyote_App.History;
