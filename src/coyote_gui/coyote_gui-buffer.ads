--  Coyote_GUI.Buffer — GtkTextBuffer wrapper for the conversation view.
--
--  Owns one GtkTextBuffer and renders all conversation content into it:
--
--    * Streaming assistant text appended verbatim; on End_Text_Block the
--      streamed range is deleted and re-inserted as Pango-marked-up text
--      derived from the completed CommonMark AST (via libcmark-gfm).
--
--    * Thinking blocks inserted with a dim italic span, 24 px left margin,
--      preceded by a single "╎ " gutter character.
--
--    * Tool calls rendered as box-drawing text blocks with a clickable
--      tag covering the entire block.  Clicking opens a detail window.
--      End_Tool replaces the placeholder footer line in-place.
--
--    * Notices (Info / Warning / Error) are coloured single-line inserts.
--
--    * Turn footers inserted with a dim style.
--
--  All operations must be called from the GTK main loop thread.
--
--  Project: coyote

with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded;        use Ada.Strings.Unbounded;
with Coyote_App.Utils;
with Glib;
with Gtk.Text_Buffer;
with Gtk.Text_Mark;
with Gtk.Text_Tag;
with Gtk.Text_View;

package Coyote_GUI.Buffer is

   type Instance is tagged limited private;

   --  Attach Buffer to an already-created view/buffer pair and set up tags.
   procedure Attach
     (B    : in out Instance;
      View : Gtk.Text_View.Gtk_Text_View;
      Buf  : Gtk.Text_Buffer.Gtk_Text_Buffer);

   --  ── Streaming assistant text ──────────────────────────────────────────

   procedure Append_Text      (B : in out Instance; Text : String);
   procedure End_Text_Block   (B : in out Instance);

   --  ── Thinking blocks ───────────────────────────────────────────────────

   procedure Begin_Thinking   (B : in out Instance);
   procedure Append_Thinking  (B : in out Instance; Text : String);
   procedure End_Thinking     (B : in out Instance);

   --  ── Tool call segments ────────────────────────────────────────────────

   procedure Begin_Tool
     (B          : in out Instance;
      Name       :        String;
      Args       :        String;
      Session_Id :        String;
      Tool_Id    :        String);

   procedure End_Tool
     (B       : in out Instance;
      Tool_Id :        String;
      Status  :        Tool_End_Status;
      Result  :        String);

   --  ── Tool click result ─────────────────────────────────────────────────

   type Tool_Click_Result (Found : Boolean := False) is record
      case Found is
         when True =>
            Title   : Unbounded_String;
            Content : Unbounded_String;
         when False =>
            null;
      end case;
   end record;

   --  Handle a click at buffer coordinates (X, Y).  If the click falls
   --  within a tool-call block, returns Found => True with the formatted
   --  detail title and content.  The caller should display the detail
   --  (e.g. via Show_Text_Window).
   --  Called from the frontend's button-press handler on the conversation
   --  view, after converting widget coordinates to buffer coordinates.
   function Handle_Tool_Click
     (B : in out Instance;
      X :        Glib.Gint;
      Y :        Glib.Gint) return Tool_Click_Result;

   --  ── Action strips ──────────────────────────────────────────────────

   type Action_Kind is (Fork);

   type Action_Info (Kind : Action_Kind := Fork) is record
      case Kind is
         when Fork =>
            Fork_UUID   : Unbounded_String;
            Fork_Turn_N : Positive;
            Fork_Step_N : Natural;
      end case;
   end record;

   type Action_Click_Result (Found : Boolean := False) is record
      case Found is
         when True =>
            Action : Action_Info;
         when False =>
            null;
      end case;
   end record;

   --  Insert a clickable action strip with a display label.  The action
   --  data is stored in the buffer; Handle_Action_Click returns it when
   --  the user clicks.  Called by the GUI frontend's Append_Fork_Action.
   procedure Append_Action_Strip
     (B      : in out Instance;
      Label  :        String;
      Action :        Action_Info);

   --  Handle a click at buffer coordinates (X, Y).  If the click falls
   --  within an action strip, returns Found => True with the action data.
   --  Called from the frontend's button-press handler.
   function Handle_Action_Click
     (B : in out Instance;
      X :        Glib.Gint;
      Y :        Glib.Gint) return Action_Click_Result;

   --  ── Notices and footers ───────────────────────────────────────────────

   procedure Append_Notice
     (B    : in out Instance;
      Kind :        Notice_Kind;
      Text :        String);

   procedure Append_Turn_Footer (B : in out Instance; Text : String);

   --  ── Scroll ───────────────────────────────────────────────────────────

   procedure Scroll_To_End (B : in out Instance);

   --  ── Markdown rendering toggle ─────────────────────────────────────────

   procedure Set_Render_Markdown (B : in out Instance; Enabled : Boolean);
   --  Enable or disable Pango-markup rendering of assistant text blocks.
   --  When disabled, End_Text_Block inserts plain UTF-8 instead.

   function Get_Render_Markdown (B : Instance) return Boolean;
   --  Return the current markdown-rendering state.

private

   type Tool_Info is record
      Name          : Unbounded_String;
      Args          : Unbounded_String;
      Result_Text   : Unbounded_String;
      Result_Status : Tool_End_Status := Success;
      Tag           : Gtk.Text_Tag.Gtk_Text_Tag;
      Start_Mark    : Gtk.Text_Mark.Gtk_Text_Mark;
   end record;

   package Tool_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Tool_Info,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   package Action_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Action_Info,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   type Instance is tagged limited record
      The_View         : Gtk.Text_View.Gtk_Text_View;
      The_Buf          : Gtk.Text_Buffer.Gtk_Text_Buffer;
      Tag_Thinking     : Gtk.Text_Tag.Gtk_Text_Tag;
      Tag_Notice_Info  : Gtk.Text_Tag.Gtk_Text_Tag;
      Tag_Notice_Warn  : Gtk.Text_Tag.Gtk_Text_Tag;
      Tag_Notice_Error : Gtk.Text_Tag.Gtk_Text_Tag;
      Tag_Footer       : Gtk.Text_Tag.Gtk_Text_Tag;
      Tag_Action       : Gtk.Text_Tag.Gtk_Text_Tag;
      In_Text_Block    : Boolean := False;
      Stream_Mark      : Gtk.Text_Mark.Gtk_Text_Mark;
      Stream_Buf       : Unbounded_String;
      In_Thinking          : Boolean := False;
      Thinking_Tok : Coyote_App.Utils.Thinking_Tokenizer.Instance;
      Tools                : Tool_Maps.Map;
      Actions              : Action_Maps.Map;
      Action_Seq           : Natural := 0;
      Prefix_Emitted       : Boolean := False;
      Render_Markdown  : Boolean := True;
   end record;

end Coyote_GUI.Buffer;
