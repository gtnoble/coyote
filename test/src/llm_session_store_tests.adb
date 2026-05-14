with AUnit.Assertions;
with Ada.Containers;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNATCOLL.JSON;
with LLM.Session_Store;
with LLM.Types;
with Session_Fixture;
with Session_Lister;

package body LLM_Session_Store_Tests is

   use AUnit.Assertions;
   use type Ada.Containers.Count_Type;
   use type GNATCOLL.JSON.JSON_Value_Type;
   use type LLM.Types.Content_Block_Kind;
   use type LLM.Types.Role;
   use type LLM.Types.Stop_Reason;

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
      Ada.Directories.Create_Path (Test_Root & "/.coyote");
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

   function Get_Array_Field
     (Value : GNATCOLL.JSON.JSON_Value;
      Field : String) return GNATCOLL.JSON.JSON_Array
   is
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind = GNATCOLL.JSON.JSON_Array_Type
      then
         return Value.Get (Field).Get;
      end if;

      return GNATCOLL.JSON.Empty_Array;
   end Get_Array_Field;

   function Get_Array_Element_String
     (Value : GNATCOLL.JSON.JSON_Array;
      Index : Positive) return String
   is
      Element : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Get (Value, Index);
   begin
      if Element.Kind = GNATCOLL.JSON.JSON_String_Type then
         return Element.Get;
      end if;

      return "";
   end Get_Array_Element_String;

   function Get_Object_Field
     (Value : GNATCOLL.JSON.JSON_Value;
      Field : String) return GNATCOLL.JSON.JSON_Value
   is
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind = GNATCOLL.JSON.JSON_Object_Type
      then
         return Value.Get (Field);
      end if;

      return GNATCOLL.JSON.JSON_Null;
   end Get_Object_Field;

   procedure Append_Raw_Line
     (Path : String;
      Line : String)
   is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.Append_File, Path);
      Ada.Text_IO.Put_Line (File, Line);
      Ada.Text_IO.Close (File);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         raise;
   end Append_Raw_Line;

   function Text_Block_JSON (Text : String) return GNATCOLL.JSON.JSON_Value is
      Block : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
   begin
      Block.Set_Field ("type", "text");
      Block.Set_Field ("text", Text);
      return Block;
   end Text_Block_JSON;

   function User_Message_JSON (Text : String) return String is
      Msg     : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Content : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
   begin
      GNATCOLL.JSON.Append (Content, Text_Block_JSON (Text));
      Msg.Set_Field ("role", "user");
      Msg.Set_Field ("content", Content);
      Msg.Set_Field ("timestamp", Integer (1));
      return GNATCOLL.JSON.Write (Msg);
   end User_Message_JSON;

   function Compaction_Record_JSON
     (Summary          : String;
      First_Kept_Index : Natural;
      Tokens_Before    : Natural) return String
   is
      Record_Value : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Details      : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
   begin
      Details.Set_Field ("readFiles", GNATCOLL.JSON.Empty_Array);
      Details.Set_Field ("modifiedFiles", GNATCOLL.JSON.Empty_Array);

      Record_Value.Set_Field ("type", "compaction");
      Record_Value.Set_Field ("summary", Summary);
      Record_Value.Set_Field
        ("firstKeptMessageIndex", Integer (First_Kept_Index));
      Record_Value.Set_Field ("tokensBefore", Integer (Tokens_Before));
      Record_Value.Set_Field ("details", Details);

      return GNATCOLL.JSON.Write (Record_Value);
   end Compaction_Record_JSON;

   function Find_Compaction_Record
     (Path : String) return GNATCOLL.JSON.JSON_Value
   is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);

      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line   : constant String := Ada.Text_IO.Get_Line (File);
            Parsed : constant GNATCOLL.JSON.Read_Result :=
              GNATCOLL.JSON.Read (Line);
         begin
            if Parsed.Success
              and then Get_String_Field (Parsed.Value, "type") = "compaction"
            then
               Ada.Text_IO.Close (File);
               return Parsed.Value;
            end if;
         end;
      end loop;

      Ada.Text_IO.Close (File);
      return GNATCOLL.JSON.JSON_Null;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         raise;
   end Find_Compaction_Record;

   function Message_Text (Msg : LLM.Types.Message) return String is
   begin
      for Block of Msg.Content loop
         if Block.Kind = LLM.Types.Text_Block then
            return To_String (Block.Text);
         end if;
      end loop;

      return "";
   end Message_Text;

   function Make_Compaction_Summary_Message
     (Text : String) return LLM.Types.Message
   is
      Content : LLM.Types.Content_Block_Vectors.Vector;
   begin
      Content.Append
        ((Kind => LLM.Types.Text_Block,
          Text => To_Unbounded_String (Text)));

      return
        (Role      => LLM.Types.Compaction_Summary,
         Content   => Content,
         Tok_Usage => (others => 0),
         Stop      => LLM.Types.Unknown_Stop,
         Timestamp => Null_Unbounded_String);
   end Make_Compaction_Summary_Message;

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

   function Make_Assistant_With_Usage
     (Text : String;
      Stop : LLM.Types.Stop_Reason;
      Usage : LLM.Types.Usage) return LLM.Types.Message
   is
      Content : LLM.Types.Content_Block_Vectors.Vector;
   begin
      Content.Append
        ((Kind => LLM.Types.Text_Block,
          Text => To_Unbounded_String (Text)));

      return
        (Role      => LLM.Types.Assistant,
         Content   => Content,
         Tok_Usage => Usage,
         Stop      => Stop,
         Timestamp => Null_Unbounded_String);
   end Make_Assistant_With_Usage;

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
        ((Kind      => LLM.Types.Thinking_Block,
          Thinking  => To_Unbounded_String ("trace this"),
          Signature => Ada.Strings.Unbounded.To_Unbounded_String ("sig-abc")));
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
           (To_String (Messages.Element (0).Content.Element (0).Signature)
              = "sig-abc",
            "Thinking block signature should round-trip");
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

   procedure Test_Load_Legacy_Pi_Envelope_Lines (T : in out Test) is
      pragma Unreferenced (T);

      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Cwd_Slug     : constant String := "--legacy-envelope-test--";
   begin
      Prepare_Test_Home;
      declare
         Session_Id : constant String :=
           Session_Fixture.Create_Native_Session
             (Home     => Test_Root,
              Cwd_Slug => Cwd_Slug,
              Name     => "legacy-envelope");
         Messages   : LLM.Types.Message_Vectors.Vector;
      begin
         Session_Fixture.Append_Legacy_User_Message
           (Home     => Test_Root,
            Cwd_Slug => Cwd_Slug,
            UUID     => Session_Id,
            Text     => "Legacy one");
         Session_Fixture.Append_Legacy_User_Message
           (Home     => Test_Root,
            Cwd_Slug => Cwd_Slug,
            UUID     => Session_Id,
            Text     => "Legacy two");
         Session_Fixture.Append_User_Message
           (Home     => Test_Root,
            Cwd_Slug => Cwd_Slug,
            UUID     => Session_Id,
            Text     => "Native three");

         Messages := LLM.Session_Store.Load_Messages (Session_Id);

         Assert (Messages.Length = 3, "Three user messages should load");
         Assert
           (Messages.Element (0).Role = LLM.Types.User,
            "First loaded role should be User");
         Assert
           (Messages.Element (1).Role = LLM.Types.User,
            "Second loaded role should be User");
         Assert
           (Messages.Element (2).Role = LLM.Types.User,
            "Third loaded role should be User");
         Assert
           (To_String (Messages.Element (0).Content.Element (0).Text)
              = "Legacy one",
            "First legacy envelope text should load");
         Assert
           (To_String (Messages.Element (1).Content.Element (0).Text)
              = "Legacy two",
            "Second legacy envelope text should load");
         Assert
           (To_String (Messages.Element (2).Content.Element (0).Text)
              = "Native three",
            "Native user line should load after legacy lines");
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Root;
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Root;
         raise;
   end Test_Load_Legacy_Pi_Envelope_Lines;

   procedure Test_Load_Skips_Malformed_Lines (T : in out Test) is
      pragma Unreferenced (T);

      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Cwd_Slug     : constant String := "--malformed-lines-test--";
   begin
      Prepare_Test_Home;
      declare
         Session_Id : constant String :=
           Session_Fixture.Create_Native_Session
             (Home     => Test_Root,
              Cwd_Slug => Cwd_Slug,
              Name     => "malformed-lines");
         Path       : constant String :=
           Session_Fixture.Session_File_Path (Test_Root, Cwd_Slug, Session_Id);
         Messages   : LLM.Types.Message_Vectors.Vector;
         File       : Ada.Text_IO.File_Type;
      begin
         Session_Fixture.Append_User_Message
           (Home     => Test_Root,
            Cwd_Slug => Cwd_Slug,
            UUID     => Session_Id,
            Text     => "Before bad json");

         Ada.Text_IO.Open (File, Ada.Text_IO.Append_File, Path);
         Ada.Text_IO.Put_Line (File, "not json");
         Ada.Text_IO.Close (File);

         Session_Fixture.Append_User_Message
           (Home     => Test_Root,
            Cwd_Slug => Cwd_Slug,
            UUID     => Session_Id,
            Text     => "After bad json");

         Messages := LLM.Session_Store.Load_Messages (Session_Id);

         Assert
           (Messages.Length = 2,
            "Malformed JSON lines should be skipped by Load_Messages");
         Assert
           (To_String (Messages.Element (0).Content.Element (0).Text)
              = "Before bad json",
            "First valid message should survive malformed input");
         Assert
           (To_String (Messages.Element (1).Content.Element (0).Text)
              = "After bad json",
            "Second valid message should survive malformed input");
      exception
         when others =>
            if Ada.Text_IO.Is_Open (File) then
               Ada.Text_IO.Close (File);
            end if;
            raise;
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Root;
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Root;
         raise;
   end Test_Load_Skips_Malformed_Lines;

   procedure Test_Assistant_Usage_And_Stop_Reason_Persist
     (T : in out Test)
   is
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
           (Session_Id,
            Make_Assistant_With_Usage
              (Text  => "Usage persists",
               Stop  => LLM.Types.Stop,
               Usage =>
                 (Input       => 31,
                  Output      => 17,
                  Cache_Read  => 5,
                  Cache_Write => 2)));

         Messages := LLM.Session_Store.Load_Messages (Session_Id);

         Assert (Messages.Length = 1, "One assistant message should load");
         Assert
           (Messages.Element (0).Role = LLM.Types.Assistant,
            "Loaded role should be Assistant");
         Assert
           (Messages.Element (0).Stop = LLM.Types.Stop,
            "Stop reason should persist as stop");
         Assert
           (Messages.Element (0).Tok_Usage.Output > 0,
            "Assistant output-token usage should persist");
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Root;
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Root;
         raise;
   end Test_Assistant_Usage_And_Stop_Reason_Persist;

   procedure Test_Append_Compaction_Writes_Entry (T : in out Test) is
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
      begin
         LLM.Session_Store.Append_Message
           (Session_Id, Make_User_Message ("Before one"));
         LLM.Session_Store.Append_Message
           (Session_Id, Make_User_Message ("Before two"));
         LLM.Session_Store.Append_Compaction
           (Session_Id       => Session_Id,
            Summary          => "## Goal" & ASCII.LF & "- Keep working",
            First_Kept_Index => 1,
            Tokens_Before    => 123,
            Read_Files       => "src/one.adb" & ASCII.LF & "src/two.ads",
            Modified_Files   => "src/three.adb");

         declare
            Record_Value : constant GNATCOLL.JSON.JSON_Value :=
              Find_Compaction_Record (Path);
            Details      : constant GNATCOLL.JSON.JSON_Value :=
              Get_Object_Field (Record_Value, "details");
            Read_Files   : constant GNATCOLL.JSON.JSON_Array :=
              Get_Array_Field (Details, "readFiles");
            Modified     : constant GNATCOLL.JSON.JSON_Array :=
              Get_Array_Field (Details, "modifiedFiles");
         begin
            Assert
              (Record_Value.Kind = GNATCOLL.JSON.JSON_Object_Type,
               "A compaction record should be written to the JSONL file");
            Assert
              (Get_String_Field (Record_Value, "type") = "compaction",
               "The appended record should have type=compaction");
            Assert
              (Get_Integer_Field (Record_Value, "firstKeptMessageIndex") = 1,
               "firstKeptMessageIndex should be persisted");
            Assert
              (Get_Integer_Field (Record_Value, "tokensBefore") = 123,
               "tokensBefore should be persisted");
            Assert
              (GNATCOLL.JSON.Length (Read_Files) = 2,
               "Read_Files should split into two JSON array elements");
            Assert
              (Get_Array_Element_String (Read_Files, 1) = "src/one.adb",
               "First readFiles element should match the first path");
            Assert
              (Get_Array_Element_String (Read_Files, 2) = "src/two.ads",
               "Second readFiles element should match the second path");
            Assert
              (GNATCOLL.JSON.Length (Modified) = 1,
               "Modified_Files should split into one JSON array element");
            Assert
              (Get_Array_Element_String (Modified, 1) = "src/three.adb",
               "modifiedFiles should contain the written path");
         end;
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Root;
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Root;
         raise;
   end Test_Append_Compaction_Writes_Entry;

   procedure Test_Compaction_Summary_Not_Persisted
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Prepare_Test_Home;
      declare
         Session_Id     : constant String :=
           LLM.Session_Store.Create_Session (Source_Cwd);
         Raised         : Boolean := False;
         Error_Message  : Unbounded_String;
      begin
         begin
            LLM.Session_Store.Append_Message
              (Session_Id,
               Make_Compaction_Summary_Message ("already summarized"));
         exception
            when Error : LLM.Session_Store.Session_Error =>
               Raised := True;
               Error_Message := To_Unbounded_String
                 (Ada.Exceptions.Exception_Message (Error));
         end;

         Assert
           (Raised,
            "Compaction_Summary messages should not be persisted directly");
         Assert
           (Contains
              (To_String (Error_Message),
               "must not be persisted directly"),
            "The raised Session_Error should explain the guard");
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Root;
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Root;
         raise;
   end Test_Compaction_Summary_Not_Persisted;

   procedure Test_Load_With_Compaction_Entry (T : in out Test) is
      pragma Unreferenced (T);

      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Cwd_Slug     : constant String := "--compaction-load-test--";
   begin
      Prepare_Test_Home;
      declare
         Session_Id : constant String :=
           Session_Fixture.Create_Native_Session
             (Home     => Test_Root,
              Cwd_Slug => Cwd_Slug,
              Name     => "");
         Path       : constant String :=
           Session_Fixture.Session_File_Path (Test_Root, Cwd_Slug, Session_Id);
         Messages   : LLM.Types.Message_Vectors.Vector;
      begin
         Append_Raw_Line (Path, User_Message_JSON ("First before"));
         Append_Raw_Line (Path, User_Message_JSON ("Second before"));
         Append_Raw_Line
           (Path,
            Compaction_Record_JSON
              (Summary          => "## Goal" & ASCII.LF & "Keep context",
               First_Kept_Index => 1,
               Tokens_Before    => 88));
         Append_Raw_Line (Path, User_Message_JSON ("After compaction"));

         Messages := LLM.Session_Store.Load_Messages (Session_Id);

         Assert
           (Messages.Length = 3,
            "Compaction load should return summary plus kept messages");
         Assert
           (Messages.Element (0).Role = LLM.Types.Compaction_Summary,
            "The first loaded message should be a synthetic summary");
         Assert
           (Contains (Message_Text (Messages.Element (0)), "Keep context"),
            "The summary text should be loaded into the synthetic message");
         Assert
           (Message_Text (Messages.Element (1)) = "Second before",
            "The second pre-compaction message should be retained");
         Assert
           (Message_Text (Messages.Element (2)) = "After compaction",
            "Messages after compaction should remain in order");
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Root;
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Root;
         raise;
   end Test_Load_With_Compaction_Entry;

   procedure Test_Load_Without_Compaction_Unchanged
     (T : in out Test)
   is
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
           (Session_Id, Make_User_Message ("Alpha"));
         LLM.Session_Store.Append_Message
           (Session_Id, Make_Assistant_Text ("Beta"));
         LLM.Session_Store.Append_Message
           (Session_Id, Make_User_Message ("Gamma"));

         Messages := LLM.Session_Store.Load_Messages (Session_Id);

         Assert
           (Messages.Length = 3,
            "Sessions without compaction should load every message");
         Assert
           (Messages.Element (0).Role = LLM.Types.User,
            "First role should remain User");
         Assert
           (Messages.Element (1).Role = LLM.Types.Assistant,
            "Second role should remain Assistant");
         Assert
           (Messages.Element (2).Role = LLM.Types.User,
            "Third role should remain User");
         Assert
           (Message_Text (Messages.Element (0)) = "Alpha",
            "First message text should remain unchanged");
         Assert
           (Message_Text (Messages.Element (1)) = "Beta",
            "Second message text should remain unchanged");
         Assert
           (Message_Text (Messages.Element (2)) = "Gamma",
            "Third message text should remain unchanged");
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Root;
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Root;
         raise;
   end Test_Load_Without_Compaction_Unchanged;

   procedure Test_Append_Then_Load_Round_Trip (T : in out Test) is
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
           (Session_Id, Make_User_Message ("Zero"));
         LLM.Session_Store.Append_Message
           (Session_Id, Make_User_Message ("One"));
         LLM.Session_Store.Append_Message
           (Session_Id, Make_User_Message ("Two"));
         LLM.Session_Store.Append_Message
           (Session_Id, Make_User_Message ("Three"));
         LLM.Session_Store.Append_Compaction
           (Session_Id       => Session_Id,
            Summary          => "## Progress" & ASCII.LF & "- checkpoint",
            First_Kept_Index => 2,
            Tokens_Before    => 200,
            Read_Files       => "",
            Modified_Files   => "");
         LLM.Session_Store.Append_Message
           (Session_Id, Make_User_Message ("Four"));

         Messages := LLM.Session_Store.Load_Messages (Session_Id);

         Assert
           (Messages.Length = 4,
            "Round-trip load should return summary, kept messages, and post"
            & "-compaction messages");
         Assert
           (Messages.Element (0).Role = LLM.Types.Compaction_Summary,
            "Round-trip load should synthesize a compaction summary message");
         Assert
           (Contains (Message_Text (Messages.Element (0)), "checkpoint"),
            "The synthetic summary should contain the stored summary text");
         Assert
           (Message_Text (Messages.Element (1)) = "Two",
            "First kept message should be the third original message");
         Assert
           (Message_Text (Messages.Element (2)) = "Three",
            "Second kept message should be the fourth original message");
         Assert
           (Message_Text (Messages.Element (3)) = "Four",
            "Post-compaction messages should load after kept messages");
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Root;
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Root;
         raise;
   end Test_Append_Then_Load_Round_Trip;

   procedure Test_Session_Work_Dir (T : in out Test) is
      pragma Unreferenced (T);

      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Prepare_Test_Home;

      --  Case 1: happy path — Session_Work_Dir returns the Cwd written by
      --  Create_Session.
      declare
         Session_Id : constant String :=
           LLM.Session_Store.Create_Session (Source_Cwd);
      begin
         Assert
           (LLM.Session_Store.Session_Work_Dir (Session_Id) = Source_Cwd,
            "Session_Work_Dir should return the Cwd passed to Create_Session");
      end;

      --  Case 2: unknown UUID — Session_Work_Dir returns "".
      Assert
        (LLM.Session_Store.Session_Work_Dir ("no-such-uuid") = "",
         "Session_Work_Dir should return empty string for an unknown UUID");

      --  Case 3: header present but missing workDir field — returns "".
      declare
         Session_Id : constant String :=
           LLM.Session_Store.Create_Session (Source_Cwd);
         Path       : constant String :=
           LLM.Session_Store.Session_File_Path (Session_Id);
         File       : Ada.Text_IO.File_Type;
      begin
         --  Overwrite the session file with a header that has no workDir.
         Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
         Ada.Text_IO.Put_Line
           (File,
            "{""version"":1,""id"":""" & Session_Id & ""","
            & """createdAt"":1000000}");
         Ada.Text_IO.Close (File);

         Assert
           (LLM.Session_Store.Session_Work_Dir (Session_Id) = "",
            "Session_Work_Dir should return empty string when header has no "
            & "workDir field");
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Root;
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Root;
         raise;
   end Test_Session_Work_Dir;

   procedure Test_Large_Tool_Result_Round_Trip (T : in out Test) is
      --  Regression test for a secondary-stack overflow in Write_Raw_Line.
      --  Before the fix, Append_Message raised Storage_Error (SIGSEGV) when
      --  the tool-result text was large enough that the temporary produced by
      --  "Line & ASCII.LF" overflowed the secondary stack alongside the
      --  String result of Message_To_Json.  512 KB is comfortably above any
      --  typical secondary-stack limit and well within heap limits.
      pragma Unreferenced (T);

      Large_Size   : constant := 512 * 1_024;  --  512 KB
      Large_Text   : constant String (1 .. Large_Size) := (others => 'x');
      Content      : LLM.Types.Content_Block_Vectors.Vector;
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Prepare_Test_Home;

      Content.Append
        ((Kind        => LLM.Types.Tool_Result_Block,
          Result_Id   => To_Unbounded_String ("call-large"),
          Result_Text => To_Unbounded_String (Large_Text),
          Is_Error    => False));

      declare
         Msg : constant LLM.Types.Message :=
           (Role      => LLM.Types.Tool_Result,
            Content   => Content,
            Tok_Usage => (others => 0),
            Stop      => LLM.Types.Unknown_Stop,
            Timestamp => Null_Unbounded_String);

         Session_Id : constant String :=
           LLM.Session_Store.Create_Session (Source_Cwd);
         Messages   : LLM.Types.Message_Vectors.Vector;
      begin
         --  This must not raise Storage_Error or any other exception.
         LLM.Session_Store.Append_Message (Session_Id, Msg);

         Messages := LLM.Session_Store.Load_Messages (Session_Id);

         Assert
           (Messages.Length = 1,
            "Large tool result: one message should round-trip");
         Assert
           (Messages.Element (0).Role = LLM.Types.Tool_Result,
            "Large tool result: role should round-trip");
         Assert
           (To_String
              (Messages.Element (0).Content.Element (0).Result_Text)
              = Large_Text,
            "Large tool result: full text should round-trip without "
            & "truncation or corruption");
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Root;
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Root;
         raise;
   end Test_Large_Tool_Result_Round_Trip;

end LLM_Session_Store_Tests;
