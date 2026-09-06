with AUnit.Assertions;
with Ada.Containers;
with AUnit.Test_Caller;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with LLM.Types;

package body LLM_Types_Tests is

   use AUnit.Assertions;
   use LLM.Types;
   use type Ada.Containers.Count_Type;

   procedure Test_Text_Block (T : in out Test) is
      pragma Unreferenced (T);

      Block : constant Content_Block :=
        (Kind => Text_Block,
         Text => To_Unbounded_String ("hello"));
   begin
      Assert (To_String (Block.Text) = "hello", "Text should round-trip");
   end Test_Text_Block;

   procedure Test_Thinking_Block (T : in out Test) is
      pragma Unreferenced (T);

      Block : constant Content_Block :=
        (Kind            => Thinking_Block,
         Thinking        => To_Unbounded_String ("step by step"),
         Signature       => Null_Unbounded_String,
         Origin_Provider => To_Unbounded_String ("openrouter"),
         Origin_Model    => To_Unbounded_String ("test-model"));
   begin
      Assert
        (To_String (Block.Thinking) = "step by step",
         "Thinking text should round-trip");
   end Test_Thinking_Block;

   procedure Test_Tool_Call_Block (T : in out Test) is
      pragma Unreferenced (T);

      Block : constant Content_Block :=
        (Kind           => Tool_Call_Block,
         Tool_Call_Id   => To_Unbounded_String ("call-1"),
         Tool_Name      => To_Unbounded_String ("read"),
         Arguments_Json => To_Unbounded_String ("{""path"":""foo.adb""}"));
   begin
      Assert
        (To_String (Block.Tool_Call_Id) = "call-1",
         "Tool call id should round-trip");
      Assert
        (To_String (Block.Tool_Name) = "read",
         "Tool name should round-trip");
      Assert
        (To_String (Block.Arguments_Json) = "{""path"":""foo.adb""}",
         "Arguments JSON should round-trip");
   end Test_Tool_Call_Block;

   procedure Test_Tool_Result_Block (T : in out Test) is
      pragma Unreferenced (T);

      Block : constant Content_Block :=
        (Kind        => Tool_Result_Block,
         Result_Id   => To_Unbounded_String ("call-1"),
         Result_Text => To_Unbounded_String ("file contents"),
         Media_Type  => Null_Unbounded_String,
         Is_Error    => True);
   begin
      Assert
        (To_String (Block.Result_Id) = "call-1",
         "Result id should round-trip");
      Assert
        (To_String (Block.Result_Text) = "file contents",
         "Result text should round-trip");
      Assert (Block.Is_Error, "Is_Error should round-trip");
   end Test_Tool_Result_Block;

   procedure Test_Compaction_Summary_Role (T : in out Test) is
      pragma Unreferenced (T);

      Content : Content_Block_Vectors.Vector;
      Msg     : Message;
   begin
      Content.Append
        ((Kind => Text_Block,
          Text => To_Unbounded_String ("Checkpoint summary text")));

      Msg :=
        (Role      => Compaction_Summary,
         Content   => Content,
         Tok_Usage => (others => 0),
         Stop      => Unknown_Stop,
         Timestamp => To_Unbounded_String ("2026-05-02T12:00:00Z"));

      Assert
        (Msg.Role = Compaction_Summary,
         "Compaction summary messages should preserve their role");
      Assert
        (To_String (Msg.Content.Element (0).Text) = "Checkpoint summary text",
         "Compaction summary text should round-trip");
   end Test_Compaction_Summary_Role;

   procedure Test_Usage_Addition (T : in out Test) is
      pragma Unreferenced (T);

      Left  : constant Usage :=
        (Input => 10, Output => 20, Cache_Read => 3, Cache_Write => 4,
         Thinking => 0);
      Right : constant Usage :=
        (Input => 1, Output => 2, Cache_Read => 30, Cache_Write => 40,
         Thinking => 0);
      Sum   : constant Usage := Left + Right;
   begin
      Assert (Sum.Input = 11, "Input counts should add");
      Assert (Sum.Output = 22, "Output counts should add");
      Assert (Sum.Cache_Read = 33, "Cache_Read counts should add");
      Assert (Sum.Cache_Write = 44, "Cache_Write counts should add");
   end Test_Usage_Addition;

   procedure Test_Message_Vectors (T : in out Test) is
      pragma Unreferenced (T);

      Messages          : Message_Vectors.Vector;
      User_Content      : Content_Block_Vectors.Vector;
      Assistant_Content : Content_Block_Vectors.Vector;
      First             : Message;
      Second            : Message;
   begin
      User_Content.Append
        ((Kind => Text_Block,
          Text => To_Unbounded_String ("Hello")));
      Assistant_Content.Append
        ((Kind => Text_Block,
          Text => To_Unbounded_String ("Hi there")));

      First :=
        (Role      => User,
         Content   => User_Content,
         Tok_Usage => (Input => 1, Output => 0, Cache_Read => 0,
                       Cache_Write => 0, Thinking => 0),
         Stop      => Stop,
         Timestamp => To_Unbounded_String ("2026-05-02T12:00:00Z"));
      Second :=
        (Role      => Assistant,
         Content   => Assistant_Content,
         Tok_Usage => (Input => 4, Output => 7, Cache_Read => 0,
                       Cache_Write => 0, Thinking => 0),
         Stop      => Length,
         Timestamp => To_Unbounded_String ("2026-05-02T12:00:01Z"));
      Messages.Append (First);
      Messages.Append (Second);

      Assert (Messages.Length = 2, "Two messages should be appended");
      Assert
        (Messages.Element (0).Role = User,
         "First message role should be User");
      Assert
        (To_String (Messages.Element (0).Content.Element (0).Text) = "Hello",
         "First message content should round-trip");
      Assert
        (Messages.Element (1).Role = Assistant,
         "Second message role should be Assistant");
      Assert
        (Messages.Element (1).Tok_Usage.Output = 7,
         "Second message usage should round-trip");
      Assert
        (Messages.Element (1).Stop = Length,
         "Second message stop reason should round-trip");
   end Test_Message_Vectors;

   procedure Test_Tool_Result_Block_Media_Type (T : in out Test) is
      pragma Unreferenced (T);

      Block : constant Content_Block :=
        (Kind        => Tool_Result_Block,
         Result_Id   => To_Unbounded_String ("call-2"),
         Result_Text => To_Unbounded_String ("SGVsbG8="),
         Media_Type  => To_Unbounded_String ("image/png"),
         Is_Error    => False);
   begin
      Assert
        (To_String (Block.Result_Id) = "call-2",
         "Result_Id should round-trip");
      Assert
        (To_String (Block.Result_Text) = "SGVsbG8=",
         "Result_Text should round-trip");
      Assert
        (To_String (Block.Media_Type) = "image/png",
         "Media_Type should round-trip");
      Assert
        (not Block.Is_Error,
         "Is_Error should be False");
   end Test_Tool_Result_Block_Media_Type;

   package LLM_Types_Caller is
     new AUnit.Test_Caller (LLM_Types_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (LLM_Types_Caller.Create
        ("LLM.Types text block stores text content",
         LLM_Types_Tests.Test_Text_Block'Access));
      Result.Add_Test (LLM_Types_Caller.Create
        ("LLM.Types thinking block stores thinking content",
         LLM_Types_Tests.Test_Thinking_Block'Access));
      Result.Add_Test (LLM_Types_Caller.Create
        ("LLM.Types tool-call block stores id/name/arguments",
         LLM_Types_Tests.Test_Tool_Call_Block'Access));
      Result.Add_Test (LLM_Types_Caller.Create
        ("LLM.Types tool-result block stores result and error flag",
         LLM_Types_Tests.Test_Tool_Result_Block'Access));
      Result.Add_Test (LLM_Types_Caller.Create
        ("LLM.Types tool-result block stores Media_Type field",
         LLM_Types_Tests.Test_Tool_Result_Block_Media_Type'Access));
      Result.Add_Test (LLM_Types_Caller.Create
        ("LLM.Types compaction summary messages preserve role and text",
         LLM_Types_Tests.Test_Compaction_Summary_Role'Access));
      Result.Add_Test (LLM_Types_Caller.Create
        ("LLM.Types usage values add field-by-field",
         LLM_Types_Tests.Test_Usage_Addition'Access));
      Result.Add_Test (LLM_Types_Caller.Create
        ("LLM.Types message vectors append and preserve values",
         LLM_Types_Tests.Test_Message_Vectors'Access));

      return Result;
   end Suite;

end LLM_Types_Tests;
