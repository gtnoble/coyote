--  Coyote_App.Frontend.TUI — terminal UI frontend (ANSI/VT100).
--
--  Implements Coyote_App.Frontend.Instance by maintaining a typed
--  conversation buffer, rendering it to a VT100 terminal, and reading
--  user input from stdin in raw mode.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded;

package Coyote_App.Frontend.TUI is

   type Instance is new Coyote_App.Frontend.Instance with private;

   --  Initialise F: enter raw terminal mode, start Render_Task and
   --  Input_Task.  Win_Name is used in the status bar title.
   procedure Create
     (F        : in out Instance;
      Win_Name : in     String);

   overriding
   procedure Set_Status
     (F    : in out Instance;
      Text : in     String);

   overriding
   procedure Set_Mode
     (F    : in out Instance;
      Mode : in     Coyote_App.Frontend.Run_Mode);

   overriding
   procedure Append_Text
     (F    : in out Instance;
      Text : in     String);

   overriding
   procedure End_Text_Block (F : in out Instance);

   overriding
   procedure Begin_Thinking (F : in out Instance);

   overriding
   procedure Append_Thinking
     (F    : in out Instance;
      Text : in     String);

   overriding
   procedure End_Thinking (F : in out Instance);

   overriding
   procedure Begin_Tool
     (F          : in out Instance;
      Name       : in     String;
      Args_Json  : in     String;
      Session_Id : in     String;
      Tool_Id    : in     String);

   overriding
   procedure End_Tool
     (F           : in out Instance;
      Tool_Id     : in     String;
      Status      : in     Coyote_App.Frontend.Tool_End_Status;
      Result_Text : in     String := "");

   overriding
   procedure Append_Turn_Footer
     (F    : in out Instance;
      Text : in     String);

   overriding
   procedure Append_Notice
     (F    : in out Instance;
      Kind : in     Coyote_App.Frontend.Notice_Kind;
      Text : in     String);

   overriding
   procedure Show_Detail
     (F       : in out Instance;
      Title   : in     String;
      Content : in     String);

   overriding
   function Read_Prompt
     (F : in out Instance) return String;

   overriding
   procedure Shutdown (F : in out Instance);
   --  Store a formatted stats summary for display by the :stats command.
   --  Not part of the abstract Frontend interface; TUI-specific.
   procedure Set_Stats_Summary (F : in out Instance; Text : String);

   --  ── Testing-support subprograms ──────────────────────────────────────
   --
   --  Not part of the Frontend interface.  Expose internal state for
   --  white-box unit tests that must not require an initialised terminal.

   --  Reset the segment buffer and all search / stats state.
   procedure Clear_Buffer       (F : in out Instance);

   --  Compute matches for Term, store results, return match count.
   function Match_Count_For
     (F    : in out Instance;
      Term :        String) return Natural;

   --  Advance the search cursor by Dir (+1 forward, -1 backward).
   procedure Advance_Search     (F : in out Instance; Dir : Integer);

   --  Segment index of the current search match (0 when no match set).
   function Current_Search_Seg (F : Instance) return Natural;
   function Current_Search_Match_Offset (F : Instance) return Natural;
   function Current_Search_Match_Len    (F : Instance) return Natural;

   --  The current stats-summary text (placeholder when not yet set).
   function Stats_Summary_Text (F : Instance) return String;

private

   --  ── Segment buffer types ─────────────────────────────────────────────

   type Segment_Kind is
     (User_Turn,
      Steer_Turn,
      Assistant_Text,
      Thinking_Block,
      Tool_Segment,
      Turn_Footer,
      System_Notice);

   type Tool_Run_Status is (Running, Success, Error, Cancelled);

   type Segment (Kind : Segment_Kind := System_Notice) is record
      Content   : Ada.Strings.Unbounded.Unbounded_String;
      Complete  : Boolean := False;
      Sev       : Coyote_App.Frontend.Notice_Kind :=
                    Coyote_App.Frontend.Info;
      Tool_Name : Ada.Strings.Unbounded.Unbounded_String;
      Tool_Args : Ada.Strings.Unbounded.Unbounded_String;
      Tool_Id   : Ada.Strings.Unbounded.Unbounded_String;
      T_Status  : Tool_Run_Status := Running;
   end record;

   --  ── Instance record ───────────────────────────────────────────────────
   --  All mutable state lives in package-level protected objects (body).
   --  This record just tracks whether Create has been called.

   type Instance is new Coyote_App.Frontend.Instance with record
      Created : Boolean := False;
   end record;

end Coyote_App.Frontend.TUI;
