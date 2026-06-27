--  Coyote_App.Frontend.Acme — concrete acme window frontend.
--
--  Implements Coyote_App.Frontend.Instance by routing all rendering calls to
--  the shared Acme.Window.Win object supplied at creation time.  Each
--  Instance maintains its own Nine_P.Client.Fs connection to the acme
--  namespace so it can be called from any task without sharing Fs state
--  with other tasks.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded;
with Acme.Window;
with Nine_P.Client;

package Coyote_App.Frontend.Acme_Win is

   --  ── Instance ──────────────────────────────────────────────────────────

   type Instance is new Coyote_App.Frontend.Instance with private;

   --  Initialise F to render into Win_Ptr.  Opens a private Nine_P
   --  connection to the acme namespace.
   procedure Create
     (F       :    out Instance;
      Win_Ptr : not null access Acme.Window.Win);

   --  Store the tag suffix appended after the dynamic button group.
   --  Must be called before the first Set_Mode; defaults to "".
   procedure Set_Tag_Suffix
     (F      : in out Instance;
      Suffix : in     String);

   --  Return the underlying Win pointer so callers can pass it to other
   --  operations that still need the raw Win object.
   function Win_Access
     (F : Instance) return not null access Acme.Window.Win;

   --  ── Frontend primitives ───────────────────────────────────────────────

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

private

   type Instance is new Coyote_App.Frontend.Instance with record
      Win_Ptr    : access Acme.Window.Win := null;
      In_Thinking          : Boolean := False;
      Prefix_Emitted       : Boolean := False;
      My_FS      : aliased Nine_P.Client.Fs;
      Tag_Suffix : Ada.Strings.Unbounded.Unbounded_String;
   end record;

end Coyote_App.Frontend.Acme_Win;
