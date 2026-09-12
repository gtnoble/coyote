--  Coyote_Semantics_Tests body.
--
--  Project: coyote

with Ada.Strings.Fixed;
with AUnit.Assertions;
with AUnit.Test_Caller;
with Coyote_Renderer.Markup;
with Coyote_Renderer.Semantics;

package body Coyote_Semantics_Tests is
   use AUnit.Assertions;
   use Coyote_Renderer.Semantics;

   procedure Test_Construction_And_Order (T : in out Test) is
      pragma Unreferenced (T);
      D       : Document;
      Heading_Block : constant Block_Id :=
        New_Block (D, Coyote_Renderer.Semantics.Heading, "# title");
      Para    : constant Block_Id :=
        New_Block (D, Paragraph, "plain source");
      Rule    : constant Block_Id :=
        New_Block (D, Horizontal_Rule, "---");
   begin
      Assert (Append_Block (D, Heading_Block), "heading appended to root");
      Assert (Append_Block (D, Para), "paragraph appended to root");
      Assert (Append_Block (D, Rule), "rule appended to root");
      Assert (Block_Count (D) = 3, "root block count preserves construction");
      Assert (Block_At (D, 1) = Heading_Block, "first root block is heading");
      Assert (Block_At (D, 2) = Para, "second root block is paragraph");
      Assert (Block_At (D, 3) = Rule, "third root block is rule");
      Assert
        (Block_Kind_Of (D, Block_At (D, 1)) =
           Coyote_Renderer.Semantics.Heading,
         "heading kind is retained");
      Assert (Block_Source (D, Para) = "plain source",
              "block source is retained");
   end Test_Construction_And_Order;

   procedure Test_Nested_Blocks_And_Inlines (T : in out Test) is
      pragma Unreferenced (T);
      D         : Document;
      Quote     : constant Block_Id := New_Block (D, Blockquote, "> quoted");
      Para      : constant Block_Id := New_Block (D, Paragraph, "quoted");
      Strong_Inline : constant Inline_Id :=
        New_Inline
          (D, Coyote_Renderer.Semantics.Strong,
           "important", "**important**");
      Link_Inline : constant Inline_Id :=
        New_Inline
          (D, Coyote_Renderer.Semantics.Link,
           "label", "[label](https://example.test)");
      Text_Inline      : constant Inline_Id :=
        New_Inline (D, Coyote_Renderer.Semantics.Text, "tail");
   begin
      Assert (Append_Block (D, Quote), "quote appended");
      Assert (Append_Block (D, Quote, Para), "paragraph nested in quote");
      Assert
        (Append_Inline (D, Para, Strong_Inline),
         "strong inline appended");
      Assert (Append_Inline (D, Para, Link_Inline), "link inline appended");
      Assert
        (Append_Inline (D, Link_Inline, Text_Inline),
         "link label child appended");
      Assert (Block_Child_Count (D, Quote) = 1, "quote has one child block");
      Assert (Block_Child_At (D, Quote, 1) = Para,
              "nested block ordering is preserved");
      Assert (Block_Inline_Count (D, Para) = 2,
              "inline ordering is preserved");
      Assert
        (Inline_Kind_Of (D, Block_Inline_At (D, Para, 1)) =
           Coyote_Renderer.Semantics.Strong,
         "strong kind is retained");
      Assert
        (Inline_Child_Count (D, Link_Inline) = 1,
         "link has label children");
      Assert (Inline_Value (D, Inline_Child_At (D, Link_Inline, 1)) = "tail",
              "inline child value is inspectable");
   end Test_Nested_Blocks_And_Inlines;

   procedure Test_Attributes_And_Source (T : in out Test) is
      pragma Unreferenced (T);
      D       : Document;
      Head    : constant Block_Id :=
        New_Block (D, Coyote_Renderer.Semantics.Heading, "# decoded");
      List_Block : constant Block_Id :=
        New_Block (D, Coyote_Renderer.Semantics.List, "3. item");
      Code    : constant Block_Id :=
        New_Block (D, Coyote_Renderer.Semantics.Code_Block, "```ada");
      Math    : constant Block_Id :=
        New_Block (D, Coyote_Renderer.Semantics.Display_Math, "$$x$$");
      Link    : constant Inline_Id := New_Inline
        (D, Coyote_Renderer.Semantics.Link, "label", "[raw label](url)");
   begin
      Assert (Set_Heading_Level (D, Head, 3), "heading level set");
      Assert (Set_List_Attributes (D, List_Block, Ordered_List, 3),
              "list attributes set");
      Assert (Set_Code_Block_Data (D, Code, "x := 1;", "ada"),
              "code data set");
      Assert (Set_Display_Math_Data (D, Math, "<math><mi>x</mi></math>"),
              "math data set");
      Assert (Set_Link_URL (D, Link, "https://example.test"),
              "link URL set");
      Assert (Heading_Level_Of (D, Head) = 3, "heading level is inspectable");
      Assert
        (List_Kind_Of (D, List_Block) = Ordered_List,
         "ordered list retained");
      Assert (List_Start (D, List_Block) = 3, "list start retained");
      Assert (Code_Literal (D, Code) = "x := 1;", "code literal retained");
      Assert (Code_Language (D, Code) = "ada", "code language retained");
      Assert (MathML_Source (D, Math) = "$$x$$",
              "math source is separate from value");
      Assert (MathML_Value (D, Math) = "<math><mi>x</mi></math>",
              "math value is retained");
      Assert (Inline_Source (D, Link) = "[raw label](url)",
              "inline source is retained");
      Assert (Inline_URL (D, Link) = "https://example.test",
              "link URL is inspectable");
   end Test_Attributes_And_Source;

   procedure Test_Table_Model (T : in out Test) is
      pragma Unreferenced (T);
      D      : Document;
      Table  : constant Block_Id :=
        New_Block
          (D,
           Coyote_Renderer.Semantics.Table,
           "| raw |" & ASCII.LF & "| --- |" & ASCII.LF & "| x |");
      Row    : constant Table_Row_Id := New_Table_Row (D, Table, True);
      Cell   : constant Table_Cell_Id :=
        New_Table_Cell (D, Row, "decoded", "raw");
      Cell_Inline : constant Inline_Id :=
        New_Inline
          (D, Coyote_Renderer.Semantics.Text, "cell text", "cell");
   begin
      Assert (Append_Block (D, Table), "table appended");
      Assert (Set_Table_Alignment (D, Table, 1, Center),
              "table alignment set");
      Assert (Set_Table_Alignment (D, Table, 2, Right),
              "second alignment set");
      Assert (Append_Inline (D, Cell, Cell_Inline), "cell inline appended");
      Assert (Table_Row_Count (D, Table) = 1, "table row count retained");
      Assert (Table_Row_Is_Header (D, Table_Row_At (D, Table, 1)),
              "header row state retained");
      Assert (Table_Cell_Count (D, Row) = 1, "cell count retained");
      Assert (Table_Cell_Source (D, Cell) = "raw", "cell source retained");
      Assert (Table_Cell_Value (D, Cell) = "decoded", "cell value retained");
      Assert (Table_Cell_Inline_Count (D, Cell) = 1,
              "cell inline count retained");
      Assert (Table_Alignment_At (D, Table, 1) = Center,
              "first alignment retained");
      Assert (Table_Alignment_At (D, Table, 2) = Right,
              "second alignment retained");
   end Test_Table_Model;

   procedure Test_Clear_Invalidates_Handles (T : in out Test) is
      pragma Unreferenced (T);
      D       : Document;
      Old     : constant Block_Id := New_Block (D, Paragraph, "old");
      Old_Inline : constant Inline_Id :=
        New_Inline (D, Coyote_Renderer.Semantics.Text, "old");
   begin
      Assert (Append_Block (D, Old), "old block appended");
      Assert (Is_Valid (D, Old), "new block handle is valid");
      Assert (Is_Valid (D, Old_Inline), "new inline handle is valid");
      Clear (D);
      Assert (Block_Count (D) = 0, "clear removes root blocks");
      Assert (not Is_Valid (D, Old), "clear invalidates block handle");
      Assert (not Is_Valid (D, Old_Inline), "clear invalidates inline handle");
      Assert
        (Block_Source (D, Old) = "",
         "invalid block is safely inspectable");
      Assert (Append_Block (D, Old) = False,
              "stale block cannot be reattached");
   end Test_Clear_Invalidates_Handles;

   procedure Test_Markdown_Adapter_Constructs_Model (T : in out Test) is
      pragma Unreferenced (T);
      D : Document;
      Input : constant String :=
        "# Head" & ASCII.LF & ASCII.LF
        & "1. **bold** [link](https://example.test)" & ASCII.LF
        & ASCII.LF & "| A | B |" & ASCII.LF
        & "| --- | --- |" & ASCII.LF
        & "| x | `y` |" & ASCII.LF;
      Heading : Block_Id;
      List : Block_Id;
      Item : Block_Id;
      Table : Block_Id;
      Link : Inline_Id;
      Row : Table_Row_Id;
      Cell : Table_Cell_Id;
   begin
      Assert (Coyote_Renderer.Markup.Parse_Markdown (Input, D),
              "Markdown adapter parses representative GFM");
      Assert (Block_Count (D) = 3, "adapter preserves root block order");
      Heading := Block_At (D, 1);
      List := Block_At (D, 2);
      Table := Block_At (D, 3);
      Assert (Block_Kind_Of (D, Heading) = Coyote_Renderer.Semantics.Heading,
              "adapter creates heading block");
      Assert (Heading_Level_Of (D, Heading) = 1,
              "adapter retains heading level");
      Assert (List_Kind_Of (D, List) = Ordered_List,
              "adapter retains ordered-list kind");
      Item := Block_Child_At (D, List, 1);
      Link := Block_Inline_At (D, Item, 3);
      Assert (Inline_URL (D, Link) = "https://example.test",
              "adapter retains link destination");
      Assert (Table_Row_Count (D, Table) = 2,
              "adapter creates header and body rows");
      Row := Table_Row_At (D, Table, 2);
      Cell := Table_Cell_At (D, Row, 2);
      Assert (Table_Cell_Value (D, Cell) = "y",
              "adapter decodes inline-code table value");
   end Test_Markdown_Adapter_Constructs_Model;

   procedure Test_Markdown_Adapter_Constructs_Display_Math
     (T : in out Test)
   is
      pragma Unreferenced (T);
      D : Document;
      Input : constant String :=
        "before" & ASCII.LF & ASCII.LF & "$$" & ASCII.LF
        & "<math><mi>x</mi></math>" & ASCII.LF & "$$" & ASCII.LF
        & ASCII.LF & "after";
      Math : Block_Id;
   begin
      Assert (Coyote_Renderer.Markup.Parse_Markdown (Input, D),
              "Markdown adapter accepts display math");
      Assert (Block_Count (D) = 3,
              "display math remains in source order");
      Math := Block_At (D, 2);
      Assert (Block_Kind_Of (D, Math) = Display_Math,
              "display math becomes a semantic block");
      Assert (Ada.Strings.Fixed.Index
                (MathML_Value (D, Math), "<math><mi>x</mi></math>") > 0,
              "display math stores inner MathML");
   end Test_Markdown_Adapter_Constructs_Display_Math;
   procedure Test_Semantic_Pango_Golden (T : in out Test) is
      pragma Unreferenced (T);
      Input : constant String :=
        "# Head" & ASCII.LF & ASCII.LF & "plain **bold** and `code`";
      Expected : constant String :=
        ASCII.LF & "<span weight=""bold"" size=""larger"">Head</span>"
        & ASCII.LF & ASCII.LF & "plain <b>bold</b> and <tt>code</tt>"
        & ASCII.LF & ASCII.LF;
   begin
      Assert (Coyote_Renderer.Markup.To_Pango_Markup (Input) = Expected,
              "semantic Pango serializer preserves golden output");
   end Test_Semantic_Pango_Golden;

   package Caller is new AUnit.Test_Caller (Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (Caller.Create
        ("Semantics construction and order",
         Test_Construction_And_Order'Access));
      Result.Add_Test (Caller.Create
        ("Semantics nested blocks and inlines",
         Test_Nested_Blocks_And_Inlines'Access));
      Result.Add_Test (Caller.Create
        ("Semantics attributes and source",
         Test_Attributes_And_Source'Access));
      Result.Add_Test (Caller.Create
        ("Semantics table model",
         Test_Table_Model'Access));
      Result.Add_Test (Caller.Create
        ("Semantics clear invalidates handles",
         Test_Clear_Invalidates_Handles'Access));
      Result.Add_Test (Caller.Create
        ("Markdown adapter constructs semantic model",
         Test_Markdown_Adapter_Constructs_Model'Access));
      Result.Add_Test (Caller.Create
        ("Markdown adapter constructs display math",
         Test_Markdown_Adapter_Constructs_Display_Math'Access));
      Result.Add_Test (Caller.Create
        ("Semantic Pango serializer golden output",
         Test_Semantic_Pango_Golden'Access));
      return Result;
   end Suite;

end Coyote_Semantics_Tests;
