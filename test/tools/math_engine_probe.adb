with Ada.Command_Line;
with Ada.Containers;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Interfaces;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Math_Engine;
with Math_Layout;
with Math_Macros;
with Math_Model;
with Math_Paths;
with Math_Semantics;
with Math_Syntax;
with Math_Work_Control;

procedure Math_Engine_Probe is
   use type Ada.Containers.Count_Type;
   use type Interfaces.Unsigned_32;
   use type Math_Engine.Status_Kind;
   use type Math_Work_Control.Stop_Reason;
   use type Math_Macros.Diagnostic_Kind;
   use type Math_Layout.Command_Kind;
   use type Math_Layout.Box;
   use type Math_Model.Array_Rule_Kind;
   use type Math_Model.Node_Kind;
   use type Math_Paths.Segment;
   use type Math_Syntax.Diagnostic_Kind;
   Checks : Natural := 0;
   Failures : Natural := 0;
   Shared : aliased Math_Macros.Context;

   type Budget_Context is new Math_Work_Control.Context with record
      Stop_At : Natural := Natural'Last;
      Reason : Math_Work_Control.Stop_Reason :=
        Math_Work_Control.Continue_Work;
   end record;
   type Budget_Context_Access is access all Budget_Context;

   overriding function Check
     (Item : Budget_Context) return Math_Work_Control.Stop_Reason;

   Poll_Count : Natural := 0;
   Cancel_Context : aliased Budget_Context :=
     (Math_Work_Control.Context with Stop_At => 3,
      Reason => Math_Work_Control.Cancel_Requested);
   Deadline_Context : aliased Budget_Context :=
     (Math_Work_Control.Context with Stop_At => 3,
      Reason => Math_Work_Control.Deadline_Reached);

   overriding function Check
     (Item : Budget_Context) return Math_Work_Control.Stop_Reason is
   begin
      Poll_Count := Poll_Count + 1;
      return (if Poll_Count >= Item.Stop_At then Item.Reason
              else Math_Work_Control.Continue_Work);
   end Check;

   procedure Check (Condition : Boolean; Label : String) is
   begin
      Checks := Checks + 1;
      if not Condition then
         Failures := Failures + 1;
         Ada.Text_IO.Put_Line ("FAIL " & Label);
      end if;
   end Check;

   procedure Expect_Abuse_Rejection
     (Source, Expected_Error, Label : String;
      Bounded_Source : Boolean := False)
   is
      Opt : Math_Engine.Request;
      Outp : Math_Engine.Result;
      Prior_Depth : constant Natural := Math_Macros.Scope_Depth (Shared);
      Prefix_Matches : Boolean := False;
   begin
      Math_Engine.Parse (Source, Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Parse_Error and then
        Ada.Strings.Fixed.Index
          (Math_Engine.Error (Outp), Expected_Error) > 0,
        Label & " reports the expected rejection category: " &
          Math_Engine.Error (Outp));
      Check (not Outp.Geometry.Valid and then
        Outp.Geometry.Commands.Is_Empty,
        Label & " publishes no fallback or successful geometry");
      Check (not Math_Syntax.Is_Valid (Outp.Parsed),
        Label & " does not retain a valid parsed document");
      if Bounded_Source then
         Prefix_Matches := Math_Syntax.Source (Outp.Parsed)'Length =
           Math_Syntax.Max_Source_Bytes and then
           Math_Syntax.Source (Outp.Parsed) =
             Source (Source'First ..
               Source'First + Math_Syntax.Max_Source_Bytes - 1);
      else
         Prefix_Matches := Math_Syntax.Source (Outp.Parsed) = Source;
      end if;
      Check (Prefix_Matches,
        Label & " retains source or the bounded original prefix");
      Check (Math_Macros.Scope_Depth (Shared) = Prior_Depth,
        Label & " restores macro scope depth");
      Math_Engine.Parse ("x", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready and then
        Outp.Geometry.Valid and then
        not Outp.Geometry.Commands.Is_Empty,
        Label & " is followed by a successful ordinary request");
   end Expect_Abuse_Rejection;

   procedure Test_Scope_Limit_Recovery is
      Local_Shared : aliased Math_Macros.Context;
      Opt : Math_Engine.Request;
      Outp : Math_Engine.Result;

      procedure Check_Nested_Boundary
        (Caller_Depth : Natural; Source, Label : String) is
         Nested_Shared : aliased Math_Macros.Context;
         Entry_Depth : constant Natural := Caller_Depth;
      begin
         for Index in 1 .. Caller_Depth loop
            Math_Macros.Begin_Group (Nested_Shared);
         end loop;
         Check (Math_Macros.Scope_Depth (Nested_Shared) = Entry_Depth,
           Label & " starts at caller-created depth" &
             Natural'Image (Entry_Depth));
         Math_Engine.Parse (Source, Nested_Shared'Access, Opt, Outp);
         Check (Outp.Status = Math_Engine.Parse_Error and then
           Math_Engine.Error (Outp) = "macro scope error" and then
           Math_Syntax.Source (Outp.Parsed) = Source and then
           not Math_Syntax.Is_Valid (Outp.Parsed) and then
           not Outp.Geometry.Valid and then
           Outp.Geometry.Commands.Is_Empty,
           Label & " rejects nested scope push visibly without geometry");
         Check (not Math_Macros.Is_Defined
             (Nested_Shared, "\scopeleak"),
           Label & " prevents nested gdef expansion after rejected push");
         Check (Math_Macros.Scope_Depth (Nested_Shared) = Entry_Depth,
           Label & " restores exact entry depth; actual=" &
             Natural'Image (Math_Macros.Scope_Depth (Nested_Shared)));
         Check (Math_Macros.Diagnostic (Nested_Shared) =
             Math_Macros.No_Error,
           Label & " cleanup clears scope-limit diagnostic");
         Math_Engine.Parse ("x", Nested_Shared'Access, Opt, Outp);
         Check (Outp.Status = Math_Engine.Ready and then
           Outp.Geometry.Valid and then
           not Outp.Geometry.Commands.Is_Empty and then
           Math_Macros.Scope_Depth (Nested_Shared) = Entry_Depth and then
           Math_Macros.Diagnostic (Nested_Shared) =
             Math_Macros.No_Error,
           Label & " recovers on ordinary default request at entry depth");
      end Check_Nested_Boundary;
   begin
      Check_Nested_Boundary
        (255, "\sqrt{\gdef\scopeleak{x}}",
         "caller-depth-255 root-plus-square-root argument");
      Check_Nested_Boundary
        (255, "\begin{matrix}\gdef\scopeleak{x}\end{matrix}",
         "caller-depth-255 root-plus-matrix environment");
      Check_Nested_Boundary
        (254, "\begin{CD}x\gdef\scopeleak{x}\end{CD}",
         "caller-depth-254 root-environment-plus-CD row");
      declare
         CD_Shared : aliased Math_Macros.Context;
      begin
         for Index in 1 .. 254 loop
            Math_Macros.Begin_Group (CD_Shared);
         end loop;
         Math_Engine.Parse
           ("\gdef\scopeleak{x}\begin{CD}x\end{CD}",
            CD_Shared'Access, Opt, Outp);
         Check (Outp.Status = Math_Engine.Parse_Error and then
           Math_Engine.Error (Outp) = "macro scope error" and then
           Math_Macros.Is_Defined (CD_Shared, "\scopeleak") and then
           Math_Macros.Scope_Depth (CD_Shared) = 254,
           "leading CD gdef persists before later row scope failure");
         Math_Macros.Restore_To_Depth (CD_Shared, 0);
         Math_Engine.Parse ("\scopeleak", CD_Shared'Access, Opt, Outp);
         Check (Outp.Status = Math_Engine.Ready and then
           Outp.Geometry.Valid and then
           not Outp.Geometry.Commands.Is_Empty,
           "CD failed request recovers with persistent global sentinel");
      end;
      declare
         Empty_Shared : aliased Math_Macros.Context;
      begin
         for Index in 1 .. 256 loop
            Math_Macros.Begin_Group (Empty_Shared);
         end loop;
         Check (Math_Macros.Diagnostic (Empty_Shared) =
             Math_Macros.No_Error,
           "clean empty-input boundary starts without pending diagnostic");
         Math_Engine.Parse ("", Empty_Shared'Access, Opt, Outp);
         Check (Outp.Status = Math_Engine.Parse_Error and then
           Math_Engine.Error (Outp) = "macro scope error" and then
           not Outp.Geometry.Valid and then
           Math_Macros.Scope_Depth (Empty_Shared) = 256,
           "empty default request immediately rejects root scope push");
         Math_Macros.End_Group (Empty_Shared);
         Math_Engine.Parse ("x", Empty_Shared'Access, Opt, Outp);
         Check (Outp.Status = Math_Engine.Ready and then
           Outp.Geometry.Valid and then
           not Outp.Geometry.Commands.Is_Empty and then
           Math_Macros.Diagnostic (Empty_Shared) =
             Math_Macros.No_Error,
           "empty-input admission failure recovers after caller unwind");
      end;
      declare
         Full_Shared : aliased Math_Macros.Context;
      begin
         for Index in 1 .. 256 loop
            Math_Macros.Begin_Group (Full_Shared);
         end loop;
         Check (Math_Macros.Scope_Depth (Full_Shared) = 256 and then
           Math_Macros.Diagnostic (Full_Shared) = Math_Macros.No_Error,
           "caller-created full stack starts without pending diagnostic");
         Math_Engine.Parse
           ("x", Full_Shared'Access,
            (Global_Group => True, others => <>), Outp);
         Check (Outp.Status = Math_Engine.Ready and then
           Outp.Geometry.Valid and then
           not Outp.Geometry.Commands.Is_Empty and then
           Math_Macros.Scope_Depth (Full_Shared) = 256 and then
           Math_Macros.Diagnostic (Full_Shared) = Math_Macros.No_Error,
           "full-stack Global_Group request succeeds without stack change");
         Math_Engine.Parse ("x", Full_Shared'Access, Opt, Outp);
         Check (Outp.Status = Math_Engine.Parse_Error and then
           Math_Engine.Error (Outp) = "macro scope error" and then
           Math_Syntax.Source (Outp.Parsed) = "x" and then
           not Math_Syntax.Is_Valid (Outp.Parsed) and then
           not Outp.Geometry.Valid and then
           Outp.Geometry.Commands.Is_Empty and then
           Math_Macros.Scope_Depth (Full_Shared) = 256,
           "full-stack default request rejects root scope push");
         Math_Macros.End_Group (Full_Shared);
         Check (Math_Macros.Scope_Depth (Full_Shared) = 255 and then
           Math_Macros.Diagnostic (Full_Shared) = Math_Macros.No_Error,
           "full-stack caller pop clears rejected root diagnostic");
      end;
      Math_Engine.Parse
        ("\gdef\scopeprobe{g}", Local_Shared'Access,
         (Global_Group => True, others => <>), Outp);
      Check (Outp.Status = Math_Engine.Ready and then
        Math_Macros.Is_Defined (Local_Shared, "\scopeprobe"),
        "scope recovery fixture installs global sentinel");
      for Index in 1 .. 255 loop
         Math_Macros.Begin_Group (Local_Shared);
      end loop;
      Math_Engine.Parse
        ("\def\scopeprobe{l}", Local_Shared'Access,
         (Global_Group => True, others => <>), Outp);
      Check (Outp.Status = Math_Engine.Ready and then
        Math_Macros.Scope_Depth (Local_Shared) = 255,
        "parser shadows global sentinel in caller scope 255");
      Math_Macros.Begin_Group (Local_Shared);
      Check (Math_Macros.Scope_Depth (Local_Shared) = 256,
        "caller fills scope stack to its bound");
      Math_Macros.Begin_Group (Local_Shared);
      Check (Math_Macros.Scope_Depth (Local_Shared) = 256 and then
        Math_Macros.Diagnostic (Local_Shared) = Math_Macros.Scope_Limit,
        "failed scope push records limit without a phantom frame");
      Math_Engine.Parse ("\scopeprobe", Local_Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Parse_Error and then
        Math_Engine.Error (Outp) = "macro scope error" and then
        Math_Syntax.Source (Outp.Parsed) = "\scopeprobe" and then
        not Math_Syntax.Is_Valid (Outp.Parsed) and then
        not Outp.Geometry.Valid and then
        Outp.Geometry.Commands.Is_Empty,
        "full-scope nonempty parse fails visibly without geometry");
      Math_Engine.Parse ("", Local_Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Parse_Error and then
        Math_Engine.Error (Outp) = "macro scope error" and then
        not Outp.Geometry.Valid and then
        Math_Macros.Scope_Depth (Local_Shared) = 256,
        "full-scope empty parse rejects failed scope admission");
      Math_Engine.Parse
        ("\gdef\scopeleak{x}", Local_Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Parse_Error and then
        not Math_Macros.Is_Defined (Local_Shared, "\scopeleak") and then
        Math_Macros.Scope_Depth (Local_Shared) = 256,
        "failed scope admission prevents global expansion side effects");
      Math_Macros.End_Group (Local_Shared);
      Check (Math_Macros.Scope_Depth (Local_Shared) = 255 and then
        Math_Macros.Diagnostic (Local_Shared) = Math_Macros.No_Error,
        "caller pop clears only recovered scope-limit diagnostic");
      Math_Engine.Parse ("\scopeprobe", Local_Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready and then
        Outp.Geometry.Valid and then
        not Outp.Geometry.Commands.Is_Empty,
        "default parse recovers using scoped sentinel");
      Math_Engine.Parse
        ("\scopeprobe", Local_Shared'Access,
         (Global_Group => True, others => <>), Outp);
      Check (Outp.Status = Math_Engine.Ready and then
        Outp.Geometry.Valid and then
        not Outp.Geometry.Commands.Is_Empty,
        "global-group parse recovers in same context");
      Math_Macros.Restore_To_Depth (Local_Shared, 0);
      Check (Math_Macros.Scope_Depth (Local_Shared) = 0 and then
        Math_Macros.Is_Defined (Local_Shared, "\scopeprobe") and then
        Math_Macros.Diagnostic (Local_Shared) = Math_Macros.No_Error,
        "unwinding caller scopes restores global sentinel");
      Math_Engine.Parse ("\scopeprobe", Local_Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready and then
        Outp.Geometry.Commands.Length = 1 and then
        Outp.Geometry.Commands.First_Element.Code_Point =
          Character'Pos ('g'),
        "restored global sentinel expands to its original value");
      Math_Macros.Reset (Local_Shared);
      Math_Macros.Begin_Group (Local_Shared);
      Math_Macros.Restore_To_Depth (Local_Shared, 2);
      Check (Math_Macros.Scope_Depth (Local_Shared) = 1 and then
        Math_Macros.Diagnostic (Local_Shared) =
          Math_Macros.Unbalanced_Group,
        "impossible restore records unbalanced group without phantom pop");
      Math_Macros.End_Group (Local_Shared);
      Check (Math_Macros.Scope_Depth (Local_Shared) = 0 and then
        Math_Macros.Diagnostic (Local_Shared) =
          Math_Macros.Unbalanced_Group,
        "successful pop preserves sticky unbalanced-group diagnostic");
      Math_Macros.Reset (Local_Shared);
      Check (Math_Macros.Diagnostic (Local_Shared) = Math_Macros.No_Error,
        "reset retains explicit diagnostic-clearing semantics");
   end Test_Scope_Limit_Recovery;

   procedure Test_Composed_Geometry_Recovery is
      Local_Shared : aliased Math_Macros.Context;
      Opt : Math_Engine.Request;
      Outp : Math_Engine.Result;
      At_Limit : constant String :=
        "\geometryh\geometryf\geometryb\geometrya\geometryi";
      Below_Limit : constant String :=
        "\geometryh\geometryf\geometryb\geometrya\geometryj x";
      Over_Limit : constant String :=
        "\geometryh\geometryf\geometryb\geometrya\geometryk x";
   begin
      Check (At_Limit'Length < 128 and then
        Below_Limit'Length < 128 and then Over_Limit'Length < 128,
        "composed width fixtures remain short and bounded");
      Math_Engine.Parse
        ("\gdef\geometryprobe{g}\gdef\geometrya{\kern{100em}}" &
         "\gdef\geometryb{\geometrya\geometrya}" &
         "\gdef\geometryc{\geometryb\geometryb}" &
         "\gdef\geometryd{\geometryc\geometryc}" &
         "\gdef\geometrye{\geometryd\geometryd}" &
         "\gdef\geometryf{\geometrye\geometrye}" &
         "\gdef\geometryg{\geometryf\geometryf}" &
         "\gdef\geometryh{\geometryg\geometryg}" &
         "\gdef\geometryi{\kern{84em}}" &
         "\gdef\geometryj{\kern{83em}}" &
         "\gdef\geometryk{\kern{85em}}",
         Local_Shared'Access, (Global_Group => True, others => <>), Outp);
      Check (Outp.Status = Math_Engine.Ready and then
        Math_Macros.Is_Defined (Local_Shared, "\geometryprobe") and then
        Math_Macros.Scope_Depth (Local_Shared) = 0,
        "geometry recovery fixture establishes global sentinel baseline");

      Math_Engine.Parse (At_Limit, Local_Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready and then
        Math_Syntax.Is_Valid (Outp.Parsed) and then
        Math_Semantics.Is_Valid (Outp.Meaning) and then
        Outp.Geometry.Valid and then Outp.Geometry.Width = 16_384.0 and then
        Outp.Geometry.Commands.Is_Empty,
        "individually legal kern pieces compose to exact valid limit");
      Math_Engine.Parse (Below_Limit, Local_Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready and then
        Math_Syntax.Is_Valid (Outp.Parsed) and then
        Math_Semantics.Is_Valid (Outp.Meaning) and then
        Outp.Geometry.Valid and then Outp.Geometry.Width < 16_384.0 and then
        Outp.Geometry.Commands.Length = 1 and then
        Outp.Geometry.Commands.First_Element.Kind =
          Math_Layout.Glyph_Command and then
        Outp.Geometry.Commands.First_Element.Code_Point = Character'Pos ('x'),
        "composed kern pieces plus glyph render below geometry limit");
      for Command of Outp.Geometry.Commands loop
         Check (Command.X >= 0.0,
           "short below-limit glyph has no negative coordinate");
      end loop;

      for Setting in 1 .. 2 loop
         Opt.Settings.Throw_On_Error := Setting = 1;
         for Attempt in 1 .. 2 loop
            Math_Engine.Parse
              (Over_Limit, Local_Shared'Access, Opt, Outp);
            Check (Outp.Status = Math_Engine.Layout_Error and then
              Math_Engine.Error (Outp) = "layout geometry limit exceeded" and then
              Math_Syntax.Is_Valid (Outp.Parsed) and then
              Math_Syntax.Source (Outp.Parsed) = Over_Limit and then
              Math_Semantics.Is_Valid (Outp.Meaning),
              "composed over-limit layout rejected with valid views, throw=" &
                Boolean'Image (Opt.Settings.Throw_On_Error) & " attempt=" &
                Natural'Image (Attempt));
            Check (not Outp.Geometry.Valid and then
              Outp.Geometry.Width = 0.0 and then
              Outp.Geometry.Ascent = 0.0 and then
              Outp.Geometry.Descent = 0.0 and then
              Outp.Geometry.Commands.Is_Empty,
              "layout rejection publishes empty zero-width geometry");
            Check (Math_Macros.Scope_Depth (Local_Shared) = 0 and then
              Math_Macros.Is_Defined (Local_Shared, "\geometryprobe"),
              "layout rejection preserves exact global-sentinel scope");
            Math_Engine.Parse
              ("\geometryprobe", Local_Shared'Access, Opt, Outp);
            Check (Outp.Status = Math_Engine.Ready and then
              Outp.Geometry.Valid and then
              Outp.Geometry.Commands.Length = 1 and then
              Outp.Geometry.Commands.First_Element.Code_Point =
                Character'Pos ('g') and then
              Math_Macros.Scope_Depth (Local_Shared) = 0,
              "sentinel immediately survives layout rejection");
            Math_Engine.Parse ("x", Local_Shared'Access, Opt, Outp);
            Check (Outp.Status = Math_Engine.Ready and then
              Outp.Geometry.Valid and then
              Outp.Geometry.Width < 16_384.0 and then
              Outp.Geometry.Commands.Length = 1 and then
              Outp.Geometry.Commands.First_Element.Code_Point =
                Character'Pos ('x') and then
              Math_Macros.Scope_Depth (Local_Shared) = 0,
              "default same-context request recovers after layout rejection");
         end loop;
      end loop;
   end Test_Composed_Geometry_Recovery;

   procedure Test_Abuse_Rejection_Recovery is
      use Ada.Strings.Unbounded;
      Outp : Math_Engine.Result;
      Depth_Source : Unbounded_String := Null_Unbounded_String;
      Growth_Source : Unbounded_String :=
        To_Unbounded_String ("\def\grow#1{#1#1}\grow{");
      Row_Source : Unbounded_String :=
        To_Unbounded_String ("\begin{matrix}");
      Column_Source : Unbounded_String :=
        To_Unbounded_String ("\begin{matrix}");
      Valid_Row_Source : Unbounded_String :=
        To_Unbounded_String ("\begin{matrix}");
      Valid_Column_Source : Unbounded_String :=
        To_Unbounded_String ("\begin{matrix}");
      Moderate_Nesting : Unbounded_String := Null_Unbounded_String;
      Moderate_Duplicate : Unbounded_String := Null_Unbounded_String;
      Nested_Duplication : Unbounded_String :=
        To_Unbounded_String ("\def\dup#1{#1#1}");
      Expansion_Limits : constant array (1 .. 2) of Positive :=
        (1_000, 10_000);
      Doubling_Chain : Unbounded_String :=
        To_Unbounded_String ("\def\a{x}");
      Oversized_Source : constant String :=
        (1 .. Math_Syntax.Max_Source_Bytes + 1 => 'x');
   begin
      Append (Moderate_Duplicate, "\def\dup#1{#1#1}");
      for Index in 1 .. 6 loop
         Append (Moderate_Duplicate, "\dup{");
      end loop;
      Append (Moderate_Duplicate, "x");
      for Index in 1 .. 6 loop
         Append (Moderate_Duplicate, "}");
      end loop;
      Append (Nested_Duplication, "\dup{");
      for Index in 1 .. 18 loop
         Append (Nested_Duplication, "\dup{");
      end loop;
      Append (Nested_Duplication, "x");
      for Index in 1 .. 19 loop
         Append (Nested_Duplication, "}");
      end loop;
      for Index in 1 .. 9 loop
         declare
            Letter : constant Character := Character'Val
              (Character'Pos ('a') + Index);
            Previous : constant Character := Character'Val
              (Character'Pos ('a') + Index - 1);
         begin
            Append (Doubling_Chain, "\def\" & Letter & "{\" &
              Previous & "\" & Previous & "}");
         end;
      end loop;
      Append (Doubling_Chain, "\j");
      Check (Length (Nested_Duplication) < 1_024 and then
        Length (Doubling_Chain) < 1_024,
        "exponential duplication sources stay structurally small");

      for Index in 1 .. Math_Syntax.Max_Depth + 2 loop
         Append (Depth_Source, "\sqrt{");
      end loop;
      Append (Depth_Source, "x");
      Append (Growth_Source, (1 .. 60_000 => 'x'));
      Append (Growth_Source, "}");
      for Index in 1 .. Math_Syntax.Max_Depth + 2 loop
         Append (Depth_Source, "}");
      end loop;
      for Index in 1 .. Math_Syntax.Max_Array_Rows loop
         if Index > 1 then
            Append (Valid_Row_Source, "\\");
         end if;
         Append (Valid_Row_Source, "x");
      end loop;
      Append (Valid_Row_Source, "\end{matrix}");
      for Index in 1 .. Math_Syntax.Max_Array_Columns loop
         if Index > 1 then
            Append (Valid_Column_Source, "&");
         end if;
         Append (Valid_Column_Source, "x");
      end loop;
      Append (Valid_Column_Source, "\end{matrix}");
      for Index in 1 .. 8 loop
         Append (Moderate_Nesting, "\sqrt{");
      end loop;
      Append (Moderate_Nesting, "x");
      for Index in 1 .. 8 loop
         Append (Moderate_Nesting, "}");
      end loop;
      for Index in 1 .. Math_Syntax.Max_Array_Rows + 1 loop
         if Index > 1 then
            Append (Row_Source, "\\");
         end if;
         Append (Row_Source, "x");
      end loop;
      Append (Row_Source, "\end{matrix}");
      for Index in 1 .. Math_Syntax.Max_Array_Columns + 1 loop
         if Index > 1 then
            Append (Column_Source, "&");
         end if;
         Append (Column_Source, "x");
      end loop;
      Append (Column_Source, "\end{matrix}");

      Check (Math_Syntax.Max_Array_Rows = 64 and then
        Math_Syntax.Max_Array_Columns = 64,
        "matrix boundary controls use 64 rows and columns");
      Math_Engine.Parse
        (To_String (Valid_Row_Source), Shared'Access, (others => <>), Outp);
      Check (Outp.Status = Math_Engine.Ready and then
        Math_Syntax.Is_Valid (Outp.Parsed),
        "matrix with exactly 64 rows is accepted");
      Math_Engine.Parse
        (To_String (Valid_Column_Source), Shared'Access,
         (others => <>), Outp);
      Check (Outp.Status = Math_Engine.Ready and then
        Math_Syntax.Is_Valid (Outp.Parsed),
        "matrix with exactly 64 columns is accepted");
      Math_Engine.Parse
        (To_String (Moderate_Nesting), Shared'Access,
         (others => <>), Outp);
      Check (Outp.Status = Math_Engine.Ready and then
        Math_Syntax.Is_Valid (Outp.Parsed),
        "eight-level nested square roots are accepted");
      Math_Engine.Parse
        (To_String (Moderate_Duplicate), Shared'Access,
         (others => <>), Outp);
      Check (Outp.Status = Math_Engine.Ready and then
        Outp.Geometry.Valid and then
        Outp.Geometry.Commands.Length = 64,
        "six-level nested duplication renders 64 glyphs");
      declare
         X_Glyphs : Natural := 0;
      begin
         for Command of Outp.Geometry.Commands loop
            if Command.Kind = Math_Layout.Glyph_Command and then
              Command.Code_Point = Character'Pos ('x')
            then
               X_Glyphs := X_Glyphs + 1;
            end if;
         end loop;
         Check (X_Glyphs = 64,
           "moderate nested duplication contains 64 x glyphs");
      end;

      for Attempt in 1 .. 2 loop
         Expect_Abuse_Rejection
           ("\def\local{x}\def\cycle{\cycle}\cycle",
            "macro expansion: EXPANSION_LIMIT",
            "recursive macro cycle " & Natural'Image (Attempt));
         Check (not Math_Macros.Is_Defined (Shared, "\local"),
           "cycle rejection rolls back local macro definition");
         Math_Engine.Parse ("\saved", Shared'Access,
           (others => <>), Outp);
         Check (Outp.Status = Math_Engine.Ready and then
           Outp.Geometry.Valid and then
           not Outp.Geometry.Commands.Is_Empty,
           "prior global macro remains usable after cycle rejection");
         Expect_Abuse_Rejection
           (To_String (Growth_Source),
            "macro expansion: TOKEN_LIMIT",
            "single-pass macro argument duplication " &
              Natural'Image (Attempt));
         for Limit of Expansion_Limits loop
            declare
               Opt : Math_Engine.Request;
               Result : Math_Engine.Result;
            begin
               Opt.Settings.Max_Expand := Limit;
               Math_Engine.Parse
                 (To_String (Nested_Duplication), Shared'Access,
                  Opt, Result);
               Check (Result.Status = Math_Engine.Parse_Error and then
                 Ada.Strings.Fixed.Index
                   (Math_Engine.Error (Result),
                    "macro expansion: EXPANSION_LIMIT") > 0 and then
                 not Result.Geometry.Valid and then
                 Result.Geometry.Commands.Is_Empty,
                 "nested duplication rejected at expansion limit" &
                   Natural'Image (Limit));
               Check (Math_Syntax.Source (Result.Parsed) =
                   To_String (Nested_Duplication) and then
                 not Math_Syntax.Is_Valid (Result.Parsed) and then
                 Math_Macros.Scope_Depth (Shared) = 0,
                 "nested duplication rejection preserves source and scope");
               Math_Engine.Parse ("\saved", Shared'Access, Opt, Result);
               Check (Result.Status = Math_Engine.Ready and then
                 Result.Geometry.Valid and then
                 not Result.Geometry.Commands.Is_Empty,
                 "global sentinel survives nested duplication rejection");
               Math_Engine.Parse ("x", Shared'Access, Opt, Result);
               Check (Result.Status = Math_Engine.Ready and then
                 Result.Geometry.Valid and then
                 not Result.Geometry.Commands.Is_Empty,
                 "same-context request recovers after nested duplication");
            end;
         end loop;
         declare
            Opt : Math_Engine.Request;
            Result : Math_Engine.Result;
         begin
            Opt.Settings.Max_Expand := 1_000;
            Math_Engine.Parse
              (To_String (Doubling_Chain), Shared'Access, Opt, Result);
            Check (Result.Status = Math_Engine.Parse_Error and then
              Ada.Strings.Fixed.Index
                (Math_Engine.Error (Result),
                 "macro expansion: EXPANSION_LIMIT") > 0 and then
              not Result.Geometry.Valid and then
              Result.Geometry.Commands.Is_Empty,
              "nine-level doubling chain hits 1000 invocation limit");
            Math_Engine.Parse ("\saved", Shared'Access, Opt, Result);
            Check (Result.Status = Math_Engine.Ready and then
              Result.Geometry.Valid and then
              not Result.Geometry.Commands.Is_Empty,
              "global sentinel immediately survives doubling rejection");
            Math_Engine.Parse ("x", Shared'Access, Opt, Result);
            Check (Result.Status = Math_Engine.Ready and then
              Result.Geometry.Valid and then
              not Result.Geometry.Commands.Is_Empty,
              "default request immediately recovers from doubling rejection");
            Opt.Settings.Max_Expand := 10_000;
            Math_Engine.Parse
              (To_String (Doubling_Chain), Shared'Access, Opt, Result);
            Check (Result.Status = Math_Engine.Ready and then
              Result.Geometry.Valid and then
              Result.Geometry.Commands.Length = 512,
              "nine-level doubling chain renders 512 commands at 10000");
            declare
               Glyphs : Natural := 0;
            begin
               for Command of Result.Geometry.Commands loop
                  if Command.Kind = Math_Layout.Glyph_Command and then
                    Command.Code_Point = Character'Pos ('x')
                  then
                     Glyphs := Glyphs + 1;
                  end if;
               end loop;
               Check (Glyphs = 512,
                 "nine-level doubling chain emits 512 x glyph commands");
            end;
         end;
         Expect_Abuse_Rejection
           (To_String (Depth_Source), "nesting depth exceeded",
            "excessive parse depth " & Natural'Image (Attempt));
         Expect_Abuse_Rejection
           (To_String (Row_Source), "array row limit exceeded",
            "excessive array rows " & Natural'Image (Attempt));
         Expect_Abuse_Rejection
           (To_String (Column_Source), "array column limit exceeded",
            "excessive array columns " & Natural'Image (Attempt));
         Expect_Abuse_Rejection
           ("x+" & (1 .. Math_Syntax.Max_Nodes => 'x'),
            "node limit exceeded",
            "excessive AST nodes " & Natural'Image (Attempt));
         Expect_Abuse_Rejection
           ("\kern{16385em}", "dimension exceeds bounded geometry",
            "excessive source dimension " & Natural'Image (Attempt));
         Expect_Abuse_Rejection
           (Oversized_Source, "source byte limit exceeded",
            "oversized source " & Natural'Image (Attempt), True);
      end loop;
   end Test_Abuse_Rejection_Recovery;

   procedure Test_Foreground_Work_Control is
      Mixed_Source : constant String :=
        "a+\textcolor{blue}{b}+c+d+e+f+g+h+i+j+k+l+m+n+o+p+q+r+s+t";
      Explicit_Source : constant String := "\color{blue}abcdefghijklmnop";
      Repeated_Source : constant String := (1 .. 512 => 'x');
      Blue : constant Math_Model.Color_Value :=
        (Red => 0.0, Green => 0.0, Blue => 1.0, Alpha => 1.0);
      Red : constant Math_Model.Color_Value :=
        (Red => 1.0, Green => 0.0, Blue => 0.0, Alpha => 1.0);

      procedure Test_Direct_Box_Application is
         Item : Math_Layout.Box;
         Empty : Math_Layout.Box;
         First : Math_Layout.Draw_Command;
         Second : Math_Layout.Draw_Command;
         Third : Math_Layout.Draw_Command;
         Segment : Math_Paths.Segment :=
           (Kind => Math_Paths.Move_To,
            First => (X => 1.25, Y => -2.5),
            Second => (X => 0.0, Y => 0.0),
            Third => (X => 0.0, Y => 0.0));
         Cancel_Work : aliased Budget_Context :=
           (Math_Work_Control.Context with
            Stop_At => 2,
            Reason => Math_Work_Control.Cancel_Requested);
         Deadline_Work : aliased Budget_Context :=
           (Math_Work_Control.Context with
            Stop_At => 1,
            Reason => Math_Work_Control.Deadline_Reached);
         Stopped : Boolean;
      begin
         Poll_Count := 0;
         Math_Layout.Apply_Foreground
           (Empty, Red, Deadline_Work'Unchecked_Access);
         Check (Poll_Count = 0 and then Empty.Commands.Is_Empty,
           "empty box performs no command polls or mutation");
         Item.Valid := True;
         Item.Width := 8.5;
         First.X := 1.0;
         First.Y := 2.0;
         First.Scale := 1.5;
         First.Has_Clip := True;
         First.Clip_X := -1.0;
         First.Clip_Y := 2.25;
         First.Clip_W := 3.5;
         First.Clip_H := 4.75;
         First.Has_Shadow := True;
         First.Shadow_X := 0.25;
         First.Shadow_Y := -0.5;
         First.Shadow_Blur_Px := 1.75;
         First.Path_Data.Append (Segment);
         Item.Commands.Append (First);

         Second.Has_Color := True;
         Second.Red := Blue.Red;
         Second.Green := Blue.Green;
         Second.Blue := Blue.Blue;
         Second.Alpha := Blue.Alpha;
         Second.X := 5.0;
         Second.Y := -3.0;
         Second.Scale := 0.75;
         Second.Text_Run_Text :=
           Ada.Strings.Unbounded.To_Unbounded_String ("payload");
         Item.Commands.Append (Second);

         Third.X := 9.0;
         Third.Y := 10.0;
         Third.Scale := 2.0;
         Item.Commands.Append (Third);

         Poll_Count := 0;
         Math_Layout.Apply_Foreground (Item, Red);
         Check (Poll_Count = 0,
           "empty-work fallback assignment performs no polls");
         Check (Item.Valid and then Item.Commands.Length = 3,
           "direct fallback preserves valid geometry and command count");
         Check (Item.Commands (1).Has_Color and then
           Item.Commands (1).Red = Red.Red and then
           Item.Commands (2).Red = Blue.Red and then
           Item.Commands (3).Red = Red.Red,
           "fallback colors uncolored commands and preserves explicit blue");
         Check (Item.Commands (1).X = 1.0 and then
           Item.Commands (1).Y = 2.0 and then
           Item.Commands (1).Scale = 1.5 and then
           Item.Commands (1).Clip_X = -1.0 and then
           Item.Commands (1).Clip_Y = 2.25 and then
           Item.Commands (1).Clip_W = 3.5 and then
           Item.Commands (1).Clip_H = 4.75 and then
           Item.Commands (1).Shadow_X = 0.25 and then
           Item.Commands (1).Shadow_Y = -0.5 and then
           Item.Commands (1).Shadow_Blur_Px = 1.75 and then
           Item.Commands (1).Path_Data.Length = 1 and then
           Item.Commands (1).Path_Data (1) = Segment,
           "fallback preserves first-command path and geometry payload");
         Check (Ada.Strings.Unbounded.To_String
             (Item.Commands (2).Text_Run_Text) = "payload" and then
           Item.Commands (2).X = 5.0 and then
           Item.Commands (2).Y = -3.0 and then
           Item.Commands (2).Scale = 0.75 and then
           Item.Commands (3).X = 9.0 and then
           Item.Commands (3).Y = 10.0 and then
           Item.Commands (3).Scale = 2.0,
           "fallback preserves text payload and later geometry");

         Poll_Count := 0;
         Math_Layout.Apply_Foreground (Item, Blue);
         Math_Layout.Apply_Foreground (Item, Red);
         Check (Poll_Count = 0 and then Item.Valid and then
           Item.Commands (1).Red = Red.Red and then
           Item.Commands (2).Red = Blue.Red and then
           Item.Commands (3).Red = Red.Red,
           "successful repeats are idempotent and preserve assigned colors");

         --  Start fresh: first and third must still need fallback color.
         Item.Commands.Replace_Element (1, First);
         Item.Commands.Replace_Element (3, Third);
         Poll_Count := 0;
         Stopped := False;
         begin
            Math_Layout.Apply_Foreground
              (Item, Red, Cancel_Work'Unchecked_Access);
         exception
            when Math_Work_Control.Stop_Requested =>
               Stopped := True;
         end;
         Check (Stopped and then Poll_Count = 2,
           "cancel polls before second command");
         Check (Item.Valid and then Item.Commands (1).Has_Color and then
           Item.Commands (1).Red = Red.Red and then
           Item.Commands (2).Blue = Blue.Blue and then
           not Item.Commands (3).Has_Color,
           "cancel colors only earlier command and leaves later one untouched");
         Item.Commands.Append (Third);
         Item.Commands.Delete_Last;
         Check (Item.Commands.Length = 3,
           "stopped helper releases scoped references before container mutation");
         Item.Commands.Replace_Element (1, First);

         Poll_Count := 0;
         Stopped := False;
         begin
            Math_Layout.Apply_Foreground
              (Item, (Red => 0.0, Green => 1.0, Blue => 0.0, Alpha => 1.0),
               Deadline_Work'Unchecked_Access);
         exception
            when Math_Work_Control.Deadline_Expired =>
               Stopped := True;
         end;
         Check (Stopped and then Poll_Count = 1,
           "deadline polls before first command");
         Check (Item.Valid and then not Item.Commands (1).Has_Color and then
           Item.Commands (2).Blue = Blue.Blue and then
           not Item.Commands (3).Has_Color,
           "deadline before first command leaves fresh box unchanged");
      end Test_Direct_Box_Application;

      procedure Check_Source (Source, Label : String) is
         Opt : Math_Engine.Request;
         Outp : Math_Engine.Result;
         Baseline_Polls : Natural;
         Command_Count : Natural;
         Prior_Depth : constant Natural := Math_Macros.Scope_Depth (Shared);
         Cancel_Work : aliased Budget_Context :=
           (Math_Work_Control.Context with
            Stop_At => Natural'Last,
            Reason => Math_Work_Control.Cancel_Requested);
         Deadline_Work : aliased Budget_Context :=
           (Math_Work_Control.Context with
            Stop_At => Natural'Last,
            Reason => Math_Work_Control.Deadline_Reached);
         Stopped : Boolean;
      begin
         Opt.Work := Cancel_Work'Unchecked_Access;
         Poll_Count := 0;
         Math_Engine.Parse (Source, Shared'Access, Opt, Outp);
         Baseline_Polls := Poll_Count;
         Command_Count := Natural (Outp.Geometry.Commands.Length);
         Check (Outp.Status = Math_Engine.Ready and then
           Outp.Geometry.Valid and then Command_Count > 0,
           Label & " uncolored calibration request is ready");

         Opt.Foreground_Set := True;
         Opt.Foreground :=
           (Red => Blue.Red, Green => Blue.Green,
            Blue => Blue.Blue, Alpha => Blue.Alpha);
         Poll_Count := 0;
         Math_Engine.Parse (Source, Shared'Access, Opt, Outp);
         Check (Outp.Status = Math_Engine.Ready and then
           Outp.Geometry.Valid,
           Label & " foreground request remains ready");
         Check (Poll_Count >= Baseline_Polls and then
           Poll_Count - Baseline_Polls = Command_Count,
           Label & " foreground poll delta equals command count; delta=" &
             Natural'Image (Poll_Count - Natural'Min
               (Poll_Count, Baseline_Polls)) & " commands=" &
             Natural'Image (Command_Count));

         Cancel_Work.Stop_At := Baseline_Polls + 2;
         Opt.Work := Cancel_Work'Unchecked_Access;
         Poll_Count := 0;
         Stopped := False;
         begin
            Math_Engine.Parse (Source, Shared'Access, Opt, Outp);
         exception
            when Math_Work_Control.Stop_Requested =>
               Stopped := True;
         end;
         Check (Stopped,
           Label & " foreground cancellation propagates");
         Check (Math_Macros.Scope_Depth (Shared) = Prior_Depth,
           Label & " cancellation preserves macro scope");
         Cancel_Work.Stop_At := Natural'Last;
         Cancel_Work.Reason := Math_Work_Control.Continue_Work;
         Poll_Count := 0;
         Math_Engine.Parse ("x", Shared'Access, Opt, Outp);
         Check (Outp.Status = Math_Engine.Ready and then
           Outp.Geometry.Valid and then
           Math_Macros.Scope_Depth (Shared) = Prior_Depth,
           Label & " cancellation context recovers on next request");

         Deadline_Work.Stop_At := Baseline_Polls + 2;
         Deadline_Work.Reason := Math_Work_Control.Deadline_Reached;
         Opt.Work := Deadline_Work'Unchecked_Access;
         Poll_Count := 0;
         Stopped := False;
         begin
            Math_Engine.Parse (Source, Shared'Access, Opt, Outp);
         exception
            when Math_Work_Control.Deadline_Expired =>
               Stopped := True;
         end;
         Check (Stopped,
           Label & " foreground deadline propagates distinctly");
         Check (Math_Macros.Scope_Depth (Shared) = Prior_Depth,
           Label & " deadline preserves macro scope");
         Deadline_Work.Stop_At := Natural'Last;
         Deadline_Work.Reason := Math_Work_Control.Continue_Work;
         Poll_Count := 0;
         Math_Engine.Parse ("x", Shared'Access, Opt, Outp);
         Check (Outp.Status = Math_Engine.Ready and then
           Outp.Geometry.Valid and then
           Math_Macros.Scope_Depth (Shared) = Prior_Depth,
           Label & " deadline context recovers on next request");
      end Check_Source;
   begin
      Test_Direct_Box_Application;
      Check_Source (Mixed_Source, "mixed explicit-blue");
      Check_Source (Explicit_Source, "all explicit-blue");
      Check_Source (Repeated_Source, "512 repeated glyphs");
   end Test_Foreground_Work_Control;

   procedure Test_Seeded_Stop_Recovery is
      Seed : constant Interfaces.Unsigned_32 := 16#7374_6F70#;
      State : Interfaces.Unsigned_32 := Seed;
      Local_Name : constant String := "\fuzzlocal";
      Saved_Name : constant String := "\fuzzsaved";
      Case_Count : constant Positive := 64;
      Opt : Math_Engine.Request;
      Outp : Math_Engine.Result;
      Baseline : Natural;
      Target : Natural;
      Source : Ada.Strings.Unbounded.Unbounded_String;
      Label : Ada.Strings.Unbounded.Unbounded_String;
      Cancel_Work : aliased Budget_Context;
      Deadline_Work : aliased Budget_Context;

      function Next_Value return Interfaces.Unsigned_32 is
      begin
         State := State xor Interfaces.Shift_Left (State, 13);
         State := State xor Interfaces.Shift_Right (State, 17);
         State := State xor Interfaces.Shift_Left (State, 5);
         return State;
      end Next_Value;

      function Make_Source (Case_Number : Positive) return String is
         Choice : constant Natural :=
           Natural (Next_Value mod Interfaces.Unsigned_32 (4));
         Atom : constant Character :=
           Character'Val (Character'Pos ('a') + Case_Number mod 26);
         Numerator : constant String :=
           (if Case_Number mod 2 = 0 then "a+b" else "x-y");
         Denominator : constant String :=
           (if Case_Number mod 3 = 0 then "c+d" else "m+n");
         Fragment : constant String :=
           (case Choice is
               when 0 => "\sqrt{\frac{" & Numerator &
                 "}{" & Denominator & "}}+\fuzzlocal",
               when 1 => "\textcolor{blue}{\fuzzlocal+" &
                 Atom & "}+\frac{p}{q}",
               when 2 => "\begin{matrix}\fuzzlocal&" &
                 Atom & "\\x&y\end{matrix}",
               when others => "\hat{\fuzzlocal}+\sqrt{" &
                 Atom & "}");
      begin
         return "\def\fuzzlocal{" & Atom & "}" & Fragment;
      end Make_Source;

      procedure Run_Stop (Reason : Math_Work_Control.Stop_Reason) is
         Context : Budget_Context_Access;
         Expected_Cancel : constant Boolean :=
           Reason = Math_Work_Control.Cancel_Requested;
         Got_Cancel : Boolean := False;
         Got_Deadline : Boolean := False;
         Tag : constant String :=
           (if Expected_Cancel then "cancel" else "deadline");
      begin
         if Expected_Cancel then
            Context := Cancel_Work'Unchecked_Access;
         else
            Context := Deadline_Work'Unchecked_Access;
         end if;
         Context.Stop_At := Target;
         Context.Reason := Reason;
         if Expected_Cancel then
            Opt.Work := Cancel_Work'Unchecked_Access;
         else
            Opt.Work := Deadline_Work'Unchecked_Access;
         end if;
         Poll_Count := 0;
         begin
            Math_Engine.Parse
              (Ada.Strings.Unbounded.To_String (Source),
               Shared'Access, Opt, Outp);
            Check (False, Ada.Strings.Unbounded.To_String (Label) &
              " poll=" & Natural'Image (Target) & " " & Tag &
              " unexpectedly completed");
         exception
            when Math_Work_Control.Stop_Requested =>
               Got_Cancel := True;
            when Math_Work_Control.Deadline_Expired =>
               Got_Deadline := True;
            when Error : others =>
               Check (False, Ada.Strings.Unbounded.To_String (Label) &
                 " poll=" & Natural'Image (Target) & " " & Tag &
                 " wrong exception=" &
                 Ada.Exceptions.Exception_Name (Error));
         end;
         if Expected_Cancel then
            Check (Got_Cancel and then not Got_Deadline,
              Ada.Strings.Unbounded.To_String (Label) &
              " poll=" & Natural'Image (Target) &
              " cancellation exception identity");
         else
            Check (Got_Deadline and then not Got_Cancel,
              Ada.Strings.Unbounded.To_String (Label) &
              " poll=" & Natural'Image (Target) &
              " deadline exception identity");
         end if;
         Check (Math_Macros.Scope_Depth (Shared) = 0 and then
           Math_Macros.Diagnostic (Shared) = Math_Macros.No_Error and then
           not Math_Macros.Is_Defined (Shared, Local_Name) and then
           Math_Macros.Is_Defined (Shared, Saved_Name),
           Ada.Strings.Unbounded.To_String (Label) & " poll=" &
           Natural'Image (Target) & " " & Tag &
           " restores local scope and global sentinel");
         Context.Stop_At := Natural'Last;
         Context.Reason := Math_Work_Control.Continue_Work;
         Opt.Work := null;
         Math_Engine.Parse ("\fuzzsaved+x", Shared'Access, Opt, Outp);
         Check (Outp.Status = Math_Engine.Ready and then
           Outp.Geometry.Valid and then
           Outp.Geometry.Commands.Length = 3 and then
           Outp.Geometry.Commands (1).Code_Point = Character'Pos ('z') and then
           Outp.Geometry.Commands (2).Code_Point = Character'Pos ('+') and then
           Outp.Geometry.Commands (3).Code_Point = Character'Pos ('x') and then
           Math_Macros.Scope_Depth (Shared) = 0 and then
           Math_Macros.Diagnostic (Shared) = Math_Macros.No_Error and then
           not Math_Macros.Is_Defined (Shared, Local_Name) and then
           Math_Macros.Is_Defined (Shared, Saved_Name),
           Ada.Strings.Unbounded.To_String (Label) & " poll=" &
           Natural'Image (Target) & " " & Tag &
           " null-Work recovery renders exact sentinel and ordinary glyphs");
      end Run_Stop;
   begin
      Math_Macros.Reset (Shared);
      Opt.Work := null;
      Math_Engine.Parse ("\gdef\fuzzsaved{z}", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready and then
        Math_Macros.Is_Defined (Shared, Saved_Name) and then
        Math_Macros.Scope_Depth (Shared) = 0,
        "seeded stop harness installs shared global sentinel");
      for Case_Index in 1 .. Case_Count loop
         Ada.Strings.Unbounded.Set_Unbounded_String
           (Source, Make_Source (Case_Index));
         Ada.Strings.Unbounded.Set_Unbounded_String
           (Label, "seed=0x73746f70 case=" &
             Positive'Image (Case_Index));
         Cancel_Work.Stop_At := Natural'Last;
         Cancel_Work.Reason := Math_Work_Control.Continue_Work;
         Opt.Work := Cancel_Work'Unchecked_Access;
         Poll_Count := 0;
         Math_Engine.Parse
           (Ada.Strings.Unbounded.To_String (Source),
            Shared'Access, Opt, Outp);
         Baseline := Poll_Count;
         Check (Outp.Status = Math_Engine.Ready and then
           Outp.Geometry.Valid and then Baseline > 0 and then
           Math_Macros.Scope_Depth (Shared) = 0 and then
           Math_Macros.Diagnostic (Shared) = Math_Macros.No_Error and then
           not Math_Macros.Is_Defined (Shared, Local_Name) and then
           Math_Macros.Is_Defined (Shared, Saved_Name),
           Ada.Strings.Unbounded.To_String (Label) &
           " uncancelled baseline ready; source=" &
           Ada.Strings.Unbounded.To_String (Source));
         Target := 1 + Natural (Next_Value mod
           Interfaces.Unsigned_32 (Baseline));
         Ada.Text_IO.Put_Line
           ("SEEDED_STOP case=" & Positive'Image (Case_Index) &
            " baseline_polls=" & Natural'Image (Baseline) &
            " target_poll=" & Natural'Image (Target) & " source=" &
            Ada.Strings.Unbounded.To_String (Source));
         Run_Stop (Math_Work_Control.Cancel_Requested);
         Run_Stop (Math_Work_Control.Deadline_Reached);
      end loop;
      Ada.Text_IO.Put_Line
        ("SEEDED_STOPS seed=0x73746f70 cases=64 injections=128");
   end Test_Seeded_Stop_Recovery;

   procedure Test_Array_Rule_Work is
      use Ada.Strings.Unbounded;
      Counts : constant array (Positive range 1 .. 4) of Positive :=
        (1, 16, 256, 1_024);
      Parsed : Math_Syntax.Document;
      Reference : Math_Layout.Box;
      Measured : Math_Layout.Box;
      Source : Unbounded_String := Null_Unbounded_String;
      Context : aliased Budget_Context;
      Root_Value : Math_Syntax.Node;
      Array_Value : Math_Syntax.Node;
      Rules : Math_Model.Array_Rule_Vectors.Vector;
      Solid_Count : Natural;
      Dashed_Count : Natural;
      Glyph_Count : Natural;
      Baseline_Polls : Natural;
      Stopped : Boolean;
      Stop_Reasons : constant array (Positive range 1 .. 2) of
        Math_Work_Control.Stop_Reason :=
          (Math_Work_Control.Cancel_Requested,
           Math_Work_Control.Deadline_Reached);

      procedure Make_Source (Rule_Count : Positive) is
      begin
         Set_Unbounded_String (Source, "\begin{array}{c}");
         for Index in 1 .. Rule_Count loop
            Append (Source,
              (if Index mod 2 = 0 then "\hdashline " else "\hline "));
         end loop;
         Append (Source, "x\\y\end{array}");
      end Make_Source;

      procedure Check_Mixed_Boundaries is
         Source_Text : constant String :=
           "\begin{array}{c}\hline a\\\hdashline b\\\hline\hdashline c\end{array}";
      begin
         Parsed := Math_Syntax.Parse (Source_Text);
         Check (Math_Syntax.Is_Valid (Parsed),
           "mixed-boundary array fixture parses: " &
             Math_Syntax.Error (Parsed));
         if not Math_Syntax.Is_Valid (Parsed) then
            return;
         end if;

         Root_Value := Math_Syntax.Element
           (Parsed, Positive (Math_Syntax.Root (Parsed)));
         Array_Value := Math_Syntax.Element
           (Parsed, Positive (Root_Value.First));
         Rules := Array_Value.Array_Rules;
         Check (Rules.Length = 4,
           "mixed-boundary metadata retains four rules");
         if Rules.Length = 4 then
            Check (Rules (1).Boundary = 0 and then
              Rules (1).Kind = Math_Model.Solid_Array_Rule,
              "first row opening rule is solid at boundary zero");
            Check (Rules (2).Boundary = 1 and then
              Rules (2).Kind = Math_Model.Dashed_Array_Rule,
              "second row opening rule is dashed at boundary one");
            Check (Rules (3).Boundary = 2 and then
              Rules (3).Kind = Math_Model.Solid_Array_Rule,
              "third row opening rule is solid at boundary two");
            Check (Rules (4).Boundary = 2 and then
              Rules (4).Kind = Math_Model.Dashed_Array_Rule,
              "third row keeps ordered double rule at boundary two");
         end if;

         Reference := Math_Layout.Build
           (Parsed, Math_Layout.Text_Style);
         Check (Reference.Valid,
           "mixed-boundary unpolled geometry is valid");
         Context.Stop_At := Natural'Last;
         Context.Reason := Math_Work_Control.Continue_Work;
         Poll_Count := 0;
         Measured := Math_Layout.Build
           (Parsed, Math_Layout.Text_Style,
            Context'Unchecked_Access);
         Check (Measured.Valid and then Measured = Reference,
           "mixed-boundary polled geometry is exact");
         Ada.Text_IO.Put_Line
           ("ARRAY_RULE_BOUNDARIES rules=4 boundaries=0,1,2 polls=" &
            Natural'Image (Poll_Count));
      end Check_Mixed_Boundaries;

      procedure Check_Size (Rule_Count : Positive) is
         Source_Text : constant String := To_String (Source);
      begin
         Parsed := Math_Syntax.Parse (Source_Text);
         Check (Math_Syntax.Is_Valid (Parsed),
           "array work fixture parses N=" & Positive'Image (Rule_Count) &
             " error=" & Math_Syntax.Error (Parsed));
         if not Math_Syntax.Is_Valid (Parsed) then
            return;
         end if;
         Root_Value := Math_Syntax.Element
           (Parsed, Positive (Math_Syntax.Root (Parsed)));
         Array_Value := Math_Syntax.Element
           (Parsed, Positive (Root_Value.First));
         Rules := Array_Value.Array_Rules;
         Check (Rules.Length = Ada.Containers.Count_Type (Rule_Count),
           "array metadata retains all rules N=" &
             Positive'Image (Rule_Count));
         Solid_Count := 0;
         Dashed_Count := 0;
         for Index in 1 .. Rule_Count loop
            Check (Rules (Index).Boundary = 0,
              "array rule remains at boundary zero N=" &
                Positive'Image (Rule_Count));
            if Index mod 2 = 0 then
               Check (Rules (Index).Kind = Math_Model.Dashed_Array_Rule,
                 "array metadata preserves dashed order");
               Dashed_Count := Dashed_Count + 1;
            else
               Check (Rules (Index).Kind = Math_Model.Solid_Array_Rule,
                 "array metadata preserves solid order");
               Solid_Count := Solid_Count + 1;
            end if;
         end loop;
         Check (Solid_Count + Dashed_Count = Rule_Count,
           "mixed rule metadata counts are preserved");

         Reference := Math_Layout.Build
           (Parsed, Math_Layout.Text_Style);
         Check (Reference.Valid,
           "unpolled array geometry is valid N=" &
             Positive'Image (Rule_Count));
         Glyph_Count := 0;
         for Command of Reference.Commands loop
            if Command.Kind = Math_Layout.Glyph_Command then
               Glyph_Count := Glyph_Count + 1;
            end if;
         end loop;
         Check (Glyph_Count = 2,
           "array retains exactly x and y glyphs N=" &
             Positive'Image (Rule_Count));

         Context.Stop_At := Natural'Last;
         Context.Reason := Math_Work_Control.Continue_Work;
         Poll_Count := 0;
         Measured := Math_Layout.Build
           (Parsed, Math_Layout.Text_Style,
            Context'Unchecked_Access);
         Baseline_Polls := Poll_Count;
         Check (Measured.Valid and then Measured = Reference,
           "polled array geometry is exact N=" &
             Positive'Image (Rule_Count));
         --  Keep the current metadata-poll relationship regression-visible;
         --  this is not an independent geometry-work oracle.
         Check (Baseline_Polls <= 21 * Rule_Count + 128 and then
           (if Rule_Count >= 256 then
              Baseline_Polls >= 20 * Rule_Count
            else
              Baseline_Polls >= 6 * Rule_Count),
           "array metadata poll envelope N=" &
             Positive'Image (Rule_Count) & " polls=" &
             Natural'Image (Baseline_Polls));
         Ada.Text_IO.Put_Line
           ("ARRAY_RULE_WORK rules=" & Positive'Image (Rule_Count) &
            " polls=" & Natural'Image (Baseline_Polls));

         for Reason of Stop_Reasons loop
            Context.Stop_At := Natural'Max (1, Baseline_Polls / 2);
            Context.Reason := Reason;
            Poll_Count := 0;
            Stopped := False;
            begin
               Measured := Math_Layout.Build
                 (Parsed, Math_Layout.Text_Style,
                  Context'Unchecked_Access);
               Check (False, "array stop request propagates");
            exception
               when Math_Work_Control.Stop_Requested =>
                  Stopped :=
                    Reason = Math_Work_Control.Cancel_Requested;
               when Math_Work_Control.Deadline_Expired =>
                  Stopped :=
                    Reason = Math_Work_Control.Deadline_Reached;
            end;
            Check (Stopped,
              "array cancellation/deadline identity is preserved");
            Context.Stop_At := Natural'Last;
            Context.Reason := Math_Work_Control.Continue_Work;
            Poll_Count := 0;
            Measured := Math_Layout.Build
              (Parsed, Math_Layout.Text_Style);
            Check (Measured.Valid and then Measured = Reference,
              "array geometry recovers exactly after stop");
         end loop;
      end Check_Size;
   begin
      Check_Mixed_Boundaries;
      for Rule_Count of Counts loop
         Make_Source (Rule_Count);
         Check_Size (Rule_Count);
      end loop;
   end Test_Array_Rule_Work;

   procedure Run is
      Opt : Math_Engine.Request;
      Outp : Math_Engine.Result;
      Bad_Source : constant String := "\not-a-command";
   begin
      Test_Array_Rule_Work;
      Test_Foreground_Work_Control;
      Test_Seeded_Stop_Recovery;
      Test_Composed_Geometry_Recovery;
      Math_Engine.Parse ("x+\frac{a}{b}", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready, "default request ready");
      Check (Math_Syntax.Is_Valid (Outp.Parsed) and
        Math_Layout.Box (Outp.Geometry).Valid, "syntax and layout valid");
      Check (Math_Semantics.Is_Valid (Outp.Meaning),
        "semantics derive from parsed AST");
      Check (Math_Syntax.Source (Outp.Parsed) = "x+\frac{a}{b}" and
        Math_Semantics.Source (Outp.Meaning) = "x+\frac{a}{b}",
        "source retained across views");
      Check (not Opt.Settings.Trust,
        "native default trust policy is false");
      Opt.Settings.Trust := True;
      Math_Engine.Parse ("x", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Unsupported_Settings and then
        Math_Engine.Error (Outp) = "trust is not supported by native math",
        "trust=true is rejected by the native untrusted policy");
      Opt := (others => <>);
      Check (not Opt.Settings.Color_Is_Text_Color,
        "colorIsTextColor defaults to false");
      Math_Engine.Parse ("\color{red}x+y", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready and then
        Outp.Geometry.Valid and then Outp.Geometry.Commands.Length > 0,
        "default color command produces nonempty valid geometry");
      declare
         Root_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Math_Syntax.Root (Outp.Parsed)));
         Color_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Root_Node.First));
         Red_Glyphs : Natural := 0;
      begin
         declare
            Expression_Row : constant Math_Syntax.Node := Math_Syntax.Element
              (Outp.Parsed, Positive (Color_Node.First));
            First_Atom : constant Math_Syntax.Node := Math_Syntax.Element
              (Outp.Parsed, Positive (Expression_Row.First));
            Binary_Atom : constant Math_Syntax.Node := Math_Syntax.Element
              (Outp.Parsed, Positive (First_Atom.Next));
            Last_Atom : constant Math_Syntax.Node := Math_Syntax.Element
              (Outp.Parsed, Positive (Binary_Atom.Next));
         begin
            Check (Color_Node.Kind = Math_Model.Color_Node and then
              Expression_Row.Kind = Math_Model.Row_Node and then
              First_Atom.Code_Point = Character'Pos ('x'),
              "default color AST wraps initial expression");
            Check (Binary_Atom.Code_Point = Character'Pos ('+'),
              "default color AST includes subsequent binary atom");
            Check (Last_Atom.Code_Point = Character'Pos ('y'),
              "default color AST includes subsequent ordinary atom");
         end;
         for Command of Outp.Geometry.Commands loop
            if Command.Kind = Math_Layout.Glyph_Command and then
              Command.Has_Color and then Command.Red = 1.0 and then
              Command.Green = 0.0 and then Command.Blue = 0.0
            then
               Red_Glyphs := Red_Glyphs + 1;
            end if;
         end loop;
         Check (Red_Glyphs = 3,
           "default color command colors all expression glyphs");
      end;
      Opt.Settings.Color_Is_Text_Color := True;
      Math_Engine.Parse ("\color{red}x+y", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready and then
        Outp.Geometry.Valid and then Outp.Geometry.Commands.Length > 0,
        "text-color compatibility request has nonempty geometry");
      declare
         Root_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Math_Syntax.Root (Outp.Parsed)));
         Color_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Root_Node.First));
         Inner_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Color_Node.First));
         Red_Glyphs : Natural := 0;
      begin
         Check (Color_Node.Kind = Math_Model.Color_Node and then
           Inner_Node.Code_Point = Character'Pos ('x') and then
           Inner_Node.Next = Math_Model.No_Node,
           "text-color compatibility limits color node to one argument");
         for Command of Outp.Geometry.Commands loop
            if Command.Kind = Math_Layout.Glyph_Command and then
              Command.Has_Color and then Command.Red = 1.0 and then
              Command.Green = 0.0 and then Command.Blue = 0.0
            then
               Red_Glyphs := Red_Glyphs + 1;
            end if;
         end loop;
         Check (Red_Glyphs = 1,
           "text-color compatibility colors only its argument");
      end;

      Opt := (others => <>);
      Math_Engine.Parse ("{\color{red}x+y}z", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready and then
        Outp.Geometry.Valid and then Outp.Geometry.Commands.Length > 0,
        "grouped color scope retains nonempty valid geometry");
      declare
         Root_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Math_Syntax.Root (Outp.Parsed)));
         Group_Row : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Root_Node.First));
         Color_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Group_Row.First));
         Inner_Row : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Color_Node.First));
         Following_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Group_Row.Next));
         Red_Glyphs : Natural := 0;
         Plain_Z : Boolean := False;
      begin
         Check (Color_Node.Kind = Math_Model.Color_Node and then
           Inner_Row.Kind = Math_Model.Row_Node and then
           Inner_Row.First /= Math_Model.No_Node,
           "nested group retains its own color node scope");
         for Command of Outp.Geometry.Commands loop
            if Command.Kind = Math_Layout.Glyph_Command and then
              Command.Code_Point = Character'Pos ('z')
            then
               Plain_Z := not Command.Has_Color;
            elsif Command.Kind = Math_Layout.Glyph_Command and then
              Command.Has_Color and then Command.Red = 1.0 and then
              Command.Green = 0.0 and then Command.Blue = 0.0
            then
               Red_Glyphs := Red_Glyphs + 1;
            end if;
         end loop;
         Check (Following_Node.Code_Point = Character'Pos ('z') and then
           Plain_Z and then Red_Glyphs = 3,
           "nested color restores uncolored following glyphs");
      end;

      Math_Engine.Parse
        ("\begin{matrix}\color{red}a+b&c\\d&e\end{matrix}",
         Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready and then Outp.Geometry.Valid and
        then Outp.Geometry.Commands.Length > 0,
        "color expression respects array cell and row boundaries");
      declare
         Root_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Math_Syntax.Root (Outp.Parsed)));
         Array_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Root_Node.First));
         First_Row : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Array_Node.First));
         First_Cell : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (First_Row.First));
         Color_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (First_Cell.First));
         Color_Row : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Color_Node.First));
         Second_Cell : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (First_Cell.Next));
         Second_Row : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (First_Row.Next));
         Second_Glyph_Row : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Second_Cell.First));
         Second_Glyph : constant Math_Syntax.Node := Second_Glyph_Row;
      begin
         Check (Array_Node.Kind = Math_Model.Array_Node and then
           Color_Node.Kind = Math_Model.Color_Node and then
           Color_Row.Kind = Math_Model.Row_Node and then
           Color_Row.First /= Math_Model.No_Node and then
           Math_Syntax.Element
             (Outp.Parsed, Positive (Color_Row.First)).Next /=
               Math_Model.No_Node and then
           Second_Glyph.Code_Point = Character'Pos ('c') and then
           Second_Row.First /= Math_Model.No_Node,
           "array AST closes color before next cell and row");
      end;

      Math_Engine.Parse
        ("\left(\color{red}x+y\right)+z", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready and then Outp.Geometry.Valid and
        then Outp.Geometry.Commands.Length > 0,
        "color expression stops at right delimiter boundary");
      declare
         Root_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Math_Syntax.Root (Outp.Parsed)));
         Delimited_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Root_Node.First));
         Inner_Row : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Delimited_Node.First));
         Color_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Inner_Row.First));
         Color_Row : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Color_Node.First));
         Trailing : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Delimited_Node.Next));
      begin
         Check (Delimited_Node.Kind = Math_Model.Delimited_Node and then
           Color_Node.Kind = Math_Model.Color_Node and then
           Math_Syntax.Element
             (Outp.Parsed, Positive (Color_Row.First)).Code_Point =
               Character'Pos ('x') and then
           Math_Syntax.Element
             (Outp.Parsed,
              Positive
                (Math_Syntax.Element
                   (Outp.Parsed, Positive (Color_Row.First)).Next))
                .Code_Point = Character'Pos ('+') and then
           Trailing.Code_Point = Character'Pos ('+'),
           "right delimiter remains outside color expression");
      end;

      Math_Engine.Parse
        ("\color{red}x^2+\frac{a}{b}+z", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready and then Outp.Geometry.Valid and
        then Outp.Geometry.Commands.Length > 0,
        "color expression with scripts and fraction has geometry");
      declare
         Root_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Math_Syntax.Root (Outp.Parsed)));
         Color_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Root_Node.First));
         Color_Row : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Color_Node.First));
         Script_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Color_Row.First));
         Binary_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Script_Node.Next));
         Fraction_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Binary_Node.Next));
         Red_Glyphs : Natural := 0;
      begin
         Check (Color_Node.Kind = Math_Model.Color_Node and then
           Script_Node.Kind = Math_Model.Scripts_Node and then
           Fraction_Node.Kind = Math_Model.Fraction_Node and then
           Math_Syntax.Element
             (Outp.Parsed, Positive (Fraction_Node.First)).First /=
               Math_Model.No_Node and then
           Math_Syntax.Element
             (Outp.Parsed, Positive (Fraction_Node.Second)).First /=
               Math_Model.No_Node,
           "script and fraction AST remain inside color scope");
         for Command of Outp.Geometry.Commands loop
            if Command.Kind = Math_Layout.Glyph_Command and then
              Command.Has_Color and then Command.Red = 1.0 and then
              Command.Green = 0.0 and then Command.Blue = 0.0
            then
               Red_Glyphs := Red_Glyphs + 1;
            end if;
         end loop;
         Check (Red_Glyphs = 7,
           "script and fraction descendant glyphs receive scoped color");
      end;

      Math_Engine.Parse ("\color{unknown}x", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Parse_Error and then
        Math_Syntax.Error (Outp.Parsed) = "unsupported color name" and then
        Math_Syntax.Diagnostic_Count (Outp.Parsed) = 1 and then
        Math_Syntax.Diagnostic_At (Outp.Parsed, 1).Kind =
          Math_Syntax.Parse_Error,
        "unsupported color retains its explicit parse diagnostic");
      Math_Engine.Parse ("\color{#12xz56}x", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Parse_Error and then
        Math_Syntax.Error (Outp.Parsed) = "invalid color value" and then
        Math_Syntax.Diagnostic_Count (Outp.Parsed) = 1,
        "malformed hex color retains its explicit parse diagnostic");

      Opt := (others => <>);
      Math_Engine.Parse ("\href{https://example.invalid}{x}",
        Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Policy_Visible_Command and then
        Math_Syntax.Is_Valid (Outp.Parsed) and then Outp.Geometry.Valid,
        "valid refused href has dedicated policy-visible status");
      Check (Outp.Geometry.Commands.Length = 5 and then
        Outp.Geometry.Commands (1).Code_Point = Character'Pos ('\') and then
        Outp.Geometry.Commands (2).Code_Point = Character'Pos ('h') and then
        Outp.Geometry.Commands (3).Code_Point = Character'Pos ('r') and then
        Outp.Geometry.Commands (4).Code_Point = Character'Pos ('e') and then
        Outp.Geometry.Commands (5).Code_Point = Character'Pos ('f'),
        "refusal draws only the original href command glyphs");
      Check (Outp.Geometry.Commands (1).Has_Color and then
        Outp.Geometry.Commands (1).Red = 204.0 / 255.0 and then
        Outp.Geometry.Commands (1).Green = 0.0 and then
        Outp.Geometry.Commands (1).Blue = 0.0 and then
        Outp.Geometry.Commands (1).Alpha = 1.0,
        "refusal command glyphs use KaTeX default red RGBA");
      Opt.Strict := Math_Syntax.Strict_Error;
      Math_Engine.Parse ("\href{}{x}", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Parse_Error and then
        Math_Syntax.Error (Outp.Parsed)'Length > 0 and then
        Outp.Geometry.Commands.Is_Empty,
        "strict malformed href fails before policy-visible rendering");

      Opt.Style := Math_Layout.Display_Style;
      Math_Engine.Parse ("\sum_i^n", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready,
        "display style accepted");
      Opt := (others => <>);
      Opt.Strict := Math_Syntax.Strict_Error;
      Math_Engine.Parse ("\htmlClass{class}{x}", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Parse_Error and then
        Math_Engine.Error (Outp)'Length > 10 and then
        Math_Engine.Error (Outp) = Math_Syntax.Error (Outp.Parsed) and then
        not Math_Syntax.Is_Valid (Outp.Parsed),
        "strict policy rejects refused HTML command");

      Opt := (others => <>);
      Opt.Settings.Throw_On_Error := False;
      Math_Engine.Parse ("x+}", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Parse_Error and then
        not Math_Syntax.Is_Valid (Outp.Parsed) and then
        Outp.Geometry.Valid and then
        Math_Engine.Error (Outp) = Math_Syntax.Error (Outp.Parsed),
        "nonthrowing parse error draws original source without math success");
      Check (Outp.Geometry.Commands.Length = 3 and then
        Outp.Geometry.Commands (1).Code_Point = Character'Pos ('x') and then
        Outp.Geometry.Commands (2).Code_Point = Character'Pos ('+') and then
        Outp.Geometry.Commands (3).Code_Point = Character'Pos ('}'),
        "fallback commands preserve literal source code points");
      Opt := (others => <>);
      Opt.Settings.Max_Expand := 1;
      Math_Engine.Parse ("\def\budget{\budget}\budget",
        Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Parse_Error and then
        Math_Engine.Error (Outp)'Length > 10,
        "configured maxExpand enforces the expansion budget");
      Opt := (others => <>);
      Opt.Settings.Max_Expand := 10_001;
      Math_Engine.Parse ("x", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Unsupported_Settings and then
        Math_Engine.Error (Outp) = "maxExpand must be in 1..10000",
        "out-of-range maxExpand rejected explicitly");

      Opt := (others => <>);
      Math_Engine.Parse ("\frac{a}{b}", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready,
        "default rule thickness request ready");
      declare
         Default_Ascent : constant Long_Float := Outp.Geometry.Ascent;
         Default_Descent : constant Long_Float := Outp.Geometry.Descent;
         Default_Rules : Natural := 0;
         Thick_Rules : Natural := 0;
         Thick_Rule_Height : Long_Float := 0.0;
      begin
         for Command of Outp.Geometry.Commands loop
            if Command.Kind = Math_Layout.Rule_Command then
               Default_Rules := Default_Rules + 1;
            end if;
         end loop;
         Opt.Settings.Min_Rule_Thickness := 0.2;
         Math_Engine.Parse ("\frac{a}{b}", Shared'Access, Opt, Outp);
         Check (Outp.Status = Math_Engine.Ready,
           "configured rule thickness request ready");
         for Command of Outp.Geometry.Commands loop
            if Command.Kind = Math_Layout.Rule_Command then
               Thick_Rules := Thick_Rules + 1;
               Thick_Rule_Height := Command.Height;
            end if;
         end loop;
         Check (Default_Rules = 1 and Thick_Rules = Default_Rules,
           "minimum thickness preserves fraction rule count");
         Check (Thick_Rule_Height >= 0.2,
           "fraction rule honors minimum thickness");
         Check (Outp.Geometry.Ascent > Default_Ascent and
           Outp.Geometry.Descent > Default_Descent,
           "thicker fraction expands composed clearance bounds");
      end;
      Opt := (others => <>);
      Opt.Settings.Min_Rule_Thickness := 0.02;
      Math_Engine.Parse ("\genfrac{}{}{0.01pt}{}{a}{b}",
        Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready,
        "source fraction rule parses with a configured minimum");
      declare
         Custom_Rule_Height : Long_Float := 0.0;
      begin
         for Command of Outp.Geometry.Commands loop
            if Command.Kind = Math_Layout.Rule_Command then
               Custom_Rule_Height := Command.Height;
            end if;
         end loop;
         Check (Custom_Rule_Height >= 0.02,
           "minimum thickness overrides a thinner source fraction rule");
      end;
      Opt.Settings.Min_Rule_Thickness := 0.0;
      Math_Engine.Parse ("\genfrac{}{}{0.01pt}{}{a}{b}",
        Shared'Access, Opt, Outp);
      declare
         Source_Rule_Height : Long_Float := 0.0;
      begin
         for Command of Outp.Geometry.Commands loop
            if Command.Kind = Math_Layout.Rule_Command then
               Source_Rule_Height := Command.Height;
            end if;
         end loop;
         Check (Source_Rule_Height < 0.02,
           "source thickness below legacy cutoff is retained without minimum");
      end;
      Opt := (others => <>);
      Opt.Settings.Min_Rule_Thickness := 100.1;
      Math_Engine.Parse ("x", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Unsupported_Settings,
        "out-of-range minimum rule thickness rejected");
      Opt := (others => <>);
      Opt.Settings.Max_Size := 1;
      Math_Engine.Parse ("x", Shared'Access, Opt, Outp);
      Check (Outp.Status /= Math_Engine.Unsupported_Settings,
        "minimum supported maxSize passes engine validation");
      Opt.Settings.Max_Size := 100;
      Math_Engine.Parse ("x", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready,
        "maximum supported maxSize accepted");
      Opt.Settings.Max_Size := 101;
      Math_Engine.Parse ("x", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Unsupported_Settings and then
        Math_Engine.Error (Outp) = "maxSize must be in 1..100",
        "maxSize above 100 rejected explicitly");
      Opt := (others => <>);
      Opt.Settings.Leqno := True;
      Math_Engine.Parse
        ("\begin{equation}x\tag{1}\end{equation}",
         Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready,
        "leqno accepted by engine");
      declare
         Root : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Math_Syntax.Root (Outp.Parsed)));
         Tag_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Root.First));
      begin
         Check (Tag_Node.Kind = Math_Model.Tagged_Node and then
           Tag_Node.Tag_Is_Left,
           "leqno marks equation tag as left-positioned");
      end;
      Opt := (others => <>);
      Opt.Foreground_Set := True;
      Opt.Foreground := (Red => 0.2, Green => 0.3,
                         Blue => 0.4, Alpha => 1.0);
      Math_Engine.Parse ("x", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready,
        "valid foreground accepted");
      declare
         Found : Boolean := False;
      begin
         for Command of Outp.Geometry.Commands loop
            if Command.Kind = Math_Layout.Glyph_Command and then
              Command.Has_Color and then Command.Red = 0.2 and then
              Command.Green = 0.3 and then Command.Blue = 0.4
            then
               Found := True;
            end if;
         end loop;
         Check (Found, "foreground applied to uncolored glyph");
      end;

      Opt.Foreground.Red := 1.1;
      Math_Engine.Parse ("x", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Unsupported_Settings,
        "invalid foreground range rejected");

      Opt := (others => <>);
      Opt.Global_Group := True;
      Math_Engine.Parse ("\gdef\saved{x}", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready and then
        Math_Macros.Is_Defined (Shared, "\saved") and then
        Outp.Geometry.Valid and then Outp.Geometry.Width = 0.0 and then
        Outp.Geometry.Ascent = 0.0 and then Outp.Geometry.Descent = 0.0 and then
        Outp.Geometry.Commands.Is_Empty,
        "command-only global definition is a valid empty rendering");
      Opt.Global_Group := False;
      Math_Engine.Parse ("\saved", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready and then
        Math_Syntax.Source (Outp.Parsed) = "\saved" and then
        not Outp.Geometry.Commands.Is_Empty,
        "global macro renders in a following request");
      Math_Engine.Parse ("\def\temp{x}", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready and then
        not Math_Macros.Is_Defined (Shared, "\temp") and then
        Outp.Geometry.Commands.Is_Empty,
        "local definition in command-only root rolls back");
      Math_Engine.Parse ("\gdef\saved{y}\bogus", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Parse_Error and then
        Math_Macros.Is_Defined (Shared, "\saved"),
        "global definition persists after later parse failure");
      Math_Engine.Parse ("\saved", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready and then
        not Outp.Geometry.Commands.Is_Empty,
        "failed request leaves updated global macro available");
      Math_Engine.Parse ("", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready,
        "empty source is engine-ready");
      Check (Outp.Geometry.Valid and then Outp.Geometry.Width = 0.0 and then
        Outp.Geometry.Ascent = 0.0 and then
        Outp.Geometry.Descent = 0.0 and then
        Outp.Geometry.Commands.Is_Empty,
        "empty source has empty valid geometry");
      Math_Engine.Parse ("\newline", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready and then
        Outp.Geometry.Valid and then Outp.Geometry.Width = 0.0 and then
        Outp.Geometry.Ascent = 0.0 and then
        Outp.Geometry.Descent = 0.0 and then
        Outp.Geometry.Commands.Is_Empty,
        "standalone forced break has no rendered line extent");
      Math_Engine.Parse ("\saved", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready and then
        Math_Syntax.Source (Outp.Parsed) = "\saved" and then
        not Outp.Geometry.Commands.Is_Empty,
        "shared macro expands with source identity preserved");
      Check (Math_Macros.Scope_Depth (Shared) = 0,
        "shared scope restored after requests");
      Test_Scope_Limit_Recovery;
      Test_Abuse_Rejection_Recovery;

      declare
         Parsed : Math_Syntax.Document;
         Geometry : Math_Layout.Box;
         Source : constant String := (1 .. 1_000 => 'x');
      begin
         Poll_Count := 0;
         Parsed := Math_Syntax.Parse (Source);
         begin
            Geometry := Math_Layout.Build
              (Parsed, Math_Layout.Text_Style, Cancel_Context'Unchecked_Access);
            Check (False, "layout cancellation propagates from row sweep");
         exception
            when Math_Work_Control.Stop_Requested =>
               Check (True, "layout cancellation propagates from row sweep");
         end;
      end;
      declare
         Parsed : Math_Syntax.Document;
         Geometry : Math_Layout.Box;
         Source : constant String := (1 .. 1_000 => 'x');
      begin
         Poll_Count := 0;
         Parsed := Math_Syntax.Parse (Source);
         begin
            Geometry := Math_Layout.Build
              (Parsed, Math_Layout.Text_Style, Deadline_Context'Unchecked_Access);
            Check (False, "layout deadline propagates distinctly");
         exception
            when Math_Work_Control.Deadline_Expired =>
               Check (True, "layout deadline propagates distinctly");
         end;
      end;
      declare
         Opt : Math_Engine.Request;
         Prior_Depth : constant Natural := Math_Macros.Scope_Depth (Shared);
      begin
         Opt.Work := Cancel_Context'Unchecked_Access;
         Poll_Count := 0;
         begin
            Math_Engine.Parse
              ("\begin{matrix}x\\y\end{matrix}",
               Shared'Access, Opt, Outp);
            Check (False, "engine cancellation propagates distinctly");
         exception
            when Math_Work_Control.Stop_Requested =>
               Check (Math_Macros.Scope_Depth (Shared) = Prior_Depth,
                 "early engine cancellation leaves scope unchanged");
         end;
         Math_Engine.Parse ("x", Shared'Access, (others => <>), Outp);
         Check (Outp.Status = Math_Engine.Ready and then
           Outp.Geometry.Valid and then
           Math_Macros.Scope_Depth (Shared) = Prior_Depth,
           "engine cancellation is followed by null-Work recovery");
      end;
      declare
         Opt : Math_Engine.Request;
         Prior_Depth : constant Natural := Math_Macros.Scope_Depth (Shared);
      begin
         Opt.Work := Deadline_Context'Unchecked_Access;
         Poll_Count := 0;
         begin
            Math_Engine.Parse
              ("\begin{matrix}x\\y\end{matrix}",
               Shared'Access, Opt, Outp);
            Check (False, "engine deadline propagates distinctly");
         exception
            when Math_Work_Control.Deadline_Expired =>
               Check (Math_Macros.Scope_Depth (Shared) = Prior_Depth,
                 "early engine deadline leaves scope unchanged");
         end;
         Math_Engine.Parse ("x", Shared'Access, (others => <>), Outp);
         Check (Outp.Status = Math_Engine.Ready and then
           Outp.Geometry.Valid and then
           Math_Macros.Scope_Depth (Shared) = Prior_Depth,
           "engine deadline is followed by null-Work recovery");
      end;
   end Run;
begin
   Run;
   Ada.Text_IO.Put_Line ("ASSERTIONS" & Natural'Image (Checks) &
     " failures=" & Natural'Image (Failures));
   if Checks < 18 or else Failures /= 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Math_Engine_Probe;
