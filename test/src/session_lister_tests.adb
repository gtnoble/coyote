with AUnit.Assertions;
with Ada.Containers;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with LLM.Session_Store;
with LLM.Types;
with Session_Fixture;
with Session_Lister;        use Session_Lister;

package body Session_Lister_Tests is

   use AUnit.Assertions;
   use type Ada.Containers.Count_Type;
   use type LLM.Types.Role;

   function Getpid return Integer;
   pragma Import (C, Getpid, "getpid");

   function PID_Image return String is
      Image : constant String := Integer'Image (Getpid);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end PID_Image;

   function Long_Long_Image (Value : Long_Long_Integer) return String is
      Image : constant String := Long_Long_Integer'Image (Value);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end Long_Long_Image;

   Test_Home_Root : constant String :=
     "/tmp/session_lister_tests_" & PID_Image;

   procedure Restore_Env (Name : String; Was_Set : Boolean; Value : String) is
   begin
      if Was_Set then
         Ada.Environment_Variables.Set (Name, Value);
      else
         Ada.Environment_Variables.Clear (Name);
      end if;
   end Restore_Env;

   procedure Prepare_Test_Home (Home : String) is
   begin
      if Ada.Directories.Exists (Home) then
         Ada.Directories.Delete_Tree (Home);
      end if;

      Ada.Directories.Create_Path (Home & "/.coyote");
      Ada.Environment_Variables.Set ("HOME", Home);
   end Prepare_Test_Home;

   procedure Cleanup_Test_Home (Home : String) is
   begin
      if Ada.Directories.Exists (Home) then
         Ada.Directories.Delete_Tree (Home);
      end if;
   exception
      when others =>
         null;
   end Cleanup_Test_Home;

   procedure Write_File (Path : String; Content : String) is
      F : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (F, Content);
      Ada.Text_IO.Close (F);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (F) then
            Ada.Text_IO.Close (F);
         end if;
         raise;
   end Write_File;

   procedure Rewrite_Native_Header
     (Home       : String;
      Cwd_Slug   : String;
      UUID       : String;
      Name       : String;
      Created_At : Long_Long_Integer)
   is
      Path : constant String :=
        Session_Fixture.Session_File_Path (Home, Cwd_Slug, UUID);
   begin
      Write_File
        (Path,
         "{""version"":1,""id"":""" & UUID & ""","
         & """createdAt"":" & Long_Long_Image (Created_At)
         & ",""workDir"":""" & Cwd_Slug & """}"
         & ASCII.LF
         & "{""role"":""session_info"",""name"":""" & Name
         & """,""timestamp"":" & Long_Long_Image (Created_At)
         & "}"
         & ASCII.LF);
   end Rewrite_Native_Header;

   --  ── Encode_Cwd ────────────────────────────────────────────────────────

   procedure Test_Encode_Cwd_Absolute (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (Encode_Cwd ("/home/user/proj") = "--home-user-proj--",
              "Absolute path encoding");
      Assert (Encode_Cwd ("/home/gtnoble/Projects/coyote")
              = "--home-gtnoble-Projects-coyote--",
              "Deeper absolute path");
   end Test_Encode_Cwd_Absolute;

   procedure Test_Encode_Cwd_Relative (T : in out Test) is
      pragma Unreferenced (T);
   begin
      --  A path not starting with '/' is kept as-is (slashes -> dashes).
      Assert (Encode_Cwd ("foo/bar") = "--foo-bar--",
              "Relative path encoding");
   end Test_Encode_Cwd_Relative;

   procedure Test_Encode_Cwd_Empty (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (Encode_Cwd ("") = "----", "Empty path -> '----'");
      Assert (Encode_Cwd ("/") = "----",
              "Root '/' -> '----' (leading slash stripped, nothing left)");
   end Test_Encode_Cwd_Empty;

   --  ── Format_Timestamp ─────────────────────────────────────────────────

   procedure Test_Format_Timestamp (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert
        (Format_Timestamp ("2024-01-15T10:30:00.000Z") = "2024-01-15 10:30",
         "ISO timestamp with Z suffix");
      Assert
        (Format_Timestamp ("2025-12-31T23:59:00+00:00") = "2025-12-31 23:59",
         "ISO timestamp with offset");
   end Test_Format_Timestamp;

   procedure Test_Format_Timestamp_Short (T : in out Test) is
      pragma Unreferenced (T);
   begin
      --  Short/empty timestamps are returned verbatim.
      Assert (Format_Timestamp ("2024") = "2024",     "Short string verbatim");
      Assert (Format_Timestamp ("") = "",             "Empty string verbatim");
   end Test_Format_Timestamp_Short;

   --  ── Parse_Session_File ────────────────────────────────────────────────

   --  Write lines to a temp file and return its path.
   function Write_Temp (Lines : String) return String is
      Path : constant String := "/tmp/test_pi_session.jsonl";
      F    : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (F, Lines);
      Ada.Text_IO.Close (F);
      return Path;
   end Write_Temp;

   procedure Test_Parse_Session_Full (T : in out Test) is
      pragma Unreferenced (T);
      Path : constant String := Write_Temp
        ("{""type"":""session"","
         & """id"":""abc-def-123"","
         & """timestamp"":""2024-06-01T12:00:00Z""}"
         & ASCII.LF
         & "{""type"":""session_info"",""name"":""My Session""}"
         & ASCII.LF
         & "{""type"":""message"","
         & """message"":{""role"":""user"","
         & """content"":[{""type"":""text"",""text"":""Hello pi""}]}}"
         & ASCII.LF);
      Info : constant Session_Info := Parse_Session_File (Path);
   begin
      Assert (To_String (Info.UUID)    = "abc-def-123",
              "UUID should be 'abc-def-123'");
      Assert (To_String (Info.Name)    = "My Session",
              "Name should be 'My Session'");
      Assert (To_String (Info.Date)    = "2024-06-01 12:00",
              "Date should be '2024-06-01 12:00'");
      Assert (To_String (Info.Snippet) = "Hello pi",
              "Snippet should be 'Hello pi'");
   end Test_Parse_Session_Full;

   procedure Test_Parse_Session_No_Name (T : in out Test) is
      pragma Unreferenced (T);
      Path : constant String := Write_Temp
        ("{""type"":""session"","
         & """id"":""xyz-789"","
         & """timestamp"":""2024-03-10T08:15:00Z""}"
         & ASCII.LF);
      Info : constant Session_Info := Parse_Session_File (Path);
   begin
      Assert (To_String (Info.UUID)    = "xyz-789",
              "UUID should be parsed");
      Assert (To_String (Info.Name)    = "",
              "Name should be empty when absent");
      Assert (To_String (Info.Snippet) = "",
              "Snippet should be empty when no messages");
      Assert (To_String (Info.Date)    = "2024-03-10 08:15",
              "Date should be formatted");
   end Test_Parse_Session_No_Name;

   procedure Test_Parse_Session_Bad_Json (T : in out Test) is
      pragma Unreferenced (T);
      Path : constant String := Write_Temp
        ("this is not json" & ASCII.LF
         & "also not json" & ASCII.LF);
      Info : constant Session_Info := Parse_Session_File (Path);
   begin
      Assert (To_String (Info.UUID) = "",
              "UUID should be empty when file has no valid session record");
   end Test_Parse_Session_Bad_Json;

   procedure Test_Parse_Session_Long_Line (T : in out Test) is
      --  Regression: Ada.Text_IO.Get_Line (function form) recurses in GNAT
      --  for every chunk of a long line, causing STORAGE_ERROR on lines
      --  of ~100 KiB or more.  The fixed Read_Line helper uses the procedure
      --  form in a loop and must survive any line length.
      pragma Unreferenced (T);
      Long_Text : constant String (1 .. 100_000) := (others => 'x');
      Path      : constant String :=
        "/tmp/test_pi_long_line.jsonl";
      F         : Ada.Text_IO.File_Type;
      Info      : Session_Info;
   begin
      Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put_Line
        (F,
         "{""type"":""session"","
         & """id"":""long-line-uuid"","
         & """timestamp"":""2024-06-01T12:00:00Z""}");
      Ada.Text_IO.Put_Line
        (F,
         "{""type"":""message"","
         & """message"":{""role"":""user"","
         & """content"":[{""type"":""text"","
         & """text"":""" & Long_Text & """}]}}");
      Ada.Text_IO.Close (F);

      Info := Parse_Session_File (Path);

      Assert (To_String (Info.UUID) = "long-line-uuid",
              "UUID must be parsed correctly despite a 100 KiB JSONL line");
      Assert (Length (Info.Snippet) > 0,
              "Snippet must be extracted from the long text line");
   exception
      when others =>
         if Ada.Text_IO.Is_Open (F) then
            Ada.Text_IO.Close (F);
         end if;
         raise;
   end Test_Parse_Session_Long_Line;

   --  ── Find_Session_File ─────────────────────────────────────────────────
   --
   --  These tests create temporary JSONL files under a dedicated test slug
   --  inside $HOME/.coyote/sessions/ and clean them up afterward.

   --  Directory slug used exclusively by these tests.
   function Sessions_Test_Dir_A return String is
   begin
      return Ada.Environment_Variables.Value ("HOME", "")
             & "/.coyote/sessions/--coyote-test--";
   end Sessions_Test_Dir_A;

   function Sessions_Test_Dir_B return String is
   begin
      return Ada.Environment_Variables.Value ("HOME", "")
             & "/.coyote/sessions/--coyote-test-B--";
   end Sessions_Test_Dir_B;

   --  Create JSONL file containing UUID in its name under Dir.
   --  Returns the full path of the created file.
   function Write_Session_File
     (Dir  : String;
      UUID : String) return String
   is
      Path : constant String := Dir & "/" & UUID & ".jsonl";
      F    : Ada.Text_IO.File_Type;
   begin
      if not Ada.Directories.Exists (Dir) then
         Ada.Directories.Create_Path (Dir);
      end if;
      Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put_Line
        (F,
         "{""type"":""session"","
         & """id"":""" & UUID & ""","
         & """timestamp"":""2024-01-01T00:00:00Z""}");
      Ada.Text_IO.Close (F);
      return Path;
   end Write_Session_File;

   --  Delete the test JSONL file if it exists.
   procedure Delete_Session_File (Dir : String; UUID : String) is
      Path : constant String := Dir & "/" & UUID & ".jsonl";
   begin
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_File (Path);
      end if;
   end Delete_Session_File;

   procedure Test_Find_Session_File_Found (T : in out Test) is
      pragma Unreferenced (T);
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Home         : constant String :=
        Test_Home_Root & "/find-found";
      UUID         : constant String := "test-piacme-find-found";
   begin
      Prepare_Test_Home (Home);
      declare
         Path : constant String :=
           Write_Session_File (Sessions_Test_Dir_A, UUID);
      begin
         Assert (Find_Session_File (UUID) = Path,
                 "Find_Session_File should return the full path of "
                 & "the matching file");
         Delete_Session_File (Sessions_Test_Dir_A, UUID);
      exception
         when others =>
            Delete_Session_File (Sessions_Test_Dir_A, UUID);
            raise;
      end;
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Find_Session_File_Found;

   procedure Test_Find_Session_File_Not_Found (T : in out Test) is
      pragma Unreferenced (T);
      UUID : constant String :=
        "test-piacme-no-such-uuid-xyzzy-99999999";
   begin
      --  This UUID should not match any real session file.
      Assert (Find_Session_File (UUID) = "",
              "Find_Session_File should return empty when UUID not found");
   end Test_Find_Session_File_Not_Found;

   procedure Test_Find_Session_File_Any_Dir (T : in out Test) is
      pragma Unreferenced (T);
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Home         : constant String :=
        Test_Home_Root & "/find-any-dir";
      UUID         : constant String := "test-piacme-find-any-dir";
   begin
      Prepare_Test_Home (Home);
      declare
         Path : constant String :=
           Write_Session_File (Sessions_Test_Dir_B, UUID);
      begin
         --  File is in a different directory slug; should still be found.
         Assert (Find_Session_File (UUID) = Path,
                 "Find_Session_File should locate sessions in any "
                 & "subdirectory, not just the current CWD slug");
         Delete_Session_File (Sessions_Test_Dir_B, UUID);
      exception
         when others =>
            Delete_Session_File (Sessions_Test_Dir_B, UUID);
            raise;
      end;
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Find_Session_File_Any_Dir;

   --  ── Fork_Session ──────────────────────────────────────────────────────
   --
   --  Test directory used for fork source files.
   function Sessions_Fork_Dir return String is
   begin
      return Ada.Environment_Variables.Value ("HOME", "")
             & "/.coyote/sessions/--coyote-fork-test--";
   end Sessions_Fork_Dir;

   --  Target CWD for forked sessions (maps to the fork test dir).
   Fork_Target_Cwd : constant String := "/coyote-fork-test";

   --  Build a two-turn session JSONL string.
   --  Turn 1: user "Hello" / assistant "World"
   --  Turn 2: user "Foo"   / assistant "Bar"
   function Two_Turn_JSONL (UUID : String) return String is
   begin
      return
        "{""type"":""session"",""id"":""" & UUID & ""","
        & """timestamp"":""2024-01-01T00:00:00Z""}" & ASCII.LF
        & "{""type"":""session_info"",""name"":""Original""}" & ASCII.LF
        --  Turn 1
        & "{""type"":""message"",""message"":{""role"":""user"","
        & """content"":[{""type"":""text"",""text"":""Hello""}]}}"
        & ASCII.LF
        & "{""type"":""message"",""message"":{""role"":""assistant"","
        & """content"":[{""type"":""text"",""text"":""World""}]}}"
        & ASCII.LF
        --  Turn 2
        & "{""type"":""message"",""message"":{""role"":""user"","
        & """content"":[{""type"":""text"",""text"":""Foo""}]}}"
        & ASCII.LF
        & "{""type"":""message"",""message"":{""role"":""assistant"","
        & """content"":[{""type"":""text"",""text"":""Bar""}]}}"
        & ASCII.LF;
   end Two_Turn_JSONL;

   --  Write a JSONL string as a session file under Sessions_Fork_Dir.
   procedure Write_Fork_Source (UUID : String; Content : String) is
      Path : constant String :=
        Sessions_Fork_Dir & "/" & UUID & ".jsonl";
      F    : Ada.Text_IO.File_Type;
   begin
      if not Ada.Directories.Exists (Sessions_Fork_Dir) then
         Ada.Directories.Create_Path (Sessions_Fork_Dir);
      end if;
      Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (F, Content);
      Ada.Text_IO.Close (F);
   end Write_Fork_Source;

   --  Delete the source session file from Sessions_Fork_Dir.
   procedure Delete_Fork_Source (UUID : String) is
      Path : constant String :=
        Sessions_Fork_Dir & "/" & UUID & ".jsonl";
   begin
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_File (Path);
      end if;
   end Delete_Fork_Source;

   --  Delete a fork-result session by its UUID from the target dir.
   procedure Delete_Fork_Result (UUID : String) is
      Target_Dir : constant String := Sessions_Dir (Fork_Target_Cwd);
      Path       : constant String :=
        Target_Dir & "/" & UUID & ".jsonl";
   begin
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_File (Path);
      end if;
   end Delete_Fork_Result;

   --  Read the whole content of Path as a String.
   function Read_File (Path : String) return String is
      F   : Ada.Text_IO.File_Type;
      Buf : Unbounded_String;
   begin
      Ada.Text_IO.Open (F, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (F) loop
         Append (Buf, Ada.Text_IO.Get_Line (F) & ASCII.LF);
      end loop;
      Ada.Text_IO.Close (F);
      return To_String (Buf);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (F) then
            Ada.Text_IO.Close (F);
         end if;
         return "";
   end Read_File;

   --  Fork after turn 1 of a two-turn session; verify the result file
   --  contains turn 1 messages but not turn 2, and carries a fork name.
   procedure Test_Fork_Session_One_Turn (T : in out Test) is
      pragma Unreferenced (T);
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Home         : constant String :=
        Test_Home_Root & "/fork-one-turn";
      Src_UUID     : constant String := "test-fork-src-one-turn";
   begin
      Prepare_Test_Home (Home);
      Write_Fork_Source (Src_UUID, Two_Turn_JSONL (Src_UUID));
      declare
         New_UUID : constant String :=
           Fork_Session (Src_UUID, 1, Fork_Target_Cwd);
      begin
         Assert (New_UUID'Length > 0,
                 "Fork_Session should return a non-empty UUID");
         declare
            Content : constant String :=
              Read_File (Sessions_Dir (Fork_Target_Cwd)
                         & "/" & New_UUID & ".jsonl");
         begin
            Assert (Ada.Strings.Fixed.Index (Content, "Hello") > 0,
                    "Fork @1 should contain turn-1 user message");
            Assert (Ada.Strings.Fixed.Index (Content, "World") > 0,
                    "Fork @1 should contain turn-1 assistant message");
            Assert (Ada.Strings.Fixed.Index (Content, "Foo") = 0,
                    "Fork @1 must not contain turn-2 user message");
            Assert (Ada.Strings.Fixed.Index (Content, "Bar") = 0,
                    "Fork @1 must not contain turn-2 assistant message");
            Assert (Ada.Strings.Fixed.Index (Content, "Fork of") > 0,
                    "Fork result should carry a fork session name");
            Assert (Ada.Strings.Fixed.Index (Content, "@1") > 0,
                    "Fork name should include the turn number");
         end;
         Delete_Fork_Result (New_UUID);
      end;
      Delete_Fork_Source (Src_UUID);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Delete_Fork_Source (Src_UUID);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Fork_Session_One_Turn;

   --  Fork after turn 2 (the last turn); both turns must be present.
   procedure Test_Fork_Session_Second_Turn (T : in out Test) is
      pragma Unreferenced (T);
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Home         : constant String :=
        Test_Home_Root & "/fork-second-turn";
      Src_UUID     : constant String := "test-fork-src-two-turn";
   begin
      Prepare_Test_Home (Home);
      Write_Fork_Source (Src_UUID, Two_Turn_JSONL (Src_UUID));
      declare
         New_UUID : constant String :=
           Fork_Session (Src_UUID, 2, Fork_Target_Cwd);
      begin
         Assert (New_UUID'Length > 0,
                 "Fork @2 should succeed for a two-turn session");
         declare
            Content : constant String :=
              Read_File (Sessions_Dir (Fork_Target_Cwd)
                         & "/" & New_UUID & ".jsonl");
         begin
            Assert (Ada.Strings.Fixed.Index (Content, "Hello") > 0,
                    "Fork @2 should contain turn-1 user message");
            Assert (Ada.Strings.Fixed.Index (Content, "Foo") > 0,
                    "Fork @2 should contain turn-2 user message");
            Assert (Ada.Strings.Fixed.Index (Content, "Bar") > 0,
                    "Fork @2 should contain turn-2 assistant message");
         end;
         Delete_Fork_Result (New_UUID);
      end;
      Delete_Fork_Source (Src_UUID);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Delete_Fork_Source (Src_UUID);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Fork_Session_Second_Turn;

   --  Requesting a turn that does not exist returns "".
   procedure Test_Fork_Session_Beyond_End (T : in out Test) is
      pragma Unreferenced (T);
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Home         : constant String :=
        Test_Home_Root & "/fork-beyond-end";
      Src_UUID     : constant String := "test-fork-src-beyond";
   begin
      Prepare_Test_Home (Home);
      Write_Fork_Source (Src_UUID, Two_Turn_JSONL (Src_UUID));
      Assert (Fork_Session (Src_UUID, 99, Fork_Target_Cwd) = "",
              "Fork beyond last turn should return empty string");
      Delete_Fork_Source (Src_UUID);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Delete_Fork_Source (Src_UUID);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Fork_Session_Beyond_End;

   --  Non-existent source UUID returns "".
   procedure Test_Fork_Session_Missing_Src (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert
        (Fork_Session ("no-such-uuid-xyzzy-999999", 1, Fork_Target_Cwd) = "",
         "Fork with non-existent source should return empty string");
   end Test_Fork_Session_Missing_Src;

   procedure Test_List_Sessions_Newest_First (T : in out Test) is
      pragma Unreferenced (T);

      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Home         : constant String :=
        Test_Home_Root & "/list-sessions-newest-first";
      Cwd          : constant String := "/tmp/session-lister-newest-first";
      Cwd_Slug     : constant String := Encode_Cwd (Cwd);
      Newest_Ms    : constant Long_Long_Integer := 1_735_689_600_000;
      Middle_Ms    : constant Long_Long_Integer := 1_704_067_200_000;
      Oldest_Ms    : constant Long_Long_Integer := 1_672_531_200_000;
   begin
      Prepare_Test_Home (Home);
      declare
         Middle_UUID : constant String :=
           Session_Fixture.Create_Native_Session
             (Home     => Home,
              Cwd_Slug => Cwd_Slug,
              Name     => "middle");
         Newest_UUID : constant String :=
           Session_Fixture.Create_Native_Session
             (Home     => Home,
              Cwd_Slug => Cwd_Slug,
              Name     => "newest");
         Oldest_UUID : constant String :=
           Session_Fixture.Create_Native_Session
             (Home     => Home,
              Cwd_Slug => Cwd_Slug,
              Name     => "oldest");
         Sessions    : Session_Vectors.Vector;
      begin
         Rewrite_Native_Header
           (Home       => Home,
            Cwd_Slug   => Cwd_Slug,
            UUID       => Middle_UUID,
            Name       => "middle",
            Created_At => Middle_Ms);
         Rewrite_Native_Header
           (Home       => Home,
            Cwd_Slug   => Cwd_Slug,
            UUID       => Newest_UUID,
            Name       => "newest",
            Created_At => Newest_Ms);
         Rewrite_Native_Header
           (Home       => Home,
            Cwd_Slug   => Cwd_Slug,
            UUID       => Oldest_UUID,
            Name       => "oldest",
            Created_At => Oldest_Ms);

         Sessions := List_Sessions (Cwd);

         Assert (Sessions.Length = 3, "Three native sessions should list");
         Assert
           (To_String (Sessions.Element (0).UUID) = Newest_UUID,
            "List_Sessions should sort native sessions newest first");
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_List_Sessions_Newest_First;

   procedure Test_List_Sessions_Skips_Invalid_Files (T : in out Test) is
      pragma Unreferenced (T);

      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Home         : constant String :=
        Test_Home_Root & "/list-sessions-skips-invalid";
      Cwd          : constant String := "/tmp/session-lister-invalid-files";
      Cwd_Slug     : constant String := Encode_Cwd (Cwd);
      Dir          : constant String :=
        Home & "/.coyote/sessions/" & Cwd_Slug;
   begin
      Prepare_Test_Home (Home);
      declare
         Valid_UUID : constant String :=
           Session_Fixture.Create_Native_Session
             (Home     => Home,
              Cwd_Slug => Cwd_Slug,
              Name     => "valid native session");
         pragma Unreferenced (Valid_UUID);
         Sessions   : Session_Vectors.Vector;
      begin
         Ada.Directories.Create_Path (Dir);
         Write_File (Dir & "/not-a-session.txt", "garbage" & ASCII.LF);

         Sessions := List_Sessions (Cwd);

         Assert
           (Sessions.Length = 1,
            "List_Sessions should ignore non-session files in the directory");
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_List_Sessions_Skips_Invalid_Files;

   procedure Test_Fork_Native_Format_Preserves_Turn_Boundary
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Home         : constant String :=
        Test_Home_Root & "/fork-native-turn-boundary";
      Source_Cwd   : constant String := "/tmp/native-fork-source";
      Target_Cwd   : constant String := "/tmp/native-fork-target";
      Source_Slug  : constant String := Encode_Cwd (Source_Cwd);
   begin
      Prepare_Test_Home (Home);
      declare
         Source_UUID : constant String :=
           Session_Fixture.Create_Native_Session
             (Home     => Home,
              Cwd_Slug => Source_Slug,
              Name     => "source native session");
      begin
         Session_Fixture.Append_User_Message
           (Home     => Home,
            Cwd_Slug => Source_Slug,
            UUID     => Source_UUID,
            Text     => "Turn one question");
         Session_Fixture.Append_Assistant_Text
           (Home     => Home,
            Cwd_Slug => Source_Slug,
            UUID     => Source_UUID,
            Text     => "Turn one answer");
         Session_Fixture.Append_Turn_End
           (Home     => Home,
            Cwd_Slug => Source_Slug,
            UUID     => Source_UUID);
         Session_Fixture.Append_User_Message
           (Home     => Home,
            Cwd_Slug => Source_Slug,
            UUID     => Source_UUID,
            Text     => "Turn two question");
         Session_Fixture.Append_Assistant_Text
           (Home     => Home,
            Cwd_Slug => Source_Slug,
            UUID     => Source_UUID,
            Text     => "Turn two answer");

         declare
            Fork_UUID : constant String :=
              Fork_Session (Source_UUID, 1, Target_Cwd);
            Messages  : constant LLM.Types.Message_Vectors.Vector :=
              LLM.Session_Store.Load_Messages (Fork_UUID);
         begin
            Assert (Fork_UUID'Length > 0, "Fork_Session should succeed");
            Assert
              (Messages.Length = 2,
               "Forked native session should contain only the first turn");
            Assert
              (Messages.Element (0).Role = LLM.Types.User,
               "Forked message 1 should be the first-turn user message");
            Assert
              (Messages.Element (1).Role = LLM.Types.Assistant,
               "Forked message 2 should be the first-turn assistant message");
            Assert
              (To_String (Messages.Element (0).Content.Element (0).Text)
                 = "Turn one question",
               "Fork should preserve the first-turn user text");
            Assert
              (To_String (Messages.Element (1).Content.Element (0).Text)
                 = "Turn one answer",
               "Fork should preserve the first-turn assistant text");
         end;
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Fork_Native_Format_Preserves_Turn_Boundary;

end Session_Lister_Tests;