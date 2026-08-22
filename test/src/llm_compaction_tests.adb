with AUnit.Assertions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with LLM.Compaction;
with LLM.Types;

package body LLM_Compaction_Tests is

   use AUnit.Assertions;
   use type LLM.Types.Content_Block_Kind;
   use type LLM.Types.Role;

   function Contains (Text : String; Pattern : String) return Boolean is
   begin
      return Ada.Strings.Fixed.Index (Text, Pattern) > 0;
   end Contains;

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

   function Make_Assistant_Text_Message
     (Text : String;
      Usage : LLM.Types.Usage := (others => 0);
      Stop  : LLM.Types.Stop_Reason := LLM.Types.Stop)
      return LLM.Types.Message
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
   end Make_Assistant_Text_Message;

   function Make_Assistant_Thinking_Tool_Message
     (Text          : String;
      Thinking      : String;
      Tool_Name     : String;
      Arguments_Json : String)
      return LLM.Types.Message
   is
      Content : LLM.Types.Content_Block_Vectors.Vector;
   begin
      Content.Append
        ((Kind => LLM.Types.Text_Block,
          Text => To_Unbounded_String (Text)));
      Content.Append
        ((Kind            => LLM.Types.Thinking_Block,
          Thinking        => To_Unbounded_String (Thinking),
          Signature       => Null_Unbounded_String,
          Origin_Provider => Null_Unbounded_String,
          Origin_Model    => Null_Unbounded_String));
      Content.Append
        ((Kind           => LLM.Types.Tool_Call_Block,
          Tool_Call_Id   => To_Unbounded_String ("call-1"),
          Tool_Name      => To_Unbounded_String (Tool_Name),
          Arguments_Json => To_Unbounded_String (Arguments_Json)));

      return
        (Role      => LLM.Types.Assistant,
         Content   => Content,
         Tok_Usage => (others => 0),
         Stop      => LLM.Types.Tool_Use,
         Timestamp => Null_Unbounded_String);
   end Make_Assistant_Thinking_Tool_Message;

   function Make_Assistant_Tool_Call_Message
     (Tool_Name      : String;
      Arguments_Json : String;
      Tool_Call_Id   : String := "call-1")
      return LLM.Types.Message
   is
      Content : LLM.Types.Content_Block_Vectors.Vector;
   begin
      Content.Append
        ((Kind           => LLM.Types.Tool_Call_Block,
          Tool_Call_Id   => To_Unbounded_String (Tool_Call_Id),
          Tool_Name      => To_Unbounded_String (Tool_Name),
          Arguments_Json => To_Unbounded_String (Arguments_Json)));

      return
        (Role      => LLM.Types.Assistant,
         Content   => Content,
         Tok_Usage => (others => 0),
         Stop      => LLM.Types.Tool_Use,
         Timestamp => Null_Unbounded_String);
   end Make_Assistant_Tool_Call_Message;

   function Make_Tool_Result_Message
     (Result_Text : String;
      Tool_Call_Id : String := "call-1") return LLM.Types.Message
   is
      Content : LLM.Types.Content_Block_Vectors.Vector;
   begin
      Content.Append
        ((Kind        => LLM.Types.Tool_Result_Block,
          Result_Id   => To_Unbounded_String (Tool_Call_Id),
          Result_Text => To_Unbounded_String (Result_Text),
          Media_Type  => Null_Unbounded_String,
          Is_Error    => False));

      return
        (Role      => LLM.Types.Tool_Result,
         Content   => Content,
         Tok_Usage => (others => 0),
         Stop      => LLM.Types.Unknown_Stop,
         Timestamp => Null_Unbounded_String);
   end Make_Tool_Result_Message;

   procedure Test_Estimate_Tokens (T : in out Test) is
      pragma Unreferenced (T);

      User_Msg : constant LLM.Types.Message :=
        Make_User_Message ("abcdefghi");
      Assistant_Msg : constant LLM.Types.Message :=
        Make_Assistant_Thinking_Tool_Message
          (Text           => "abcd",
           Thinking       => "efgh",
           Tool_Name      => "read",
           Arguments_Json => "{""path"":""x""}");
      Long_Result : constant String := (1 .. 2_003 => 'r');
      Result_Msg  : constant LLM.Types.Message :=
        Make_Tool_Result_Message (Long_Result);
   begin
      Assert
        (LLM.Compaction.Estimate_Tokens (User_Msg) = 3,
         "9 user chars should estimate to ceil(9/4)=3 tokens");
      Assert
        (LLM.Compaction.Estimate_Tokens (Assistant_Msg) = 5,
         "assistant text+thinking+tool JSON should use one ceil(total/4)");
      Assert
        (LLM.Compaction.Estimate_Tokens (Result_Msg) = 501,
         "tool-result estimation should count the full content length");
   end Test_Estimate_Tokens;

   procedure Test_Estimate_Context_Tokens (T : in out Test) is
      pragma Unreferenced (T);

      Empty_History : LLM.Types.Message_Vectors.Vector;
      Usage_History : LLM.Types.Message_Vectors.Vector;
      Sum_History   : LLM.Types.Message_Vectors.Vector;
   begin
      Assert
        (LLM.Compaction.Estimate_Context_Tokens (Empty_History) = 0,
         "empty histories should estimate to zero tokens");

      Usage_History.Append (Make_User_Message ("ignored because usage wins"));
      Usage_History.Append
        (Make_Assistant_Text_Message
           (Text  => "reply",
            Usage =>
              (Input => 11, Output => 7, Cache_Read => 3, Cache_Write => 2,
               Thinking => 0)));
      Assert
        (LLM.Compaction.Estimate_Context_Tokens (Usage_History) = 23,
         "non-zero assistant usage should override heuristic estimates");

      Sum_History.Append (Make_User_Message ("abcdefgh"));
      Sum_History.Append (Make_Assistant_Text_Message ("wxyz"));
      Assert
        (LLM.Compaction.Estimate_Context_Tokens (Sum_History) = 3,
         "histories without usage should sum message estimates");
   end Test_Estimate_Context_Tokens;

   procedure Test_Should_Compact (T : in out Test) is
      pragma Unreferenced (T);

      Disabled : constant LLM.Compaction.Compact_Settings :=
        (Enabled            => False,
         Reserve_Tokens     => 30,
         Keep_Recent_Tokens => 20, Consecutive_Failures => 0, Tripped => False);
      Enabled : constant LLM.Compaction.Compact_Settings :=
        (Enabled            => True,
         Reserve_Tokens     => 30,
         Keep_Recent_Tokens => 20, Consecutive_Failures => 0, Tripped => False);
   begin
      Assert
        (not LLM.Compaction.Should_Compact (70, 100, Disabled),
         "disabled compaction should never trigger");
      Assert
        (not LLM.Compaction.Should_Compact (69, 100, Enabled),
         "usage below the reserve threshold should not compact");
      Assert
        (LLM.Compaction.Should_Compact (70, 100, Enabled),
         "usage at the threshold should compact");
   end Test_Should_Compact;

   procedure Test_Find_Cut_Point (T : in out Test) is
      pragma Unreferenced (T);

      Short_History : LLM.Types.Message_Vectors.Vector;
      History       : LLM.Types.Message_Vectors.Vector;
      Short_Setting : constant LLM.Compaction.Compact_Settings :=
        (Enabled            => True,
         Reserve_Tokens     => 10,
         Keep_Recent_Tokens => 100, Consecutive_Failures => 0, Tripped => False);
      Keep_Last_Turn : constant LLM.Compaction.Compact_Settings :=
        (Enabled            => True,
         Reserve_Tokens     => 10,
         Keep_Recent_Tokens => 30, Consecutive_Failures => 0, Tripped => False);
      Keep_All : constant LLM.Compaction.Compact_Settings :=
        (Enabled            => True,
         Reserve_Tokens     => 10,
         Keep_Recent_Tokens => 200, Consecutive_Failures => 0, Tripped => False);
   begin
      Short_History.Append (Make_User_Message ("short"));
      Short_History.Append (Make_Assistant_Text_Message ("reply"));
      Assert
        (LLM.Compaction.Find_Cut_Point (Short_History, Short_Setting) = 0,
         "short histories should not be cut");

      History.Append (Make_User_Message ((1 .. 80 => 'a')));
      History.Append
        (Make_Assistant_Tool_Call_Message
           (Tool_Name      => "read",
            Arguments_Json => "{""path"":""src/old.adb""}"));
      History.Append (Make_Tool_Result_Message ((1 .. 80 => 'b')));
      History.Append (Make_Assistant_Text_Message ((1 .. 80 => 'c')));
      History.Append (Make_User_Message ((1 .. 80 => 'd')));
      History.Append (Make_Assistant_Text_Message ((1 .. 80 => 'e')));

      declare
         Cut : constant Natural :=
           LLM.Compaction.Find_Cut_Point (History, Keep_Last_Turn);
      begin
         Assert (Cut = 4, "cut should move back to the next user boundary");
         Assert
           (History.Element (Cut).Role = LLM.Types.User,
            "cut point should always start at a user message");
         Assert
           (Cut /= 2 and then Cut /= 3,
            "cut must not split a tool-call/tool-result exchange");
      end;

      Assert
        (LLM.Compaction.Find_Cut_Point (History, Keep_All) = 0,
         "large keep-recent budgets should keep the full history");
   end Test_Find_Cut_Point;

   procedure Test_Serialize_Conversation (T : in out Test) is
      pragma Unreferenced (T);

      Messages     : LLM.Types.Message_Vectors.Vector;
      Long_Result  : constant String := (1 .. 2_005 => 'x');
      Truncated    : constant String := (1 .. 2_000 => 'x');
      Serialized   : Unbounded_String;
   begin
      Messages.Append (Make_User_Message ("Review src/llm/llm-agent.adb"));
      Messages.Append
        (Make_Assistant_Thinking_Tool_Message
           (Text           => "I checked the file.",
            Thinking       => "Need to keep turn boundaries.",
            Tool_Name      => "read",
            Arguments_Json => "{""path"":""src/llm/llm-agent.adb""}"));
      Messages.Append (Make_Tool_Result_Message (Long_Result));

      Serialized :=
        To_Unbounded_String
          (LLM.Compaction.Serialize_Conversation (Messages));

      Assert
        (Contains
           (To_String (Serialized),
            "[User]: Review src/llm/llm-agent.adb"),
         "user messages should be labelled with [User]");
      Assert
        (Contains (To_String (Serialized), "[Assistant]: I checked the file."),
         "assistant text should be labelled with [Assistant]");
      Assert
        (Contains
           (To_String (Serialized),
            "[Assistant thinking]: Need to keep turn boundaries."),
         "assistant thinking should be labelled explicitly");
      Assert
        (Contains
           (To_String (Serialized),
            "[Assistant tool calls]: read(path=src/llm/llm-agent.adb)"),
         "assistant tool calls should render their names and arguments");
      Assert
        (Contains
           (To_String (Serialized),
            "[Tool result]: " & Truncated),
         "tool results should be truncated to 2000 characters");
      Assert
        (not Contains
           (To_String (Serialized),
            "[Tool result]: " & Long_Result),
         "serialisation should not include tool-result text past 2000 chars");
      Assert
        (Contains
           (To_String (Serialized),
            "[User]: Review src/llm/llm-agent.adb"
            & ASCII.LF & ASCII.LF
            & "[Assistant]: I checked the file."),
         "messages should be separated by one blank line");
   end Test_Serialize_Conversation;

   procedure Test_Full_Compaction_Candidate (T : in out Test) is
      pragma Unreferenced (T);

      History   : LLM.Types.Message_Vectors.Vector;
      Candidate : LLM.Types.Message_Vectors.Vector;
      Settings  : constant LLM.Compaction.Compact_Settings :=
        (Enabled            => True,
         Reserve_Tokens     => 100,
         Keep_Recent_Tokens => 30, Consecutive_Failures => 0, Tripped => False);
      Cut       : Natural;
      Text      : Unbounded_String;
   begin
      History.Append (Make_User_Message ((1 .. 80 => 'u')));
      History.Append
        (Make_Assistant_Tool_Call_Message
           (Tool_Name      => "read",
            Arguments_Json => "{""path"":""src/demo.adb""}"));
      History.Append (Make_Tool_Result_Message ((1 .. 80 => 'r')));
      History.Append (Make_Assistant_Text_Message ((1 .. 80 => 'a')));
      History.Append (Make_User_Message ((1 .. 80 => 'n')));
      History.Append (Make_Assistant_Text_Message ((1 .. 80 => 'z')));

      Cut := LLM.Compaction.Find_Cut_Point (History, Settings);
      Assert (Cut = 4, "the realistic history should keep the newest turn");

      for I in History.First_Index .. Cut - 1 loop
         Candidate.Append (History.Element (I));
      end loop;

      Text :=
        To_Unbounded_String
          (LLM.Compaction.Serialize_Conversation (Candidate));

      Assert
        (Contains (To_String (Text), "[User]:"),
         "serialised candidate should include user labels");
      Assert
        (Contains (To_String (Text), "[Assistant tool calls]: read("),
         "serialised candidate should include assistant tool calls");
      Assert
        (Contains (To_String (Text), "[Tool result]:"),
         "serialised candidate should include tool-result labels");
      Assert
        (Contains (To_String (Text), "[Assistant]:"),
         "serialised candidate should include assistant text labels");
   end Test_Full_Compaction_Candidate;

end LLM_Compaction_Tests;
