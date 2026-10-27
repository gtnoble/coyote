with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Math_Tokens;

package Math_Macros is
   use type Math_Tokens.Token;
   Max_Definitions : constant := 32_768;
   type Token_Sequence is array (Positive range <>) of Math_Tokens.Token;
   type Definition is private;
   type Context is limited private;
   type Diagnostic_Kind is
     (No_Error, Definition_Limit, Scope_Limit, Unbalanced_Group);
   procedure Reset (Item : in out Context);
   procedure Begin_Group (Item : in out Context);
   procedure End_Group (Item : in out Context);
   --  Restore the scope stack to Depth; an impossible depth records
   --  Unbalanced_Group without changing definitions.
   procedure Restore_To_Depth (Item : in out Context; Depth : Natural);
   function Scope_Depth (Item : Context) return Natural;
   --  Unwind every scope. Parsers with shared contexts should instead
   --  restore their entry depth.
   procedure End_All (Item : in out Context);
   procedure Define
     (Item : in out Context; Name : String; Num_Params : Natural;
      Replacement : Math_Tokens.Stream; First : Positive; Last : Natural;
      Is_Global : Boolean; Diagnostic : out Diagnostic_Kind);
   procedure Define_Tokens
     (Item : in out Context; Name : String; Num_Params : Natural;
      Replacement : Token_Sequence; Is_Global : Boolean;
      Diagnostic : out Diagnostic_Kind);
   procedure Set_Optional_Default
     (Item : in out Context; Name : String;
      Replacement : Token_Sequence; Diagnostic : out Diagnostic_Kind);
   procedure Copy_Definition
     (Item : in out Context; Target, Source : String; Is_Global : Boolean;
      Diagnostic : out Diagnostic_Kind);
   function Is_Defined (Item : Context; Name : String) return Boolean;
   function Lookup (Item : Context; Name : String) return Definition;
   function Name_Of (Item : Definition) return String;
   function Num_Params (Item : Definition) return Natural;
   function Has_Optional_Default (Item : Definition) return Boolean;
   function Default_Token_Count (Item : Definition) return Natural;
   function Default_Token_At
     (Item : Definition; Index : Positive) return Math_Tokens.Token;
   function Token_Count (Item : Definition) return Natural;
   function Token_At
     (Item : Definition; Index : Positive) return Math_Tokens.Token;
   function Definition_Count (Item : Context) return Natural;
   --  Return the definition at its current context index without changing it.
   function Definition_At
     (Item : Context; Index : Positive) return Definition;
   function Diagnostic (Item : Context) return Diagnostic_Kind;
private
   package Token_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Math_Tokens.Token);
   type Definition is record
      Name : Ada.Strings.Unbounded.Unbounded_String;
      Num_Params : Natural := 0;
      Optional_Default : Token_Vectors.Vector;
      Has_Default : Boolean := False;
      Tokens : Token_Vectors.Vector;
   end record;
   package Definition_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Definition);
   type Undo is record
      Name : Ada.Strings.Unbounded.Unbounded_String;
      Had_Value : Boolean := False;
      Previous : Definition;
   end record;
   package Undo_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Undo);
   use type Undo_Vectors.Vector;
   package Scope_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Undo_Vectors.Vector);
   type Context is limited record
      Definitions : Definition_Vectors.Vector;
      Scopes : Scope_Vectors.Vector;
      Status : Diagnostic_Kind := No_Error;
   end record;
end Math_Macros;
