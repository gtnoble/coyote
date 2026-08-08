--  Coyote_Lasem — thin Ada binding to Lasem's iTeX renderer.
--
--  Lasem converts its supported iTeX/LaTeX subset to MathML and renders
--  the result directly onto a Cairo context.  The C shim owns all Lasem
--  GObject and GError values; callers only receive dimensions or an error
--  string.
--
--  Project: coyote

with Cairo;
with Interfaces.C;
with Interfaces.C.Strings;

package Coyote_Lasem is
   pragma Elaborate_Body;

   --  Measure an iTeX expression in pixels.  A null result indicates
   --  success; otherwise the result is an allocated error message which
   --  must be released with Free_Error.
   function Measure_Itex
     (Itex     : Interfaces.C.char_array;
      Itex_Len : Interfaces.C.long;
      Width    : access Interfaces.C.unsigned;
      Height   : access Interfaces.C.unsigned;
      Baseline : access Interfaces.C.unsigned)
      return Interfaces.C.Strings.chars_ptr
   with Import, Convention => C,
        External_Name => "coyote_lasem_measure_itex";

   --  Render an iTeX expression at (X, Y) on Cr.  A null result indicates
   --  success; otherwise the result is an allocated error message which
   --  must be released with Free_Error.
   function Render_Itex
     (Itex     : Interfaces.C.char_array;
      Itex_Len : Interfaces.C.long;
      Cr       : Cairo.Cairo_Context;
      X, Y     : Interfaces.C.double)
      return Interfaces.C.Strings.chars_ptr
   with Import, Convention => C,
        External_Name => "coyote_lasem_render_itex";

   --  Release an error message returned by Measure_Itex or Render_Itex.
   procedure Free_Error (Message : Interfaces.C.Strings.chars_ptr)
   with Import, Convention => C,
        External_Name => "coyote_lasem_free_error";

end Coyote_Lasem;
