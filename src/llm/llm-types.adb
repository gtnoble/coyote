--  LLM.Types body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

package body LLM.Types is

   function "+" (Left : Usage; Right : Usage) return Usage is
   begin
      return
        (Input       => Left.Input + Right.Input,
         Output      => Left.Output + Right.Output,
         Cache_Read  => Left.Cache_Read + Right.Cache_Read,
         Cache_Write => Left.Cache_Write + Right.Cache_Write);
   end "+";

end LLM.Types;
