with Ada.Exceptions;
with Ada.Text_IO;
with Math_Macros;
with Math_Memory_Budget;
with Math_Source;
with Math_Syntax;
with Math_Tokens;
with Math_Unicode;
with Math_Work_Control;

procedure Math_Parser_Memory_Probe is
   use Math_Memory_Budget;
   use type Math_Source.Diagnostic_Kind;
   use type Math_Tokens.Diagnostic_Kind;
   use type Math_Work_Control.Stop_Reason;

   Poll_Count : Natural := 0;
   Stop_After : Natural := 0;
   type Countdown_Work is new Math_Work_Control.Context with record
      Reason : Math_Work_Control.Stop_Reason :=
        Math_Work_Control.Cancel_Requested;
   end record;
   overriding function Check
     (Item : Countdown_Work) return Math_Work_Control.Stop_Reason;
   overriding function Check
     (Item : Countdown_Work) return Math_Work_Control.Stop_Reason is
   begin
      Poll_Count := Poll_Count + 1;
      if Poll_Count >= Stop_After then
         return Item.Reason;
      end if;
      return Math_Work_Control.Continue_Work;
   end Check;

   type Fixed_Work is new Math_Work_Control.Context with record
      Reason : Math_Work_Control.Stop_Reason :=
        Math_Work_Control.Continue_Work;
   end record;
   overriding function Check
     (Item : Fixed_Work) return Math_Work_Control.Stop_Reason;
   overriding function Check
     (Item : Fixed_Work) return Math_Work_Control.Stop_Reason is
   begin
      return Item.Reason;
   end Check;

   Checks : Natural := 0;
   Failures : Natural := 0;

   procedure Check (Condition : Boolean; Label : String) is
   begin
      Checks := Checks + 1;
      if Condition then
         Ada.Text_IO.Put_Line ("ok " & Label);
      else
         Failures := Failures + 1;
         Ada.Text_IO.Put_Line ("FAIL " & Label);
      end if;
   end Check;

   procedure Parse_Expect_Budget
     (Text : String; Account : not null Budget_Access;
      Rejected : out Boolean; Shared : access Math_Macros.Context := null) is
   begin
      Rejected := False;
      begin
         if Shared = null then
            declare
               Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
                 (Text, Memory => Account);
               pragma Unreferenced (Parsed);
            begin
               null;
            end;
         else
            declare
               Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
                 (Text, Shared, Memory => Account);
               pragma Unreferenced (Parsed);
            begin
               null;
            end;
         end if;
      exception
         when Budget_Exceeded =>
            Rejected := True;
      end;
   end Parse_Expect_Budget;

   function UTF8 (Code_Point : Natural) return String is
   begin
      if Code_Point < 16#80# then
         return String'(1 => Character'Val (Code_Point));
      elsif Code_Point < 16#800# then
         return Character'Val (16#C0# + Code_Point / 64) &
           Character'Val (16#80# + Code_Point mod 64);
      else
         return Character'Val (16#E0# + Code_Point / 4_096) &
           Character'Val (16#80# + (Code_Point / 64) mod 64) &
           Character'Val (16#80# + Code_Point mod 64);
      end if;
   end UTF8;

   procedure Check_Lex_Bound (Text : String; Label : String) is
      Source : Math_Source.Source;
      Source_Diagnostic : Math_Source.Diagnostic_Kind;
      Lexical_Diagnostic : Math_Tokens.Diagnostic_Kind;
      Error_Byte : Natural;
      Tokens : Math_Tokens.Stream;
      Bound : Natural;
   begin
      Math_Source.Create (Text, Source, Source_Diagnostic, Error_Byte);
      Check (Source_Diagnostic = Math_Source.No_Error,
        Label & " source creation");
      if Source_Diagnostic = Math_Source.No_Error then
         Math_Tokens.Lex
           (Source, Tokens, Lexical_Diagnostic, Error_Byte);
         Bound := Math_Tokens.Transformation_Token_Bound (Text'Length);
         Check (Lexical_Diagnostic = Math_Tokens.No_Error and then
           Math_Tokens.Count (Tokens) <= Bound,
           Label & " token count within transformation bound");
         Check (Math_Tokens.Vector_Storage_Bytes (Tokens) =
           Bound * (Math_Tokens.Token'Size / 8),
           Label & " vector retains reserved bound capacity");
      end if;
   end Check_Lex_Bound;

   procedure Check_Decomposition_Table is
      Entries : Natural := 0;
   begin
      for Code_Point in 16#80# .. 16#3FF# loop
         if Math_Unicode.Lookup_Decomposition (Code_Point)'Length > 0 then
            Entries := Entries + 1;
            Check_Lex_Bound (UTF8 (Code_Point),
              "decomposition U+" & Natural'Image (Code_Point));
         end if;
      end loop;
      Check (Entries > 0, "Latin and Greek decomposition entries discovered");
   end Check_Decomposition_Table;

   procedure Check_Parse_Status
     (Text : String; Expected_Valid : Boolean; Label : String) is
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse (Text);
   begin
      Check (Math_Syntax.Is_Valid (Parsed) = Expected_Valid, Label);
   end Check_Parse_Status;

   Source_Text : constant String := "x + \alpha + y^2";
   Lexical_Work_Text : constant String := (1 .. 4_096 => 'x');
   Measured_Peak : Natural := 0;
   Rejected : Boolean;
   Delayed_Stop : aliased Countdown_Work;
   Deadline_Stop : aliased Fixed_Work :=
     (Reason => Math_Work_Control.Deadline_Reached);

begin
   Check_Lex_Bound (UTF8 (16#390#), "precomposed U+0390 two-mark scalar");
   Check_Lex_Bound ("x" & UTF8 (16#301#), "combining acute wrapper");
   Check_Lex_Bound ("xₓ⁺", "subscript and superscript wrappers");
   Check_Decomposition_Table;
   Check_Parse_Status ("x + α", True, "known valid Unicode parse status");
   Check_Parse_Status ("{x", False, "known invalid parse status");
   Check_Parse_Status
     ("x" & Character'Val (16#C0#) & Character'Val (16#AF#), False,
      "known invalid UTF-8 parse status");
   declare
      Measure : aliased Budget;
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
        (Source_Text, Memory => Measure'Unchecked_Access);
      pragma Unreferenced (Parsed);
   begin
      Measured_Peak := Peak (Measure);
      Check (Measured_Peak > 0 and Used (Measure) = 0,
        "successful stage reservations release at parser return");
   end;
   Check (Measured_Peak > 1,
     "measured peak leaves room for one-byte-short budget");

   declare
      Exact : aliased Budget (Limit => Measured_Peak);
      Short : aliased Budget (Limit => Measured_Peak - 1);
      Blocked : aliased Budget (Limit => Measured_Peak);
      Held : Reservation;
   begin
      Parse_Expect_Budget
        (Source_Text, Exact'Unchecked_Access, Rejected);
      Check (not Rejected and Used (Exact) = 0 and
        Peak (Exact) = Measured_Peak, "measured peak exact fit");
      Parse_Expect_Budget
        (Source_Text, Short'Unchecked_Access, Rejected);
      Check (Rejected and Used (Short) = 0,
        "one-byte-short pre-admission rejects without charge leak");
      Reserve (Held, Blocked'Unchecked_Access, 1);
      Parse_Expect_Budget
        (Source_Text, Blocked'Unchecked_Access, Rejected);
      Check (Rejected and Used (Blocked) = 1,
        "held charge overlaps parser reservation on rejection");
      Release (Held);
      Parse_Expect_Budget
        (Source_Text, Blocked'Unchecked_Access, Rejected);
      Check (not Rejected and Used (Blocked) = 0,
        "budget reusable after overlap rejection");
   end;

   declare
      Context : aliased Math_Macros.Context;
      Short : aliased Budget (Limit => Measured_Peak - 1);
      Depth : constant Natural := Math_Macros.Scope_Depth (Context);
   begin
      Parse_Expect_Budget
        ("\def\localOnly{x}x", Short'Unchecked_Access,
         Rejected, Context'Access);
      Check (Rejected and Math_Macros.Scope_Depth (Context) = Depth and
        not Math_Macros.Is_Defined (Context, "\localOnly"),
        "pre-parse budget rejection leaves macro scope untouched; post-group rollback untested");
   end;

   declare
      Account : aliased Budget;
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
        ("\verb|x", Memory => Account'Unchecked_Access);
      pragma Unreferenced (Parsed);
   begin
      Check (Used (Account) = 0,
        "lexical failure releases source and token reservations");
   end;

   declare
      Account : aliased Budget;
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
        ("{x", Memory => Account'Unchecked_Access);
      pragma Unreferenced (Parsed);
   begin
      Check (Used (Account) = 0,
        "syntax failure releases source and token reservations");
   end;

   declare
      Invalid : constant String :=
        "x" & Character'Val (16#C0#) & Character'Val (16#AF#);
      Map_Bound : constant Natural :=
        Math_Source.Map_Storage_Bound (Invalid'Length);
      Exact : aliased Budget (Limit => Map_Bound);
      Short : aliased Budget (Limit => Map_Bound - 1);
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
        (Invalid, Memory => Exact'Unchecked_Access);
      pragma Unreferenced (Parsed);
   begin
      Check (Peak (Exact) = Map_Bound and Used (Exact) = 0,
        "source-map stage admits exact predicted bound");
      declare
         Rejected_Source : Boolean := False;
      begin
         begin
            declare
               Failed_Parse : constant Math_Syntax.Document :=
                 Math_Syntax.Parse (Invalid, Memory => Short'Unchecked_Access);
               pragma Unreferenced (Failed_Parse);
            begin
               null;
            end;
         exception
            when Budget_Exceeded => Rejected_Source := True;
         end;
         Check (Rejected_Source and Used (Short) = 0,
           "source-map stage rejects one byte below bound");
      end;
   end;

   declare
      Account : aliased Budget;
      Work : constant Math_Work_Control.Context_Access :=
        Delayed_Stop'Unchecked_Access;
      Raised : Boolean := False;
   begin
      Poll_Count := 0;
      Stop_After := Lexical_Work_Text'Length + 4;
      begin
         declare
            Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
              (Lexical_Work_Text, Work => Work,
               Memory => Account'Unchecked_Access);
            pragma Unreferenced (Parsed);
         begin
            null;
         end;
      exception
         when Math_Work_Control.Stop_Requested => Raised := True;
      end;
      Check (Raised and Poll_Count = Stop_After and Used (Account) = 0,
        "lexical cancellation after token allocation releases reservations");
   end;

   declare
      Account : aliased Budget;
      Work : constant Math_Work_Control.Context_Access :=
        Deadline_Stop'Unchecked_Access;
      Raised : Boolean := False;
   begin
      begin
         declare
            Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
              (Source_Text, Work => Work, Memory => Account'Unchecked_Access);
            pragma Unreferenced (Parsed);
         begin
            null;
         end;
      exception
         when Math_Work_Control.Deadline_Expired => Raised := True;
      end;
      Check (Raised and Used (Account) = 0,
        "deadline propagates and releases reservations");
   end;

   declare
      Unicode : constant String := "αβ😀";
      Account : aliased Budget;
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
        (Unicode, Memory => Account'Unchecked_Access);
      pragma Unreferenced (Parsed);
   begin
      Check (Peak (Account) > 0 and Used (Account) = 0,
        "multibyte source admission and cleanup");
   end;

   declare
      Expanded_Unicode : constant String := "éx" & Character'Val (16#CC#) &
        Character'Val (16#81#) & "ₓ⁺";
      Account : aliased Budget;
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
        (Expanded_Unicode, Memory => Account'Unchecked_Access);
      pragma Unreferenced (Parsed);
   begin
      Check (Peak (Account) > 0 and Used (Account) = 0,
        "Unicode decomposition, accent, and script expansion cleanup");
   end;

   declare
      Worst_Decomposition : constant String :=
        Character'Val (16#CE#) & Character'Val (16#B9#) &
        Character'Val (16#CC#) & Character'Val (16#88#) &
        Character'Val (16#CC#) & Character'Val (16#81#);
      Stress_Text : constant String :=
        (1 .. 32 => 'x') & Worst_Decomposition &
        Character'Val (16#CC#) & Character'Val (16#81#) & "ₓ⁺";
      Peak_Bytes : Natural;
   begin
      declare
         Measure : aliased Budget;
         Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
           (Stress_Text, Memory => Measure'Unchecked_Access);
         pragma Unreferenced (Parsed);
      begin
         Peak_Bytes := Peak (Measure);
         Check (Peak_Bytes < 1_048_576 and Used (Measure) = 0,
           "short worst-case Unicode expansion stays below 1 MiB");
      end;
      declare
         Exact : aliased Budget (Limit => Peak_Bytes);
         Short : aliased Budget (Limit => Peak_Bytes - 1);
      begin
         Parse_Expect_Budget
           (Stress_Text, Exact'Unchecked_Access, Rejected);
         Check (not Rejected and Peak (Exact) = Peak_Bytes,
           "worst-case Unicode expansion exact budget fit");
         Parse_Expect_Budget
           (Stress_Text, Short'Unchecked_Access, Rejected);
         Check (Rejected and Used (Short) = 0,
           "worst-case Unicode expansion one-byte-short rejection");
      end;
   end;

   declare
      Account : aliased Budget;
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
        ((1 .. Math_Syntax.Max_Source_Bytes => 'x'),
         Memory => Account'Unchecked_Access);
      pragma Unreferenced (Parsed);
   begin
      Check (Peak (Account) > 0 and Used (Account) = 0,
        "maximum-size source control");
   end;

   Ada.Text_IO.Put_Line
     ("math_parser_memory_probe: " & Natural'Image (Checks) &
      " checks; " & Natural'Image (Failures) & " failures; measured peak " &
      Natural'Image (Measured_Peak) & " bytes");
   if Failures /= 0 then
      raise Program_Error with "parser memory checks failed";
   end if;
exception
   when Error : others =>
      Ada.Text_IO.Put_Line (Ada.Exceptions.Exception_Information (Error));
      raise;
end Math_Parser_Memory_Probe;
