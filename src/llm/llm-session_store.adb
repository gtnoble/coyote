--  LLM.Session_Store body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Calendar.Time_Zones;
with Ada.Environment_Variables;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Numerics.Discrete_Random;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with Coyote_Canvas.Store;
with Coyote_Process_Control;
with Coyote_Session_Transactions;
with GNAT.OS_Lib;
with GNATCOLL.JSON;
with Interfaces;
with Session_Lister;
with LLM.User_Images;

package body LLM.Session_Store is

   use type GNATCOLL.JSON.JSON_Value_Type;
   use type LLM.Types.Content_Block_Kind;
   use type LLM.Types.Role;

   subtype Byte is Interfaces.Unsigned_8;
   use type Byte;

   package Byte_Random is new Ada.Numerics.Discrete_Random (Byte);

   function Current_Unix_Milliseconds return Long_Long_Integer is
      use Ada.Calendar;

      Epoch : constant Time :=
        Time_Of (Year => 1_970, Month => 1, Day => 1, Seconds => 0.0);
   begin
      return Long_Long_Integer ((Clock - Epoch) * 1_000.0);
   end Current_Unix_Milliseconds;

   function Get_String_Field
     (Value   : GNATCOLL.JSON.JSON_Value;
      Field   : String;
      Default : String := "")
      return String
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
      Field : String)
      return GNATCOLL.JSON.JSON_Value
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
      Field : String)
      return GNATCOLL.JSON.JSON_Array
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
      Default : Natural := 0)
      return Natural
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
     (Value : GNATCOLL.JSON.JSON_Value; Field : String) return Boolean
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
     (Value : GNATCOLL.JSON.JSON_Value; Field : String) return String
   is
      Raw : Long_Integer;
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Value.Has_Field (Field)
      then
         if Value.Get (Field).Kind = GNATCOLL.JSON.JSON_Int_Type then
            Raw := Value.Get (Field).Get;
            return
              Ada.Strings.Fixed.Trim
                (Long_Integer'Image (Raw), Ada.Strings.Both);
         elsif Value.Get (Field).Kind = GNATCOLL.JSON.JSON_String_Type then
            return Value.Get (Field).Get;
         end if;
      end if;

      return "";
   end Get_Integer_Image;

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

   function Tool_Result_Status_Image
     (Status : LLM.Types.Tool_Result_Status) return String
   is
   begin
      case Status is
         when LLM.Types.Result_Success =>
            return "success";
         when LLM.Types.Result_Error =>
            return "error";
         when LLM.Types.Result_Timed_Out =>
            return "timed_out";
         when LLM.Types.Result_Cancelled =>
            return "cancelled";
      end case;
   end Tool_Result_Status_Image;

   function Tool_Result_Status_Value
     (Text : String; Is_Error : Boolean) return LLM.Types.Tool_Result_Status
   is
   begin
      if Text = "timed_out" then
         return LLM.Types.Result_Timed_Out;
      elsif Text = "cancelled" then
         return LLM.Types.Result_Cancelled;
      elsif Text = "success" then
         return LLM.Types.Result_Success;
      elsif Text = "error" or else Is_Error then
         return LLM.Types.Result_Error;
      else
         return LLM.Types.Result_Success;
      end if;
   end Tool_Result_Status_Value;

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
      Bytes     : array (Positive range 1 .. 16)
        of Byte;
   begin
      Byte_Random.Reset (Generator);

      for I in Bytes'Range loop
         Bytes (I) := Byte_Random.Random (Generator);
      end loop;

      --  RFC 4122 UUIDv4: byte 7 carries the version nibble and byte 9
      --  carries the variant bits.
      Bytes (7) := (Bytes (7) and 16#0F#) or 16#40#;
      Bytes (9) := (Bytes (9) and 16#3F#) or 16#80#;

      return
        Byte_Image (Bytes (1)) & Byte_Image (Bytes (2))
        & Byte_Image (Bytes (3)) & Byte_Image (Bytes (4)) & "-"
        & Byte_Image (Bytes (5)) & Byte_Image (Bytes (6)) & "-"
        & Byte_Image (Bytes (7)) & Byte_Image (Bytes (8)) & "-"
        & Byte_Image (Bytes (9)) & Byte_Image (Bytes (10)) & "-"
        & Byte_Image (Bytes (11)) & Byte_Image (Bytes (12))
        & Byte_Image (Bytes (13)) & Byte_Image (Bytes (14))
        & Byte_Image (Bytes (15)) & Byte_Image (Bytes (16));
   end New_UUID;

   package Tx renames Coyote_Session_Transactions;
   use type Tx.Result;

   procedure Require_Writer (Path : String; Lock : in out Tx.Guard) is
      Status : Tx.Result;
   begin
      if Path'Length = 0 then
         raise Session_Error with "Cannot resolve session file";
      end if;
      Tx.Wait_For_Lock (Path, Lock, Status);
      case Status is
         when Tx.Acquired => null;
         when Tx.Busy => raise Session_Error with "Session writer is busy";
         when Tx.Unavailable =>
            raise Session_Error with "Session writer lock unavailable";
      end case;
   end Require_Writer;

   function Read_Line (File : Ada.Text_IO.File_Type) return Unbounded_String;

   function Wrap_Message (Msg : GNATCOLL.JSON.JSON_Value)
      return GNATCOLL.JSON.JSON_Value is
      use GNATCOLL.JSON;
      Envelope : constant JSON_Value := Create_Object;
   begin
      Envelope.Set_Field ("type", "message");
      Envelope.Set_Field ("message", Msg);
      return Envelope;
   end Wrap_Message;

   function ISO_Date (Ms : Long_Long_Integer) return String is
      use Ada.Calendar;
      Result : String := Ada.Calendar.Formatting.Image
        (Time_Of (1970, 1, 1) + Duration (Long_Long_Float (Ms) / 1_000.0),
         Include_Time_Fraction => True);
   begin
      Result (11) := 'T';
      return Result & "Z";
   end ISO_Date;

   procedure Write_Raw_Line
     (Path, Line : String; Mode : Ada.Streams.Stream_IO.File_Mode;
      Fresh : Boolean := False; Message : Boolean := False;
      Image_Turn : Boolean := False; Session_Id : String := "")
   is
      Resolved : constant String :=
        (if Fresh then Tx.Resolve (Ada.Directories.Containing_Directory (Path))
           & "/" & Ada.Directories.Simple_Name (Path)
         else Tx.Resolve (Path));
      Lock     : Tx.Guard;
      File     : Ada.Streams.Stream_IO.File_Type;
      Stream   : Ada.Streams.Stream_IO.Stream_Access;
      Accepted : Boolean := False;
      Stage    : Unbounded_String;
      Status   : Tx.Result;
      Input    : Ada.Text_IO.File_Type;
      Payload  : Unbounded_String := To_Unbounded_String (Line);
      Migrate  : Boolean := False;
      Uncertain : Boolean := False;
      procedure Put (Text : String) is
      begin
         String'Write (Stream, Text);
         Character'Write (Stream, ASCII.LF);
      end Put;
   begin
      Require_Writer (Resolved, Lock);
      Coyote_Process_Control.Begin_Persistence_Write (Accepted);
      if not Accepted then
         if Fresh or else Image_Turn then
            raise Session_Error with "Session persistence is frozen";
         end if;
         return;
      end if;
      if Message then
         declare
            use GNATCOLL.JSON;
         begin
            Ada.Text_IO.Open (Input, Ada.Text_IO.In_File, Resolved);
            declare
               Header : constant Read_Result := Read (To_String (Read_Line (Input)));
               V : constant Natural :=
                 (if Header.Success then Get_Natural_Field (Header.Value, "version")
                  else 0);
               Is_V3 : constant Boolean := V = 3 and then
                 Get_String_Field (Header.Value, "type") = "session";
            begin
               if Image_Turn and then (not Header.Success or else
                  Get_String_Field (Header.Value, "id") /= Session_Id or else
                  Tx.Identity (Resolved) /= Session_Id or else Path /= Resolved or else
                  (not Is_V3 and then V /= 1))
               then
                  raise Session_Error with "Cannot validate session for Canvas images";
               end if;
               Migrate := Image_Turn and then not Is_V3;
               if Migrate or else Is_V3 then
                  Payload := To_Unbounded_String (Write (Wrap_Message (Read (Line))));
               end if;
               if Migrate then
                  declare
                     H : constant JSON_Value := Header.Value;
                     Ms : constant Long_Long_Integer := Get (H.Get ("createdAt"));
                     Work : constant String := Get_String_Field (H, "workDir");
                  begin
                     if Work = "" or else Ms <= 0 then
                        raise Session_Error with "Invalid legacy session header";
                     end if;
                     H.Set_Field ("version", Integer (3));
                     H.Set_Field ("type", "session");
                     H.Set_Field ("timestamp", ISO_Date (Ms));
                     H.Set_Field ("cwd", Work);
                     Stage := To_Unbounded_String (Tx.Create_Stage (Resolved));
                     if Length (Stage) = 0 then
                        raise Session_Error with "Cannot stage Canvas session migration";
                     end if;
                     Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.Out_File,
                                                 To_String (Stage));
                     Stream := Ada.Streams.Stream_IO.Stream (File);
                     Put (Write (H));
                     while not Ada.Text_IO.End_Of_File (Input) loop
                        declare
                           Raw : constant String := To_String (Read_Line (Input));
                        begin
                           if Raw'Length > 0 then
                              declare
                                 Rec : constant JSON_Value := Read (Raw);
                                 Role : constant String := Get_String_Field (Rec, "role");
                              begin
                                 if Rec.Kind /= JSON_Object_Type then
                                    raise Session_Error with "Invalid legacy session record";
                                 elsif Role = "user" or else Role = "assistant"
                                   or else Role = "toolResult"
                                 then
                                    Put (Write (Wrap_Message (Rec)));
                                 else
                                    Put (Raw);
                                 end if;
                              end;
                           end if;
                        end;
                     end loop;
                  end;
               end if;
            end;
            Ada.Text_IO.Close (Input);
         end;
      end if;
      if Fresh then
         Stage := To_Unbounded_String (Tx.Create_Stage (Resolved));
         if Length (Stage) = 0 then
            raise Session_Error with "Cannot stage session header";
         end if;
         Ada.Streams.Stream_IO.Open (File, Mode, To_String (Stage));
      elsif not Migrate then
         Ada.Streams.Stream_IO.Open (File, Mode, Resolved);
      end if;
      Stream := Ada.Streams.Stream_IO.Stream (File);
      Put (To_String (Payload));
      Ada.Streams.Stream_IO.Close (File);
      if Fresh then
         Tx.Publish (To_String (Stage), Resolved, Status);
         if Status /= Tx.Acquired then
            raise Session_Error with "Cannot publish session header";
         end if;
      elsif Migrate then
         Tx.Replace_Log (To_String (Stage), Resolved, Status, Uncertain);
         if Uncertain then
            raise Session_Error with "Canvas session migration published; durability uncertain";
         elsif Status /= Tx.Acquired then
            raise Session_Error with "Cannot publish Canvas session migration";
         end if;
      elsif Image_Turn and then not Tx.Sync_Log (Resolved) then
         raise Session_Error with "Canvas record may have been written; durability uncertain";
      end if;
      Coyote_Process_Control.End_Persistence_Write;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (Input) then
            Ada.Text_IO.Close (Input);
         end if;
         if Ada.Streams.Stream_IO.Is_Open (File) then
            begin
               Ada.Streams.Stream_IO.Close (File);
            exception
               when others => null;
            end;
         end if;
         if Length (Stage) /= 0 then
            begin
               Ada.Directories.Delete_File (To_String (Stage));
            exception
               when others => null;
            end;
         end if;
         if Accepted then
            Coyote_Process_Control.End_Persistence_Write;
         end if;
         raise;
   end Write_Raw_Line;

   function Read_Line (File : Ada.Text_IO.File_Type) return Unbounded_String is
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
         Tok_Usage =>
           (others => 0),
         Stop      => LLM.Types.Unknown_Stop,
         Timestamp => To_Unbounded_String (""));
   end Compaction_Summary_Message;

   procedure Append_Kept_Messages
     (Target           : in out LLM.Types.Message_Vectors.Vector;
      Source           :        LLM.Types.Message_Vectors.Vector;
      First_Kept_Index :        Natural)
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
      if Role = "user" or else Role = "assistant" or else Role = "toolResult"
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
      Msg      : GNATCOLL.JSON.JSON_Value)
      return Unbounded_String
   is
      Image : constant String :=
        (if
           Get_Integer_Image (Msg, "timestamp")'Length > 0
         then
           Get_Integer_Image (Msg, "timestamp")
         elsif
           Get_Integer_Image (Envelope, "timestamp")'Length > 0
         then
           Get_Integer_Image (Envelope, "timestamp")
         elsif
           Get_String_Field (Envelope, "timestamp")'Length > 0
         then
           Get_String_Field (Envelope, "timestamp")
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
            when LLM.Types.User
               | LLM.Types.Compaction_Summary =>
               if Block.Kind = LLM.Types.Text_Block then
                  declare
                     Item : constant GNATCOLL.JSON.JSON_Value :=
                       GNATCOLL.JSON.Create_Object;
                  begin
                     Item.Set_Field ("type", "text");
                     Item.Set_Field ("text", To_String (Block.Text));
                     GNATCOLL.JSON.Append (Result, Item);
                  end;
               elsif Block.Kind = LLM.Types.User_Image_Block then
                  GNATCOLL.JSON.Append (Result, LLM.User_Images.To_JSON (Block.Image));
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
                        Item.Set_Field
                          ("originProvider",
                           To_String (Block.Origin_Provider));
                        Item.Set_Field
                          ("originModel", To_String (Block.Origin_Model));
                        GNATCOLL.JSON.Append (Result, Item);
                     end;
                  when LLM.Types.Tool_Call_Block =>
                     declare
                        Item      : constant GNATCOLL.JSON.JSON_Value  :=
                          GNATCOLL.JSON.Create_Object;
                        Parsed    : constant GNATCOLL.JSON.Read_Result :=
                          GNATCOLL.JSON.Read
                            (To_String (Block.Arguments_Json));
                        Arguments : GNATCOLL.JSON.JSON_Value;
                     begin
                        if Length (Block.Arguments_Json) = 0 then
                           Arguments := GNATCOLL.JSON.Create_Object;
                        elsif Parsed.Success
                          and then Parsed.Value.Kind
                            = GNATCOLL.JSON.JSON_Object_Type
                        then
                           Arguments := Parsed.Value;
                        else
                           --  The LLM generated invalid JSON arguments.
                           --  Preserve the raw text so session persistence
                           --  never crashes and the tool-call can still be
                           --  replayed.  On reload, a string-valued
                           --  "arguments" field is restored as-is.
                           Arguments :=
                             GNATCOLL.JSON.Create
                               (To_String (Block.Arguments_Json));
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
      Media_Type   : Unbounded_String;
      Is_Error     : Boolean                           := False;
      Status       : LLM.Types.Tool_Result_Status := LLM.Types.Result_Success;
   begin
      for Block of Msg.Content loop
         case Block.Kind is
            when LLM.Types.Tool_Result_Block =>
               if Length (Tool_Call_Id) = 0 then
                  Tool_Call_Id := Block.Result_Id;
               end if;
               Is_Error := Is_Error or else Block.Is_Error;
               Status   := Block.Status;
               if Length (Block.Media_Type) > 0 then
                  Media_Type := Block.Media_Type;
               end if;

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
         Ms   : constant Long_Integer             :=
           Long_Integer (Current_Unix_Milliseconds);
      begin
         if Length (Media_Type) > 0 then
            Item.Set_Field ("type", "image");
            Item.Set_Field ("media_type", To_String (Media_Type));
            Item.Set_Field ("data", To_String (Result_Text));
         else
            Item.Set_Field ("type", "text");
            Item.Set_Field ("text", To_String (Result_Text));
         end if;
         GNATCOLL.JSON.Append (Content, Item);

         Result.Set_Field ("role", "toolResult");
         Result.Set_Field ("toolCallId", To_String (Tool_Call_Id));
         Result.Set_Field ("toolName", To_String (Tool_Name));
         Result.Set_Field ("content", Content);
         Result.Set_Field ("isError", Is_Error);
         Result.Set_Field ("status", Tool_Result_Status_Image (Status));
         Result.Set_Field ("timestamp", Ms);
      end;

      return Result;
   end Tool_Result_Object;

   function Message_To_Json (Msg : LLM.Types.Message) return String is
      Result : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Usage : constant GNATCOLL.JSON.JSON_Value := GNATCOLL.JSON.Create_Object;
      Ms : constant Long_Integer := Long_Integer (Current_Unix_Milliseconds);
   begin
      case Msg.Role is
         when LLM.Types.Compaction_Summary =>
            raise Session_Error
              with "Compaction_Summary messages must not be persisted directly";

         when LLM.Types.User =>
            Result.Set_Field ("role", "user");
            Result.Set_Field ("content", Content_To_Array (Msg));
            Result.Set_Field ("timestamp", Ms);

         when LLM.Types.Assistant =>
            Usage.Set_Field ("input", Integer (Msg.Tok_Usage.Input));
            Usage.Set_Field ("output", Integer (Msg.Tok_Usage.Output));
            Usage.Set_Field ("cacheRead", Integer (Msg.Tok_Usage.Cache_Read));
            Usage.Set_Field
              ("cacheWrite", Integer (Msg.Tok_Usage.Cache_Write));
            Usage.Set_Field ("thinking", Integer (Msg.Tok_Usage.Thinking));
            Usage.Set_Field
              ("contextTokens", Integer (Msg.Tok_Usage.Context_Tokens));

            Result.Set_Field ("role", "assistant");
            Result.Set_Field ("content", Content_To_Array (Msg));
            declare
               Provider : Unbounded_String;
               Model_Id : Unbounded_String;
            begin
               for Block of Msg.Content loop
                  if Block.Kind = LLM.Types.Thinking_Block then
                     Provider := Block.Origin_Provider;
                     Model_Id := Block.Origin_Model;
                     exit;
                  end if;
               end loop;
               Result.Set_Field ("model", To_String (Model_Id));
               Result.Set_Field ("provider", To_String (Provider));
            end;
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
      Msg      : GNATCOLL.JSON.JSON_Value)
      return LLM.Types.Message
   is
      Content : LLM.Types.Content_Block_Vectors.Vector;
      Blocks  : constant GNATCOLL.JSON.JSON_Array :=
        Get_Array_Field (Msg, "content");
      Images : LLM.Types.User_Images.Vector;
      Total : Natural := 0;
   begin
      for I in 1 .. GNATCOLL.JSON.Length (Blocks) loop
         declare
            Block : constant GNATCOLL.JSON.JSON_Value :=
              GNATCOLL.JSON.Get (Blocks, I);
         begin
            if Get_String_Field (Block, "type") = "text" then
               Content.Append
                 ((Kind => LLM.Types.Text_Block,
                   Text =>
                     To_Unbounded_String (Get_String_Field (Block, "text"))));
            elsif Get_String_Field (Block, "type") = "image" then
               if Natural (Images.Length) >= LLM.User_Images.Max_Count then
                  raise LLM.User_Images.Invalid_Image with "Too many stored Canvas images";
               end if;
               declare
                  Image : constant LLM.Types.User_Image := LLM.User_Images.From_JSON (Block);
               begin
                  Total := Total + Length (Image.PNG);
                  if Total > LLM.User_Images.Max_Turn then
                     raise LLM.User_Images.Invalid_Image with "Stored Canvas turn exceeds byte limit";
                  end if;
                  Images.Append (Image);
                  Content.Append ((Kind => LLM.Types.User_Image_Block, Image => Image));
               end;
            end if;
         end;
      end loop;

      return
        (Role      => LLM.Types.User,
         Content   => Content,
         Tok_Usage =>
           (others => 0),
         Stop      => LLM.Types.Unknown_Stop,
         Timestamp => Message_Timestamp (Envelope, Msg));
   end Parse_User_Message;

   function Parse_Assistant_Message
     (Envelope         : GNATCOLL.JSON.JSON_Value;
      Msg              : GNATCOLL.JSON.JSON_Value;
      Default_Provider : String;
      Default_Model    : String)
      return LLM.Types.Message
   is
      Content  : LLM.Types.Content_Block_Vectors.Vector;
      Blocks   : constant GNATCOLL.JSON.JSON_Array :=
        Get_Array_Field (Msg, "content");
      Usage    : constant GNATCOLL.JSON.JSON_Value :=
        Get_Object_Field (Msg, "usage");
      Provider : constant String                   :=
        (if
           Get_String_Field (Msg, "provider")'Length > 0
         then
           Get_String_Field (Msg, "provider")
         else Default_Provider);
      Model_Id : constant String                   :=
        (if
           Get_String_Field (Msg, "model")'Length > 0
         then
           Get_String_Field (Msg, "model")
         else Default_Model);
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
                   Text =>
                     To_Unbounded_String (Get_String_Field (Block, "text"))));
            elsif Kind = "thinking" then
               Content.Append
                 ((Kind            => LLM.Types.Thinking_Block,
                   Thinking        =>
                     To_Unbounded_String
                       (Get_String_Field (Block, "thinking")),
                   Signature       =>
                     To_Unbounded_String
                       (Get_String_Field (Block, "signature")),
                   Origin_Provider =>
                     To_Unbounded_String
                       ((if
                           Get_String_Field (Block, "originProvider")'Length
                           > 0
                         then
                           Get_String_Field (Block, "originProvider")
                         else Provider)),
                   Origin_Model    =>
                     To_Unbounded_String
                       ((if
                           Get_String_Field (Block, "originModel")'Length > 0
                         then
                           Get_String_Field (Block, "originModel")
                         else Model_Id))));
            elsif Kind = "toolCall" then
               declare
                  Arguments : constant GNATCOLL.JSON.JSON_Value :=
                    Block.Get ("arguments");
                  Args_Json : constant String                   :=
                    (if
                       Arguments.Kind = GNATCOLL.JSON.JSON_Object_Type
                     then
                       GNATCOLL.JSON.Write (Arguments)
                     elsif
                       Arguments.Kind = GNATCOLL.JSON.JSON_String_Type
                     then
                       Arguments.Get
                     else "{}");
               begin
                  Content.Append
                    ((Kind           => LLM.Types.Tool_Call_Block,
                      Tool_Call_Id   =>
                        To_Unbounded_String (Get_String_Field (Block, "id")),
                      Tool_Name      =>
                        To_Unbounded_String (Get_String_Field (Block, "name")),
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
            Cache_Write    => Get_Natural_Field (Usage, "cacheWrite"),
            Thinking       => Get_Natural_Field (Usage, "thinking"),
            Context_Tokens => Get_Natural_Field (Usage, "contextTokens")),
         Stop      => To_Stop_Reason (Get_String_Field (Msg, "stopReason")),
         Timestamp => Message_Timestamp (Envelope, Msg));
   end Parse_Assistant_Message;

   function Parse_Tool_Result_Message
     (Envelope : GNATCOLL.JSON.JSON_Value;
      Msg      : GNATCOLL.JSON.JSON_Value)
      return LLM.Types.Message
   is
      Content    : LLM.Types.Content_Block_Vectors.Vector;
      Blocks     : constant GNATCOLL.JSON.JSON_Array     :=
        Get_Array_Field (Msg, "content");
      Text       : Unbounded_String;
      Media_Type : Unbounded_String;
      Is_Error   : constant Boolean := Get_Boolean_Field (Msg, "isError");
      Status     : constant LLM.Types.Tool_Result_Status :=
        Tool_Result_Status_Value (Get_String_Field (Msg, "status"), Is_Error);
   begin
      for I in 1 .. GNATCOLL.JSON.Length (Blocks) loop
         declare
            Block      : constant GNATCOLL.JSON.JSON_Value :=
              GNATCOLL.JSON.Get (Blocks, I);
            Block_Type : constant String := Get_String_Field (Block, "type");
         begin
            if Block_Type = "text" then
               if Length (Text) > 0 then
                  Append (Text, ASCII.LF);
               end if;
               Append (Text, Get_String_Field (Block, "text"));
            elsif Block_Type = "image" then
               Media_Type :=
                 To_Unbounded_String (Get_String_Field (Block, "media_type"));
               Text := To_Unbounded_String (Get_String_Field (Block, "data"));
            end if;
         end;
      end loop;

      Content.Append
        ((Kind        => LLM.Types.Tool_Result_Block,
          Result_Id   =>
            To_Unbounded_String (Get_String_Field (Msg, "toolCallId")),
          Result_Text => Text,
          Media_Type  => Media_Type,
          Is_Error    => Is_Error,
          Status      => Status));

      return
        (Role      => LLM.Types.Tool_Result,
         Content   => Content,
         Tok_Usage =>
           (others => 0),
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
            Session_Id : constant String                   := New_UUID;
            Path : constant String := Dir_Path & "/" & Session_Id & ".jsonl";
            Header     : constant GNATCOLL.JSON.JSON_Value :=
              GNATCOLL.JSON.Create_Object;
            Created_At : constant Long_Integer             :=
              Long_Integer (Current_Unix_Milliseconds);
         begin
            if not Ada.Directories.Exists (Path) then
               Header.Set_Field ("version", Integer (3));
               Header.Set_Field ("type", "session");
               Header.Set_Field ("timestamp", ISO_Date (Long_Long_Integer (Created_At)));
               Header.Set_Field ("cwd", Cwd);
               Header.Set_Field ("id", Session_Id);
               Header.Set_Field ("createdAt", Created_At);
               Header.Set_Field ("workDir", Cwd);
               declare
                  Parent_Id : constant String :=
                    Ada.Environment_Variables.Value
                      ("COYOTE_PARENT_SESSION", "");
               begin
                  if Parent_Id'Length > 0 then
                     Header.Set_Field ("parentSession", Parent_Id);
                     Header.Set_Field ("parentRelation", "subagent");
                  end if;
               end;
               --  Record the current thinking level in the session header so
               --  session replayers and SQC tooling can see it.
               declare
                  Think_Level : constant String :=
                    Ada.Environment_Variables.Value
                      ("COYOTE_THINKING_LEVEL", "");
               begin
                  if Think_Level'Length > 0 then
                     Header.Set_Field ("thinkingLevel", Think_Level);
                  end if;
               end;

               --  Record sandbox profile so session replayers can reinstate
               --  the profile on reload.
               declare
                  Sand_Profile : constant String :=
                    Ada.Environment_Variables.Value
                      ("COYOTE_SANDBOX_PROFILE", "");
               begin
                  if Sand_Profile'Length > 0 then
                     Header.Set_Field ("sandboxProfile", Sand_Profile);
                  end if;
               end;

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
         raise Session_Error
           with "Create_Session failed: "
           & Ada.Exceptions.Exception_Message (Ex);
   end Create_Session;

   procedure Delete_Session
     (Session_Id : String; Empty_Only : Boolean := False)
   is
      use Ada.Directories;
      package Store renames Coyote_Canvas.Store;
      Found : constant String := Session_File_Path (Session_Id);
      Path : constant String := Tx.Resolve (Found);
      Lock : Tx.Guard;
      Accepted : Boolean := False;
      Status : Store.Result;
   begin
      if Session_Id = "" or else Path = "" then
         return;
      end if;
      if GNAT.OS_Lib.Is_Symbolic_Link (Found) then
         raise Session_Error with "Refusing to delete a session through an alias";
      end if;
      Require_Writer (Path, Lock);
      if not Exists (Path) then
         return;
      end if;
      declare
         Parent : constant String := Containing_Directory (Path);
         Identity : constant String := Tx.Identity (Path);
         UUID : constant String := (if Identity'Length = 36 then Identity else "");
         File : Ada.Text_IO.File_Type;
      begin
         --  Lookup historically permits substring matches. Never delete a
         --  different session, even if its filename matched the lookup.
         Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
         declare
            Header : constant GNATCOLL.JSON.Read_Result :=
              GNATCOLL.JSON.Read (To_String (Read_Line (File)));
            Is_Empty : constant Boolean := Ada.Text_IO.End_Of_File (File);
         begin
            Ada.Text_IO.Close (File);
            if not Header.Success or else
              Get_String_Field (Header.Value, "id") /= Session_Id or else
              (UUID /= "" and then UUID /= Session_Id)
            then
               raise Session_Error with "Session identity does not match";
            end if;
            if Empty_Only and then
              (not Is_Empty or else
               (UUID /= "" and then
                (Exists (Parent & "/" & UUID & ".canvas") or else
                 GNAT.OS_Lib.Is_Symbolic_Link (Parent & "/" & UUID & ".canvas"))))
            then
               return;
            end if;
         end;
         Coyote_Process_Control.Begin_Persistence_Write (Accepted);
         if not Accepted then
            return;
         end if;
         --  In empty-only mode never authorize removal of a sidecar.
         Store.Remove_Session (Parent, (if Empty_Only then "" else UUID),
                               Simple_Name (Path), Status);
         Coyote_Process_Control.End_Persistence_Write;
         Accepted := False;
      end;
      case Status is
         when Store.Ok | Store.Missing => null;
         when Store.Busy =>
            raise Session_Error with "Canvas is still open for editing";
         when Store.Uncertain =>
            raise Session_Error with "Session removed; cleanup or durability uncertain";
         when others =>
            raise Session_Error with "Cannot remove session storage: " & Status'Image;
      end case;
   exception
      when Ex : others =>
         if Accepted then
            Coyote_Process_Control.End_Persistence_Write;
         end if;
         raise Session_Error with "Delete_Session failed: "
           & Ada.Exceptions.Exception_Message (Ex);
   end Delete_Session;

   procedure Append_Message (Session_Id : String; Msg : LLM.Types.Message) is
      Path : constant String := Session_File_Path (Session_Id);
   begin
      if LLM.User_Images.Has_Images (Msg) then
         declare
            Messages : LLM.Types.Message_Vectors.Vector;
         begin
            Messages.Append (Msg);
            LLM.User_Images.Check_History (Messages);
         end;
      end if;
      if Path'Length = 0 then
         raise Session_Error
           with "Append_Message: session file not found for " & Session_Id;
      end if;

      Write_Raw_Line
        (Path => Path,
         Line => Message_To_Json (Msg),
         Mode => Ada.Streams.Stream_IO.Append_File, Message => True,
         Image_Turn => LLM.User_Images.Has_Images (Msg), Session_Id => Session_Id);
   exception
      when Session_Error =>
         raise;
      when Ex : others   =>
         raise Session_Error
           with "Append_Message failed: "
           & Ada.Exceptions.Exception_Message (Ex);
   end Append_Message;

   procedure Append_Compaction
     (Session_Id       : String;
      Summary          : String;
      First_Kept_Index : Natural;
      Tokens_Before    : Natural)
   is
      Path         : constant String := Session_File_Path (Session_Id);
      Record_Value : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
   begin
      if Path'Length = 0 then
         raise Session_Error
           with "Append_Compaction: session file not found for " & Session_Id;
      end if;

      Record_Value.Set_Field ("type", "compaction");
      Record_Value.Set_Field ("summary", Summary);
      Record_Value.Set_Field
        ("firstKeptMessageIndex", Integer (First_Kept_Index));
      Record_Value.Set_Field ("tokensBefore", Integer (Tokens_Before));

      Write_Raw_Line
        (Path => Path,
         Line => GNATCOLL.JSON.Write (Record_Value),
         Mode => Ada.Streams.Stream_IO.Append_File);
   exception
      when Session_Error =>
         raise;
      when Ex : others   =>
         raise Session_Error
           with "Append_Compaction failed: "
           & Ada.Exceptions.Exception_Message (Ex);
   end Append_Compaction;

   procedure Append_Model_Change
     (Session_Id : String; Provider : String; Model_Id : String)
   is
      Path         : constant String := Session_File_Path (Session_Id);
      Record_Value : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
   begin
      if Path'Length = 0 then
         raise Session_Error
           with "Append_Model_Change: session file not found for "
           & Session_Id;
      end if;

      Record_Value.Set_Field ("type", "model_change");
      Record_Value.Set_Field ("provider", Provider);
      Record_Value.Set_Field ("modelId", Model_Id);

      Write_Raw_Line
        (Path => Path,
         Line => GNATCOLL.JSON.Write (Record_Value),
         Mode => Ada.Streams.Stream_IO.Append_File);
   exception
      when Session_Error =>
         raise;
      when Ex : others   =>
         raise Session_Error
           with "Append_Model_Change failed: "
           & Ada.Exceptions.Exception_Message (Ex);
   end Append_Model_Change;

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
            return Get_String_Field (Parsed.Value, "workDir",
                                     Get_String_Field (Parsed.Value, "cwd"));
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

   function Session_Created_At (Session_Id : String) return String is
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
         if Parsed.Success and then Parsed.Value.Has_Field ("createdAt")
           and then Parsed.Value.Get ("createdAt").Kind
             = GNATCOLL.JSON.JSON_Int_Type
         then
            declare
               use Ada.Calendar;
               Epoch      : constant Ada.Calendar.Time :=
                 Ada.Calendar.Formatting.Value
                   ("1970-01-01 00:00:00",
                    Ada.Calendar.Time_Zones.Time_Offset (0));
               Created_Ms : constant Long_Integer      :=
                 Parsed.Value.Get ("createdAt").Get;
               Created    : constant Ada.Calendar.Time :=
                 Epoch + Duration (Long_Float (Created_Ms) / 1_000.0);
            begin
               return
                 Ada.Calendar.Formatting.Local_Image
                   (Created, Include_Time_Fraction => False);
            end;
         elsif Parsed.Success then
            return Get_String_Field (Parsed.Value, "timestamp");
         end if;
      end;
      return "";
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         return "";
   end Session_Created_At;

   function Session_Sandbox_Profile (Session_Id : String) return String is
      Path : constant String := Session_File_Path (Session_Id);
      File : Ada.Text_IO.File_Type;
   begin
      if Path'Length = 0 or else not Ada.Directories.Exists (Path) then
         return "";
      end if;

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);

      declare
         Line    : constant String := To_String (Read_Line (File));
         Parsed  : constant GNATCOLL.JSON.Read_Result :=
           GNATCOLL.JSON.Read (Line);
         Profile : constant String                    :=
           (if
              Parsed.Success
            then
              Get_String_Field (Parsed.Value, "sandboxProfile")
            else "");
      begin
         Ada.Text_IO.Close (File);
         return Profile;
      end;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         return "";
   end Session_Sandbox_Profile;

   function Load_Messages
     (Session_Id : String) return LLM.Types.Message_Vectors.Vector
   is
      Path               : constant String := Session_File_Path (Session_Id);
      Result             : LLM.Types.Message_Vectors.Vector;
      File               : Ada.Text_IO.File_Type;
      Line_N             : Natural         := 0;
      Current_Provider   : Unbounded_String;
      Current_Model      : Unbounded_String;
      Strict             : Boolean := False;
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

            if Line_N = 1 then
               declare
                  Header : constant GNATCOLL.JSON.Read_Result := GNATCOLL.JSON.Read (Line);
               begin
                  --  A legacy reader may skip malformed historical lines.
                  --  Coyote-written v3 logs must never silently lose a turn.
                  Strict := Header.Success and then
                    Get_Natural_Field (Header.Value, "version") = 3;
               end;
            elsif Line'Length = 0 then
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
                        Record_Type : constant String                   :=
                          Get_String_Field (Envelope, "type");
                        Msg         : constant GNATCOLL.JSON.JSON_Value :=
                          Message_Object (Envelope);
                        Role        : constant String                   :=
                          Get_String_Field (Msg, "role");
                     begin
                        if Record_Type = "compaction" then
                           declare
                              Tail : LLM.Types.Message_Vectors.Vector;
                              First_Kept : Natural := Get_Natural_Field
                                (Envelope, "firstKeptMessageIndex");
                           begin
                              if First_Kept = 0 and then not Result.Is_Empty
                                and then Result.First_Element.Role = LLM.Types.Compaction_Summary
                              then
                                 First_Kept := 1;
                              end if;
                              Tail.Append (Compaction_Summary_Message
                                (Get_String_Field (Envelope, "summary")));
                              Append_Kept_Messages (Tail, Result, First_Kept);
                              LLM.Types.Message_Vectors.Move (Result, Tail);
                           end;
                        elsif Record_Type = "model_change" then
                           Current_Provider :=
                             To_Unbounded_String
                               (Get_String_Field (Envelope, "provider"));
                           Current_Model    :=
                             To_Unbounded_String
                               (Get_String_Field (Envelope, "modelId"));
                        elsif Msg.Kind = GNATCOLL.JSON.JSON_Object_Type then
                           declare
                              Parsed_Message : constant LLM.Types.Message :=
                                (if
                                   Role = "user"
                                 then
                                   Parse_User_Message (Envelope, Msg)
                                 elsif
                                   Role = "assistant"
                                 then
                                   Parse_Assistant_Message
                                     (Envelope,
                                      Msg,
                                      To_String (Current_Provider),
                                      To_String (Current_Model))
                                 elsif
                                   Role = "toolResult"
                                 then
                                   Parse_Tool_Result_Message (Envelope, Msg)
                                 else (Role   => LLM.Types.User,
                                    Content   =>
                                      LLM.Types.Content_Block_Vectors
                                        .Empty_Vector,
                                    Tok_Usage =>
                                      (others => 0),
                                    Stop      => LLM.Types.Unknown_Stop,
                                    Timestamp => Null_Unbounded_String));
                           begin
                              if Role = "user" or else Role = "assistant"
                                or else Role = "toolResult"
                              then
                                 Result.Append (Parsed_Message);
                              end if;
                           end;
                        end if;
                     end;
                  elsif Strict then
                     raise Session_Error with "Invalid JSONL line in Canvas session";
                  end if;
               end;
            end if;
         end;
      end loop;

      Ada.Text_IO.Close (File);

      return Result;
   exception
      when Ex : others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         raise Session_Error with "Cannot replay session: " & Ada.Exceptions.Exception_Message (Ex);
   end Load_Messages;

end LLM.Session_Store;
