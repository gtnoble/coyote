--  Coyote_Incremental_Tests body.
--
--  Project: coyote

with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with AUnit.Assertions;
with AUnit.Test_Caller;
with Coyote_Renderer.Incremental;

package body Coyote_Incremental_Tests is

   use AUnit.Assertions;
   use Coyote_Renderer.Incremental;

   type Event_Log is record
      Text          : Unbounded_String;
      Count         : Natural := 0;
      Invalid_Count : Natural := 0;
   end record;

   type Event_Log_Access is access all Event_Log;
   Test_Log : aliased Event_Log;
   Active_Log : Event_Log_Access := Test_Log'Access;

   procedure Reset_Log is
   begin
      Test_Log := (others => <>);
      Active_Log := Test_Log'Access;
   end Reset_Log;

   procedure Collect (Value : Event) is
   begin
      if Active_Log = null then
         return;
      end if;
      Active_Log.Count := Active_Log.Count + 1;
      if Value.Kind = Invalid_Event then
         Active_Log.Invalid_Count := Active_Log.Invalid_Count + 1;
      end if;
      if Length (Active_Log.Text) > 0 then
         Append (Active_Log.Text, "|");
      end if;
      Append (Active_Log.Text, To_String (Value.Text));
   end Collect;

   procedure Test_Text_Is_Emitted_Immediately (T : in out Test) is
      pragma Unreferenced (T);
      Parser : Instance;
   begin
      Reset_Log;
      Feed (Parser, "hello", Collect'Access);
      Assert (Test_Log.Count = 1, "plain text should emit one event immediately");
      Assert (To_String (Test_Log.Text) = "hello", "text event should preserve text");
   end Test_Text_Is_Emitted_Immediately;

   procedure Test_Tag_Split_Across_Deltas (T : in out Test) is
      pragma Unreferenced (T);
      Parser : Instance;
   begin
      Reset_Log;
      Feed (Parser, "left<", Collect'Access);
      Assert (To_String (Test_Log.Text) = "left", "text before partial tag emits");
      Feed (Parser, "p>right</p>", Collect'Access);
      Assert (To_String (Test_Log.Text) = "left||right|",
              "split tag is reassembled");
      Assert (Test_Log.Invalid_Count = 0, "recognised split tags are valid");
   end Test_Tag_Split_Across_Deltas;

   procedure Test_Unknown_Tag_Is_Visible (T : in out Test) is
      pragma Unreferenced (T);
      Parser : Instance;
   begin
      Reset_Log;
      Feed (Parser, "a<unknown>b", Collect'Access);
      Assert (Test_Log.Invalid_Count = 1, "unknown tag should be invalid");
      Assert (To_String (Test_Log.Text) = "a|<unknown>|b",
              "unknown tag source should remain visible");
   end Test_Unknown_Tag_Is_Visible;

   procedure Test_Flush_Emits_Incomplete_Tag (T : in out Test) is
      pragma Unreferenced (T);
      Parser : Instance;
   begin
      Reset_Log;
      Feed (Parser, "tail<", Collect'Access);
      Flush (Parser, Collect'Access);
      Assert (Test_Log.Invalid_Count = 1, "flush should expose incomplete tag");
      Assert (To_String (Test_Log.Text) = "tail|<", "flush should preserve source");
   end Test_Flush_Emits_Incomplete_Tag;

   package Caller is new AUnit.Test_Caller (Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (Caller.Create
        ("Incremental text emits immediately",
         Test_Text_Is_Emitted_Immediately'Access));
      Result.Add_Test (Caller.Create
        ("Incremental tags survive delta boundaries",
         Test_Tag_Split_Across_Deltas'Access));
      Result.Add_Test (Caller.Create
        ("Incremental unknown tags remain visible",
         Test_Unknown_Tag_Is_Visible'Access));
      Result.Add_Test (Caller.Create
        ("Incremental flush exposes incomplete tags",
         Test_Flush_Emits_Incomplete_Tag'Access));
      return Result;
   end Suite;

end Coyote_Incremental_Tests;
