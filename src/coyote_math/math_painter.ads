with Ada.Finalization;
with Cairo;
with Math_Layout;

--  Paints validated layout commands with the pinned KaTeX fonts.
--  Load once and draw as needed. Each Cairo font face owns its FreeType
--  face and library until Cairo releases the final face reference, so Cairo
--  contexts may safely outlive the Font_Set.
package Math_Painter is
   Font_Error : exception;

   type Font_Set is new Ada.Finalization.Limited_Controlled with private;

   procedure Load
     (Fonts     : in out Font_Set;
      Directory : String);

   procedure Draw
     (Fonts    : Font_Set;
      Context  : Cairo.Cairo_Context;
      Item     : Math_Layout.Box;
      X        : Long_Float;
      Baseline : Long_Float;
      Em       : Long_Float);

private
   type FT_Face_Record is limited null record;
   type FT_Face is access all FT_Face_Record;
   type FT_Library_Record is limited null record;
   type FT_Library is access all FT_Library_Record;

   type Font_State;
   type Font_State_Access is access Font_State;

   type Font_Set is new Ada.Finalization.Limited_Controlled with record
      Data : Font_State_Access := null;
   end record;

   overriding procedure Finalize (Fonts : in out Font_Set);
end Math_Painter;
