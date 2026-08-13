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

   procedure Test_Measure_MathML_Fraction (T : in out Test) is
      pragma Unreferenced (T);
      Source   : constant String :=
        "<math xmlns=""http://www.w3.org/1998/Math/MathML"">"
        & "<mfrac><mn>1</mn><mn>2</mn></mfrac></math>";
      C_Source : constant Interfaces.C.char_array :=
        Interfaces.C.To_C (Source, Append_Nul => True);
      Width    : aliased Interfaces.C.unsigned := 0;
      Height   : aliased Interfaces.C.unsigned := 0;
      Baseline : aliased Interfaces.C.unsigned := 0;
      Error    : Interfaces.C.Strings.chars_ptr;
   begin
      Error := Coyote_Lasem.Measure_MathML
        (C_Source, Interfaces.C.long (Source'Length),
         Width'Access, Height'Access, Baseline'Access);
      Assert (Error = Interfaces.C.Strings.Null_Ptr,
              "Lasem measures a MathML fraction: "
              & (if Error = Interfaces.C.Strings.Null_Ptr
                 then ""
                 else Interfaces.C.Strings.Value (Error)));
      Assert (Width > 0, "fraction width is non-zero");
      Assert (Height > 0, "fraction height is non-zero");
      Assert (Baseline <= Height, "fraction baseline is within height");
   end Test_Measure_MathML_Fraction;

   procedure Test_Measure_MathML_Matrix (T : in out Test) is
      pragma Unreferenced (T);
      Source   : constant String :=
        "<math xmlns=""http://www.w3.org/1998/Math/MathML"">"
        & "<mtable>"
        & "<mtr><mtd><mi>a</mi></mtd><mtd><mi>b</mi></mtd></mtr>"
        & "<mtr><mtd><mi>c</mi></mtd><mtd><mi>d</mi></mtd></mtr>"
        & "</mtable></math>";
      C_Source : constant Interfaces.C.char_array :=
        Interfaces.C.To_C (Source, Append_Nul => True);
      Width    : aliased Interfaces.C.unsigned := 0;
      Height   : aliased Interfaces.C.unsigned := 0;
      Baseline : aliased Interfaces.C.unsigned := 0;
      Error    : Interfaces.C.Strings.chars_ptr;
   begin
      Error := Coyote_Lasem.Measure_MathML
        (C_Source, Interfaces.C.long (Source'Length),
         Width'Access, Height'Access, Baseline'Access);
      Assert (Error = Interfaces.C.Strings.Null_Ptr,
              "Lasem measures a MathML matrix");
      Assert (Width > 0 and then Height > 0,
              "matrix dimensions are non-zero");
   end Test_Measure_MathML_Matrix;

   procedure Test_Measure_MathML_Relations (T : in out Test) is
      pragma Unreferenced (T);
      Source   : constant String :=
        "<math xmlns=""http://www.w3.org/1998/Math/MathML"">"
        & "<mrow><mi>x</mi><mo>&lt;</mo><mo>&gt;</mo><mn>1</mn></mrow>"
        & "</math>";
      C_Source : constant Interfaces.C.char_array :=
        Interfaces.C.To_C (Source, Append_Nul => True);
      Width    : aliased Interfaces.C.unsigned := 0;
      Height   : aliased Interfaces.C.unsigned := 0;
      Baseline : aliased Interfaces.C.unsigned := 0;
      Error    : Interfaces.C.Strings.chars_ptr;
   begin
      Error := Coyote_Lasem.Measure_MathML
        (C_Source, Interfaces.C.long (Source'Length),
         Width'Access, Height'Access, Baseline'Access);
      Assert (Error = Interfaces.C.Strings.Null_Ptr,
              "MathML relation entities are accepted");
      Assert (Width > 0 and then Height > 0,
              "relation dimensions are non-zero");
   end Test_Measure_MathML_Relations;

   procedure Test_Invalid_MathML_Returns_Error (T : in out Test) is
      pragma Unreferenced (T);
      Source   : constant String := "";
      C_Source : constant Interfaces.C.char_array :=
        Interfaces.C.To_C (Source, Append_Nul => True);
      Width    : aliased Interfaces.C.unsigned := 0;
      Height   : aliased Interfaces.C.unsigned := 0;
      Baseline : aliased Interfaces.C.unsigned := 0;
      Error    : Interfaces.C.Strings.chars_ptr;
   begin
      Error := Coyote_Lasem.Measure_MathML
        (C_Source, Interfaces.C.long (Source'Length),
         Width'Access, Height'Access, Baseline'Access);
      Assert (Error /= Interfaces.C.Strings.Null_Ptr,
              "invalid MathML returns an error");
      Coyote_Lasem.Free_Error (Error);
   end Test_Invalid_MathML_Returns_Error;

end Coyote_Lasem_Tests;
