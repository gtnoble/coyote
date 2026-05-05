--  Coyote_App.Dispatch body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Exceptions;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNATCOLL.JSON;
with LLM.Types;
with Nine_P.Client;          use Nine_P.Client;
with Coyote_App.Utils;      use Coyote_App.Utils;

package body Coyote_App.Dispatch is

   use type GNATCOLL.JSON.JSON_Value_Type;
   use type LLM.Events.Message_Update_Kind;
   use type LLM.Types.Stop_Reason;

   function Stop_Reason_Image
     (Reason : LLM.Types.Stop_Reason) return String
   is
   begin
      case Reason is
         when LLM.Types.Stop       => return "stop";
         when LLM.Types.Length     => return "length";
         when LLM.Types.Tool_Use   => return "toolUse";
         when LLM.Types.Aborted    => return "aborted";
         when LLM.Types.Error_Stop => return "error";
         when others               => return "unknown";
      end case;
   end Stop_Reason_Image;

   --  Build the one-line status string.
   function Format_Status
     (State : App_State;
      Extra : String := "ready") return String
   is
      Model_Text   : constant String  := State.Current_Model;
      Agent_Text   : constant String  := State.Current_Agent;
      Session_Text : constant String  := State.Session_Id;
      Think_Text   : constant String  := State.Current_Thinking;
      Input_Tokens : constant Natural := State.Turn_Input_Tokens;
      Ctx_Window   : constant Natural := State.Context_Window;

      Model_Part   : constant String :=
        (if Model_Text'Length > 0
         then " [" & Model_Text & "]"
         else "");
      Agent_Part   : constant String :=
        (if Agent_Text'Length > 0
         then " <" & Agent_Stem (Agent_Text) & ">"
         else "");
      Think_Part   : constant String :=
        (if Think_Text'Length > 0 then " ~" & Think_Text else "");
      Session_Part : constant String :=
        (if Session_Text'Length >= 8
         then " session:"
              & Session_Text (Session_Text'First
                               .. Session_Text'First + 7)
         else "");
      Context_Part : constant String :=
        (if Input_Tokens > 0 and then Ctx_Window > 0
         then " " & Format_Kilo (Input_Tokens)
              & "/" & Format_Kilo (Ctx_Window)
              & " (" & Natural_Image (Input_Tokens * 100 / Ctx_Window)
              & "%)"
         else "");
   begin
      return UC_BULLET & " " & Extra
             & Agent_Part & Model_Part & Think_Part
             & Context_Part & Session_Part;
   end Format_Status;

   --  Append a live turn footer using the current state fields and advance
   --  the turn counter.
   procedure Append_Live_Turn_Footer
     (Win   : in out Acme.Window.Win;
      FS    : not null access Nine_P.Client.Fs;
      State : in out App_State;
      PID   : String)
   is
      Input_Tokens      : constant Natural :=
        State.Turn_Input_Tokens;
      Output_Tokens     : constant Natural :=
        State.Turn_Output_Tokens;
      Ctx_Window        : constant Natural :=
        State.Context_Window;
      Model_Text        : constant String  :=
        State.Current_Model;
      Turn_Cost_Dmil    : constant Natural :=
        State.Turn_Cost_Dmil;
      Session_Cost_Dmil : constant Natural :=
        State.Session_Cost_Dmil;
   begin
      State.Increment_Turn_Count;
      Acme.Window.Append
        (Win, FS,
         Format_Turn_Footer
           (Turn_N            => State.Turn_Count,
            UUID              => State.Session_Id,
            PID               => PID,
            Input_Tokens      => Input_Tokens,
            Output_Tokens     => Output_Tokens,
            Ctx_Window        => Ctx_Window,
            Model_Text        => Model_Text,
            Turn_Cost_Dmil    => Turn_Cost_Dmil,
            Session_Cost_Dmil => Session_Cost_Dmil));
   end Append_Live_Turn_Footer;

   --  ── Open_Sub_Window ───────────────────────────────────────────────────
   --
   --  Create a new acme window named  Parent/Sub, write Content, mark clean.

   procedure Open_Sub_Window
     (FS      : not null access Nine_P.Client.Fs;
      Parent  : String;
      Sub     : String;
      Content : String)
   is
      W : Acme.Window.Win := Acme.Window.New_Win (FS);
   begin
      Acme.Window.Set_Name (W, FS, Parent & "/" & Sub);
      if Content'Length > 0 then
         Acme.Window.Append (W, FS, Content);
      end if;
      Acme.Window.Ctl (W, FS, "clean");
   exception
      when Ex : others =>
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "Open_Sub_Window failed: "
            & Ada.Exceptions.Exception_Information (Ex));
   end Open_Sub_Window;

   procedure Dispatch_Event
     (Event   : LLM.Events.Agent_Event'Class;
      Win     : in out Acme.Window.Win;
      FS      : not null access Nine_P.Client.Fs;
      State   : in out App_State;
      Section : in out Section_Kind;
      PID     : String)
   is
   begin

      --  ── agent_start ───────────────────────────────────────────────────
      if Event in LLM.Events.Agent_Start_Event then
         State.Set_Streaming (True);
         State.Set_Text_Emitted (False);
         State.Set_Has_Text_Delta (False);
         State.Set_Has_Tool_In_Turn (False);
         State.Set_Last_Stop_Reason ("");
         State.Set_Last_Error_Message ("");
         Section := No_Section;
         Acme.Window.Replace_Line1
           (Win, FS, Format_Status (State, "running"));

      --  ── agent_end ─────────────────────────────────────────────────────
      elsif Event in LLM.Events.Agent_End_Event then
         State.Set_Streaming (False);
         Section := No_Section;
         if State.Was_Aborted then
            Acme.Window.Append
              (Win, FS, ASCII.LF & "[STOP] Aborted." & ASCII.LF);
            State.Set_Aborted (False);
         elsif not State.Text_Emitted
           and then not State.Is_Retrying
         then
            --  No text and no retry in flight: either the context is too
            --  long (the most common cause) or a non-retryable error
            --  occurred.  If auto-retry is handling a transient API error
            --  it will emit auto_retry_start right after this event, which
            --  sets Is_Retrying and suppresses this message on all
            --  subsequent retry attempts.
            declare
               Err_Msg : constant String := State.Last_Error_Message;
            begin
               Acme.Window.Append
                 (Win, FS,
                  ASCII.LF
                  & UC_WARN
                  & " No response from the agent"
                  & (if Err_Msg'Length > 0
                     then ": " & Err_Msg
                     else " -- context may be too long, or a temporary"
                          & " error occurred. Try New.")
                  & ASCII.LF);
            end;
         end if;
         --  Emit the turn footer and request stats when the agent's final
         --  LLM call ended normally.  The stop reason is "stop" or "length"
         --  on the last text-producing call; intermediate tool-calling turns
         --  use "toolUse".  agent_end fires exactly once per user prompt
         --  (not once per internal LLM call), so there is no risk of a
         --  premature footer.
         declare
            Stop : constant String := State.Last_Stop_Reason;
         begin
            if Stop = "stop" or else Stop = "length" then
               State.Set_Pending_Stats (True);
            end if;
         end;
         Acme.Window.Replace_Line1
           (Win, FS, Format_Status (State, "ready"));

      elsif Event in LLM.Events.Message_Update_Event then
         declare
            Ev : constant LLM.Events.Message_Update_Event :=
              LLM.Events.Message_Update_Event (Event);
         begin
            if Ev.Kind = LLM.Events.Thinking_Delta then
               if Section /= Thinking_Section then
                  Acme.Window.Append
                    (Win, FS, ASCII.LF & UC_BOX_V & " ");
                  Section := Thinking_Section;
               end if;
               declare
                  Text_Delta : constant String := To_String (Ev.Delta_Text);
                  Start      : Natural         := Text_Delta'First;
               begin
                  --  Indent continuation lines; write chunks to keep
                  --  multi-byte UTF-8 sequences intact across 9P writes.
                  for I in Text_Delta'Range loop
                     if Text_Delta (I) = ASCII.LF then
                        if I > Start then
                           Acme.Window.Append
                             (Win, FS, Text_Delta (Start .. I - 1));
                        end if;
                        Acme.Window.Append
                          (Win, FS,
                           "" & ASCII.LF & UC_BOX_V & " ");
                        Start := I + 1;
                     end if;
                  end loop;
                  if Start <= Text_Delta'Last then
                     Acme.Window.Append
                       (Win, FS, Text_Delta (Start .. Text_Delta'Last));
                  end if;
               end;

            elsif Ev.Kind = LLM.Events.Thinking_End then
               Acme.Window.Append
                 (Win, FS, "" & ASCII.LF & ASCII.LF);
               Section := No_Section;

            elsif Ev.Kind = LLM.Events.Text_Delta then
               if Section /= Text_Section then
                  if Section /= No_Section then
                     Acme.Window.Append (Win, FS, "" & ASCII.LF);
                  end if;
                  Section := Text_Section;
               end if;
               State.Set_Text_Emitted (True);
               State.Set_Has_Text_Delta (True);
               Acme.Window.Append
                 (Win, FS, To_String (Ev.Delta_Text));

            elsif Ev.Kind = LLM.Events.Text_End then
               Section := No_Section;
            end if;
         end;

      --  ── tool_execution_start ──────────────────────────────────────────
      elsif Event in LLM.Events.Tool_Execution_Start_Event then
         State.Set_Text_Emitted (True);
         State.Set_Has_Tool_In_Turn (True);
         declare
            Ev          : constant LLM.Events.Tool_Execution_Start_Event :=
              LLM.Events.Tool_Execution_Start_Event (Event);
            Tool        : constant String := To_String (Ev.Tool_Name);
            Tool_Id     : constant String := To_String (Ev.Tool_Call_Id);
            Tok         : constant String :=
              (if Tool_Id'Length > 0
               then Hash_Tool_Id (Tool_Id)
               else "");
            Sess        : constant String := State.Session_Id;
            Args_Parsed : constant GNATCOLL.JSON.Read_Result :=
              GNATCOLL.JSON.Read (To_String (Ev.Args_Json));
            Args        : constant GNATCOLL.JSON.JSON_Value :=
              (if Args_Parsed.Success
               then Args_Parsed.Value
               else GNATCOLL.JSON.Create_Object);
         begin
            if Section /= No_Section then
               Acme.Window.Append (Win, FS, "" & ASCII.LF & ASCII.LF);
            else
               Acme.Window.Append (Win, FS, "" & ASCII.LF);
            end if;
            if Sess'Length > 0 and then Tok'Length > 0 then
               Acme.Window.Append
                 (Win, FS,
                  ASCII.LF & UC_BOX_TL & " " & UC_GEAR & " " & Tool
                  & " coyote-session+" & Sess & "/tool/" & Tok);
            else
               Acme.Window.Append
                 (Win, FS,
                  ASCII.LF & UC_BOX_TL & " " & UC_GEAR & " " & Tool);
            end if;
            --  Show key args.  For the edit tool, display the file path
            --  followed by a compact unified diff of oldText vs newText,
            --  matching the Python reference's edit_diff_lines() output.
            if Tool = "edit" then
               declare
                  Edit_Path : constant String :=
                    Get_String (Args, "path");
                  Diff_Body : constant String :=
                    Edit_Diff_Lines
                      (Get_String (Args, "oldText"),
                       Get_String (Args, "newText"));
                  Diff_Pos  : Natural := Diff_Body'First;
               begin
                  Acme.Window.Append
                    (Win, FS,
                     ASCII.LF & UC_BOX_V & " path: " & Edit_Path);
                  --  Append each diff body line with the │ prefix.
                  for I in Diff_Body'Range loop
                     if Diff_Body (I) = ASCII.LF then
                        Acme.Window.Append
                          (Win, FS,
                           ASCII.LF & UC_BOX_V & " "
                           & Diff_Body (Diff_Pos .. I - 1));
                        Diff_Pos := I + 1;
                     end if;
                  end loop;
                  if Diff_Pos <= Diff_Body'Last then
                     Acme.Window.Append
                       (Win, FS,
                        ASCII.LF & UC_BOX_V & " "
                        & Diff_Body (Diff_Pos .. Diff_Body'Last));
                  end if;
               end;
            elsif Args.Kind = GNATCOLL.JSON.JSON_Object_Type then
               declare
                  procedure Show_Field
                    (Name  : GNATCOLL.JSON.UTF8_String;
                     Value : GNATCOLL.JSON.JSON_Value)
                  is
                  begin
                     if Name not in "oldText" | "newText" then
                        Acme.Window.Append
                          (Win, FS,
                           ASCII.LF
                           & Format_Tool_Field
                               (Name, JSON_Scalar_Image (Value)));
                     end if;
                  end Show_Field;
               begin
                  Args.Map_JSON_Object (Show_Field'Access);
               end;
            end if;
            --  Append a pending-close placeholder that embeds the token.
            --  tool_execution_end will find and replace it in-place via
            --  acme's regexp addr mechanism.  When no token is available
            --  the placeholder is omitted and the end handler falls back
            --  to appending the close marker normally.
            if Tok'Length > 0 then
               Acme.Window.Append
                 (Win, FS,
                  ASCII.LF & UC_BOX_BL & " " & UC_ELLIP & Tok
                  & ASCII.LF & ASCII.LF);
            end if;
            Section := Tool_Section;
         end;

      --  ── tool_execution_end ────────────────────────────────────────────
      elsif Event in LLM.Events.Tool_Execution_End_Event then
         declare
            Ev      : constant LLM.Events.Tool_Execution_End_Event :=
              LLM.Events.Tool_Execution_End_Event (Event);
            Tool_Id : constant String := To_String (Ev.Tool_Call_Id);
            Tok     : constant String :=
              (if Tool_Id'Length > 0
               then Hash_Tool_Id (Tool_Id)
               else "");
         begin
            if Tok'Length > 0 then
               --  Replace the pending-close placeholder written by
               --  tool_execution_start in-place via acme regexp addr.
               if Ev.Is_Error then
                  declare
                     Result  : constant String  := To_String (Ev.Result_Text);
                     Preview : constant Natural :=
                       (if Result'Length > 80
                        then Result'First + 79
                        else Result'Last);
                  begin
                     Acme.Window.Replace_Match
                       (Win, FS,
                        "/" & UC_BOX_BL & " " & UC_ELLIP & Tok & "/",
                        UC_BOX_BL & " " & UC_CROSS & " "
                        & Result (Result'First .. Preview));
                  end;
               else
                  Acme.Window.Replace_Match
                    (Win, FS,
                     "/" & UC_BOX_BL & " " & UC_ELLIP & Tok & "/",
                     UC_BOX_BL & " " & UC_CHECK);
               end if;
            else
               --  No token: fall back to appending the close marker.
               if Ev.Is_Error then
                  declare
                     Result  : constant String  := To_String (Ev.Result_Text);
                     Preview : constant Natural :=
                       (if Result'Length > 80
                        then Result'First + 79
                        else Result'Last);
                  begin
                     Acme.Window.Append
                       (Win, FS,
                        ASCII.LF & UC_BOX_BL & " " & UC_CROSS & " "
                        & Result (Result'First .. Preview)
                        & ASCII.LF & ASCII.LF);
                  end;
               else
                  Acme.Window.Append
                    (Win, FS,
                     "" & ASCII.LF
                     & UC_BOX_BL & " " & UC_CHECK & ASCII.LF & ASCII.LF);
               end if;
            end if;
            Section := No_Section;
         end;

      --  ── message_end (token counts and turn cost) ─────────────────────
      elsif Event in LLM.Events.Message_End_Event then
         declare
            Ev           : constant LLM.Events.Message_End_Event :=
              LLM.Events.Message_End_Event (Event);
            Input_Count  : constant Natural :=
              Ev.Tok_Usage.Input
              + Ev.Tok_Usage.Cache_Read
              + Ev.Tok_Usage.Cache_Write;
            Output_Count : constant Natural := Ev.Tok_Usage.Output;
         begin
            --  Track the stop reason so agent_end can detect whether
            --  this was the agent's final text turn ("stop", "length")
            --  or an intermediate tool-calling turn ("toolUse").
            State.Set_Last_Stop_Reason (Stop_Reason_Image (Ev.Stop));
            if Ev.Stop = LLM.Types.Error_Stop then
               State.Set_Last_Error_Message (To_String (Ev.Err_Msg));
            else
               State.Set_Last_Error_Message ("");
            end if;
            if Input_Count > 0 or else Output_Count > 0 then
               State.Set_Turn_Tokens (Input_Count, Output_Count);
            end if;
            if Ev.Cost_Dmil > 0 then
               State.Set_Turn_Cost (Ev.Cost_Dmil);
            end if;
         end;

      --  ── auto_retry_start ──────────────────────────────────────────────
      --  Emitted before each retry attempt.  Show a compact notice
      --  so the user can see why the turn is being retried and how long
      --  the backoff delay is.
      --
      --  NOTE: An agent_end event is emitted BEFORE this event.  Setting
      --  Is_Retrying here means the flag is True for all subsequent
      --  agent_end events within the same retry sequence (i.e. the 2nd,
      --  3rd, … failed attempt), suppressing the spurious "No response"
      --  message for those attempts.  The very first failure is shown
      --  once, followed immediately by this retry notice.
      elsif Event in LLM.Events.Auto_Retry_Start_Event then
         State.Set_Is_Retrying (True);
         declare
            Ev          : constant LLM.Events.Auto_Retry_Start_Event :=
              LLM.Events.Auto_Retry_Start_Event (Event);
            Attempt     : constant Natural := Ev.Attempt;
            Max_Att     : constant Natural := Ev.Max_Attempts;
            Delay_Ms    : constant Natural := Ev.Delay_Ms;
            Err_Msg     : constant String  := To_String (Ev.Error_Msg);
            Delay_S_Str : constant String  :=
              (if Delay_Ms >= 1000
               then Natural_Image (Delay_Ms / 1000) & "s"
               else Natural_Image (Delay_Ms) & "ms");
         begin
            Acme.Window.Append
              (Win, FS,
               ASCII.LF
               & UC_RETRY & " Retry "
               & Natural_Image (Attempt)
               & "/" & Natural_Image (Max_Att)
               & " in " & Delay_S_Str
               & ": " & Err_Msg
               & ASCII.LF);
            Acme.Window.Replace_Line1
              (Win, FS, Format_Status (State, "retrying"));
         end;

      --  ── auto_retry_end ────────────────────────────────────────────────
      --  Emitted when the retry sequence concludes (success or exhausted).
      --  On success streaming continues immediately so no extra note is
      --  needed.  On failure show the final error prominently.
      elsif Event in LLM.Events.Auto_Retry_End_Event then
         State.Set_Is_Retrying (False);
         declare
            Ev : constant LLM.Events.Auto_Retry_End_Event :=
              LLM.Events.Auto_Retry_End_Event (Event);
         begin
            if not Ev.Success then
               declare
                  Final_Err : constant String := To_String (Ev.Final_Error);
                  Attempts  : constant Natural := Ev.Attempt;
               begin
                  Acme.Window.Append
                    (Win, FS,
                     ASCII.LF
                     & UC_CROSS & " Retry failed after "
                     & Natural_Image (Attempts)
                     & (if Attempts = 1 then " attempt" else " attempts")
                     & (if Final_Err'Length > 0
                        then ": " & Final_Err
                        else "")
                     & ASCII.LF);
               end;
            end if;
         end;

      --  ── auto_compaction_start ────────────────────────────────────────
      --  Emitted when auto-compacting the context begins (either because
      --  the context overflowed or because the configured threshold was
      --  crossed).  Show a compact notice and update the tag.
      elsif Event in LLM.Events.Auto_Compaction_Start_Event then
         State.Set_Compacting (True);
         declare
            Ev     : constant LLM.Events.Auto_Compaction_Start_Event :=
              LLM.Events.Auto_Compaction_Start_Event (Event);
            Reason : constant String := To_String (Ev.Reason);
            Label  : constant String :=
              (if Reason = "overflow"
               then "Overflow: compacting context" & UC_ELLIP
               else "Compacting context" & UC_ELLIP);
         begin
            Acme.Window.Append
              (Win, FS,
               ASCII.LF & UC_GEAR & " " & Label & ASCII.LF);
         end;
         Acme.Window.Replace_Line1
           (Win, FS, Format_Status (State, "compacting"));

      --  ── auto_compaction_end ───────────────────────────────────────────
      --  Emitted when auto-compaction finishes (success, aborted, or
      --  error).  The three cases are distinguished by the "errorMessage",
      --  "aborted", and "willRetry" fields.
      elsif Event in LLM.Events.Auto_Compaction_End_Event then
         State.Set_Compacting (False);
         declare
            Ev         : constant LLM.Events.Auto_Compaction_End_Event :=
              LLM.Events.Auto_Compaction_End_Event (Event);
            Err_Msg    : constant String  := To_String (Ev.Err_Msg);
            Is_Aborted : constant Boolean := Ev.Aborted;
            Will_Retry : constant Boolean := Ev.Will_Retry;
         begin
            if Err_Msg'Length > 0 then
               Acme.Window.Append
                 (Win, FS,
                  ASCII.LF & UC_WARN & " Compaction failed: "
                  & Err_Msg & ASCII.LF);
            elsif Is_Aborted then
               Acme.Window.Append
                 (Win, FS,
                  ASCII.LF & UC_CROSS & " Compaction aborted." & ASCII.LF);
            elsif Will_Retry then
               Acme.Window.Append
                 (Win, FS,
                  ASCII.LF & UC_CHECK
                  & " Context compacted, retrying" & UC_ELLIP
                  & ASCII.LF);
            else
               Acme.Window.Append
                 (Win, FS,
                  ASCII.LF & UC_CHECK & " Context compacted." & ASCII.LF);
            end if;
         end;
         Acme.Window.Replace_Line1
           (Win, FS,
            Format_Status
              (State,
               (if State.Is_Streaming then "running" else "ready")));

      --  ── model_select ─────────────────────────────────────────────────
      --  Emitted when the active model changes.
      elsif Event in LLM.Events.Model_Select_Event then
         declare
            Ev         : constant LLM.Events.Model_Select_Event :=
              LLM.Events.Model_Select_Event (Event);
            Provider   : constant String  := To_String (Ev.Provider);
            Model_Id   : constant String  := To_String (Ev.Model_Id);
            Ctx_Window : constant Natural := Ev.Context_Window;
         begin
            if Provider'Length > 0 and then Model_Id'Length > 0 then
               State.Set_Model (Provider & "/" & Model_Id);
            end if;
            if Ctx_Window > 0 then
               State.Set_Context_Window (Ctx_Window);
            end if;
         end;
         Acme.Window.Replace_Line1
           (Win, FS,
            Format_Status
              (State,
               (if State.Is_Streaming then "running" else "ready")));

      --  ── session info ──────────────────────────────────────────────────
      elsif Event in LLM.Events.Session_Info_Event then
         declare
            Ev           : constant LLM.Events.Session_Info_Event :=
              LLM.Events.Session_Info_Event (Event);
            Session_Id_V : constant String := To_String (Ev.Session_Id);
            Think_Level  : constant String := To_String (Ev.Thinking_Level);
         begin
            if Session_Id_V'Length > 0 then
               State.Set_Session_Id (Session_Id_V);
            end if;
            if Think_Level'Length > 0 then
               State.Set_Thinking (Think_Level);
            end if;
         end;
         Acme.Window.Replace_Line1
           (Win, FS, Format_Status (State, "ready"));

      --  ── session stats ─────────────────────────────────────────────────
      elsif Event in LLM.Events.Session_Stats_Event then
         declare
            Ev : constant LLM.Events.Session_Stats_Event :=
              LLM.Events.Session_Stats_Event (Event);
         begin
            State.Set_Session_Stats
              (Cost_Dmil   => Ev.Cost_Dmil,
               Input       => Ev.Input,
               Output      => Ev.Output,
               Cache_Read  => Ev.Cache_Read,
               Cache_Write => Ev.Cache_Write,
               Total       => Ev.Total);
         end;
         if State.Pending_Stats then
            State.Set_Pending_Stats (False);
            --  Append turn footer: summary and fork token on the
            --  same line, followed by the separator rule.
            Append_Live_Turn_Footer
              (Win   => Win,
               FS    => FS,
               State => State,
               PID   => PID);
         end if;
         Acme.Window.Replace_Line1
           (Win, FS, Format_Status (State, "ready"));
      end if;
   end Dispatch_Event;

end Coyote_App.Dispatch;
