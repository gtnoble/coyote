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

   type Instance is tagged limited private;

   procedure Reset (Parser : in out Instance);

   --  Copy the current typed semantic document into Target.  Handles in the
   --  target belong to Target and remain valid until its next Clear/Copy.
   procedure Snapshot
     (Parser : Instance;
      Target : in out Coyote_Renderer.Semantics.Document);

   --  Consume UTF-8 data synchronously.  CSM-2 is an explicit, case-sensitive
   --  XML-like language.  Unknown, malformed, crossing, and incomplete input
   --  remains visible source through the compatibility event and
   --  Invalid_Source semantic block.
   procedure Feed
     (Parser  : in out Instance;
      Data    :        String;
      Handler :        Event_Handler);

   --  Emit the exact uncompleted suffix as Invalid_Event, notify the semantic
   --  observer, and reset the parser.  A second Flush is a no-op.
   procedure Flush
     (Parser  : in out Instance;
      Handler :        Event_Handler);

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
      Source_Start  : Natural := 0;
      Opening_Length : Natural := 0;
      Raw           : Ada.Strings.Unbounded.Unbounded_String;
      Opaque        : Boolean := False;
      Invalid       : Boolean := False;
   end record;

   type Stack_Array is array (Positive range 1 .. Max_Nesting_Depth)
     of Stack_Entry;

   type Instance is tagged limited record
      Pending     : Ada.Strings.Unbounded.Unbounded_String;
      Source      : Ada.Strings.Unbounded.Unbounded_String;
      Document    : Coyote_Renderer.Semantics.Document;
      Stack       : Stack_Array;
      Cursor      : Natural := 0;
      Open        : Natural := 0;
      Invalid     : Boolean := False;
   end record;

end Coyote_Renderer.Incremental;
