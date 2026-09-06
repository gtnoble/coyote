--  Coyote_GUI.Mnemonics body.
--
--  Project: coyote

with Ada.Characters.Handling;

package body Coyote_GUI.Mnemonics is

   function Key (Label : String) return Character is
      Index : Integer := Label'First;
   begin
      while Index <= Label'Last loop
         if Label (Index) = '_' then
            if Index < Label'Last and then Label (Index + 1) = '_' then
               Index := Index + 2;
            elsif Index < Label'Last then
               return Ada.Characters.Handling.To_Lower (Label (Index + 1));
            else
               return Character'Val (0);
            end if;
         else
            Index := Index + 1;
         end if;
      end loop;
      return Character'Val (0);
   end Key;

   procedure Clear (Context : in out Registry) is
   begin
      Context.Used := (others => False);
   end Clear;

   procedure Reserve
     (Context : in out Registry;
      Label   : String;
      Name    : String)
   is
      Mnemonic : constant Character := Key (Label);
   begin
      if Mnemonic /= Character'Val (0) then
         if Context.Used (Mnemonic) then
            raise Program_Error with
              "duplicate mnemonic '" & Mnemonic & "' in " & Name;
         end if;
         Context.Used (Mnemonic) := True;
      end if;
   end Reserve;

end Coyote_GUI.Mnemonics;
