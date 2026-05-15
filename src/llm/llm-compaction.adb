--  LLM.Compaction body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with GNATCOLL.JSON;

package body LLM.Compaction is

   use type GNATCOLL.JSON.JSON_Value_Type;
   use type LLM.Types.Content_Block_Kind;
   use type LLM.Types.Role;

   function Usage_Total (Value : LLM.Types.Usage) return Natural is
   begin
      return
        Value.Input
        + Value.Output
        + Value.Cache_Read
        + Value.Cache_Write;
   end Usage_Total;

   function Ceil_Quarter (Chars : Natural) return Natural is
   begin
      if Chars = 0 then
         return 0;
      elsif Chars mod 4 = 0 then
         return Chars / 4;
      else
         return (Chars / 4) + 1;
      end if;
   end Ceil_Quarter;

   procedure Append_With_Separator
     (Target    : in out Unbounded_String;
      Fragment  : String;
      Separator : String)
   is
   begin
      if Fragment'Length = 0 then
         return;
      end if;

      if Length (Target) > 0 then
         Append (Target, Separator);
      end if;

      Append (Target, Fragment);
   end Append_With_Separator;

   procedure Append_Line
     (Target : in out Unbounded_String;
      Line   : String) is
   begin
      Append_With_Separator
        (Target    => Target,
         Fragment  => Line,
         Separator => "" & ASCII.LF);
   end Append_Line;

   function Scalar_Image (Value : GNATCOLL.JSON.JSON_Value) return String is
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_String_Type then
         return Value.Get;
      end if;

      return GNATCOLL.JSON.Write (Value);
   end Scalar_Image;

   function Render_Tool_Call
     (Block : LLM.Types.Content_Block) return String
   is
      Tool_Name : constant String := To_String (Block.Tool_Name);
      Raw_Args  : constant String := To_String (Block.Arguments_Json);
      Parsed    : constant GNATCOLL.JSON.Read_Result :=
        GNATCOLL.JSON.Read (Raw_Args);
      Fields    : Unbounded_String;
      First     : Boolean := True;

      procedure Collect_Field
        (Name  : GNATCOLL.JSON.UTF8_String;
         Value : GNATCOLL.JSON.JSON_Value)
      is
      begin
         if not First then
            Append (Fields, ", ");
         end if;

         First := False;
         Append (Fields, Name);
         Append (Fields, "=");
         Append (Fields, Scalar_Image (Value));
      end Collect_Field;
   begin
      if Parsed.Success
        and then Parsed.Value.Kind = GNATCOLL.JSON.JSON_Object_Type
      then
         Parsed.Value.Map_JSON_Object (Collect_Field'Access);
         return Tool_Name & "(" & To_String (Fields) & ")";
      elsif Raw_Args'Length > 0 then
         return Tool_Name & "(" & Raw_Args & ")";
      else
         return Tool_Name & "()";
      end if;
   end Render_Tool_Call;

   function Truncate (Text : String; Max_Length : Natural) return String is
   begin
      if Text'Length <= Max_Length then
         return Text;
      elsif Max_Length = 0 then
         return "";
      else
         return Text (Text'First .. Text'First + Max_Length - 1);
      end if;
   end Truncate;

   function Estimate_Tokens (Msg : LLM.Types.Message) return Natural is
      Characters : Natural := 0;
   begin
      for Block of Msg.Content loop
         case Block.Kind is
            when LLM.Types.Text_Block =>
               Characters := Characters + Length (Block.Text);
            when LLM.Types.Thinking_Block =>
               Characters := Characters + Length (Block.Thinking);
            when LLM.Types.Tool_Call_Block =>
               Characters := Characters + Length (Block.Arguments_Json);
            when LLM.Types.Tool_Result_Block =>
               Characters := Characters + Length (Block.Result_Text);
         end case;
      end loop;

      return Ceil_Quarter (Characters);
   end Estimate_Tokens;

   function Estimate_Context_Tokens
     (History : LLM.Types.Message_Vectors.Vector) return Natural
   is
      Sum : Natural := 0;
   begin
      if not History.Is_Empty then
         for I in reverse History.First_Index .. History.Last_Index loop
            declare
               Msg : constant LLM.Types.Message := History.Element (I);
            begin
               if Msg.Role = LLM.Types.Assistant then
                  declare
                     Actual_Used : constant Natural :=
                       Usage_Total (Msg.Tok_Usage);
                  begin
                     if Actual_Used > 0 then
                        return Actual_Used;
                     end if;

                     exit;
                  end;
               end if;
            end;
         end loop;
      end if;

      for Msg of History loop
         Sum := Sum + Estimate_Tokens (Msg);
      end loop;

      return Sum;
   end Estimate_Context_Tokens;

   function Should_Compact
     (Context_Tokens : Natural;
      Context_Window : Natural;
      Settings       : Compact_Settings) return Boolean
   is
      Threshold : constant Natural :=
        (if Context_Window > Natural (Settings.Reserve_Tokens)
         then Context_Window - Natural (Settings.Reserve_Tokens)
         else 0);
   begin
      return Settings.Enabled and then Context_Tokens >= Threshold;
   end Should_Compact;

   function Find_Cut_Point
     (History  : LLM.Types.Message_Vectors.Vector;
      Settings : Compact_Settings) return Natural
   is
      Accumulated     : Natural := 0;
      Threshold_Index : Natural := 0;
      Found_Threshold : Boolean := False;
   begin
      if History.Is_Empty then
         return 0;
      end if;

      for I in reverse History.First_Index .. History.Last_Index loop
         Accumulated := Accumulated + Estimate_Tokens (History.Element (I));
         if Accumulated >= Natural (Settings.Keep_Recent_Tokens) then
            Threshold_Index := I;
            Found_Threshold := True;
            exit;
         end if;
      end loop;

      if not Found_Threshold then
         return 0;
      end if;

      for I in reverse History.First_Index .. Threshold_Index loop
         if History.Element (I).Role = LLM.Types.User then
            if I = History.First_Index then
               return 0;
            else
               return I;
            end if;
         end if;
      end loop;

      return 0;
   end Find_Cut_Point;

   function Serialize_Conversation
     (Messages : LLM.Types.Message_Vectors.Vector) return String
   is
      Result : Unbounded_String;
   begin
      for Msg of Messages loop
         declare
            Serialized : Unbounded_String;
         begin
            if Msg.Role = LLM.Types.User then
               declare
                  Text : Unbounded_String;
               begin
                  for Block of Msg.Content loop
                     if Block.Kind = LLM.Types.Text_Block then
                        Append_With_Separator
                          (Target    => Text,
                           Fragment  => To_String (Block.Text),
                           Separator => "" & ASCII.LF);
                     end if;
                  end loop;

                  Append_Line
                    (Serialized,
                     "[User]: " & To_String (Text));
               end;
            elsif Msg.Role = LLM.Types.Assistant then
               declare
                  Assistant_Text     : Unbounded_String;
                  Assistant_Thinking : Unbounded_String;
                  Tool_Calls         : Unbounded_String;
               begin
                  for Block of Msg.Content loop
                     case Block.Kind is
                        when LLM.Types.Text_Block =>
                           Append_With_Separator
                             (Target    => Assistant_Text,
                              Fragment  => To_String (Block.Text),
                              Separator => "" & ASCII.LF);
                        when LLM.Types.Thinking_Block =>
                           Append_With_Separator
                             (Target    => Assistant_Thinking,
                              Fragment  => To_String (Block.Thinking),
                              Separator => "" & ASCII.LF);
                        when LLM.Types.Tool_Call_Block =>
                           Append_With_Separator
                             (Target    => Tool_Calls,
                              Fragment  => Render_Tool_Call (Block),
                              Separator => "; ");
                        when others =>
                           null;
                     end case;
                  end loop;

                  if Length (Assistant_Text) > 0 then
                     Append_Line
                       (Serialized,
                        "[Assistant]: " & To_String (Assistant_Text));
                  end if;

                  if Length (Assistant_Thinking) > 0 then
                     Append_Line
                       (Serialized,
                        "[Assistant thinking]: "
                        & To_String (Assistant_Thinking));
                  end if;

                  if Length (Tool_Calls) > 0 then
                     Append_Line
                       (Serialized,
                        "[Assistant tool calls]: " & To_String (Tool_Calls));
                  end if;
               end;
            elsif LLM.Types.Role'Image (Msg.Role) = "COMPACTION_SUMMARY" then
               declare
                  Text : Unbounded_String;
               begin
                  for Block of Msg.Content loop
                     if Block.Kind = LLM.Types.Text_Block then
                        Append_With_Separator
                          (Target    => Text,
                           Fragment  => To_String (Block.Text),
                           Separator => "" & ASCII.LF);
                     end if;
                  end loop;

                  Append_Line
                    (Serialized,
                     "[Summary]: " & To_String (Text));
               end;
            else
               declare
                  Tool_Result : Unbounded_String;
               begin
                  for Block of Msg.Content loop
                     case Block.Kind is
                        when LLM.Types.Tool_Result_Block =>
                           Append_With_Separator
                             (Target    => Tool_Result,
                              Fragment  => To_String (Block.Result_Text),
                              Separator => "" & ASCII.LF);
                        when LLM.Types.Text_Block =>
                           Append_With_Separator
                             (Target    => Tool_Result,
                              Fragment  => To_String (Block.Text),
                              Separator => "" & ASCII.LF);
                        when others =>
                           null;
                     end case;
                  end loop;

                  Append_Line
                    (Serialized,
                     "[Tool result]: "
                     & Truncate (To_String (Tool_Result), 2_000));
               end;
            end if;

            Append_With_Separator
              (Target    => Result,
               Fragment  => To_String (Serialized),
               Separator => ASCII.LF & ASCII.LF);
         end;
      end loop;

      return To_String (Result);
   end Serialize_Conversation;

end LLM.Compaction;
