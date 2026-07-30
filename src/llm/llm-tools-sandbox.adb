--  LLM.Tools.Sandbox body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Containers;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Coyote_Utils;

package body LLM.Tools.Sandbox is

   use type GNATCOLL.JSON.JSON_Value_Type;

   Rule_Types : constant array (1 .. 4) of Ada.Strings.Unbounded
     .Unbounded_String :=
     (Ada.Strings.Unbounded.To_Unbounded_String ("allowWrite"),
      Ada.Strings.Unbounded.To_Unbounded_String ("denyWrite"),
      Ada.Strings.Unbounded.To_Unbounded_String ("denyRead"),
      Ada.Strings.Unbounded.To_Unbounded_String ("allowRead"));

   function Home_Dir return String is
   begin
      if Ada.Environment_Variables.Exists ("HOME") then
         return Ada.Environment_Variables.Value ("HOME");
      end if;
      return "";
   end Home_Dir;

   function Profiles_Dir return String is
      Home : constant String := Home_Dir;
   begin
      if Home'Length = 0 then
         return "";
      end if;
      return Home & "/.coyote/sandbox";
   end Profiles_Dir;

   procedure Resolve_Path
     (Path : in out Ada.Strings.Unbounded.Unbounded_String;
      Cwd  :        String)
   is
      S : constant String :=
        Ada.Strings.Unbounded.To_String (Path);
   begin
      if S = "." then
         Path := Ada.Strings.Unbounded.To_Unbounded_String (Cwd);
      elsif S'Length >= 2
        and then S (S'First .. S'First + 1) = "./"
      then
         Path := Ada.Strings.Unbounded.To_Unbounded_String
           (Cwd & "/" & S (S'First + 2 .. S'Last));
      elsif S'Length >= 2
        and then S (S'First .. S'First + 1) = "~/"
      then
         declare
            Home : constant String := Home_Dir;
         begin
            if Home'Length > 0 then
               Path := Ada.Strings.Unbounded.To_Unbounded_String
                 (Home & "/" & S (S'First + 2 .. S'Last));
            end if;
         end;
      end if;
   end Resolve_Path;

   function Available_Profiles return String_Vectors.Vector is
      Dir     : constant String := Profiles_Dir;
      Search  : Ada.Directories.Search_Type;
      Ent     : Ada.Directories.Directory_Entry_Type;
      Result  : String_Vectors.Vector;
      Filter  : constant Ada.Directories.Filter_Type :=
        (Ada.Directories.Ordinary_File => True,
         others                        => False);
   begin
      if Dir'Length = 0
        or else not Ada.Directories.Exists (Dir)
      then
         return Result;
      end if;

      Ada.Directories.Start_Search
        (Search, Dir, "*.json", Filter => Filter);

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Ent);
         declare
            Name : constant String :=
              Ada.Directories.Simple_Name (Ent);
         begin
            --  Strip ".json" suffix to get the profile name.
            if Name'Length > 5 then
               Result.Append
                 (Name (Name'First .. Name'Last - 5));
            end if;
         end;
      end loop;

      Ada.Directories.End_Search (Search);
      return Result;
   end Available_Profiles;

   function Load_Profile
     (Name : String) return GNATCOLL.JSON.JSON_Value
   is
      use type Ada.Directories.File_Kind;

      Dir  : constant String := Profiles_Dir;
      Path : constant String := Dir & "/" & Name & ".json";
   begin
      if Dir'Length = 0 then
         return GNATCOLL.JSON.JSON_Null;
      end if;

      if not Ada.Directories.Exists (Path)
        or else Ada.Directories.Kind (Path) /= Ada.Directories.Ordinary_File
      then
         return GNATCOLL.JSON.JSON_Null;
      end if;

      declare
         Raw : constant String := Coyote_Utils.Read_Whole_File (Path);
         Read_Result : constant GNATCOLL.JSON.Read_Result :=
           GNATCOLL.JSON.Read (Raw);
      begin
         if not Read_Result.Success then
            return GNATCOLL.JSON.JSON_Null;
         end if;
         return Read_Result.Value;
      end;
   end Load_Profile;

   function Build_Bwrap_Args
     (Profile_Name : String;
      Cwd         : String) return String_Vectors.Vector
   is
      type Rule_Entry is record
         Rtype    : Ada.Strings.Unbounded.Unbounded_String;
         Path     : Ada.Strings.Unbounded.Unbounded_String;
         Depth    : Natural := 0;
      end record;

      type Rule_Entry_Array is array (Positive range <>) of Rule_Entry;

      Rules   : GNATCOLL.JSON.JSON_Value;
      Args    : String_Vectors.Vector;
      Num     : Natural := 0;
   begin
      if Profile_Name'Length = 0 then
         return Args;
      end if;

      Rules := Load_Profile (Profile_Name);
      if Rules.Kind /= GNATCOLL.JSON.JSON_Object_Type then
         return Args;
      end if;

      --  Collect all rule paths with their type and depth.
      for I in Rule_Types'Range loop
         declare
            Rtype : constant String :=
              Ada.Strings.Unbounded.To_String (Rule_Types (I));
         begin
            if Rules.Has_Field (Rtype)
              and then Rules.Get (Rtype).Kind =
                GNATCOLL.JSON.JSON_Array_Type
            then
               declare
                  Arr  : constant GNATCOLL.JSON.JSON_Array :=
                    Rules.Get (Rtype).Get;
                  Path : Ada.Strings.Unbounded.Unbounded_String;
               begin
                  for J in 1 .. GNATCOLL.JSON.Length (Arr) loop
                     declare
                        Raw : constant String := GNATCOLL.JSON.Get (Arr, J).Get;
                     begin
                        Path :=
                          Ada.Strings.Unbounded.To_Unbounded_String
                            (Raw);
                        Resolve_Path (Path, Cwd);
                        if Ada.Directories.Exists
                          (Ada.Strings.Unbounded.To_String (Path))
                        then
                           Num := Num + 1;
                        end if;
                     end;
                  end loop;
               end;
            end if;
         end;
      end loop;

      --  Build the unsorted array, then sort by path depth.
      declare
         Entries : Rule_Entry_Array (1 .. Num);
         Idx     : Natural := 0;

         function Depth (S : String) return Natural is
            Count : Natural := 0;
         begin
            for C of S loop
               if C = '/' then
                  Count := Count + 1;
               end if;
            end loop;
            return Count;
         end Depth;
      begin
         --  Populate the array.
         for I in Rule_Types'Range loop
            declare
               Rtype : constant String :=
                 Ada.Strings.Unbounded.To_String (Rule_Types (I));
            begin
               if Rules.Has_Field (Rtype)
                 and then Rules.Get (Rtype).Kind =
                   GNATCOLL.JSON.JSON_Array_Type
               then
                  declare
                     Arr  : constant GNATCOLL.JSON.JSON_Array :=
                       Rules.Get (Rtype).Get;
                     Path : Ada.Strings.Unbounded.Unbounded_String;
                  begin
                     for J in 1 .. GNATCOLL.JSON.Length (Arr) loop
                        declare
                           Raw : constant String := GNATCOLL.JSON.Get (Arr, J).Get;
                        begin
                           Path :=
                             Ada.Strings.Unbounded.To_Unbounded_String
                               (Raw);
                           Resolve_Path (Path, Cwd);
                           if Ada.Directories.Exists
                             (Ada.Strings.Unbounded.To_String (Path))
                           then
                              Idx := Idx + 1;
                              Entries (Idx) :=
                                (Rtype =>
                                   Ada.Strings.Unbounded
                                     .To_Unbounded_String (Rtype),
                                 Path  => Path,
                                 Depth => Depth
                                   (Ada.Strings.Unbounded
                                     .To_String (Path)));
                           end if;
                        end;
                     end loop;
                  end;
               end if;
            end;
         end loop;

         --  Bubble-sort by depth, shallowest first.
         if Num > 1 then
            declare
               Sorted : Boolean := False;
            begin
               while not Sorted loop
                  Sorted := True;
                  for J in 1 .. Num - 1 loop
                     if Entries (J).Depth > Entries (J + 1).Depth then
                        declare
                           Tmp : constant Rule_Entry := Entries (J);
                        begin
                           Entries (J) := Entries (J + 1);
                           Entries (J + 1) := Tmp;
                           Sorted := False;
                        end;
                     end if;
                  end loop;
               end loop;
            end;
         end if;

         --  Build bwrap args in depth-sorted order.
         for J in 1 .. Num loop
            declare
               Rtype    : constant String :=
                 Ada.Strings.Unbounded.To_String (Entries (J).Rtype);
               Resolved : constant String :=
                 Ada.Strings.Unbounded.To_String (Entries (J).Path);
            begin
               if Rtype = "allowWrite" then
                  Args.Append ("--bind");
                  Args.Append (Resolved);
                  Args.Append (Resolved);
               elsif Rtype = "denyWrite" or else Rtype = "allowRead" then
                  Args.Append ("--ro-bind");
                  Args.Append (Resolved);
                  Args.Append (Resolved);
               elsif Rtype = "denyRead" then
                  Args.Append ("--tmpfs");
                  Args.Append (Resolved);
               end if;
            end;
         end loop;
      end;

      return Args;
   end Build_Bwrap_Args;

end LLM.Tools.Sandbox;
