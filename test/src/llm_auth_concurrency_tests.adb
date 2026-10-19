with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Real_Time;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with AUnit.Assertions; use AUnit.Assertions;
with AUnit.Test_Caller;
with GNATCOLL.OS.FS;
with GNATCOLL.OS.Process;
with LLM.Auth;
with LLM.Credential_Locks;
with Test_HTTP_Server;

package body LLM_Auth_Concurrency_Tests is
   use GNATCOLL.OS.Process;
   use type Ada.Real_Time.Time;

   function Kill (Pid : Integer; Signal : Integer) return Integer;
   pragma Import (C, Kill, "kill");

   function PID return Natural is
      function Getpid return Integer;
      pragma Import (C, Getpid, "getpid");
   begin
      return Natural (Getpid);
   end PID;

   procedure Kill_Child (H : Process_Handle) is
      Result : constant Integer := Kill (Integer (H), 9);
      pragma Unreferenced (Result);
   begin
      null;
   end Kill_Child;

   function Image (Value : Natural) return String is
      S : constant String := Natural'Image (Value);
   begin
      return S (S'First + 1 .. S'Last);
   end Image;

   function Worker return String is
      Candidate : constant String := "bin/auth_test_worker";
   begin
      if Ada.Directories.Exists (Candidate) then
         return Candidate;
      end if;
      return "../bin/auth_test_worker";
   end Worker;

   procedure Write (Path, Data : String) is
      F : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (F, Data);
      Ada.Text_IO.Close (F);
   end Write;

   procedure Touch (Path : String) is
   begin
      Write (Path, "ready");
   end Touch;

   procedure Await (Path : String; Seconds : Duration := 10.0) is
      Start : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
   begin
      while not Ada.Directories.Exists (Path)
        and then Ada.Real_Time.To_Duration
          (Ada.Real_Time.Clock - Start) < Seconds
      loop
         delay 0.01;
      end loop;
      Assert (Ada.Directories.Exists (Path), "timed out waiting for " & Path);
   end Await;

   procedure Remove_Tree (Path : String) is
   begin
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_Tree (Path);
      end if;
   exception
      when others => null;
   end Remove_Tree;

   procedure Stop_And_Reap (H : Process_Handle) is
   begin
      if H /= Invalid_Handle and then State (H) /= TERMINATED then
         Kill_Child (H);
         declare
            Ignore : constant Integer := Wait (H);
            pragma Unreferenced (Ignore);
         begin
            null;
         end;
      end if;
   exception
      when others => null;
   end Stop_And_Reap;

   function Start_Worker
     (Mode, Home, Ready, Gate : String) return Process_Handle
   is
      Args : Argument_List;
      Env  : Environment_Dict;
      Null_IO : GNATCOLL.OS.FS.File_Descriptor;
   begin
      Args.Append (Worker);
      Args.Append (Mode);
      Args.Append (Ready);
      Args.Append (Gate);
      Env.Include ("HOME", Home);
      Null_IO := GNATCOLL.OS.FS.Open
        (GNATCOLL.OS.FS.Null_File, GNATCOLL.OS.FS.Write_Mode);
      declare
         H : constant Process_Handle := Start
           (Args => Args, Env => Env, Stdin => Null_IO,
            Stdout => Null_IO, Stderr => Null_IO, Inherit_Env => True);
      begin
         GNATCOLL.OS.FS.Close (Null_IO);
         return H;
      exception
         when others =>
            GNATCOLL.OS.FS.Close (Null_IO);
            raise;
      end;
   end Start_Worker;

   procedure Check_Children
     (A, B : in out Process_Handle; Done_A, Done_B : String)
   is
      Code_A : Integer;
      Code_B : Integer;
   begin
      Await (Done_A);
      Await (Done_B);
      Code_A := Wait (A);
      Code_B := Wait (B);
      A := Invalid_Handle;
      B := Invalid_Handle;
      Assert (Code_A = 0 and then Code_B = 0, "auth workers must succeed");
   exception
      when others =>
         Stop_And_Reap (A);
         Stop_And_Reap (B);
         raise;
   end Check_Children;

   procedure Run_Concurrent_Ensure (Mode : String; Expired : Boolean) is
      Home : constant String := "/tmp/coyote_auth_concurrency_" & Image (PID);
      Ready_A : constant String := Home & "/a.ready";
      Ready_B : constant String := Home & "/b.ready";
      Gate : constant String := Home & "/go";
      Port : constant Positive := 30_000 + PID mod 20_000;
      Count : Natural := 0;
      procedure Handler
        (Req : Test_HTTP_Server.Request; Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Count := Count + 1;
         Res.Status := 200;
         Append
           (Res.Body_Data,
            "{""access_token"":""synthetic-fresh""," &
            """refresh_token"":""refresh-1"",""expires_in"":3600}");
         Res.Body_Delay := 0.6;
      end Handler;
      Srv : Test_HTTP_Server.Server (Handler'Unrestricted_Access);
      A, B : Process_Handle := Invalid_Handle;
      Saved : LLM.Auth.Provider_Credentials;
      Url_Old : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_CODEX_TOKEN_URL", "");
      Url_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_CODEX_TOKEN_URL");
      Home_Old : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Home_Set : constant Boolean := Ada.Environment_Variables.Exists ("HOME");
      Original_Access : constant String :=
        (if Expired then "expired" else "rejected-original");
      Original_Expiry : constant String :=
        (if Expired then "0" else "4102444800000");
   begin
      Remove_Tree (Home);
      Ada.Directories.Create_Path (Home & "/.coyote");
      Write
        (Home & "/.coyote/auth.json",
         "{""codex"":{""type"":""oauth"",""refresh"":""refresh-0""," &
         """access"":""" & Original_Access & """,""expires"":" &
         Original_Expiry & "}}");
      Ada.Environment_Variables.Set
        ("COYOTE_CODEX_TOKEN_URL",
         "http://127.0.0.1:" & Image (Port) & "/oauth/token");
      Srv.Bind (Port);
      A := Start_Worker (Mode, Home, Ready_A, Gate);
      B := Start_Worker (Mode, Home, Ready_B, Gate);
      Await (Ready_A);
      Await (Ready_B);
      Touch (Gate);
      Check_Children (A, B, Ready_A & ".done", Ready_B & ".done");
      Srv.Stop;
      Ada.Environment_Variables.Set ("HOME", Home);
      Saved := LLM.Auth.Load_Credentials ("codex");
      Assert (Count = 1, "exactly one process should refresh the token");
      Assert (To_String (Saved.Access_Token) = "synthetic-fresh",
              "fresh credential should be persisted");
      if Url_Set then
         Ada.Environment_Variables.Set ("COYOTE_CODEX_TOKEN_URL", Url_Old);
      else
         Ada.Environment_Variables.Clear ("COYOTE_CODEX_TOKEN_URL");
      end if;
      if Home_Set then
         Ada.Environment_Variables.Set ("HOME", Home_Old);
      else
         Ada.Environment_Variables.Clear ("HOME");
      end if;
      Remove_Tree (Home);
   exception
      when others =>
         Stop_And_Reap (A);
         Stop_And_Reap (B);
         Srv.Stop;
         if Url_Set then
            Ada.Environment_Variables.Set ("COYOTE_CODEX_TOKEN_URL", Url_Old);
         else
            Ada.Environment_Variables.Clear ("COYOTE_CODEX_TOKEN_URL");
         end if;
         if Home_Set then
            Ada.Environment_Variables.Set ("HOME", Home_Old);
         else
            Ada.Environment_Variables.Clear ("HOME");
         end if;
         Remove_Tree (Home);
         raise;
   end Run_Concurrent_Ensure;

   procedure Test_Concurrent_Ensure (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Run_Concurrent_Ensure ("ensure", Expired => True);
   end Test_Concurrent_Ensure;

   procedure Test_Concurrent_Recover (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Run_Concurrent_Ensure ("recover", Expired => False);
   end Test_Concurrent_Recover;

   procedure Run_Refresh_Save_Race (Mode : String) is
      Home : constant String := "/tmp/coyote_auth_refresh_save_" & Image (PID);
      Refresh_Ready : constant String := Home & "/refresh.ready";
      Save_Ready : constant String := Home & "/save.ready";
      Gate : constant String := Home & "/go";
      Request_Seen : constant String := Home & "/request-seen";
      Port : constant Positive := 30_000 + PID mod 20_000;
      Count : Natural := 0;
      procedure Handler
        (Req : Test_HTTP_Server.Request; Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Count := Count + 1;
         Touch (Request_Seen);
         Res.Status := 200;
         Append
           (Res.Body_Data,
            "{""access_token"":""refresh-wins-first""," &
            """refresh_token"":""refresh-next"",""expires_in"":3600}");
         Res.Body_Delay := 0.8;
      end Handler;
      Srv : Test_HTTP_Server.Server (Handler'Unrestricted_Access);
      Refresher, Saver : Process_Handle := Invalid_Handle;
      Home_Old : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Home_Set : constant Boolean := Ada.Environment_Variables.Exists ("HOME");
      Url_Old : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_CODEX_TOKEN_URL", "");
      Url_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_CODEX_TOKEN_URL");
   begin
      Remove_Tree (Home);
      Ada.Directories.Create_Path (Home & "/.coyote");
      Write
        (Home & "/.coyote/auth.json",
         "{""codex"":{""type"":""oauth"",""refresh"":""refresh-0""," &
         """access"":""expired"",""expires"":0}}");
      Ada.Environment_Variables.Set
        ("COYOTE_CODEX_TOKEN_URL",
         "http://127.0.0.1:" & Image (Port) & "/oauth/token");
      Srv.Bind (Port);
      Refresher := Start_Worker ("ensure", Home, Refresh_Ready, Gate);
      Await (Refresh_Ready);
      Touch (Gate);
      Await (Request_Seen);
      Saver := Start_Worker (Mode, Home, Save_Ready, Gate);
      Await (Save_Ready);
      Touch (Gate);
      delay 0.2;
      Assert
        (not Ada.Directories.Exists (Save_Ready & ".done"),
         Mode & " must block while the refresh request is in flight");
      Await (Refresh_Ready & ".done");
      Await (Save_Ready & ".done");
      declare
         Ignore_Refresh : constant Integer := Wait (Refresher);
         Ignore_Save : constant Integer := Wait (Saver);
         pragma Unreferenced (Ignore_Refresh, Ignore_Save);
      begin
         Refresher := Invalid_Handle;
         Saver := Invalid_Handle;
      end;
      Srv.Stop;
      Assert (Count = 1, "refresh endpoint should receive one request");
      Ada.Environment_Variables.Set ("HOME", Home);
      declare
         Saved : constant LLM.Auth.Provider_Credentials :=
           LLM.Auth.Load_Credentials ("codex");
      begin
         Assert
           (To_String (Saved.Access_Token) =
              (if Mode = "logout-codex" then "" else Mode),
            Mode & " must replace the completed refresh credential");
      end;
      if Url_Set then
         Ada.Environment_Variables.Set ("COYOTE_CODEX_TOKEN_URL", Url_Old);
      else
         Ada.Environment_Variables.Clear ("COYOTE_CODEX_TOKEN_URL");
      end if;
      if Home_Set then
         Ada.Environment_Variables.Set ("HOME", Home_Old);
      else
         Ada.Environment_Variables.Clear ("HOME");
      end if;
      Remove_Tree (Home);
   exception
      when others =>
         Stop_And_Reap (Refresher);
         Stop_And_Reap (Saver);
         Srv.Stop;
         if Url_Set then
            Ada.Environment_Variables.Set ("COYOTE_CODEX_TOKEN_URL", Url_Old);
         else
            Ada.Environment_Variables.Clear ("COYOTE_CODEX_TOKEN_URL");
         end if;
         if Home_Set then
            Ada.Environment_Variables.Set ("HOME", Home_Old);
         else
            Ada.Environment_Variables.Clear ("HOME");
         end if;
         Remove_Tree (Home);
         raise;
   end Run_Refresh_Save_Race;

   procedure Test_Refresh_Blocked_By_Login_And_Logout (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Run_Refresh_Save_Race ("save-codex");
      Run_Refresh_Save_Race ("logout-codex");
   end Test_Refresh_Blocked_By_Login_And_Logout;

   procedure Test_Codex_Save_Waits (T : in out Test) is
      pragma Unreferenced (T);
      Home : constant String := "/tmp/coyote_auth_codex_save_" & Image (PID);
      Ready : constant String := Home & "/save.ready";
      Gate : constant String := Home & "/go";
      Done : constant String := Ready & ".done";
      Holder : constant String := Home & "/held";
      Release_Holder : constant String := Home & "/release";
      H, Saver : Process_Handle := Invalid_Handle;
      Started : Ada.Real_Time.Time;
      Old_Home : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Had_Home : constant Boolean := Ada.Environment_Variables.Exists ("HOME");
   begin
      Remove_Tree (Home);
      Ada.Directories.Create_Path (Home & "/.coyote");
      Write (Home & "/.coyote/auth.json", "{}");
      H := Start_Worker ("hold-lock", Home, Holder, Release_Holder);
      Await (Holder);
      Saver := Start_Worker ("save-codex", Home, Ready, Gate);
      Await (Ready);
      Touch (Gate);
      delay 0.2;
      Assert (not Ada.Directories.Exists (Done),
              "Codex login/logout save must wait for refresh lock");
      Started := Ada.Real_Time.Clock;
      Touch (Release_Holder);
      Await (Done);
      Assert
        (Ada.Real_Time.To_Duration (Ada.Real_Time.Clock - Started) < 2.0,
              "Codex save must proceed promptly when refresh releases");
      declare
         Ignore_H : constant Integer := Wait (H);
         Ignore_S : constant Integer := Wait (Saver);
         pragma Unreferenced (Ignore_H, Ignore_S);
      begin
         H := Invalid_Handle;
         Saver := Invalid_Handle;
      end;
      Ada.Environment_Variables.Set ("HOME", Home);
      Assert (To_String (LLM.Auth.Load_Credentials ("codex").Access_Token)
              = "save-codex", "Codex save must win over prior refresh state");
      if Had_Home then
         Ada.Environment_Variables.Set ("HOME", Old_Home);
      else
         Ada.Environment_Variables.Clear ("HOME");
      end if;
      Remove_Tree (Home);
   exception
      when others =>
         Stop_And_Reap (H);
         Stop_And_Reap (Saver);
         if Had_Home then
            Ada.Environment_Variables.Set ("HOME", Old_Home);
         else
            Ada.Environment_Variables.Clear ("HOME");
         end if;
         Remove_Tree (Home);
         raise;
   end Test_Codex_Save_Waits;

   procedure Test_Concurrent_Save_Merge (T : in out Test) is
      pragma Unreferenced (T);
      Home : constant String := "/tmp/coyote_auth_save_race_" & Image (PID);
      Gate : constant String := Home & "/go";
      Ready_A : constant String := Home & "/openai.ready";
      Ready_B : constant String := Home & "/anthropic.ready";
      A, B : Process_Handle := Invalid_Handle;
      Old_Home : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Had_Home : constant Boolean := Ada.Environment_Variables.Exists ("HOME");
   begin
      Remove_Tree (Home);
      Ada.Directories.Create_Path (Home & "/.coyote");
      Write (Home & "/.coyote/auth.json", "{}");
      A := Start_Worker ("save-openai", Home, Ready_A, Gate);
      B := Start_Worker ("save-anthropic", Home, Ready_B, Gate);
      Await (Ready_A);
      Await (Ready_B);
      Touch (Gate);
      Check_Children (A, B, Ready_A & ".done", Ready_B & ".done");
      Ada.Environment_Variables.Set ("HOME", Home);
      Assert
        (To_String (LLM.Auth.Load_Credentials ("openai").Access_Token)
         = "save-openai", "OpenAI entry should survive concurrent merge");
      Assert
        (To_String (LLM.Auth.Load_Credentials ("anthropic").Access_Token)
         = "save-anthropic",
         "Anthropic entry should survive concurrent merge");
      if Had_Home then
         Ada.Environment_Variables.Set ("HOME", Old_Home);
      else
         Ada.Environment_Variables.Clear ("HOME");
      end if;
      Remove_Tree (Home);
   exception
      when others =>
         Stop_And_Reap (A);
         Stop_And_Reap (B);
         if Had_Home then
            Ada.Environment_Variables.Set ("HOME", Old_Home);
         else
            Ada.Environment_Variables.Clear ("HOME");
         end if;
         Remove_Tree (Home);
         raise;
   end Test_Concurrent_Save_Merge;

   procedure Test_Killed_Lock_Holder (T : in out Test) is
      pragma Unreferenced (T);
      Home : constant String := "/tmp/coyote_auth_lock_kill_" & Image (PID);
      Ready : constant String := Home & "/held";
      Gate : constant String := Home & "/release";
      H : Process_Handle := Invalid_Handle;
      Guard : LLM.Credential_Locks.Lock;
      Start_Time : Ada.Real_Time.Time;
   begin
      Remove_Tree (Home);
      Ada.Directories.Create_Path (Home & "/.coyote");
      H := Start_Worker ("hold-lock", Home, Ready, Gate);
      Await (Ready);
      Kill_Child (H);
      declare
         Ignore : constant Integer := Wait (H);
         pragma Unreferenced (Ignore);
      begin
         H := Invalid_Handle;
      end;
      Start_Time := Ada.Real_Time.Clock;
      LLM.Credential_Locks.Acquire
        (Guard, Home & "/.coyote/codex-refresh.lock", Timeout_Seconds => 2);
      Assert
        (Ada.Real_Time.To_Duration (Ada.Real_Time.Clock - Start_Time) < 1.0,
         "lock must be promptly available after holder death");
      LLM.Credential_Locks.Release (Guard);
      Remove_Tree (Home);
   exception
      when others =>
         Stop_And_Reap (H);
         Remove_Tree (Home);
         raise;
   end Test_Killed_Lock_Holder;

   procedure Test_Lock_Close_On_Exec (T : in out Test) is
      pragma Unreferenced (T);
      Home : constant String := "/tmp/coyote_auth_lock_exec_" & Image (PID);
      Ready : constant String := Home & "/idle.ready";
      Gate : constant String := Home & "/release-idle";
      Child : Process_Handle := Invalid_Handle;
      Parent_Guard : LLM.Credential_Locks.Lock;
      Child_Guard : LLM.Credential_Locks.Lock;
      Start_Time : Ada.Real_Time.Time;
   begin
      Remove_Tree (Home);
      Ada.Directories.Create_Path (Home & "/.coyote");
      LLM.Credential_Locks.Acquire
        (Parent_Guard, Home & "/.coyote/codex-refresh.lock");
      Child := Start_Worker ("idle", Home, Ready, Gate);
      Await (Ready);
      LLM.Credential_Locks.Release (Parent_Guard);
      Start_Time := Ada.Real_Time.Clock;
      LLM.Credential_Locks.Acquire
        (Child_Guard, Home & "/.coyote/codex-refresh.lock",
         Timeout_Seconds => 2);
      Assert
        (Ada.Real_Time.To_Duration (Ada.Real_Time.Clock - Start_Time) < 1.0,
         "exec child must not inherit the parent's lock descriptor");
      Assert (State (Child) /= TERMINATED,
              "idle child must remain alive during second acquisition");
      LLM.Credential_Locks.Release (Child_Guard);
      Touch (Gate);
      declare
         Ignore : constant Integer := Wait (Child);
         pragma Unreferenced (Ignore);
      begin
         Child := Invalid_Handle;
      end;
      Remove_Tree (Home);
   exception
      when others =>
         Stop_And_Reap (Child);
         Remove_Tree (Home);
         raise;
   end Test_Lock_Close_On_Exec;

   package Caller is new AUnit.Test_Caller (Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test
        (Caller.Create
           ("LLM.Auth serializes concurrent cross-process refresh",
            Test_Concurrent_Ensure'Access));
      Result.Add_Test
        (Caller.Create
           ("LLM.Auth shares rejected-token recovery across processes",
            Test_Concurrent_Recover'Access));
      Result.Add_Test
        (Caller.Create
           ("LLM.Auth merges concurrent provider saves",
            Test_Concurrent_Save_Merge'Access));
      Result.Add_Test
        (Caller.Create
           ("LLM.Auth Codex save waits behind refresh lock",
            Test_Codex_Save_Waits'Access));
      Result.Add_Test
        (Caller.Create
           ("LLM.Auth refresh serializes against login and logout",
            Test_Refresh_Blocked_By_Login_And_Logout'Access));
      Result.Add_Test
        (Caller.Create
           ("LLM.Auth releases a killed process lock",
            Test_Killed_Lock_Holder'Access));
      Result.Add_Test
        (Caller.Create
           ("LLM.Auth lock descriptor closes on exec",
            Test_Lock_Close_On_Exec'Access));
      return Result;
   end Suite;
end LLM_Auth_Concurrency_Tests;
