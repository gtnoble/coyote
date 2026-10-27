with Ada.Exceptions;
with Ada.Unchecked_Deallocation;
with Cairo.Font_Face;
with Glib;
with Interfaces.C;
with Interfaces.C.Strings;
with System;
with System.Address_To_Access_Conversions;
with Math_Model;
with Math_Paths;

package body Math_Painter is
   use type Cairo.Cairo_Font_Face;
   use type Cairo.Cairo_Status;
   use type Interfaces.C.unsigned;
   use type Interfaces.C.int;
   use type Interfaces.C.Strings.chars_ptr;

   function FT_Init_FreeType
     (Library : access FT_Library) return Interfaces.C.int;
   pragma Import (C, FT_Init_FreeType, "FT_Init_FreeType");

   function FT_New_Face
     (Library    : FT_Library; File_Name : Interfaces.C.Strings.chars_ptr;
      Face_Index : Interfaces.C.long; Face : access FT_Face)
      return Interfaces.C.int;
   pragma Import (C, FT_New_Face, "FT_New_Face");

   function FT_Get_Char_Index
     (Face : FT_Face; Code_Point : Interfaces.C.unsigned_long)
      return Interfaces.C.unsigned;
   pragma Import (C, FT_Get_Char_Index, "FT_Get_Char_Index");

   function FT_Done_Face (Face : FT_Face) return Interfaces.C.int;
   pragma Import (C, FT_Done_Face, "FT_Done_Face");

   function FT_Done_FreeType (Library : FT_Library) return Interfaces.C.int;
   pragma Import (C, FT_Done_FreeType, "FT_Done_FreeType");

   function Cairo_FT_Font_Face_Create_For_FT_Face
     (Face : FT_Face; Flags : Interfaces.C.int) return Cairo.Cairo_Font_Face;
   pragma Import
     (C, Cairo_FT_Font_Face_Create_For_FT_Face,
      "cairo_ft_font_face_create_for_ft_face");

   type FT_Owner is record
      Face    : FT_Face    := null;
      Library : FT_Library := null;
   end record;
   package FT_Owner_Addresses is new System.Address_To_Access_Conversions
     (FT_Owner);
   subtype FT_Owner_Access is FT_Owner_Addresses.Object_Pointer;
   use type FT_Owner_Access;
   procedure Free_Owner is new Ada.Unchecked_Deallocation
     (FT_Owner, FT_Owner_Access);

   Cairo_FT_Owner_Key : aliased Cairo.Cairo_User_Data_Key := (Unused => 0);

   procedure Destroy_FT_Owner (Address : System.Address);
   pragma Convention (C, Destroy_FT_Owner);

   type Font_Face_Array is
     array (Math_Model.Font_Kind) of Cairo.Cairo_Font_Face;
   type FT_Face_Array is array (Math_Model.Font_Kind) of FT_Face;

   type Font_State is record
      FT_Faces    : FT_Face_Array   := (others => null);
      Cairo_Faces : Font_Face_Array := (others => Cairo.Null_Font_Face);
   end record;

   procedure Free_State is new Ada.Unchecked_Deallocation
     (Font_State, Font_State_Access);

   procedure Destroy_FT_Owner (Address : System.Address) is
      Owner : FT_Owner_Access := FT_Owner_Addresses.To_Pointer (Address);
   begin
      if Owner /= null then
         if Owner.Face /= null then
            declare
               Result : constant Interfaces.C.int := FT_Done_Face (Owner.Face);
               pragma Unreferenced (Result);
            begin
               Owner.Face := null;
            end;
         end if;
         if Owner.Library /= null then
            declare
               Result : constant Interfaces.C.int :=
                 FT_Done_FreeType (Owner.Library);
               pragma Unreferenced (Result);
            begin
               Owner.Library := null;
            end;
         end if;
         Free_Owner (Owner);
      end if;
   exception
      when others =>
         null;
   end Destroy_FT_Owner;

   procedure Release (Data : in out Font_State) is
   begin
      for Kind in Math_Model.Font_Kind loop
         if Data.Cairo_Faces (Kind) /= Cairo.Null_Font_Face then
            Cairo.Font_Face.Destroy (Data.Cairo_Faces (Kind));
            Data.Cairo_Faces (Kind) := Cairo.Null_Font_Face;
         end if;
      end loop;
      --  Cairo user data owns each face and its library.
      Data.FT_Faces := (others => null);
   end Release;

   function Font_File
     (Directory : String; Kind : Math_Model.Font_Kind) return String
   is
      Name : constant String :=
        (case Kind is
           when Math_Model.AMS_Regular => "KaTeX_AMS-Regular.ttf",
           when Math_Model.Caligraphic_Bold =>
             "KaTeX_Caligraphic-Bold.ttf",
           when Math_Model.Caligraphic_Regular =>
             "KaTeX_Caligraphic-Regular.ttf",
           when Math_Model.Fraktur_Bold => "KaTeX_Fraktur-Bold.ttf",
           when Math_Model.Fraktur_Regular => "KaTeX_Fraktur-Regular.ttf",
           when Math_Model.Main_Regular => "KaTeX_Main-Regular.ttf",
           when Math_Model.Main_Bold => "KaTeX_Main-Bold.ttf",
           when Math_Model.Main_Bold_Italic =>
             "KaTeX_Main-BoldItalic.ttf",
           when Math_Model.Main_Italic => "KaTeX_Main-Italic.ttf",
           when Math_Model.Math_Bold_Italic =>
             "KaTeX_Math-BoldItalic.ttf",
           when Math_Model.Math_Italic => "KaTeX_Math-Italic.ttf",
           when Math_Model.Sans_Serif_Bold =>
             "KaTeX_SansSerif-Bold.ttf",
           when Math_Model.Sans_Serif_Italic =>
             "KaTeX_SansSerif-Italic.ttf",
           when Math_Model.Sans_Serif_Regular =>
             "KaTeX_SansSerif-Regular.ttf",
           when Math_Model.Script_Regular => "KaTeX_Script-Regular.ttf",
           when Math_Model.Size_1 => "KaTeX_Size1-Regular.ttf",
           when Math_Model.Size_2 => "KaTeX_Size2-Regular.ttf",
           when Math_Model.Size_3 => "KaTeX_Size3-Regular.ttf",
           when Math_Model.Size_4 => "KaTeX_Size4-Regular.ttf",
           when Math_Model.Typewriter_Regular =>
             "KaTeX_Typewriter-Regular.ttf");
   begin
      if Directory'Length = 0 then
         return Name;
      elsif Directory (Directory'Last) = '/' then
         return Directory & Name;
      else
         return Directory & "/" & Name;
      end if;
   end Font_File;

   procedure Check_Cairo (Context : Cairo.Cairo_Context) is
   begin
      if Cairo.Status (Context) /= Cairo.Cairo_Status_Success then
         raise Font_Error with "Cairo drawing failed";
      end if;
   end Check_Cairo;

   procedure Load (Fonts : in out Font_Set; Directory : String) is
      Data : Font_State_Access := null;
   begin
      if Fonts.Data /= null then
         raise Font_Error with "font set is already loaded";
      end if;
      Data := new Font_State;
      for Kind in Math_Model.Font_Kind loop
         declare
            Path     : constant String := Font_File (Directory, Kind);
            C_Path   : Interfaces.C.Strings.chars_ptr :=
              Interfaces.C.Strings.New_String (Path);
            New_Face : aliased FT_Face                := null;
            Library  : aliased FT_Library             := null;
            Owner    : FT_Owner_Access                := null;
            Result   : Interfaces.C.int;
         begin
            Result := FT_Init_FreeType (Library'Access);
            if Result /= 0 then
               raise Font_Error with "FT_Init_FreeType failed: " & Path;
            end if;
            Result := FT_New_Face (Library, C_Path, 0, New_Face'Access);
            Interfaces.C.Strings.Free (C_Path);
            C_Path := Interfaces.C.Strings.Null_Ptr;
            if Result /= 0 then
               raise Font_Error with "cannot load exact font file: " & Path;
            end if;
            Owner := new FT_Owner'(Face => New_Face, Library => Library);
            Data.FT_Faces (Kind)    := New_Face;
            Data.Cairo_Faces (Kind) :=
              Cairo_FT_Font_Face_Create_For_FT_Face (Data.FT_Faces (Kind), 0);
            if Data.Cairo_Faces (Kind) = Cairo.Null_Font_Face
              or else Cairo.Font_Face.Status (Data.Cairo_Faces (Kind)) /=
                Cairo.Cairo_Status_Success
            then
               raise Font_Error with "cannot create Cairo face: " & Path;
            end if;
            declare
               Set_Result : constant Cairo.Cairo_Status :=
                 Cairo.Font_Face.Set_User_Data
                   (Data.Cairo_Faces (Kind), Cairo_FT_Owner_Key'Access,
                    FT_Owner_Addresses.To_Address (Owner),
                    Destroy_FT_Owner'Access);
            begin
               if Set_Result /= Cairo.Cairo_Status_Success then
                  Destroy_FT_Owner (FT_Owner_Addresses.To_Address (Owner));
                  Owner                := null;
                  New_Face             := null;
                  Library              := null;
                  Data.FT_Faces (Kind) := null;
                  raise Font_Error
                    with "cannot attach FreeType owner to Cairo face: " & Path;
               end if;
               Owner    := null;
               New_Face := null;
               Library  := null;
            end;
         exception
            when others =>
               if C_Path /= Interfaces.C.Strings.Null_Ptr then
                  Interfaces.C.Strings.Free (C_Path);
               end if;
               if Owner /= null then
                  Destroy_FT_Owner (FT_Owner_Addresses.To_Address (Owner));
               else
                  if New_Face /= null then
                     declare
                        Done_Result : constant Interfaces.C.int :=
                          FT_Done_Face (New_Face);
                        pragma Unreferenced (Done_Result);
                     begin
                        New_Face := null;
                     end;
                  end if;
                  if Library /= null then
                     declare
                        Done_Result : constant Interfaces.C.int :=
                          FT_Done_FreeType (Library);
                        pragma Unreferenced (Done_Result);
                     begin
                        Library := null;
                     end;
                  end if;
               end if;
               raise;
         end;
      end loop;
      Fonts.Data := Data;
   exception
      when Font_Error =>
         if Data /= null then
            Release (Data.all);
            Free_State (Data);
         end if;
         raise;
      when E : others =>
         if Data /= null then
            Release (Data.all);
            Free_State (Data);
         end if;
         Ada.Exceptions.Reraise_Occurrence (E);
   end Load;

   procedure Draw
     (Fonts : Font_Set; Context : Cairo.Cairo_Context; Item : Math_Layout.Box;
      X     : Long_Float; Baseline : Long_Float; Em : Long_Float)
   is
      Saved : Boolean := False;
   begin
      if Fonts.Data = null then
         raise Font_Error with "font set is not loaded";
      end if;
      if not Item.Valid then
         raise Font_Error with "cannot draw invalid layout box";
      end if;
      if not X'Valid or else not Baseline'Valid or else not Em'Valid
        or else abs X > Long_Float'Last or else abs Baseline > Long_Float'Last
        or else Em <= 0.0 or else Em > 256.0
      then
         raise Font_Error with "invalid drawing scale or origin";
      end if;
      Check_Cairo (Context);
      Cairo.Save (Context);
      Saved := True;
      if not Item.Commands.Is_Empty then
         for Index in Item.Commands.First_Index .. Item.Commands.Last_Index
         loop
            declare
               Command : constant Math_Layout.Draw_Command :=
                 Item.Commands (Index);
               Clip_Saved : Boolean := False;
            begin
               if not Command.X'Valid or else not Command.Y'Valid
                 or else not Command.Scale'Valid
                 or else not Command.Width'Valid
                 or else not Command.Height'Valid
                 or else abs Command.X > Long_Float'Last
                 or else abs Command.Y > Long_Float'Last
                 or else Command.Scale <= 0.0 or else Command.Scale > 256.0
                 or else Command.Width < 0.0 or else Command.Height < 0.0
               then
                  raise Font_Error with "invalid drawing command geometry";
               end if;
               if Command.Has_Clip then
                  if not Command.Clip_X'Valid or else
                    not Command.Clip_Y'Valid or else
                    not Command.Clip_W'Valid or else
                    not Command.Clip_H'Valid or else
                    Command.Clip_W < 0.0 or else Command.Clip_H < 0.0
                  then
                     raise Font_Error with "invalid drawing clip geometry";
                  end if;
                  Cairo.Save (Context);
                  Clip_Saved := True;
                  Cairo.Rectangle
                    (Context,
                     Glib.Gdouble (X + (Command.X + Command.Clip_X) * Em),
                     Glib.Gdouble
                       (Baseline + (Command.Y + Command.Clip_Y) * Em),
                     Glib.Gdouble (Command.Clip_W * Em),
                     Glib.Gdouble (Command.Clip_H * Em));
                  Cairo.Clip (Context);
               end if;
               case Command.Kind is
                  when Math_Layout.Glyph_Command =>
                     declare
                        Glyph_Index : constant Interfaces.C.unsigned :=
                          FT_Get_Char_Index
                            (Fonts.Data.FT_Faces (Command.Font),
                             Interfaces.C.unsigned_long (Command.Code_Point));
                        Glyph       : aliased Cairo.Cairo_Glyph      :=
                          (Index  => Glib.Gulong (Glyph_Index),
                           X      => Glib.Gdouble (X + Command.X * Em),
                           Y      => Glib.Gdouble (Baseline + Command.Y * Em),
                           others => <>);
                     begin
                        if Command.Code_Point > 16#10_FFFF# then
                           raise Font_Error with "invalid Unicode code point";
                        end if;
                        if Glyph_Index = 0 then
                           raise Font_Error with "font lacks requested glyph";
                        end if;
                        Cairo.Set_Font_Face
                          (Context, Fonts.Data.Cairo_Faces (Command.Font));
                        Cairo.Set_Font_Size
                          (Context, Glib.Gdouble (Em * Command.Scale));
                        Cairo.Show_Glyphs (Context, Glyph'Access, 1);
                     end;
                  when Math_Layout.Path_Command =>
                     declare
                        Segment : Math_Paths.Segment;
                        function PX (Value : Long_Float) return Glib.Gdouble is
                          (Glib.Gdouble (X + (Command.X + Value) * Em));
                        function PY (Value : Long_Float) return Glib.Gdouble is
                          (Glib.Gdouble (Baseline + (Command.Y + Value) * Em));
                     begin
                        if Command.Path_Data.Is_Empty then
                           raise Font_Error with "empty path command";
                        end if;
                        if Command.Has_Color then
                           Cairo.Set_Source_Rgba
                             (Context, Glib.Gdouble (Command.Red),
                              Glib.Gdouble (Command.Green),
                              Glib.Gdouble (Command.Blue),
                              Glib.Gdouble (Command.Alpha));
                        end if;
                        for Part in Command.Path_Data.First_Index ..
                          Command.Path_Data.Last_Index
                        loop
                           Segment := Command.Path_Data (Part);
                           case Segment.Kind is
                              when Math_Paths.Move_To =>
                                 Cairo.Move_To
                                   (Context, PX (Segment.First.X),
                                    PY (Segment.First.Y));
                              when Math_Paths.Line_To =>
                                 Cairo.Line_To
                                   (Context, PX (Segment.First.X),
                                    PY (Segment.First.Y));
                              when Math_Paths.Cubic_To =>
                                 Cairo.Curve_To
                                   (Context, PX (Segment.First.X),
                                    PY (Segment.First.Y),
                                    PX (Segment.Second.X),
                                    PY (Segment.Second.Y),
                                    PX (Segment.Third.X),
                                    PY (Segment.Third.Y));
                              when Math_Paths.Close_Path =>
                                 Cairo.Close_Path (Context);
                           end case;
                        end loop;
                        Cairo.Fill (Context);
                     end;
                  when Math_Layout.Rule_Command =>
                     if Command.Width < 0.0 or else Command.Height < 0.0 then
                        raise Font_Error with "invalid rule geometry";
                     end if;
                     Cairo.Rectangle
                       (Context, Glib.Gdouble (X + Command.X * Em),
                        Glib.Gdouble (Baseline + Command.Y * Em),
                        Glib.Gdouble (Command.Width * Em),
                        Glib.Gdouble (Command.Height * Em));
                     Cairo.Fill (Context);
               end case;
               if Clip_Saved then
                  Cairo.Restore (Context);
                  Clip_Saved := False;
               end if;
               Check_Cairo (Context);
            exception
               when others =>
                  if Clip_Saved then
                     begin
                        Cairo.Restore (Context);
                     exception
                        when others =>
                           null;
                     end;
                     Clip_Saved := False;
                  end if;
                  raise;
            end;
         end loop;
      end if;
      Cairo.Restore (Context);
      Saved := False;
      Check_Cairo (Context);
   exception
      when E : others =>
         if Saved then
            begin
               Cairo.Restore (Context);
            exception
               when others =>
                  null;
            end;
         end if;
         Ada.Exceptions.Reraise_Occurrence (E);
   end Draw;

   overriding procedure Finalize (Fonts : in out Font_Set) is
   begin
      if Fonts.Data /= null then
         Release (Fonts.Data.all);
         Free_State (Fonts.Data);
      end if;
   end Finalize;

end Math_Painter;
