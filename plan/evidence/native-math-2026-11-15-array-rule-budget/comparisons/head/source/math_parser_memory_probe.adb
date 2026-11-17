with Ada.Exceptions;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with System;
with Math_Macros;
with Math_Model;
with Math_Memory_Budget;
with Math_Source;
with Math_Syntax;
with Math_Tokens;
with Math_Unicode;
with Math_Work_Control;

procedure Math_Parser_Memory_Probe is
   use Math_Memory_Budget;
   use type Math_Model.Node_Kind;
   use type Math_Model.Array_Rule_Kind;
   use type Math_Source.Diagnostic_Kind;
   use type Math_Syntax.Diagnostic_Kind;
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
      Rejected : out Boolean; Shared : access Math_Macros.Context := null;
      Settings : Math_Syntax.Options := (others => <>)) is
   begin
      Rejected := False;
      begin
         if Shared = null then
            declare
               Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
                 (Text, Settings, Memory => Account);
            begin
               null;
            end;
         else
            declare
               Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
                 (Text, Shared, Settings, Memory => Account);
            begin
               null;
            end;
         end if;
      exception
         when Budget_Exceeded =>
            Rejected := True;
      end;
   end Parse_Expect_Budget;

   Node_Record_Width : constant Positive :=
     (Math_Syntax.Node'Size + System.Storage_Unit - 1) / System.Storage_Unit;
   Rule_Width : constant Positive :=
     (Math_Model.Array_Rule'Size + System.Storage_Unit - 1) /
       System.Storage_Unit;
   Saw_Accounting_Threshold : Boolean := False;
   Capture_AST_Baseline : Boolean := False;
   Previous_Charge : Natural := 0;
   AST_Baseline_Charge : Natural := 0;
   Rule_Observation_Stage : Natural := 0;
   Rule_Observed_Charges : array (1 .. 4) of Natural := (others => 0);
   Rule_Charge_Baseline : Natural := 0;
   Observe_Rule_Charges : Boolean := False;
   Observe_Drift : Boolean := False;
   Drift_Stage : Natural := 0;
   Drift_Slots : constant array (1 .. 5) of Natural := (4, 12, 8, 24, 16);

   type Accounting_Stop_Work is new Math_Work_Control.Context with record
      Account : Budget_Access := null;
      Threshold : Natural := Natural'Last;
      Reason : Math_Work_Control.Stop_Reason :=
        Math_Work_Control.Cancel_Requested;
      Stop_On_Rule_Growth : Boolean := False;
   end record;
   overriding function Check
     (Item : Accounting_Stop_Work) return Math_Work_Control.Stop_Reason;
   overriding function Check
     (Item : Accounting_Stop_Work) return Math_Work_Control.Stop_Reason is
      Current_Charge : Natural := 0;
      Rule_Bytes : Natural := 0;
   begin
      if Item.Account /= null then
         Current_Charge := Used (Item.Account.all);
         if Capture_AST_Baseline and then Current_Charge > Previous_Charge
           and then Current_Charge - Previous_Charge =
             32 * Node_Record_Width
         then
            AST_Baseline_Charge := Previous_Charge;
            Capture_AST_Baseline := False;
            if Observe_Rule_Charges then
               Rule_Charge_Baseline :=
                 AST_Baseline_Charge + 32 * Node_Record_Width;
            end if;
         end if;
         if Observe_Rule_Charges and then Rule_Charge_Baseline > 0 and then
           Current_Charge >= Rule_Charge_Baseline
         then
            Rule_Bytes := Current_Charge - Rule_Charge_Baseline;
            if Observe_Drift and then Drift_Stage < Drift_Slots'Last
              and then Rule_Bytes = Drift_Slots (Drift_Stage + 1) * Rule_Width
            then
               Drift_Stage := Drift_Stage + 1;
            end if;
            if Rule_Observation_Stage = 0 and then
              Rule_Bytes = 4 * Rule_Width
            then
               Rule_Observation_Stage := 1;
               Rule_Observed_Charges (1) := Rule_Bytes;
            elsif Rule_Observation_Stage = 1 and then
              Rule_Bytes = 12 * Rule_Width
            then
               Rule_Observation_Stage := 2;
               Rule_Observed_Charges (2) := Rule_Bytes;
               if Item.Stop_On_Rule_Growth then
                  Saw_Accounting_Threshold := True;
                  Previous_Charge := Current_Charge;
                  return Item.Reason;
               end if;
            elsif Rule_Observation_Stage = 2 and then
              Rule_Bytes = 8 * Rule_Width
            then
               Rule_Observation_Stage := 3;
               Rule_Observed_Charges (3) := Rule_Bytes;
            elsif Rule_Observation_Stage = 3 and then
              Rule_Bytes = 12 * Rule_Width
            then
               Rule_Observation_Stage := 4;
               Rule_Observed_Charges (4) := Rule_Bytes;
            end if;
         end if;
         Previous_Charge := Current_Charge;
         if not Item.Stop_On_Rule_Growth and then
           Current_Charge > Item.Threshold
         then
            Saw_Accounting_Threshold := True;
            return Item.Reason;
         end if;
      end if;
      return Math_Work_Control.Continue_Work;
   end Check;

   function Expansion_Source return String is
      use Ada.Strings.Unbounded;
      Result : Unbounded_String;
      Previous : Character := 'a';
   begin
      Append (Result, "\def\a{x}");
      for Index in 1 .. 11 loop
         declare
            Current : constant Character := Character'Val
              (Character'Pos ('a') + Index);
         begin
            Append (Result, "\def\" & Current & "{\" & Previous &
              "\" & Previous & "}");
            Previous := Current;
         end;
      end loop;
      Append (Result, "\" & Previous);
      return To_String (Result);
   end Expansion_Source;

   function Lexical_Charge_Bound (Text : String) return Natural is
      Width : constant Positive := Math_Tokens.Token'Size / 8;
      Map_Bound : constant Natural := Math_Source.Map_Storage_Bound
        (Natural'Max (1, Text'Length));
      Token_Bound : constant Natural :=
        Math_Tokens.Transformation_Token_Bound (Text'Length);
   begin
      return 2 * Map_Bound + (3 * Token_Bound + 1) * Width;
   end Lexical_Charge_Bound;

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
   Expansion_Text : constant String := Expansion_Source;
   Expansion_Options : constant Math_Syntax.Options :=
     (Max_Expand => 10_000, others => <>);
   Expansion_Lexical_Bound : constant Natural :=
     Lexical_Charge_Bound (Expansion_Text);
   Lexical_Peak : Natural := 0;
   Measured_Peak : Natural := 0;
   Expected_Expansion_Peak : Natural := 0;
   Expansion_AST_Count : Natural := 0;
   Expansion_Glyph_Count : Natural := 0;
   Rule_Drift_Source : constant String :=
     "\begin{array}{c}\hline\hdashline\hline\hdashline\hline "
       & "a\\\hline\hdashline\hline\hdashline\hline\hdashline"
       & "\hline b\end{array}";
   Rule_Link_Source : constant String :=
     "\begin{array}{c}a\\\hline b\end{array}+"
       & "\begin{array}{c}c\\\hline d\end{array}"
       & "+\begin{array}{c}e\\\hline f\end{array}";
   function Rule_Growth_Source return String is
      Result : Ada.Strings.Unbounded.Unbounded_String;
   begin
      for Index in 1 .. 20 loop
         if Index > 1 then
            Ada.Strings.Unbounded.Append (Result, "+");
         end if;
         Ada.Strings.Unbounded.Append
           (Result, "\begin{array}{c}a\\\hline b\end{array}");
      end loop;
      return Ada.Strings.Unbounded.To_String (Result);
   end Rule_Growth_Source;
   Rule_Source : constant String :=
     "\begin{array}{c}a\\\hline\hdashline\hline\hdashline"
       & "\hline b\end{array}+\begin{array}{c}c\\\hline d\end{array}";
   Rejected : Boolean;
   Delayed_Stop : aliased Countdown_Work;

   procedure Check_Rule_Boundary (Text : String; Label : String) is
      Measure : aliased Budget;
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
        (Text, Memory => Measure'Unchecked_Access);
      Peak_Bytes : constant Positive := Peak (Measure);
      Exact : aliased Budget (Limit => Peak_Bytes);
      Short : aliased Budget (Limit => Peak_Bytes - 1);
      Held_Account : aliased Budget (Limit => Peak_Bytes);
      Held : Reservation;
      Denied : Boolean;
   begin
      Parse_Expect_Budget (Text, Exact'Unchecked_Access, Denied);
      Check (Math_Syntax.Is_Valid (Parsed) and not Denied and
        Used (Exact) = 0, Label & " exact measured fit");
      Parse_Expect_Budget (Text, Short'Unchecked_Access, Denied);
      Check (Denied and Used (Short) = 0, Label & " one-byte-short cleanup");
      Reserve (Held, Held_Account'Unchecked_Access, 1);
      Parse_Expect_Budget (Text, Held_Account'Unchecked_Access, Denied);
      Check (Denied and Used (Held_Account) = 1,
        Label & " held charge preserved");
      Release (Held);
      Parse_Expect_Budget (Text, Held_Account'Unchecked_Access, Denied);
      Check (not Denied and Used (Held_Account) = 0,
        Label & " rejected account reusable");
   end Check_Rule_Boundary;

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
      Short : aliased Budget (Limit => Lexical_Peak + 1);
      Depth : constant Natural := Math_Macros.Scope_Depth (Context);
   begin
      Parse_Expect_Budget
        ("\def\localOnly{x}x", Short'Unchecked_Access,
         Rejected, Context'Access, Expansion_Options);
      Check (Rejected and Math_Macros.Scope_Depth (Context) = Depth and
        not Math_Macros.Is_Defined (Context, "\localOnly"),
        "pre-parse budget rejection leaves macro scope untouched");
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
      Work : aliased Accounting_Stop_Work :=
        (Account => Account'Unchecked_Access,
         Threshold => Expansion_Lexical_Bound,
         Reason => Math_Work_Control.Deadline_Reached,
         others => <>);
      Raised : Boolean := False;
   begin
      Saw_Accounting_Threshold := False;
      begin
         declare
            Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
              (Expansion_Text, Expansion_Options,
               Work => Work'Unchecked_Access,
               Memory => Account'Unchecked_Access);
         begin
            null;
         end;
      exception
         when Math_Work_Control.Deadline_Expired => Raised := True;
      end;
      Check (Raised and Saw_Accounting_Threshold and Used (Account) = 0,
        "AST-stage deadline propagates and releases reservations");
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

   declare
      Measure : aliased Budget;
      Work : aliased Accounting_Stop_Work :=
        (Account => Measure'Unchecked_Access,
         Threshold => Natural'Last,
         Reason => Math_Work_Control.Cancel_Requested,
         others => <>);
   begin
      Capture_AST_Baseline := True;
      Previous_Charge := 0;
      AST_Baseline_Charge := 0;
      declare
         Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
           (Expansion_Text, Expansion_Options,
            Work => Work'Unchecked_Access,
            Memory => Measure'Unchecked_Access);
      begin
         Expansion_AST_Count := Math_Syntax.Count (Parsed);
         for Node_Index in 1 .. Expansion_AST_Count loop
            if Math_Syntax.Element (Parsed, Node_Index).Kind =
              Math_Model.Glyph_Node
            then
               Expansion_Glyph_Count := Expansion_Glyph_Count + 1;
            end if;
         end loop;
         Capture_AST_Baseline := False;
         Lexical_Peak := AST_Baseline_Charge;
         Expected_Expansion_Peak := Lexical_Peak +
           (2_048 + 4_096) * Node_Record_Width;
         Measured_Peak := Peak (Measure);
         Check (Math_Syntax.Is_Valid (Parsed) and
           Expansion_AST_Count = 2_049 and Expansion_Glyph_Count = 2_048,
           "doubling macros return an inspectable 2048-glyph AST");
         Check (Lexical_Peak > 0 and
           Measured_Peak = Expected_Expansion_Peak and Used (Measure) = 0,
           "AST growth peak (baseline " & Natural'Image (Lexical_Peak) &
             ", measured " & Natural'Image (Measured_Peak) &
             ", expected " & Natural'Image (Expected_Expansion_Peak) & ")");
      end;
   end;

   declare
      Exact : aliased Budget (Limit => Measured_Peak);
      Short : aliased Budget (Limit => Measured_Peak - 1);
   begin
      Parse_Expect_Budget
        (Expansion_Text, Exact'Unchecked_Access, Rejected,
         Settings => Expansion_Options);
      Check (not Rejected and Peak (Exact) = Measured_Peak and
        Used (Exact) = 0, "AST-dominated exact measured budget");
      Parse_Expect_Budget
        (Expansion_Text, Short'Unchecked_Access, Rejected,
         Settings => Expansion_Options);
      Check (Rejected and Used (Short) = 0,
        "AST-dominated one-byte-short budget releases charge");
   end;

   declare
      Account : aliased Budget (Limit => Measured_Peak);
      Held : Reservation;
   begin
      Reserve (Held, Account'Unchecked_Access, 1);
      Parse_Expect_Budget
        (Expansion_Text, Account'Unchecked_Access, Rejected,
         Settings => Expansion_Options);
      Check (Rejected and Used (Account) = 1,
        "held charge rejects AST growth without disturbing owner charge");
      Release (Held);
      Parse_Expect_Budget
        (Expansion_Text, Account'Unchecked_Access, Rejected,
         Settings => Expansion_Options);
      Check (not Rejected and Used (Account) = 0 and
        Peak (Account) = Measured_Peak,
        "AST budget reusable after held-charge rejection");
   end;

   declare
      Account : aliased Budget;
      Work : aliased Accounting_Stop_Work :=
        (Account => Account'Unchecked_Access,
         Threshold => Expansion_Lexical_Bound,
         Reason => Math_Work_Control.Cancel_Requested,
         others => <>);
      Raised : Boolean := False;
   begin
      Saw_Accounting_Threshold := False;
      begin
         declare
            Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
              (Expansion_Text, Expansion_Options,
               Work => Work'Unchecked_Access,
               Memory => Account'Unchecked_Access);
            pragma Unreferenced (Parsed);
         begin
            null;
         end;
      exception
         when Math_Work_Control.Stop_Requested => Raised := True;
      end;
      Check (Raised and Saw_Accounting_Threshold and Used (Account) = 0,
        "live AST charge triggers cancellation and releases reservations");
   end;

   declare
      Account : aliased Budget;
      Work : aliased Accounting_Stop_Work :=
        (Account => Account'Unchecked_Access, others => <>);
      Parsed : Math_Syntax.Document;
      Rule_Count : Natural := 0;
   begin
      Drift_Stage := 0;
      Observe_Drift := True;
      Observe_Rule_Charges := True;
      Capture_AST_Baseline := True;
      Rule_Charge_Baseline := 0;
      Rule_Observation_Stage := 0;
      Previous_Charge := 0;
      Parsed := Math_Syntax.Parse
        (Rule_Drift_Source, Work => Work'Unchecked_Access,
         Memory => Account'Unchecked_Access);
      Observe_Drift := False;
      Observe_Rule_Charges := False;
      Check (Drift_Stage = Drift_Slots'Last,
        "first-row regrowth live charge follows 4/12/8/24/16 slots");
      for Index in 1 .. Math_Syntax.Count (Parsed) loop
         declare
            Current : constant Math_Syntax.Node :=
              Math_Syntax.Element (Parsed, Index);
         begin
            if Current.Kind = Math_Model.Array_Node then
               Rule_Count := Rule_Count + Natural
                 (Current.Array_Rules.Length);
            end if;
         end;
      end loop;
      Check (Math_Syntax.Is_Valid (Parsed) and Rule_Count = 12 and
        Used (Account) = 0,
        "first-row link preserves twelve rules through later growth");
   end;

   declare
      Parsed : constant Math_Syntax.Document :=
        Math_Syntax.Parse (Rule_Link_Source);
      Array_Count : Natural := 0;
   begin
      for Index in 1 .. Math_Syntax.Count (Parsed) loop
         declare
            Current : constant Math_Syntax.Node :=
              Math_Syntax.Element (Parsed, Index);
         begin
            if Current.Kind = Math_Model.Array_Node then
               Array_Count := Array_Count + 1;
            end if;
         end;
      end loop;
      Check (Math_Syntax.Is_Valid (Parsed) and Array_Count = 3,
        "multiple top-level array links retain all array nodes");
   end;

   declare
      Parsed : constant Math_Syntax.Document :=
        Math_Syntax.Parse (Rule_Growth_Source);
   begin
      Check (Math_Syntax.Is_Valid (Parsed) and Math_Syntax.Count (Parsed) > 32,
        "outer node-vector growth follows accumulated array rules");
   end;

   Check_Rule_Boundary (Rule_Drift_Source, "first-row regrowth");
   Check_Rule_Boundary (Rule_Growth_Source, "outer-node growth");

   declare
      Measure : aliased Budget;
      Work : aliased Accounting_Stop_Work :=
        (Account => Measure'Unchecked_Access,
         Threshold => Natural'Last,
         Reason => Math_Work_Control.Cancel_Requested,
         others => <>);
      Parsed : Math_Syntax.Document;
   begin
      Rule_Observation_Stage := 0;
      Rule_Observed_Charges := (others => 0);
      Rule_Charge_Baseline := 0;
      Observe_Rule_Charges := True;
      Capture_AST_Baseline := True;
      Previous_Charge := 0;
      AST_Baseline_Charge := 0;
      Parsed := Math_Syntax.Parse
        (Rule_Source, Work => Work'Unchecked_Access,
         Memory => Measure'Unchecked_Access);
      Observe_Rule_Charges := False;
      Check (Math_Syntax.Is_Valid (Parsed) and Rule_Observation_Stage = 4 and
        Rule_Observed_Charges (1) = 4 * Rule_Width and
        Rule_Observed_Charges (2) = 12 * Rule_Width and
        Rule_Observed_Charges (3) = 8 * Rule_Width and
        Rule_Observed_Charges (4) = 12 * Rule_Width and
        Used (Measure) = 0,
        "rule charge stages " & Natural'Image (Rule_Observation_Stage) &
          " [" & Natural'Image (Rule_Observed_Charges (1)) & "," &
          Natural'Image (Rule_Observed_Charges (2)) & "," &
          Natural'Image (Rule_Observed_Charges (3)) & "," &
          Natural'Image (Rule_Observed_Charges (4)) & "]");
      Check (AST_Baseline_Charge > 0 and Math_Syntax.Count (Parsed) < 32,
        "rule fixture baseline is lexical plus initial 32-node capacity");
   end;

   declare
      Account : aliased Budget;
      Work : aliased Accounting_Stop_Work :=
        (Account => Account'Unchecked_Access,
         Threshold => Natural'Last,
         Reason => Math_Work_Control.Cancel_Requested,
         Stop_On_Rule_Growth => True);
      Raised : Boolean := False;
   begin
      Rule_Observation_Stage := 0;
      Rule_Observed_Charges := (others => 0);
      Rule_Charge_Baseline := 0;
      Observe_Rule_Charges := True;
      Capture_AST_Baseline := True;
      Previous_Charge := 0;
      AST_Baseline_Charge := 0;
      begin
         declare
            Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
              (Rule_Source, Work => Work'Unchecked_Access,
               Memory => Account'Unchecked_Access);
            pragma Unreferenced (Parsed);
         begin
            null;
         end;
      exception
         when Math_Work_Control.Stop_Requested => Raised := True;
      end;
      Observe_Rule_Charges := False;
      Check (Raised and Saw_Accounting_Threshold and
        Rule_Observation_Stage = 2 and
        Rule_Observed_Charges (1) = 4 * Rule_Width and
        Rule_Observed_Charges (2) = 12 * Rule_Width and
        Used (Account) = 0,
        "cancel occurs at measured old/new rule-array overlap and releases charges");
   end;

   declare
      Account : aliased Budget;
      Work : aliased Accounting_Stop_Work :=
        (Account => Account'Unchecked_Access,
         Threshold => Natural'Last,
         Reason => Math_Work_Control.Deadline_Reached,
         Stop_On_Rule_Growth => True);
      Raised : Boolean := False;
   begin
      Rule_Observation_Stage := 0;
      Rule_Observed_Charges := (others => 0);
      Rule_Charge_Baseline := 0;
      Observe_Rule_Charges := True;
      Capture_AST_Baseline := True;
      Previous_Charge := 0;
      AST_Baseline_Charge := 0;
      begin
         declare
            Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
              (Rule_Source, Work => Work'Unchecked_Access,
               Memory => Account'Unchecked_Access);
            pragma Unreferenced (Parsed);
         begin
            null;
         end;
      exception
         when Math_Work_Control.Deadline_Expired => Raised := True;
      end;
      Observe_Rule_Charges := False;
      Check (Raised and Saw_Accounting_Threshold and
        Rule_Observation_Stage = 2 and
        Rule_Observed_Charges (1) = 4 * Rule_Width and
        Rule_Observed_Charges (2) = 12 * Rule_Width and
        Used (Account) = 0,
        "deadline occurs at measured rule overlap and releases charges");
   end;

   declare
      Account : aliased Budget;
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
        (Rule_Source & "{", Memory => Account'Unchecked_Access);
   begin
      Check (not Math_Syntax.Is_Valid (Parsed) and
        Math_Syntax.Error (Parsed)'Length > 0 and
        Math_Syntax.Count (Parsed) = 0 and Used (Account) = 0,
        "malformed suffix after array rules reports failure and clears partial nodes");
   end;

   declare
      Account : aliased Budget;
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
        (Rule_Source & "\text{\url{https://example.test}}",
         (Strict => Math_Syntax.Strict_Warn, others => <>),
         Memory => Account'Unchecked_Access);
      Array_Count : Natural := 0;
      First_Rule_Count : Natural := 0;
      Second_Rule_Count : Natural := 0;
      First_Kind_OK : Boolean := True;
      Second_Kind_OK : Boolean := True;
      First_Boundary_OK : Boolean := True;
      Second_Boundary_OK : Boolean := True;
   begin
      for Node_Index in 1 .. Math_Syntax.Count (Parsed) loop
         declare
            Current : constant Math_Syntax.Node :=
              Math_Syntax.Element (Parsed, Node_Index);
         begin
            if Current.Kind = Math_Model.Array_Node then
               Array_Count := Array_Count + 1;
               if Array_Count = 1 then
                  First_Rule_Count := Natural (Current.Array_Rules.Length);
                  for Index in 1 .. First_Rule_Count loop
                     First_Kind_OK := First_Kind_OK and then
                       Current.Array_Rules (Index).Kind =
                         (if Index mod 2 = 0 then
                            Math_Model.Dashed_Array_Rule
                          else Math_Model.Solid_Array_Rule);
                     First_Boundary_OK := First_Boundary_OK and then
                       Current.Array_Rules (Index).Boundary = 1;
                  end loop;
               else
                  Second_Rule_Count := Natural (Current.Array_Rules.Length);
                  for Rule of Current.Array_Rules loop
                     Second_Kind_OK := Second_Kind_OK and then
                       Rule.Kind = Math_Model.Solid_Array_Rule;
                     Second_Boundary_OK := Second_Boundary_OK and then
                       Rule.Boundary = 1;
                  end loop;
               end if;
            end if;
         end;
      end loop;
      Check (Math_Syntax.Is_Valid (Parsed) and Array_Count = 2 and
        First_Rule_Count = 5 and Second_Rule_Count = 1 and
        First_Kind_OK and Second_Kind_OK and First_Boundary_OK and
        Second_Boundary_OK and Math_Syntax.Error (Parsed)'Length = 0 and
        Math_Syntax.Diagnostic_Count (Parsed) > 0 and
        Math_Syntax.Diagnostic_At (Parsed, 1).Kind = Math_Syntax.Warning and
        Used (Account) = 0,
        "post-array warning preserves all rule kinds and boundaries");
   end;

   declare
      Account : aliased Budget;
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
        (Expansion_Text, Expansion_Options,
         Memory => Account'Unchecked_Access);
      Glyph_Count : Natural := 0;
      Has_X : Boolean := False;
   begin
      for Node_Index in 1 .. Math_Syntax.Count (Parsed) loop
         declare
            Current : constant Math_Syntax.Node :=
              Math_Syntax.Element (Parsed, Node_Index);
         begin
            if Current.Kind = Math_Model.Glyph_Node then
               Glyph_Count := Glyph_Count + 1;
               Has_X := Has_X or else
                 Current.Code_Point = Character'Pos ('x');
            end if;
         end;
      end loop;
      Check (Math_Syntax.Is_Valid (Parsed) and Glyph_Count >= 2_048 and
        Has_X and Used (Account) = 0,
        "returned AST content remains usable after reservation release");
   end;

   declare
      Local : aliased Math_Macros.Context;
      Bounded : aliased Budget
        (Limit => Expansion_Lexical_Bound + 32 * Node_Record_Width);
      Depth : constant Natural := Math_Macros.Scope_Depth (Local);
      Raised : Boolean := False;
   begin
      begin
         declare
            Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
              (Expansion_Text, Local'Access, Expansion_Options,
               Memory => Bounded'Unchecked_Access);
            pragma Unreferenced (Parsed);
         begin
            null;
         end;
      exception
         when Budget_Exceeded => Raised := True;
      end;
      Check (Raised and Math_Macros.Scope_Depth (Local) = Depth and
        not Math_Macros.Is_Defined (Local, "\a"),
        "AST budget rejection rolls back local expansion definitions");
   end;

   declare
      Global : aliased Math_Macros.Context;
      Bounded : aliased Budget
        (Limit => Expansion_Lexical_Bound + 32 * Node_Record_Width);
      Raised : Boolean := False;
   begin
      begin
         declare
            Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
              (Expansion_Text, Global'Access, Expansion_Options,
               Global_Group => True, Memory => Bounded'Unchecked_Access);
            pragma Unreferenced (Parsed);
         begin
            null;
         end;
      exception
         when Budget_Exceeded => Raised := True;
      end;
      Check (Raised and Math_Macros.Is_Defined (Global, "\a"),
        "AST budget rejection retains Global_Group definitions");
   end;

   declare
      Local : aliased Math_Macros.Context;
      Depth : constant Natural := Math_Macros.Scope_Depth (Local);
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
        ("\def\rollbackLocal{x}x{", Local'Access);
   begin
      Check (not Math_Syntax.Is_Valid (Parsed) and
        not Math_Macros.Is_Defined (Local, "\rollbackLocal") and
        Math_Macros.Scope_Depth (Local) = Depth,
        "syntax failure after mutation rolls back local macro group");
   end;

   declare
      Global : aliased Math_Macros.Context;
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
        ("\def\rollbackGlobal{x}x{", Global'Access,
         Global_Group => True);
   begin
      Check (not Math_Syntax.Is_Valid (Parsed) and
        Math_Macros.Is_Defined (Global, "\rollbackGlobal"),
        "syntax failure preserves Global_Group definition");
   end;

   declare
      Account : aliased Budget;
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
        ("", Memory => Account'Unchecked_Access);
   begin
      Check (Math_Syntax.Is_Valid (Parsed) and Math_Syntax.Count (Parsed) = 1
        and Math_Syntax.Root (Parsed) = 1 and Used (Account) = 0,
        "empty input returns valid root document and releases reservation");
   end;

   declare
      Account : aliased Budget;
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
        ("x+{y", Memory => Account'Unchecked_Access);
   begin
      Check (not Math_Syntax.Is_Valid (Parsed) and Used (Account) = 0,
        "malformed input after AST construction releases node charge");
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
