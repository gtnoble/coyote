--  Coyote_App.Frontend.TUI — terminal UI frontend.
--
--  Implements the abstract Frontend.Instance interface by delegating to
--  the Coyote_TUI subsystem.  All state is carried in the Instance record
--  itself (Conv, PQ, Nav, The_Task); there are no package-level globals.
--
--  Two instances may coexist.  Tests may construct an Instance, call any
--  combination of Append_Text / End_Text_Block / Append_Turn_Footer / etc.
--  and then call the testing-support subprograms — without ever calling
--  Create and without a UI task being started.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Coyote_TUI.Store;
with Coyote_TUI.Prompt_Queue;
with Coyote_TUI.Nav_State;
with Coyote_TUI.UI;

package Coyote_App.Frontend.TUI is

   type Instance is new Coyote_App.Frontend.Instance with private;

   --  Initialise F: enter raw terminal mode, start the UI task.
   --  Win_Name is shown in the status bar title.
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

   --  ── TUI-specific (not in abstract Frontend interface) ─────────────────

   --  Store a formatted stats summary for the :stats command.
   procedure Set_Stats_Summary (F : in out Instance; Text : String);

   --  ── Testing-support subprograms ───────────────────────────────────────
   --
   --  These expose internal state for white-box unit tests.  They do not
   --  require Create to have been called and never touch ncurses.

   --  Reset the segment buffer and search/stats state.
   procedure Clear_Buffer (F : in out Instance);

   --  Compute matches for Term, store in Nav, return match count.
   function Match_Count_For
     (F    : in out Instance;
      Term :        String) return Natural;

   --  Advance the search cursor by Dir (+1 forward, -1 backward).
   procedure Advance_Search (F : in out Instance; Dir : Integer);

   --  Segment index of the current search match (0 when none).
   function Current_Search_Seg (F : Instance) return Natural;
   function Current_Search_Match_Offset (F : Instance) return Natural;
   function Current_Search_Match_Len    (F : Instance) return Natural;

   --  The current stats-summary text.
   function Stats_Summary_Text (F : Instance) return String;

private

   type Instance is new Coyote_App.Frontend.Instance with record
      Conv     : aliased Coyote_TUI.Store.Conversation;
      PQ       : aliased Coyote_TUI.Prompt_Queue.Queue;
      Nav      : aliased Coyote_TUI.Nav_State.State;
      The_Task : Coyote_TUI.UI.Task_Access := null;
   end record;

end Coyote_App.Frontend.TUI;
