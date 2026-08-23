--  Coyote_GUI.Conversation — Gtk.Layout-based conversation renderer.
--
--  Replaces Coyote_GUI.Buffer with a virtualized text renderer that only
--  lays out and draws visible blocks, giving acme-like resize performance
--  regardless of document size.
--
--  Data model: a flat vector of Logical_Line records.  Each line is a
--  variable-height block (paragraph, heading, math, tool-card row, etc.)
--  carrying a style tag, a cached Pixel_Height, and optional metadata.
--  Document height is the sum of block pixel heights.  On draw, only the
--  visible slice is wrapped and rendered via Cairo + Pango.
--
--  Selection is supported: click-drag to select, Ctrl+C to copy,
--  Ctrl+A to select all, Escape to clear.
--
--  All operations must be called from the GTK main loop thread.
--
--  Project: coyote

with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Vectors;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded;        use Ada.Strings.Unbounded;
with Coyote_App.Utils;
with Glib;
with Pango.Layout;
with Pango.Font;
with Gtk.Layout;
with Gtk.Scrolled_Window;

package Coyote_GUI.Conversation is

   --  ── Line style ────────────────────────────────────────────────────────

   type Line_Style is
     (Plain,              --  assistant text (may contain Pango markup)
      Display_Math,       --  Presentation MathML rendered by Lasem onto Cairo
      Heading_1,          --  level-1 heading
      Heading_2,          --  level-2 heading
      Heading_3,          --  level-3 heading
      Heading_4,          --  level-4 heading
      Heading_5,          --  level-5 heading
      Heading_6,          --  level-6 heading
      Code_Block,         --  fenced code block line
      Blockquote,         --  block quote line
      Thematic_Break,     --  horizontal rule
      List_Item_Bullet,   --  bullet list item
      List_Item_Ordered,  --  ordered list item
      Thinking,           --  reasoning block
      Notice_Info,        --  blue-background notice
      Notice_Warn,        --  amber notice
      Notice_Error,       --  red notice
      Footer,             --  dim horizontal-rule turn separator
      Action_Strip,         --  clickable fork action
      Tool_Header,          --  graphical tool-card header
      Tool_Argument,        --  graphical tool-card argument
      Tool_Footer);         --  graphical tool-card status

   --  ── Tool and action metadata ──────────────────────────────────────────

   type Tool_End_Status is (Success, Error, Cancelled);

   type Tool_Info is record
      Name             : Unbounded_String;
      Args             : Unbounded_String;
      Result_Text      : Unbounded_String;
      Media_Type       : Unbounded_String;
      Result_Status    : Tool_End_Status := Success;
      Model            : Unbounded_String;
      Source_Directory : Unbounded_String;
      Session_Start    : Unbounded_String;
      Turn_Index       : Positive := 1;
      Call_In_Turn     : Positive := 1;
   end record;
   type Action_Kind is (Fork);

   type Action_Info (Kind : Action_Kind := Fork) is record
      case Kind is
         when Fork =>
            Fork_UUID   : Unbounded_String;
            Fork_Turn_N : Positive;
            Fork_Step_N : Natural;
      end case;
   end record;

   --  ── Click results ─────────────────────────────────────────────────────

   type Tool_Click_Result (Found : Boolean := False) is record
      case Found is
         when True =>
            Info : Tool_Info;
         when False =>
            null;
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

   --  ── Instance ───────────────────────────────────────────────────────────

   type Instance is tagged limited private;

   --  Attach to a Gtk.Layout inside a Gtk.Scrolled_Window.
   --  The layout must already be created; this procedure connects
   --  the draw, button-press, motion-notify, button-release, and
   --  key-press signals and sets up event masks.
   procedure Attach
     (C      : in out Instance;
      Scroll   : not null access Gtk.Scrolled_Window.Gtk_Scrolled_Window_Record'Class;
      Layout_W : not null access Gtk.Layout.Gtk_Layout_Record'Class);

   --  ── Streaming assistant text ──────────────────────────────────────────

   procedure Append_Text      (C : in out Instance; Text : String);
   procedure End_Text_Block   (C : in out Instance);

   --  ── Thinking blocks ───────────────────────────────────────────────────

   procedure Begin_Thinking   (C : in out Instance);
   procedure Append_Thinking  (C : in out Instance; Text : String);
   procedure End_Thinking     (C : in out Instance);

   --  ── Tool call segments ────────────────────────────────────────────────

   procedure Begin_Tool
     (C               : in out Instance;
      Name            :        String;
      Args            :        String;
      Session_Id      :        String;
      Tool_Id          :        String;
      Model           :        String := "";
      Source_Directory :        String := "";
      Session_Start   :        String := "";
      Turn_Index      :        Positive := 1;
      Call_In_Turn    :        Positive := 1);

   procedure End_Tool
     (C          : in out Instance;
      Tool_Id    :        String;
      Status     :        Tool_End_Status;
      Result     :        String;
      Media_Type :        String := "");
   --  ── Click handling ────────────────────────────────────────────────────

   function Handle_Tool_Click
     (C : in out Instance;
      X :        Glib.Gint;
      Y :        Glib.Gint) return Tool_Click_Result;

   function Handle_Action_Click
     (C : in out Instance;
      X :        Glib.Gint;
      Y :        Glib.Gint) return Action_Click_Result;

   --  Move keyboard focus to the next or previous interactive item.
   procedure Move_Interactive_Focus
     (C       : in out Instance;
      Forward :        Boolean := True);

   --  Return the currently focused tool card, if any.
   function Focused_Tool (C : Instance) return Tool_Click_Result;

   --  Return the currently focused action strip, if any.
   function Focused_Action (C : Instance) return Action_Click_Result;

   --  Return a plain-text transcript suitable for native accessibility tools.
   function Transcript_Text (C : Instance) return String;

   --  Return the current selection as plain UTF-8 text.  This is independent
   --  of the global clipboard and is also the value offered through PRIMARY.
   function Selected_Text (C : Instance) return String;

   --  True when a conversation selection range is active.
   function Has_Selection (C : Instance) return Boolean;

   --  Select the entire conversation and publish PRIMARY.
   procedure Select_All (C : in out Instance);

   --  Clear the conversation selection and release PRIMARY if owned.
   procedure Clear_Selection (C : in out Instance);

   --  Copy the current conversation selection to CLIPBOARD.  PRIMARY is
   --  left unchanged.
   procedure Copy_Selection (C : in out Instance);

   --  Publish the current selection through the desktop PRIMARY selection.
   --  The ordinary clipboard remains unchanged.  Call from the GTK thread.
   procedure Publish_Primary_Selection (C : in out Instance);

   --  ── Action strips ─────────────────────────────────────────────────────
   procedure Append_Action_Strip
     (C      : in out Instance;
      Label  :        String;
      Action :        Action_Info);

   --  ── Notices and footers ───────────────────────────────────────────────

   type Footer_Kind is (Step_Footer, Final_Footer);

   procedure Append_Notice
     (C    : in out Instance;
      Kind :        Line_Style;  --  Notice_Info / Notice_Warn / Notice_Error
      Text :        String);

   procedure Append_Turn_Footer
     (C    : in out Instance;
      Text :        String;
      Kind :        Footer_Kind := Final_Footer);

   --  ── Markdown rendering toggle ─────────────────────────────────────────

   procedure Set_Render_Markdown (C : in out Instance; Enabled : Boolean);
   function Get_Render_Markdown (C : Instance) return Boolean;

   --  ── Debug logging ────────────────────────────────────────────────────

   procedure Set_Debug_Logging (C : in out Instance; Enabled : Boolean);
   function Get_Debug_Logging (C : Instance) return Boolean;

   --  ── Zoom ──────────────────────────────────────────────────────────────

   --  Apply a default Pango font and rescale display math.  Call from the
   --  GTK main loop after changing the frontend zoom level.
   procedure Set_Font
     (C         : in out Instance;
      Desc      :        Pango.Font.Pango_Font_Description;
      Math_Scale :       Long_Float := 1.0);

   --  Recompute the body-text line height, invalidate cached block
   --  heights, and queue a redraw.  Call after font changes.
   procedure Invalidate_Layout (C : in out Instance);

   --  ── Session lifecycle ─────────────────────────────────────────────────

   --  Clear all displayed content and reset internal state to empty.
   --  Used when replacing the current session with a fresh one.
   procedure Clear (C : in out Instance);

private

   type Logical_Line (Style : Line_Style := Plain) is record
      Text          : Unbounded_String;
      Has_Markup    : Boolean := False;  --  Text contains Pango markup
      Vis_Count     : Natural := 0;      --  cached wrap rows (tests / debug)
      Pixel_Height  : Natural := 0;      --  cached block height in pixels
      Math_Width    : Natural := 0;      --  measured width for display math
      Math_Baseline : Natural := 0;      --  baseline for display math
      Tool_Id      : Unbounded_String;
      Tool_Status  : Tool_End_Status := Success;
      Tool_Running : Boolean := False;
      case Style is
         when Action_Strip =>
            Action : Action_Info;
         when others =>
            null;
      end case;
   end record;

   package Line_Vectors is new Ada.Containers.Vectors (Positive, Logical_Line);

   type Tool_Block is record
      First_Line : Positive;  --  index into Lines
      Last_Line  : Positive;
      Info       : Tool_Info;
   end record;

   package Tool_Maps is new Ada.Containers.Vectors (Positive, Tool_Block);

   type Tool_Start_Info is record
      First_Line       : Positive;
      Footer_Line      : Positive;
      Name             : Unbounded_String;
      Args             : Unbounded_String;
      Model            : Unbounded_String;
      Source_Directory : Unbounded_String;
      Session_Start    : Unbounded_String;
      Turn_Index       : Positive := 1;
      Call_In_Turn     : Positive := 1;
   end record;
   package Tool_Start_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Tool_Start_Info,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   type Instance is tagged limited record
      Scroll        : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout_W      : Gtk.Layout.Gtk_Layout;
      Lines         : Line_Vectors.Vector;
      Tools         : Tool_Maps.Vector;
      --  Streaming state
      In_Text_Block    : Boolean := False;
      Stream_Buf        : Unbounded_String;
      Text_UTF8         : Coyote_App.Utils.UTF8_Stream.Instance;
      Stream_First_Line : Natural := 0;
      In_Thinking       : Boolean := False;
      Prefix_Emitted    : Boolean := False;
      Thinking_UTF8     : Coyote_App.Utils.UTF8_Stream.Instance;
      Thinking_Tok      : Coyote_App.Utils.Thinking_Tokenizer.Instance;
      Tool_Starts        : Tool_Start_Maps.Map;
      --  Layout.  Line_Height_Px is the body-text metric used as a
      --  fallback for empty blocks and as a zoom-sensitive baseline.
      --  Document height is Total_Height_Px, the sum of Pixel_Height.
      Line_Height_Px   : Glib.Gint := 18;
      Math_Scale       : Long_Float := 1.0;
      --  Reusable layout objects for measuring and drawing lines.
      --  Created in Attach, unreffed in Clear.
      Measure_Layout   : Pango.Layout.Pango_Layout;
      Draw_Layout      : Pango.Layout.Pango_Layout;
      --  Cache: width and line count at which Pixel_Height values
      --  are valid.  A zero Pixel_Height marks a line that must be
      --  measured again.
      Cache_Width_Px    : Glib.Gint := 0;
      Cached_Line_Count : Natural := 0;
      Cache_Dirty       : Boolean := True;
      Total_Vis_Lines   : Natural := 0;
      Total_Height_Px   : Natural := 0;
      Render_Markdown  : Boolean := True;
      Debug_Logging    : Boolean := False;
      --  Selection
      Sel_Dragging     : Boolean := False;
      Sel_Visible      : Boolean := False;
      Sel_Start_Line   : Natural := 0;
      Sel_Start_Byte   : Natural := 0;
      Sel_End_Line     : Natural := 0;
      Sel_End_Byte     : Natural := 0;
      --  Keyboard focus for tool cards and action strips.  Zero means none.
      Interactive_Focus : Natural := 0;
      --  True while this instance owns the desktop PRIMARY selection.
      Primary_Owner    : Boolean := False;
      --  Tool-card hover state.  Zero means no completed card is hovered.
      Hover_Tool_First : Natural := 0;
      Hover_Tool_Last  : Natural := 0;
      --  Use the GTK dark-theme preference for canvas colors.
      Dark_Theme       : Boolean := False;
      --  Action sequence for unique tag names
      Action_Seq       : Natural := 0;
   end record;

end Coyote_GUI.Conversation;
