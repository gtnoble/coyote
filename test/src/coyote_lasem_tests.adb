--  Coyote_Lasem_Tests body.
--
--  Project: coyote

with AUnit.Assertions;
with Coyote_Lasem;
with Interfaces.C;
with Interfaces.C.Strings;

package body Coyote_Lasem_Tests is

   use AUnit.Assertions;
   use type Interfaces.C.Strings.chars_ptr;
   use type Interfaces.C.unsigned;

   procedure Test_Measure_Fraction (T : in out Test) is
      pragma Unreferenced (T);
      Source   : constant String := "$$\frac{1}{2}$$";
      C_Source : constant Interfaces.C.char_array :=
        Interfaces.C.To_C (Source, Append_Nul => True);
      Width    : aliased Interfaces.C.unsigned := 0;
      Height   : aliased Interfaces.C.unsigned := 0;
      Baseline : aliased Interfaces.C.unsigned := 0;
      Error    : Interfaces.C.Strings.chars_ptr;
   begin
      Error := Coyote_Lasem.Measure_Itex
        (C_Source, Interfaces.C.long (Source'Length),
         Width'Access, Height'Access, Baseline'Access);
      Assert (Error = Interfaces.C.Strings.Null_Ptr,
              "Lasem measures a fraction: "
              & (if Error = Interfaces.C.Strings.Null_Ptr
                 then ""
                 else Interfaces.C.Strings.Value (Error)));
      Assert (Width > 0, "fraction width is non-zero");
      Assert (Height > 0, "fraction height is non-zero");
      Assert (Baseline <= Height, "fraction baseline is within height");
   end Test_Measure_Fraction;

   procedure Test_Measure_Complex_Expression (T : in out Test) is
      pragma Unreferenced (T);
      Source   : constant String :=
        "$$\begin{pmatrix}a&b\\c&d\end{pmatrix}$$";
      C_Source : constant Interfaces.C.char_array :=
        Interfaces.C.To_C (Source, Append_Nul => True);
      Width    : aliased Interfaces.C.unsigned := 0;
      Height   : aliased Interfaces.C.unsigned := 0;
      Baseline : aliased Interfaces.C.unsigned := 0;
      Error    : Interfaces.C.Strings.chars_ptr;
   begin
      Error := Coyote_Lasem.Measure_Itex
        (C_Source, Interfaces.C.long (Source'Length),
         Width'Access, Height'Access, Baseline'Access);
      Assert (Error = Interfaces.C.Strings.Null_Ptr,
              "Lasem measures a matrix");
      Assert (Width > 0 and then Height > 0,
              "matrix dimensions are non-zero");
   end Test_Measure_Complex_Expression;

   procedure Test_Measure_Literal_Relations (T : in out Test) is
      pragma Unreferenced (T);
      Literal_Source : constant String :=
        "\[" & ASCII.LF
        & "\zeta(s)=\sum_{n=1}^{\infty}\frac{1}{n^s}" & ASCII.LF
        & "\quad\text{for }\operatorname{Re}(s)>1," & ASCII.LF
        & "\]";
      Command_Source : constant String :=
        "\[" & ASCII.LF
        & "\zeta(s)=\sum_{n=1}^{\infty}\frac{1}{n^s}" & ASCII.LF
        & "\quad\text{for }\operatorname{Re}(s)\gt 1," & ASCII.LF
        & "\]";
      Literal_C : constant Interfaces.C.char_array :=
        Interfaces.C.To_C (Literal_Source, Append_Nul => True);
      Command_C : constant Interfaces.C.char_array :=
        Interfaces.C.To_C (Command_Source, Append_Nul => True);
      Literal_Width    : aliased Interfaces.C.unsigned := 0;
      Literal_Height   : aliased Interfaces.C.unsigned := 0;
      Literal_Baseline : aliased Interfaces.C.unsigned := 0;
      Command_Width    : aliased Interfaces.C.unsigned := 0;
      Command_Height   : aliased Interfaces.C.unsigned := 0;
      Command_Baseline : aliased Interfaces.C.unsigned := 0;
      Literal_Error    : Interfaces.C.Strings.chars_ptr;
      Command_Error    : Interfaces.C.Strings.chars_ptr;
   begin
      Literal_Error := Coyote_Lasem.Measure_Itex
        (Literal_C, Interfaces.C.long (Literal_Source'Length),
         Literal_Width'Access, Literal_Height'Access,
         Literal_Baseline'Access);
      Command_Error := Coyote_Lasem.Measure_Itex
        (Command_C, Interfaces.C.long (Command_Source'Length),
         Command_Width'Access, Command_Height'Access,
         Command_Baseline'Access);

      Assert (Literal_Error = Interfaces.C.Strings.Null_Ptr,
              "literal relation expression is accepted: "
              & (if Literal_Error = Interfaces.C.Strings.Null_Ptr
                 then ""
                 else Interfaces.C.Strings.Value (Literal_Error)));
      Assert (Command_Error = Interfaces.C.Strings.Null_Ptr,
              "command relation expression is accepted: "
              & (if Command_Error = Interfaces.C.Strings.Null_Ptr
                 then ""
                 else Interfaces.C.Strings.Value (Command_Error)));
      Assert (Literal_Width = Command_Width,
              "literal and command relation widths match");
      Assert (Literal_Height = Command_Height,
              "literal and command relation heights match");
      Assert (Literal_Baseline = Command_Baseline,
              "literal and command relation baselines match");

      if Literal_Error /= Interfaces.C.Strings.Null_Ptr then
         Coyote_Lasem.Free_Error (Literal_Error);
      end if;
      if Command_Error /= Interfaces.C.Strings.Null_Ptr then
         Coyote_Lasem.Free_Error (Command_Error);
      end if;
   end Test_Measure_Literal_Relations;

   procedure Test_Invalid_Itex_Returns_Error (T : in out Test) is
      pragma Unreferenced (T);
      Source   : constant String := "$$\frac{1}{$$";
      C_Source : constant Interfaces.C.char_array :=
        Interfaces.C.To_C (Source, Append_Nul => True);
      Width    : aliased Interfaces.C.unsigned := 0;
      Height   : aliased Interfaces.C.unsigned := 0;
      Baseline : aliased Interfaces.C.unsigned := 0;
      Error    : Interfaces.C.Strings.chars_ptr;
   begin
      Error := Coyote_Lasem.Measure_Itex
        (C_Source, Interfaces.C.long (Source'Length),
         Width'Access, Height'Access, Baseline'Access);
      Assert (Error /= Interfaces.C.Strings.Null_Ptr,
              "invalid iTeX returns an error");
      Coyote_Lasem.Free_Error (Error);
   end Test_Invalid_Itex_Returns_Error;

end Coyote_Lasem_Tests;
