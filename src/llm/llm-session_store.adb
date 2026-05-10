--  LLM.Session_Store body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Calendar;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Numerics.Discrete_Random;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNATCOLL.JSON;
with Interfaces;
with Session_Lister;

package body LLM.Session_Store is

   use type GNATCOLL.JSON.JSON_Value_Type;
   use type LLM.Types.Content_Block_Kind;

   subtype Byte is Interfaces.Unsigned_8;
   use type Byte;

   package Byte_Random is new Ada.Numerics.Discrete_Random (Byte);

   function Current_Unix_Milliseconds return Long_Long_Integer is
      use Ada.Calendar;

      Epoch : constant Time :=
        Time_Of (Year => 1970, Month => 1, Day => 1, Seconds => 0.0);
   begin
      return Long_Long_Integer ((Clock - Epoch) * 1000.0);
   end Current_Unix_Milliseconds;

   function Get_String_Field
     (Value   : GNATCOLL.JSON.JSON_Value;
      Field   : String;
      Default : String := "") return String
   is
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind = GNATCOLL.JSON.JSON_String_Type
      then
         return Value.Get (Field).Get;
      end if;

      return Default;
   end Get_String_Field;

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

   function Get_Natural_Field
     (Value   : GNATCOLL.JSON.JSON_Value;
      Field   : String;
      Default : Natural := 0) return Natural
   is
      Raw : Long_Integer;
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind = GNATCOLL.JSON.JSON_Int_Type
      then
         Raw := Value.Get (Field).Get;
         if Raw >= 0 then
            return Natural (Raw);
         end if;
      end if;

      return Default;
   end Get_Natural_Field;

   function Get_Boolean_Field
     (Value : GNATCOLL.JSON.JSON_Value;
      Field : String) return Boolean
   is
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind = GNATCOLL.JSON.JSON_Boolean_Type
      then
         return Value.Get (Field).Get;
      end if;

      return False;
   end Get_Boolean_Field;

   function Get_Integer_Image
     (Value : GNATCOLL.JSON.JSON_Value;
      Field : String) return String
   is
      Raw : Long_Integer;
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Value.Has_Field (Field)
      then
         if Value.Get (Field).Kind = GNATCOLL.JSON.JSON_Int_Type then
            Raw := Value.Get (Field).Get;
            return Ada.Strings.Fixed.Trim
              (Long_Integer'Image (Raw), Ada.Strings.Both);
         elsif Value.Get (Field).Kind = GNATCOLL.JSON.JSON_String_Type then
            return Value.Get (Field).Get;
         end if;
      end if;

      return "";
   end Get_Integer_Image;

   function Parse_Json
     (Text : String;
      What : String) return GNATCOLL.JSON.JSON_Value
   is
      Parsed : constant GNATCOLL.JSON.Read_Result :=
        GNATCOLL.JSON.Read (Text);
   begin
      if Parsed.Success then
         return Parsed.Value;
      end if;

      raise Session_Error with
        What & ": " & GNATCOLL.JSON.Format_Parsing_Error (Parsed.Error);
   end Parse_Json;

   function To_Stop_Reason (Text : String) return LLM.Types.Stop_Reason is
   begin
      if Text = "stop" then
         return LLM.Types.Stop;
      elsif Text = "length" then
         return LLM.Types.Length;
      elsif Text = "toolUse" or else Text = "tool_use" then
         return LLM.Types.Tool_Use;
      elsif Text = "aborted" then
         return LLM.Types.Aborted;
      elsif Text = "error" or else Text = "error_stop" then
         return LLM.Types.Error_Stop;
      else
         return LLM.Types.Unknown_Stop;
      end if;
   end To_Stop_Reason;

   function Stop_Reason_Image (Reason : LLM.Types.Stop_Reason) return String is
   begin
      case Reason is
         when LLM.Types.Stop =>
            return "stop";
         when LLM.Types.Length =>
            return "length";
         when LLM.Types.Tool_Use =>
            return "toolUse";
         when LLM.Types.Aborted =>
            return "aborted";
         when LLM.Types.Error_Stop =>
            return "error";
         when others =>
            return "unknown";
      end case;
   end Stop_Reason_Image;

   function Hex_Digit (Value : Natural) return Character is
      Hex_Table : constant String := "0123456789abcdef";
   begin
      return Hex_Table (Value + 1);
   end Hex_Digit;

   function Byte_Image (Value : Byte) return String is
      Uns : constant Natural := Natural (Value);
   begin
      return "" & Hex_Digit (Uns / 16) & Hex_Digit (Uns mod 16);
   end Byte_Image;

   function New_UUID return String is
      Generator : Byte_Random.Generator;
      Bytes     : array (Positive range 1 .. 16) of Byte;
   begin
      Byte_Random.Reset (Generator);

      for I in Bytes'Range loop
         Bytes (I) := Byte_Random.Random (Generator);
      end loop;

      --  RFC 4122 UUIDv4: byte 7 carries the version nibble and byte 9
      --  carries the variant bits.
      Bytes (7) := (Bytes (7) and 16#0F#) or 16#40#;
      Bytes (9) := (Bytes (9) and 16#3F#) or 16#80#;

      return Byte_Image (Bytes (1))
        & Byte_Image (Bytes (2))
        & Byte_Image (Bytes (3))
        & Byte_Image (Bytes (4))
        & "-"
        & Byte_Image (Bytes (5))
        & Byte_Image (Bytes (6))
        & "-"
        & Byte_Image (Bytes (7))
        & Byte_Image (Bytes (8))
        & "-"
        & Byte_Image (Bytes (9))
        & Byte_Image (Bytes (10))
        & "-"
        & Byte_Image (Bytes (11))
        & Byte_Image (Bytes (12))
        & Byte_Image (Bytes (13))
        & Byte_Image (Bytes (14))
        & Byte_Image (Bytes (15))
        & Byte_Image (Bytes (16));
   end New_UUID;

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

   function Read_Line
     (File : Ada.Text_IO.File_Type) return Unbounded_String
   is
      Chunk  : String (1 .. 65_536);
      Last   : Natural;
      Result : Unbounded_String;
   begin
      loop
         Ada.Text_IO.Get_Line (File, Chunk, Last);
         Append (Result, Chunk (1 .. Last));
         exit when Last < Chunk'Last;
      end loop;
      return Result;
   end Read_Line;

   function String_List_To_Array
     (Text : String) return GNATCOLL.JSON.JSON_Array
   is
      Result : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
      Start  : Natural := Text'First;
   begin
      if Text'Length = 0 then
         return Result;
      end if;

      for I in Text'Range loop
         if Text (I) = ASCII.LF then
            if Start <= I - 1 then
               GNATCOLL.JSON.Append
                 (Result, GNATCOLL.JSON.Create (Text (Start .. I - 1)));
            end if;

            Start := I + 1;
         end if;
      end loop;

      if Start <= Text'Last then
         GNATCOLL.JSON.Append
           (Result, GNATCOLL.JSON.Create (Text (Start .. Text'Last)));
      end if;

      return Result;
   end String_List_To_Array;

   function Compaction_Summary_Message
     (Summary : String) return LLM.Types.Message
   is
      Content : LLM.Types.Content_Block_Vectors.Vector;
   begin
      Content.Append
        ((Kind => LLM.Types.Text_Block,
          Text => To_Unbounded_String (Summary)));

      return
        (Role      => LLM.Types.Compaction_Summary,
         Content   => Content,
         Tok_Usage => (others => 0),
         Stop      => LLM.Types.Unknown_Stop,
         Timestamp => To_Unbounded_String (""));
   end Compaction_Summary_Message;

   procedure Append_Vector
     (Target : in out LLM.Types.Message_Vectors.Vector;
      Source : LLM.Types.Message_Vectors.Vector)
   is
   begin
      for Msg of Source loop
         Target.Append (Msg);
      end loop;
   end Append_Vector;

   procedure Append_Kept_Messages
     (Target           : in out LLM.Types.Message_Vectors.Vector;
      Source           : LLM.Types.Message_Vectors.Vector;
      First_Kept_Index : Natural)
   is
   begin
      if First_Kept_Index < Natural (Source.Length) then
         for I in First_Kept_Index .. Source.Last_Index loop
            Target.Append (Source.Element (I));
         end loop;
      end if;
   end Append_Kept_Messages;

   function Message_Object
     (Value : GNATCOLL.JSON.JSON_Value) return GNATCOLL.JSON.JSON_Value
   is
      Role : constant String := Get_String_Field (Value, "role");
   begin
      if Role = "user"
        or else Role = "assistant"
        or else Role = "toolResult"
      then
         return Value;
      end if;

      if Get_String_Field (Value, "type") = "message" then
         return Get_Object_Field (Value, "message");
      end if;

      return GNATCOLL.JSON.JSON_Null;
   end Message_Object;

   function Message_Timestamp
     (Envelope : GNATCOLL.JSON.JSON_Value;
      Msg      : GNATCOLL.JSON.JSON_Value) return Unbounded_String
   is
      Image : constant String :=
        (if Get_Integer_Image (Msg, "timestamp")'Length > 0
         then Get_Integer_Image (Msg, "timestamp")
         elsif Get_Integer_Image (Envelope, "timestamp")'Length > 0
         then Get_Integer_Image (Envelope, "timestamp")
         elsif Get_String_Field (Envelope, "timestamp")'Length > 0
         then Get_String_Field (Envelope, "timestamp")
         else "");
   begin
      return To_Unbounded_String (Image);
   end Message_Timestamp;

   function Content_To_Array
     (Msg : LLM.Types.Message) return GNATCOLL.JSON.JSON_Array
   is
      Result : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
   begin
      for Block of Msg.Content loop
         case Msg.Role is
            when LLM.Types.User | LLM.Types.Compaction_Summary =>
               if Block.Kind = LLM.Types.Text_Block then
                  declare
                     Item : constant GNATCOLL.JSON.JSON_Value :=
                       GNATCOLL.JSON.Create_Object;
                  begin
                     Item.Set_Field ("type", "text");
                     Item.Set_Field ("text", To_String (Block.Text));
                     GNATCOLL.JSON.Append (Result, Item);
                  end;
               end if;

            when LLM.Types.Assistant =>
               case Block.Kind is
                  when LLM.Types.Text_Block =>
                     declare
                        Item : constant GNATCOLL.JSON.JSON_Value :=
                          GNATCOLL.JSON.Create_Object;
                     begin
                        Item.Set_Field ("type", "text");
                        Item.Set_Field ("text", To_String (Block.Text));
                        GNATCOLL.JSON.Append (Result, Item);
                     end;
                  when LLM.Types.Thinking_Block =>
                     declare
                        Item : constant GNATCOLL.JSON.JSON_Value :=
                          GNATCOLL.JSON.Create_Object;
                     begin
                        Item.Set_Field ("type", "thinking");
                        Item.Set_Field
                          ("thinking", To_String (Block.Thinking));
                        Item.Set_Field
                          ("signature", To_String (Block.Signature));
                        GNATCOLL.JSON.Append (Result, Item);
                     end;
                  when LLM.Types.Tool_Call_Block =>
                     declare
                        Item      : constant GNATCOLL.JSON.JSON_Value :=
                          GNATCOLL.JSON.Create_Object;
                        Arguments : constant GNATCOLL.JSON.JSON_Value :=
                          (if Length (Block.Arguments_Json) = 0
                           then GNATCOLL.JSON.Create_Object
                           else Parse_Json
                             (To_String (Block.Arguments_Json),
                              "Invalid toolCall arguments JSON"));
                     begin
                        if Arguments.Kind
                          /= GNATCOLL.JSON.JSON_Object_Type
                        then
                           raise Session_Error with
                             "Invalid toolCall arguments JSON:"
                             & " expected object";
                        end if;

                        Item.Set_Field ("type", "toolCall");
                        Item.Set_Field ("id", To_String (Block.Tool_Call_Id));
                        Item.Set_Field ("name", To_String (Block.Tool_Name));
                        Item.Set_Field ("arguments", Arguments);
                        GNATCOLL.JSON.Append (Result, Item);
                     end;
                  when others =>
                     null;
               end case;

            when LLM.Types.Tool_Result =>
               null;
         end case;
      end loop;

      return Result;
   end Content_To_Array;

   function Tool_Result_Object
     (Msg : LLM.Types.Message) return GNATCOLL.JSON.JSON_Value
   is
      Result       : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Content      : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
      Tool_Call_Id : Unbounded_String;
      Tool_Name    : Unbounded_String;
      Result_Text  : Unbounded_String;
      Is_Error     : Boolean := False;
   begin
      for Block of Msg.Content loop
         case Block.Kind is
            when LLM.Types.Tool_Result_Block =>
               if Length (Tool_Call_Id) = 0 then
                  Tool_Call_Id := Block.Result_Id;
               end if;
               Is_Error := Is_Error or else Block.Is_Error;

               if Length (Result_Text) > 0 then
                  Append (Result_Text, ASCII.LF);
               end if;
               Append (Result_Text, To_String (Block.Result_Text));

            when LLM.Types.Text_Block =>
               if Length (Result_Text) > 0 then
                  Append (Result_Text, ASCII.LF);
               end if;
               Append (Result_Text, To_String (Block.Text));

            when others =>
               null;
         end case;
      end loop;

      declare
         Item : constant GNATCOLL.JSON.JSON_Value :=
           GNATCOLL.JSON.Create_Object;
         Ms   : constant Long_Integer :=
           Long_Integer (Current_Unix_Milliseconds);
      begin
         Item.Set_Field ("type", "text");
         Item.Set_Field ("text", To_String (Result_Text));
         GNATCOLL.JSON.Append (Content, Item);

         Result.Set_Field ("role", "toolResult");
         Result.Set_Field ("toolCallId", To_String (Tool_Call_Id));
         Result.Set_Field ("toolName", To_String (Tool_Name));
         Result.Set_Field ("content", Content);
         Result.Set_Field ("isError", Is_Error);
         Result.Set_Field ("timestamp", Ms);
      end;

      return Result;
   end Tool_Result_Object;

   function Message_To_Json (Msg : LLM.Types.Message) return String is
      Result : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Usage  : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Ms     : constant Long_Integer :=
        Long_Integer (Current_Unix_Milliseconds);
   begin
      case Msg.Role is
         when LLM.Types.Compaction_Summary =>
            raise Session_Error with
              "Compaction_Summary messages must not be persisted directly";

         when LLM.Types.User =>
            Result.Set_Field ("role", "user");
            Result.Set_Field ("content", Content_To_Array (Msg));
            Result.Set_Field ("timestamp", Ms);

         when LLM.Types.Assistant =>
            Usage.Set_Field ("input", Integer (Msg.Tok_Usage.Input));
            Usage.Set_Field ("output", Integer (Msg.Tok_Usage.Output));
            Usage.Set_Field
              ("cacheRead", Integer (Msg.Tok_Usage.Cache_Read));
            Usage.Set_Field
              ("cacheWrite", Integer (Msg.Tok_Usage.Cache_Write));

            Result.Set_Field ("role", "assistant");
            Result.Set_Field ("content", Content_To_Array (Msg));
            Result.Set_Field ("model", "");
            Result.Set_Field ("provider", "");
            Result.Set_Field ("stopReason", Stop_Reason_Image (Msg.Stop));
            Result.Set_Field ("usage", Usage);
            Result.Set_Field ("timestamp", Ms);

         when LLM.Types.Tool_Result =>
            return GNATCOLL.JSON.Write (Tool_Result_Object (Msg));
      end case;

      return GNATCOLL.JSON.Write (Result);
   end Message_To_Json;

   function Parse_User_Message
     (Envelope : GNATCOLL.JSON.JSON_Value;
      Msg      : GNATCOLL.JSON.JSON_Value) return LLM.Types.Message
   is
      Content : LLM.Types.Content_Block_Vectors.Vector;
      Blocks  : constant GNATCOLL.JSON.JSON_Array :=
        Get_Array_Field (Msg, "content");
   begin
      for I in 1 .. GNATCOLL.JSON.Length (Blocks) loop
         declare
            Block : constant GNATCOLL.JSON.JSON_Value :=
              GNATCOLL.JSON.Get (Blocks, I);
         begin
            if Get_String_Field (Block, "type") = "text" then
               Content.Append
                 ((Kind => LLM.Types.Text_Block,
                   Text => To_Unbounded_String
                     (Get_String_Field (Block, "text"))));
            end if;
         end;
      end loop;

      return
        (Role      => LLM.Types.User,
         Content   => Content,
         Tok_Usage => (others => 0),
         Stop      => LLM.Types.Unknown_Stop,
         Timestamp => Message_Timestamp (Envelope, Msg));
   end Parse_User_Message;

   function Parse_Assistant_Message
     (Envelope : GNATCOLL.JSON.JSON_Value;
      Msg      : GNATCOLL.JSON.JSON_Value) return LLM.Types.Message
   is
      Content : LLM.Types.Content_Block_Vectors.Vector;
      Blocks  : constant GNATCOLL.JSON.JSON_Array :=
        Get_Array_Field (Msg, "content");
      Usage   : constant GNATCOLL.JSON.JSON_Value :=
        Get_Object_Field (Msg, "usage");
   begin
      for I in 1 .. GNATCOLL.JSON.Length (Blocks) loop
         declare
            Block : constant GNATCOLL.JSON.JSON_Value :=
              GNATCOLL.JSON.Get (Blocks, I);
            Kind  : constant String := Get_String_Field (Block, "type");
         begin
            if Kind = "text" then
               Content.Append
                 ((Kind => LLM.Types.Text_Block,
                   Text => To_Unbounded_String
                     (Get_String_Field (Block, "text"))));
            elsif Kind = "thinking" then
               Content.Append
                 ((Kind      => LLM.Types.Thinking_Block,
                   Thinking  => To_Unbounded_String
                     (Get_String_Field (Block, "thinking")),
                   Signature => To_Unbounded_String
                     (Get_String_Field (Block, "signature"))));
            elsif Kind = "toolCall" then
               declare
                  Arguments : constant GNATCOLL.JSON.JSON_Value :=
                    Get_Object_Field (Block, "arguments");
                  Args_Json : constant String :=
                    (if Arguments.Kind = GNATCOLL.JSON.JSON_Object_Type
                     then GNATCOLL.JSON.Write (Arguments)
                     else "{}");
               begin
                  Content.Append
                    ((Kind           => LLM.Types.Tool_Call_Block,
                      Tool_Call_Id   => To_Unbounded_String
                        (Get_String_Field (Block, "id")),
                      Tool_Name      => To_Unbounded_String
                        (Get_String_Field (Block, "name")),
                      Arguments_Json => To_Unbounded_String (Args_Json)));
               end;
            end if;
         end;
      end loop;

      return
        (Role      => LLM.Types.Assistant,
         Content   => Content,
         Tok_Usage =>
           (Input       => Get_Natural_Field (Usage, "input"),
            Output      => Get_Natural_Field (Usage, "output"),
            Cache_Read  => Get_Natural_Field (Usage, "cacheRead"),
            Cache_Write => Get_Natural_Field (Usage, "cacheWrite")),
         Stop      => To_Stop_Reason (Get_String_Field (Msg, "stopReason")),
         Timestamp => Message_Timestamp (Envelope, Msg));
   end Parse_Assistant_Message;

   function Parse_Tool_Result_Message
     (Envelope : GNATCOLL.JSON.JSON_Value;
      Msg      : GNATCOLL.JSON.JSON_Value) return LLM.Types.Message
   is
      Content : LLM.Types.Content_Block_Vectors.Vector;
      Blocks  : constant GNATCOLL.JSON.JSON_Array :=
        Get_Array_Field (Msg, "content");
      Text    : Unbounded_String;
   begin
      for I in 1 .. GNATCOLL.JSON.Length (Blocks) loop
         declare
            Block : constant GNATCOLL.JSON.JSON_Value :=
              GNATCOLL.JSON.Get (Blocks, I);
         begin
            if Get_String_Field (Block, "type") = "text" then
               if Length (Text) > 0 then
                  Append (Text, ASCII.LF);
               end if;
               Append (Text, Get_String_Field (Block, "text"));
            end if;
         end;
      end loop;

      Content.Append
        ((Kind        => LLM.Types.Tool_Result_Block,
          Result_Id   => To_Unbounded_String
            (Get_String_Field (Msg, "toolCallId")),
          Result_Text => Text,
          Is_Error    => Get_Boolean_Field (Msg, "isError")));

      return
        (Role      => LLM.Types.Tool_Result,
         Content   => Content,
         Tok_Usage => (others => 0),
         Stop      => LLM.Types.Unknown_Stop,
         Timestamp => Message_Timestamp (Envelope, Msg));
   end Parse_Tool_Result_Message;

   function Session_File_Path (Session_Id : String) return String is
   begin
      return Session_Lister.Find_Session_File (Session_Id);
   end Session_File_Path;

   function Create_Session (Cwd : String) return String is
      Dir_Path : constant String := Session_Lister.Sessions_Dir (Cwd);
   begin
      Ada.Directories.Create_Path (Dir_Path);

      loop
         declare
            Session_Id : constant String := New_UUID;
            Path       : constant String :=
              Dir_Path & "/" & Session_Id & ".jsonl";
            Header     : constant GNATCOLL.JSON.JSON_Value :=
              GNATCOLL.JSON.Create_Object;
            Created_At : constant Long_Integer :=
              Long_Integer (Current_Unix_Milliseconds);
         begin
            if not Ada.Directories.Exists (Path) then
               Header.Set_Field ("version", Integer (1));
               Header.Set_Field ("id", Session_Id);
               Header.Set_Field ("createdAt", Created_At);
               Header.Set_Field ("workDir", Cwd);

               Write_Raw_Line
                 (Path  => Path,
                  Line  => GNATCOLL.JSON.Write (Header),
                  Mode  => Ada.Streams.Stream_IO.Out_File,
                  Fresh => True);

               return Session_Id;
            end if;
         end;
      end loop;
   exception
      when Ex : others =>
         raise Session_Error with
           "Create_Session failed: " & Ada.Exceptions.Exception_Message (Ex);
   end Create_Session;

   procedure Delete_Session
     (Session_Id : String)
   is
      Path : constant String := Session_File_Path (Session_Id);
   begin
      if Path'Length > 0 and then Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_File (Path);
      end if;
   exception
      when Ex : others =>
         raise Session_Error with
           "Delete_Session failed: " & Ada.Exceptions.Exception_Message (Ex);
   end Delete_Session;

   procedure Append_Message
     (Session_Id : String;
      Msg        : LLM.Types.Message)
   is
      Path : constant String := Session_File_Path (Session_Id);
   begin
      if Path'Length = 0 then
         raise Session_Error with
           "Append_Message: session file not found for " & Session_Id;
      end if;

      Write_Raw_Line
        (Path  => Path,
         Line  => Message_To_Json (Msg),
         Mode  => Ada.Streams.Stream_IO.Append_File);
   exception
      when Session_Error =>
         raise;
      when Ex : others =>
         raise Session_Error with
           "Append_Message failed: " & Ada.Exceptions.Exception_Message (Ex);
   end Append_Message;

   procedure Append_Compaction
     (Session_Id       : String;
      Summary          : String;
      First_Kept_Index : Natural;
      Tokens_Before    : Natural;
      Read_Files       : String;
      Modified_Files   : String)
   is
      Path         : constant String := Session_File_Path (Session_Id);
      Record_Value : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Details      : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
   begin
      if Path'Length = 0 then
         raise Session_Error with
           "Append_Compaction: session file not found for " & Session_Id;
      end if;

      Details.Set_Field ("readFiles", String_List_To_Array (Read_Files));
      Details.Set_Field
        ("modifiedFiles", String_List_To_Array (Modified_Files));

      Record_Value.Set_Field ("type", "compaction");
      Record_Value.Set_Field ("summary", Summary);
      Record_Value.Set_Field
        ("firstKeptMessageIndex", Integer (First_Kept_Index));
      Record_Value.Set_Field ("tokensBefore", Integer (Tokens_Before));
      Record_Value.Set_Field ("details", Details);

      Write_Raw_Line
        (Path  => Path,
         Line  => GNATCOLL.JSON.Write (Record_Value),
         Mode  => Ada.Streams.Stream_IO.Append_File);
   exception
      when Session_Error =>
         raise;
      when Ex : others =>
         raise Session_Error with
           "Append_Compaction failed: "
           & Ada.Exceptions.Exception_Message (Ex);
   end Append_Compaction;

   function Session_Work_Dir (Session_Id : String) return String is
      Path : constant String := Session_File_Path (Session_Id);
      File : Ada.Text_IO.File_Type;
   begin
      if Path'Length = 0 or else not Ada.Directories.Exists (Path) then
         return "";
      end if;

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);

      declare
         Line   : constant String := To_String (Read_Line (File));
         Parsed : constant GNATCOLL.JSON.Read_Result :=
           GNATCOLL.JSON.Read (Line);
      begin
         Ada.Text_IO.Close (File);

         if Parsed.Success then
            return Get_String_Field (Parsed.Value, "workDir");
         end if;
      end;

      return "";
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         return "";
   end Session_Work_Dir;

   function Load_Messages
     (Session_Id : String) return LLM.Types.Message_Vectors.Vector
   is
      Path               : constant String := Session_File_Path (Session_Id);
      Result             : LLM.Types.Message_Vectors.Vector;
      Pre_Messages       : LLM.Types.Message_Vectors.Vector;
      Post_Messages      : LLM.Types.Message_Vectors.Vector;
      File               : Ada.Text_IO.File_Type;
      Line_N             : Natural := 0;
      Compaction_Found   : Boolean := False;
      Compaction_Summary : Unbounded_String;
      First_Kept         : Natural := 0;
   begin
      if Path'Length = 0 or else not Ada.Directories.Exists (Path) then
         return Result;
      end if;

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);

      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line : constant String := To_String (Read_Line (File));
         begin
            Line_N := Line_N + 1;

            if Line_N = 1 or else Line'Length = 0 then
               null;
            else
               declare
                  Parsed : constant GNATCOLL.JSON.Read_Result :=
                    GNATCOLL.JSON.Read (Line);
               begin
                  if Parsed.Success then
                     declare
                        Envelope    : constant GNATCOLL.JSON.JSON_Value :=
                          Parsed.Value;
                        Record_Type : constant String :=
                          Get_String_Field (Envelope, "type");
                        Msg         : constant GNATCOLL.JSON.JSON_Value :=
                          Message_Object (Envelope);
                        Role        : constant String :=
                          Get_String_Field (Msg, "role");
                     begin
                        if Record_Type = "compaction" then
                           if Compaction_Found then
                              Pre_Messages.Clear;
                              Post_Messages.Clear;
                           end if;

                           Compaction_Found := True;
                           Compaction_Summary := To_Unbounded_String
                             (Get_String_Field (Envelope, "summary"));
                           First_Kept := Get_Natural_Field
                             (Envelope, "firstKeptMessageIndex");
                        elsif Msg.Kind = GNATCOLL.JSON.JSON_Object_Type then
                           declare
                              Parsed_Message : constant LLM.Types.Message :=
                                (if Role = "user"
                                 then Parse_User_Message (Envelope, Msg)
                                 elsif Role = "assistant"
                                 then Parse_Assistant_Message (Envelope, Msg)
                                 elsif Role = "toolResult"
                                 then Parse_Tool_Result_Message (Envelope, Msg)
                                 else (Role      => LLM.Types.User,
                                       Content   =>
                                         LLM.Types.Content_Block_Vectors
                                           .Empty_Vector,
                                       Tok_Usage => (others => 0),
                                       Stop      => LLM.Types.Unknown_Stop,
                                       Timestamp => Null_Unbounded_String));
                           begin
                              if Role = "user"
                                or else Role = "assistant"
                                or else Role = "toolResult"
                              then
                                 if Compaction_Found then
                                    Post_Messages.Append (Parsed_Message);
                                 else
                                    Pre_Messages.Append (Parsed_Message);
                                 end if;
                              end if;
                           end;
                        end if;
                     end;
                  end if;
               end;
            end if;
         end;
      end loop;

      Ada.Text_IO.Close (File);

      if Compaction_Found then
         Result.Append
           (Compaction_Summary_Message (To_String (Compaction_Summary)));
         Append_Kept_Messages (Result, Pre_Messages, First_Kept);
         Append_Vector (Result, Post_Messages);
      else
         Append_Vector (Result, Pre_Messages);
      end if;

      return Result;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;

         return Result;
   end Load_Messages;

end LLM.Session_Store;
