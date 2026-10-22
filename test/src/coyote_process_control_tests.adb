with AUnit.Test_Caller;
--  Coyote_Process_Control_Tests body.
--  Project: coyote

with Ada.Directories;
with Ada.Real_Time;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with AUnit.Assertions;
with Coyote_Process_Control;
with Coyote_Process_Trees;
with Coyote_Temp_Files;
with GNAT.OS_Lib;
with GNATCOLL.OS.Process;
with LLM.Settings;

package body Coyote_Process_Control_Tests is

   use AUnit.Assertions;

   procedure Test_Grace_Clamps (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Coyote_Process_Control.Set_Grace_Seconds
        (LLM.Settings.Max_Termination_Grace_Seconds + 1);
      Assert
        (Coyote_Process_Control.Grace_Seconds
         = LLM.Settings.Max_Termination_Grace_Seconds,
         "shutdown grace should clamp to the configured maximum");
      Coyote_Process_Control.Set_Grace_Seconds (0);
      Assert
        (Coyote_Process_Control.Grace_Seconds = 0,
         "zero shutdown grace should be accepted");
   end Test_Grace_Clamps;

   procedure Test_Launches_Reject_After_Shutdown (T : in out Test) is
      pragma Unreferenced (T);
      Accepted : Boolean;
      First    : Boolean;
   begin
      Coyote_Process_Control.Begin_Launch (Accepted);
      Assert (Accepted, "launch should be accepted before shutdown");
      Coyote_Process_Control.Cancel_Launch;
      Coyote_Process_Control.Begin_Shutdown (First);
      Assert (First, "first shutdown request should be identified");
      Coyote_Process_Control.Begin_Launch (Accepted);
      Assert (not Accepted, "launch should be rejected after shutdown");
   end Test_Launches_Reject_After_Shutdown;

   procedure Test_Persistence_Freezes (T : in out Test) is
      pragma Unreferenced (T);
      Accepted : Boolean;
   begin
      Coyote_Process_Control.Begin_Persistence_Write (Accepted);
      Assert (Accepted, "write should be accepted before freeze");
      Coyote_Process_Control.End_Persistence_Write;
      Coyote_Process_Control.Freeze_Persistence;
      Coyote_Process_Control.Begin_Persistence_Write (Accepted);
      Assert (not Accepted, "writes should be rejected after freeze");
   end Test_Persistence_Freezes;

   procedure Test_Process_Stat_Parser (T : in out Test) is
      pragma Unreferenced (T);
      Parent : Integer;
   begin
      Assert
        (Coyote_Process_Trees.Parse_Stat
           ("123 (worker ) with spaces) S 45 1 1", 123, Parent),
         "stat parser should preserve comm parentheses and spaces");
      Assert (Parent = 45, "stat parser should return ppid");
      Assert
        (not Coyote_Process_Trees.Parse_Stat
           ("124 (worker) S 45 1 1", 123, Parent),
         "stat parser should reject a mismatched pid field");
      Assert (Parent = 0, "rejected records must clear the parent PID");
      Assert
        (not Coyote_Process_Trees.Parse_Stat
           ("123 (worker) S 45x 1 1", 123, Parent),
         "stat parser should reject nondigit ppid");
      Assert (Parent = 0, "rejected records must clear the parent PID");
      Assert
        (not Coyote_Process_Trees.Parse_Stat
           ("123 (worker) S -45 1 1", 123, Parent),
         "stat parser should reject negative ppid");
      Assert (Parent = 0, "rejected records must clear the parent PID");
      Assert
        (not Coyote_Process_Trees.Parse_Stat
           ("123 (worker) S 16#2D# 1 1", 123, Parent),
         "stat parser should reject based ppid syntax");
      Assert (Parent = 0, "rejected records must clear the parent PID");
      Assert
        (not Coyote_Process_Trees.Parse_Stat
           ("123 (worker) S 45_0 1 1", 123, Parent),
         "stat parser should reject underscore ppid");
      Assert (Parent = 0, "rejected records must clear the parent PID");
      Assert
        (not Coyote_Process_Trees.Parse_Stat
           ("123 (worker) ? 45 1 1", 123, Parent),
         "stat parser should reject malformed state");
      Assert (Parent = 0, "rejected records must clear the parent PID");
      Assert
        (not Coyote_Process_Trees.Parse_Stat
           ("123 (worker) S 999999999999999999999 1 1", 123, Parent),
         "stat parser should reject overflowing ppid");
      Assert (Parent = 0, "rejected records must clear the parent PID");
      Assert
        (not Coyote_Process_Trees.Parse_Stat
           ("123 (worker) S", 123, Parent),
         "stat parser should reject truncated input");
      Assert (Parent = 0, "rejected records must clear the parent PID");
      Assert
        (not Coyote_Process_Trees.Parse_Stat ("", 123, Parent),
         "stat parser should reject empty input");
      Assert (Parent = 0, "rejected records must clear the parent PID");
      Assert
        (not Coyote_Process_Trees.Parse_Stat
           ("x23 (worker) S 45 1 1", 123, Parent),
         "stat parser should reject malformed pid field");
      Assert (Parent = 0, "rejected records must clear the parent PID");
      declare
         Text : constant String := "123 (worker ) with spaces) S 45 1 1";
         Shifted : constant String (20 .. 19 + Text'Length) := Text;
      begin
         Assert
           (Coyote_Process_Trees.Parse_Stat (Shifted, 123, Parent)
            and then Parent = 45,
            "stat parser should accept non-unit string bounds");
      end;
   end Test_Process_Stat_Parser;

   procedure Test_Process_Snapshot (T : in out Test) is
      pragma Unreferenced (T);
      Small : constant Coyote_Process_Trees.Process_Record_Array :=
        ((Pid => 10, Parent => 1),
         (Pid => 11, Parent => 10),
         (Pid => 12, Parent => 11),
         (Pid => 13, Parent => 10),
         (Pid => 20, Parent => 21),
         (Pid => 21, Parent => 20));
      Large : Coyote_Process_Trees.Process_Record_Array (1 .. 9_000);
   begin
      declare
         Result : constant Coyote_Process_Trees.PID_Array :=
           Coyote_Process_Trees.Descendants (10, Small);
      begin
         Assert
           (Result'Length = 4 and then Result (1) = 10
            and then Result (2) = 11 and then Result (3) = 13
            and then Result (4) = 12,
            "snapshot should be breadth-first with nested children");
      end;
      declare
         Result : constant Coyote_Process_Trees.PID_Array :=
           Coyote_Process_Trees.Descendants (99, Small);
      begin
         Assert
           (Result'Length = 1 and then Result (1) = 99,
            "missing root without known children remains a sentinel");
      end;
      declare
         Missing_Root : constant Coyote_Process_Trees.Process_Record_Array :=
           ((Pid => 30, Parent => 99),
            (Pid => 31, Parent => 30),
            (Pid => 99, Parent => 31));
         Result : constant Coyote_Process_Trees.PID_Array :=
           Coyote_Process_Trees.Descendants (99, Missing_Root);
      begin
         Assert
           (Result'Length = 3 and then Result (1) = 99
            and then Result (2) = 30 and then Result (3) = 31,
            "missing root must traverse known children and visit cycles once");
      end;
      declare
         Result : constant Coyote_Process_Trees.PID_Array :=
           Coyote_Process_Trees.Descendants (20, Small);
      begin
         Assert
           (Result'Length = 2,
            "cycle reachable from root must visit each process once");
      end;
      declare
         Result : constant Coyote_Process_Trees.PID_Array :=
           Coyote_Process_Trees.Descendants (1, Small);
      begin
         Assert (Result'Length = 0, "unsafe root pids must not traverse");
      end;
      Large (1) := (Pid => 30, Parent => 1);
      for Position in 2 .. Large'Last loop
         Large (Position) :=
           (Pid => 30 + Position - 1, Parent => 30 + Position - 2);
      end loop;
      declare
         Result : constant Coyote_Process_Trees.PID_Array :=
           Coyote_Process_Trees.Descendants (30, Large);
      begin
         Assert
           (Result'Length = Large'Length
            and then Result (Result'Last) = 9_029,
            "large snapshot should traverse over 8192 descendants");
      end;
   end Test_Process_Snapshot;

   procedure Test_Signal_Group_Tree (T : in out Test) is
      pragma Unreferenced (T);
      use GNATCOLL.OS.Process;
      use Ada.Real_Time;
      function Getpgid (Pid : Integer) return Integer;
      pragma Import (C, Getpgid, "getpgid");
      function Kill (Pid : Integer; Signal : Integer) return Integer;
      pragma Import (C, Kill, "kill");
      function Process_Id (Handle : Process_Handle) return Integer is
        (Integer (Handle));
      Root_FD, Nested_FD, Term_FD : GNAT.OS_Lib.File_Descriptor;
      Root_Ready, Nested_Ready, Term_Marker :
        Ada.Strings.Unbounded.Unbounded_String;
      Args : Argument_List;
      Handle : Process_Handle := Invalid_Handle;
      Root_Pid : Integer := 0;
      Group_Confirmed : Boolean := False;
      Started : constant Time := Clock;
      Ignore : Integer;
      pragma Unreferenced (Ignore);

      function Shell_Quote (Value : String) return String is
         Result : Ada.Strings.Unbounded.Unbounded_String :=
           Ada.Strings.Unbounded.To_Unbounded_String ("'");
      begin
         for Ch of Value loop
            if Ch = ''' then
               Ada.Strings.Unbounded.Append (Result, "'\''");
            else
               Ada.Strings.Unbounded.Append (Result, Ch);
            end if;
         end loop;
         Ada.Strings.Unbounded.Append (Result, "'");
         return Ada.Strings.Unbounded.To_String (Result);
      end Shell_Quote;

      procedure Wait_For (Path : String) is
         Limit : constant Time := Clock + Seconds (4);
      begin
         while not Ada.Directories.Exists (Path) and then Clock < Limit loop
            delay 0.02;
         end loop;
      end Wait_For;

      function Read_Integer (Path : String) return Integer is
         File : Ada.Text_IO.File_Type;
         Line : String (1 .. 32);
         Last : Natural;
      begin
         Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
         Ada.Text_IO.Get_Line (File, Line, Last);
         Ada.Text_IO.Close (File);
         return Integer'Value (Line (1 .. Last));
      exception
         when others =>
            if Ada.Text_IO.Is_Open (File) then
               Ada.Text_IO.Close (File);
            end if;
            raise;
      end Read_Integer;

      procedure Cleanup is
         Nested_Pid : Integer := 0;
      begin
         if Ada.Strings.Unbounded.Length (Nested_Ready) > 0
           and then not Ada.Directories.Exists
             (Ada.Strings.Unbounded.To_String (Nested_Ready))
           and then Root_Pid > 1
         then
            Wait_For (Ada.Strings.Unbounded.To_String (Nested_Ready));
         end if;
         if Ada.Strings.Unbounded.Length (Nested_Ready) > 0
           and then Ada.Directories.Exists
             (Ada.Strings.Unbounded.To_String (Nested_Ready))
         then
            begin
               Nested_Pid := Read_Integer
                 (Ada.Strings.Unbounded.To_String (Nested_Ready));
            exception
               when others =>
                  Nested_Pid := 0;
            end;
         end if;
         if Nested_Pid > 1 then
            if Getpgid (Nested_Pid) = Nested_Pid then
               Ignore := Kill (-Nested_Pid, 9);
            end if;
            Ignore := Kill (Nested_Pid, 9);
         end if;
         if Root_Pid > 1 then
            begin
               Coyote_Process_Trees.Signal_Group_Tree (Root_Pid, 9);
            exception
               when others =>
                  null;
            end;
            if Group_Confirmed then
               Ignore := Kill (-Root_Pid, 9);
            end if;
            Ignore := Kill (Root_Pid, 9);
         end if;
         if Handle /= Invalid_Handle then
            declare
               Reaped : Boolean := False;
               Deadline : Time := Clock + Seconds (2);
            begin
               while not Reaped and then Clock < Deadline loop
                  Reaped := State (Handle) = TERMINATED;
                  if not Reaped then
                     delay 0.02;
                  end if;
               end loop;
               if not Reaped then
                  Ignore := Kill (Process_Id (Handle), 9);
                  Deadline := Clock + Seconds (2);
                  while not Reaped and then Clock < Deadline loop
                     Reaped := State (Handle) = TERMINATED;
                     if not Reaped then
                        delay 0.02;
                     end if;
                  end loop;
               end if;
               if Reaped then
                  Ignore := Wait (Handle);
               end if;
               Handle := Invalid_Handle;
            exception
               when others =>
                  Handle := Invalid_Handle;
            end;
         end if;
         Coyote_Temp_Files.Delete
           (Ada.Strings.Unbounded.To_String (Root_Ready));
         Coyote_Temp_Files.Delete
           (Ada.Strings.Unbounded.To_String (Nested_Ready));
         Coyote_Temp_Files.Delete
           (Ada.Strings.Unbounded.To_String (Term_Marker));
      exception
         when others =>
            null;
      end Cleanup;
   begin
      Coyote_Temp_Files.Create (Root_FD, Root_Ready);
      Coyote_Temp_Files.Create (Nested_FD, Nested_Ready);
      Coyote_Temp_Files.Create (Term_FD, Term_Marker);
      GNAT.OS_Lib.Close (Root_FD);
      GNAT.OS_Lib.Close (Nested_FD);
      GNAT.OS_Lib.Close (Term_FD);
      Coyote_Temp_Files.Delete
        (Ada.Strings.Unbounded.To_String (Root_Ready));
      Coyote_Temp_Files.Delete
        (Ada.Strings.Unbounded.To_String (Nested_Ready));
      Coyote_Temp_Files.Delete
        (Ada.Strings.Unbounded.To_String (Term_Marker));
      declare
         Nested_Script : constant String :=
           "trap 'echo term > ""$2""' TERM; echo $$ > ""$1""; "
           & "while :; do sleep 1; done";
         Script : constant String :=
           "touch " & Shell_Quote
             (Ada.Strings.Unbounded.To_String (Root_Ready)) & "; "
           & "setsid /bin/sh -c " & Shell_Quote (Nested_Script) & " sh "
           & Shell_Quote
             (Ada.Strings.Unbounded.To_String (Nested_Ready)) & " "
           & Shell_Quote
             (Ada.Strings.Unbounded.To_String (Term_Marker))
           & " & wait";
      begin
         Args.Append ("/usr/bin/setsid");
         Args.Append ("/bin/sh");
         Args.Append ("-c");
         Args.Append (Script);
      end;
      Handle := Start (Args);
      Root_Pid := Process_Id (Handle);
      Wait_For (Ada.Strings.Unbounded.To_String (Root_Ready));
      Assert
        (Ada.Directories.Exists
           (Ada.Strings.Unbounded.To_String (Root_Ready)),
         "root shell should become ready within four seconds");
      Group_Confirmed := Getpgid (Root_Pid) = Root_Pid;
      Assert
        (Group_Confirmed,
         "isolated setsid root must have PGID equal to PID");
      Wait_For (Ada.Strings.Unbounded.To_String (Nested_Ready));
      Assert
        (Ada.Directories.Exists
           (Ada.Strings.Unbounded.To_String (Nested_Ready)),
         "nested setsid shell should become ready within four seconds");
      declare
         Nested_Pid : constant Integer := Read_Integer
           (Ada.Strings.Unbounded.To_String (Nested_Ready));
      begin
         Assert
           (Nested_Pid > 1 and then Getpgid (Nested_Pid) = Nested_Pid,
            "nested process must be in its own process group");
      end;
      Assert (Clock - Started < Seconds (9), "readiness waits are bounded");
      Coyote_Process_Trees.Signal_Group_Tree (Root_Pid, 15);
      Wait_For (Ada.Strings.Unbounded.To_String (Term_Marker));
      Assert
        (Ada.Directories.Exists
           (Ada.Strings.Unbounded.To_String (Term_Marker)),
         "nested setsid descendant should receive SIGTERM");
      Cleanup;
   exception
      when others =>
         Cleanup;
         raise;
   end Test_Signal_Group_Tree;

   package Coyote_Process_Control_Caller is new AUnit.Test_Caller
     (Coyote_Process_Control_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test
        (Coyote_Process_Control_Caller.Create
           ("Coyote process control clamps shutdown grace",
            Coyote_Process_Control_Tests.Test_Grace_Clamps'Access));
      Result.Add_Test
        (Coyote_Process_Control_Caller.Create
           ("Coyote process control freezes persistence",
            Coyote_Process_Control_Tests.Test_Persistence_Freezes'Access));
      Result.Add_Test
        (Coyote_Process_Control_Caller.Create
           ("Coyote process signalling reaches nested setsid descendants",
            Coyote_Process_Control_Tests.Test_Signal_Group_Tree'Access));
      Result.Add_Test
        (Coyote_Process_Control_Caller.Create
           ("Coyote process control rejects launches after shutdown",
            Coyote_Process_Control_Tests.Test_Launches_Reject_After_Shutdown'
              Access));
      Result.Add_Test
        (Coyote_Process_Control_Caller.Create
           ("Coyote process stat parser handles proc records",
            Coyote_Process_Control_Tests.Test_Process_Stat_Parser'Access));
      Result.Add_Test
        (Coyote_Process_Control_Caller.Create
           ("Coyote process snapshot handles cycles and large trees",
            Coyote_Process_Control_Tests.Test_Process_Snapshot'Access));
      return Result;
   end Suite;

end Coyote_Process_Control_Tests;
