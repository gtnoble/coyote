--  Session_Fixture body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Calendar;
with Ada.Directories;
with Ada.Streams.Stream_IO;
with GNATCOLL.JSON;
with LLM.Session_Store;

package body Session_Fixture is

   use type GNATCOLL.JSON.JSON_Value_Type;

   function Current_Unix_Milliseconds return Long_Long_Integer is
      use Ada.Calendar;

      Epoch : constant Time :=
        Time_Of (Year => 1970, Month => 1, Day => 1, Seconds => 0.0);
   begin
      return Long_Long_Integer ((Clock - Epoch) * 1000.0);
   end Current_Unix_Milliseconds;

   function Sessions_Dir
     (Home     : String;
      Cwd_Slug : String) return String
   is
   begin
      return Home & "/.coyote/sessions/" & Cwd_Slug;
   end Sessions_Dir;

   function Session_File_Path
     (Home     : String;
      Cwd_Slug : String;
      UUID     : String) return String
   is
   begin
      return Sessions_Dir (Home, Cwd_Slug) & "/" & UUID & ".jsonl";
   end Session_File_Path;

   procedure Write_Raw_Line
     (Path  : String;
      Line  : String;
      Mode  : Ada.Streams.Stream_IO.File_Mode;
      Fresh : Boolean := False)
   is
      File   : Ada.Streams.Stream_IO.File_Type;
      Stream : Ada.Streams.Stream_IO.Stream_Access;
   begin
      if Fresh then
         Ada.Streams.Stream_IO.Create (File, Mode, Path);
      else
         Ada.Streams.Stream_IO.Open (File, Mode, Path);
      end if;

      Stream := Ada.Streams.Stream_IO.Stream (File);
      String'Write (Stream, Line & ASCII.LF);
      Ada.Streams.Stream_IO.Close (File);
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;

         raise;
   end Write_Raw_Line;

   procedure Append_Line
     (Home     : String;
      Cwd_Slug : String;
      UUID     : String;
      Line     : String)
   is
   begin
      Write_Raw_Line
        (Path => Session_File_Path (Home, Cwd_Slug, UUID),
         Line => Line,
         Mode => Ada.Streams.Stream_IO.Append_File);
   end Append_Line;

   function Parse_Object_JSON
     (Text : String) return GNATCOLL.JSON.JSON_Value
   is
      Parsed : constant GNATCOLL.JSON.Read_Result :=
        GNATCOLL.JSON.Read (Text);
   begin
      if not Parsed.Success then
         raise Constraint_Error with "invalid JSON object";
      end if;

      if Parsed.Value.Kind /= GNATCOLL.JSON.JSON_Object_Type then
         raise Constraint_Error with "expected JSON object";
      end if;

      return Parsed.Value;
   end Parse_Object_JSON;

   function Text_Block (Text : String) return GNATCOLL.JSON.JSON_Value is
      Block : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
   begin
      Block.Set_Field ("type", "text");
      Block.Set_Field ("text", Text);
      return Block;
   end Text_Block;

   function Zero_Usage return GNATCOLL.JSON.JSON_Value is
      Usage : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
   begin
      Usage.Set_Field ("input", Integer (0));
      Usage.Set_Field ("output", Integer (0));
      Usage.Set_Field ("cacheRead", Integer (0));
      Usage.Set_Field ("cacheWrite", Integer (0));
      return Usage;
   end Zero_Usage;

   function Assistant_Message_JSON
     (Content     : GNATCOLL.JSON.JSON_Array;
      Stop_Reason : String) return String
   is
      Msg : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
   begin
      Msg.Set_Field ("role", "assistant");
      Msg.Set_Field ("content", Content);
      Msg.Set_Field ("model", "");
      Msg.Set_Field ("provider", "");
      Msg.Set_Field ("stopReason", Stop_Reason);
      Msg.Set_Field ("usage", Zero_Usage);
      Msg.Set_Field
        ("timestamp", Long_Integer (Current_Unix_Milliseconds));
      return GNATCOLL.JSON.Write (Msg);
   end Assistant_Message_JSON;

   function Create_Native_Session
     (Home     : String;
      Cwd_Slug : String;
      Name     : String) return String
   is
      UUID       : constant String := LLM.Session_Store.New_UUID;
      Path       : constant String :=
        Session_File_Path (Home, Cwd_Slug, UUID);
      Header     : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Created_At : constant Long_Integer :=
        Long_Integer (Current_Unix_Milliseconds);
   begin
      Ada.Directories.Create_Path (Sessions_Dir (Home, Cwd_Slug));

      Header.Set_Field ("version", Integer (1));
      Header.Set_Field ("id", UUID);
      Header.Set_Field ("createdAt", Created_At);
      Header.Set_Field ("workDir", Cwd_Slug);

      Write_Raw_Line
        (Path  => Path,
         Line  => GNATCOLL.JSON.Write (Header),
         Mode  => Ada.Streams.Stream_IO.Out_File,
         Fresh => True);

      if Name'Length > 0 then
         declare
            Info : constant GNATCOLL.JSON.JSON_Value :=
              GNATCOLL.JSON.Create_Object;
         begin
            Info.Set_Field ("role", "session_info");
            Info.Set_Field ("name", Name);
            Info.Set_Field ("timestamp", Created_At);
            Append_Line
              (Home, Cwd_Slug, UUID, GNATCOLL.JSON.Write (Info));
         end;
      end if;

      return UUID;
   end Create_Native_Session;

   procedure Append_User_Message
     (Home     : String;
      Cwd_Slug : String;
      UUID     : String;
      Text     : String)
   is
      Msg     : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Content : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
   begin
      GNATCOLL.JSON.Append (Content, Text_Block (Text));
      Msg.Set_Field ("role", "user");
      Msg.Set_Field ("content", Content);
      Msg.Set_Field
        ("timestamp", Long_Integer (Current_Unix_Milliseconds));
      Append_Line (Home, Cwd_Slug, UUID, GNATCOLL.JSON.Write (Msg));
   end Append_User_Message;

   procedure Append_Assistant_Text
     (Home     : String;
      Cwd_Slug : String;
      UUID     : String;
      Text     : String)
   is
      Content : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
   begin
      GNATCOLL.JSON.Append (Content, Text_Block (Text));
      Append_Line
        (Home,
         Cwd_Slug,
         UUID,
         Assistant_Message_JSON (Content, "stop"));
   end Append_Assistant_Text;

   procedure Append_Assistant_Tool_Call
     (Home      : String;
      Cwd_Slug  : String;
      UUID      : String;
      Tool_Id   : String;
      Tool_Name : String;
      Args_JSON : String)
   is
      Block     : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Content   : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
      Arguments : constant GNATCOLL.JSON.JSON_Value :=
        (if Args_JSON'Length = 0
         then GNATCOLL.JSON.Create_Object
         else Parse_Object_JSON (Args_JSON));
   begin
      Block.Set_Field ("type", "toolCall");
      Block.Set_Field ("id", Tool_Id);
      Block.Set_Field ("name", Tool_Name);
      Block.Set_Field ("arguments", Arguments);
      GNATCOLL.JSON.Append (Content, Block);

      Append_Line
        (Home,
         Cwd_Slug,
         UUID,
         Assistant_Message_JSON (Content, "toolUse"));
   end Append_Assistant_Tool_Call;

   procedure Append_Tool_Result
     (Home      : String;
      Cwd_Slug  : String;
      UUID      : String;
      Tool_Id   : String;
      Result    : String;
      Is_Error  : Boolean := False)
   is
      Msg     : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Content : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
   begin
      GNATCOLL.JSON.Append (Content, Text_Block (Result));
      Msg.Set_Field ("role", "toolResult");
      Msg.Set_Field ("toolCallId", Tool_Id);
      Msg.Set_Field ("toolName", "");
      Msg.Set_Field ("content", Content);
      Msg.Set_Field ("isError", Is_Error);
      Msg.Set_Field
        ("timestamp", Long_Integer (Current_Unix_Milliseconds));
      Append_Line (Home, Cwd_Slug, UUID, GNATCOLL.JSON.Write (Msg));
   end Append_Tool_Result;

   procedure Append_Legacy_User_Message
     (Home     : String;
      Cwd_Slug : String;
      UUID     : String;
      Text     : String)
   is
      Envelope : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Msg      : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Content  : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
   begin
      GNATCOLL.JSON.Append (Content, Text_Block (Text));
      Msg.Set_Field ("role", "user");
      Msg.Set_Field ("content", Content);
      Msg.Set_Field
        ("timestamp", Long_Integer (Current_Unix_Milliseconds));

      Envelope.Set_Field ("type", "message");
      Envelope.Set_Field ("message", Msg);
      Append_Line
        (Home, Cwd_Slug, UUID, GNATCOLL.JSON.Write (Envelope));
   end Append_Legacy_User_Message;

   procedure Append_Model_Change
     (Home     : String;
      Cwd_Slug : String;
      UUID     : String;
      Provider : String;
      Model_Id : String)
   is
      Event : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
   begin
      Event.Set_Field ("type", "model_change");
      Event.Set_Field ("provider", Provider);
      Event.Set_Field ("modelId", Model_Id);
      Append_Line
        (Home, Cwd_Slug, UUID, GNATCOLL.JSON.Write (Event));
   end Append_Model_Change;

   procedure Append_Turn_End
     (Home     : String;
      Cwd_Slug : String;
      UUID     : String)
   is
      pragma Unreferenced (Home, Cwd_Slug, UUID);
   begin
      null;
   end Append_Turn_End;

end Session_Fixture;
