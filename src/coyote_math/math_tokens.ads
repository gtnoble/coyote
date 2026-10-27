with Math_Source;
with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

--  Lex validated source into stable owned tokens with original byte spans.
package Math_Tokens is
   Max_Tokens : constant := 131_072;
   type Token_Kind is
     (Character_Token, Control_Word, Control_Symbol, Space_Token,
      Left_Group, Right_Group, Parameter, Superscript, Subscript,
      Alignment, End_Of_Input);
   type Token is record
      Kind        : Token_Kind := End_Of_Input;
      First_Byte  : Natural := 0;
      After_Byte  : Natural := 0;
      First_Scalar : Natural := 0;
      After_Scalar : Natural := 0;
      First_UTF16 : Natural := 0;
      After_UTF16 : Natural := 0;
      Code_Point  : Natural := 0;
      Text_First  : Natural := 0;
      Text_Length : Natural := 0;
      Lexeme      : Ada.Strings.Unbounded.Unbounded_String;
      Has_Invocation : Boolean := False;
      Invocation_First_Byte : Natural := 0;
      Invocation_After_Byte : Natural := 0;
   end record;
   type Stream is private;
   type Token_Sequence is array (Positive range <>) of Token;
   type Diagnostic_Kind is
     (No_Error, Invalid_Source, Token_Limit, Trailing_Escape,
      Unicode_Unsupported);

   procedure Lex
     (Input       : Math_Source.Source;
      Result      : out Stream;
      Diagnostic  : out Diagnostic_Kind;
      Error_Byte  : out Natural);
   function Count (Item : Stream) return Natural;
   function Element (Item : Stream; Index : Positive) return Token;
   function Source (Item : Stream) return String;
   procedure From_Tokens
     (Original : Stream; Items : Token_Sequence; Result : out Stream);
private
   package Token_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Token);
   type Stream is record
      Original : Math_Source.Source;
      Items    : Token_Vectors.Vector;
   end record;
end Math_Tokens;
