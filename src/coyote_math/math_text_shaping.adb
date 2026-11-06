with Ada.Unchecked_Conversion;
with Cairo;
with Glib;
with Interfaces.C;
with Interfaces.C.Strings;
with Math_Model;
with Math_Source;
with Math_Work_Control;
with System;

package body Math_Text_Shaping is
   use type Interfaces.C.int;
   use type Interfaces.C.unsigned;
   use type Math_Source.Diagnostic_Kind;
   use type System.Address;
   use type Interfaces.C.Strings.chars_ptr;

   function Context_Address is new Ada.Unchecked_Conversion
     (Cairo.Cairo_Context, System.Address);

   type Pango_Rectangle is record
      X, Y, Width, Height : Interfaces.C.int;
   end record;
   pragma Convention (C, Pango_Rectangle);

   function Font_Map_New return System.Address;
   pragma Import (C, Font_Map_New, "pango_cairo_font_map_new");
   function Font_Map_Create_Context
     (Map : System.Address) return System.Address;
   pragma Import (C, Font_Map_Create_Context, "pango_font_map_create_context");
   function Layout_New (Context : System.Address) return System.Address;
   pragma Import (C, Layout_New, "pango_layout_new");
   procedure Layout_Set_Text
     (Layout : System.Address; Text : Interfaces.C.Strings.chars_ptr;
      Length : Interfaces.C.int);
   pragma Import (C, Layout_Set_Text, "pango_layout_set_text");
   procedure Layout_Set_Font_Description
     (Layout, Description : System.Address);
   pragma Import (C, Layout_Set_Font_Description,
                  "pango_layout_set_font_description");
   procedure Layout_Get_Extents
     (Layout : System.Address; Ink, Logical : access Pango_Rectangle);
   pragma Import (C, Layout_Get_Extents, "pango_layout_get_extents");
   function Description_From_String
     (Text : Interfaces.C.Strings.chars_ptr) return System.Address;
   pragma Import (C, Description_From_String,
                  "pango_font_description_from_string");
   procedure Description_Set_Absolute_Size
     (Description : System.Address; Size : Interfaces.C.double);
   pragma Import (C, Description_Set_Absolute_Size,
                  "pango_font_description_set_absolute_size");
   procedure Description_Free (Description : System.Address);
   pragma Import (C, Description_Free, "pango_font_description_free");
   procedure Cairo_Show_Layout (Context, Layout : System.Address);
   pragma Import (C, Cairo_Show_Layout, "pango_cairo_show_layout");
   function Layout_Get_Baseline (Layout : System.Address)
      return Interfaces.C.int;
   pragma Import (C, Layout_Get_Baseline, "pango_layout_get_baseline");
   function Layout_Get_Unknown_Glyphs_Count
     (Layout : System.Address) return Interfaces.C.unsigned;
   pragma Import (C, Layout_Get_Unknown_Glyphs_Count,
                  "pango_layout_get_unknown_glyphs_count");
   procedure Cairo_Move_To
     (Context : System.Address; X, Y : Interfaces.C.double);
   pragma Import (C, Cairo_Move_To, "cairo_move_to");
   procedure Object_Unref (Object : System.Address);
   pragma Import (C, Object_Unref, "g_object_unref");
   Pango_Scale : constant Long_Float := 1_024.0;
   Default_Pixel_Em : constant Long_Float := 16.0;
   Max_Text_Bytes : constant := Math_Source.Max_Source_Bytes;

   function Is_Valid_Profile
     (Profile : Math_Model.Script_Profile) return Boolean is
      (Profile'Valid);

   function Font_For (Profile : Math_Model.Script_Profile) return String is
   begin
      case Profile is
         when Math_Model.Latin_Fallback => return "DejaVu Serif";
         when Math_Model.Cyrillic_Fallback => return "DejaVu Serif";
         when Math_Model.Armenian_Fallback => return "DejaVu Sans";
         when Math_Model.Georgian_Fallback => return "DejaVu Sans";
         when Math_Model.Hebrew_Fallback => return "DejaVu Sans";
         when Math_Model.Arabic_Fallback => return "DejaVu Sans";
         when Math_Model.Indic_Fallback => return "DejaVu Sans";
         when Math_Model.CJK_Fallback => return "Noto Sans CJK SC";
         when Math_Model.Hangul_Fallback => return "Noto Sans CJK KR";
         when Math_Model.Fullwidth_Fallback => return "Noto Sans CJK SC";
         when Math_Model.Other_Script_Fallback => return "DejaVu Sans";
      end case;
   end Font_For;

   procedure With_Layout
     (Text : String; Profile : Math_Model.Script_Profile;
      Pixel_Em : Long_Float; Cairo : System.Address := System.Null_Address;
      X, Baseline, Em, Scale : Long_Float := 0.0;
      Work : Math_Work_Control.Context_Access := null;
      Result : out Metrics) is
      Map : System.Address := System.Null_Address;
      Context : System.Address := System.Null_Address;
      Layout : System.Address := System.Null_Address;
      Description : System.Address := System.Null_Address;
      C_Text : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.Null_Ptr;
      Family : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.Null_Ptr;
      Logical : aliased Pango_Rectangle := (others => 0);
      Ink : aliased Pango_Rectangle := (others => 0);
      Effective_Em : constant Long_Float :=
        (if Pixel_Em = 0.0 then Default_Pixel_Em else Pixel_Em);
   begin
      Math_Work_Control.Poll (Work);
      if Text'Length = 0 or else Text'Length > Max_Text_Bytes or else
        not Is_Valid_Profile (Profile) or else not Pixel_Em'Valid or else
        Pixel_Em < 0.0 or else Pixel_Em > 256.0
      then
         raise Constraint_Error with "invalid Pango text run";
      end if;
      declare
         Validated : Math_Source.Source;
         Diagnostic : Math_Source.Diagnostic_Kind;
         Error_Byte : Natural;
      begin
         Math_Source.Create (Text, Validated, Diagnostic, Error_Byte, Work);
         if Diagnostic /= Math_Source.No_Error then
            raise Constraint_Error with "invalid UTF-8 Pango text run";
         end if;
      end;
      Family := Interfaces.C.Strings.New_String (Font_For (Profile));
      Description := Description_From_String (Family);
      Interfaces.C.Strings.Free (Family);
      Family := Interfaces.C.Strings.Null_Ptr;
      if Description = System.Null_Address then
         raise Program_Error with "Pango font description unavailable";
      end if;
      Description_Set_Absolute_Size
        (Description, Interfaces.C.double (Effective_Em * Pango_Scale));
      Map := Font_Map_New;
      if Map = System.Null_Address then
         raise Program_Error with "Pango font map unavailable";
      end if;
      Context := Font_Map_Create_Context (Map);
      if Context = System.Null_Address then
         raise Program_Error with "Pango context unavailable";
      end if;
      Layout := Layout_New (Context);
      if Layout = System.Null_Address then
         raise Program_Error with "Pango layout unavailable";
      end if;
      C_Text := Interfaces.C.Strings.New_String (Text);
      Layout_Set_Font_Description (Layout, Description);
      Description_Free (Description);
      Description := System.Null_Address;
      Layout_Set_Text (Layout, C_Text, Interfaces.C.int (Text'Length));
      Interfaces.C.Strings.Free (C_Text);
      C_Text := Interfaces.C.Strings.Null_Ptr;
      Math_Work_Control.Poll (Work);
      if Layout_Get_Unknown_Glyphs_Count (Layout) /= 0 then
         raise Constraint_Error with "Pango fallback has missing glyphs";
      end if;
      Layout_Get_Extents (Layout, Ink'Access, Logical'Access);
      Result.Advance := Long_Float (Logical.Width) /
        Pango_Scale / Effective_Em;
      declare
         Baseline_Pango : constant Integer :=
           Integer (Layout_Get_Baseline (Layout));
         Bottom_Pango : constant Integer :=
           Integer (Logical.Y) + Integer (Logical.Height);
      begin
         Result.Ascent := Long_Float
           (Integer'Max (0, Baseline_Pango)) / Pango_Scale / Effective_Em;
         Result.Descent := Long_Float
           (Integer'Max (0, Bottom_Pango - Baseline_Pango)) /
             Pango_Scale / Effective_Em;
      end;
      if Result.Advance < 0.0 or else Result.Advance > 16_384.0 or else
        Result.Ascent > 16_384.0 or else Result.Descent > 16_384.0 or else
        Result.Advance /= Result.Advance or else
        Result.Ascent /= Result.Ascent or else
        Result.Descent /= Result.Descent
      then
         raise Constraint_Error with "Pango metrics exceed text-run bounds";
      end if;
      if Cairo /= System.Null_Address then
         Cairo_Move_To
           (Cairo, Interfaces.C.double (X),
            Interfaces.C.double
              (Baseline - Long_Float (Layout_Get_Baseline (Layout)) /
               Pango_Scale * Em * Scale / Effective_Em));
         Math_Work_Control.Poll (Work);
         Cairo_Show_Layout (Cairo, Layout);
         Math_Work_Control.Poll (Work);
      end if;
      Object_Unref (Layout);
      Layout := System.Null_Address;
      Object_Unref (Context);
      Context := System.Null_Address;
      Object_Unref (Map);
      Map := System.Null_Address;
      Math_Work_Control.Poll (Work);
   exception
      when others =>
         if C_Text /= Interfaces.C.Strings.Null_Ptr then
            Interfaces.C.Strings.Free (C_Text);
         end if;
         if Family /= Interfaces.C.Strings.Null_Ptr then
            Interfaces.C.Strings.Free (Family);
         end if;
         if Description /= System.Null_Address then
            Description_Free (Description);
         end if;
         if Layout /= System.Null_Address then
            Object_Unref (Layout);
         end if;
         if Context /= System.Null_Address then
            Object_Unref (Context);
         end if;
         if Map /= System.Null_Address then
                  Object_Unref (Map);
         end if;
         raise;
   end With_Layout;

   function Measure
     (Text : String; Profile : Math_Model.Script_Profile;
      Pixel_Em : Long_Float := 0.0;
      Work : Math_Work_Control.Context_Access := null) return Metrics is
      Result : Metrics;
   begin
      With_Layout
        (Text, Profile, Pixel_Em, Work => Work, Result => Result);
      return Result;
   end Measure;

   procedure Draw
     (Context : Cairo.Cairo_Context; Text : String;
      Profile : Math_Model.Script_Profile;
      X, Baseline, Em, Scale : Long_Float;
      Work : Math_Work_Control.Context_Access := null) is
      Result : Metrics;
      Pixel_Em : constant Long_Float := Em * Scale;
   begin
      if not Em'Valid or else not Scale'Valid or else Em <= 0.0 or else
        Scale <= 0.0 or else Pixel_Em <= 0.0 or else Pixel_Em > 256.0
      then
         raise Constraint_Error with "invalid Pango draw scale";
      end if;
      Math_Work_Control.Poll (Work);
      Cairo.Save (Context);
      begin
         With_Layout
           (Text, Profile, Pixel_Em, Context_Address (Context),
            X => X, Baseline => Baseline, Em => Em, Scale => Scale,
            Work => Work, Result => Result);
      exception
         when others =>
            Cairo.Restore (Context);
            raise;
      end;
      Cairo.Restore (Context);
   end Draw;
end Math_Text_Shaping;
