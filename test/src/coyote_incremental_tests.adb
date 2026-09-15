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

   function Snapshot_Text (D : Document) return String is
      Result : Unbounded_String;
   begin
      for Position in 1 .. Block_Count (D) loop
         declare
            Block : constant Block_Id := Block_At (D, Position);
            Previous_Text : Boolean := False;
         begin
            Append (Result, Block_Kind'Image (Block_Kind_Of (D, Block)));
            Append (Result, ":" & Block_Source (D, Block));
            for Inline_Position in 1 .. Block_Inline_Count (D, Block) loop
               declare
                  Inline : constant Inline_Id :=
                    Block_Inline_At (D, Block, Inline_Position);
               begin
                  if Inline_Kind_Of (D, Inline) = Text
                    and then Previous_Text
                  then
                     Append (Result, Inline_Source (D, Inline));
                  else
                     Append (Result, "|" & Inline_Kind'Image
                       (Inline_Kind_Of (D, Inline)) & ":" & Inline_Source (D, Inline));
                  end if;
                  Previous_Text := Inline_Kind_Of (D, Inline) = Text;
               end;
            end loop;
         end;
      end loop;
      return To_String (Result);
   end Snapshot_Text;

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

   procedure Test_Table_Structural_Whitespace (T : in out Test) is
      pragma Unreferenced (T);
      D      : Document;
      Result : Log;
      Source : constant String :=
        "<table>" & ASCII.LF & "  <row>" & ASCII.HT
        & "<cell>A</cell>" & ASCII.CR & "  <cell>B</cell>" & ASCII.LF
        & "</row>" & ASCII.LF & " <row><cell>C</cell><cell>D</cell>"
        & "</row>" & ASCII.LF & "</table>";
      Table  : Block_Id;
   begin
      Parse (Source, D, Result);
      Assert (Result.Invalid = 0,
              "structural table whitespace is ignored");
      Table := Block_At (D, 1);
      Assert (Table_Row_Count (D, Table) = 2,
              "whitespace table retains both rows");
      Assert (Table_Column_Count (D, Table) = 2,
              "whitespace table retains its width");
      Assert
        (Table_Cell_Value
           (D, Table_Cell_At (D, Table_Row_At (D, Table, 1), 1)) = "A",
         "whitespace table retains first cell value");
      Assert
        (Table_Row_Source (D, Table_Row_At (D, Table, 1)) =
           "<row>" & ASCII.HT & "<cell>A</cell>" & ASCII.CR
           & "  <cell>B</cell>" & ASCII.LF & "</row>",
         "whitespace table preserves exact row source");
      Parse ("<table> meaningful<row><cell>x</cell></row></table>",
             D, Result);
      Assert (Result.Invalid > 0,
              "meaningful table text remains invalid");
      Parse ("<table><row> meaningful<cell>x</cell></row></table>",
             D, Result);
      Assert (Result.Invalid > 0,
              "meaningful row text remains invalid");
   end Test_Table_Structural_Whitespace;

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
      Assert (Block_Count (D) = 2,
              "malformed recovery preserves the valid table root");
      Assert (Block_Kind_Of (D, Block_At (D, 1)) = Table,
              "valid table remains typed before malformed table");
      Assert (Block_Kind_Of (D, Block_At (D, 2)) = Invalid_Source,
              "malformed table is one isolated invalid root");
      Assert
        (Block_Source (D, Block_At (D, 2)) = "<table>bad</table>",
         "malformed table source is preserved exactly");
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

   procedure Test_Whitespace_Robustness (T : in out Test) is
      pragma Unreferenced (T);
      D      : Document;
      Result : Log;
      Code   : Block_Id;
      Para   : Block_Id;
      Math   : Block_Id;
      Table        : Block_Id;
      Split_Parser : Instance;
      Split_Result : aliased Log := (others => <>);
      Source       : constant String :=
        "<p><link url=""https://e.test/?a=1>0"">x</link></p>"
        & "<code lang=""ada"">line</code   >"
        & "<math xmlns=""http://www.w3.org/1998/Math/MathML"">"
        & ASCII.LF & "  <mrow><mi>x</mi></mrow>" & ASCII.LF
        & "</math   >"
        & "<table>" & "&#x20;" & ASCII.LF
        & "<row><cell>v</cell></row></table>";
   begin
      Parse (Source, D, Result);
      Assert (Result.Invalid = 0, "formatted CSM whitespace is valid");
      Assert (Block_Count (D) = 4, "formatted source retains block order");
      Para := Block_At (D, 1);
      Code := Block_At (D, 2);
      Math := Block_At (D, 3);
      Table := Block_At (D, 4);
      Assert (Inline_URL (D, Block_Inline_At (D, Para, 1)) =
                "https://e.test/?a=1>0",
              "quoted greater-than remains inside the attribute");
      Assert (Code_Literal (D, Code) = "line",
              "spaced code closer excludes its syntax from payload");
      Assert (Block_Source (D, Code) =
                "<code lang=""ada"">line</code   >",
              "spaced code closer is preserved in source");
      Assert (MathML_Value (D, Math) =
                "<math xmlns=""http://www.w3.org/1998/Math/MathML"">"
                & ASCII.LF & "  <mrow><mi>x</mi></mrow>" & ASCII.LF
                & "</math   >",
              "spaced MathML closer preserves source value");
      Assert (Normalize_Math_Source (MathML_Value (D, Math)) =
                "<math xmlns=""http://www.w3.org/1998/Math/MathML"">"
                & ASCII.LF & "  <mrow><mi>x</mi></mrow>" & ASCII.LF
                & "</math>",
              "spaced MathML closer normalizes for rendering");
      Assert (Table_Row_Count (D, Table) = 1,
              "decoded structural whitespace is ignored");
      Active_Log := Split_Result'Unchecked_Access;
      Feed (Split_Parser, "<code>part</co", Collect'Access);
      Feed (Split_Parser, "de ", Collect'Access);
      Feed (Split_Parser, ">", Collect'Access);
      Snapshot (Split_Parser, D);
      Active_Log := null;
      Assert (Split_Result.Invalid = 0,
              "split whitespace-formatted closer is valid");
      Assert (Block_Count (D) = 1 and then
                Code_Literal (D, Block_At (D, 1)) = "part",
              "split whitespace-formatted closer preserves payload");
   end Test_Whitespace_Robustness;

   procedure Test_Redundant_Math_Wrapper (T : in out Test) is
      pragma Unreferenced (T);
      Less_Equal : constant String :=
        Character'Val (16#E2#) & Character'Val (16#89#)
        & Character'Val (16#A4#);
      D      : Document;
      Result : Log;
      Source : constant String :=
        "<math xmlns=""http://www.w3.org/1998/Math/MathML"">"
        & ASCII.LF & "  <math xmlns=""http://www.w3.org/1998/Math/MathML"">"
        & "<mrow><mi>x</mi><mo>" & Less_Equal
        & "</mo><mn>10</mn></mrow>"
        & "</math>" & ASCII.LF & "</math>";
      Math : Block_Id;
      Qualified : constant String :=
        "<math xmlns=""http://www.w3.org/1998/Math/MathML"">";
      Normalized : constant String :=
        Qualified & "<mrow><mi>x</mi><mo>" & Less_Equal
        & "</mo><mn>10</mn></mrow></math>";
   begin
      Parse (Source, D, Result);
      Assert (Result.Invalid = 0,
              "qualified redundant MathML wrapper is accepted");
      Assert (Block_Count (D) = 1,
              "redundant MathML remains one semantic block");
      Math := Block_At (D, 1);
      Assert (Block_Kind_Of (D, Math) = Display_Math,
              "redundant MathML remains display math");
      Assert (MathML_Source (D, Math) = Source,
              "redundant MathML preserves complete source");
      Assert (Normalize_Math_Source (Source) = Normalized,
              "normalization unwraps the redundant outer wrapper");
      Assert
        (Normalize_Math_Source
           ("<math xmlns=""http://www.w3.org/1998/Math/MathML""><math>"
            & "<mi>x</mi></math></math>") =
           "<math xmlns=""http://www.w3.org/1998/Math/MathML""><math>"
           & "<mi>x</mi></math></math>",
         "unqualified nested MathML remains unchanged");
   end Test_Redundant_Math_Wrapper;

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
      Assert (Block_Count (D) = 3,
              "each malformed top-level root has its own fallback");
      Assert
        (Block_Kind_Of (D, Block_At (D, 1)) = Invalid_Source,
         "crossing fallback is typed");
      Assert
        (Block_Kind_Of (D, Block_At (D, 2)) = Invalid_Source,
         "mis-cased fallback is typed");
      Assert
        (Block_Kind_Of (D, Block_At (D, 3)) = Invalid_Source,
         "attribute fallback is typed");
      Assert
        (Block_Source (D, Block_At (D, 1)) = "<p><strong>x</p></strong>",
         "crossing fallback preserves exact source");
      Assert
        (Block_Source (D, Block_At (D, 2)) = "<P>bad</P>",
         "mis-cased fallback preserves exact source");
      Assert
        (Block_Source (D, Block_At (D, 3)) = "<p a=""x"">z</p>",
         "attribute fallback preserves exact source");
      Parse ("<unknown>bad<p>later</p>", D, Result);
      Assert (Result.Invalid = 1,
              "unclosed unknown root is reported once");
      Assert (Block_Count (D) = 2,
              "paragraph after unclosed unknown root is recovered");
      Assert (Block_Source (D, Block_At (D, 1)) = "<unknown>bad",
              "unclosed unknown source ends at the safe paragraph boundary");
      Assert (Block_Kind_Of (D, Block_At (D, 2)) = Paragraph,
              "paragraph after unclosed unknown root remains typed");
      Parse ("<unknown>bad<h2>later</h2>", D, Result);
      Assert (Block_Count (D) = 2 and then
              Block_Kind_Of (D, Block_At (D, 2)) = Heading,
              "heading after unclosed unknown root remains typed");
      Parse ("<unknown>bad<table><row><cell>x</cell></row></table>", D,
             Result);
      Assert (Block_Count (D) = 2 and then
              Block_Source (D, Block_At (D, 1)) = "<unknown>bad" and then
              Block_Kind_Of (D, Block_At (D, 2)) = Table,
              "table after unclosed unknown root remains typed");
      declare
         Split_Parser : Instance;
         Split_Result : aliased Log := (others => <>);
         Split_D      : Document;
      begin
         Active_Log := Split_Result'Unchecked_Access;
         Feed (Split_Parser, "<unknown>bad<p>lat", Collect'Access);
         Feed (Split_Parser, "er</p>", Collect'Access);
         Snapshot (Split_Parser, Split_D);
         Active_Log := null;
         Assert (Split_Result.Invalid = 1,
                 "split unclosed unknown recovery reports once");
         Assert (Block_Count (Split_D) = 2 and then
                 Block_Source (Split_D, Block_At (Split_D, 1)) =
                   "<unknown>bad" and then
                 Block_Kind_Of (Split_D, Block_At (Split_D, 2)) = Paragraph,
                 "split recovery resumes at the paragraph boundary");
         Reset (Split_Parser);
         Split_Result := (others => <>);
         Active_Log := Split_Result'Unchecked_Access;
         Feed (Split_Parser, "<unknown>bad<h2>la", Collect'Access);
         Feed (Split_Parser, "ter</h2>", Collect'Access);
         Snapshot (Split_Parser, Split_D);
         Assert (Split_Result.Invalid = 1 and then
                 Block_Kind_Of (Split_D, Block_At (Split_D, 2)) = Heading,
                 "split recovery resumes at the heading boundary");
         Reset (Split_Parser);
         Split_Result := (others => <>);
         Active_Log := Split_Result'Unchecked_Access;
         Feed (Split_Parser,
               "<unknown>bad<table><row><cell>x</cell></row></ta",
               Collect'Access);
         Feed (Split_Parser, "ble>", Collect'Access);
         Snapshot (Split_Parser, Split_D);
         Active_Log := null;
         Assert (Split_Result.Invalid = 1 and then
                 Block_Kind_Of (Split_D, Block_At (Split_D, 2)) = Table,
                 "split recovery resumes at the table boundary");
      end;
   end Test_Malformed_Source_Is_Visible;

   procedure Test_Unknown_Recovery_Before_Opaque_Roots (T : in out Test) is
      pragma Unreferenced (T);
      D      : Document;
      Result : Log;
   begin
      Parse ("<unknown>bad<code><p>literal</p></code><p>later</p>", D,
             Result);
      Assert (Result.Invalid = 1,
              "unknown prefix is one invalid source region before code");
      Assert (Block_Count (D) = 3,
              "code and later paragraph remain separate roots");
      Assert (Block_Kind_Of (D, Block_At (D, 1)) = Invalid_Source,
              "unknown prefix is typed Invalid_Source");
      Assert (Block_Source (D, Block_At (D, 1)) = "<unknown>bad",
              "invalid prefix ends immediately before code");
      Assert (Block_Kind_Of (D, Block_At (D, 2)) = Code_Block,
              "code opening is owned by the normal parser");
      Assert (Code_Literal (D, Block_At (D, 2)) = "<p>literal</p>",
              "code payload remains opaque and literal");
      Assert (Block_Kind_Of (D, Block_At (D, 3)) = Paragraph,
              "paragraph after code remains typed");
      Assert (Block_Source (D, Block_At (D, 3)) = "<p>later</p>",
              "later paragraph source remains exact");

      Parse ("<unknown>bad<math xmlns=""http://www.w3.org/1998/Math/MathML"">"
             & "<mi>x</mi></math><p>later</p>", D, Result);
      Assert (Result.Invalid = 1,
              "unknown prefix is one invalid source region before MathML");
      Assert (Block_Count (D) = 3,
              "MathML and later paragraph remain separate roots");
      Assert (Block_Kind_Of (D, Block_At (D, 1)) = Invalid_Source,
              "MathML case has a typed invalid prefix");
      Assert (Block_Source (D, Block_At (D, 1)) = "<unknown>bad",
              "MathML invalid prefix ends before the qualified root");
      Assert (Block_Kind_Of (D, Block_At (D, 2)) = Display_Math,
              "qualified MathML opening is owned by the normal parser");
      Assert
        (MathML_Value (D, Block_At (D, 2)) =
           "<math xmlns=""http://www.w3.org/1998/Math/MathML"">"
           & "<mi>x</mi></math>",
         "qualified MathML payload remains opaque");
      Assert (Block_Kind_Of (D, Block_At (D, 3)) = Paragraph,
              "paragraph after MathML remains typed");

      declare
         Split_Parser : Instance;
         Split_Result : aliased Log := (others => <>);
         Split_D      : Document;
      begin
         Active_Log := Split_Result'Unchecked_Access;
         Feed (Split_Parser, "<unknown>bad<code><p>lit", Collect'Access);
         Feed (Split_Parser, "eral</p></code><p>later</p>",
               Collect'Access);
         Snapshot (Split_Parser, Split_D);
         Assert (Split_Result.Invalid = 1 and then
                 Block_Kind_Of (Split_D, Block_At (Split_D, 1)) =
                   Invalid_Source and then
                 Block_Kind_Of (Split_D, Block_At (Split_D, 2)) = Code_Block
                 and then Code_Literal (Split_D, Block_At (Split_D, 2)) =
                   "<p>literal</p>" and then
                 Block_Kind_Of (Split_D, Block_At (Split_D, 3)) = Paragraph,
                 "split code recovery preserves typed opaque and later roots");
         Reset (Split_Parser);
         Split_Result := (others => <>);
         Feed (Split_Parser,
               "<unknown>bad<math xmlns="""
               & "http://www.w3.org/1998/Math/MathML"">"
               & "<mi>x</mi></ma", Collect'Access);
         Feed (Split_Parser, "th><p>later</p>", Collect'Access);
         Snapshot (Split_Parser, Split_D);
         Active_Log := null;
         Assert (Split_Result.Invalid = 1 and then
                 Block_Kind_Of (Split_D, Block_At (Split_D, 1)) =
                   Invalid_Source and then
                 Block_Kind_Of (Split_D, Block_At (Split_D, 2)) =
                   Display_Math and then
                 Block_Kind_Of (Split_D, Block_At (Split_D, 3)) = Paragraph,
                 "split MathML recovery preserves typed opaque and later"
                 & " roots");
      end;
   end Test_Unknown_Recovery_Before_Opaque_Roots;

   procedure Test_Incomplete_Flush_Is_Exact (T : in out Test) is
      pragma Unreferenced (T);
      Parser : Instance;
      Result : aliased Log := (others => <>);
      D      : Document;
   begin
      Active_Log := Result'Unchecked_Access;
      Feed (Parser, "<h1>valid</h1><p>tail", Collect'Access);
      Snapshot (Parser, D);
      Assert (Block_Count (D) = 2,
              "valid prefix and incomplete root are retained provisionally");
      Assert (Block_Kind_Of (D, Block_At (D, 1)) = Heading,
              "valid prefix remains typed before Flush");
      Flush (Parser, Collect'Access);
      Snapshot (Parser, D);
      Active_Log := null;
      Assert (Result.Invalid = 1, "flush emits exactly one invalid suffix");
      Assert
        (Ada.Strings.Fixed.Index (To_String (Result.Text), "<p>tail") > 0,
         "flush preserves exact incomplete source");
      Assert (Block_Count (D) = 2,
              "Flush retains the valid prefix and invalid suffix roots");
      Assert (Block_Kind_Of (D, Block_At (D, 1)) = Heading,
              "Flush does not invalidate the valid prefix root");
      Assert (Block_Kind_Of (D, Block_At (D, 2)) = Invalid_Source,
              "Flush quarantines only the incomplete root");
      Assert (Block_Source (D, Block_At (D, 2)) = "<p>tail",
              "Flush invalid source is exactly the incomplete suffix");
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

   procedure Test_Localized_Root_Recovery (T : in out Test) is
      pragma Unreferenced (T);
      D      : Document;
      Result : Log;
      Source : constant String :=
        "<p>before</p><p><strong>broken</p></strong>"
        & "<h2>after</h2>";
      Split_Parser : Instance;
      Split_Result : aliased Log := (others => <>);
      Split_D      : Document;
   begin
      Parse (Source, D, Result);
      Assert (Result.Invalid = 1, "one invalid ordinary root is reported");
      Assert (Block_Count (D) = 3, "roots before, invalid, and after remain");
      Assert (Block_Kind_Of (D, Block_At (D, 1)) = Paragraph,
              "valid prefix root remains typed");
      Assert (Block_Kind_Of (D, Block_At (D, 2)) = Invalid_Source,
              "crossing root is quarantined as one block");
      Assert (Block_Kind_Of (D, Block_At (D, 3)) = Heading,
              "parser resumes at later safe root boundary");
      Assert (Block_Source (D, Block_At (D, 2)) =
                "<p><strong>broken</p></strong>",
              "invalid ordinary root preserves exact source");
      Active_Log := Split_Result'Unchecked_Access;
      for I in Source'Range loop
         Feed (Split_Parser, Source (I .. I), Collect'Access);
      end loop;
      Snapshot (Split_Parser, Split_D);
      Active_Log := null;
      Assert (Split_Result.Invalid = Result.Invalid,
              "split recovery reports the same invalid count");
      Assert (Block_Count (Split_D) = Block_Count (D),
              "split recovery preserves root count");
      for Position in 1 .. Block_Count (D) loop
         Assert (Block_Kind_Of (Split_D, Block_At (Split_D, Position)) =
                   Block_Kind_Of (D, Block_At (D, Position)),
                 "split recovery preserves root kind");
         Assert (Block_Source (Split_D, Block_At (Split_D, Position)) =
                   Block_Source (D, Block_At (D, Position)),
                 "split recovery preserves exact root source");
      end loop;
   end Test_Localized_Root_Recovery;

   procedure Test_Localized_Inline_Salvage (T : in out Test) is
      pragma Unreferenced (T);
      D      : Document;
      Result : Log;
      Para   : Block_Id;
   begin
      Parse ("<p>prefix <strong>typed</strong><link bad>broken</link>tail</p>"
             & "<h2>later</h2>", D, Result);
      Assert (Result.Invalid = 1, "malformed inline is reported once");
      Assert (Block_Count (D) = 2, "later root survives inline salvage");
      Para := Block_At (D, 1);
      Assert (Block_Kind_Of (D, Para) = Paragraph,
              "ordinary root remains typed after inline corruption");
      Assert (Inline_Kind_Of (D, Block_Inline_At (D, Para, 1)) = Text,
              "valid text prefix remains typed");
      Assert (Inline_Kind_Of (D, Block_Inline_At (D, Para, 2)) = Strong,
              "valid styled prefix remains typed");
      Assert (Inline_Kind_Of (D, Block_Inline_At (D, Para, 3)) = Raw_Markup,
              "only corrupted suffix becomes raw markup");
      Assert (Inline_Source (D, Block_Inline_At (D, Para, 3)) =
                "<link bad>broken</link>tail",
              "raw inline source is exact through root close boundary");
      Assert (Block_Kind_Of (D, Block_At (D, 2)) = Heading,
              "valid later heading remains typed");
   end Test_Localized_Inline_Salvage;

   procedure Test_Localized_Entity_Salvage (T : in out Test) is
      pragma Unreferenced (T);
      D      : Document;
      Result : Log;
      Para   : Block_Id;
   begin
      Parse ("<p>good <strong>bold</strong> bad &bogus; after</p>"
             & "<p>later</p>", D, Result);
      Para := Block_At (D, 1);
      Assert (Result.Invalid = 1, "invalid entity is reported once");
      Assert (Inline_Kind_Of (D, Block_Inline_At (D, Para, 2)) = Strong,
              "styled prefix survives invalid entity");
      Assert (Inline_Kind_Of (D, Block_Inline_At (D, Para, 4)) = Raw_Markup,
              "invalid entity suffix is raw");
      Assert (Inline_Value (D, Block_Inline_At (D, Para, 3)) = " bad ",
              "valid text before invalid entity remains typed");
      Assert (Inline_Value (D, Block_Inline_At (D, Para, 4)) =
                "&bogus; after",
              "invalid entity source is retained exactly");
      Assert (Block_Kind_Of (D, Block_At (D, 2)) = Paragraph,
              "later paragraph survives invalid entity");
   end Test_Localized_Entity_Salvage;

   procedure Test_Localized_Entity_Flush (T : in out Test) is
      pragma Unreferenced (T);
      Parser : Instance;
      D      : Document;
      Result : aliased Log := (others => <>);
   begin
      Active_Log := Result'Unchecked_Access;
      Feed (Parser, "<p>prefix &broken", Collect'Access);
      Snapshot (Parser, D);
      Assert (Block_Kind_Of (D, Block_At (D, 1)) = Paragraph,
              "incomplete entity is provisionally paragraph typed");
      Flush (Parser, Collect'Access);
      Snapshot (Parser, D);
      Active_Log := null;
      Assert (Result.Invalid = 1, "incomplete entity is reported on Flush");
      Assert (Block_Kind_Of (D, Block_At (D, 1)) = Paragraph,
              "incomplete entity keeps paragraph typed count="
              & Natural'Image (Block_Count (D))
              & " kind=" & Block_Kind'Image
                (Block_Kind_Of (D, Block_At (D, 1)))
              & " source=" & Block_Source (D, Block_At (D, 1))
              & " inlines=" & Natural'Image
                (Block_Inline_Count (D, Block_At (D, 1))));
      Assert (Inline_Kind_Of (D, Block_Inline_At (D, Block_At (D, 1), 2)) =
                Raw_Markup,
              "incomplete entity is raw after Flush");
      Assert (Inline_Value (D, Block_Inline_At (D, Block_At (D, 1), 2)) =
                "&broken",
              "Flush retains incomplete entity source");
   end Test_Localized_Entity_Flush;

   procedure Test_Localized_Tag_Flush (T : in out Test) is
      pragma Unreferenced (T);
      Parser : Instance;
      D      : Document;
      Result : aliased Log := (others => <>);
   begin
      Active_Log := Result'Unchecked_Access;
      Feed (Parser, "<p>prefix <unk", Collect'Access);
      Feed (Parser, "nown>x</unknown>", Collect'Access);
      Flush (Parser, Collect'Access);
      Snapshot (Parser, D);
      Active_Log := null;
      Assert (Result.Invalid = 1, "split malformed inline tag is reported once");
      Assert (Block_Kind_Of (D, Block_At (D, 1)) = Paragraph,
              "split malformed inline tag keeps paragraph typed");
      Assert (Inline_Kind_Of (D, Block_Inline_At (D, Block_At (D, 1), 2)) =
                Raw_Markup,
              "split malformed inline tag is raw");
      Assert (Inline_Value (D, Block_Inline_At (D, Block_At (D, 1), 2)) =
                "<unknown>x</unknown>",
              "split malformed inline tag retains exact source");
   end Test_Localized_Tag_Flush;

   procedure Test_Localized_Split_Invariance (T : in out Test) is
      pragma Unreferenced (T);
      Source : constant String :=
        "<p>good <strong>x</strong> bad &bogus; tail</p><h3>later</h3>";
      Whole  : Instance;
      Split  : Instance;
      A      : aliased Log := (others => <>);
      B      : aliased Log := (others => <>);
      D1     : Document;
      D2     : Document;
   begin
      Active_Log := A'Unchecked_Access;
      Feed (Whole, Source, Collect'Access);
      Snapshot (Whole, D1);
      Active_Log := B'Unchecked_Access;
      for Boundary in Source'Range loop
         Reset (Split);
         B := (others => <>);
         Feed (Split, Source (Source'First .. Boundary), Collect'Access);
         if Boundary < Source'Last then
            Feed (Split, Source (Boundary + 1 .. Source'Last), Collect'Access);
         end if;
         Snapshot (Split, D2);
         Assert (Snapshot_Text (D1) = Snapshot_Text (D2),
                 "inline salvage is invariant at byte boundary "
                 & Natural'Image (Boundary)
                 & " whole=" & Snapshot_Text (D1)
                 & " split=" & Snapshot_Text (D2));
         Assert (A.Invalid = B.Invalid,
                 "inline salvage invalid count is invariant at byte boundary "
                 & Natural'Image (Boundary));
      end loop;
      Active_Log := null;
   end Test_Localized_Split_Invariance;

   procedure Test_Crossing_Inline_Remains_Atomic (T : in out Test) is
      pragma Unreferenced (T);
      D      : Document;
      Result : Log;
   begin
      Parse ("<p>prefix <strong>cross</p></strong><p>later</p>", D, Result);
      Assert (Result.Invalid = 1, "crossing inline is reported once");
      Assert (Block_Kind_Of (D, Block_At (D, 1)) = Invalid_Source,
              "crossing inline remains root-atomic");
      Assert (Block_Kind_Of (D, Block_At (D, 2)) = Paragraph,
              "later root survives crossing recovery");
   end Test_Crossing_Inline_Remains_Atomic;

   procedure Test_Opaque_Root_Recovery (T : in out Test) is
      pragma Unreferenced (T);
      D      : Document;
      Result : Log;
   begin
      Parse ("<p>before</p><code><bad><p>x</p></code><p>after</p>", D,
             Result);
      Assert (Result.Invalid = 0,
              "opaque code payload remains atomic invalid="
              & Natural'Image (Result.Invalid)
              & " blocks=" & Natural'Image (Block_Count (D)));
      Assert (Block_Count (D) = 3, "opaque code preserves surrounding roots");
      Assert (Block_Kind_Of (D, Block_At (D, 1)) = Paragraph,
              "prefix paragraph remains typed around code");
      Assert (Block_Kind_Of (D, Block_At (D, 2)) = Code_Block,
              "opaque code payload remains a typed code root");
      Assert (Block_Kind_Of (D, Block_At (D, 3)) = Paragraph,
              "post-code paragraph is parsed normally");
      Parse ("<p>before</p><math xmlns=""http://www.w3.org/1998/Math/MathML"">"
             & "<math><mi>x</mi></math></math><p>after</p>", D, Result);
      Assert (Result.Invalid = 1, "malformed MathML is reported once");
      Assert (Block_Count (D) = 3, "MathML remains atomic during recovery");
      Assert (Block_Kind_Of (D, Block_At (D, 2)) = Invalid_Source,
              "MathML root is one invalid source block");
      Assert (Block_Kind_Of (D, Block_At (D, 3)) = Paragraph,
              "parser resumes only after MathML close");
   end Test_Opaque_Root_Recovery;

   procedure Test_Multiple_Malformed_Roots (T : in out Test) is
      pragma Unreferenced (T);
      D      : Document;
      Result : Log;
   begin
      Parse ("<p>a</p><p><em>x</p></em><table><p>bad</p></table>"
             & "<h3>z</h3>", D, Result);
      Assert (Result.Invalid = 2, "multiple malformed roots report separately");
      Assert (Block_Count (D) = 4, "valid roots survive multiple regions");
      Assert (Block_Kind_Of (D, Block_At (D, 1)) = Paragraph,
              "first valid root is retained");
      Assert (Block_Kind_Of (D, Block_At (D, 2)) = Invalid_Source,
              "first malformed root is isolated");
      Assert (Block_Kind_Of (D, Block_At (D, 3)) = Invalid_Source,
              "second malformed root is isolated");
      Assert (Block_Kind_Of (D, Block_At (D, 4)) = Heading,
              "later valid root survives multiple regions");
   end Test_Multiple_Malformed_Roots;

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
        (Block_Inline_Count (D, Block_At (D, 1)) = 1,
         "UTF-8 split coalesces into one semantic text inline");
      Assert
        (Inline_Source (D, Block_Inline_At (D, Block_At (D, 1), 1))
         = "caf" & Character'Val (16#C3#) & Character'Val (16#A9#),
         "UTF-8 source bytes are not lost at delta boundary");
      Assert
        (Inline_Value (D, Block_Inline_At (D, Block_At (D, 1), 1))
         = "caf" & Character'Val (16#C3#) & Character'Val (16#A9#),
         "UTF-8 decoded value is exact at delta boundary");
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
      Assert (Result.Invalid = 1,
              "only the non-whitespace top-level region is invalid");
      Assert (Block_Count (D) = 3,
              "invalid source, rule, and paragraph are ordered roots");
      Assert
        (Block_Kind_Of (D, Block_At (D, 1)) = Invalid_Source,
         "top-level text is an Invalid_Source root");
      Assert (Block_Source (D, Block_At (D, 1)) = "text",
              "top-level invalid source is exact");
      Assert
        (Block_Kind_Of (D, Block_At (D, 2)) = Horizontal_Rule,
         "horizontal rule is a semantic block");
      Assert
        (Block_Kind_Of (D, Block_At (D, 3)) = Paragraph,
         "paragraph remains the third root block");
      Assert (Block_Inline_Count (D, Block_At (D, 3)) = 3,
              "paragraph retains text, hard break, and text order");
      Assert
        (Inline_Kind_Of
           (D, Block_Inline_At (D, Block_At (D, 3), 2)) = Hard_Line_Break,
         "br is a typed hard-break inline");
      Assert (Result.Events > 0, "legacy events remain synchronous");
   end Test_Empty_Elements_And_Event_Compatibility;






   procedure Test_Semantic_Protocol (T : in out Test) is
      pragma Unreferenced (T);
      Parser : Instance;
      Copy_Parser : Instance;
      Split_Parser : Instance;
      D1 : Document;
      D2 : Document;
      Source : constant String :=
        "<p>left <strong>bold</strong></p>"
        & "<table><row><cell>x</cell></row></table>"
        & "<math xmlns=""http://www.w3.org/1998/Math/MathML""><mi>x</mi></math>"
        & "<h2>right</h2>";
      type Semantic_Log is record
         Count : Natural := 0;
         Last_Sequence : Natural := 0;
         Finish_Count : Natural := 0;
         Begin_Count : Natural := 0;
         Commit_Count : Natural := 0;
         Text_Count : Natural := 0;
         Table_Change_Count : Natural := 0;
         Math_Change_Count : Natural := 0;
         Table_Commit_Count : Natural := 0;
         Math_Commit_Count : Natural := 0;
         Invalid_Count : Natural := 0;
         Bad_Sequence : Boolean := False;
         Bad_Range : Boolean := False;
         Invalid_Text : Unbounded_String;
         Invalid_Start : Natural := 0;
         Invalid_End : Natural := 0;
      end record;
      Log : aliased Semantic_Log;
      Active : access Semantic_Log := Log'Access;
      procedure Collect_Semantic (Value : Semantic_Event) is
      begin
         if Active = null then
            return;
         end if;
         Active.Count := Active.Count + 1;
         if Value.Sequence <= Active.Last_Sequence then
            Active.Bad_Sequence := True;
         end if;
         Active.Last_Sequence := Value.Sequence;
         if Value.Source_Start /= 0
           and then Value.Source_End < Value.Source_Start
         then
            Active.Bad_Range := True;
         end if;
         case Value.Kind is
            when Semantic_Root_Begin_Event =>
               Active.Begin_Count := Active.Begin_Count + 1;
            when Semantic_Root_Commit_Event =>
               Active.Commit_Count := Active.Commit_Count + 1;
               if Value.Block_Kind = Table then
                  Active.Table_Commit_Count := Active.Table_Commit_Count + 1;
               elsif Value.Block_Kind = Display_Math then
                  Active.Math_Commit_Count := Active.Math_Commit_Count + 1;
               end if;
            when Semantic_Text_Change_Event =>
               Active.Text_Count := Active.Text_Count + 1;
            when Semantic_Root_Change_Event =>
               if Value.Block_Kind = Table then
                  Active.Table_Change_Count :=
                    Active.Table_Change_Count + 1;
               elsif Value.Block_Kind = Display_Math then
                  Active.Math_Change_Count :=
                    Active.Math_Change_Count + 1;
               end if;
            when Semantic_Root_Replace_Invalid_Event |
                 Semantic_Localized_Recovery_Event =>
               Active.Invalid_Count := Active.Invalid_Count + 1;
               Active.Invalid_Text := Value.Text;
               Active.Invalid_Start := Value.Source_Start;
               Active.Invalid_End := Value.Source_End;
            when Semantic_Document_Finish_Event =>
               Active.Finish_Count := Active.Finish_Count + 1;
            when Semantic_Inline_Change_Event =>
               null;
         end case;
      end Collect_Semantic;
      procedure Raise_Callback (Value : Semantic_Event) is
         pragma Unreferenced (Value);
      begin
         raise Program_Error;
      end Raise_Callback;
      First_Root : Natural;
      Last_Root : Natural;
   begin
      Feed (Parser, Source, Semantic_Handler'(Collect_Semantic'Unrestricted_Access));
      Snapshot (Parser, D1);
      Assert (Log.Count > 0, "semantic protocol emits mutations");
      Assert (not Log.Bad_Sequence, "semantic sequence is deterministic");
      Assert (not Log.Bad_Range, "semantic ranges are ordered");
      Assert (Log.Begin_Count >= 4, "all top-level roots begin semantically");
      Assert (Log.Commit_Count >= 4, "completed roots commit semantically");
      Assert (Log.Table_Change_Count > 0,
              "table reports provisional semantic changes");
      Assert (Log.Table_Commit_Count = 1,
              "table commits atomically at its grammar boundary");
      Assert (Log.Math_Commit_Count = 1,
              "math commits atomically at its grammar boundary");
      First_Root := Block_Semantic_Root_Id (D1, Block_At (D1, 1));
      Last_Root := Block_Semantic_Root_Id
        (D1, Block_At (D1, Block_Count (D1)));
      Assert (First_Root /= 0 and then Last_Root > First_Root,
              "top-level root IDs are ordered and stable");
      Snapshot (Parser, D2);
      Assert (Block_Semantic_Root_Id (D2, Block_At (D2, 1)) = First_Root,
              "root ID survives Snapshot/Copy");
      Feed (Split_Parser, "<p>left</p><h2>right</h2>",
           Semantic_Handler'(Collect_Semantic'Unrestricted_Access));
      Snapshot (Split_Parser, D2);
      Assert (Block_Semantic_Root_Id (D2, Block_At (D2, 1)) = 1
                and then Block_Semantic_Root_Id (D2, Block_At (D2, 2)) = 2,
              "root IDs remain stable across a complete delta");
      Reset (Copy_Parser);
      Feed (Copy_Parser, "<p>delta</p>",
           Semantic_Handler'(Collect_Semantic'Unrestricted_Access));
      Snapshot (Copy_Parser, D2);
      Assert (Block_Semantic_Root_Id (D2, Block_At (D2, 1)) = 1,
              "root identity restarts deterministically after Reset");
      Log := (others => <>);
      Active := Log'Access;
      Feed (Parser, "<p>a", Semantic_Handler'(Collect_Semantic'Unrestricted_Access));
      Assert (Log.Text_Count > 0, "incremental text change is reported");
      Flush (Parser, Semantic_Handler'(Collect_Semantic'Unrestricted_Access));
      Flush (Parser, Semantic_Handler'(Collect_Semantic'Unrestricted_Access));
      Active := null;
      Assert (Log.Finish_Count = 1, "document finish is emitted once");
      Assert (Log.Invalid_Count = 1, "incomplete root is replaced once");
      Reset (Parser);
      Log := (others => <>);
      Active := Log'Access;
      Feed (Parser, "<p>before <link bad>x</link> after</p>"
                    & "<h2>after</h2>",
           Semantic_Handler'(Collect_Semantic'Unrestricted_Access));
      Active := null;
      Assert (Log.Invalid_Count = 1,
              "localized invalid replacement is one event");
      Assert (To_String (Log.Invalid_Text) = "<link bad>x</link> after",
              "invalid replacement text is exact");
      Assert (Log.Invalid_Start > 0 and then
                Log.Invalid_End - Log.Invalid_Start + 1 =
                  To_String (Log.Invalid_Text)'Length,
              "invalid replacement range is exact");
      Snapshot (Parser, D2);
      Assert (Block_Count (D2) = 2,
              "localized recovery preserves neighboring roots");
      Assert (Block_Semantic_Root_Id (D2, Block_At (D2, 1)) /= 0,
              "localized recovery keeps preceding root identity");
      Assert (Block_Semantic_Root_Id (D2, Block_At (D2, 2)) >
                Block_Semantic_Root_Id (D2, Block_At (D2, 1)),
              "localized recovery keeps following root identity");
      begin
         Feed (Parser, "<p>callback",
              Semantic_Handler'(Raise_Callback'Unrestricted_Access));
      exception
         when Program_Error =>
            null;
      end;
      Feed (Parser, " text", Semantic_Handler'(null));
      Assert (True, "semantic callback clears after exception");
   end Test_Semantic_Protocol;

   type Semantic_Record is record
      Kind : Semantic_Event_Kind := Semantic_Document_Finish_Event;
      Block : Coyote_Renderer.Semantics.Block_Kind := Invalid_Source;
      Root : Natural := 0;
      First : Natural := 0;
      Last : Natural := 0;
      Text : Unbounded_String;
   end record;

   type Semantic_Record_Array is array (Positive range 1 .. 4096)
     of Semantic_Record;

   type Semantic_Log is record
      Records : Semantic_Record_Array;
      Record_Count : Natural := 0;
      Count : Natural := 0;
      Last_Sequence : Natural := 0;
      Bad_Sequence : Boolean := False;
      Bad_Range : Boolean := False;
      Begin_Count : Natural := 0;
      Commit_Count : Natural := 0;
      Finish_Count : Natural := 0;
      Invalid_Count : Natural := 0;
      Last_Invalid : Unbounded_String;
   end record;

   procedure Collect_Semantic (Value : Semantic_Event; Log : in out Semantic_Log) is
      Text : constant String := To_String (Value.Text);
   begin
      Log.Count := Log.Count + 1;
      if Value.Sequence <= Log.Last_Sequence then
         Log.Bad_Sequence := True;
      end if;
      Log.Last_Sequence := Value.Sequence;
      if Value.Kind /= Semantic_Document_Finish_Event
        and then (Value.Source_Start = 0
                  or else Value.Source_End < Value.Source_Start)
      then
         Log.Bad_Range := True;
      end if;
      if Value.Kind = Semantic_Root_Replace_Invalid_Event
        and then Log.Record_Count > 0
        and then Log.Records (Log.Record_Count).Kind =
          Semantic_Root_Begin_Event
        and then Log.Records (Log.Record_Count).Root = Value.Root_Id
      then
         Log.Records (Log.Record_Count).First := Value.Source_Start;
         Log.Records (Log.Record_Count).Last := Value.Source_End;
         Log.Records (Log.Record_Count).Text := Value.Text;
      end if;
      if Value.Provisional
        and then Value.Kind in Semantic_Text_Change_Event
          | Semantic_Inline_Change_Event | Semantic_Root_Change_Event
        and then Log.Record_Count > 0
        and then Log.Records (Log.Record_Count).Kind = Value.Kind
        and then Log.Records (Log.Record_Count).Root = Value.Root_Id
        and then Log.Records (Log.Record_Count).Last + 1 = Value.Source_Start
      then
         Log.Records (Log.Record_Count).Last := Value.Source_End;
         Log.Records (Log.Record_Count).Text :=
           Log.Records (Log.Record_Count).Text & Value.Text;
      else
         if not (Value.Provisional
           and then Value.Kind = Semantic_Root_Change_Event
           and then Value.Block_Kind in Code_Block | Display_Math)
         then
            Log.Record_Count := Log.Record_Count + 1;
            Log.Records (Log.Record_Count) :=
              (Kind => Value.Kind, Block => Value.Block_Kind,
               Root => Value.Root_Id, First => Value.Source_Start,
               Last => Value.Source_End, Text => Value.Text);
         end if;
      end if;
      case Value.Kind is
         when Semantic_Root_Begin_Event =>
            Log.Begin_Count := Log.Begin_Count + 1;
         when Semantic_Root_Commit_Event =>
            Log.Commit_Count := Log.Commit_Count + 1;
         when Semantic_Root_Replace_Invalid_Event |
              Semantic_Localized_Recovery_Event =>
            Log.Invalid_Count := Log.Invalid_Count + 1;
            Log.Last_Invalid := Value.Text;
         when Semantic_Document_Finish_Event =>
            Log.Finish_Count := Log.Finish_Count + 1;
         when Semantic_Text_Change_Event | Semantic_Inline_Change_Event |
              Semantic_Root_Change_Event =>
            null;
      end case;
   end Collect_Semantic;

   Active_Semantic_Log : access Semantic_Log;

   procedure Collect_Semantic_Active (Value : Semantic_Event) is
   begin
      if Active_Semantic_Log /= null then
         Collect_Semantic (Value, Active_Semantic_Log.all);
      end if;
   end Collect_Semantic_Active;

   function Normalize_Journal (Log : Semantic_Log) return String is
      Result : Unbounded_String;
   begin
      for Position in 1 .. Log.Record_Count loop
         Append (Result,
           Semantic_Event_Kind'Image (Log.Records (Position).Kind) & ":"
           & Natural'Image (Log.Records (Position).Root) & ":"
           & Natural'Image (Log.Records (Position).First) & "-"
           & Natural'Image (Log.Records (Position).Last) & ":"
           & To_String (Log.Records (Position).Text) & "|");
      end loop;
      return To_String (Result);
   end Normalize_Journal;

   function Semantic_Journal
     (Source : String; Split : Boolean; Flush_Source : Boolean := False)
      return String is
      Parser : Instance;
      Log : aliased Semantic_Log;
      Snapshot_Document : Document;
   begin
      Active_Semantic_Log := Log'Unrestricted_Access;
      if Split then
         for Position in Source'Range loop
            Feed (Parser, Source (Position .. Position),
               Semantic_Handler'(Collect_Semantic_Active'Access));
         end loop;
      else
         Feed (Parser, Source,
            Semantic_Handler'(Collect_Semantic_Active'Access));
      end if;
      if Flush_Source then
         Flush (Parser, Semantic_Handler'(Collect_Semantic_Active'Access));
      end if;
      Active_Semantic_Log := null;
      Snapshot (Parser, Snapshot_Document);
      return Normalize_Journal (Log) & "#" & Snapshot_Text (Snapshot_Document);
   end Semantic_Journal;

   procedure Test_Semantic_Root_Identity (T : in out Test) is
      pragma Unreferenced (T);
      Parser : Instance;
      D : Document;
      Root : Block_Id;
      Child : Block_Id;
      Nested_Table : Block_Id;
   begin
      Feed (Parser, "<blockquote><p>x</p><table><row><cell>y</cell></row></table>"
            & "</blockquote><hr/><p>z</p>",
         Semantic_Handler'(null));
      Snapshot (Parser, D);
      Assert (Block_Count (D) = 3, "all top-level roots are retained");
      Root := Block_At (D, 1);
      Child := Block_Child_At (D, Root, 1);
      Nested_Table := Block_Child_At (D, Root, 2);
      Assert (Block_Semantic_Root_Id (D, Root) = 1,
              "first root ID is nonzero");
      Assert (Block_Semantic_Root_Id (D, Child) = 1,
              "nested paragraph resolves to top-level root ID");
      Assert (Block_Semantic_Root_Id (D, Nested_Table) = 1,
              "nested table resolves to top-level root ID");
      Assert (Block_Semantic_Root_Id (D, Block_At (D, 2)) >
                Block_Semantic_Root_Id (D, Root),
              "horizontal rule receives monotonic root ID");
      Assert (Block_Semantic_Root_Id (D, Block_At (D, 3)) >
                Block_Semantic_Root_Id (D, Block_At (D, 2)),
              "following paragraph receives monotonic root ID");
   end Test_Semantic_Root_Identity;

   procedure Test_Semantic_Ranges_And_Lifecycle (T : in out Test) is
      pragma Unreferenced (T);
      Source : constant String := "<p>a<strong>b</strong></p><h2>c</h2>";
      Parser : Instance;
      Log : aliased Semantic_Log;
      Begin_Seen : Boolean := False;
      Commit_Seen : Boolean := False;
      procedure Check (Value : Semantic_Event) is
      begin
         Collect_Semantic (Value, Log);
         if Value.Kind = Semantic_Root_Begin_Event then
            Begin_Seen := True;
         elsif Value.Kind = Semantic_Root_Commit_Event then
            Commit_Seen := True;
         end if;
         if Value.Kind in Semantic_Text_Change_Event
           | Semantic_Inline_Change_Event | Semantic_Root_Change_Event
           | Semantic_Root_Commit_Event
         then
            Assert (Begin_Seen, "root begin precedes root mutations");
         end if;
         if Value.Kind = Semantic_Root_Commit_Event then
            Assert (Value.Root_Id /= 0, "commit root ID is nonzero");
         end if;
      end Check;
   begin
      Feed (Parser, Source, Semantic_Handler'(Check'Unrestricted_Access));
      Assert (not Log.Bad_Range, "semantic ranges are inclusive and ordered");
      Assert (Begin_Seen and then Commit_Seen,
              "complete root has begin and commit");
      Assert (Log.Record_Count > 0,
              "semantic lifecycle journal is nonempty");
   end Test_Semantic_Ranges_And_Lifecycle;

   procedure Test_Semantic_Split_Journal (T : in out Test) is
      pragma Unreferenced (T);
      Sources : constant array (Positive range 1 .. 6) of Unbounded_String :=
        (To_Unbounded_String ("<p><strong>nested</strong> text</p>"),
         To_Unbounded_String ("<table><row><cell>x</cell></row></table>"),
         To_Unbounded_String ("<math xmlns=""http://www.w3.org/1998/Math/MathML""><mi>x</mi></math>"),
         To_Unbounded_String ("<p>bad &broken</p><p>after</p>"),
         To_Unbounded_String ("bad<blockquote>x</blockquote>"),
         To_Unbounded_String ("<p>incomplete"));
   begin
      for Position in Sources'Range loop
         declare
            Whole : constant String :=
              Semantic_Journal (To_String (Sources (Position)), False,
                                Position = Sources'Last);
            Split : constant String :=
              Semantic_Journal (To_String (Sources (Position)), True,
                                Position = Sources'Last);
         begin
            Assert (Whole = Split,
              "normalized semantic journals agree for case"
              & Positive'Image (Position) & " whole=" & Whole
              & " split=" & Split);
         end;
      end loop;
   end Test_Semantic_Split_Journal;

   procedure Test_Semantic_Flush_And_Callback_Recovery (T : in out Test) is
      pragma Unreferenced (T);
      Parser : Instance;
      D : Document;
      Raised : Boolean := False;
      procedure Raise_Callback (Value : Semantic_Event) is
         pragma Unreferenced (Value);
      begin
         Raised := True;
         raise Program_Error;
      end Raise_Callback;
   begin
      Feed (Parser, "<p>before", Semantic_Handler'(null));
      begin
         Feed (Parser, " <strong>callback</strong>",
            Semantic_Handler'(Raise_Callback'Unrestricted_Access));
      exception
         when Program_Error =>
            null;
      end;
      Assert (Raised, "semantic callback was invoked");
      Feed (Parser, " <strong>callback</strong> after</p>",
         Semantic_Handler'(null));
      Snapshot (Parser, D);
      Assert (Block_Count (D) = 1, "callback recovery avoids duplicate roots");
      Assert (Block_Source (D, Block_At (D, 1)) =
                "<p>before <strong>callback</strong> after</p>",
              "callback recovery preserves canonical source after retry");
      Flush (Parser, Semantic_Handler'(null));
      Feed (Parser, "<p>ignored</p>", Semantic_Handler'(null));
      Snapshot (Parser, D);
      Assert (Block_Count (D) = 1,
              "feed after document finish is ignored until reset");
   end Test_Semantic_Flush_And_Callback_Recovery;

   procedure Test_Semantic_Text_Coalescing_Boundaries (T : in out Test) is
      pragma Unreferenced (T);
      Parser : Instance;
      D : Document;
      Source : constant String :=
        "<p>a&amp;" & Character'Val (16#C3#) & Character'Val (16#A9#)
        & "<strong>b" & Character'Val (16#C3#) & Character'Val (16#B1#)
        & "</strong>c<br/>d<unknown>x</unknown>e</p>"
        & "<table><row><cell>f&amp;g</cell></row></table>"
        & "<h2>h</h2>";
      Para : Block_Id;
      Strong : Inline_Id;
      First_Text : Inline_Id;
      Last_Text : Inline_Id;
      Table : Block_Id;
      Cell : Table_Cell_Id;
   begin
      Feed (Parser, Source, Semantic_Handler'(null));
      Snapshot (Parser, D);
      Assert (Block_Count (D) = 3,
              "coalescing boundary corpus retains three roots");
      Para := Block_At (D, 1);
      Assert (Block_Inline_Count (D, Para) = 6,
              "style, break, and recovery boundaries are preserved");
      First_Text := Block_Inline_At (D, Para, 1);
      Assert (Inline_Kind_Of (D, First_Text) = Text,
              "plain prefix is a Text inline");
      Assert (Inline_Value (D, First_Text) = "a&" &
                Character'Val (16#C3#) & Character'Val (16#A9#),
              "entities and split UTF-8 decode into one exact value");
      Assert (Inline_Source (D, First_Text) =
                "a&amp;" & Character'Val (16#C3#) & Character'Val (16#A9#),
              "coalesced Text retains exact combined source");
      Strong := Block_Inline_At (D, Para, 2);
      Assert (Inline_Kind_Of (D, Strong) = Coyote_Renderer.Semantics.Strong,
              "style boundary starts a Strong inline");
      Assert (Inline_Child_Count (D, Strong) = 1,
              "styled text remains nested rather than merged");
      Assert (Inline_Value (D, Inline_Child_At (D, Strong, 1)) = "b" &
                Character'Val (16#C3#) & Character'Val (16#B1#),
              "styled UTF-8 text remains exact");
      Assert (Inline_Kind_Of (D, Block_Inline_At (D, Para, 3)) = Text
                and then Inline_Value
                  (D, Block_Inline_At (D, Para, 3)) = "c",
              "plain text before hard break remains separate");
      Assert (Inline_Kind_Of (D, Block_Inline_At (D, Para, 4)) =
                Hard_Line_Break,
              "hard break prevents adjacent text coalescing");
      Assert (Inline_Kind_Of (D, Block_Inline_At (D, Para, 5)) = Text
                and then Inline_Value
                  (D, Block_Inline_At (D, Para, 5)) = "d",
              "text after hard break is a new inline");
      Last_Text := Block_Inline_At (D, Para, 6);
      Assert (Inline_Kind_Of (D, Last_Text) = Raw_Markup
                and then Inline_Source (D, Last_Text) =
                  "<unknown>x</unknown>e",
              "raw recovery prevents text coalescing");
      Table := Block_At (D, 2);
      Cell := Table_Cell_At (D, Table_Row_At (D, Table, 1), 1);
      Assert (Table_Cell_Inline_Count (D, Cell) = 1,
              "cell text coalesces only within the cell parent");
      Assert (Table_Cell_Value (D, Cell) = "f&g",
              "cell entity value is decoded exactly");
      Assert (Block_Semantic_Root_Id (D, Para) /=
                Block_Semantic_Root_Id (D, Table),
              "root boundaries keep distinct root IDs");
   end Test_Semantic_Text_Coalescing_Boundaries;

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
        ("CSM-2 table structural whitespace",
         Test_Table_Structural_Whitespace'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 table incomplete and malformed recovery",
         Test_Table_Incomplete_And_Malformed_Recovery'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 opaque code and MathML",
         Test_Math_And_Code_Are_Opaque'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 whitespace robustness", Test_Whitespace_Robustness'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 redundant MathML wrapper",
         Test_Redundant_Math_Wrapper'Access));
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
        ("CSM-2 unknown recovery before opaque roots",
         Test_Unknown_Recovery_Before_Opaque_Roots'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 exact incomplete flush",
         Test_Incomplete_Flush_Is_Exact'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 delta boundary invariance",
         Test_Delta_Boundary_Invariance'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 localized root recovery",
         Test_Localized_Root_Recovery'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 localized inline salvage",
         Test_Localized_Inline_Salvage'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 localized entity salvage",
         Test_Localized_Entity_Salvage'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 localized entity Flush",
         Test_Localized_Entity_Flush'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 localized tag Flush",
         Test_Localized_Tag_Flush'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 localized split invariance",
         Test_Localized_Split_Invariance'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 crossing inline remains atomic",
         Test_Crossing_Inline_Remains_Atomic'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 opaque root recovery",
         Test_Opaque_Root_Recovery'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 multiple malformed roots",
         Test_Multiple_Malformed_Roots'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 UTF-8 split safety", Test_UTF8_Splits'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 parser limits", Test_Nesting_And_Tag_Limits'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 empty tags and compatibility events",
         Test_Empty_Elements_And_Event_Compatibility'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 semantic mutation protocol",
         Test_Semantic_Protocol'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 semantic root identity",
         Test_Semantic_Root_Identity'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 semantic ranges and lifecycle",
         Test_Semantic_Ranges_And_Lifecycle'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 semantic split journal",
         Test_Semantic_Split_Journal'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 semantic Flush and callback recovery",
         Test_Semantic_Flush_And_Callback_Recovery'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 semantic text coalescing boundaries",
         Test_Semantic_Text_Coalescing_Boundaries'Access));
      return Result;
   end Suite;

end Coyote_Incremental_Tests;
