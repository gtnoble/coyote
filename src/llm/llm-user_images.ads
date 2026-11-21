with GNATCOLL.JSON;
with LLM.Types;

--  User PNGs are independent of assistant and tool-result images.
package LLM.User_Images is
   Max_Count : constant := 8;
   Max_PNG : constant := 8 * 1_024 * 1_024;
   Max_Turn : constant := 16 * 1_024 * 1_024;
   Max_Request : constant := 32 * 1_024 * 1_024;
   Invalid_Image : exception;

   function Byte_Count (Images : Types.User_Images.Vector) return Natural;
   procedure Check_Turn (Images : Types.User_Images.Vector);
   function Has_Images (Msg : Types.Message) return Boolean;
   function Has_Images (History : Types.Message_Vectors.Vector) return Boolean;
   procedure Check_History (History : Types.Message_Vectors.Vector);
   function Ordinal (N : Positive) return String;
   function Marker (Image : Types.User_Image; N : Positive) return String;
   function Base64 (Image : Types.User_Image) return String;
   function To_JSON (Image : Types.User_Image) return GNATCOLL.JSON.JSON_Value;
   function From_JSON (Value : GNATCOLL.JSON.JSON_Value) return Types.User_Image;
end LLM.User_Images;
