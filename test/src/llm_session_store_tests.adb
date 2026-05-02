with AUnit.Assertions;
with Ada.Containers;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNATCOLL.JSON;
with LLM.Session_Store;
with LLM.Types;
with Session_Lister;

package body LLM_Session_Store_Tests is

   use AUnit.Assertions;
   use type Ada.Containers.Count_Type;
   use type GNATCOLL.JSON.JSON_Value_Type;
   use type LLM.Types.Content_Block_Kind;
   use type LLM.Types.Role;

   function Getpid return Integer;
   pragma Import (C, Getpid, "getpid");

   function PID_Image return String is
      Image : constant String := Integer'Image (Getpid);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end PID_Image;

   Test_Root : constant String := "/tmp/llm_session_test_" & PID_Image;
   Source_Cwd : constant String := "/tmp/llm_session_store_source";
   Target_Cwd : constant String := "/tmp/llm_session_store_target";

   procedure Restore_Env (Name : String; Was_Set : Boolean; Value : String) is
   begin
      if Was_Set then
         Ada.Environment_Variables.Set (Name, Value);
      else
         Ada.Environment_Variables.Clear (Name);
      end if;
   end Restore_Env;

   procedure Cleanup_Test_Root is
   begin
      if Ada.Directories.Exists (Test_Root) then
         Ada.Directories.Delete_Tree (Test_Root);
      end if;
   exception
      when others =>
         null;
   end Cleanup_Test_Root;

   procedure Prepare_Test_Home is
   begin
      Cleanup_Test_Root;
      Ada.Directories.Create_Path (Test_Root & "/.pi/agent");
      Ada.Environment_Variables.Set ("HOME", Test_Root);
   end Prepare_Test_Home;

   function Contains (Text : String; Pattern : String) return Boolean is
   begin
      return Ada.Strings.Fixed.Index (Text, Pattern) > 0;
   end Contains;

   function Read_First_Line (Path : String) return String is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      declare
         Line : constant String := Ada.Text_IO.Get_Line (File);
      begin
         Ada.Text_IO.Close (File);
         return Line;
      end;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         raise;
   end Read_First_Line;

   function Read_File (Path : String) return String is
      File    : Ada.Text_IO.File_Type;
      Content : Unbounded_String;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         Append (Content, Ada.Text_IO.Get_Line (File));
         Append (Content, ASCII.LF);
      end loop;
      Ada.Text_IO.Close (File);
      return To_String (Content);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         raise;
   end Read_File;

   function Get_String_Field
     (Value : GNATCOLL.JSON.JSON_Value;
      Field : String) return String
   is
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind = GNATCOLL.JSON.JSON_String_Type
      then
         return Value.Get (Field).Get;
      end if;
      return "";
   end Get_String_Field;

   function Get_Integer_Field
     (Value : GNATCOLL.JSON.JSON_Value;
      Field : String) return Long_Integer
   is
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind = GNATCOLL.JSON.JSON_Int_Type
      then
         return Value.Get (Field).Get;
      end if;
      return 0;
   end Get_Integer_Field;

   function Make_User_Message (Text : String) return LLM.Types.Message is
      Content : LLM.Types.Content_Block_Vectors.Vector;
   begin
      Content.Append
        ((Kind => LLM.Types.Text_Block,
          Text => To_Unbounded_String (Text)));

      return
        (Role      => LLM.Types.User,
         Content   => Content,
         Tok_Usage => (others => 0),
         Stop      => LLM.Types.Unknown_Stop,
         Timestamp => Null_Unbounded_String);
   end Make_User_Message;

   function Make_Assistant_Text (Text : String) return LLM.Types.Message is
      Content : LLM.Types.Content_Block_Vectors.Vector;
   begin
      Content.Append
        ((Kind => LLM.Types.Text_Block,
          Text => To_Unbounded_String (Text)));

      return
        (Role      => LLM.Types.Assistant,
         Content   => Content,
         Tok_Usage =>
           (Input => 11, Output => 7, Cache_Read => 3, Cache_Write => 2),
         Stop      => LLM.Types.Stop,
         Timestamp => Null_Unbounded_String);
   end Make_Assistant_Text;

   function Make_Assistant_Tool_Call return LLM.Types.Message is
      Content : LLM.Types.Content_Block_Vectors.Vector;
   begin
      Content.Append
        ((Kind           => LLM.Types.Tool_Call_Block,
          Tool_Call_Id   => To_Unbounded_String ("call-1"),
          Tool_Name      => To_Unbounded_String ("read"),
          Arguments_Json => To_Unbounded_String
            ("{""path"":""demo.adb""}")));

      return
        (Role      => LLM.Types.Assistant,
         Content   => Content,
         Tok_Usage =>
           (Input => 20, Output => 5, Cache_Read => 0, Cache_Write => 0),
         Stop      => LLM.Types.Tool_Use,
         Timestamp => Null_Unbounded_String);
   end Make_Assistant_Tool_Call;

   function Make_Assistant_Thinking_Text return LLM.Types.Message is
      Content : LLM.Types.Content_Block_Vectors.Vector;
   begin
      Content.Append
        ((Kind     => LLM.Types.Thinking_Block,
          Thinking => To_Unbounded_String ("trace this")));
      Content.Append
        ((Kind => LLM.Types.Text_Block,
          Text => To_Unbounded_String ("Final answer")));

      return
        (Role      => LLM.Types.Assistant,
         Content   => Content,
         Tok_Usage =>
           (Input => 6, Output => 4, Cache_Read => 1, Cache_Write => 0),
         Stop      => LLM.Types.Stop,
         Timestamp => Null_Unbounded_String);
   end Make_Assistant_Thinking_Text;

   function Make_Tool_Result return LLM.Types.Message is
      Content : LLM.Types.Content_Block_Vectors.Vector;
   begin
      Content.Append
        ((Kind        => LLM.Types.Tool_Result_Block,
          Result_Id   => To_Unbounded_String ("call-1"),
          Result_Text => To_Unbounded_String ("file contents"),
          Is_Error    => False));

      return
        (Role      => LLM.Types.Tool_Result,
         Content   => Content,
         Tok_Usage => (others => 0),
         Stop      => LLM.Types.Unknown_Stop,
         Timestamp => Null_Unbounded_String);
   end Make_Tool_Result;

   procedure Test_New_UUID_Format (T : in out Test) is
      pragma Unreferenced (T);

      UUID : constant String := LLM.Session_Store.New_UUID;
   begin
      Assert (UUID'Length = 36, "UUID should be 36 chars long");
      Assert
        (UUID (UUID'First + 8) = '-',
         "UUID hyphen at position 9");
      Assert
        (UUID (UUID'First + 13) = '-',
         "UUID hyphen at position 14");
      Assert
        (UUID (UUID'First + 18) = '-',
         "UUID hyphen at position 19");
      Assert
        (UUID (UUID'First + 23) = '-',
         "UUID hyphen at position 24");
      Assert
        (UUID (UUID'First + 14) = '4',
         "UUID version nibble should be 4");
      Assert
        (UUID (UUID'First + 19) in '8' | '9' | 'a' | 'b',
         "UUID variant nibble should be RFC 4122 variant 1");

      for I in UUID'Range loop
         if I not in UUID'First + 8
           | UUID'First + 13
           | UUID'First + 18
           | UUID'First + 23
         then
            Assert
              (UUID (I) in '0' .. '9' | 'a' .. 'f',
               "UUID should contain only lowercase hex digits");
         end if;
      end loop;
   end Test_New_UUID_Format;

   procedure Test_New_UUID_Unique (T : in out Test) is
      pragma Unreferenced (T);

      Left  : constant String := LLM.Session_Store.New_UUID;
      Right : constant String := LLM.Session_Store.New_UUID;
   begin
      Assert (Left /= Right, "Two UUIDv4 values should differ");
   end Test_New_UUID_Unique;

   procedure Test_Create_Session_Header (T : in out Test) is
      pragma Unreferenced (T);

      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Prepare_Test_Home;
      declare
         Session_Id : constant String :=
           LLM.Session_Store.Create_Session (Source_Cwd);
         Path       : constant String :=
           LLM.Session_Store.Session_File_Path (Session_Id);
         Header     : constant String := Read_First_Line (Path);
         Parsed     : constant GNATCOLL.JSON.Read_Result :=
           GNATCOLL.JSON.Read (Header);
         Info       : constant Session_Lister.Session_Info :=
           Session_Lister.Parse_Session_File (Path);
      begin
         Assert (Ada.Directories.Exists (Path), "Session file should exist");
         Assert (Parsed.Success, "Header line should be valid JSON");
         Assert
           (To_String (Info.UUID) = Session_Id,
            "Parse_Session_File should recover the new UUID");
         Assert
           (Get_Integer_Field (Parsed.Value, "version") = 1,
            "Header version should be 1");
         Assert
           (Get_String_Field (Parsed.Value, "id") = Session_Id,
            "Header id should match the returned UUID");
         Assert
           (Get_Integer_Field (Parsed.Value, "createdAt") > 0,
            "Header createdAt should be a Unix-millisecond integer");
         Assert
           (Get_String_Field (Parsed.Value, "workDir") = Source_Cwd,
            "Header workDir should match the requested Cwd");
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Root;
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Root;
         raise;
   end Test_Create_Session_Header;

   procedure Test_User_Round_Trip (T : in out Test) is
      pragma Unreferenced (T);

      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Prepare_Test_Home;
      declare
         Session_Id : constant String :=
           LLM.Session_Store.Create_Session (Source_Cwd);
         Messages   : LLM.Types.Message_Vectors.Vector;
      begin
         LLM.Session_Store.Append_Message
           (Session_Id, Make_User_Message ("Hello from native store"));
         Messages := LLM.Session_Store.Load_Messages (Session_Id);

         Assert (Messages.Length = 1, "One user message should load back");
         Assert
           (Messages.Element (0).Role = LLM.Types.User,
            "Loaded role should be User");
         Assert
           (Messages.Element (0).Content.Length = 1,
            "Loaded user message should contain one block");
         Assert
           (Messages.Element (0).Content.Element (0).Kind
              = LLM.Types.Text_Block,
            "Loaded user block should be Text_Block");
         Assert
           (To_String (Messages.Element (0).Content.Element (0).Text)
              = "Hello from native store",
            "Loaded user text should round-trip");
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Root;
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Root;
         raise;
   end Test_User_Round_Trip;

   procedure Test_Assistant_Tool_Call (T : in out Test) is
      pragma Unreferenced (T);

      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Prepare_Test_Home;
      declare
         Session_Id : constant String :=
           LLM.Session_Store.Create_Session (Source_Cwd);
         Messages   : LLM.Types.Message_Vectors.Vector;
      begin
         LLM.Session_Store.Append_Message
           (Session_Id, Make_Assistant_Tool_Call);
         Messages := LLM.Session_Store.Load_Messages (Session_Id);

         Assert (Messages.Length = 1, "One assistant message should load");
         Assert
           (Messages.Element (0).Role = LLM.Types.Assistant,
            "Loaded role should be Assistant");
         Assert
           (Messages.Element (0).Content.Length = 1,
            "Assistant tool-call message should have one block");
         Assert
           (Messages.Element (0).Content.Element (0).Kind
              = LLM.Types.Tool_Call_Block,
            "Assistant block should be Tool_Call_Block");
         Assert
           (To_String (Messages.Element (0).Content.Element (0).Tool_Call_Id)
              = "call-1",
            "Tool call id should round-trip");
         Assert
           (To_String (Messages.Element (0).Content.Element (0).Tool_Name)
              = "read",
            "Tool call name should round-trip");
         Assert
           (Contains
              (To_String
                 (Messages.Element (0).Content.Element (0).Arguments_Json),
               "demo.adb"),
            "Tool call arguments should round-trip as JSON text");
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Root;
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Root;
         raise;
   end Test_Assistant_Tool_Call;

   procedure Test_Assistant_Thinking_Text_Round_Trip (T : in out Test) is
      pragma Unreferenced (T);

      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Prepare_Test_Home;
      declare
         Session_Id : constant String :=
           LLM.Session_Store.Create_Session (Source_Cwd);
         Messages   : LLM.Types.Message_Vectors.Vector;
      begin
         LLM.Session_Store.Append_Message
           (Session_Id, Make_Assistant_Thinking_Text);
         Messages := LLM.Session_Store.Load_Messages (Session_Id);

         Assert (Messages.Length = 1, "One assistant message should load");
         Assert
           (Messages.Element (0).Role = LLM.Types.Assistant,
            "Loaded role should be Assistant");
         Assert
           (Messages.Element (0).Content.Length = 2,
            "Assistant message should preserve both content blocks");
         Assert
           (Messages.Element (0).Content.Element (0).Kind
              = LLM.Types.Thinking_Block,
            "First block should round-trip as Thinking_Block");
         Assert
           (To_String (Messages.Element (0).Content.Element (0).Thinking)
              = "trace this",
            "Thinking block text should round-trip");
         Assert
           (Messages.Element (0).Content.Element (1).Kind
              = LLM.Types.Text_Block,
            "Second block should round-trip as Text_Block");
         Assert
           (To_String (Messages.Element (0).Content.Element (1).Text)
              = "Final answer",
            "Text block should round-trip after the thinking block");
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Root;
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Root;
         raise;
   end Test_Assistant_Thinking_Text_Round_Trip;

   procedure Test_Tool_Result_Round_Trip (T : in out Test) is
      pragma Unreferenced (T);

      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Prepare_Test_Home;
      declare
         Session_Id : constant String :=
           LLM.Session_Store.Create_Session (Source_Cwd);
         Messages   : LLM.Types.Message_Vectors.Vector;
      begin
         LLM.Session_Store.Append_Message (Session_Id, Make_Tool_Result);
         Messages := LLM.Session_Store.Load_Messages (Session_Id);

         Assert (Messages.Length = 1, "One tool result message should load");
         Assert
           (Messages.Element (0).Role = LLM.Types.Tool_Result,
            "Loaded role should be Tool_Result");
         Assert
           (Messages.Element (0).Content.Length = 1,
            "Tool result message should have one block");
         Assert
           (Messages.Element (0).Content.Element (0).Kind
              = LLM.Types.Tool_Result_Block,
            "Loaded block should be Tool_Result_Block");
         Assert
           (To_String (Messages.Element (0).Content.Element (0).Result_Id)
              = "call-1",
            "Tool result id should round-trip");
         Assert
           (To_String (Messages.Element (0).Content.Element (0).Result_Text)
              = "file contents",
            "Tool result text should round-trip");
         Assert
           (not Messages.Element (0).Content.Element (0).Is_Error,
            "Tool result error flag should round-trip");
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Root;
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Root;
         raise;
   end Test_Tool_Result_Round_Trip;

   procedure Test_Fork_Session_Native_Source (T : in out Test) is
      pragma Unreferenced (T);

      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Prepare_Test_Home;
      declare
         Source_Id : constant String :=
           LLM.Session_Store.Create_Session (Source_Cwd);
      begin
         LLM.Session_Store.Append_Message
           (Source_Id, Make_User_Message ("Hello"));
         LLM.Session_Store.Append_Message
           (Source_Id, Make_Assistant_Text ("World"));
         LLM.Session_Store.Append_Message
           (Source_Id, Make_User_Message ("Foo"));
         LLM.Session_Store.Append_Message
           (Source_Id, Make_Assistant_Text ("Bar"));

         declare
            Fork_Id : constant String :=
              Session_Lister.Fork_Session (Source_Id, 1, Target_Cwd);
            Path : constant String :=
              LLM.Session_Store.Session_File_Path (Fork_Id);
            Content : constant String := Read_File (Path);
            Messages : constant LLM.Types.Message_Vectors.Vector :=
              LLM.Session_Store.Load_Messages (Fork_Id);
         begin
            Assert (Fork_Id'Length > 0, "Fork_Session should succeed");
            Assert
              (Contains (Content, """role"":""session_info"""),
               "Native fork output should include a role=session_info line");
            Assert
              (Messages.Length = 2,
               "Fork after one complete turn should keep exactly"
               & " two messages");
            Assert
              (To_String (Messages.Element (0).Content.Element (0).Text)
                 = "Hello",
               "Fork should retain the first user message");
            Assert
              (To_String (Messages.Element (1).Content.Element (0).Text)
                 = "World",
               "Fork should retain the first assistant message");
         end;
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Root;
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Root;
         raise;
   end Test_Fork_Session_Native_Source;

end LLM_Session_Store_Tests;
