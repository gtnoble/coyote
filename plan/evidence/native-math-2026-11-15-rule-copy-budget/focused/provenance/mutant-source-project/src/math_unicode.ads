--  GENERATED from the pinned KaTeX 0.16.22 runtime inventory.
--  Inventory SHA-256: 445511f22cbf79b0300a505c4f096bc57066b40daaa095bd9d39fc614943604d
--  dist/katex.js SHA-256: 8f1f4fb1080439c012bb8fddf424fa253e9144ab4cdd7dc0eae0e92cd04a5e33

with Ada.Strings.Unbounded;

package Math_Unicode is
   type Accent_Mode is (Math_Mode, Text_Mode);
   function Lookup_Decomposition (Code_Point : Natural) return String;
   function Lookup_Accent (Code_Point : Natural; Mode : Accent_Mode) return String;
   function Lookup_Script (Code_Point : Natural) return String;
   function Is_Superscript (Code_Point : Natural) return Boolean;
   function Is_Subscript_Lead (Code_Point : Natural) return Boolean;
   function Is_Script_Data (Code_Point : Natural) return Boolean;
end Math_Unicode;
