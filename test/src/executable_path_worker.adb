with Ada.Command_Line;
with Ada.Directories;
with Ada.Text_IO;
with Coyote_Utils;
with GNAT.OS_Lib;

procedure Executable_Path_Worker is
   Source_Path : constant String := Coyote_Utils.Active_Executable_Path;
   Stage_Path  : constant String := Source_Path & ".replacement";
   Renamed     : Boolean := False;
   Copied      : Boolean := False;
begin
   --  Only the temporary copy named by the caller may replace itself.
   if Ada.Command_Line.Argument_Count /= 1
     or else Ada.Command_Line.Argument (1) /= Source_Path
     or else Source_Path'Length = 0
     or else not GNAT.OS_Lib.Is_Executable_File (Source_Path)
   then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   Ada.Directories.Set_Directory ("/");
   GNAT.OS_Lib.Copy_File (Source_Path, Stage_Path, Copied,
                          Preserve => GNAT.OS_Lib.Full);
   if not Copied then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;
   GNAT.OS_Lib.Rename_File (Stage_Path, Source_Path, Renamed);
   if not Renamed then
      GNAT.OS_Lib.Delete_File (Stage_Path, Renamed);
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   if Coyote_Utils.Available_Executable_Path /= Source_Path then
      GNAT.OS_Lib.Delete_File (Source_Path, Renamed);
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   GNAT.OS_Lib.Delete_File (Source_Path, Renamed);
   if not Renamed
     or else Coyote_Utils.Available_Executable_Path'Length /= 0
   then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Output, "PASS");
end Executable_Path_Worker;
