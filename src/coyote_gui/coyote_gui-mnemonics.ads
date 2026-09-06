--  Coyote_GUI.Mnemonics — context-local GTK mnemonic validation.
--
--  Project: coyote

package Coyote_GUI.Mnemonics is

   type Registry is private;

   --  Reset the keys reserved for one menu, dialog, or other UI context.
   procedure Clear (Context : in out Registry);

   --  Reserve the first GTK mnemonic in Label for Context.  A duplicate key
   --  in the same registry raises Program_Error.  Escaped underscores ("__")
   --  do not define mnemonics.
   procedure Reserve
     (Context : in out Registry;
      Label   : String;
      Name    : String);

   --  Return the first mnemonic key in Label, or Character'Val (0) when the
   --  label has no GTK mnemonic.
   function Key (Label : String) return Character;

private

   type Key_Set is array (Character) of Boolean;

   type Registry is record
      Used : Key_Set := (others => False);
   end record;

end Coyote_GUI.Mnemonics;
