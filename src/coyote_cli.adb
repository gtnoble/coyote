with Ada.Command_Line; use Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with GNAT.OS_Lib;
with Ada.Text_IO; use Ada.Text_IO;
with Session_Lister;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Coyote_Canvas.Import_Service;
with Coyote_Canvas.Store.Workspaces;
with Coyote_Session_Transactions;
with Ada.Strings.Fixed;

package body Coyote_CLI is

   procedure Print_Subcommands is
   begin
      Put_Line ("Subcommands:");
      Put_Line
        ("  session list             List sessions for this directory");
      Put_Line
        ("  canvas add [--] FILE...   Import into an authorized Canvas");
      Put_Line
        ("  canvas reclaim [--apply] [--orphan] UUID   Inspect Canvas storage");
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

   package Canvas_Import renames Coyote_Canvas.Import_Service;
   use type Canvas_Import.Result;

   procedure Print_Receipt (Text : String) is
      First : Positive := Text'First;
   begin
      for I in Text'Range loop
         if Text (I) = ASCII.LF then
            Put_Line (Text (First .. I - 1));
            First := I + 1;
         end if;
      end loop;
      if First <= Text'Last then
         Put_Line (Text (First .. Text'Last));
      end if;
   end Print_Receipt;

   procedure Canvas_Add is
      Count      : constant Natural := Argument_Count;
      First_File : Positive := 3;
      Literal    : constant Boolean := Count >= 3 and then Argument (3) = "--";
   begin
      if Count = 3 and then Is_Help (Argument (3)) then
         Put_Line ("Usage: coyote canvas add [--] FILE...");
         Put_Line ("Add PNG, JPEG or SVG files to an authorized GUI session.");
         Put_Line ("Requires a live Canvas capability from the root shell tool.");
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

      if Count - First_File + 1 > Canvas_Import.MAX_FILES then
         Fail ("canvas add takes at most eight files");
         return;
      end if;
      declare
         Files : Canvas_Import.Text_List (1 .. Count - First_File + 1);
         Status : Canvas_Import.Result;
         Message : Unbounded_String;
      begin
         for I in Files'Range loop
            Files (I) := To_Unbounded_String (Argument (First_File + I - 1));
         end loop;
         Canvas_Import.Add (Files, Status, Message);
         if Status = Canvas_Import.Ok then
            Print_Receipt (To_String (Message));
         else
            Fail (To_String (Message));
         end if;
      exception
         when others => Fail ("Canvas import failed; inspect Drawings before retrying");
      end;
   end Canvas_Add;

   procedure Canvas_Reclaim is
      package Store renames Coyote_Canvas.Store;
      package Tx renames Coyote_Session_Transactions;
      use Ada.Strings;
      Apply, Orphan : Boolean := False;
      Status : Store.Result;
      Report : Store.Reclaim_Report;
   begin
      if Argument_Count = 3 and then Is_Help (Argument (3)) then
         Put_Line ("Usage: coyote canvas reclaim [--apply] [--orphan] UUID");
         Put_Line ("Inspect one UUID in this directory's session storage.");
         Put_Line ("Use --apply to remove unreferenced files; "
                   & "--orphan requires no matching log.");
         return;
      end if;
      if Argument_Count < 3
        or else not Tx.Canonical_UUID (Argument (Argument_Count))
      then
         Fail ("canvas reclaim requires one full lowercase session UUID");
         return;
      end if;
      for I in 3 .. Argument_Count - 1 loop
         if Argument (I) = "--apply" and then not Apply then
            Apply := True;
         elsif Argument (I) = "--orphan" and then not Orphan then
            Orphan := True;
         else
            Fail ("invalid or repeated canvas reclaim option");
            return;
         end if;
      end loop;
      if Ada.Environment_Variables.Value ("HOME", "") = "" then
         Fail ("canvas reclaim requires HOME");
         return;
      end if;
      declare
         use Ada.Directories;
         Path : constant String :=
           Session_Lister.Sessions_Dir (Current_Directory);
         Root : constant String := Tx.Resolve (Containing_Directory (Path));
         Parent : constant String := Compose (Root, Simple_Name (Path));
      begin
         if GNAT.OS_Lib.Is_Symbolic_Link (Parent) then
            Fail ("refusing a symlinked project session directory");
            return;
         elsif not Exists (Parent) then
            Fail ("no session storage for this directory");
            return;
         end if;
         --  The native store also opens the final entry with O_NOFOLLOW.
         Store.Workspaces.Reclaim (Parent, Argument (Argument_Count), Orphan,
                                   Apply, Report, Status);
      end;
      case Status is
         when Store.Ok =>
            Put_Line
              ((if Apply then "Removed " else "Would remove ")
               & Fixed.Trim (Report.Files'Image, Both) & " file(s), "
               & Fixed.Trim (Report.Bytes'Image, Both) & " byte(s)"
               & (if Orphan then " and the logless Canvas directory." else "."));
         when Store.Missing =>
            Fail ("no matching session log, Canvas directory, "
                  & "or committed manifest");
         when Store.Busy =>
            Fail ("Canvas or session writer is busy; "
                  & "close the editor and retry");
         when Store.Invalid =>
            Fail ("refusing unsafe, ambiguous, or invalid Canvas storage");
         when Store.Uncertain =>
            Fail ("Canvas cleanup incomplete or durability uncertain; "
                  & "inspect again before retrying");
         when Store.IO_Error =>
            Fail ("cannot inspect or reclaim Canvas storage");
      end case;
   exception
      when others => Fail ("cannot inspect or reclaim Canvas storage");
   end Canvas_Reclaim;

   procedure Canvas_Command is
   begin
      if Argument_Count = 1 then
         Fail ("missing canvas command (expected add or reclaim)");
      elsif Argument_Count = 2 and then Is_Help (Argument (2)) then
         Put_Line ("Usage: coyote canvas add [--] FILE...");
         Put_Line ("       coyote canvas reclaim [--apply] [--orphan] UUID");
      elsif Argument (2) = "add" then
         Canvas_Add;
      elsif Argument (2) = "reclaim" then
         Canvas_Reclaim;
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
