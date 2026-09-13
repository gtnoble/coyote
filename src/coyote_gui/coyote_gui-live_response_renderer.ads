--  Coyote_GUI.Live_Response_Renderer — incremental CSM-2 GTK presentation.
--
--  GTK operations are confined to the GTK main-loop task.  Call Create once,
--  then Begin and Apply for a live stream.  Clear discards the owned live
--  subtree contents without producing an authoritative final replacement.
--
--  Tables and MathML are deliberately deferred.  Their complete literal
--  payloads are retained through Deferred_Text for a later semantic-block
--  integration layer; this package never creates native table or math widgets.
--
--  Project: coyote

with Ada.Strings.Unbounded;
with Coyote_Renderer.Incremental;
with Gtk.Box;
with Gtk.Text_Buffer;
with Gtk.Text_Mark;
with Gtk.Text_Tag;
with Gtk.Text_View;

package Coyote_GUI.Live_Response_Renderer is

   type Instance is tagged limited private;

   type Style_Kind is
     (Strong_Style,
      Em_Style,
      Del_Style,
      Link_Style,
      Inline_Code_Style,
      Code_Block_Style,
      Blockquote_Style,
      List_Style,
      Heading_Style);

   --  Create the one renderer-owned subtree under Parent.  Repeated calls
   --  reuse the existing subtree and clear its live contents.
   procedure Create
     (R      : in out Instance;
      Parent : not null access Gtk.Box.Gtk_Box_Record'Class);

   --  Start a new live response.  Begin_Response clears the live subtree
   --  before marking the renderer ready for events.
   procedure Begin_Response (R : in out Instance);

   --  Discard all live content and reset parser-event state.  The subtree
   --  remains owned by Parent and can be reused by Begin.
   procedure Clear (R : in out Instance);

   --  Detach the renderer-owned subtree without destroying it.  Create can
   --  attach it again to a later response host.
   procedure Detach
     (R      : in out Instance;
      Parent : not null access Gtk.Box.Gtk_Box_Record'Class);

   --  Release GTK handles after the containing exchange has been removed.
   procedure Release (R : in out Instance);

   --  Apply one renderer-neutral CSM-2 event.  Events must arrive on the GTK
   --  main thread in increasing Sequence order.  Root markers delimit the
   --  output checkpoint used for localized invalid-root rollback; invalid
   --  source is left visible without active styles.
   procedure Apply
     (R     : in out Instance;
      Value :        Coyote_Renderer.Incremental.Live_Event);

   --  Mark the current live stream complete.  This does not replace it with
   --  a final semantic render and does not realize deferred blocks.
   procedure Finalize (R : in out Instance);

   function Is_Finalized (R : Instance) return Boolean;
   function Widget (R : Instance) return Gtk.Box.Gtk_Box;
   function Buffer (R : Instance) return Gtk.Text_Buffer.Gtk_Text_Buffer;
   function View (R : Instance) return Gtk.Text_View.Gtk_Text_View;
   function Text (R : Instance) return String;
   function Has_Style
     (R      : Instance;
      Style  : Style_Kind;
      Offset : Natural) return Boolean;

   type Deferred_Kind is (Deferred_Table, Deferred_Math);

   --  Deferred blocks are never realized as native widgets.  Each complete
   --  block remains available as an ordered source item for a later semantic
   --  integration layer.  Deferred_Text is retained as a compatibility
   --  summary of those sources.
   function Deferred_Block_Count (R : Instance) return Natural;
   function Deferred_Block_Kind_At
     (R : Instance; Index : Positive) return Deferred_Kind;
   function Deferred_Block_Source_At
     (R : Instance; Index : Positive) return String;
   function Deferred_Text (R : Instance) return String;
   function Invalid_Event_Count (R : Instance) return Natural;

private

   Max_List_Depth : constant Positive := 64;

   type List_Kind is (Unordered, Ordered);
   type List_Frame is record
      Kind       : List_Kind := Unordered;
      Next_Value : Positive  := 1;
   end record;
   type List_Frame_Array is array (Positive range 1 .. Max_List_Depth)
     of List_Frame;

   Max_Deferred_Blocks : constant Positive := 256;
   type Deferred_Block_Record is record
      Kind   : Deferred_Kind := Deferred_Table;
      Source : Ada.Strings.Unbounded.Unbounded_String;
   end record;
   type Deferred_Block_Array is
     array (Positive range 1 .. Max_Deferred_Blocks)
       of Deferred_Block_Record;

   type Tag_Set is record
      Strong      : Gtk.Text_Tag.Gtk_Text_Tag;
      Em          : Gtk.Text_Tag.Gtk_Text_Tag;
      Del         : Gtk.Text_Tag.Gtk_Text_Tag;
      Link        : Gtk.Text_Tag.Gtk_Text_Tag;
      Inline_Code : Gtk.Text_Tag.Gtk_Text_Tag;
      Code_Block  : Gtk.Text_Tag.Gtk_Text_Tag;
      Blockquote  : Gtk.Text_Tag.Gtk_Text_Tag;
      List        : Gtk.Text_Tag.Gtk_Text_Tag;
      Heading     : Gtk.Text_Tag.Gtk_Text_Tag;
   end record;

   type Root_Checkpoint is record
      Mark                 : Gtk.Text_Mark.Gtk_Text_Mark;
      Root_Id              : Natural := 0;
      List_Frames          : List_Frame_Array;
      List_Depth           : Natural := 0;
      Strong_Depth         : Natural := 0;
      Em_Depth             : Natural := 0;
      Del_Depth            : Natural := 0;
      Link_Depth           : Natural := 0;
      Inline_Code_Depth    : Natural := 0;
      Code_Block_Depth     : Natural := 0;
      Blockquote_Depth     : Natural := 0;
      Heading_Depth        : Natural := 0;
      Deferred_Depth       : Natural := 0;
      Deferred_Count       : Natural := 0;
      Deferred_Blocks      : Deferred_Block_Array;
      Active_Deferred_Kind : Deferred_Kind := Deferred_Table;
      Deferred_Payload     : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   type Instance is tagged limited record
      Root              : Gtk.Box.Gtk_Box;
      Text_Buffer       : Gtk.Text_Buffer.Gtk_Text_Buffer;
      Text_View         : Gtk.Text_View.Gtk_Text_View;
      Tags              : Tag_Set;
      List_Frames       : List_Frame_Array;
      List_Depth        : Natural := 0;
      Strong_Depth      : Natural := 0;
      Em_Depth          : Natural := 0;
      Del_Depth         : Natural := 0;
      Link_Depth        : Natural := 0;
      Inline_Code_Depth : Natural := 0;
      Code_Block_Depth  : Natural := 0;
      Blockquote_Depth  : Natural := 0;
      Heading_Depth     : Natural := 0;
      Deferred_Depth    : Natural := 0;
      Deferred_Count    : Natural := 0;
      Deferred_Blocks   : Deferred_Block_Array;
      Active_Deferred_Kind : Deferred_Kind := Deferred_Table;
      Invalid_Count     : Natural := 0;
      Invalid_State     : Boolean := False;
      Last_Sequence     : Natural := 0;
      Finalized         : Boolean := False;
      Started           : Boolean := False;
      Attached          : Boolean := False;
      Detached_Reference : Boolean := False;
      Deferred_Payload  : Ada.Strings.Unbounded.Unbounded_String;
      Checkpoint        : Root_Checkpoint;
      Checkpoint_Active : Boolean := False;
   end record;

end Coyote_GUI.Live_Response_Renderer;
