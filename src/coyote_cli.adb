with Ada.Command_Line; use Ada.Command_Line;
with Ada.Directories;
with Ada.Text_IO; use Ada.Text_IO;
with Session_Lister;

package body Coyote_CLI is

   procedure Print_Subcommands is
   begin
      Put_Line ("Subcommands:");
      Put_Line
        ("  session list             List sessions for this directory");
      Put_Line
        ("  canvas add [--] FILE...   Canvas import (not yet available)");
      Put_Line ("  Use -h or --help after a group or command for usage.");
   end Print_Subcommands;

   function Is_Help (Arg : String) return Boolean is
     (Arg = "-h" or else Arg = "--help");

   procedure Fail (Message : String) is
   begin
      Put_Line (Standard_Error, "error: " & Message);
      Set_Exit_Status (Failure);
   end Fail;

   procedure Session_Command is
      Count : constant Natural := Argument_Count;
   begin
      if Count = 1 then
         Fail ("missing session command (expected list)");
      elsif Count = 2 and then Is_Help (Argument (2)) then
         Put_Line ("Usage: coyote session list");
      elsif Argument (2) /= "list" then
         Fail ("unknown session command: " & Argument (2));
      elsif Count = 3 and then Is_Help (Argument (3)) then
         Put_Line ("Usage: coyote session list");
         Put_Line ("Print UUID, name, date and snippet for this directory.");
      elsif Count /= 2 then
         Fail ("session list takes no operands");
      else
         Session_Lister.Print_TSV (Ada.Directories.Current_Directory);
      end if;
   end Session_Command;

   procedure Canvas_Add is
      Count      : constant Natural := Argument_Count;
      First_File : Positive := 3;
      Literal    : constant Boolean := Count >= 3 and then Argument (3) = "--";
   begin
      if Count = 3 and then Is_Help (Argument (3)) then
         Put_Line ("Usage: coyote canvas add [--] FILE...");
         Put_Line ("Add PNG, JPEG or SVG files to an authorized GUI session.");
         Put_Line ("Canvas import is not available in this build.");
         return;
      end if;

      if Literal then
         First_File := First_File + 1;
      end if;
      if Count < First_File then
         Fail ("canvas add requires at least one file");
         return;
      end if;

      for Index in First_File .. Count loop
         File_Operand : declare
            Name : constant String := Argument (Index);
         begin
            if Name'Length = 0 then
               Fail ("canvas add does not accept an empty filename");
               return;
            elsif not Literal and then Name (Name'First) = '-' then
               Fail ("invalid canvas add option: " & Name
                     & " (use -- before filenames beginning with a dash)");
               return;
            end if;
         end File_Operand;
      end loop;

      --  Until a scoped import endpoint exists, do not probe paths or
      --  guess a session. This branch has no file or session side effects.
      Fail ("Canvas import unavailable: no authorized Canvas service");
   end Canvas_Add;

   procedure Canvas_Command is
   begin
      if Argument_Count = 1 then
         Fail ("missing canvas command (expected add)");
      elsif Argument_Count = 2 and then Is_Help (Argument (2)) then
         Put_Line ("Usage: coyote canvas add [--] FILE...");
      elsif Argument (2) = "add" then
         Canvas_Add;
      else
         Fail ("unknown canvas command: " & Argument (2));
      end if;
   end Canvas_Command;

   function Dispatch return Boolean is
   begin
      if Argument_Count = 0 then
         return False;
      end if;
      if Argument (1) = "session" then
         Set_Exit_Status (Success);
         Session_Command;
      elsif Argument (1) = "canvas" then
         Set_Exit_Status (Success);
         Canvas_Command;
      else
         return False;
      end if;
      return True;
   end Dispatch;

end Coyote_CLI;
