--  Coyote_Help body.
--
--  Project: coyote

with Ada.Directories;
with Ada.Environment_Variables;
with GNAT.OS_Lib;
with GNATCOLL.OS.Process;
with Coyote_Config;
with Coyote_Spawn;
with LLM.Skills;

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

   function Help_Data_Directory
     (Executable : String := "") return String
   is
      Base : constant String := LLM.Skills.Install_Base (Executable);
   begin
      if Base'Length = 0 then
         return "";
      end if;

      return Base & "/share";
   end Help_Data_Directory;

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

      Path              : GNAT.OS_Lib.String_Access := Locate_Yelp;
      Args              : Argument_List;
      Help_Data         : constant String := Help_Data_Directory;
      XDG_Was_Set       : constant Boolean :=
        Ada.Environment_Variables.Exists ("XDG_DATA_DIRS");
      Old_XDG_Data_Dirs : constant String :=
        Ada.Environment_Variables.Value ("XDG_DATA_DIRS", "");
      Environment_Set   : Boolean := False;

      procedure Restore_Data_Directory is
      begin
         if Environment_Set then
            if XDG_Was_Set then
               Ada.Environment_Variables.Set
                 ("XDG_DATA_DIRS", Old_XDG_Data_Dirs);
            else
               Ada.Environment_Variables.Clear ("XDG_DATA_DIRS");
            end if;
            Environment_Set := False;
         end if;
      end Restore_Data_Directory;
   begin
      if Path = null then
         return False;
      end if;

      --  Yelp resolves help: URIs through XDG data directories.  Add the
      --  executable-relative share directory for both installed binaries and
      --  development checkouts, but do not alter the parent after spawning.
      if Help_Data'Length > 0
        and then Ada.Directories.Exists
          (Help_Data & "/help/C/coyote")
      then
         if Old_XDG_Data_Dirs'Length > 0 then
            Ada.Environment_Variables.Set
              ("XDG_DATA_DIRS", Help_Data & ":" & Old_XDG_Data_Dirs);
         else
            Ada.Environment_Variables.Set ("XDG_DATA_DIRS", Help_Data);
         end if;
         Environment_Set := True;
      end if;

      Args.Append (Path.all);
      Args.Append (Help_URI (Topic));
      Coyote_Spawn.Spawn_Detached (Args);
      Restore_Data_Directory;
      GNAT.OS_Lib.Free (Path);
      Path := null;
      return True;
   exception
      when others =>
         begin
            Restore_Data_Directory;
         exception
            when others =>
               null;
         end;
         if Path /= null then
            GNAT.OS_Lib.Free (Path);
         end if;
         return False;
   end Open;

   function Product_Information_Text return String is
   begin
      return
        "coyote " & Coyote_Config.Crate_Version & ASCII.LF & ASCII.LF
        & "coyote is a native Ada LLM coding agent with GTK "
        & "and plain-text frontends." & ASCII.LF
        & "License: MIT OR Apache-2.0 WITH LLVM-exception.";
   end Product_Information_Text;

end Coyote_Help;
