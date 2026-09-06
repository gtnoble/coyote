with AUnit.Test_Caller;
--  Coyote_GUI_Session_Stats_Window_Tests body.
--
--  Project: coyote

with Ada.Environment_Variables;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with AUnit.Assertions;
with Coyote_GUI;
with Coyote_GUI.Session_Stats_Window;
with Gtk.Main;
with Gtk.Window;
with Gtk.Enums;

package body Coyote_GUI_Session_Stats_Window_Tests is

   use AUnit.Assertions;

   function Display_Detected return Boolean is
   begin
      return Ada.Environment_Variables.Exists ("DISPLAY")
        or else Ada.Environment_Variables.Exists ("WAYLAND_DISPLAY");
   exception
      when others =>
         return False;
   end Display_Detected;

   function Sample_Stats return Coyote_GUI.Session_Stats_Record is
   begin
      return
        (Model          => To_Unbounded_String ("openrouter/test-model"),
         Session_Id     => To_Unbounded_String ("session-12345678"),
         Turn_Count     => 7,
         Last_Input     => 1_200,
         Last_Output    => 340,
         Last_Cost_Dmil => 23,
         Input          => 9_000,
         Cache_Read     => 1_500,
         Cache_Write    => 500,
         Output         => 2_100,
         Cost_Dmil      => 156);
   end Sample_Stats;

   overriding procedure Set_Up (T : in out Test) is
   begin
      if Display_Detected then
         Gtk.Main.Init;
         T.Display_Available := True;
      end if;
   end Set_Up;

   procedure Test_Snapshot_Round_Trip (T : in out Test) is
      Window : Coyote_GUI.Session_Stats_Window.Instance;
      Want   : constant Coyote_GUI.Session_Stats_Record := Sample_Stats;
      Got    : Coyote_GUI.Session_Stats_Record;
   begin
      Coyote_GUI.Session_Stats_Window.Update (Window, Want);
      Got := Coyote_GUI.Session_Stats_Window.Current_Stats (Window);
      Assert (Got.Model = Want.Model, "model must be retained");
      Assert (Got.Session_Id = Want.Session_Id,
              "session identifier must be retained");
      Assert (Got.Turn_Count = Want.Turn_Count,
              "turn count must be retained");
      Assert (Got.Last_Input = Want.Last_Input,
              "last input must be retained");
      Assert (Got.Last_Output = Want.Last_Output,
              "last output must be retained");
      Assert (Got.Last_Cost_Dmil = Want.Last_Cost_Dmil,
              "last cost must be retained");
      Assert (Got.Input = Want.Input, "input total must be retained");
      Assert (Got.Cache_Read = Want.Cache_Read,
              "cache-read total must be retained");
      Assert (Got.Cache_Write = Want.Cache_Write,
              "cache-write total must be retained");
      Assert (Got.Output = Want.Output, "output total must be retained");
      Assert (Got.Cost_Dmil = Want.Cost_Dmil,
              "cost total must be retained");
   end Test_Snapshot_Round_Trip;

   procedure Test_Clear_Resets_Snapshot (T : in out Test) is
      Window : Coyote_GUI.Session_Stats_Window.Instance;
      Got    : Coyote_GUI.Session_Stats_Record;
   begin
      Coyote_GUI.Session_Stats_Window.Update (Window, Sample_Stats);
      Coyote_GUI.Session_Stats_Window.Clear (Window);
      Got := Coyote_GUI.Session_Stats_Window.Current_Stats (Window);
      Assert (Length (Got.Model) = 0, "clear must remove the model");
      Assert (Length (Got.Session_Id) = 0,
              "clear must remove the session identifier");
      Assert (Got.Turn_Count = 0, "clear must reset the turn count");
      Assert (Got.Input = 0, "clear must reset input total");
      Assert (Got.Output = 0, "clear must reset output total");
      Assert (Got.Cost_Dmil = 0, "clear must reset cost total");
   end Test_Clear_Resets_Snapshot;

   procedure Test_Create_Is_Idempotent (T : in out Test) is
      Parent : Gtk.Window.Gtk_Window;
      Window : Coyote_GUI.Session_Stats_Window.Instance;
   begin
      if not T.Display_Available then
         return;
      end if;
      Gtk.Window.Gtk_New (Parent, Gtk.Enums.Window_Toplevel);
      Coyote_GUI.Session_Stats_Window.Create
        (Window, Parent.all'Access);
      Assert (Coyote_GUI.Session_Stats_Window.Is_Created (Window),
              "create must construct the support window");
      Coyote_GUI.Session_Stats_Window.Create
        (Window, Parent.all'Access);
      Assert (Coyote_GUI.Session_Stats_Window.Is_Created (Window),
              "repeated create must retain the support window");
      Parent.Destroy;
   end Test_Create_Is_Idempotent;

   package Coyote_GUI_Session_Stats_Window_Caller is
     new AUnit.Test_Caller (Coyote_GUI_Session_Stats_Window_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (Coyote_GUI_Session_Stats_Window_Caller.Create
        ("Coyote.GUI session stats snapshot round trip",
         Coyote_GUI_Session_Stats_Window_Tests
           .Test_Snapshot_Round_Trip'Access));
      Result.Add_Test (Coyote_GUI_Session_Stats_Window_Caller.Create
        ("Coyote.GUI session stats clear resets snapshot",
         Coyote_GUI_Session_Stats_Window_Tests
           .Test_Clear_Resets_Snapshot'Access));
      Result.Add_Test (Coyote_GUI_Session_Stats_Window_Caller.Create
        ("Coyote.GUI session stats window creation is idempotent",
         Coyote_GUI_Session_Stats_Window_Tests
           .Test_Create_Is_Idempotent'Access));

      return Result;
   end Suite;

end Coyote_GUI_Session_Stats_Window_Tests;
