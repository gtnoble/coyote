with Ada.Text_IO;
with Interfaces.C;

package body Test_Verbose_Result is

   --  Detect whether stdout is a TTY; suppress ANSI colours when piped.

   STDOUT_FILENO : constant Interfaces.C.int := 1;

   function C_Isatty (Fd : Interfaces.C.int) return Interfaces.C.int;
   pragma Import (C, C_Isatty, "isatty");

   use type Interfaces.C.int;
   Use_Color : constant Boolean := C_Isatty (STDOUT_FILENO) = 1;

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
      if Use_Color then
         Ada.Text_IO.Put (ANSI_Green);
      end if;
      Ada.Text_IO.Put ("OK ");
      Put_Test_Name (Test_Name, Routine_Name);
      if Use_Color then
         Ada.Text_IO.Put_Line (ANSI_Reset);
      else
         Ada.Text_IO.New_Line;
      end if;
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
      if Use_Color then
         Ada.Text_IO.Put (ANSI_Red);
      end if;
      Ada.Text_IO.Put ("FAIL ");
      Put_Test_Name (Test_Name, Routine_Name);
      if Use_Color then
         Ada.Text_IO.Put_Line (ANSI_Reset);
      else
         Ada.Text_IO.New_Line;
      end if;
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
      if Use_Color then
         Ada.Text_IO.Put (ANSI_Red);
      end if;
      Ada.Text_IO.Put ("ERR  ");
      Put_Test_Name (Test_Name, Routine_Name);
      if Use_Color then
         Ada.Text_IO.Put_Line (ANSI_Reset);
      else
         Ada.Text_IO.New_Line;
      end if;
      AUnit.Test_Results.Add_Error
        (AUnit.Test_Results.Result (R),
         Test_Name, Routine_Name, Error, Elapsed);
   end Add_Error;

end Test_Verbose_Result;
