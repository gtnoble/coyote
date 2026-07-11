with Ada.Text_IO;

package body Test_Verbose_Result is

   --  ANSI escape sequences for coloured output.
   ANSI_Reset : constant String := ASCII.ESC & "[0m";
   ANSI_Green : constant String := ASCII.ESC & "[32m";
   ANSI_Red   : constant String := ASCII.ESC & "[31m";

   --  Make Message_String's equality operators directly visible.
   use type AUnit.Message_String;

   --  ── Put_Test_Name ────────────────────────────────────────────────────

   procedure Put_Test_Name
     (Test_Name    : AUnit.Message_String;
      Routine_Name : AUnit.Message_String)
   is
   begin
      Ada.Text_IO.Put ("   ");
      if Test_Name /= null then
         Ada.Text_IO.Put (Test_Name.all);
      end if;
      if Routine_Name /= null then
         Ada.Text_IO.Put (" : ");
         Ada.Text_IO.Put (Routine_Name.all);
      end if;
   end Put_Test_Name;

   --  ── Add_Success ──────────────────────────────────────────────────────

   overriding
   procedure Add_Success
     (R            : in out Verbose_Result;
      Test_Name    : AUnit.Message_String;
      Routine_Name : AUnit.Message_String;
      Elapsed      : AUnit.Time_Measure.Time)
   is
      pragma Unreferenced (Elapsed);
   begin
      Ada.Text_IO.Put (ANSI_Green);
      Ada.Text_IO.Put ("OK ");
      Put_Test_Name (Test_Name, Routine_Name);
      Ada.Text_IO.Put_Line (ANSI_Reset);
      --  Chain to parent so the summary reporter still works.
      AUnit.Test_Results.Add_Success
        (AUnit.Test_Results.Result (R),
         Test_Name, Routine_Name, Elapsed);
   end Add_Success;

   --  ── Add_Failure ──────────────────────────────────────────────────────

   overriding
   procedure Add_Failure
     (R            : in out Verbose_Result;
      Test_Name    : AUnit.Message_String;
      Routine_Name : AUnit.Message_String;
      Failure      : AUnit.Test_Results.Test_Failure;
      Elapsed      : AUnit.Time_Measure.Time)
   is
      pragma Unreferenced (Elapsed);
   begin
      Ada.Text_IO.Put (ANSI_Red);
      Ada.Text_IO.Put ("FAIL ");
      Put_Test_Name (Test_Name, Routine_Name);
      Ada.Text_IO.Put_Line (ANSI_Reset);
      AUnit.Test_Results.Add_Failure
        (AUnit.Test_Results.Result (R),
         Test_Name, Routine_Name, Failure, Elapsed);
   end Add_Failure;

   --  ── Add_Error ────────────────────────────────────────────────────────

   overriding
   procedure Add_Error
     (R            : in out Verbose_Result;
      Test_Name    : AUnit.Message_String;
      Routine_Name : AUnit.Message_String;
      Error        : AUnit.Test_Results.Test_Error;
      Elapsed      : AUnit.Time_Measure.Time)
   is
      pragma Unreferenced (Elapsed);
   begin
      Ada.Text_IO.Put (ANSI_Red);
      Ada.Text_IO.Put ("ERR  ");
      Put_Test_Name (Test_Name, Routine_Name);
      Ada.Text_IO.Put_Line (ANSI_Reset);
      AUnit.Test_Results.Add_Error
        (AUnit.Test_Results.Result (R),
         Test_Name, Routine_Name, Error, Elapsed);
   end Add_Error;

end Test_Verbose_Result;
