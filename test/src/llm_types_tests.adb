with AUnit.Assertions;
with Ada.Containers;
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
        (Kind      => Thinking_Block,
         Thinking  => To_Unbounded_String ("step by step"),
         Signature => Null_Unbounded_String);
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
        (Input => 10, Output => 20, Cache_Read => 3, Cache_Write => 4);
      Right : constant Usage :=
        (Input => 1, Output => 2, Cache_Read => 30, Cache_Write => 40);
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
                       Cache_Write => 0),
         Stop      => Stop,
         Timestamp => To_Unbounded_String ("2026-05-02T12:00:00Z"));
      Second :=
        (Role      => Assistant,
         Content   => Assistant_Content,
         Tok_Usage => (Input => 4, Output => 7, Cache_Read => 0,
                       Cache_Write => 0),
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

end LLM_Types_Tests;
