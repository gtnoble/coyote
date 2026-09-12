--  Coyote_Incremental_Tests body.
--
--  Project: coyote

with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with AUnit.Assertions;
with AUnit.Test_Caller;
with Coyote_Renderer.Incremental;
with Coyote_Renderer.Semantics;

package body Coyote_Incremental_Tests is

   use AUnit.Assertions;
   use Coyote_Renderer.Incremental;
   use Coyote_Renderer.Semantics;

   type Log is record
      Text    : Unbounded_String;
      Invalid : Natural := 0;
      Events  : Natural := 0;
   end record;

   Test_Log   : aliased Log;
   Active_Log : access Log := Test_Log'Access;

   procedure Collect (Value : Event) is
   begin
      if Active_Log = null then
         return;
      end if;
      Active_Log.Events := Active_Log.Events + 1;
      if Value.Kind = Invalid_Event then
         Active_Log.Invalid := Active_Log.Invalid + 1;
      end if;
      Append (Active_Log.Text, To_String (Value.Text));
   end Collect;

   procedure Parse
     (Source : String; D : out Document; Result : out Log) is
      Parser : Instance;
   begin
      Test_Log := (others => <>);
      Active_Log := Test_Log'Access;
      Feed (Parser, Source, Collect'Access);
      Snapshot (Parser, D);
      Result := Test_Log;
      Active_Log := null;
   end Parse;

   procedure Test_Valid_Nested_Inlines (T : in out Test) is
      pragma Unreferenced (T);
      D      : Document;
      Result : Log;
      Para   : Block_Id;
      Strong : Inline_Id;
      Link   : Inline_Id;
   begin
      Parse
        ("<p>Hello <strong><em>world</em></strong> <link "
         & "url=""https://e.test/a&amp;b"">go</link><br/></p>", D, Result);
      Assert (Result.Invalid = 0, "nested inline source is valid");
      Assert (Block_Count (D) = 1, "one paragraph is built");
      Para := Block_At (D, 1);
      Assert (Block_Kind_Of (D, Para) = Paragraph, "paragraph kind is typed");
      Assert
        (Block_Inline_Count (D, Para) = 5,
         "paragraph inline order retained");
      Strong := Block_Inline_At (D, Para, 2);
      Assert (Inline_Kind_Of (D, Strong) = Coyote_Renderer.Semantics.Strong,
              "strong style is typed");
      Assert (Inline_Child_Count (D, Strong) = 1,
              "nested emphasis is a child");
      Assert (Inline_Kind_Of (D, Inline_Child_At (D, Strong, 1)) = Emphasis,
              "emphasis style is typed");
      Link := Block_Inline_At (D, Para, 4);
      Assert (Inline_Kind_Of (D, Link) = Coyote_Renderer.Semantics.Link,
              "link style is typed");
      Assert (Inline_URL (D, Link) = "https://e.test/a&b",
              "link URL entities are decoded");
      Assert (Result.Text = "Hello world go", "legacy text remains available");
   end Test_Valid_Nested_Inlines;

   procedure Test_Block_Nesting_And_Attributes (T : in out Test) is
      pragma Unreferenced (T);
      D      : Document;
      Result : Log;
      Quote  : Block_Id;
      List   : Block_Id;
      Item   : Block_Id;
      Head   : Block_Id;
   begin
      Parse
        ("<blockquote><h2>Title</h2><list kind=""ordered"" start=""3"">"
         & "<item>one</item></list></blockquote><h6>x</h6>", D, Result);
      Assert (Result.Invalid = 0, "nested block source is valid");
      Assert (Block_Count (D) = 2, "root block order retained");
      Quote := Block_At (D, 1);
      Assert (Block_Kind_Of (D, Quote) = Blockquote,
              "blockquote is typed");
      Assert (Block_Child_Count (D, Quote) = 2,
              "blockquote contains two block children");
      Head := Block_Child_At (D, Quote, 1);
      Assert (Heading_Level_Of (D, Head) = 2, "heading level retained");
      List := Block_Child_At (D, Quote, 2);
      Assert (List_Kind_Of (D, List) = Ordered_List,
              "ordered list attribute retained");
      Assert (List_Start (D, List) = 3, "list start attribute retained");
      Item := Block_Child_At (D, List, 1);
      Assert (Block_Kind_Of (D, Item) = List_Item, "item is a block child");
   end Test_Block_Nesting_And_Attributes;

   procedure Test_Explicit_Table_Model (T : in out Test) is
      pragma Unreferenced (T);
      D      : Document;
      Result : Log;
      Table  : Block_Id;
      Row    : Table_Row_Id;
      Cell   : Table_Cell_Id;
   begin
      Parse
        ("<table><row kind=""header""><cell align=""center"">Name</cell>"
         & "<cell align=""right"">Value</cell></row><row kind=""body"">"
         & "<cell>A</cell><cell>42</cell></row></table>", D, Result);
      Assert (Result.Invalid = 0, "explicit table source is valid");
      Table := Block_At (D, 1);
      Assert (Block_Kind_Of (D, Table) = Coyote_Renderer.Semantics.Table,
              "table is typed without GFM");
      Assert (Table_Row_Count (D, Table) = 2, "two explicit rows are built");
      Row := Table_Row_At (D, Table, 1);
      Assert (Table_Row_Is_Header (D, Row), "header row kind is retained");
      Assert (Table_Cell_Count (D, Row) = 2, "header cells are explicit");
      Cell := Table_Cell_At (D, Row, 2);
      Assert (Table_Cell_Value (D, Cell) = "Value", "cell value is retained");
      Assert (Table_Alignment_At (D, Table, 1) = Center,
              "center alignment is retained");
      Assert (Table_Alignment_At (D, Table, 2) = Right,
              "right alignment is retained");
   end Test_Explicit_Table_Model;

   procedure Test_Table_Alignments_And_Column_Count (T : in out Test) is
      pragma Unreferenced (T);
      D      : Document;
      Result : Log;
      Table  : Block_Id;
   begin
      Parse
        ("<table><row><cell align=""none"">a</cell>"
         & "<cell align=""left"">b</cell><cell align=""center"">c</cell>"
         & "<cell align=""right"">d</cell></row></table>", D, Result);
      Table := Block_At (D, 1);
      Assert (Result.Invalid = 0, "all documented alignments are valid");
      Assert (Table_Column_Count (D, Table) = 4,
              "column count comes from cells without alignment loss");
      Assert (Table_Alignment_At (D, Table, 1) = Unspecified,
              "none alignment is unspecified");
      Assert (Table_Alignment_At (D, Table, 2) = Left,
              "left alignment is retained");
      Assert (Table_Alignment_At (D, Table, 3) = Center,
              "center alignment is retained");
      Assert (Table_Alignment_At (D, Table, 4) = Right,
              "right alignment is retained");
      Parse
        ("<table><row><cell>a</cell><cell>b</cell></row>"
         & "<row><cell>c</cell><cell>d</cell></row></table>", D, Result);
      Assert (Result.Invalid = 0, "alignment-free table is valid");
      Assert (Table_Column_Count (D, Block_At (D, 1)) = 2,
              "alignment-free table still exposes its width");
   end Test_Table_Alignments_And_Column_Count;

   procedure Test_Table_Structure_Validation (T : in out Test) is
      pragma Unreferenced (T);
      D      : Document;
      Result : Log;
   begin
      Parse ("<table></table>", D, Result);
      Assert (Result.Invalid = 1, "empty table is invalid");
      Parse ("<table><row></row></table>", D, Result);
      Assert (Result.Invalid > 0, "empty row is invalid");
      Parse ("<table><row><cell></cell></row></table>", D, Result);
      Assert (Result.Invalid > 0, "empty cell is invalid");
      Parse ("<table><row><cell>a</cell></row>"
             & "<row><cell>b</cell><cell>c</cell></row></table>", D, Result);
      Assert (Result.Invalid > 0, "uneven rows are invalid");
      Parse ("<table><row kind=""body""><cell>a</cell></row>"
             & "<row kind=""header""><cell>b</cell></row></table>", D, Result);
      Assert (Result.Invalid > 0, "header after body is invalid");
      Parse ("<table><row kind=""header""><cell>a</cell></row>"
             & "<row kind=""header""><cell>b</cell></row></table>", D, Result);
      Assert (Result.Invalid > 0, "duplicate header is invalid");
      Parse ("<table/>", D, Result);
      Assert (Result.Invalid > 0, "self-closing table is invalid");
      Parse ("<table><row/><row><cell>a</cell></row></table>", D, Result);
      Assert (Result.Invalid > 0, "self-closing row is invalid");
      Parse ("<table><row><cell/></row></table>", D, Result);
      Assert (Result.Invalid > 0, "self-closing cell is invalid");
      Parse ("<table><p>x</p></table>", D, Result);
      Assert (Result.Invalid > 0, "non-row table child is invalid");
      Parse ("<table><row>x<cell>a</cell></row></table>", D, Result);
      Assert (Result.Invalid > 0, "non-cell row child is invalid");
      Parse ("<cell>a</cell>", D, Result);
      Assert (Result.Invalid > 0, "cell outside row is invalid");
      Parse ("<table><row><cell>" & "<p>x</p>"
             & "</cell></row></table>", D, Result);
      Assert (Result.Invalid > 0, "block nesting in a cell is invalid");
   end Test_Table_Structure_Validation;

   procedure Test_Table_Inline_Content_And_Source (T : in out Test) is
      pragma Unreferenced (T);
      D      : Document;
      Result : Log;
      Table  : Block_Id;
      Row    : Table_Row_Id;
      Cell   : Table_Cell_Id;
      Link   : Inline_Id;
   begin
      Parse
        ("<table><row kind=""header""><cell>plain <strong>bold</strong> "
         & "<em>em</em> <link url=""u&amp;v"">go</link> "
         & "<code-inline>x&lt;y</code-inline></cell></row></table>",
         D, Result);
      Assert (Result.Invalid = 0, "inline cell content is valid");
      Table := Block_At (D, 1);
      Row := Table_Row_At (D, Table, 1);
      Cell := Table_Cell_At (D, Row, 1);
      Assert (Table_Row_Source (D, Row) =
                "<row kind=""header""><cell>plain <strong>bold</strong> "
                & "<em>em</em> <link url=""u&amp;v"">go</link> "
                & "<code-inline>x&lt;y</code-inline></cell></row>",
              "row source preserves exact source order");
      Assert (Table_Cell_Source (D, Cell) =
                "<cell>plain <strong>bold</strong> <em>em</em> "
                & "<link url=""u&amp;v"">go</link> "
                & "<code-inline>x&lt;y</code-inline></cell>",
              "cell source preserves exact source order");
      Assert (Table_Cell_Value (D, Cell) = "plain bold em go x&lt;y",
              "cell decoded value includes inline content");
      Assert (Table_Cell_Inline_Count (D, Cell) = 8,
              "cell inline source order is retained");
      Link := Table_Cell_Inline_At (D, Cell, 6);
      Assert (Inline_Kind_Of (D, Link) = Coyote_Renderer.Semantics.Link,
              "link style is typed in cell");
      Assert (Inline_URL (D, Link) = "u&v", "cell link URL is decoded");
      Assert (Inline_Kind_Of (D, Table_Cell_Inline_At (D, Cell, 8)) =
                Inline_Code, "inline code is typed in cell");
   end Test_Table_Inline_Content_And_Source;

   procedure Test_Table_Delta_Boundaries (T : in out Test) is
      pragma Unreferenced (T);
      Whole : Instance;
      Split : Instance;
      A     : aliased Log := (others => <>);
      B     : aliased Log := (others => <>);
      D1    : Document;
      D2    : Document;
      Source : constant String :=
        "<table><row kind=""header""><cell align=""center"">H</cell>"
        & "</row><row><cell>v</cell></row></table>";
   begin
      Active_Log := A'Unchecked_Access;
      Feed (Whole, Source, Collect'Access);
      Snapshot (Whole, D1);
      Active_Log := B'Unchecked_Access;
      for I in Source'Range loop
         Feed (Split, Source (I .. I), Collect'Access);
      end loop;
      Snapshot (Split, D2);
      Active_Log := null;
      Assert (A.Invalid = B.Invalid, "every structural split preserves validity");
      Assert (Table_Column_Count (D1, Block_At (D1, 1)) =
                Table_Column_Count (D2, Block_At (D2, 1)),
              "every structural split preserves table width");
      Assert (Table_Row_Source (D1, Table_Row_At (D1, Block_At (D1, 1), 1)) =
                Table_Row_Source (D2, Table_Row_At (D2, Block_At (D2, 1), 1)),
              "every structural split preserves row source");
   end Test_Table_Delta_Boundaries;

   procedure Test_Table_Incomplete_And_Malformed_Recovery (T : in out Test) is
      pragma Unreferenced (T);
      Parser : Instance;
      Result : aliased Log := (others => <>);
      D      : Document;
   begin
      Active_Log := Result'Unchecked_Access;
      Feed (Parser, "<table><row><cell>x", Collect'Access);
      Flush (Parser, Collect'Access);
      Active_Log := null;
      Assert (Result.Invalid = 1, "incomplete table flush is one invalid event");
      Assert (Ada.Strings.Fixed.Index (To_String (Result.Text),
                                       "<table><row><cell>x") > 0,
              "incomplete table flush preserves exact source");
      Parse ("<table><row><cell align=""bogus"">x</cell></row></table>",
             D, Result);
      Assert (Result.Invalid > 0, "malformed alignment remains visible");
      Parse ("<table><row><cell>x</cell></row></table><table>bad</table>",
             D, Result);
      Assert (Result.Invalid > 0, "malformed table remains visible");
      Assert (Block_Count (D) >= 2, "malformed recovery keeps visible blocks");
   end Test_Table_Incomplete_And_Malformed_Recovery;

   procedure Test_Math_And_Code_Are_Opaque (T : in out Test) is
      pragma Unreferenced (T);
      D      : Document;
      Result : Log;
      Code   : Block_Id;
      Math   : Block_Id;
      Para   : Block_Id;
   begin
      Parse
        ("<code lang=""ada"">&lt;p&gt;<p>x</p>&amp;</code>"
         & "<math xmlns=""http://www.w3.org/1998/Math/MathML"">"
         & "<mrow><mi>x</mi><mo>&lt;</mo><mn>1</mn></mrow></math>"
         & "<p><code-inline>&lt;strong&gt;</code-inline></p>", D, Result);
      Assert (Result.Invalid = 0, "opaque regions are valid");
      Code := Block_At (D, 1);
      Math := Block_At (D, 2);
      Para := Block_At (D, 3);
      Assert (Code_Literal (D, Code) = "&lt;p&gt;<p>x</p>&amp;",
              "code payload remains byte-literal");
      Assert (Code_Language (D, Code) = "ada", "code language retained");
      Assert
        (MathML_Value (D, Math) =
           "<math xmlns=""http://www.w3.org/1998/Math/MathML"">"
           & "<mrow><mi>x</mi><mo>&lt;</mo><mn>1</mn></mrow></math>",
         "complete Presentation MathML payload is retained");
      Assert (Block_Inline_Count (D, Para) = 1,
              "code-inline is one inline terminal");
      Assert (Inline_Value (D, Block_Inline_At (D, Para, 1)) =
                "&lt;strong&gt;", "code-inline is not recursively parsed");
   end Test_Math_And_Code_Are_Opaque;

   procedure Test_Entities_And_Markdown_Are_Literal (T : in out Test) is
      pragma Unreferenced (T);
      D      : Document;
      Result : Log;
      Para   : Block_Id;
   begin
      Parse
        ("<p>*bold* **not strong** &lt;x&gt; &amp;quot;"
         & "$$x$$</p>", D, Result);
      Assert (Result.Invalid = 0, "escaped ordinary text is valid");
      Para := Block_At (D, 1);
      Assert (Block_Inline_Count (D, Para) = 1,
              "Markdown punctuation does not create inline nodes");
      Assert (Inline_Value (D, Block_Inline_At (D, Para, 1)) =
                "*bold* **not strong** <x> &quot;$$x$$",
              "ordinary entities decode and Markdown stays literal");
   end Test_Entities_And_Markdown_Are_Literal;

   procedure Test_Pipe_Text_Is_Not_A_Table (T : in out Test) is
      pragma Unreferenced (T);
      D      : Document;
      Result : Log;
   begin
      Parse ("<table>| H | V |" & ASCII.LF
             & "| --- | --- |</table>", D, Result);
      Assert (Result.Invalid > 0,
              "pipe-separated table text is not CSM table syntax");
      Assert (Table_Row_Count (D, Block_At (D, 1)) = 0,
              "pipe text creates no implicit rows");
   end Test_Pipe_Text_Is_Not_A_Table;

   procedure Test_Malformed_Source_Is_Visible (T : in out Test) is
      pragma Unreferenced (T);
      D      : Document;
      Result : Log;
   begin
      Parse ("<p><strong>x</p></strong><P>bad</P><p a=""x"">z</p>", D, Result);
      Assert (Result.Invalid > 0, "crossing and mis-cased tags are invalid");
      Assert
        (Ada.Strings.Fixed.Index (To_String (Result.Text), "<p>") > 0,
         "malformed source is visible");
      Assert (Block_Count (D) > 0, "invalid source has a semantic fallback");
      Assert
        (Block_Kind_Of (D, Block_At (D, Block_Count (D))) = Invalid_Source,
         "invalid fallback is typed");
   end Test_Malformed_Source_Is_Visible;

   procedure Test_Incomplete_Flush_Is_Exact (T : in out Test) is
      pragma Unreferenced (T);
      Parser : Instance;
      Result : aliased Log := (others => <>);
   begin
      Active_Log := Result'Unchecked_Access;
      Feed (Parser, "prefix <p>tail", Collect'Access);
      Flush (Parser, Collect'Access);
      Active_Log := null;
      Assert (Result.Invalid = 1, "flush emits exactly one invalid suffix");
      Assert
        (Ada.Strings.Fixed.Index (To_String (Result.Text), "<p>tail") > 0,
         "flush preserves exact incomplete source");
      Flush (Parser, Collect'Access);
      Assert (Result.Invalid = 1, "second flush is deterministic no-op");
   end Test_Incomplete_Flush_Is_Exact;

   procedure Test_Delta_Boundary_Invariance (T : in out Test) is
      pragma Unreferenced (T);
      Whole : Instance;
      Split : Instance;
      A     : aliased Log := (others => <>);
      B     : aliased Log := (others => <>);
      D1    : Document;
      D2    : Document;
   begin
      Active_Log := A'Unchecked_Access;
      Feed (Whole, "<p>a<strong>b</strong>c</p>", Collect'Access);
      Snapshot (Whole, D1);
      Active_Log := B'Unchecked_Access;
      Feed (Split, "<p>a<str", Collect'Access);
      Feed (Split, "ong>b</strong>c</p>", Collect'Access);
      Snapshot (Split, D2);
      Active_Log := null;
      Assert (A.Invalid = B.Invalid, "split and whole validity agree");
      Assert (Block_Count (D1) = Block_Count (D2),
              "split and whole block counts agree");
      Assert (Block_Source (D1, Block_At (D1, 1)) =
                Block_Source (D2, Block_At (D2, 1)),
              "split and whole source agree");
   end Test_Delta_Boundary_Invariance;

   procedure Test_UTF8_Splits (T : in out Test) is
      pragma Unreferenced (T);
      Parser : Instance;
      Result : aliased Log := (others => <>);
      D      : Document;
   begin
      Active_Log := Result'Unchecked_Access;
      Feed (Parser, "<p>caf", Collect'Access);
      Feed (Parser, String'(1 => Character'Val (16#C3#)), Collect'Access);
      Feed
        (Parser, String'(1 => Character'Val (16#A9#)) & "</p>",
         Collect'Access);
      Snapshot (Parser, D);
      Active_Log := null;
      Assert (Result.Invalid = 0, "UTF-8 split is accepted");
      Assert
        (Block_Inline_Count (D, Block_At (D, 1)) = 2,
         "UTF-8 split yields only text fragments");
      Assert
        (Inline_Source (D, Block_Inline_At (D, Block_At (D, 1), 1))
         & Inline_Source (D, Block_Inline_At (D, Block_At (D, 1), 2))
         = "caf" & Character'Val (16#C3#) & Character'Val (16#A9#),
         "UTF-8 source bytes are not lost at delta boundary");
   end Test_UTF8_Splits;

   procedure Test_Nesting_And_Tag_Limits (T : in out Test) is
      pragma Unreferenced (T);
      D      : Document;
      Result : Log;
      Deep   : Unbounded_String := To_Unbounded_String ("<p>x");
   begin
      for I in 1 .. Max_Nesting_Depth + 1 loop
         Append (Deep, "<strong>");
      end loop;
      Parse (To_String (Deep), D, Result);
      Assert (Result.Invalid > 0, "nesting limit rejects excessive depth");
      Parse ("<p>bad</p a=""x"">", D, Result);
      Assert (Result.Invalid > 0, "malformed closing attributes are rejected");
      Parse ("<p", D, Result);
      Assert (Result.Invalid = 0, "incomplete input is deferred until Flush");
   end Test_Nesting_And_Tag_Limits;

   procedure Test_Empty_Elements_And_Event_Compatibility (T : in out Test) is
      pragma Unreferenced (T);
      Parser : Instance;
      Result : aliased Log := (others => <>);
      D      : Document;
   begin
      Active_Log := Result'Unchecked_Access;
      Feed (Parser, "text<hr/><p>x<br/>y</p>", Collect'Access);
      Snapshot (Parser, D);
      Active_Log := null;
      Assert (Result.Invalid = 0, "empty tags are valid only in legal form");
      Assert (Block_Count (D) = 2, "rule and paragraph are typed roots");
      Assert
        (Block_Kind_Of (D, Block_At (D, 1)) = Horizontal_Rule,
         "horizontal rule is a semantic block");
      Assert (Result.Events > 0, "legacy events remain synchronous");
   end Test_Empty_Elements_And_Event_Compatibility;

   package Caller is new AUnit.Test_Caller (Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (Caller.Create
        ("CSM-2 nested inline semantics", Test_Valid_Nested_Inlines'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 nested blocks and attributes",
         Test_Block_Nesting_And_Attributes'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 explicit table model", Test_Explicit_Table_Model'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 table alignments and column count",
         Test_Table_Alignments_And_Column_Count'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 table structure validation",
         Test_Table_Structure_Validation'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 table inline content and source",
         Test_Table_Inline_Content_And_Source'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 table delta boundaries", Test_Table_Delta_Boundaries'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 table incomplete and malformed recovery",
         Test_Table_Incomplete_And_Malformed_Recovery'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 opaque code and MathML",
         Test_Math_And_Code_Are_Opaque'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 entities and Markdown literalness",
         Test_Entities_And_Markdown_Are_Literal'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 pipe text is not a table",
         Test_Pipe_Text_Is_Not_A_Table'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 malformed source recovery",
         Test_Malformed_Source_Is_Visible'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 exact incomplete flush",
         Test_Incomplete_Flush_Is_Exact'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 delta boundary invariance",
         Test_Delta_Boundary_Invariance'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 UTF-8 split safety", Test_UTF8_Splits'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 parser limits", Test_Nesting_And_Tag_Limits'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 empty tags and compatibility events",
         Test_Empty_Elements_And_Event_Compatibility'Access));
      return Result;
   end Suite;

end Coyote_Incremental_Tests;
