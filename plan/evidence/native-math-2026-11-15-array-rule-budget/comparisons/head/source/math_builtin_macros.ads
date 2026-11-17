--  Generated from KaTeX 0.16.22 builtin macro templates.
--  Inventory SHA-256: 445511f22cbf79b0300a505c4f096bc57066b40daaa095bd9d39fc614943604d
--  dist/katex.js SHA-256: 8f1f4fb1080439c012bb8fddf424fa253e9144ab4cdd7dc0eae0e92cd04a5e33

with Ada.Strings.Unbounded;

package Math_Builtin_Macros is
   Supported_String_Macro_Count : constant := 318;
   Callable_Macro_Count : constant := 20;
   type Macro_Record is record
      Found : Boolean := False;
      Template : Ada.Strings.Unbounded.Unbounded_String;
      Num_Params : Natural := 0;
   end record;
   function Lookup (Name : String) return Macro_Record;
end Math_Builtin_Macros;
