--  LLM.Types — core conversation data types for native providers.
--
--  These types represent messages, content blocks, usage counters, and
--  related metadata shared by all LLM provider adapters.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

package LLM.Types is

   --  Conversation role for one message in the transcript.
   type Role is (User, Assistant, Tool_Result, Compaction_Summary);

   --  Terminal status retained for a tool result.  Older session files omit
   --  this value and are reconstructed from Is_Error by the store.
   type Tool_Result_Status is (Result_Success, Result_Error,
                               Result_Timed_Out, Result_Cancelled);

   --  Variant kind for one content block inside a message.
   type Content_Block_Kind is
     (Text_Block,
      Thinking_Block,
      Tool_Call_Block,
      Tool_Result_Block);

   --  One structured content block within a message.
   type Content_Block (Kind : Content_Block_Kind := Text_Block) is record
      case Kind is
         when Text_Block =>
            Text : Ada.Strings.Unbounded.Unbounded_String;
         when Thinking_Block =>
            Thinking        : Ada.Strings.Unbounded.Unbounded_String;
            Signature       : Ada.Strings.Unbounded.Unbounded_String;
            --  Provider/model identity that owns opaque Signature state.
            Origin_Provider : Ada.Strings.Unbounded.Unbounded_String :=
              Ada.Strings.Unbounded.Null_Unbounded_String;
            Origin_Model    : Ada.Strings.Unbounded.Unbounded_String :=
              Ada.Strings.Unbounded.Null_Unbounded_String;
         when Tool_Call_Block =>
            Tool_Call_Id   : Ada.Strings.Unbounded.Unbounded_String;
            Tool_Name      : Ada.Strings.Unbounded.Unbounded_String;
            Arguments_Json : Ada.Strings.Unbounded.Unbounded_String;
         when Tool_Result_Block =>
            Result_Id   : Ada.Strings.Unbounded.Unbounded_String;
            Result_Text : Ada.Strings.Unbounded.Unbounded_String;
            Media_Type  : Ada.Strings.Unbounded.Unbounded_String;
            Is_Error    : Boolean := False;
            Status      : Tool_Result_Status := Result_Success;
      end case;
   end record;

   package Content_Block_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Content_Block);

   --  Token-usage counters reported by the provider.
   type Usage is record
      Input       : Natural := 0;
      Output      : Natural := 0;
      Cache_Read  : Natural := 0;
      Cache_Write : Natural := 0;
      Thinking    : Natural := 0;  --  Thinking/reasoning tokens (estimated for Anthropic)
   end record;

   --  Add two usage values field-by-field.
   function "+" (Left : Usage; Right : Usage) return Usage;

   --  Provider stop reason for a message or turn.
   type Stop_Reason is
     (Stop,
      Length,
      Tool_Use,
      Aborted,
      Error_Stop,
      Unknown_Stop);

   --  Per-million-token cost information for a model.
   type Model_Cost is record
      Input       : Long_Float := 0.0;
      Output      : Long_Float := 0.0;
      Cache_Read  : Long_Float := 0.0;
      Cache_Write : Long_Float := 0.0;
   end record;

   --  One complete conversation message.
   --  Timestamp stores the raw ISO-8601 string used by session files and
   --  provider APIs.
   type Message is record
      Role      : LLM.Types.Role := User;
      Content   : Content_Block_Vectors.Vector;
      Tok_Usage : Usage := (others => 0);
      Stop      : Stop_Reason := Unknown_Stop;
      Timestamp : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   package Message_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Message);

end LLM.Types;
