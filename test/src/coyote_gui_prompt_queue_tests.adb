with AUnit.Assertions;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Coyote_GUI.Prompt_Queue;
with LLM.Providers;
with LLM.Settings;
with Ada.Containers;
use type LLM.Providers.Thinking_Level;
use type Ada.Containers.Count_Type;

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
          Target_Agent_Id => Null_Unbounded_String,
          Preferences =>
            (Provider => To_Unbounded_String ("openrouter"),
             Model_Id => To_Unbounded_String ("test/model"),
             Thinking          => LLM.Providers.High,
             Sandbox           => To_Unbounded_String ("restricted"),
             Subagent_Provider        => To_Unbounded_String ("openrouter"),
             Subagent_Model           => To_Unbounded_String
               ("test/fast-model"),
             Max_Recursion_Depth      => 3,
             Termination_Grace_Seconds => 7,
             Completion_Notifications =>
               False,
             Price_Display => LLM.Settings.Decibels,
             Skill_Paths =>
               LLM.Settings.String_Vectors.Empty_Vector)));
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
        (Got.Preferences.Max_Recursion_Depth = 3,
         "recursion depth should survive queue transport");
      Assert
        (Got.Preferences.Termination_Grace_Seconds = 7,
         "termination grace should survive queue transport");
      Assert
        (not Got.Preferences.Completion_Notifications,
         "disabled completion preference should survive queue transport");
      declare
         Paths : LLM.Settings.String_Vectors.Vector;
      begin
         Paths.Append ("/one/skills");
         Paths.Append ("/two/skills");
         Queue.Enqueue
           ((Kind => Set_Preferences,
             Target_Agent_Id => Null_Unbounded_String,
             Preferences =>
               (Provider => Null_Unbounded_String,
                Model_Id => Null_Unbounded_String,
                Thinking => LLM.Providers.Off,
                Sandbox => Null_Unbounded_String,
                Subagent_Provider => Null_Unbounded_String,
                Subagent_Model => Null_Unbounded_String,
                Max_Recursion_Depth => 1,
                Termination_Grace_Seconds => 2,
                Completion_Notifications => True,
                Price_Display => LLM.Settings.SI_Prefixes,
                Skill_Paths => Paths)));
         Queue.Dequeue (Got);
         Assert (Got.Preferences.Skill_Paths.Length = 2,
                 "skill paths should survive queue transport");
         Assert (Got.Preferences.Skill_Paths.Element (1) = "/one/skills",
                 "first skill path should survive queue transport");
         Assert (Got.Preferences.Skill_Paths.Element (2) = "/two/skills",
                 "second skill path should survive queue transport");
      end;

      Queue.Enqueue
        ((Kind => Set_Preferences,
          Target_Agent_Id => Null_Unbounded_String,
          Preferences =>
            (Provider          => Null_Unbounded_String,
             Model_Id          => Null_Unbounded_String,
             Thinking          => LLM.Providers.Off,
             Sandbox           => Null_Unbounded_String,
             Subagent_Provider        => Null_Unbounded_String,
             Subagent_Model           => Null_Unbounded_String,
             Max_Recursion_Depth      => 0,
             Termination_Grace_Seconds => 0,
             Completion_Notifications => True,
             Price_Display             => LLM.Settings.SI_Prefixes,
             Skill_Paths               =>
               LLM.Settings.String_Vectors.Empty_Vector)));
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
      Assert
        (Got.Preferences.Max_Recursion_Depth = 0,
         "zero recursion depth should survive queue transport");
   end Test_Set_Preferences_Round_Trips;

   procedure Test_Enqueue_Reports_Acceptance (T : in out Test) is
      pragma Unreferenced (T);
      Queue    : Coyote_GUI.Prompt_Queue.Queue;
      Accepted : Boolean;
      Got      : Coyote_GUI.Prompt_Queue.Item;
   begin
      Queue.Enqueue
        ((Kind            => User_Prompt,
          Target_Agent_Id => Null_Unbounded_String,
          Text            => To_Unbounded_String ("hello")),
         Accepted);
      Assert (Accepted, "available queue should accept an item");
      Queue.Dequeue (Got);
      Assert (To_String (Got.Text) = "hello",
              "accepted prompt should be delivered");
   end Test_Enqueue_Reports_Acceptance;

   procedure Test_Target_Agent_Id_Round_Trips (T : in out Test) is
      pragma Unreferenced (T);
      Queue : Coyote_GUI.Prompt_Queue.Queue;
      Got   : Coyote_GUI.Prompt_Queue.Item;
   begin
      Queue.Enqueue
        ((Kind            => User_Prompt,
          Target_Agent_Id => To_Unbounded_String ("agent-7"),
          Text            => To_Unbounded_String ("steer")));
      Queue.Dequeue (Got);
      Assert (Got.Kind = User_Prompt,
              "targeted item kind should survive queue transport");
      Assert (To_String (Got.Target_Agent_Id) = "agent-7",
              "target runtime identity must survive prompt transport");
      Assert (To_String (Got.Text) = "steer",
              "targeted prompt text must survive queue transport");
   end Test_Target_Agent_Id_Round_Trips;

   procedure Test_Enqueue_Rejects_Overflow (T : in out Test) is
      pragma Unreferenced (T);
      Queue    : Coyote_GUI.Prompt_Queue.Queue;
      Accepted : Boolean;
   begin
      for I in 1 .. Max_Depth loop
         Queue.Enqueue
           ((Kind => User_Prompt,
             Target_Agent_Id => Null_Unbounded_String,
             Text => To_Unbounded_String ("prompt")), Accepted);
         Assert (Accepted, "queue should accept items through capacity");
      end loop;
      Queue.Enqueue
        ((Kind            => User_Prompt,
          Target_Agent_Id => Null_Unbounded_String,
          Text            => To_Unbounded_String ("lost")),
         Accepted);
      Assert (not Accepted, "full queue should reject an item");
   end Test_Enqueue_Rejects_Overflow;

end Coyote_GUI_Prompt_Queue_Tests;
