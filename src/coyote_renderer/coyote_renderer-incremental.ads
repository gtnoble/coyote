--  Coyote_Renderer.Incremental — independent CSM-2 streaming parser.
--
--  The parser has no frontend, renderer, or external document-parser
--  dependencies.  The
--  legacy event callback remains available as a presentation compatibility
--  facade; Snapshot exposes the typed CSM-2 semantic document.
--
--  Project: coyote

with Ada.Strings.Unbounded;
with Coyote_Renderer.Semantics;

package Coyote_Renderer.Incremental is

   Max_Nesting_Depth : constant Positive := 64;
   Max_Tag_Bytes     : constant Positive := 256;
   Max_Attributes    : constant Positive := 16;

   type Event_Kind is
     (Text_Event,
      Paragraph_Begin_Event,
      Paragraph_End_Event,
      Line_Break_Event,
      Table_Event,
      Math_Event,
      Code_Event,
      Horizontal_Rule_Event,
      Heading_Event,
      Blockquote_Event,
      Invalid_Event);

   type Event is record
      Kind          : Event_Kind := Text_Event;
      Text          : Ada.Strings.Unbounded.Unbounded_String;
      Level          : Natural := 0;
      Semantic_Ready : Boolean := False;
      Source_End     : Natural := 0;
   end record;

   type Event_Handler is not null access procedure (Value : Event);

   --  Renderer-neutral events are emitted in deterministic source order.
   type Live_Event_Kind is
     (Live_Text_Event,
      Live_Strong_Begin_Event,
      Live_Strong_End_Event,
      Live_Em_Begin_Event,
      Live_Em_End_Event,
      Live_Del_Begin_Event,
      Live_Del_End_Event,
      Live_Link_Begin_Event,
      Live_Link_End_Event,
      Live_Code_Inline_Begin_Event,
      Live_Code_Inline_End_Event,
      Live_Hard_Break_Event,
      Live_Horizontal_Rule_Event,
      Live_Paragraph_Begin_Event,
      Live_Paragraph_End_Event,
      Live_Heading_Begin_Event,
      Live_Heading_End_Event,
      Live_Blockquote_Begin_Event,
      Live_Blockquote_End_Event,
      Live_List_Begin_Event,
      Live_List_End_Event,
      Live_Item_Begin_Event,
      Live_Item_End_Event,
      Live_Code_Begin_Event,
      Live_Code_End_Event,
      Live_Table_Begin_Event,
      Live_Table_End_Event,
      Live_Math_Begin_Event,
      Live_Math_End_Event,
      Live_Literal_Event,
      Live_Invalid_Event);

   --  Root_Id identifies the top-level transaction that produced the event.
   --  Root_Begin and Root_End delimit its provisional live output.  Invalid
   --  events carry only the affected root's exact source range.
   type Live_Event is record
      Kind         : Live_Event_Kind := Live_Text_Event;
      Text         : Ada.Strings.Unbounded.Unbounded_String;
      Detail       : Ada.Strings.Unbounded.Unbounded_String;
      Level        : Natural := 0;
      Source_Start : Natural := 0;
      Source_End   : Natural := 0;
      Context_Id   : Natural := 0;
      Root_Id      : Natural := 0;
      Sequence     : Natural := 0;
      Deferred     : Boolean := False;
      Complete     : Boolean := False;
      Root_Begin   : Boolean := False;
      Root_End     : Boolean := False;
   end record;

   type Live_Handler is access procedure (Value : Live_Event);

   type Instance is tagged limited private;

   procedure Reset (Parser : in out Instance);

   --  Copy the current typed semantic document into Target.  Handles in the
   --  target belong to Target and remain valid until its next Clear/Copy.
   procedure Snapshot
     (Parser : Instance;
      Target : in out Coyote_Renderer.Semantics.Document);

   --  Normalize a complete CSM terminal math block for native MathML.
   --  One redundant namespace-qualified nested math wrapper is unwrapped.
   function Normalize_Math_Source (Source : String) return String;
   --  Consume UTF-8 data synchronously.  CSM-2 is an explicit, case-sensitive
   --  XML-like language.  Unknown, malformed, crossing, and incomplete input
   --  remains visible source through the compatibility event and
   --  Invalid_Source semantic block.
   procedure Feed
     (Parser  : in out Instance;
      Data    :        String;
      Handler :        Event_Handler);

   --  Emit renderer-neutral live events.  This overload does not emit the
   --  compatibility Event stream.
   procedure Feed
     (Parser  : in out Instance;
      Data    :        String;
      Handler :        Live_Handler);

   --  Emit the exact uncompleted suffix as Invalid_Event, notify the semantic
   --  observer, and reset the parser.  A second Flush is a no-op.
   procedure Flush
     (Parser  : in out Instance;
      Handler :        Event_Handler);

   --  Complete a live stream.  Incomplete source is reported as a live
   --  invalid event; subsequent Flush calls are no-ops.
   procedure Flush
     (Parser  : in out Instance;
      Handler :        Live_Handler);

private

   type Stack_Entry is record
      Name          : Ada.Strings.Unbounded.Unbounded_String;
      Block         : Coyote_Renderer.Semantics.Block_Id :=
        Coyote_Renderer.Semantics.No_Block;
      Inline        : Coyote_Renderer.Semantics.Inline_Id :=
        Coyote_Renderer.Semantics.No_Inline;
      Row           : Coyote_Renderer.Semantics.Table_Row_Id :=
        Coyote_Renderer.Semantics.No_Table_Row;
      Cell          : Coyote_Renderer.Semantics.Table_Cell_Id :=
        Coyote_Renderer.Semantics.No_Table_Cell;
      Source_Start   : Natural := 0;
      Opening_Length : Natural := 0;
      Opaque_Emitted : Natural := 0;
      Context_Id     : Natural := 0;
      Raw            : Ada.Strings.Unbounded.Unbounded_String;
      Opaque         : Boolean := False;
      Invalid        : Boolean := False;
   end record;

   type Stack_Array is array (Positive range 1 .. Max_Nesting_Depth)
     of Stack_Entry;

   type Recovery_Kind is
     (No_Recovery,
      Ordinary_Recovery,
      Table_Recovery,
      Code_Recovery,
      Math_Recovery,
      Unknown_Recovery);

   type Instance is tagged limited record
      Pending        : Ada.Strings.Unbounded.Unbounded_String;
      Source         : Ada.Strings.Unbounded.Unbounded_String;
      Document       : Coyote_Renderer.Semantics.Document;
      Stack          : Stack_Array;
      Cursor         : Natural := 0;
      Open           : Natural := 0;
      Recovering     : Boolean := False;
      Flushed        : Boolean := False;
      Recovery_Mode  : Recovery_Kind := No_Recovery;
      Recovery_Start : Natural := 0;
      Recovery_End    : Natural := 0;
      Recovery_Name   : Ada.Strings.Unbounded.Unbounded_String;
      Recovery_Root_Id : Natural := 0;
      Recovery_Had_Provisional : Boolean := False;
      Recovery_Reported : Boolean := False;
      Live_Reported : Boolean := False;
      Recovery_Block : Coyote_Renderer.Semantics.Block_Id :=
        Coyote_Renderer.Semantics.No_Block;
      Localized_Recovery : Boolean := False;
      Localized_Start    : Natural := 0;
      Deferred_Text      : Boolean := False;
      Deferred_Text_Start : Natural := 0;
      Deferred_Tag        : Boolean := False;
      Deferred_Tag_Start   : Natural := 0;
      Next_Context   : Natural := 0;
      Next_Sequence  : Natural := 0;
      Live           : Live_Handler := null;
   end record;

end Coyote_Renderer.Incremental;
