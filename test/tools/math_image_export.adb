with Ada.Command_Line;
with Ada.Exceptions;
with Ada.Text_IO;
with Ada.Unchecked_Deallocation;
with Cairo;
with Cairo.Image_Surface;
with Cairo.Png;
with Cairo.Surface;
with GNATCOLL.JSON;
with Glib;
with Math_Layout;
with Math_Painter;
with Math_Raster;
with Math_Syntax;

procedure Math_Image_Export is
   use GNATCOLL.JSON;
   use type Cairo.Cairo_Status;
   use type Cairo.Cairo_Surface;

   type Byte_Array_Access is access all Cairo.Image_Surface.Byte_Array;
   procedure Release_Buffer is new Ada.Unchecked_Deallocation
     (Cairo.Image_Surface.Byte_Array, Byte_Array_Access);

   Fonts : Math_Painter.Font_Set;

   function Response
     (Id : JSON_Value;
      Status : String;
      Path : String := "";
      Width : Natural := 0;
      Height : Natural := 0;
      Baseline : Long_Float := 0.0) return JSON_Value is
      Result : constant JSON_Value := Create_Object;
   begin
      Set_Field (Result, "id", Id);
      Set_Field (Result, "status", Status);
      if Status = "ok" then
         Set_Field (Result, "png", Path);
         Set_Field (Result, "width", Integer (Width));
         Set_Field (Result, "height", Integer (Height));
         Set_Field_Long_Float (Result, "baseline", Baseline);
      end if;
      return Result;
   end Response;

   function Safe_Name (Value : String) return Boolean is
   begin
      if Value'Length = 0 or else Value'Length > 96 then
         return False;
      end if;
      for Char of Value loop
         if not (Char in 'a' .. 'z' or else Char in 'A' .. 'Z'
           or else Char in '0' .. '9' or else Char = '-'
           or else Char = '_')
         then
            return False;
         end if;
      end loop;
      return True;
   end Safe_Name;

   procedure Export (Line : String) is
      Parsed : constant Read_Result := Read (Line);
      Id : JSON_Value := JSON_Null;
   begin
      if not Parsed.Success or else Parsed.Value.Kind /= JSON_Object_Type then
         Ada.Text_IO.Put_Line
           (Write (Response (Id, "request-error"), Compact => True));
         return;
      end if;
      declare
         Request : constant JSON_Value := Parsed.Value;
      begin
         if not Has_Field (Request, "id") or else
           not Has_Field (Request, "source") or else
           not Has_Field (Request, "displayMode")
         then
            Ada.Text_IO.Put_Line
              (Write (Response (Id, "request-error"), Compact => True));
            return;
         end if;
         Id := Get (Request, "id");
         if Id.Kind /= JSON_String_Type or else
           Get (Request, "source").Kind /= JSON_String_Type or else
           Get (Request, "displayMode").Kind /= JSON_Boolean_Type
         then
            Ada.Text_IO.Put_Line
              (Write (Response (Id, "request-error"), Compact => True));
            return;
         end if;
         declare
            Name : constant String := Get (Id);
            Source : constant String := Get (Request, "source");
            Display : constant Boolean := Get (Request, "displayMode");
            Syntax_Options : Math_Syntax.Options;
         begin
            if not Safe_Name (Name) then
               Ada.Text_IO.Put_Line
                 (Write (Response (Id, "request-error"), Compact => True));
               return;
            end if;
            Syntax_Options.Display_Mode := Display;
            declare
               Document : constant Math_Syntax.Document :=
                 Math_Syntax.Parse (Source, Syntax_Options);
            begin
               if not Math_Syntax.Is_Valid (Document) then
                  Ada.Text_IO.Put_Line
                    (Write (Response (Id, "parse-error"), Compact => True));
                  return;
               end if;
               declare
                  Layout : constant Math_Layout.Box := Math_Layout.Build
                    (Document,
                     (if Display then Math_Layout.Display_Style
                      else Math_Layout.Text_Style));
               begin
                  if not Layout.Valid then
                     Ada.Text_IO.Put_Line
                       (Write (Response (Id, "layout-error"), Compact => True));
                     return;
                  end if;
                  declare
                     Scale : constant Long_Float := 24.0;
                     Image : constant Math_Raster.Image :=
                       Math_Raster.Render
                         (Fonts, Layout, Scale, (0.0, 0.0, 0.0, 1.0));
                     Width : constant Natural := Math_Raster.Width (Image);
                     Height : constant Natural := Math_Raster.Height (Image);
                     Stride : constant Natural := Math_Raster.Stride (Image);
                     Data : Byte_Array_Access := new
                       Cairo.Image_Surface.Byte_Array
                         (0 .. Stride * Height - 1);
                     Surface : Cairo.Cairo_Surface := Cairo.Null_Surface;
                     Filename : constant String :=
                       Ada.Command_Line.Argument (2) & "/" & Name & ".png";
                  begin
                     for Y in 0 .. Height - 1 loop
                        declare
                           Row : constant Math_Raster.Byte_Vectors.Vector :=
                             Math_Raster.Row_Data (Image, Y);
                        begin
                           for X in 0 .. Stride - 1 loop
                              Data (Y * Stride + X) :=
                                Cairo.Image_Surface.Byte (Row.Element (X + 1));
                           end loop;
                        end;
                     end loop;
                     Surface :=
                       Cairo.Image_Surface.Create_For_Data_Generic
                         (Data (0)'Address,
                          Cairo.Image_Surface.Cairo_Format_ARGB32,
                          Glib.Gint (Width), Glib.Gint (Height),
                          Glib.Gint (Stride));
                     if Cairo.Surface.Status (Surface) /=
                       Cairo.Cairo_Status_Success
                     then
                        raise Program_Error with
                          "Cairo surface creation failed";
                     end if;
                     if Cairo.Png.Write_To_Png (Surface, Filename) /=
                       Cairo.Cairo_Status_Success
                     then
                        raise Program_Error with "Cairo PNG write failed";
                     end if;
                     Cairo.Surface.Destroy (Surface);
                     Surface := Cairo.Null_Surface;
                     Release_Buffer (Data);
                     Ada.Text_IO.Put_Line
                       (Write
                          (Response
                             (Id, "ok", Filename, Width, Height,
                              Layout.Ascent * Scale),
                           Compact => True));
                  exception
                     when others =>
                        if Surface /= Cairo.Null_Surface then
                           Cairo.Surface.Destroy (Surface);
                        end if;
                        if Data /= null then
                           Release_Buffer (Data);
                        end if;
                        raise;
                  end;
               end;
            end;
         end;
      end;
   exception
      when Error : others =>
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "math_image_export: " & Ada.Exceptions.Exception_Message (Error));
         Ada.Text_IO.Put_Line
           (Write (Response (Id, "export-error"), Compact => True));
   end Export;

begin
   if Ada.Command_Line.Argument_Count /= 2 then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "usage: math_image_export FONT_DIRECTORY OUTPUT_DIRECTORY < requests.jsonl");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;
   Math_Painter.Load (Fonts, Ada.Command_Line.Argument (1));
   while not Ada.Text_IO.End_Of_File loop
      Export (Ada.Text_IO.Get_Line);
   end loop;
exception
   when Error : others =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "math_image_export: " & Ada.Exceptions.Exception_Information (Error));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Math_Image_Export;
