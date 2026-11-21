with Interfaces.C;
with Interfaces.C.Strings;
with Coyote_Canvas.Rasters;

package body Coyote_Canvas.SVG is
   use type Interfaces.C.Strings.chars_ptr;

   function C_Decode
     (Data       : Interfaces.C.char_array;
      Data_Size  : Interfaces.C.size_t;
      Max_Bytes  : Interfaces.C.size_t;
      Max_Side   : Interfaces.C.int;
      Max_Pixels : Interfaces.C.size_t;
      Message    : access Interfaces.C.Strings.chars_ptr)
      return Coyote_Image_Decoder.Pixbuf_Handle
     with Import, Convention => C,
       External_Name => "coyote_canvas_svg_decode";

   procedure Decode
     (Data   :     String;
      Pixels : out Coyote_Image_Decoder.Pixbuf_Handle;
      Error  : out Ada.Strings.Unbounded.Unbounded_String)
   is
      C_Error : aliased Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.Null_Ptr;
   begin
      Pixels := Coyote_Image_Decoder.Null_Pixbuf;
      Error := Ada.Strings.Unbounded.Null_Unbounded_String;
      if Data'Length > Coyote_Canvas.Rasters.MAX_ENCODED_BYTES then
         Error := Ada.Strings.Unbounded.To_Unbounded_String
           ("SVG input exceeds the size limit");
         return;
      end if;
      Pixels := C_Decode
        (Interfaces.C.To_C (Data), Interfaces.C.size_t (Data'Length),
         Interfaces.C.size_t (Coyote_Canvas.Rasters.MAX_ENCODED_BYTES),
         Interfaces.C.int (Coyote_Canvas.Rasters.MAX_SIDE),
         Interfaces.C.size_t (Coyote_Canvas.Rasters.MAX_PIXELS),
         C_Error'Access);
      if C_Error /= Interfaces.C.Strings.Null_Ptr then
         Error := Ada.Strings.Unbounded.To_Unbounded_String
           (Interfaces.C.Strings.Value (C_Error));
      end if;
      if Coyote_Image_Decoder.Is_Null (Pixels)
        and then Ada.Strings.Unbounded.Length (Error) = 0
      then
         Error := Ada.Strings.Unbounded.To_Unbounded_String
           ("SVG decode failed");
      end if;
   end Decode;
end Coyote_Canvas.SVG;
