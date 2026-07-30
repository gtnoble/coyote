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
--    * Tool calls inserted as GtkFrame child-anchor widgets embedded in
--      the text flow.  End_Tool updates the frame label.
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
with Gtk.Frame;
with Gtk.Button;
with Gtk.Label;
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

   type Tool_Frame_Info is record
      Frame          : Gtk.Frame.Gtk_Frame;
      Summary_Label  : Gtk.Label.Gtk_Label;
      Summary_Prefix : Ada.Strings.Unbounded.Unbounded_String;
      Detail_Button  : Gtk.Button.Gtk_Button;
      Name           : Ada.Strings.Unbounded.Unbounded_String;
      Args           : Ada.Strings.Unbounded.Unbounded_String;
      Result_Text    : Ada.Strings.Unbounded.Unbounded_String;
      Result_Status  : Tool_End_Status := Success;
   end record;

   package Tool_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Tool_Frame_Info,
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
      In_Text_Block    : Boolean := False;
      Stream_Mark      : Gtk.Text_Mark.Gtk_Text_Mark;
      Stream_Buf       : Unbounded_String;
      In_Thinking          : Boolean := False;
      Tools                : Tool_Maps.Map;
      Prefix_Emitted       : Boolean := False;
      Render_Markdown  : Boolean := True;
   end record;

end Coyote_GUI.Buffer;
