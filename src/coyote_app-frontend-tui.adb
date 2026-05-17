--  Coyote_App.Frontend.TUI body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Environment_Variables;
with Ada.Strings.Unbounded;          use Ada.Strings.Unbounded;

with Coyote_TUI.Search;
with Coyote_TUI.Segments;

package body Coyote_App.Frontend.TUI is

   --  ── Segment-kind conversion ───────────────────────────────────────────

   function To_TUI_Notice
     (Kind : Coyote_App.Frontend.Notice_Kind)
      return Coyote_TUI.Segments.Notice_Kind
   is
   begin
      case Kind is
         when Coyote_App.Frontend.Info    =>
            return Coyote_TUI.Segments.Info;
         when Coyote_App.Frontend.Warning =>
            return Coyote_TUI.Segments.Warning;
         when Coyote_App.Frontend.Error   =>
            return Coyote_TUI.Segments.Error;
      end case;
   end To_TUI_Notice;

   function To_TUI_Status
     (Status : Coyote_App.Frontend.Tool_End_Status)
      return Coyote_TUI.Segments.Tool_Run_Status
   is
   begin
      case Status is
         when Coyote_App.Frontend.Success   =>
            return Coyote_TUI.Segments.Success;
         when Coyote_App.Frontend.Error     =>
            return Coyote_TUI.Segments.Error;
         when Coyote_App.Frontend.Cancelled =>
            return Coyote_TUI.Segments.Cancelled;
      end case;
   end To_TUI_Status;

   --  ── Create ───────────────────────────────────────────────────────────

   procedure Create
     (F        : in out Instance;
      Win_Name : in     String)
   is
      Use_Color : constant Boolean :=
        not Ada.Environment_Variables.Exists ("NO_COLOR");
   begin
      F.Nav.Set_Win_Name (Win_Name);
      F.The_Task :=
        new Coyote_TUI.UI.Task_T
              (Conv => F.Conv'Unchecked_Access,
               PQ   => F.PQ'Unchecked_Access,
               Nav  => F.Nav'Unchecked_Access);
      F.The_Task.Start (Win_Name, Use_Color);
      F.Nav.Request_Render;
   end Create;

   --  ── Set_Status ───────────────────────────────────────────────────────

   overriding
   procedure Set_Status
     (F    : in out Instance;
      Text :        String)
   is
   begin
      F.Nav.Set_Status (Text);
   end Set_Status;

   --  ── Set_Mode ─────────────────────────────────────────────────────────

   overriding
   procedure Set_Mode
     (F    : in out Instance;
      Mode :        Coyote_App.Frontend.Run_Mode)
   is
   begin
      F.Nav.Set_Streaming (Mode = Running);
      F.Nav.Request_Render;
   end Set_Mode;

   --  ── Append_Text ──────────────────────────────────────────────────────

   overriding
   procedure Append_Text
     (F    : in out Instance;
      Text :        String)
   is
   begin
      F.Conv.Append_Assistant_Text (Text);
      F.Nav.Request_Render;
   end Append_Text;

   --  ── End_Text_Block ───────────────────────────────────────────────────

   overriding
   procedure End_Text_Block (F : in out Instance) is
   begin
      F.Conv.Set_Last_Complete;
      F.Nav.Mark_Height_Stale (F.Conv.Count);
      F.Nav.Request_Render;
   end End_Text_Block;

   --  ── Begin_Thinking ───────────────────────────────────────────────────

   overriding
   procedure Begin_Thinking (F : in out Instance) is
   begin
      F.Conv.Append_Thinking_Text ("");
      F.Nav.Request_Render;
   end Begin_Thinking;

   --  ── Append_Thinking ──────────────────────────────────────────────────

   overriding
   procedure Append_Thinking
     (F    : in out Instance;
      Text :        String)
   is
   begin
      F.Conv.Append_Thinking_Text (Text);
      F.Nav.Request_Render;
   end Append_Thinking;

   --  ── End_Thinking ─────────────────────────────────────────────────────

   overriding
   procedure End_Thinking (F : in out Instance) is
   begin
      null;
   end End_Thinking;

   --  ── Begin_Tool ───────────────────────────────────────────────────────

   overriding
   procedure Begin_Tool
     (F          : in out Instance;
      Name       :        String;
      Args_Json  :        String;
      Session_Id :        String;
      Tool_Id    :        String)
   is
      pragma Unreferenced (Session_Id);
      use Coyote_TUI.Segments;
      S : constant Segment :=
        (Kind      => Tool_Segment,
         Tool_Name => To_Unbounded_String (Name),
         Tool_Args => To_Unbounded_String (Args_Json),
         Tool_Id   => To_Unbounded_String (Tool_Id),
         T_Status  => Running,
         others    => <>);
   begin
      F.Conv.Append_New (S);
      F.Nav.Request_Render;
   end Begin_Tool;

   --  ── End_Tool ─────────────────────────────────────────────────────────

   overriding
   procedure End_Tool
     (F           : in out Instance;
      Tool_Id     :        String;
      Status      :        Coyote_App.Frontend.Tool_End_Status;
      Result_Text :        String := "")
   is
   begin
      F.Conv.End_Tool (Tool_Id, Result_Text, To_TUI_Status (Status));
      F.Nav.Request_Render;
   end End_Tool;

   --  ── Append_Turn_Footer ───────────────────────────────────────────────

   overriding
   procedure Append_Turn_Footer
     (F    : in out Instance;
      Text :        String)
   is
      use Coyote_TUI.Segments;
      S : constant Segment :=
        (Kind    => Turn_Footer,
         Content => To_Unbounded_String (Text),
         others  => <>);
   begin
      F.Conv.Append_New (S);
      F.Nav.Request_Render;
   end Append_Turn_Footer;

   --  ── Append_Notice ────────────────────────────────────────────────────

   overriding
   procedure Append_Notice
     (F    : in out Instance;
      Kind :        Coyote_App.Frontend.Notice_Kind;
      Text :        String)
   is
      use Coyote_TUI.Segments;
      S : constant Segment :=
        (Kind    => System_Notice,
         Sev     => To_TUI_Notice (Kind),
         Content => To_Unbounded_String (Text),
         others  => <>);
   begin
      F.Conv.Append_New (S);
      F.Nav.Request_Render;
   end Append_Notice;

   --  ── Show_Detail ──────────────────────────────────────────────────────

   overriding
   procedure Show_Detail
     (F       : in out Instance;
      Title   :        String;
      Content :        String)
   is
      pragma Unreferenced (F);
   begin
      --  Delegated to UI_Task via Prompt_Queue is not possible from this
      --  call site; run inline (suspends ncurses, as Run_Pager does in UI).
      --  For now, emit the content as a system notice.
      pragma Unreferenced (Title, Content);
      null;
   end Show_Detail;

   --  ── Read_Prompt ──────────────────────────────────────────────────────

   overriding
   function Read_Prompt
     (F : in out Instance) return String
   is
      E : Coyote_TUI.Prompt_Queue.Entry_T;
   begin
      F.PQ.Dequeue (E);
      if F.PQ.Is_Shutdown then
         return "";
      end if;
      return To_String (E.Text);
   end Read_Prompt;

   --  ── Shutdown ─────────────────────────────────────────────────────────

   overriding
   procedure Shutdown (F : in out Instance) is
   begin
      F.PQ.Shutdown;
      F.Nav.Stop;
   end Shutdown;

   --  ── Set_Stats_Summary ────────────────────────────────────────────────

   procedure Set_Stats_Summary
     (F    : in out Instance;
      Text :        String)
   is
   begin
      F.Nav.Set_Stats_Summary (Text);
   end Set_Stats_Summary;

   --  ── Testing-support subprograms ───────────────────────────────────────

   procedure Clear_Buffer (F : in out Instance) is
   begin
      F.Conv.Clear;
      F.Nav.Set_Search ("", Coyote_TUI.Search.Match_Vectors.Empty_Vector);
      F.Nav.Set_Stats_Summary ("");
   end Clear_Buffer;

   function Match_Count_For
     (F    : in out Instance;
      Term :        String) return Natural
   is
      Snap    : constant Coyote_TUI.Segments.Vector := F.Conv.Snapshot;
      Matches : constant Coyote_TUI.Search.Match_Vector :=
        Coyote_TUI.Search.Compute_Matches (Snap, Term);
   begin
      F.Nav.Set_Search (Term, Matches);
      return Natural (Matches.Length);
   end Match_Count_For;

   procedure Advance_Search (F : in out Instance; Dir : Integer) is
   begin
      F.Nav.Advance_Search (Dir);
   end Advance_Search;

   function Current_Search_Seg (F : Instance) return Natural is
   begin
      if F.Nav.Search_Match_Count = 0 then
         return 0;
      end if;
      return F.Nav.Current_Match.Seg_Index;
   end Current_Search_Seg;

   function Current_Search_Match_Offset (F : Instance) return Natural is
   begin
      return F.Nav.Current_Match.Byte_Offset;
   end Current_Search_Match_Offset;

   function Current_Search_Match_Len (F : Instance) return Natural is
   begin
      return F.Nav.Current_Match.Match_Len;
   end Current_Search_Match_Len;

   function Stats_Summary_Text (F : Instance) return String is
   begin
      return F.Nav.Stats_Summary;
   end Stats_Summary_Text;

end Coyote_App.Frontend.TUI;
