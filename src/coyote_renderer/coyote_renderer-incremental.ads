--  Coyote_Renderer.Incremental — restricted CSM streaming parser.
--
--  The parser retains only an incomplete tag between Feed calls and emits
--  semantic events synchronously through the supplied handler.
--
--  Project: coyote

with Ada.Strings.Unbounded;

package Coyote_Renderer.Incremental is

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
      Kind  : Event_Kind := Text_Event;
      Text  : Ada.Strings.Unbounded.Unbounded_String;
      Level : Natural := 0;
   end record;

   type Event_Handler is not null access procedure (Value : Event);

   type Instance is tagged limited private;

   procedure Reset (Parser : in out Instance);

   --  Consume Data and emit semantic events synchronously.  Recognised CSM
   --  elements are <text>, <p>, </p>, <br/>, <table>...</table>,
   --  <math>...</math> or <math ...>...</math>, <code>...</code>,
   --  <hr/> or <hr />, <h1>...</h1> through <h6>...</h6>, and
   --  <blockquote>...</blockquote>. Table blocks contain GFM table source;
   --  math blocks contain one complete MathML document; code blocks contain
   --  literal source text; horizontal rules, headings, and blockquotes are
   --  native components.
   --  Unknown or incomplete elements are emitted as visible source so
   --  malformed model output remains safe.
   procedure Feed
     (Parser  : in out Instance;
      Data    :        String;
      Handler :        Event_Handler);

   --  Emit an incomplete trailing fragment as an Invalid_Event and reset.
   procedure Flush
     (Parser  : in out Instance;
      Handler :        Event_Handler);

private

   type Block_Kind is
     (No_Block, Table_Block, Math_Block, Code_Block, Heading_Block,
      Blockquote_Block);

   type Instance is tagged limited record
      Pending : Ada.Strings.Unbounded.Unbounded_String;
      Block   : Block_Kind := No_Block;
      Level   : Natural := 0;
      Buffer  : Ada.Strings.Unbounded.Unbounded_String;
   end record;

end Coyote_Renderer.Incremental;
