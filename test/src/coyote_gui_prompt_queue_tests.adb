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
             Thinking => LLM.Providers.High,
             Sandbox  => To_Unbounded_String ("restricted"))));
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

      Queue.Enqueue
        ((Kind => Set_Preferences,
          Preferences =>
            (Provider => Null_Unbounded_String,
             Model_Id => Null_Unbounded_String,
             Thinking => LLM.Providers.Off,
             Sandbox  => Null_Unbounded_String)));
      Queue.Dequeue (Got);
      Assert (Length (Got.Preferences.Provider) = 0,
              "empty provider should represent an explicit clear");
      Assert (Length (Got.Preferences.Model_Id) = 0,
              "empty model should represent an explicit clear");
      Assert (Length (Got.Preferences.Sandbox) = 0,
              "empty sandbox should represent an explicit clear");
   end Test_Set_Preferences_Round_Trips;

end Coyote_GUI_Prompt_Queue_Tests;
