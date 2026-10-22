with Ada.Containers.Ordered_Maps;
with Ada.Containers.Ordered_Sets;
with Ada.Containers.Vectors;
with Ada.Directories;
with Ada.Text_IO;
with Interfaces.C;

package body Coyote_Process_Trees is

   use type Interfaces.C.int;

   package Integer_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Integer);

   use type Integer_Vectors.Vector;

   package Record_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Process_Record);

   package Child_Maps is new Ada.Containers.Ordered_Maps
     (Key_Type     => Integer,
      Element_Type => Integer_Vectors.Vector);

   package Integer_Sets is new Ada.Containers.Ordered_Sets
     (Element_Type => Integer);

   function C_Kill
     (Pid    : Interfaces.C.int;
      Signal : Interfaces.C.int) return Interfaces.C.int
      with Import, Convention => C,
        External_Name => "coyote_process_kill";

   function C_Getpgid (Pid : Interfaces.C.int) return Interfaces.C.int
      with Import, Convention => C,
        External_Name => "coyote_process_getpgid";

   function Decimal (Value : String; Result : out Integer) return Boolean is
      Accumulator : Integer := 0;
      Digit       : Integer;
   begin
      Result := 0;
      if Value'Length = 0 then
         return False;
      end if;
      for Character of Value loop
         if Character not in '0' .. '9' then
            return False;
         end if;
         Digit := Standard.Character'Pos (Character)
           - Standard.Character'Pos ('0');
         if Accumulator > (Integer'Last - Digit) / 10 then
            return False;
         end if;
         Accumulator := Accumulator * 10 + Digit;
      end loop;
      Result := Accumulator;
      return True;
   end Decimal;

   function Parse_Stat
     (Line       : String;
      Pid        : Integer;
      Parent_Pid : out Integer) return Boolean
   is
      Open_Name  : Natural := 0;
      Close_Name : Natural := 0;
      First      : Positive;
      Last       : Natural;
      Parsed_Pid : Integer;
      Pid_End    : Natural := 0;
   begin
      Parent_Pid := 0;
      if Pid <= 0 or else Line'Length < 8 then
         return False;
      end if;
      for Position in Line'Range loop
         if Line (Position) = ' ' then
            Pid_End := Position - 1;
            exit;
         end if;
      end loop;
      if Pid_End = 0 or else Pid_End + 2 > Line'Last
        or else not Decimal (Line (Line'First .. Pid_End), Parsed_Pid)
        or else Parsed_Pid /= Pid
        or else Line (Pid_End + 1) /= ' '
        or else Line (Pid_End + 2) /= '('
      then
         return False;
      end if;
      for Position in Line'Range loop
         if Line (Position) = '(' then
            Open_Name := Position;
            exit;
         end if;
      end loop;
      for Position in reverse Line'Range loop
         if Line (Position) = ')' then
            Close_Name := Position;
            exit;
         end if;
      end loop;
      if Open_Name = 0 or else Close_Name <= Open_Name
        or else Close_Name + 3 > Line'Last
        or else Line (Close_Name + 1) /= ' '
      then
         return False;
      end if;
      First := Close_Name + 2;
      if First + 1 > Line'Last or else Line (First + 1) /= ' '
        or else Line (First) not in 'R' | 'S' | 'D' | 'Z'
          | 'T' | 't' | 'X' | 'x' | 'K'
          | 'W' | 'P' | 'I'
      then
         return False;
      end if;
      First := First + 2;
      Last := First;
      while Last <= Line'Last and then Line (Last) /= ' ' loop
         Last := Last + 1;
      end loop;
      if First > Line'Last or else Last > Line'Last then
         return False;
      end if;
      return Decimal (Line (First .. Last - 1), Parent_Pid);
   end Parse_Stat;

   function Descendants
     (Root_Pid : Integer;
      Records  : Process_Record_Array) return PID_Array
   is
      Children   : Child_Maps.Map;
      Queue      : Integer_Vectors.Vector;
      Visited    : Integer_Sets.Set;
      Index      : Positive;
   begin
      if Root_Pid <= 1 then
         return Result : PID_Array (1 .. 0);
      end if;
      for Item of Records loop
         if Item.Pid > 1 and then Item.Parent > 0 then
            if not Children.Contains (Item.Parent) then
               Children.Insert
                 (Item.Parent, Integer_Vectors.Empty_Vector);
            end if;
            Children (Item.Parent).Append (Item.Pid);
         end if;
      end loop;
      Queue.Append (Root_Pid);
      Visited.Insert (Root_Pid);
      Index := Queue.First_Index;
      while Index <= Queue.Last_Index loop
         declare
            Current : constant Integer := Queue (Index);
         begin
            if Children.Contains (Current) then
               for Child of Children (Current) loop
                  if not Visited.Contains (Child) then
                     Visited.Insert (Child);
                     Queue.Append (Child);
                  end if;
               end loop;
            end if;
         end;
         exit when Index = Queue.Last_Index;
         Index := Index + 1;
      end loop;
      return Result : PID_Array (1 .. Natural (Queue.Length)) do
         for Position in Result'Range loop
            Result (Position) := Queue (Position);
         end loop;
      end return;
   end Descendants;

   procedure Signal_Group_Tree (Root_Pid : Integer; Signal : Integer) is
      Snapshot : Record_Vectors.Vector;
      Search   : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Search_Started : Boolean := False;
      --  Linux comm can contain newlines; the fixed buffer retains the
      --  legacy limitation and is not expanded in this regression fix.
      Line     : String (1 .. 4096);
      Length   : Natural;
      Parent   : Integer;
      Pid      : Integer;
      Ignored  : Interfaces.C.int;
   begin
      if Root_Pid <= 1 or else Signal < 0 then
         return;
      end if;
      begin
         Ada.Directories.Start_Search
           (Search, "/proc", "*",
            (Ada.Directories.Ordinary_File => True,
             Ada.Directories.Directory => True,
             Ada.Directories.Special_File => True));
         Search_Started := True;
         while Ada.Directories.More_Entries (Search) loop
            Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
            declare
               Entry_Name : constant String :=
                 Ada.Directories.Simple_Name (Dir_Entry);
            begin
               if Decimal (Entry_Name, Pid) and then Pid > 0 then
                  declare
                     File : Ada.Text_IO.File_Type;
                  begin
                     Ada.Text_IO.Open
                       (File, Ada.Text_IO.In_File,
                        "/proc/" & Entry_Name & "/stat");
                     begin
                        Ada.Text_IO.Get_Line (File, Line, Length);
                        Ada.Text_IO.Close (File);
                     exception
                        when Ada.Text_IO.Status_Error |
                             Ada.Text_IO.Mode_Error |
                             Ada.Text_IO.Name_Error |
                             Ada.Text_IO.Use_Error |
                             Ada.Text_IO.Data_Error |
                             Ada.Text_IO.End_Error |
                             Ada.Text_IO.Layout_Error |
                             Ada.Text_IO.Device_Error =>
                           if Ada.Text_IO.Is_Open (File) then
                              Ada.Text_IO.Close (File);
                           end if;
                           raise;
                        when others =>
                           if Ada.Text_IO.Is_Open (File) then
                              Ada.Text_IO.Close (File);
                           end if;
                           raise;
                     end;
                     if Parse_Stat (Line (1 .. Length), Pid, Parent) then
                        Snapshot.Append
                          (Process_Record'(Pid => Pid, Parent => Parent));
                     end if;
                  exception
                     when Ada.Text_IO.Status_Error |
                          Ada.Text_IO.Mode_Error |
                          Ada.Text_IO.Name_Error |
                          Ada.Text_IO.Use_Error |
                          Ada.Text_IO.Data_Error |
                          Ada.Text_IO.End_Error |
                          Ada.Text_IO.Layout_Error |
                          Ada.Text_IO.Device_Error =>
                        null;
                  end;
               end if;
            end;
         end loop;
         Ada.Directories.End_Search (Search);
         Search_Started := False;
      exception
         when Ada.Directories.Name_Error |
              Ada.Directories.Use_Error |
              Ada.Directories.Status_Error |
              Ada.Directories.Device_Error =>
            if Search_Started then
               Ada.Directories.End_Search (Search);
               Search_Started := False;
            end if;
         when others =>
            if Search_Started then
               Ada.Directories.End_Search (Search);
               Search_Started := False;
            end if;
            raise;
      end;

      declare
         Records : Process_Record_Array (1 .. Natural (Snapshot.Length));
      begin
         for Position in Records'Range loop
            Records (Position) := Snapshot (Position);
         end loop;
         declare
            Reachable : constant PID_Array :=
              Descendants (Root_Pid, Records);
         begin
            Ignored := C_Kill
              (Interfaces.C.int (-Root_Pid), Interfaces.C.int (Signal));
            for Position in Reachable'Range loop
               declare
                  Child : constant Integer := Reachable (Position);
               begin
                  if Child /= Root_Pid then
                     Ignored := C_Kill
                       (Interfaces.C.int (Child), Interfaces.C.int (Signal));
                     if C_Getpgid (Interfaces.C.int (Child)) =
                       Interfaces.C.int (Child)
                     then
                        Ignored := C_Kill
                          (Interfaces.C.int (-Child),
                           Interfaces.C.int (Signal));
                     end if;
                  end if;
               end;
            end loop;
         end;
      end;
   exception
      when others =>
         --  Discovery is best effort.  Even allocation failure must not
         --  prevent root-group signalling or the caller's escalation pass.
         if Root_Pid > 1 and then Signal >= 0 then
            Ignored := C_Kill
              (Interfaces.C.int (-Root_Pid), Interfaces.C.int (Signal));
         end if;
   end Signal_Group_Tree;

end Coyote_Process_Trees;
