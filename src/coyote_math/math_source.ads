with Ada.Strings.Unbounded;
with Ada.Containers.Vectors;

--  Owns exact UTF-8 input and maps scalar boundaries to byte and UTF-16
--  offsets. Construction validates but never normalizes source text.
package Math_Source is
   Max_Source_Bytes : constant := 65_536;
   type Source is private;
   type Diagnostic_Kind is
     (No_Error, Source_Too_Large, Empty_Source, Invalid_UTF8,
      Forbidden_Control);


   procedure Create
     (Text      : String;
      Item      : out Source;
      Diagnostic : out Diagnostic_Kind;
      Error_Byte : out Natural);
   function Is_Valid (Item : Source) return Boolean;
   function Text (Item : Source) return String;
   function Byte_Length (Item : Source) return Natural;
   function Scalar_Length (Item : Source) return Natural;
   function UTF16_Length (Item : Source) return Natural;
   function Byte_Offset
     (Item : Source; Scalar_Boundary : Natural) return Natural;
   function UTF16_Offset
     (Item : Source; Scalar_Boundary : Natural) return Natural;
   function Scalar_Boundary
     (Item : Source; Byte_Offset : Natural) return Natural;
private
   package Offset_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Natural);
   type Source is record
      Value       : Ada.Strings.Unbounded.Unbounded_String;
      Byte_Map    : Offset_Vectors.Vector;
      UTF16_Map   : Offset_Vectors.Vector;
      Byte_Count  : Natural := 0;
      Scalar_Count : Natural := 0;
      UTF16_Count : Natural := 0;
      Valid       : Boolean := False;
   end record;
end Math_Source;
