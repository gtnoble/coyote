--  coyote_list_sessions — print coyote sessions for the current directory.
--
--  Output is tab-separated per line:
--    UUID<TAB>name<TAB>date<TAB>snippet

with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with Session_Lister;        use Session_Lister;

procedure Coyote_List_Sessions is
   Cwd      : constant String := Ada.Directories.Current_Directory;
   Sessions : constant Session_Vectors.Vector := List_Sessions (Cwd);
begin
   for S of Sessions loop
      Ada.Text_IO.Put_Line
        (To_String (S.UUID)
         & ASCII.HT & To_String (S.Name)
         & ASCII.HT & To_String (S.Date)
         & ASCII.HT & To_String (S.Snippet));
   end loop;
   Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
end Coyote_List_Sessions;
