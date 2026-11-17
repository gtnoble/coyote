with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Math_Model;
with Math_Syntax;
with Math_Metrics;
with Math_Paths;
with Math_Work_Control;

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
      Pixel_Em : Long_Float := 0.0;
      Advance_Source : Math_Metrics.Advance_Source_Access := null;
   end record;
   type Command_Kind is
     (Glyph_Command, Rule_Command, Path_Command, Text_Run_Command);
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
      Text_Run_Text : Ada.Strings.Unbounded.Unbounded_String;
      Text_Run_Profile : Script_Profile := Latin_Fallback;
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
      --  Shadow offsets are em units; blur remains CSS pixels for exact
      --  conversion by a renderer that knows its pixel-per-em size.
      Has_Shadow : Boolean := False;
      Shadow_X   : Long_Float := 0.0;
      Shadow_Y   : Long_Float := 0.0;
      Shadow_Blur_Px : Long_Float := 0.0;
   end record;
   --  Glyph X/Y is its baseline; rule X/Y is its upper-left corner.
   package Command_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Draw_Command);

   type Box is record
      Valid        : Boolean := False;
      Width        : Long_Float := 0.0;
      Ascent       : Long_Float := 0.0;
      Descent      : Long_Float := 0.0;
      Italic       : Long_Float := 0.0;
      Left_Aligned : Boolean := False;
      Left_Indent  : Long_Float := 0.0;
      Message      : Ada.Strings.Unbounded.Unbounded_String;
      Commands     : Command_Vectors.Vector;
   end record;
   --  Alignment is presentation metadata; Width and draw coordinates describe
   --  only the formula. Left_Indent is measured in em units.

   function Build
     (Item : Math_Syntax.Document;
      Style : Math_Style := Text_Style;
      Work : Math_Work_Control.Context_Access := null) return Box;
   --  Minimum rule thickness is in em units; Max_Size accepts 1..100.
   --  A borrowed advance source is used for Typewriter_Regular when Pixel_Em
   --  is positive; Pixel_Em is in pixels at the unscaled text size.
   --  Parse dimensions with the same maximum before building the AST.
   --  Rule dimensions and clearance use the effective thickness per build.
   function Build
     (Item : Math_Syntax.Document; Style : Math_Style;
      Settings : Layout_Settings;
      Work : Math_Work_Control.Context_Access := null) return Box;
   --  Work is borrowed for this call only and is never retained or boxed.
   --  Invalid syntax or unsupported geometry produces Valid=False, never
   --  a partial success. Display/text style affects fraction and op sizing.
end Math_Layout;
