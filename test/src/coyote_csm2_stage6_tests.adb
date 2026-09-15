--  Coyote_CSM2_Stage6_Tests body.
--
--  Project: coyote

with Ada.Real_Time;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with AUnit.Assertions;
with AUnit.Test_Caller;
with Coyote_Renderer.Incremental;
with Coyote_Renderer.Semantics;

package body Coyote_CSM2_Stage6_Tests is

   use AUnit.Assertions;
   package I renames Coyote_Renderer.Incremental;
   package S renames Coyote_Renderer.Semantics;
   package R renames Ada.Real_Time;

   use type I.Semantic_Event_Kind;
   use type S.Block_Kind;
   use type R.Time;
   use type R.Time_Span;

   type Journal_Item is record
      Kind : I.Semantic_Event_Kind := I.Semantic_Document_Finish_Event;
      Root : Natural := 0;
      First : Natural := 0;
      Last : Natural := 0;
      Block : S.Block_Kind := S.Invalid_Source;
      Provisional : Boolean := False;
      Text : Unbounded_String;
   end record;

   type Journal_Items is array (Positive range 1 .. 4096) of Journal_Item;

   type Journal is record
      Items : Journal_Items;
      Length : Natural := 0;
      Sequence : Natural := 0;
      Bad_Sequence : Boolean := False;
   end record;

   Active_Journal : access Journal;

   procedure Collect (Value : I.Semantic_Event) is
   begin
      if Active_Journal /= null then
         if Value.Sequence <= Active_Journal.Sequence then
            Active_Journal.Bad_Sequence := True;
         end if;
         Active_Journal.Sequence := Value.Sequence;
         if Value.Kind /= I.Semantic_Document_Finish_Event then
            if Active_Journal.Length > 0
              and then Value.Provisional
              and then Active_Journal.Items (Active_Journal.Length).Provisional
              and then Active_Journal.Items (Active_Journal.Length).Kind =
                Value.Kind
              and then Active_Journal.Items (Active_Journal.Length).Root =
                Value.Root_Id
              and then Active_Journal.Items (Active_Journal.Length).Last + 1 =
                Value.Source_Start
            then
               Active_Journal.Items (Active_Journal.Length).Last :=
                 Value.Source_End;
               Active_Journal.Items (Active_Journal.Length).Text :=
                 Active_Journal.Items (Active_Journal.Length).Text
                 & Value.Text;
            else
               Active_Journal.Length := Active_Journal.Length + 1;
               if Active_Journal.Length <= Active_Journal.Items'Last then
                  Active_Journal.Items (Active_Journal.Length) :=
                    (Kind => Value.Kind, Root => Value.Root_Id,
                     First => Value.Source_Start, Last => Value.Source_End,
                     Block => Value.Block_Kind,
                     Provisional => Value.Provisional,
                     Text => Value.Text);
               end if;
            end if;
         end if;
      end if;
   end Collect;

   procedure Append_Inline
     (D : S.Document; Id : S.Inline_Id; Result : in out Unbounded_String) is
   begin
      Append (Result, "I:" & S.Inline_Kind'Image
              (S.Inline_Kind_Of (D, Id)) & ":"
              & S.Inline_Source (D, Id) & ":"
              & S.Inline_Value (D, Id) & ":"
              & S.Inline_URL (D, Id) & "{");
      for Position in 1 .. S.Inline_Child_Count (D, Id) loop
         Append_Inline (D, S.Inline_Child_At (D, Id, Position), Result);
      end loop;
      Append (Result, "}");
   end Append_Inline;

   procedure Append_Block
     (D : S.Document; Id : S.Block_Id; Result : in out Unbounded_String) is
   begin
      Append (Result, "B:" & S.Block_Kind'Image
              (S.Block_Kind_Of (D, Id)) & ":"
              & Natural'Image (S.Block_Semantic_Root_Id (D, Id)) & ":"
              & S.Block_Source (D, Id) & ":"
              & Natural'Image (S.Heading_Level_Of (D, Id)) & ":"
              & S.Code_Language (D, Id) & ":"
              & S.Code_Literal (D, Id) & ":"
              & S.MathML_Value (D, Id) & "[");
      for Position in 1 .. S.Block_Child_Count (D, Id) loop
         Append_Block (D, S.Block_Child_At (D, Id, Position), Result);
      end loop;
      for Position in 1 .. S.Block_Inline_Count (D, Id) loop
         Append_Inline (D, S.Block_Inline_At (D, Id, Position), Result);
      end loop;
      for Position in 1 .. S.Table_Row_Count (D, Id) loop
         declare
            Row : constant S.Table_Row_Id := S.Table_Row_At (D, Id, Position);
         begin
            Append (Result, "R:" & S.Table_Row_Source (D, Row) & "{");
            for Cell_Position in 1 .. S.Table_Cell_Count (D, Row) loop
               declare
                  Cell : constant S.Table_Cell_Id :=
                    S.Table_Cell_At (D, Row, Cell_Position);
               begin
                  Append (Result, "C:" & S.Table_Cell_Source (D, Cell)
                          & ":" & S.Table_Cell_Value (D, Cell));
               end;
            end loop;
            Append (Result, "}");
         end;
      end loop;
      Append (Result, "]|");
   end Append_Block;

   function Snapshot_Text (D : S.Document) return String is
      Result : Unbounded_String;
   begin
      for Position in 1 .. S.Block_Count (D) loop
         Append_Block (D, S.Block_At (D, Position), Result);
      end loop;
      return To_String (Result);
   end Snapshot_Text;

   function Journal_Text (Value : Journal) return String is
      Result : Unbounded_String;
   begin
      for Position in 1 .. Value.Length loop
         declare
            Item : Journal_Item := Value.Items (Position);
         begin
            if Item.Provisional
              and then Position < Value.Length
              and then Value.Items (Position + 1).Provisional
              and then Value.Items (Position + 1).Kind = Item.Kind
              and then Value.Items (Position + 1).Root = Item.Root
              and then Value.Items (Position + 1).First = Item.Last + 1
            then
               Item.Last := Value.Items (Position + 1).Last;
               Item.Text := Item.Text & Value.Items (Position + 1).Text;
            end if;
            if not (Item.Provisional
              and then Position > 1
              and then Value.Items (Position - 1).Provisional
              and then Value.Items (Position - 1).Kind = Item.Kind
              and then Value.Items (Position - 1).Root = Item.Root
              and then Value.Items (Position - 1).Last = Item.Last)
            then
               Append (Result, I.Semantic_Event_Kind'Image (Item.Kind)
                       & ":" & Natural'Image (Item.Root) & ":"
                       & Natural'Image (Item.First) & "-"
                       & Natural'Image (Item.Last) & ":"
                       & To_String (Item.Text) & "|");
            end if;
         end;
      end loop;
      return To_String (Result);
   end Journal_Text;

   function Run
     (Source : String; One_Byte : Boolean; Do_Flush : Boolean)
      return String is
      Parser : I.Instance;
      Document : S.Document;
      Value : aliased Journal;
   begin
      Active_Journal := Value'Unrestricted_Access;
      if One_Byte then
         for Position in Source'Range loop
            I.Feed (Parser, Source (Position .. Position), Collect'Access);
         end loop;
      else
         I.Feed (Parser, Source, Collect'Access);
      end if;
      if Do_Flush then
         I.Flush (Parser, Collect'Access);
      end if;
      Active_Journal := null;
      I.Snapshot (Parser, Document);
      return Journal_Text (Value) & "#" & Snapshot_Text (Document);
   end Run;

   function Whitespace_Only (Value : String) return Boolean is
   begin
      for Character_Value of Value loop
         if Character_Value /= ' '
           and then Character_Value /= ASCII.HT
           and then Character_Value /= ASCII.CR
           and then Character_Value /= ASCII.LF
         then
            return False;
         end if;
      end loop;
      return True;
   end Whitespace_Only;

   function Is_Legal (Kind : S.Block_Kind) return Boolean is
   begin
      return Kind /= S.Invalid_Source;
   end Is_Legal;

   procedure Assert_Source_Coverage
     (Source : String; Document : S.Document; Label : String) is
      Cursor : Natural := Source'First;
   begin
      for Position in 1 .. S.Block_Count (Document) loop
         declare
            Block : constant S.Block_Id := S.Block_At (Document, Position);
            Raw : constant String := S.Block_Source (Document, Block);
            Start : constant Natural :=
              Ada.Strings.Fixed.Index (Source, Raw, Cursor);
         begin
            Assert (Start > 0,
                    Label & ": root source is not conserved at"
                    & Natural'Image (Position));
            Assert (Whitespace_Only
                    (Source (Cursor .. Start - 1)),
                    Label & ": non-root bytes precede a root at"
                    & Natural'Image (Position));
            Assert (Is_Legal (S.Block_Kind_Of (Document, Block))
                    or else Raw'Length > 0,
                    Label & ": empty invalid root");
            Cursor := Start + Raw'Length;
         end;
      end loop;
      if Cursor <= Source'Last then
         Assert (Whitespace_Only (Source (Cursor .. Source'Last)),
                 Label & ": non-whitespace source escaped all roots");
      end if;
   end Assert_Source_Coverage;

   function Make_Source (Count : Positive) return String is
      Result : Unbounded_String;
   begin
      for Position in 1 .. Count loop
         Append (Result, "<p>token " & Natural'Image (Position)
                 & " <strong>é</strong></p>");
         if Position mod 5 = 0 then
            Append (Result, "<hr/>");
         end if;
      end loop;
      return To_String (Result);
   end Make_Source;

   function Next_Random (State : in out Natural) return Natural is
   begin
      State := (State * 1_103 + 37) mod 32_771;
      return State;
   end Next_Random;

   procedure Feed_Chunks
     (Parser : in out I.Instance; Source : String; Mode : Natural) is
      Position : Natural := Source'First;
      State : Natural := 17;
      Width : Natural;
   begin
      while Position <= Source'Last loop
         if Mode = 1 then
            Width := 1;
         elsif Mode = 2 then
            Width := 7;
         else
            Width := 1 + Next_Random (State) mod 13;
         end if;
         Width := Natural'Min (Width, Source'Last - Position + 1);
         I.Feed (Parser, Source (Position .. Position + Width - 1),
                 I.Semantic_Handler'(null));
         Position := Position + Width;
      end loop;
   end Feed_Chunks;

   procedure Test_Generated_Valid_Boundaries_And_Journals
     (T : in out Test) is
      pragma Unreferenced (T);
      Sources : constant array (Positive range 1 .. 4) of Unbounded_String :=
        (To_Unbounded_String
           ("<p>alpha <strong>" & Character'Val (16#CE#)
            & Character'Val (16#B2#) & "</strong> &amp; text</p>"
            & "<h2>heading</h2>"),
         To_Unbounded_String
           ("<blockquote><p>q</p><list kind=""unordered""><item>x</item>"
            & "<item>y</item></list></blockquote>"),
         To_Unbounded_String
           ("<table><row kind=""header""><cell>A</cell><cell>B</cell>"
            & "</row><row><cell>1</cell><cell>2</cell></row></table>"),
         To_Unbounded_String
           ("<code lang=""ada"">&lt;p&gt;opaque</code>"
            & "<math xmlns=""http://www.w3.org/1998/Math/MathML"">"
            & "<mi>" & Character'Val (16#CF#) & Character'Val (16#80#)
            & "</mi></math>"));
   begin
      for Case_Number in Sources'Range loop
         declare
            Source : constant String := To_String (Sources (Case_Number));
            Whole : constant String := Run (Source, False, True);
            Bytewise : constant String := Run (Source, True, True);
         begin
            Assert (Whole = Bytewise,
                    "generated valid corpus journal/snapshot differs for case"
                    & Positive'Image (Case_Number));
            for Boundary in Source'First .. Source'Last loop
               declare
                  Parser : I.Instance;
                  Document : S.Document;
                  Value : aliased Journal;
               begin
                  Active_Journal := Value'Unrestricted_Access;
                  I.Feed (Parser, Source (Source'First .. Boundary),
                          Collect'Access);
                  if Boundary < Source'Last then
                     I.Feed (Parser, Source (Boundary + 1 .. Source'Last),
                             Collect'Access);
                  end if;
                  I.Flush (Parser, Collect'Access);
                  I.Snapshot (Parser, Document);
                  Assert (Journal_Text (Value) & "#" & Snapshot_Text (Document)
                          = Whole,
                          "generated valid byte boundary differs at"
                          & Natural'Image (Boundary));
                  Active_Journal := null;
               end;
            end loop;
         end;
      end loop;
   end Test_Generated_Valid_Boundaries_And_Journals;

   procedure Test_Generated_Malformed_Source_Conservation
     (T : in out Test) is
      pragma Unreferenced (T);
      Sources : constant array (Positive range 1 .. 10) of Unbounded_String :=
        (To_Unbounded_String ("<P>x</P><p>after</p>"),
         To_Unbounded_String ("<p a=""bad"">x</p><p>after</p>"),
         To_Unbounded_String ("<p><strong>x</p></strong><h2>after</h2>"),
         To_Unbounded_String ("<p>&bad;</p><p>after</p>"),
         To_Unbounded_String ("<table><row><cell>x</row></table><p>after</p>"),
         To_Unbounded_String ("<table><row><cell>x</cell></row>"),
         To_Unbounded_String
           ("<code lang=""ada"">unterminated<p>x</p>"),
         To_Unbounded_String
           ("<math xmlns=""http://www.w3.org/1998/Math/MathML"">"
            & "<mi>x</math><p>after</p>"),
         To_Unbounded_String ("raw <p>valid</p> tail"),
         To_Unbounded_String
           ("<p>before</p><unknown>x</unknown><p>after</p>"));
   begin
      for Case_Number in Sources'Range loop
         declare
            Source : constant String := To_String (Sources (Case_Number));
            Document : S.Document;
            Value : aliased Journal;
         begin
            declare
               Parser : I.Instance;
            begin
               Active_Journal := Value'Unrestricted_Access;
               I.Feed (Parser, Source, Collect'Access);
               I.Flush (Parser, Collect'Access);
               I.Snapshot (Parser, Document);
               Active_Journal := null;
            end;
            Assert (not Value.Bad_Sequence,
                    "malformed corpus semantic sequence is ordered");
            Assert (S.Block_Count (Document) > 0,
                    "malformed corpus remains visible");
            Assert_Source_Coverage
              (Source, Document, "malformed corpus case"
               & Positive'Image (Case_Number));
         end;
      end loop;
   end Test_Generated_Malformed_Source_Conservation;

   procedure Test_Root_Identity_Chunkings_And_Finish
     (T : in out Test) is
      pragma Unreferenced (T);
      Source : constant String :=
        "<p>one</p><table><row><cell>x</cell></row></table>"
        & "<math xmlns=""http://www.w3.org/1998/Math/MathML"">"
        & "<mi>y</mi></math><p>three</p>";
      Expected : Unbounded_String;
      Root_Count : Natural := 0;
   begin
      for Mode in 1 .. 3 loop
         declare
            Parser : I.Instance;
            Document : S.Document;
         begin
            Feed_Chunks (Parser, Source, Mode);
            I.Flush (Parser, I.Semantic_Handler'(null));
            I.Snapshot (Parser, Document);
            if Mode = 1 then
               Expected := To_Unbounded_String (Snapshot_Text (Document));
               Root_Count := S.Block_Count (Document);
            else
               Assert (Snapshot_Text (Document) = To_String (Expected),
                       "chunking changes semantic roots or root IDs");
               Assert (S.Block_Count (Document) = Root_Count,
                       "chunking changes root count");
            end if;
            for Position in 1 .. S.Block_Count (Document) loop
               declare
                  Root_Id : constant Natural := S.Block_Semantic_Root_Id
                    (Document, S.Block_At (Document, Position));
               begin
                  Assert (Root_Id /= 0,
                          "committed root ID is nonzero");
                  if Position > 1 then
                     Assert (Root_Id > S.Block_Semantic_Root_Id
                               (Document, S.Block_At (Document, Position - 1)),
                             "committed root IDs are strictly increasing");
                  end if;
               end;
            end loop;
         end;
      end loop;
   end Test_Root_Identity_Chunkings_And_Finish;

   function Elapsed (Start, Stop : R.Time) return Long_Float is
   begin
      return Long_Float (R.To_Duration (Stop - Start));
   end Elapsed;

   function Timed_Parse (Source : String; Repetitions : Positive)
      return Long_Float is
      Total : Long_Float := 0.0;
   begin
      for Repeat in 1 .. Repetitions loop
         declare
            Parser : I.Instance;
            Start : constant R.Time := R.Clock;
            Stop : R.Time;
         begin
            I.Feed (Parser, Source, I.Semantic_Handler'(null));
            I.Flush (Parser, I.Semantic_Handler'(null));
            Stop := R.Clock;
            Total := Total + Elapsed (Start, Stop);
         end;
      end loop;
      return Total / Long_Float (Repetitions);
   end Timed_Parse;

   procedure Test_Parser_Long_Stream_Scaling
     (T : in out Test) is
      pragma Unreferenced (T);
      Small : constant String := Make_Source (80);
      Large : constant String := Make_Source (160);
      Small_Time : constant Long_Float := Timed_Parse (Small, 3);
      Large_Time : constant Long_Float := Timed_Parse (Large, 3);
   begin
      Ada.Text_IO.Put_Line
        ("CSM-2 Stage 6 parser scaling bytes="
         & Natural'Image (Small'Length) & ","
         & Natural'Image (Large'Length) & " seconds="
         & Long_Float'Image (Small_Time) & ","
         & Long_Float'Image (Large_Time));
      Assert (Large_Time <= Small_Time * 12.0 + 0.001,
              "parser scaling is grossly superlinear: ratio="
              & Long_Float'Image
                (Large_Time / Long_Float'Max (Small_Time, 0.000001)));
   end Test_Parser_Long_Stream_Scaling;

   procedure Test_Parser_Reset_Lifecycle_Stress
     (T : in out Test) is
      pragma Unreferenced (T);
      Parser : I.Instance;
      Document : S.Document;
   begin
      for Repeat in 1 .. 80 loop
         I.Feed
           (Parser, "<p>before</p><table><row><cell>x</cell></row>"
                 & "</table><math xmlns=""http://www.w3.org/1998/Math/MathML"""
                 & ">"
                 & "<mi>z</mi></math><p><strong>bad</p>",
                 I.Semantic_Handler'(null));
         I.Flush (Parser, I.Semantic_Handler'(null));
         I.Snapshot (Parser, Document);
         Assert (S.Block_Count (Document) > 0,
                 "stress iteration has no visible roots");
         I.Reset (Parser);
         I.Snapshot (Parser, Document);
         Assert (S.Block_Count (Document) = 0,
                 "Reset leaves stale semantic roots at iteration"
                 & Natural'Image (Repeat));
      end loop;
   end Test_Parser_Reset_Lifecycle_Stress;

   package Caller is new AUnit.Test_Caller (Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (Caller.Create
        ("CSM-2 Stage 6 generated valid boundaries and journals",
         Test_Generated_Valid_Boundaries_And_Journals'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 Stage 6 generated malformed source conservation",
         Test_Generated_Malformed_Source_Conservation'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 Stage 6 root identity chunkings and Finish",
         Test_Root_Identity_Chunkings_And_Finish'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 Stage 6 parser long stream scaling",
         Test_Parser_Long_Stream_Scaling'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 Stage 6 parser reset lifecycle stress",
         Test_Parser_Reset_Lifecycle_Stress'Access));
      return Result;
   end Suite;

end Coyote_CSM2_Stage6_Tests;
