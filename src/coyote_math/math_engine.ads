with Math_Layout;
with Math_Macros;
with Math_Semantics;
with Math_Syntax;
with Math_Model;
with Ada.Strings.Unbounded;

--  Headless request facade: parse once, then derive semantic and layout
--  views from that same AST. Unsupported scalar settings are rejected.
package Math_Engine is
   type Status_Kind is
     (Ready, Parse_Error, Layout_Error, Unsupported_Settings,
      Policy_Visible_Command);

   type RGBA is record
      Red   : Long_Float := 0.0;
      Green : Long_Float := 0.0;
      Blue  : Long_Float := 0.0;
      Alpha : Long_Float := 1.0;
   end record;

   type Scalar_Settings is record
      Max_Expand        : Positive := 1_000;
      Max_Size          : Positive := 100;
      Min_Rule_Thickness : Long_Float := 0.0;
      Leqno             : Boolean := False;
      Fleqn             : Boolean := False;
      Trust             : Boolean := False;
      Color_Is_Text_Color : Boolean := False;
      Error_Color       : RGBA := (Red => 1.0, Green => 0.0,
                                   Blue => 0.0, Alpha => 1.0);
      Throw_On_Error    : Boolean := True;
   end record;

   type Request is record
      Style          : Math_Layout.Math_Style := Math_Layout.Text_Style;
      Strict         : Math_Syntax.Strict_Policy := Math_Syntax.Strict_Warn;
      Global_Group   : Boolean := False;
      Settings       : Scalar_Settings;
      Foreground     : RGBA := (Red => 0.0, Green => 0.0,
                                Blue => 0.0, Alpha => 1.0);
      Foreground_Set : Boolean := False;
   end record;

   type Result is record
      Status       : Status_Kind := Parse_Error;
      Parsed       : Math_Syntax.Document;
      Geometry     : Math_Layout.Box;
      Meaning      : Math_Semantics.Document;
      Message : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   function Error (Item : Result) return String;

   procedure Parse
     (Source  : String;
      Shared  : not null access Math_Macros.Context;
      Options : Request;
      Output  : out Result);
   --  Invalid syntax always retains Parse_Error and its full diagnostic.
   --  When Throw_On_Error is False, Geometry may contain literal source glyphs;
   --  that fallback is not a successfully parsed math expression.
   --  Valid refused untrusted commands retain their literal command glyphs,
   --  rendered with KaTeX's pinned default error color, and return
   --  Policy_Visible_Command rather than Ready.
   --  Trust=True is rejected; native rendering only permits the untrusted
   --  profile. Color_Is_Text_Color requests the syntax compatibility mode.
end Math_Engine;
