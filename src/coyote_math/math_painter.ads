with Ada.Finalization;
with Cairo;
with Math_Layout;
with Math_Metrics;
with Math_Model;
with Math_Work_Control;

--  Paints validated layout commands with the pinned KaTeX fonts.
--  Load once and draw as needed. Each Cairo font face owns its FreeType
--  face and library until Cairo releases the final face reference, so Cairo
--  contexts may safely outlive the Font_Set.
package Math_Painter is
   Font_Error : exception;

   type Font_Set is new Ada.Finalization.Limited_Controlled
     and Math_Metrics.Advance_Source with private;

   overriding function Advance
     (Item       : Font_Set;
      Font       : Math_Model.Font_Kind;
      Code_Point : Natural;
      Pixel_Em   : Long_Float) return Long_Float;

   overriding function Font_Line_Extents
     (Item     : Font_Set;
      Font     : Math_Model.Font_Kind;
      Pixel_Em : Long_Float) return Math_Metrics.Font_Line_Extent;

   overriding function Font_Line_Height
     (Item     : Font_Set;
      Font     : Math_Model.Font_Kind;
      Pixel_Em : Long_Float) return Long_Float;

   --  Work is borrowed only for this call. A native FreeType call cannot
   --  be interrupted once entered.
   procedure Load
     (Fonts     : in out Font_Set;
      Directory : String;
      Work      : Math_Work_Control.Context_Access := null);

   --  Work is borrowed only for this call; each native Cairo call is
   --  non-preemptible.
   procedure Draw
     (Fonts    : Font_Set;
      Context  : Cairo.Cairo_Context;
      Item     : Math_Layout.Box;
      X        : Long_Float;
      Baseline : Long_Float;
      Em       : Long_Float;
      Work     : Math_Work_Control.Context_Access := null);

private
   type FT_Face_Record is limited null record;
   type FT_Face is access all FT_Face_Record;
   type FT_Library_Record is limited null record;
   type FT_Library is access all FT_Library_Record;

   type Font_State;
   type Font_State_Access is access Font_State;

   type Font_Set is new Ada.Finalization.Limited_Controlled
     and Math_Metrics.Advance_Source with record
      Data : Font_State_Access := null;
   end record;

   overriding procedure Finalize (Fonts : in out Font_Set);
end Math_Painter;
