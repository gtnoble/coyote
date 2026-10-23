with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Math_Model;
with Math_Syntax;

--  Reference-guided layout in em units. Y grows down, origin is baseline.
--  Unsupported or invalid syntax/geometry returns Valid=False; commands
--  are not partial success. No Cairo/GTK or external process dependency.
package Math_Layout is
   use Math_Model;

   type Math_Style is (Display_Style, Text_Style);
   type Command_Kind is (Glyph_Command, Rule_Command);
   type Draw_Command is record
      Kind       : Command_Kind := Glyph_Command;
      Font       : Font_Kind := Main_Regular;
      Code_Point : Natural := 0;
      X          : Long_Float := 0.0;
      Y          : Long_Float := 0.0;
      Scale      : Long_Float := 1.0;
      Width      : Long_Float := 0.0;
      Height     : Long_Float := 0.0;
   end record;
   --  Glyph X/Y is its baseline; rule X/Y is its upper-left corner.
   package Command_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Draw_Command);

   type Box is record
      Valid    : Boolean := False;
      Width    : Long_Float := 0.0;
      Ascent   : Long_Float := 0.0;
      Descent  : Long_Float := 0.0;
      Italic   : Long_Float := 0.0;
      Message  : Ada.Strings.Unbounded.Unbounded_String;
      Commands : Command_Vectors.Vector;
   end record;

   function Build
     (Item : Math_Syntax.Document;
      Style : Math_Style := Text_Style) return Box;
   --  Invalid syntax or unsupported geometry produces Valid=False, never
   --  a partial success. Display/text style affects fraction and op sizing.
end Math_Layout;
