with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Math_Model;
with Math_Syntax;
with Math_Paths;

--  Reference-guided layout in em units. Y grows down, origin is baseline.
--  Unsupported or invalid syntax/geometry returns Valid=False; commands
--  are not partial success. No Cairo/GTK or external process dependency.
package Math_Layout is
   use Math_Model;

   use type Math_Paths.Command_Kind;
   use type Math_Paths.Point;
   function Equal_Path_Segment
     (Left, Right : Math_Paths.Segment) return Boolean is
     (Left.Kind = Right.Kind and then Left.First = Right.First and then
      Left.Second = Right.Second and then Left.Third = Right.Third);
   package Path_Segment_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Math_Paths.Segment,
      "=" => Equal_Path_Segment);

   type Math_Style is (Display_Style, Text_Style);
   type Layout_Settings is record
      Min_Rule_Thickness : Long_Float := 0.0;
      Max_Size : Positive := 100;
   end record;
   type Command_Kind is (Glyph_Command, Rule_Command, Path_Command);
   type Draw_Command is record
      Kind       : Command_Kind := Glyph_Command;
      Font       : Font_Kind := Main_Regular;
      Code_Point : Natural := 0;
      X          : Long_Float := 0.0;
      Y          : Long_Float := 0.0;
      Scale      : Long_Float := 1.0;
      Width      : Long_Float := 0.0;
      Height     : Long_Float := 0.0;
      Path_Data  : Path_Segment_Vectors.Vector;
      Has_Color  : Boolean := False;
      Red        : Long_Float := 0.0;
      Green      : Long_Float := 0.0;
      Blue       : Long_Float := 0.0;
      Alpha      : Long_Float := 1.0;
      Has_Clip   : Boolean := False;
      Clip_X     : Long_Float := 0.0;
      Clip_Y     : Long_Float := 0.0;
      Clip_W     : Long_Float := 0.0;
      Clip_H     : Long_Float := 0.0;
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
   --  Minimum rule thickness is in em units; Max_Size accepts 1..100.
   --  Parse dimensions with the same maximum before building the AST.
   --  Rule dimensions and clearance use the effective thickness per build.
   function Build
     (Item : Math_Syntax.Document; Style : Math_Style;
      Settings : Layout_Settings) return Box;
   --  Invalid syntax or unsupported geometry produces Valid=False, never
   --  a partial success. Display/text style affects fraction and op sizing.
end Math_Layout;
