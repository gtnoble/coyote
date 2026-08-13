--  Coyote_Lasem — thin Ada binding to Lasem's MathML renderer.
--
--  Lasem parses Presentation MathML and renders it directly onto a Cairo
--  context.  The C shim owns all Lasem GObject and GError values; callers
--  only receive dimensions or an error string.
--
--  Project: coyote

with Cairo;
with Interfaces.C;
with Interfaces.C.Strings;

package Coyote_Lasem is
   pragma Elaborate_Body;

   --  Measure a Presentation MathML document in pixels.  A null result
   --  indicates success; otherwise the result is an allocated error
   --  message which must be released with Free_Error.
   function Measure_MathML
     (MathML     : Interfaces.C.char_array;
      MathML_Len : Interfaces.C.long;
      Width      : access Interfaces.C.unsigned;
      Height     : access Interfaces.C.unsigned;
      Baseline   : access Interfaces.C.unsigned;
      Scale      : Interfaces.C.double := 1.0)
      return Interfaces.C.Strings.chars_ptr
   with Import, Convention => C,
        External_Name => "coyote_lasem_measure_mathml";

   --  Render a Presentation MathML document at (X, Y) on Cr.  A null
   --  result indicates success; otherwise the result is an allocated error
   --  message which must be released with Free_Error.
   function Render_MathML
     (MathML     : Interfaces.C.char_array;
      MathML_Len : Interfaces.C.long;
      Cr         : Cairo.Cairo_Context;
      X, Y       : Interfaces.C.double;
      Scale      : Interfaces.C.double := 1.0)
      return Interfaces.C.Strings.chars_ptr
   with Import, Convention => C,
        External_Name => "coyote_lasem_render_mathml";

   --  Release an error message returned by Measure_MathML or Render_MathML.
   procedure Free_Error (Message : Interfaces.C.Strings.chars_ptr)
   with Import, Convention => C,
        External_Name => "coyote_lasem_free_error";

end Coyote_Lasem;
