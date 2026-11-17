--  GENERATED from the pinned KaTeX 0.16.22 dist inventory.
--  Inventory SHA-256: 445511f22cbf79b0300a505c4f096bc57066b40daaa095bd9d39fc614943604d
--  dist/katex.js SHA-256: 8f1f4fb1080439c012bb8fddf424fa253e9144ab4cdd7dc0eae0e92cd04a5e33

with Math_Model; use Math_Model;

package Math_Symbols is
   type Symbol_Record is record
      Found : Boolean := False;
      Code_Point : Natural := 0;
      Class : Atom_Class := Ordinary;
      Font : Font_Kind := Main_Regular;
   end record;
   function Lookup_Math (Name : String) return Symbol_Record;
   function Lookup_Text (Name : String) return Symbol_Record;
end Math_Symbols;
