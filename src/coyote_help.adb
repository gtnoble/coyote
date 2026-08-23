--  Coyote_Help body.
--
--  Project: coyote

with GNAT.OS_Lib;
with GNATCOLL.OS.Process;
with Coyote_Spawn;

package body Coyote_Help is

   use type GNAT.OS_Lib.String_Access;

   function Help_URI (Topic : String := "") return String is
   begin
      if Topic'Length = 0 then
         return "help:coyote";
      else
         return "help:coyote/" & Topic;
      end if;
   end Help_URI;

   function Locate_Yelp return GNAT.OS_Lib.String_Access is
   begin
      return GNAT.OS_Lib.Locate_Exec_On_Path ("yelp");
   end Locate_Yelp;

   function Topic_For_Area (Area : String) return String is
   begin
      if Area = "menu" then
         return "ui-menu";
      elsif Area = "prompt" then
         return "ui-prompt";
      elsif Area = "controls" then
         return "ui-controls";
      elsif Area = "status" then
         return "ui-status";
      elsif Area = "transcript" then
         return "ui-transcript";
      else
         return "ui-conversation";
      end if;
   end Topic_For_Area;

   function Yelp_Available return Boolean is
      Path : GNAT.OS_Lib.String_Access := Locate_Yelp;
      Found : constant Boolean := Path /= null;
   begin
      if Path /= null then
         GNAT.OS_Lib.Free (Path);
      end if;
      return Found;
   end Yelp_Available;

   function Open (Topic : String := "") return Boolean is
      use GNATCOLL.OS.Process;
      Path : GNAT.OS_Lib.String_Access := Locate_Yelp;
      Args : Argument_List;
   begin
      if Path = null then
         return False;
      end if;

      Args.Append (Path.all);
      Args.Append (Help_URI (Topic));
      Coyote_Spawn.Spawn_Detached (Args);
      GNAT.OS_Lib.Free (Path);
      Path := null;
      return True;
   exception
      when others =>
         if Path /= null then
            GNAT.OS_Lib.Free (Path);
         end if;
         return False;
   end Open;

end Coyote_Help;
