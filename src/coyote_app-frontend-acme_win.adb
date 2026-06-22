--  Coyote_App.Frontend.Acme body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with GNATCOLL.JSON;
with Nine_P.Client;          use Nine_P.Client;
with Coyote_App.Dispatch;
with Coyote_App.Utils;       use Coyote_App.Utils;

package body Coyote_App.Frontend.Acme_Win is

   use type GNATCOLL.JSON.JSON_Value_Type;

   --  ── Create ────────────────────────────────────────────────────────────

   procedure Create
     (F       :    out Instance;
      Win_Ptr : not null access Acme.Window.Win)
   is
   begin
      F.Win_Ptr := Win_Ptr;
      Connect (F.My_FS, "acme");
   end Create;

   --  ── Set_Tag_Suffix ────────────────────────────────────────────────────

   procedure Set_Tag_Suffix
     (F      : in out Instance;
      Suffix : in     String)
   is
   begin
      F.Tag_Suffix := To_Unbounded_String (Suffix);
   end Set_Tag_Suffix;

   --  ── Win_Access ────────────────────────────────────────────────────────

   function Win_Access
     (F : Instance) return not null access Acme.Window.Win
   is
   begin
      return F.Win_Ptr;
   end Win_Access;

   --  ── Set_Status ────────────────────────────────────────────────────────

   procedure Set_Status
     (F    : in out Instance;
      Text : in     String)
   is
   begin
      Acme.Window.Replace_Line1 (F.Win_Ptr.all, F.My_FS'Access, Text);
   end Set_Status;

   --  ── Set_Mode ──────────────────────────────────────────────────────────

   procedure Set_Mode
     (F    : in out Instance;
      Mode : in     Coyote_App.Frontend.Run_Mode)
   is
      use Coyote_App.Frontend;
      Suffix : constant String := To_String (F.Tag_Suffix);
      Text   : constant String :=
        (case Mode is
         when Idle    => " | Send Steer New Compact Clear SetDefault",
         when Running => " | Stop Steer Pause",
         when Armed   => " | Stop Steer Pausing",
         when Paused  => " | Stop Steer Send Resume")
        & Suffix;
   begin
      Acme.Window.Ctl       (F.Win_Ptr.all, F.My_FS'Access, "cleartag");
      Acme.Window.Append_Tag (F.Win_Ptr.all, F.My_FS'Access, Text);
   end Set_Mode;

   --  ── Append_Text ───────────────────────────────────────────────────────

   procedure Append_Text
     (F    : in out Instance;
      Text : in     String)
   is
   begin
      Acme.Window.Append (F.Win_Ptr.all, F.My_FS'Access, Text);
   end Append_Text;

   --  ── End_Text_Block ────────────────────────────────────────────────────

   procedure End_Text_Block (F : in out Instance) is
      pragma Unreferenced (F);
   begin
      null;
   end End_Text_Block;



   procedure Begin_Thinking (F : in out Instance) is
   begin
      End_Text_Block (F);
      if not F.In_Thinking then
         F.In_Thinking        := True;
         F.Prefix_Emitted     := False;
         F.Last_Ended_With_LF := True;
      end if;
   end Begin_Thinking;

   --  ── Append_Thinking ───────────────────────────────────────────────────


   procedure Append_Thinking
     (F    : in out Instance;
      Text : in     String)
   is
      use Coyote_App.Utils;
      Trimmed : constant String := Collapse_Thinking_Delta (Text);
   begin
      if Trimmed'Length = 0 then
         return;
      end if;

      if not F.Prefix_Emitted then
         Acme.Window.Append
           (F.Win_Ptr.all, F.My_FS'Access,
            ASCII.LF & UC_BOX_V & " ");
         F.Prefix_Emitted     := True;
         F.Last_Ended_With_LF := False;
      elsif not F.Last_Ended_With_LF
        and then Trimmed (Trimmed'First) /= ASCII.LF
      then
         Acme.Window.Append
           (F.Win_Ptr.all, F.My_FS'Access, " ");
      end if;

      Acme.Window.Append (F.Win_Ptr.all, F.My_FS'Access, Trimmed);
      F.Last_Ended_With_LF :=
        Trimmed (Trimmed'Last) = ASCII.LF;
   end Append_Thinking;

   --  ── End_Thinking ──────────────────────────────────────────────────────

   procedure End_Thinking (F : in out Instance) is
   begin
      if F.In_Thinking then
         if F.Prefix_Emitted then
            Acme.Window.Append
              (F.Win_Ptr.all, F.My_FS'Access, "" & ASCII.LF & ASCII.LF);
         end if;
         F.In_Thinking        := False;
         F.Prefix_Emitted     := False;
         F.Last_Ended_With_LF := True;
      end if;
   end End_Thinking;
   procedure Begin_Tool
     (F          : in out Instance;
      Name       : in     String;
      Args_Json  : in     String;
      Session_Id : in     String;
      Tool_Id    : in     String)
   is
      Tok         : constant String :=
        (if Tool_Id'Length > 0 then Hash_Tool_Id (Tool_Id) else "");
      Args_Parsed : constant GNATCOLL.JSON.Read_Result :=
        GNATCOLL.JSON.Read (Args_Json);
      Args        : constant GNATCOLL.JSON.JSON_Value :=
        (if Args_Parsed.Success
         then Args_Parsed.Value
         else GNATCOLL.JSON.Create_Object);
   begin
      --  Header line with optional session/tool plumb token.
      if Session_Id'Length > 0 and then Tok'Length > 0 then
         Acme.Window.Append
           (F.Win_Ptr.all, F.My_FS'Access,
            ASCII.LF & UC_BOX_TL & " " & UC_GEAR & " " & Name
            & " coyote-session+" & Session_Id & "/tool/" & Tok);
      else
         Acme.Window.Append
           (F.Win_Ptr.all, F.My_FS'Access,
            ASCII.LF & UC_BOX_TL & " " & UC_GEAR & " " & Name);
      end if;
      --  Tool arguments: one line per JSON field.
      if Args.Kind = GNATCOLL.JSON.JSON_Object_Type then
         declare
            procedure Show_Field
              (Field_Name  : GNATCOLL.JSON.UTF8_String;
               Field_Value : GNATCOLL.JSON.JSON_Value)
            is
            begin
               Acme.Window.Append
                 (F.Win_Ptr.all, F.My_FS'Access,
                  ASCII.LF
                  & Format_Tool_Field
                      (Field_Name, JSON_Scalar_Image (Field_Value)));
            end Show_Field;
         begin
            Args.Map_JSON_Object (Show_Field'Access);
         end;
      end if;
      --  Pending-close placeholder (replaced in-place by End_Tool).
      if Tok'Length > 0 then
         Acme.Window.Append
           (F.Win_Ptr.all, F.My_FS'Access,
            ASCII.LF & UC_BOX_BL & " " & UC_ELLIP & Tok
            & ASCII.LF & ASCII.LF);
      end if;
   end Begin_Tool;

   --  ── End_Tool ──────────────────────────────────────────────────────────

   procedure End_Tool
     (F           : in out Instance;
      Tool_Id     : in     String;
      Status      : in     Coyote_App.Frontend.Tool_End_Status;
      Result_Text : in     String := "")
   is
      use Coyote_App.Frontend;
      Tok : constant String :=
        (if Tool_Id'Length > 0 then Hash_Tool_Id (Tool_Id) else "");
   begin
      if Tok'Length > 0 then
         --  Replace the placeholder written by Begin_Tool.
         case Status is
            when Cancelled =>
               Acme.Window.Replace_Match
                 (F.Win_Ptr.all, F.My_FS'Access,
                  "/" & UC_BOX_BL & " " & UC_ELLIP & Tok & "/",
                  UC_BOX_BL & " " & UC_CROSS & " cancelled");
            when Error =>
               declare
                  Preview : constant Natural :=
                    (if Result_Text'Length > 80
                     then Result_Text'First + 79
                     else Result_Text'Last);
               begin
                  Acme.Window.Replace_Match
                    (F.Win_Ptr.all, F.My_FS'Access,
                     "/" & UC_BOX_BL & " " & UC_ELLIP & Tok & "/",
                     UC_BOX_BL & " " & UC_CROSS & " "
                     & Result_Text (Result_Text'First .. Preview));
               end;
            when Success =>
               Acme.Window.Replace_Match
                 (F.Win_Ptr.all, F.My_FS'Access,
                  "/" & UC_BOX_BL & " " & UC_ELLIP & Tok & "/",
                  UC_BOX_BL & " " & UC_CHECK);
         end case;
      else
         --  No token: fall back to appending the close marker.
         case Status is
            when Cancelled =>
               Acme.Window.Append
                 (F.Win_Ptr.all, F.My_FS'Access,
                  ASCII.LF & UC_BOX_BL & " " & UC_CROSS & " cancelled"
                  & ASCII.LF & ASCII.LF);
            when Error =>
               declare
                  Preview : constant Natural :=
                    (if Result_Text'Length > 80
                     then Result_Text'First + 79
                     else Result_Text'Last);
               begin
                  Acme.Window.Append
                    (F.Win_Ptr.all, F.My_FS'Access,
                     ASCII.LF & UC_BOX_BL & " " & UC_CROSS & " "
                     & Result_Text (Result_Text'First .. Preview)
                     & ASCII.LF & ASCII.LF);
               end;
            when Success =>
               Acme.Window.Append
                 (F.Win_Ptr.all, F.My_FS'Access,
                  "" & ASCII.LF
                  & UC_BOX_BL & " " & UC_CHECK & ASCII.LF & ASCII.LF);
         end case;
      end if;
   end End_Tool;

   --  ── Append_Turn_Footer ────────────────────────────────────────────────

   procedure Append_Turn_Footer
     (F    : in out Instance;
      Text : in     String)
   is
   begin
      Acme.Window.Append (F.Win_Ptr.all, F.My_FS'Access, Text);
   end Append_Turn_Footer;

   --  ── Append_Notice ─────────────────────────────────────────────────────

   procedure Append_Notice
     (F    : in out Instance;
      Kind : in     Coyote_App.Frontend.Notice_Kind;
      Text : in     String)
   is
      use Coyote_App.Frontend;
   begin
      case Kind is
         when Info =>
            Acme.Window.Append (F.Win_Ptr.all, F.My_FS'Access, Text);
         when Warning =>
            Acme.Window.Append
              (F.Win_Ptr.all, F.My_FS'Access,
               ASCII.LF & UC_WARN & " " & Text & ASCII.LF);
         when Error =>
            Acme.Window.Append
              (F.Win_Ptr.all, F.My_FS'Access,
               ASCII.LF & "[!] " & Text & ASCII.LF);
      end case;
   end Append_Notice;

   --  ── Show_Detail ───────────────────────────────────────────────────────

   procedure Show_Detail
     (F       : in out Instance;
      Title   : in     String;
      Content : in     String)
   is
      Slash : Natural := 0;
   begin
      --  Split Title into Parent/Sub at the last '/'.
      for I in reverse Title'Range loop
         if Title (I) = '/' then
            Slash := I;
            exit;
         end if;
      end loop;
      if Slash > 0 then
         Coyote_App.Dispatch.Open_Sub_Window
           (F.My_FS'Access,
            Title (Title'First .. Slash - 1),
            Title (Slash + 1 .. Title'Last),
            Content);
      else
         Coyote_App.Dispatch.Open_Sub_Window
           (F.My_FS'Access, Title, "detail", Content);
      end if;
   end Show_Detail;

   --  ── Read_Prompt ───────────────────────────────────────────────────────

   function Read_Prompt
     (F : in out Instance) return String
   is
      pragma Unreferenced (F);
   begin
      raise Program_Error
        with "Read_Prompt is not supported by the acme frontend: "
             & "prompts arrive via the acme event task, not via this call";
      return "";
   end Read_Prompt;

   --  ── Shutdown ──────────────────────────────────────────────────────────

   procedure Shutdown (F : in out Instance) is
   begin
      Acme.Window.Ctl (F.Win_Ptr.all, F.My_FS'Access, "delete");
   end Shutdown;

end Coyote_App.Frontend.Acme_Win;
