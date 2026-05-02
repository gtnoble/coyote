--  LLM.Tools body.
--
--  Project: pi_acme
--  For revision history, see the project version-control log.

with LLM.Tools.Bash;
with LLM.Tools.File_Ops;

package body LLM.Tools is

   function Built_In_Tools return Tool_Descriptor_Vectors.Vector is
      Result : Tool_Descriptor_Vectors.Vector;
   begin
      Result.Append (LLM.Tools.Bash.Descriptor);
      Result.Append (LLM.Tools.File_Ops.Read_Descriptor);
      Result.Append (LLM.Tools.File_Ops.Write_Descriptor);
      Result.Append (LLM.Tools.File_Ops.Edit_Descriptor);
      Result.Append (LLM.Tools.File_Ops.Find_Descriptor);
      Result.Append (LLM.Tools.File_Ops.Glob_Descriptor);
      return Result;
   end Built_In_Tools;

   procedure Execute
     (Name      :     String;
      Args_Json :     String;
      Result    : out Ada.Strings.Unbounded.Unbounded_String;
      Is_Error  : out Boolean)
   is
   begin
      if Name = "bash" then
         LLM.Tools.Bash.Execute (Args_Json, Result, Is_Error);
      elsif Name = "read" then
         LLM.Tools.File_Ops.Execute_Read (Args_Json, Result, Is_Error);
      elsif Name = "write" then
         LLM.Tools.File_Ops.Execute_Write (Args_Json, Result, Is_Error);
      elsif Name = "edit" then
         LLM.Tools.File_Ops.Execute_Edit (Args_Json, Result, Is_Error);
      elsif Name = "find" then
         LLM.Tools.File_Ops.Execute_Find (Args_Json, Result, Is_Error);
      elsif Name = "glob" then
         LLM.Tools.File_Ops.Execute_Glob (Args_Json, Result, Is_Error);
      else
         raise Unknown_Tool with "unknown tool: " & Name;
      end if;
   end Execute;

end LLM.Tools;
