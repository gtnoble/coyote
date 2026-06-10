with AUnit.Assertions;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with GNATCOLL.JSON;           use GNATCOLL.JSON;
with GNATCOLL.OS.FS;
with GNATCOLL.OS.Process;     use GNATCOLL.OS.Process;
with Nine_P.Client;

package body Subagent_Integration_Tests is

   use AUnit.Assertions;


   --  ── Helpers ──────────────────────────────────────────────────────────

   --  True when the acme 9P server socket is present in the namespace.
   function Acme_Running return Boolean is
   begin
      return Ada.Directories.Exists
               (Nine_P.Client.Namespace & "/acme");
   exception
      when others => return False;
   end Acme_Running;

   --  Locate the coyote binary under test.  Checks ../bin/coyote
   --  relative to the test working directory first, then the COYOTE_BIN
   --  environment variable.  Returns "" when the binary cannot be found.
   function Find_Coyote return String is
      Candidate : constant String := "../bin/coyote";
   begin
      if Ada.Directories.Exists (Candidate) then
         return Candidate;
      end if;
      declare
         Env_Bin : constant String :=
           Ada.Environment_Variables.Value ("COYOTE_BIN", "");
      begin
         if Env_Bin'Length > 0
           and then Ada.Directories.Exists (Env_Bin)
         then
            return Env_Bin;
         end if;
      end;
      return "";
   end Find_Coyote;

   --  Return everything before the first newline in S, or S itself when
   --  no newline is present.
   function First_Line (S : String) return String is
   begin
      for I in S'Range loop
         if S (I) = ASCII.LF then
            return S (S'First .. I - 1);
         end if;
      end loop;
      return S;
   end First_Line;

   --  Return the current process ID as a decimal string with no leading
   --  space.
   function PID_Image return String is
      function Getpid return Integer;
      pragma Import (C, Getpid, "getpid");
      Image : constant String := Integer'Image (Getpid);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end PID_Image;

   --  Extract a string field from a JSON object value.  Returns "" on
   --  any type mismatch or missing field rather than raising an exception,
   --  so callers can assert on the result instead of catching errors.
   function Json_Str
     (V : JSON_Value;
      F : UTF8_String) return String
   is
   begin
      if V.Kind /= JSON_Object_Type then
         return "";
      end if;
      if V.Has_Field (F)
        and then V.Get (F).Kind = JSON_String_Type
      then
         return V.Get (F).Get;
      end if;
      return "";
   end Json_Str;

   --  Copy one test prerequisite file into the subprocess HOME when it
   --  exists in the real HOME.
   procedure Copy_If_Exists
     (Source : String;
      Target : String) is
   begin
      if Ada.Directories.Exists (Source) then
         Ada.Directories.Copy_File (Source, Target);
      end if;
   end Copy_If_Exists;

   --  Prepare an isolated HOME for a spawned one-shot coyote subprocess.
   --
   --  The live model catalogue refresh can fail transiently, in which case
   --  coyote falls back to its cached catalogue under ~/.coyote/.  The
   --  subagent tests run the child with a temporary HOME, so copy the
   --  relevant cache files as well as auth/settings to preserve the same
   --  model-resolution behaviour as the parent environment.
   procedure Populate_Test_Home
     (Test_Home : String;
      Real_Home : String) is
      Real_Agent_Dir : constant String := Real_Home & "/.coyote";
      Test_Agent_Dir : constant String := Test_Home & "/.coyote";
   begin
      Ada.Directories.Create_Path (Test_Agent_Dir & "/sessions");
      Copy_If_Exists
        (Real_Agent_Dir & "/auth.json",
         Test_Agent_Dir & "/auth.json");
      Copy_If_Exists
        (Real_Agent_Dir & "/settings.json",
         Test_Agent_Dir & "/settings.json");
      Copy_If_Exists
        (Real_Agent_Dir & "/models.json",
         Test_Agent_Dir & "/models.json");
      Copy_If_Exists
        (Real_Agent_Dir & "/github_copilot_models_cache.json",
         Test_Agent_Dir & "/github_copilot_models_cache.json");
      Copy_If_Exists
        (Real_Agent_Dir & "/openrouter_models_cache.json",
         Test_Agent_Dir & "/openrouter_models_cache.json");
   end Populate_Test_Home;

   --  Synchronisation flag: the Runner task signals this once the
   --  subprocess has exited and its output has been captured.  The main
   --  task uses select/or delay to impose a wall-clock timeout.
   protected type Done_Flag is
      procedure Signal;
      entry     Wait;
   private
      Complete : Boolean := False;
   end Done_Flag;

   protected body Done_Flag is
      procedure Signal is
      begin
         Complete := True;
      end Signal;

      entry Wait when Complete is
      begin
         null;
      end Wait;
   end Done_Flag;

   --  ── Test_One_Shot_Returns_Json ────────────────────────────────────────
   --
   --  Verifies the complete happy path: coyote --one-shot prints one JSON
   --  line whose "output" field contains "PONG" and whose "session_id" is
   --  a 36-character UUID.

   procedure Test_One_Shot_Returns_Json (T : in out Test) is
      pragma Unreferenced (T);

      Coyote     : constant String  := Find_Coyote;
      Stdout_Out : Unbounded_String;
      Got_Result : Boolean          := False;
      Flag       : Done_Flag;

      task Runner;
      task body Runner is
         use GNATCOLL.OS.FS;
         Stdout_R, Stdout_W : File_Descriptor;
         Null_In            : File_Descriptor;
         Null_Err           : File_Descriptor;
         Args               : Argument_List;
         Env_Override       : Environment_Dict;
         Handle             : Process_Handle;
         Exit_Code          : Integer;
         pragma Unreferenced (Exit_Code);
         Test_Home : constant String :=
           "/tmp/coyote_subagent_test_" & PID_Image;
         Real_Home : constant String :=
           Ada.Environment_Variables.Value ("HOME", "");
      begin
         --  Create a writable temp HOME so coyote can write session
         --  files and refresh its auth token without touching the real
         --  user's HOME directory.
         if Ada.Directories.Exists (Test_Home) then
            Ada.Directories.Delete_Tree (Test_Home);
         end if;
         Populate_Test_Home (Test_Home, Real_Home);
         Env_Override.Include ("HOME", Test_Home);

         Open_Pipe (Stdout_R, Stdout_W);
         Null_In  := Open (Null_File, Read_Mode);
         Null_Err := Open (Null_File, Write_Mode);
         Args.Append (Coyote);
         Args.Append ("--one-shot");
         Args.Append ("--prompt");
         Args.Append
           ("Reply with only the word PONG and nothing else.");
         Handle := Start
           (Args        => Args,
            Env         => Env_Override,
            Stdin       => Null_In,
            Stdout      => Stdout_W,
            Stderr      => Null_Err,
            Cwd         => Ada.Directories.Current_Directory,
            Inherit_Env => True);
         Close (Null_In);
         Close (Null_Err);
         Close (Stdout_W);
         Stdout_Out := GNATCOLL.OS.FS.Read (Stdout_R);
         Close (Stdout_R);
         Exit_Code  := Wait (Handle);
         --  Clean up temp HOME now that coyote has exited.
         if Ada.Directories.Exists (Test_Home) then
            Ada.Directories.Delete_Tree (Test_Home);
         end if;
         Got_Result := True;
         Flag.Signal;
      exception
         when others =>
            if Ada.Directories.Exists (Test_Home) then
               Ada.Directories.Delete_Tree (Test_Home);
            end if;
            Flag.Signal;
      end Runner;

   begin
      if not Acme_Running then
         return;
      end if;
      if Coyote'Length = 0 then
         Assert (False, "coyote binary not found at ../bin/coyote");
         return;
      end if;

      select
         Flag.Wait;
      or
         delay 60.0;
      end select;

      Assert (Got_Result,
              "One-shot subprocess must complete within 60 s");
      declare
         Raw : constant String :=
           First_Line (To_String (Stdout_Out));
         R   : constant Read_Result := Read (Raw);
      begin
         Assert (R.Success,
                 "stdout must be valid JSON, got: " & Raw);
         declare
            Output_Text : constant String :=
              Json_Str (R.Value, "output");
            Session_Id  : constant String :=
              Json_Str (R.Value, "session_id");
         begin
            Assert
              (Output_Text'Length > 0,
               "JSON must have a non-empty ""output"" field");
            Assert
              (Ada.Strings.Fixed.Index (Output_Text, "PONG") > 0,
               "output should contain ""PONG"", got: " & Output_Text);
            Assert
              (Session_Id'Length = 36,
               "session_id must be a 36-character UUID, got: "
               & Session_Id);
         end;
      end;
   end Test_One_Shot_Returns_Json;

   --  ── Test_One_Shot_Fresh_Session_Each_Run ─────────────────────────────
   --
   --  Verifies that --one-shot implies --no-session: two consecutive
   --  invocations each start a fresh coyote session, so the returned
   --  session_id values must differ.

   procedure Test_One_Shot_Fresh_Session_Each_Run (T : in out Test) is
      pragma Unreferenced (T);

      Coyote : constant String  := Find_Coyote;
      Out_1  : Unbounded_String;
      Out_2  : Unbounded_String;
      Done_1 : Boolean          := False;
      Done_2 : Boolean          := False;
      Flag   : Done_Flag;

      --  Invoke coyote --one-shot once and store stdout in Result.
      --  Sets Done to True on successful completion.  Creates a fresh
      --  writable temp HOME for the subprocess so it can write session
      --  files and refresh auth tokens without touching the real HOME.
      procedure Run_One_Shot
        (Result : out Unbounded_String;
         Done   : out Boolean)
      is
         use GNATCOLL.OS.FS;
         Stdout_R, Stdout_W : File_Descriptor;
         Null_In            : File_Descriptor;
         Null_Err           : File_Descriptor;
         Args               : Argument_List;
         Env_Override       : Environment_Dict;
         Handle             : Process_Handle;
         Exit_Code          : Integer;
         pragma Unreferenced (Exit_Code);
         Test_Home : constant String :=
           "/tmp/coyote_subagent_test_" & PID_Image;
         Real_Home : constant String :=
           Ada.Environment_Variables.Value ("HOME", "");
      begin
         --  Recreate the temp HOME fresh for each invocation.
         if Ada.Directories.Exists (Test_Home) then
            Ada.Directories.Delete_Tree (Test_Home);
         end if;
         Populate_Test_Home (Test_Home, Real_Home);
         Env_Override.Include ("HOME", Test_Home);

         Open_Pipe (Stdout_R, Stdout_W);
         Null_In  := Open (Null_File, Read_Mode);
         Null_Err := Open (Null_File, Write_Mode);
         Args.Append (Coyote);
         Args.Append ("--one-shot");
         Args.Append ("--prompt");
         Args.Append ("Reply with the single word PONG.");
         Handle := Start
           (Args        => Args,
            Env         => Env_Override,
            Stdin       => Null_In,
            Stdout      => Stdout_W,
            Stderr      => Null_Err,
            Cwd         => Ada.Directories.Current_Directory,
            Inherit_Env => True);
         Close (Null_In);
         Close (Null_Err);
         Close (Stdout_W);
         Result    := GNATCOLL.OS.FS.Read (Stdout_R);
         Close (Stdout_R);
         Exit_Code := Wait (Handle);
         --  Clean up temp HOME now that coyote has exited.
         if Ada.Directories.Exists (Test_Home) then
            Ada.Directories.Delete_Tree (Test_Home);
         end if;
         Done := True;
      exception
         when others =>
            if Ada.Directories.Exists (Test_Home) then
               Ada.Directories.Delete_Tree (Test_Home);
            end if;
            raise;
      end Run_One_Shot;

      task Runner;
      task body Runner is
      begin
         Run_One_Shot (Out_1, Done_1);
         Run_One_Shot (Out_2, Done_2);
         Flag.Signal;
      exception
         when others => Flag.Signal;
      end Runner;

   begin
      if not Acme_Running then
         return;
      end if;
      if Coyote'Length = 0 then
         Assert (False, "coyote binary not found at ../bin/coyote");
         return;
      end if;

      select
         Flag.Wait;
      or
         delay 90.0;
      end select;

      Assert (Done_1, "First one-shot run must complete within 90 s");
      Assert (Done_2, "Second one-shot run must complete within 90 s");

      --  Extract both session IDs and verify they differ.
      declare
         --  Parse the session_id from a raw one-shot stdout string.
         function Extract_Session_Id (Raw : String) return String is
            Line : constant String      := First_Line (Raw);
            R    : constant Read_Result := Read (Line);
         begin
            if not R.Success then
               return "";
            end if;
            return Json_Str (R.Value, "session_id");
         end Extract_Session_Id;

         Sess_1 : constant String :=
           Extract_Session_Id (To_String (Out_1));
         Sess_2 : constant String :=
           Extract_Session_Id (To_String (Out_2));
      begin
         Assert
           (Sess_1'Length = 36,
            "First run must return a UUID session_id, got: " & Sess_1);
         Assert
           (Sess_2'Length = 36,
            "Second run must return a UUID session_id, got: " & Sess_2);
         Assert
           (Sess_1 /= Sess_2,
            "Two --one-shot runs must use distinct sessions; "
            & "both returned: " & Sess_1);
      end;
   end Test_One_Shot_Fresh_Session_Each_Run;

   --  ── Test_One_Shot_Prompt_Failure_Has_Session_Id ──────────────────────
   --
   --  Verifies that when Run_Prompt raises an exception (triggered here by
   --  supplying an invalid OpenRouter API key so the provider gets an
   --  HTTP 401), the one-shot result JSON still carries both an "error"
   --  field and a well-formed "session_id" UUID.
   --
   --  The OpenRouter model catalogue is restored from the cache copied by
   --  Populate_Test_Home, so Agent.Create succeeds without any live
   --  network calls.  Only Run_Prompt touches the API and fails.

   procedure Test_One_Shot_Prompt_Failure_Has_Session_Id
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Coyote     : constant String  := Find_Coyote;
      Stdout_Out : Unbounded_String;
      Got_Result : Boolean          := False;
      Flag       : Done_Flag;

      task Runner;
      task body Runner is
         use GNATCOLL.OS.FS;
         Stdout_R, Stdout_W : File_Descriptor;
         Null_In            : File_Descriptor;
         Null_Err           : File_Descriptor;
         Args               : Argument_List;
         Env_Override       : Environment_Dict;
         Handle             : Process_Handle;
         Exit_Code          : Integer;
         pragma Unreferenced (Exit_Code);
         Test_Home : constant String :=
           "/tmp/coyote_subagent_fail_test_" & PID_Image;
         Real_Home : constant String :=
           Ada.Environment_Variables.Value ("HOME", "");
      begin
         if Ada.Directories.Exists (Test_Home) then
            Ada.Directories.Delete_Tree (Test_Home);
         end if;
         --  Populate with real settings and model caches so that
         --  Agent.Create can resolve the openrouter provider without
         --  any live network calls.
         Populate_Test_Home (Test_Home, Real_Home);

         --  Override OPENROUTER_API_KEY to an invalid value.  Agent.Create
         --  succeeds (catalogue loaded from cache), but Run_Prompt gets an
         --  HTTP 401 and raises Constraint_Error, which exercises the
         --  Run_Queued_Prompt exception handler.
         Env_Override.Include ("HOME", Test_Home);
         Env_Override.Include
           ("OPENROUTER_API_KEY", "invalid_token_for_test");

         Open_Pipe (Stdout_R, Stdout_W);
         Null_In  := Open (Null_File, Read_Mode);
         Null_Err := Open (Null_File, Write_Mode);
         Args.Append (Coyote);
         Args.Append ("--one-shot");
         Args.Append ("--model");
         Args.Append ("openrouter/openai/gpt-4o-mini");
         Args.Append ("--prompt");
         Args.Append ("Hello.");
         Handle := Start
           (Args        => Args,
            Env         => Env_Override,
            Stdin       => Null_In,
            Stdout      => Stdout_W,
            Stderr      => Null_Err,
            Cwd         => Ada.Directories.Current_Directory,
            Inherit_Env => True);
         Close (Null_In);
         Close (Null_Err);
         Close (Stdout_W);
         Stdout_Out := GNATCOLL.OS.FS.Read (Stdout_R);
         Close (Stdout_R);
         Exit_Code  := Wait (Handle);
         if Ada.Directories.Exists (Test_Home) then
            Ada.Directories.Delete_Tree (Test_Home);
         end if;
         Got_Result := True;
         Flag.Signal;
      exception
         when others =>
            if Ada.Directories.Exists (Test_Home) then
               Ada.Directories.Delete_Tree (Test_Home);
            end if;
            Flag.Signal;
      end Runner;

   begin
      if not Acme_Running then
         return;
      end if;
      if Coyote'Length = 0 then
         Assert (False, "coyote binary not found at ../bin/coyote");
         return;
      end if;

      select
         Flag.Wait;
      or
         delay 30.0;
      end select;

      Assert (Got_Result,
              "Prompt-failure one-shot must complete within 30 s");
      declare
         Raw : constant String :=
           First_Line (To_String (Stdout_Out));
         R   : constant Read_Result := Read (Raw);
      begin
         Assert (R.Success,
                 "stdout must be valid JSON on prompt failure, got: " & Raw);
         declare
            Error_Text : constant String :=
              Json_Str (R.Value, "error");
            Session_Id : constant String :=
              Json_Str (R.Value, "session_id");
         begin
            Assert
              (Error_Text'Length > 0,
               "JSON must have a non-empty ""error"" field"
               & " on prompt failure");
            Assert
              (Session_Id'Length = 36,
               "JSON must have a 36-char ""session_id"""
               & " even on prompt failure,"
               & " got: " & Session_Id);
         end;
      end;
   end Test_One_Shot_Prompt_Failure_Has_Session_Id;

end Subagent_Integration_Tests;
