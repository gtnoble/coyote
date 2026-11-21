--  coyote_list_sessions — print coyote sessions for the current directory.
--
--  Output is tab-separated per line:
--    UUID<TAB>name<TAB>date<TAB>snippet

with Ada.Command_Line;
with Ada.Directories;
with Session_Lister;

procedure Coyote_List_Sessions is
begin
   Session_Lister.Print_TSV (Ada.Directories.Current_Directory);
   Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
end Coyote_List_Sessions;
