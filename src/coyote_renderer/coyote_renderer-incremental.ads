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
      Source_End     : Natural := 0;
   end record;

   --  Deprecated compatibility events retained only for parser qualification;
   --  no production consumer remains.  Semantic_Event is the sole
   --  incremental protocol for production.
   type Event_Handler is not null access procedure (Value : Event);

   --  Semantic mutations describe changes to the canonical Document.  They
   --  never expose presentation state and are emitted in parser order.  Source
   --  ranges are one-based and inclusive; a mutation's range denotes the
   --  exact source slice that caused it.  Document_Finish may use 0/0.  Feed
   --  call boundaries are not semantic boundaries: adjacent provisional
   --  payload changes with the same root and kind may be coalesced when
   --  comparing journals from different provider-delta splits.
   type Semantic_Event_Kind is
     (Semantic_Root_Begin_Event,
      Semantic_Text_Change_Event,
      Semantic_Inline_Change_Event,
      Semantic_Root_Change_Event,
      Semantic_Root_Commit_Event,
      Semantic_Root_Replace_Invalid_Event,
      Semantic_Localized_Recovery_Event,
      Semantic_Document_Finish_Event);

   type Semantic_Event is record
      Kind         : Semantic_Event_Kind := Semantic_Root_Change_Event;
      Root_Id      : Natural := 0;
      Source_Start : Natural := 0;
      Source_End   : Natural := 0;
      Sequence     : Natural := 0;
      Block_Kind   : Coyote_Renderer.Semantics.Block_Kind :=
        Coyote_Renderer.Semantics.Invalid_Source;
      Inline_Kind  : Coyote_Renderer.Semantics.Inline_Kind :=
        Coyote_Renderer.Semantics.Text;
      Text         : Ada.Strings.Unbounded.Unbounded_String;
      Provisional  : Boolean := False;
      Complete     : Boolean := False;
      Localized    : Boolean := False;
   end record;

   type Semantic_Handler is access procedure (Value : Semantic_Event);

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


   --  Emit semantic mutations against the canonical Document.  This overload
   --  does not emit either compatibility or live presentation events.
   procedure Feed
     (Parser  : in out Instance;
      Data    :        String;
      Handler :        Semantic_Handler);

   --  Emit the exact uncompleted suffix as Invalid_Event, notify the semantic
   --  observer, and reset the parser.  A second Flush is a no-op.
   procedure Flush
     (Parser  : in out Instance;
      Handler :        Event_Handler);



   --  Complete a semantic stream.  The final mutation and document-finished
   --  events are emitted once; repeated Flush calls are no-ops.
   procedure Flush
     (Parser  : in out Instance;
      Handler :        Semantic_Handler);

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
      Recovery_Block : Coyote_Renderer.Semantics.Block_Id :=
        Coyote_Renderer.Semantics.No_Block;
      Localized_Recovery : Boolean := False;
      Localized_Start    : Natural := 0;
      Deferred_Text      : Boolean := False;
      Deferred_Text_Start : Natural := 0;
      Deferred_Tag        : Boolean := False;
      Deferred_Tag_Start   : Natural := 0;
      Next_Context      : Natural := 0;
      Semantic_Sequence : Natural := 0;
      Semantic          : Semantic_Handler := null;
   end record;

end Coyote_Renderer.Incremental;
