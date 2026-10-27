with Math_Paths;

package Math_Stretchy is
   type Accent_Kind is
     (Wide_Hat, Wide_Tilde, Over_Right_Arrow, Over_Left_Arrow,
      Vector_Accent);

   type Brace_Kind is (Over_Brace, Under_Brace);
   type Brace_Part is (Left_Part, Middle_Part, Right_Part);
   type Part_Align is (Min_Align, Mid_Align, Max_Align);

   --  Names are KaTeX table keys without a leading backslash.
   function Geometry_For (Name : String) return Math_Paths.Path;
   function ViewBoxHeightFor (Name : String) return Long_Float;
   function MinWidthFor (Name : String) return Long_Float;
   function PartCount (Name : String) return Natural;
   function PartPath
     (Name : String; Part : Positive) return Math_Paths.Path;
   function PartAlignFor
     (Name : String; Part : Positive) return Part_Align;

   --  Static single-piece geometry; callers compose/slice all parts.
   function Brace_Part_For
     (Kind : Brace_Kind; Part : Brace_Part) return Math_Paths.Path;
   function Brace_View_Width (Part : Brace_Part) return Long_Float;
   function Brace_View_Height (Kind : Brace_Kind) return Long_Float;
   function View_Width (Kind : Accent_Kind) return Long_Float;
   function View_Height (Kind : Accent_Kind) return Long_Float;
   function Path_For
     (Kind : Accent_Kind; Width : Long_Float) return Math_Paths.Path;
   function Tall_Radical
     (Height_Em, Extra_Vinculum, Width_Em : Long_Float)
      return Math_Paths.Path;
end Math_Stretchy;
