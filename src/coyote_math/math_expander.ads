with Ada.Containers.Vectors;
with Math_Macros;
with Math_Tokens;

package Math_Expander is
   use type Math_Tokens.Token;
   Default_Max_Expand : constant := 1_000;
   Maximum_Max_Expand : constant := 10_000;
   Maximum_Tokens : constant := 131_072;
   Maximum_Diagnostic_Length : constant := 512;
   type Cursor is limited private;
   type Diagnostic_Kind is
     (No_Error, Expansion_Limit, Token_Limit, Malformed_Definition,
      Argument_Error, Scope_Error);
   type Diagnostic_Severity is (Information, Error);
   subtype Diagnostic_Length is Natural range 0 .. Maximum_Diagnostic_Length;
   type Diagnostic_Record is record
      Severity : Diagnostic_Severity := Information;
      Message : String (1 .. Maximum_Diagnostic_Length) := (others => ' ');
      Length : Diagnostic_Length := 0;
   end record;
   procedure Open
     (Input : Math_Tokens.Stream; Item : in out Cursor;
      Max_Expand : Positive := Default_Max_Expand;
      Token_Ceiling : Positive := Maximum_Tokens;
      Expansion_Only : Boolean := False);
   --  Evaluate expandable tokens without executing assignment primitives.
   function Next
     (Item : in out Cursor; Shared : in out Math_Macros.Context)
      return Math_Tokens.Token;
   function Peek
     (Item : in out Cursor; Shared : in out Math_Macros.Context)
      return Math_Tokens.Token;
   procedure Pushback (Item : in out Cursor; Value : Math_Tokens.Token);
   procedure No_Expand_Next (Item : in out Cursor);
   procedure Set_Mode (Item : in out Cursor; Regular : Boolean);
   procedure Scan_Argument
     (Item : in out Cursor; Shared : in out Math_Macros.Context;
      Result : out Math_Tokens.Stream;
      Diagnostic : out Diagnostic_Kind);
   procedure Begin_Group (Shared : in out Math_Macros.Context);
   procedure End_Group (Shared : in out Math_Macros.Context);
   procedure End_All (Shared : in out Math_Macros.Context);
   function Diagnostic (Item : Cursor) return Diagnostic_Kind;
   --  Return the most recent primitive message, owned by this cursor.
   --  Primitive messages are owned by this cursor, bounded by
   --  Maximum_Tokens records, with each message limited to
   --  Maximum_Diagnostic_Length bytes.
   function Message_Count (Item : Cursor) return Natural;
   function Diagnostic_At
     (Item : Cursor; Index : Positive) return Diagnostic_Record;
   --  Compatibility accessor for the most recent primitive message.
   function Last_Diagnostic (Item : Cursor) return Diagnostic_Record;
   function Diagnostic_Serial (Item : Cursor) return Natural;
private
   package Token_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Math_Tokens.Token);
   package Diagnostic_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Diagnostic_Record);
   type Cursor is limited record
      Input : Math_Tokens.Stream;
      Queue : Token_Vectors.Vector;
      Position : Natural := 1;
      Expanded : Natural := 0;
      Max_Expand : Positive := Default_Max_Expand;
      Status : Diagnostic_Kind := No_Error;
      Messages : Diagnostic_Vectors.Vector;
      Last_Message : Diagnostic_Record;
      Message_Serial : Natural := 0;
      Pushback_Used : Boolean := False;
      Pushed : Math_Tokens.Token;
      Returned : Natural := 0;
      Live_Tokens : Natural := 0;
      Token_Ceiling : Positive := Maximum_Tokens;
      Suppress_Next : Boolean := False;
      Regular_Mode : Boolean := False;
      Expansion_Only : Boolean := False;
      Middle_Binding : Token_Vectors.Vector;
      Double_Binding : Token_Vectors.Vector;
      Has_Middle_Binding : Boolean := False;
      Has_Double_Binding : Boolean := False;
      Middle_Once : Boolean := False;
      Double_Once : Boolean := False;
      Previous_Middle_Binding : Token_Vectors.Vector;
      Previous_Double_Binding : Token_Vectors.Vector;
      Had_Previous_Middle : Boolean := False;
      Had_Previous_Double : Boolean := False;
   end record;
end Math_Expander;
