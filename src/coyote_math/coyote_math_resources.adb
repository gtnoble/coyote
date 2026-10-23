with Ada.Directories;
with Ada.Environment_Variables;
with LLM.Skills;

package body Coyote_Math_Resources is
   function Font_Directory return String is
      Base : constant String := LLM.Skills.Install_Base;
      Installed : constant String := Base & "/share/coyote/math/fonts";
      Override : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_MATH_FONTS", "");
   begin
      if Override'Length > 0 then
         return Override;
      elsif Base'Length > 0 and then Ada.Directories.Exists (Installed) then
         return Installed;
      elsif Ada.Directories.Exists ("share/coyote/math/fonts") then
         return Ada.Directories.Full_Name ("share/coyote/math/fonts");
      elsif Ada.Directories.Exists ("../share/coyote/math/fonts") then
         return Ada.Directories.Full_Name ("../share/coyote/math/fonts");
      else
         return Installed;
      end if;
   end Font_Directory;
end Coyote_Math_Resources;
