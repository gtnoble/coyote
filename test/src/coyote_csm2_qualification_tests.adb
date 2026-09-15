--  Coyote_CSM2_Qualification_Tests body.
--
--  Project: coyote

with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with AUnit.Assertions;
with AUnit.Test_Caller;
with Coyote_Renderer.Incremental;
with Coyote_Renderer.Markup;
with Coyote_Renderer.Semantics;

use type Coyote_Renderer.Incremental.Event_Kind;
use type Coyote_Renderer.Semantics.Block_Kind;
use type Coyote_Renderer.Semantics.Inline_Kind;

package body Coyote_CSM2_Qualification_Tests is

   use AUnit.Assertions;
   package I renames Coyote_Renderer.Incremental;
   package S renames Coyote_Renderer.Semantics;

   type Event_Log is record
      Text         : Unbounded_String;
      Invalid_Text : Unbounded_String;
      Invalid      : Natural := 0;
   end record;

   Active_Log : access Event_Log;

   procedure Collect (Value : I.Event) is
   begin
      if Active_Log /= null then
         if Value.Kind = I.Invalid_Event then
            Append (Active_Log.Invalid_Text, To_String (Value.Text));
            Active_Log.Invalid := Active_Log.Invalid + 1;
         else
            Append (Active_Log.Text, To_String (Value.Text));
         end if;
      end if;
   end Collect;

   procedure Parse
     (Source : String; Target : out S.Document; Log : out Event_Log) is
      Parser : I.Instance;
      Local  : aliased Event_Log := (others => <>);
   begin
      Active_Log := Local'Unchecked_Access;
      I.Feed (Parser, Source, Collect'Access);
      I.Snapshot (Parser, Target);
      Log := Local;
      Active_Log := null;
   end Parse;

   procedure Append_Inline_Snapshot
     (D : S.Document; Id : S.Inline_Id; Out_Text : in out Unbounded_String) is
   begin
      if S.Inline_Kind_Of (D, Id) = S.Text
        or else S.Inline_Kind_Of (D, Id) = S.Raw_Markup
      then
         Append (Out_Text, S.Inline_Value (D, Id));
      else
         Append (Out_Text, "I:" & S.Inline_Kind'Image
                 (S.Inline_Kind_Of (D, Id)) & ":"
                 & S.Inline_URL (D, Id) & "{");
         if S.Inline_Child_Count (D, Id) > 0 then
            for Position in 1 .. S.Inline_Child_Count (D, Id) loop
               declare
                  Child : constant S.Inline_Id :=
                    S.Inline_Child_At (D, Id, Position);
               begin
                  if S.Inline_Kind_Of (D, Child) = S.Text
                    and then Position > 1
                    and then S.Inline_Kind_Of
                      (D, S.Inline_Child_At (D, Id, Position - 1)) = S.Text
                  then
                     Append (Out_Text, S.Inline_Value (D, Child));
                  else
                     Append_Inline_Snapshot (D, Child, Out_Text);
                  end if;
               end;
            end loop;
         end if;
         Append (Out_Text, "}");
      end if;
   end Append_Inline_Snapshot;

   procedure Append_Block_Snapshot
     (D : S.Document; Id : S.Block_Id; Out_Text : in out Unbounded_String) is
      Kind : constant S.Block_Kind := S.Block_Kind_Of (D, Id);
   begin
      Append (Out_Text, "B:" & S.Block_Kind'Image (Kind) & ":"
              & S.Block_Source (D, Id) & ":"
              & Natural'Image (S.Heading_Level_Of (D, Id)) & ":"
              & S.List_Kind'Image (S.List_Kind_Of (D, Id)) & ":"
              & Positive'Image (S.List_Start (D, Id)) & ":"
              & S.Code_Language (D, Id) & ":" & S.Code_Literal (D, Id)
              & ":" & S.MathML_Value (D, Id));
      if S.Block_Child_Count (D, Id) > 0 then
         for Position in 1 .. S.Block_Child_Count (D, Id) loop
            Append_Block_Snapshot
              (D, S.Block_Child_At (D, Id, Position), Out_Text);
         end loop;
      end if;
      if S.Block_Inline_Count (D, Id) > 0 then
         for Position in 1 .. S.Block_Inline_Count (D, Id) loop
            Append_Inline_Snapshot
              (D, S.Block_Inline_At (D, Id, Position), Out_Text);
         end loop;
      end if;
      if S.Table_Row_Count (D, Id) > 0 then
         Append
           (Out_Text,
            "W:" & Natural'Image (S.Table_Column_Count (D, Id)));
         for Column in 1 .. S.Table_Column_Count (D, Id) loop
            Append (Out_Text, ":" & S.Table_Alignment'Image
                    (S.Table_Alignment_At (D, Id, Column)));
         end loop;
         for Row_Position in 1 .. S.Table_Row_Count (D, Id) loop
            declare
               Row : constant S.Table_Row_Id :=
                 S.Table_Row_At (D, Id, Row_Position);
            begin
               Append (Out_Text, "R:" & Boolean'Image
                       (S.Table_Row_Is_Header (D, Row)) & ":"
                       & S.Table_Row_Source (D, Row));
               for Cell_Position in 1 .. S.Table_Cell_Count (D, Row) loop
                  declare
                     Cell : constant S.Table_Cell_Id :=
                       S.Table_Cell_At (D, Row, Cell_Position);
                  begin
                     Append (Out_Text, "C:" & S.Table_Cell_Source (D, Cell)
                             & ":" & S.Table_Cell_Value (D, Cell));
                     for Inline_Position in
                       1 .. S.Table_Cell_Inline_Count (D, Cell) loop
                        Append_Inline_Snapshot
                          (D,
                           S.Table_Cell_Inline_At
                             (D, Cell, Inline_Position),
                           Out_Text);
                     end loop;
                  end;
               end loop;
            end;
         end loop;
      end if;
      Append (Out_Text, "|");
   end Append_Block_Snapshot;

   function Snapshot_Text (D : S.Document) return String is
      Result : Unbounded_String;
   begin
      if S.Block_Count (D) > 0 then
         for Position in 1 .. S.Block_Count (D) loop
            Append_Block_Snapshot
              (D, S.Block_At (D, Position), Result);
         end loop;
      end if;
      return To_String (Result);
   end Snapshot_Text;

   procedure Test_Grammar_And_Recovery_Matrix (T : in out Test) is
      pragma Unreferenced (T);
      Source : constant String :=
        "<p>a <strong>b</strong> <em>c</em> <del>d</del> "
        & "<link url=""https://e.test/a&amp;b"">e</link> "
        & "<code-inline>&lt;tag&gt;</code-inline><br/></p>"
        & "<h1>h</h1><h6>z</h6>"
        & "<blockquote><p>q</p></blockquote>"
        & "<list kind=""ordered"" start=""3""><item>one</item>"
        & "<item>two</item></list>"
        & "<code lang=""ada"">&lt;p&gt;<p>x</p>&amp;</code>"
        & "<hr/><table><row kind=""header""><cell align=""left"">A</cell>"
        & "<cell align=""center"">B</cell><cell align=""right"">C</cell>"
        & "</row><row kind=""body""><cell>1</cell><cell>2</cell>"
        & "<cell>3</cell></row></table>"
        & "<math xmlns=""http://www.w3.org/1998/Math/MathML"">"
        & "<mrow><mi>x</mi><mo>&lt;</mo><mn>1</mn></mrow></math>";
      D : S.Document;
      L : Event_Log;
      procedure Invalid (Text : String) is
         Bad_D : S.Document;
         Bad_L : Event_Log;
      begin
         Parse (Text, Bad_D, Bad_L);
         Assert (Bad_L.Invalid > 0, "invalid CSM is rejected: " & Text);
         Assert (S.Block_Count (Bad_D) > 0,
                 "invalid CSM has a visible semantic source block: " & Text);
         Assert (S.Block_Kind_Of
                   (Bad_D, S.Block_At (Bad_D, S.Block_Count (Bad_D))) =
                   S.Invalid_Source,
                 "invalid CSM fallback is typed: " & Text);
      end Invalid;
   begin
      Parse (Source, D, L);
      Assert (L.Invalid = 0, "complete approved grammar matrix is valid");
      Assert (S.Block_Count (D) = 9, "all block forms retain root order");
      Assert (S.Table_Row_Count (D, S.Block_At (D, 8)) = 2,
              "explicit table has two rows");
      Assert (S.Table_Column_Count (D, S.Block_At (D, 8)) = 3,
              "explicit table retains width");
      Assert (S.MathML_Value (D, S.Block_At (D, 9))'Length > 0,
              "terminal Presentation MathML is retained");
      declare
         Found_Link : Boolean := False;
      begin
         for Position in 1 .. S.Block_Inline_Count (D, S.Block_At (D, 1)) loop
            if S.Inline_URL
              (D, S.Block_Inline_At (D, S.Block_At (D, 1), Position)) =
              "https://e.test/a&b"
            then
               Found_Link := True;
            end if;
         end loop;
         Assert (Found_Link, "entities decode in legal link attributes");
      end;
      declare
         Found_Code : Boolean := False;
      begin
         for Position in 1 .. S.Block_Count (D) loop
            if S.Block_Kind_Of (D, S.Block_At (D, Position)) = S.Code_Block
              and then S.Code_Literal (D, S.Block_At (D, Position)) =
                "&lt;p&gt;<p>x</p>&amp;"
            then
               Found_Code := True;
            end if;
         end loop;
         Assert (Found_Code, "code payload is opaque and source-literal");
      end;
      Invalid ("<P>x</P>");
      Invalid ("<p a=""x"">x</p>");
      Invalid ("<p><strong>x</p></strong>");
      declare
         Local_D : S.Document;
         Local_L : Event_Log;
      begin
         Parse ("<p><strong>ok</strong><unknown>x</unknown>tail</p>"
                & "<h2>after</h2>", Local_D, Local_L);
         Assert (Local_L.Invalid = 1,
                 "unknown inline reports localized invalid source");
         Assert (S.Block_Kind_Of (Local_D, S.Block_At (Local_D, 1)) = S.Paragraph,
                 "unknown inline keeps ordinary root typed");
         Assert (S.Inline_Kind_Of
                   (Local_D, S.Block_Inline_At (Local_D, S.Block_At (Local_D, 1), 1)) =
                   S.Strong,
                 "valid styled prefix survives unknown inline");
         Assert (S.Inline_Kind_Of
                   (Local_D, S.Block_Inline_At (Local_D, S.Block_At (Local_D, 1), 2)) =
                   S.Raw_Markup,
                 "unknown inline suffix is raw");
         Assert (S.Block_Kind_Of (Local_D, S.Block_At (Local_D, 2)) = S.Heading,
                 "later root remains typed after unknown inline");
      end;
      Invalid ("<table><row><cell>a</cell></row><row><cell>b</cell>"
               & "<cell>c</cell></row></table>");
      Invalid ("<table><row kind=""header""><cell>x</cell></row>"
               & "<row kind=""header""><cell>y</cell></row></table>");
      Invalid ("<table><row><cell align=""bad"">x</cell></row></table>");
      Invalid ("<math xmlns=""http://www.w3.org/1998/Math/MathML"">"
               & "<math><mi>x</mi></math></math>");
      Invalid ("<p><em>unclosed</p>");
   end Test_Grammar_And_Recovery_Matrix;

   procedure Test_All_Delta_Boundaries_Preserve_Semantics (T : in out Test) is
      pragma Unreferenced (T);
      Source : constant String :=
        "<h2>Title</h2><p>a <strong>b</strong> c</p>"
        & "<list kind=""unordered""><item>x</item><item>y</item></list>"
        & "<table><row kind=""header""><cell align=""center"">A</cell>"
        & "<cell>B</cell></row><row><cell>1</cell>"
        & "<cell>2</cell></row></table>";
      Whole_Parser : I.Instance;
      Whole_D      : S.Document;
      Whole_L      : aliased Event_Log := (others => <>);
      Whole_Text   : Unbounded_String;
   begin
      Active_Log := Whole_L'Unchecked_Access;
      I.Feed (Whole_Parser, Source, Collect'Access);
      I.Snapshot (Whole_Parser, Whole_D);
      Whole_Text := To_Unbounded_String (Snapshot_Text (Whole_D));
      Active_Log := null;
      for Boundary in Source'First .. Source'Last loop
         declare
            Split_Parser : I.Instance;
            Split_D      : S.Document;
            Split_L      : aliased Event_Log := (others => <>);
         begin
            Active_Log := Split_L'Unchecked_Access;
            I.Feed (Split_Parser, Source (Source'First .. Boundary),
                    Collect'Access);
            if Boundary < Source'Last then
               I.Feed (Split_Parser, Source (Boundary + 1 .. Source'Last),
                       Collect'Access);
            end if;
            I.Snapshot (Split_Parser, Split_D);
            Assert (Split_L.Invalid = Whole_L.Invalid,
                    "byte boundary preserves validity at "
                    & Natural'Image (Boundary));
            Assert (Snapshot_Text (Split_D) = To_String (Whole_Text),
                    "byte boundary preserves typed semantic snapshot at "
                    & Natural'Image (Boundary)
                    & " split=" & Snapshot_Text (Split_D)
                    & " whole=" & To_String (Whole_Text));
         end;
      end loop;
      Active_Log := null;
   end Test_All_Delta_Boundaries_Preserve_Semantics;

   procedure Test_UTF8_Boundaries_Preserve_Semantics (T : in out Test) is
      pragma Unreferenced (T);
      Source : constant String := "<p>caf" & Character'Val (16#C3#)
        & Character'Val (16#A9#) & " " & Character'Val (16#E2#)
        & Character'Val (16#98#) & Character'Val (16#83#) & "</p>";
      Whole : S.Document;
      Whole_L : Event_Log;
      Expected : Unbounded_String;
   begin
      Parse (Source, Whole, Whole_L);
      Expected := To_Unbounded_String (Snapshot_Text (Whole));
      for Boundary in Source'First .. Source'Last loop
         declare
            Parser : I.Instance;
            D      : S.Document;
            L      : aliased Event_Log := (others => <>);
         begin
            Active_Log := L'Unchecked_Access;
            I.Feed (Parser, Source (Source'First .. Boundary), Collect'Access);
            if Boundary < Source'Last then
               I.Feed (Parser, Source (Boundary + 1 .. Source'Last),
                       Collect'Access);
            end if;
            I.Snapshot (Parser, D);
            Assert (L.Invalid = Whole_L.Invalid,
                    "UTF-8 byte split validity is stable");
            Assert (Snapshot_Text (D) = To_String (Expected),
                    "UTF-8 byte split semantic snapshot is stable");
         end;
      end loop;
      Active_Log := null;
   end Test_UTF8_Boundaries_Preserve_Semantics;

   procedure Test_Exact_End_Of_Stream_Flush (T : in out Test) is
      pragma Unreferenced (T);
      Parser : I.Instance;
      D      : S.Document;
      L      : aliased Event_Log := (others => <>);
      Before : constant String := "prefix";
      Suffix : constant String := "<p>tail";
      Before_Invalid : Natural;
   begin
      Active_Log := L'Unchecked_Access;
      I.Feed (Parser, Before & Suffix, Collect'Access);
      Before_Invalid := L.Invalid;
      I.Flush (Parser, Collect'Access);
      I.Snapshot (Parser, D);
      Assert (L.Invalid = Before_Invalid + 1,
              "Flush emits exactly one incomplete-source event");
      Assert (To_String (L.Invalid_Text) = Before & Suffix,
              "invalid Event stream preserves exact ordered source: got="
              & To_String (L.Invalid_Text));
      Assert
        (S.Block_Kind_Of (D, S.Block_At (D, S.Block_Count (D))) =
                S.Invalid_Source,
              "Flush exposes incomplete source semantically");
      I.Flush (Parser, Collect'Access);
      Assert (L.Invalid = Before_Invalid + 1,
              "repeated Flush is an exact no-op");
      Active_Log := null;
   end Test_Exact_End_Of_Stream_Flush;

   procedure Test_Top_Level_Regions_Are_Invalid (T : in out Test) is
      pragma Unreferenced (T);
      Source : constant String := "text<hr/><p>x</p>tail";
      D      : S.Document;
      L      : Event_Log;
   begin
      Parse (Source, D, L);
      Assert (L.Invalid > 0,
              "non-whitespace top-level regions emit invalid events");
      Assert (S.Block_Count (D) = 4,
              "top-level invalid regions remain ordered with legal roots");
      Assert
        (S.Block_Kind_Of (D, S.Block_At (D, 1)) = S.Invalid_Source,
         "leading top-level region is Invalid_Source");
      Assert
        (S.Block_Kind_Of (D, S.Block_At (D, 2)) = S.Horizontal_Rule,
         "legal horizontal rule remains a typed semantic block");
      Assert
        (S.Block_Kind_Of (D, S.Block_At (D, 3)) = S.Paragraph,
         "legal paragraph remains a typed semantic block");
      Assert
        (S.Block_Kind_Of (D, S.Block_At (D, 4)) = S.Invalid_Source,
         "trailing top-level region is Invalid_Source");
      Assert (S.Block_Source (D, S.Block_At (D, 1)) = "text",
              "leading invalid source bytes are retained");
      Assert (S.Block_Source (D, S.Block_At (D, 4)) = "tail",
              "trailing invalid source bytes are retained");
   end Test_Top_Level_Regions_Are_Invalid;

   procedure Test_Markdown_Semantics_Pango_Reference (T : in out Test) is
      pragma Unreferenced (T);
      Markdown : constant String :=
        "# Head" & ASCII.LF & ASCII.LF
        & "plain **bold** *em* ~~gone~~ [link](https://e.test)" & ASCII.LF
        & ASCII.LF & "- outer" & ASCII.LF & "  - inner" & ASCII.LF
        & ASCII.LF & "> quote" & ASCII.LF & ASCII.LF
        & "```ada" & ASCII.LF & "$$ <math>x</math> $$" & ASCII.LF
        & "```" & ASCII.LF & ASCII.LF & "---" & ASCII.LF & ASCII.LF
        & "| A | B |" & ASCII.LF & "| :--- | ---: |" & ASCII.LF
        & "| x | y |" & ASCII.LF & ASCII.LF
        & "before" & ASCII.LF & ASCII.LF & "$$" & ASCII.LF
        & "<math><mi>x</mi></math>" & ASCII.LF & "$$";
      D : S.Document;
      Pango : constant String := Coyote_Renderer.Markup.To_Pango_Markup
        (Markdown);
   begin
      Assert (Coyote_Renderer.Markup.Parse_Markdown (Markdown, D),
              "representative Markdown parses into semantics");
      Assert (S.Block_Count (D) >= 8,
              "reference semantics preserve representative block order");
      Assert
        (S.Block_Kind_Of (D, S.Block_At (D, 1)) = S.Heading,
         "reference starts with heading");
      Assert
        (S.Block_Kind_Of (D, S.Block_At (D, 2)) = S.Paragraph,
         "reference preserves styled paragraph");
      Assert
        (S.Block_Kind_Of (D, S.Block_At (D, 3)) = S.List,
         "reference preserves nested list");
      Assert
        (S.Block_Kind_Of (D, S.Block_At (D, 4)) = S.Blockquote,
         "reference preserves quote");
      Assert
        (S.Block_Kind_Of (D, S.Block_At (D, 5)) = S.Code_Block,
         "reference protects opaque code");
      Assert
        (S.Block_Kind_Of (D, S.Block_At (D, 6)) = S.Horizontal_Rule,
         "reference preserves rule");
      Assert (Pango'Length > 0, "reference Pango output is non-empty");
      Assert (Ada.Strings.Fixed.Index (Pango, "<span weight=""bold""") > 0,
              "heading/style Pango is serialized");
      Assert (Ada.Strings.Fixed.Index (Pango, "<b>bold</b>") > 0,
              "strong Pango is serialized");
      Assert (Ada.Strings.Fixed.Index (Pango, "<tt>") > 0,
              "code/table Pango is serialized");
      Assert
        (Ada.Strings.Fixed.Index (Pango, "$$") > 0,
         "math masking leaves code/display source available to reference");
      Assert (Ada.Strings.Fixed.Index (Pango, "<p>") = 0,
              "Pango output contains no CSM tags");
   end Test_Markdown_Semantics_Pango_Reference;

   package Caller is new AUnit.Test_Caller (Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (Caller.Create
        ("CSM-2 qualification grammar and recovery matrix",
         Test_Grammar_And_Recovery_Matrix'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 qualification all byte boundaries",
         Test_All_Delta_Boundaries_Preserve_Semantics'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 qualification UTF-8 boundaries",
         Test_UTF8_Boundaries_Preserve_Semantics'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 qualification exact end-of-stream Flush",
         Test_Exact_End_Of_Stream_Flush'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 qualification top-level regions are Invalid_Source",
         Test_Top_Level_Regions_Are_Invalid'Access));
      Result.Add_Test (Caller.Create
        ("Markdown semantic/Pango qualification reference",
         Test_Markdown_Semantics_Pango_Reference'Access));
      return Result;
   end Suite;

end Coyote_CSM2_Qualification_Tests;
