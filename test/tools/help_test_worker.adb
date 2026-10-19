--  Help_Test_Worker — isolated probe for the real detached Help launcher.
--
--  Project: coyote

with Ada.Command_Line;
with Ada.Environment_Variables;
with Ada.Text_IO;
with Coyote_Help;

procedure Help_Test_Worker is
   package Env renames Ada.Environment_Variables;
   Was_Set : constant Boolean := Env.Exists ("XDG_DATA_DIRS");
   Old_XDG : constant String := Env.Value ("XDG_DATA_DIRS", "");
   Opened  : Boolean;
begin
   if Ada.Command_Line.Argument_Count /= 2 then
      raise Program_Error with "usage: help_test_worker TOPIC true|false";
   end if;
   Opened := Coyote_Help.Open (Ada.Command_Line.Argument (1));
   if Opened /= Boolean'Value (Ada.Command_Line.Argument (2)) then
      raise Program_Error with "unexpected Help launch result";
   end if;
   if Env.Exists ("XDG_DATA_DIRS") /= Was_Set
     or else Env.Value ("XDG_DATA_DIRS", "") /= Old_XDG
   then
      raise Program_Error with "Help changed the parent XDG_DATA_DIRS";
   end if;
   if Opened then
      if not Coyote_Help.Yelp_Available then
         raise Program_Error with "controlled fake Yelp was not detected";
      end if;
   else
      if Coyote_Help.Yelp_Available then
         raise Program_Error with "missing-viewer probe found Yelp";
      end if;
      if Coyote_Help.Product_Information_Text'Length = 0 then
         raise Program_Error with "Product Information requires Yelp";
      end if;
   end if;
   Ada.Text_IO.Put_Line ("Help launcher probe passed");
end Help_Test_Worker;
