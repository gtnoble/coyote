with AUnit.Test_Caller;
with AUnit.Test_Suites;
--  Unit tests for LLM.Tools.Sandbox — profile discovery, loading, and
--  bwrap argument construction.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Real_Time;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with AUnit.Assertions;
with GNATCOLL.JSON;
with LLM.Tools;
with LLM.Tools.Sandbox;
with LLM.Tools.Shell;

package body Sandbox_Tests is

   use AUnit.Assertions;
   use type GNATCOLL.JSON.JSON_Value_Type;

   function Contains (Text : String; Pattern : String) return Boolean is
   begin
      return Ada.Strings.Fixed.Index (Text, Pattern) > 0;
   end Contains;

   procedure Write_File (Path : String; Content : String) is
      F : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (F, Content);
      Ada.Text_IO.Close (F);
   end Write_File;

   overriding procedure Set_Up (T : in out Test) is
      Home : constant String := Ada.Directories.Current_Directory
        & "/sandbox_test_home";
      Sandbox_Dir : constant String := Home & "/.coyote/sandbox";
   begin
      if not Ada.Directories.Exists (Sandbox_Dir) then
         Ada.Directories.Create_Path (Sandbox_Dir);
      end if;
      T.Temp_Home := To_Unbounded_String (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
   end Set_Up;

   overriding procedure Tear_Down (T : in out Test) is
      Home : constant String := To_String (T.Temp_Home);
   begin
      if Home'Length > 0
        and then Ada.Directories.Exists (Home)
      then
         Ada.Directories.Delete_Tree (Home);
      end if;
   end Tear_Down;

   --  ── Profiles_Dir ─────────────────────────────────────────────────────

   procedure Test_Profiles_Dir_Returns_Path (T : in out Test) is
      pragma Unreferenced (T);
      Dir : constant String := LLM.Tools.Sandbox.Profiles_Dir;
   begin
      Assert
        (Contains (Dir, ".coyote/sandbox"),
         "Profiles_Dir should contain .coyote/sandbox, got: " & Dir);
   end Test_Profiles_Dir_Returns_Path;

   --  ── Available_Profiles ───────────────────────────────────────────────

   procedure Test_Available_Profiles_Empty (T : in out Test) is
      pragma Unreferenced (T);
      Profiles : constant LLM.Tools.Sandbox.String_Vectors.Vector :=
        LLM.Tools.Sandbox.Available_Profiles;
   begin
      Assert
        (Profiles.Is_Empty,
         "Available_Profiles should be empty when no profiles exist");
   end Test_Available_Profiles_Empty;

   procedure Test_Available_Profiles_Found (T : in out Test) is
      pragma Unreferenced (T);
      Dir  : constant String := LLM.Tools.Sandbox.Profiles_Dir;
      Path : constant String := Dir & "/test1.json";
   begin
      Write_File (Path,
                  "{""allowWrite"":[],"
                  & """denyWrite"":[],"
                  & """denyRead"":[],"
                  & """allowRead"":[]}");

      declare
         Profiles : constant LLM.Tools.Sandbox.String_Vectors.Vector :=
           LLM.Tools.Sandbox.Available_Profiles;
      begin
         Assert
           (not Profiles.Is_Empty,
            "Available_Profiles should find test1 profile");
         Assert
           (Profiles.First_Element = "test1",
            "First profile should be 'test1', got: "
            & Profiles.First_Element);
      end;
   end Test_Available_Profiles_Found;

   --  ── Load_Profile ─────────────────────────────────────────────────────

   procedure Test_Load_Profile_Found (T : in out Test) is
      pragma Unreferenced (T);
      Dir  : constant String := LLM.Tools.Sandbox.Profiles_Dir;
      Path : constant String := Dir & "/load_test.json";
   begin
      Write_File
        (Path,
         "{""allowWrite"":[""foo""],""denyWrite"":[],"
         & """denyRead"":[],""allowRead"":[]}");

      declare
         Profile : constant GNATCOLL.JSON.JSON_Value :=
           LLM.Tools.Sandbox.Load_Profile ("load_test");
      begin
         Assert
           (Profile.Kind = GNATCOLL.JSON.JSON_Object_Type,
            "Load_Profile should return an object for a valid profile");
         Assert
           (Profile.Has_Field ("allowWrite"),
            "Profile should have allowWrite field");
         Assert
           (GNATCOLL.JSON.Length (Profile.Get ("allowWrite").Get) = 1,
            "allowWrite array should have 1 element");
      end;
   end Test_Load_Profile_Found;

   procedure Test_Load_Profile_Not_Found (T : in out Test) is
      pragma Unreferenced (T);
      Profile : constant GNATCOLL.JSON.JSON_Value :=
        LLM.Tools.Sandbox.Load_Profile ("nosuchprofile");
   begin
      Assert
        (Profile.Kind = GNATCOLL.JSON.JSON_Null_Type,
         "Load_Profile should return JSON_Null for missing profile");
   end Test_Load_Profile_Not_Found;

   procedure Test_Load_Profile_Bad_Json (T : in out Test) is
      pragma Unreferenced (T);
      Dir  : constant String := LLM.Tools.Sandbox.Profiles_Dir;
      Path : constant String := Dir & "/bad_json.json";
   begin
      Write_File (Path, "not valid json");

      declare
         Profile : constant GNATCOLL.JSON.JSON_Value :=
           LLM.Tools.Sandbox.Load_Profile ("bad_json");
      begin
         Assert
           (Profile.Kind = GNATCOLL.JSON.JSON_Null_Type,
            "Load_Profile should return JSON_Null for bad JSON");
      end;
   end Test_Load_Profile_Bad_Json;

   --  ── Build_Bwrap_Args ─────────────────────────────────────────────────

   procedure Test_Bbuild_Empty_Profile (T : in out Test) is
      pragma Unreferenced (T);
      Args : constant LLM.Tools.Sandbox.String_Vectors.Vector :=
        LLM.Tools.Sandbox.Build_Bwrap_Args ("", "/some/cwd");
   begin
      Assert
        (Args.Is_Empty,
         "Build_Bwrap_Args should return empty for empty profile name");
   end Test_Bbuild_Empty_Profile;

   procedure Test_Bbuild_Non_Existent_Profile (T : in out Test) is
      pragma Unreferenced (T);
      Args : constant LLM.Tools.Sandbox.String_Vectors.Vector :=
        LLM.Tools.Sandbox.Build_Bwrap_Args ("no_such", "/some/cwd");
   begin
      Assert
        (Args.Is_Empty,
         "Build_Bwrap_Args should return empty"
         & " for non-existent profile");
   end Test_Bbuild_Non_Existent_Profile;

   procedure Test_Bbuild_Allow_Write (T : in out Test) is
      Dir    : constant String := LLM.Tools.Sandbox.Profiles_Dir;
      Prof_Path : constant String := Dir & "/allow_write.json";
      Base   : constant String :=
        Ada.Directories.Current_Directory & "/sandbox_test_home";
      Tmp    : constant String := Base & "/scratch";
      Cwd    : constant String := To_String (T.Temp_Home);
   begin
      Ada.Directories.Create_Path (Tmp);

      Write_File
        (Prof_Path,
         "{""allowWrite"":[""" & Tmp & """],"
         & """denyWrite"":[],""denyRead"":[],""allowRead"":[]}");

      declare
         Args : constant LLM.Tools.Sandbox.String_Vectors.Vector :=
           LLM.Tools.Sandbox.Build_Bwrap_Args ("allow_write", Cwd);
      begin
         Assert
           (not Args.Is_Empty,
            "Args should not be empty for allowWrite with existing path");
         Assert
           (Args.First_Element = "--bind",
            "First arg should be --bind for allowWrite, got: "
            & Args.First_Element);
      end;
   end Test_Bbuild_Allow_Write;

   procedure Test_Bbuild_Deny_Write (T : in out Test) is
      Dir    : constant String := LLM.Tools.Sandbox.Profiles_Dir;
      Prof_Path : constant String := Dir & "/deny_write.json";
      Base   : constant String :=
        Ada.Directories.Current_Directory & "/sandbox_test_home";
      Tmp    : constant String := Base & "/scratch";
      Cwd    : constant String := To_String (T.Temp_Home);
   begin
      Ada.Directories.Create_Path (Tmp);

      Write_File
        (Prof_Path,
         "{""allowWrite"":[],"
         & """denyWrite"":[""" & Tmp & """],"
         & """denyRead"":[],""allowRead"":[]}");

      declare
         Args : constant LLM.Tools.Sandbox.String_Vectors.Vector :=
           LLM.Tools.Sandbox.Build_Bwrap_Args ("deny_write", Cwd);
      begin
         Assert
           (not Args.Is_Empty,
            "Args should not be empty for denyWrite with existing path");
         Assert
           (Args.First_Element = "--ro-bind",
            "First arg should be --ro-bind for denyWrite, got: "
            & Args.First_Element);
      end;
   end Test_Bbuild_Deny_Write;

   procedure Test_Bbuild_Allow_Read (T : in out Test) is
      Dir    : constant String := LLM.Tools.Sandbox.Profiles_Dir;
      Prof_Path : constant String := Dir & "/allow_read.json";
      Base   : constant String :=
        Ada.Directories.Current_Directory & "/sandbox_test_home";
      Tmp    : constant String := Base & "/scratch";
      Cwd    : constant String := To_String (T.Temp_Home);
   begin
      Ada.Directories.Create_Path (Tmp);

      Write_File
        (Prof_Path,
         "{""allowWrite"":[],""denyWrite"":[],""denyRead"":[],"
         & """allowRead"":[""" & Tmp & """]}");

      declare
         Args : constant LLM.Tools.Sandbox.String_Vectors.Vector :=
           LLM.Tools.Sandbox.Build_Bwrap_Args ("allow_read", Cwd);
      begin
         Assert
           (not Args.Is_Empty,
            "Args should not be empty for allowRead with existing path");
         Assert
           (Args.First_Element = "--ro-bind",
            "First arg should be --ro-bind for allowRead, got: "
            & Args.First_Element);
      end;
   end Test_Bbuild_Allow_Read;

   procedure Test_Bbuild_Deny_Read (T : in out Test) is
      Dir    : constant String := LLM.Tools.Sandbox.Profiles_Dir;
      Prof_Path : constant String := Dir & "/deny_read.json";
      Base   : constant String :=
        Ada.Directories.Current_Directory & "/sandbox_test_home";
      Tmp    : constant String := Base & "/scratch";
      Cwd    : constant String := To_String (T.Temp_Home);
   begin
      Ada.Directories.Create_Path (Tmp);

      Write_File
        (Prof_Path,
         "{""allowWrite"":[],""denyWrite"":[],"
         & """denyRead"":[""" & Tmp & """],""allowRead"":[]}");

      declare
         Args : constant LLM.Tools.Sandbox.String_Vectors.Vector :=
           LLM.Tools.Sandbox.Build_Bwrap_Args ("deny_read", Cwd);
      begin
         Assert
           (not Args.Is_Empty,
            "Args should not be empty for denyRead with existing path");
         Assert
           (Args.First_Element = "--tmpfs",
            "First arg should be --tmpfs for denyRead, got: "
            & Args.First_Element);
      end;
   end Test_Bbuild_Deny_Read;

   procedure Test_Bbuild_Missing_Path_Skipped (T : in out Test) is
      Dir    : constant String := LLM.Tools.Sandbox.Profiles_Dir;
      Prof_Path : constant String := Dir & "/missing_path.json";
      Cwd    : constant String := To_String (T.Temp_Home);
   begin
      Write_File
        (Prof_Path,
         "{""allowWrite"":[""/nonexistent/foo/bar/baz""],"
         & """denyWrite"":[],""denyRead"":[],""allowRead"":[]}");

      declare
         Args : constant LLM.Tools.Sandbox.String_Vectors.Vector :=
           LLM.Tools.Sandbox.Build_Bwrap_Args ("missing_path", Cwd);
      begin
         Assert
           (Args.Is_Empty,
            "Args should be empty when all paths in profile are missing");
      end;
   end Test_Bbuild_Missing_Path_Skipped;

   procedure Test_Bbuild_Multiple_Rule_Types (T : in out Test) is
      Dir    : constant String := LLM.Tools.Sandbox.Profiles_Dir;
      Prof_Path : constant String := Dir & "/multi_type.json";
      Base   : constant String :=
        Ada.Directories.Current_Directory & "/sandbox_test_home";
      Tmp_A  : constant String := Base & "/alpha";
      Tmp_B  : constant String := Base & "/beta";
      Cwd    : constant String := To_String (T.Temp_Home);
   begin
      Ada.Directories.Create_Path (Tmp_A);
      Ada.Directories.Create_Path (Tmp_B);

      Write_File
        (Prof_Path,
         "{""allowWrite"":[""" & Tmp_A & """],"
         & """denyWrite"":[],"
         & """denyRead"":[""" & Tmp_B & """],"
         & """allowRead"":[]}");

      declare
         Args : constant LLM.Tools.Sandbox.String_Vectors.Vector :=
           LLM.Tools.Sandbox.Build_Bwrap_Args ("multi_type", Cwd);
         Seen_Bind  : Boolean := False;
         Seen_Tmpfs  : Boolean := False;
      begin
         Assert
           (not Args.Is_Empty,
            "Args should not be empty with multiple rule types");
         Assert
           (Args.First_Element = "--bind",
            "First arg should be --bind (allowWrite comes first), got: "
            & Args.First_Element);

         for I in 1 .. Integer (Args.Length) loop
            declare
               Arg : constant String := Args.Element (Positive (I));
            begin
               if Arg = "--bind" then
                  Seen_Bind := True;
               elsif Arg = "--tmpfs" then
                  Seen_Tmpfs := True;
               end if;
            end;
         end loop;

         Assert (Seen_Bind, "Expected --bind in args");
         Assert (Seen_Tmpfs, "Expected --tmpfs in args");
      end;
   end Test_Bbuild_Multiple_Rule_Types;

   procedure Test_Bbuild_Depth_Sorted (T : in out Test) is
      Dir    : constant String := LLM.Tools.Sandbox.Profiles_Dir;
      Prof_Path : constant String := Dir & "/depth_sort.json";
      Base   : constant String :=
        Ada.Directories.Current_Directory & "/sandbox_test_home";
      Shallow : constant String := Base & "/shallow";
      Deep    : constant String := Base & "/shallow/subdir/deep";
      Cwd    : constant String := To_String (T.Temp_Home);
   begin
      Ada.Directories.Create_Path (Deep);

      Write_File
        (Prof_Path,
         "{""allowWrite"":[""" & Deep & """],"
         & """denyWrite"":[],""denyRead"":[],"
         & """allowRead"":[""" & Shallow & """]}");

      declare
         Args : constant LLM.Tools.Sandbox.String_Vectors.Vector :=
           LLM.Tools.Sandbox.Build_Bwrap_Args ("depth_sort", Cwd);
      begin
         Assert
           (not Args.Is_Empty,
            "Args should not be empty for depth sort test");
         Assert
           (Args.First_Element = "--ro-bind",
            "First arg should be --ro-bind (shallower path), got: "
            & Args.First_Element);
      end;
   end Test_Bbuild_Depth_Sorted;

   --  ── Path resolution tests ────────────────────────────────────────────

   procedure Test_Resolve_Dot_To_Cwd (T : in out Test) is
      Dir    : constant String := LLM.Tools.Sandbox.Profiles_Dir;
      Prof_Path : constant String := Dir & "/resolve_dot.json";
      Cwd    : constant String := To_String (T.Temp_Home);
   begin
      Write_File
        (Prof_Path,
         "{""allowWrite"":["".""],"
         & """denyWrite"":[],""denyRead"":[],""allowRead"":[]}");

      declare
         Args : constant LLM.Tools.Sandbox.String_Vectors.Vector :=
           LLM.Tools.Sandbox.Build_Bwrap_Args ("resolve_dot", Cwd);
      begin
         Assert
           (not Args.Is_Empty,
            "Args should not be empty when '.' resolves to existing Cwd");
         Assert
           (Args.Contains (Cwd),
            "Resolved path should equal Cwd, looking for: " & Cwd);
      end;
   end Test_Resolve_Dot_To_Cwd;

   procedure Test_Resolve_Dot_Slash (T : in out Test) is
      Dir    : constant String := LLM.Tools.Sandbox.Profiles_Dir;
      Prof_Path : constant String := Dir & "/resolve_dot_slash.json";
      Cwd    : constant String := To_String (T.Temp_Home);
   begin
      Write_File
        (Prof_Path,
         "{""allowWrite"":[""./.coyote""],"
         & """denyWrite"":[],""denyRead"":[],""allowRead"":[]}");

      declare
         Args : constant LLM.Tools.Sandbox.String_Vectors.Vector :=
           LLM.Tools.Sandbox.Build_Bwrap_Args ("resolve_dot_slash", Cwd);
      begin
         Assert
           (not Args.Is_Empty,
            "Args should not be empty when './.coyote' resolves"
            & " to existing dir");
         Assert
           (Args.Contains (Cwd & "/.coyote"),
            "Resolved path should be Cwd/.coyote, looking for: "
            & Cwd & "/.coyote");
      end;
   end Test_Resolve_Dot_Slash;

   procedure Test_Resolve_Home_Prefix (T : in out Test) is
      Dir    : constant String := LLM.Tools.Sandbox.Profiles_Dir;
      Prof_Path : constant String := Dir & "/resolve_home.json";
      Home   : constant String := To_String (T.Temp_Home);
   begin
      Write_File
        (Prof_Path,
         "{""allowWrite"":[""~/.coyote""],"
         & """denyWrite"":[],""denyRead"":[],""allowRead"":[]}");

      declare
         Args : constant LLM.Tools.Sandbox.String_Vectors.Vector :=
           LLM.Tools.Sandbox.Build_Bwrap_Args ("resolve_home", Home);
      begin
         Assert
           (not Args.Is_Empty,
            "Args should not be empty when '~/.coyote' resolves");
         Assert
           (Args.Contains (Home & "/.coyote"),
            "Resolved path should be $HOME/.coyote, looking for: "
            & Home & "/.coyote");
      end;
   end Test_Resolve_Home_Prefix;

   procedure Test_Resolve_Absolute_Untouched (T : in out Test) is
      Dir    : constant String := LLM.Tools.Sandbox.Profiles_Dir;
      Prof_Path : constant String := Dir & "/resolve_abs.json";
      Cwd    : constant String := To_String (T.Temp_Home);
   begin
      Write_File
        (Prof_Path,
         "{""allowWrite"":[""/dev/null""],"
         & """denyWrite"":[],""denyRead"":[],""allowRead"":[]}");

      declare
         Args : constant LLM.Tools.Sandbox.String_Vectors.Vector :=
           LLM.Tools.Sandbox.Build_Bwrap_Args ("resolve_abs", Cwd);
      begin
         Assert
           (not Args.Is_Empty,
            "Args should not be empty when absolute path /dev/null exists");
         Assert
           (Args.Contains ("/dev/null"),
            "Absolute path /dev/null should appear unchanged in args");
      end;
   end Test_Resolve_Absolute_Untouched;

   --  ── Shell + sandbox integration tests ────────────────────────────────

   procedure Test_Shell_Sandbox_Allow_Write (T : in out Test) is
      pragma Unreferenced (T);
      Dir    : constant String := LLM.Tools.Sandbox.Profiles_Dir;
      Prof_Path : constant String := Dir & "/shell_allow_write.json";
      Result  : Unbounded_String;
      Media_Type : Unbounded_String;
      Is_Error   : Boolean;
   begin
      Write_File
        (Prof_Path,
         "{""allowWrite"":[""/tmp""],"
         & """denyWrite"":[],""denyRead"":[],""allowRead"":[]}");

      LLM.Tools.Shell.Execute
        (Args_Json       =>
           "{""command"":""mktemp -p /tmp sandbox_test_XXXXXX "
           & "&& echo write_ok""}",
         Result          => Result,
         Media_Type      => Media_Type,
         Is_Error        => Is_Error,
         Sandbox_Profile => "shell_allow_write");

      declare
         Output : constant String := To_String (Result);
      begin
         Assert (not Is_Error,
                 "Shell command under allowWrite sandbox should succeed, "
                 & "got error: " & Output);
         Assert
           (Contains (Output, "write_ok"),
            "Output should contain 'write_ok', got: " & Output);
      end;
   end Test_Shell_Sandbox_Allow_Write;

   procedure Test_Shell_Sandbox_Deny_Read (T : in out Test) is
      pragma Unreferenced (T);
      Dir    : constant String := LLM.Tools.Sandbox.Profiles_Dir;
      Prof_Path : constant String := Dir & "/shell_deny_read.json";
      Result  : Unbounded_String;
      Media_Type : Unbounded_String;
      Is_Error   : Boolean;
   begin
      Write_File
        (Prof_Path,
         "{""allowWrite"":[""/tmp""],"
         & """denyWrite"":[],"
         & """denyRead"":[""/etc""],"
         & """allowRead"":[""/""]}");

      LLM.Tools.Shell.Execute
        (Args_Json       =>
           "{""command"":""cat /etc/passwd 2>/dev/null; "
           & "if [ $? -ne 0 ]; then echo blocked; "
           & "else echo read_ok; fi""}",
         Result          => Result,
         Media_Type      => Media_Type,
         Is_Error        => Is_Error,
         Sandbox_Profile => "shell_deny_read");

      declare
         Output : constant String := To_String (Result);
      begin
         Assert
           (Contains (Output, "blocked"),
            "Attempt to read /etc under denyRead sandbox"
            & " should be blocked, got: " & Output);
      end;
   end Test_Shell_Sandbox_Deny_Read;

   procedure Test_Shell_Sandbox_Empty_Profile (T : in out Test) is
      pragma Unreferenced (T);
      Result  : Unbounded_String;
      Media_Type : Unbounded_String;
      Is_Error   : Boolean;
   begin
      LLM.Tools.Shell.Execute
        (Args_Json       =>
           "{""command"":""echo no_sandbox""}",
         Result          => Result,
         Media_Type      => Media_Type,
         Is_Error        => Is_Error,
         Sandbox_Profile => "");

      Assert (not Is_Error,
              "Shell with no sandbox profile should succeed");
      Assert
        (Contains (To_String (Result), "no_sandbox"),
         "Output should contain 'no_sandbox'");
   end Test_Shell_Sandbox_Empty_Profile;

   procedure Test_Shell_Sandbox_Timeout (T : in out Test) is
      pragma Unreferenced (T);
      Dir        : constant String := LLM.Tools.Sandbox.Profiles_Dir;
      Prof_Path  : constant String := Dir & "/shell_timeout.json";
      Result     : Unbounded_String;
      Media_Type : Unbounded_String;
      Is_Error   : Boolean;
   begin
      Write_File
        (Prof_Path,
         "{""allowWrite"":[],""denyWrite"":[],"
         & """denyRead"":[],""allowRead"":[]}");

      LLM.Tools.Shell.Execute
        (Args_Json       =>
           "{""command"":""sleep 10"",""timeout"":1}",
         Result          => Result,
         Media_Type      => Media_Type,
         Is_Error        => Is_Error,
         Sandbox_Profile => "shell_timeout");

      Assert (Is_Error,
              "sandboxed command exceeding timeout should set Is_Error");
      Assert
        (Contains (To_String (Result), "timed out after 1 seconds"),
         "sandboxed timeout result should contain timeout notice, got: "
         & To_String (Result));
   end Test_Shell_Sandbox_Timeout;

   procedure Test_Shell_Sandbox_Abort (T : in out Test) is
      pragma Unreferenced (T);
      Dir        : constant String := LLM.Tools.Sandbox.Profiles_Dir;
      Prof_Path  : constant String := Dir & "/shell_abort.json";
      Flag       : aliased LLM.Tools.Abort_Flag;
      Result     : Unbounded_String;
      Media_Type : Unbounded_String;
      Is_Error   : Boolean;
   begin
      Write_File
        (Prof_Path,
         "{""allowWrite"":[],""denyWrite"":[],"
         & """denyRead"":[],""allowRead"":[]}");

      declare
         task Executor;

         task body Executor is
         begin
            LLM.Tools.Shell.Execute
              (Args_Json       =>
                 "{""command"":""echo sandbox_abort && sleep 10"","
                 & """timeout"":30}",
               Result          => Result,
               Media_Type      => Media_Type,
               Is_Error        => Is_Error,
               Abort_Flg       => Flag'Access,
               Sandbox_Profile => "shell_abort");
         end Executor;
      begin
         delay 0.20;
         Flag.Set;

         declare
            use Ada.Real_Time;
            Deadline : constant Time := Clock + Milliseconds (2_000);
         begin
            loop
               exit when Executor'Terminated;
               exit when Clock >= Deadline;
               delay 0.01;
            end loop;
         end;

         Assert
           (Executor'Terminated,
            "sandboxed abort should terminate the shell process group");
      end;

      Assert (Is_Error,
              "sandboxed aborted command should set Is_Error");
      Assert
        (Contains (To_String (Result), "sandbox_abort"),
         "sandboxed abort should preserve output before termination, got: "
         & To_String (Result));
      Assert
        (Contains (To_String (Result), "command was aborted"),
         "sandboxed abort result should contain abort notice, got: "
         & To_String (Result));
   end Test_Shell_Sandbox_Abort;


   package Sandbox_Caller is
     new AUnit.Test_Caller (Sandbox_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox Profiles_Dir returns path",
         Sandbox_Tests.Test_Profiles_Dir_Returns_Path'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox Available_Profiles empty when none exist",
         Sandbox_Tests.Test_Available_Profiles_Empty'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox Available_Profiles finds profile",
         Sandbox_Tests.Test_Available_Profiles_Found'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox Load_Profile returns object for valid profile",
         Sandbox_Tests.Test_Load_Profile_Found'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox Load_Profile returns JSON_Null for missing profile",
         Sandbox_Tests.Test_Load_Profile_Not_Found'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox Load_Profile returns JSON_Null for bad JSON",
         Sandbox_Tests.Test_Load_Profile_Bad_Json'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox Build_Bwrap_Args returns empty for empty profile",
         Sandbox_Tests.Test_Bbuild_Empty_Profile'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox Build_Bwrap_Args returns empty for non-existent profile",
         Sandbox_Tests.Test_Bbuild_Non_Existent_Profile'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox Build_Bwrap_Args allowWrite uses --bind",
         Sandbox_Tests.Test_Bbuild_Allow_Write'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox Build_Bwrap_Args denyWrite uses --ro-bind",
         Sandbox_Tests.Test_Bbuild_Deny_Write'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox Build_Bwrap_Args allowRead uses --ro-bind",
         Sandbox_Tests.Test_Bbuild_Allow_Read'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox Build_Bwrap_Args denyRead uses --tmpfs",
         Sandbox_Tests.Test_Bbuild_Deny_Read'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox Build_Bwrap_Args skips missing paths",
         Sandbox_Tests.Test_Bbuild_Missing_Path_Skipped'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox Build_Bwrap_Args handles multiple rule types",
         Sandbox_Tests.Test_Bbuild_Multiple_Rule_Types'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox Build_Bwrap_Args sorts by path depth",
         Sandbox_Tests.Test_Bbuild_Depth_Sorted'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox resolves '.' to Cwd",
         Sandbox_Tests.Test_Resolve_Dot_To_Cwd'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox resolves './...' relative to Cwd",
         Sandbox_Tests.Test_Resolve_Dot_Slash'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox resolves '~/' prefix to $HOME",
         Sandbox_Tests.Test_Resolve_Home_Prefix'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox passes absolute paths through unchanged",
         Sandbox_Tests.Test_Resolve_Absolute_Untouched'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox shell allowWrite succeeds",
         Sandbox_Tests.Test_Shell_Sandbox_Allow_Write'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox shell denyRead blocks access",
         Sandbox_Tests.Test_Shell_Sandbox_Deny_Read'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox shell empty profile runs unsandboxed",
         Sandbox_Tests.Test_Shell_Sandbox_Empty_Profile'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox shell timeout terminates the process group",
         Sandbox_Tests.Test_Shell_Sandbox_Timeout'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox shell abort terminates the process group",
         Sandbox_Tests.Test_Shell_Sandbox_Abort'Access));

      return Result;
   end Suite;

end Sandbox_Tests;
