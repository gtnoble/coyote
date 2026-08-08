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
