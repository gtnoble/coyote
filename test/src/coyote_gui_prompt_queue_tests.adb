with AUnit.Assertions;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Coyote_GUI.Prompt_Queue;
with LLM.Providers;
use type LLM.Providers.Thinking_Level;

package body Coyote_GUI_Prompt_Queue_Tests is

   use AUnit.Assertions;
   use Coyote_GUI.Prompt_Queue;

   procedure Test_Set_Preferences_Round_Trips (T : in out Test) is
      pragma Unreferenced (T);
      Queue : Coyote_GUI.Prompt_Queue.Queue;
      Got   : Coyote_GUI.Prompt_Queue.Item;
   begin
      Queue.Enqueue
        ((Kind => Set_Preferences,
          Preferences =>
            (Provider => To_Unbounded_String ("openrouter"),
             Model_Id => To_Unbounded_String ("test/model"),
             Thinking          => LLM.Providers.High,
             Sandbox           => To_Unbounded_String ("restricted"),
             Subagent_Provider        => To_Unbounded_String ("openrouter"),
             Subagent_Model           => To_Unbounded_String ("test/fast-model"),
             Completion_Notifications =>
               False)));
      Queue.Dequeue (Got);

      Assert (Got.Kind = Set_Preferences,
              "preference item kind should survive queue transport");
      Assert (To_String (Got.Preferences.Provider) = "openrouter",
              "provider should survive queue transport");
      Assert (To_String (Got.Preferences.Model_Id) = "test/model",
              "model ID should survive queue transport");
      Assert (Got.Preferences.Thinking = LLM.Providers.High,
              "thinking level should survive queue transport");
      Assert (To_String (Got.Preferences.Sandbox) = "restricted",
              "sandbox profile should survive queue transport");
      Assert (To_String (Got.Preferences.Subagent_Provider) = "openrouter",
              "subagent provider should survive queue transport");
      Assert
        (To_String (Got.Preferences.Subagent_Model) = "test/fast-model",
         "subagent model should survive queue transport");
      Assert
        (not Got.Preferences.Completion_Notifications,
         "disabled completion preference should survive queue transport");

      Queue.Enqueue
        ((Kind => Set_Preferences,
          Preferences =>
            (Provider          => Null_Unbounded_String,
             Model_Id          => Null_Unbounded_String,
             Thinking          => LLM.Providers.Off,
             Sandbox           => Null_Unbounded_String,
             Subagent_Provider        => Null_Unbounded_String,
             Subagent_Model           => Null_Unbounded_String,
             Completion_Notifications => True)));
      Queue.Dequeue (Got);
      Assert (Length (Got.Preferences.Provider) = 0,
              "empty provider should represent an explicit clear");
      Assert (Length (Got.Preferences.Model_Id) = 0,
              "empty model should represent an explicit clear");
      Assert (Length (Got.Preferences.Sandbox) = 0,
              "empty sandbox should represent an explicit clear");
      Assert (Length (Got.Preferences.Subagent_Provider) = 0,
              "empty subagent provider should represent an explicit clear");
      Assert (Length (Got.Preferences.Subagent_Model) = 0,
              "empty subagent model should represent an explicit clear");
   end Test_Set_Preferences_Round_Trips;

   procedure Test_Enqueue_Reports_Acceptance (T : in out Test) is
      pragma Unreferenced (T);
      Queue    : Coyote_GUI.Prompt_Queue.Queue;
      Accepted : Boolean;
      Got      : Coyote_GUI.Prompt_Queue.Item;
   begin
      Queue.Enqueue
        ((Kind => User_Prompt, Text => To_Unbounded_String ("hello")),
         Accepted);
      Assert (Accepted, "available queue should accept an item");
      Queue.Dequeue (Got);
      Assert (To_String (Got.Text) = "hello",
              "accepted prompt should be delivered");
   end Test_Enqueue_Reports_Acceptance;

   procedure Test_Enqueue_Rejects_Overflow (T : in out Test) is
      pragma Unreferenced (T);
      Queue    : Coyote_GUI.Prompt_Queue.Queue;
      Accepted : Boolean;
   begin
      for I in 1 .. Max_Depth loop
         Queue.Enqueue
           ((Kind => User_Prompt,
             Text => To_Unbounded_String ("prompt")), Accepted);
         Assert (Accepted, "queue should accept items through capacity");
      end loop;
      Queue.Enqueue
        ((Kind => User_Prompt, Text => To_Unbounded_String ("lost")),
         Accepted);
      Assert (not Accepted, "full queue should reject an item");
   end Test_Enqueue_Rejects_Overflow;

end Coyote_GUI_Prompt_Queue_Tests;
