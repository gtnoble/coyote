--  Coyote_App.Utils body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with GNAT.SHA256;
with GNATCOLL.JSON;          use GNATCOLL.JSON;
with GNATCOLL.OS.FS;
with GNATCOLL.OS.Process;
with Interfaces;             use Interfaces;
with Nine_P;                 use Nine_P;

package body Coyote_App.Utils is

   --  POSIX getpid() — needed by Edit_Diff_Lines for temp-file names.
   function Getpid return Integer;
   pragma Import (C, Getpid, "getpid");

   --  ── String utilities ─────────────────────────────────────────────────

   function Str_Repeat (Text : String; N : Positive) return String is
      Result : String (1 .. Text'Length * N);
   begin
      for I in 0 .. N - 1 loop
         Result (I * Text'Length + 1 .. (I + 1) * Text'Length) := Text;
      end loop;
      return Result;
   end Str_Repeat;

   function Natural_Image (N : Natural) return String is
      Image : constant String := Natural'Image (N);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end Natural_Image;

   --  Format a Long_Float with at most 2 decimal places, trailing zeros
   --  stripped.  Caller is responsible for passing a non-negative,
   --  already-scaled value.
   --
   --  Examples: 3.0 -> "3", 1.25 -> "1.25", 2.5 -> "2.5", 300.0 -> "300".
   function Format_Compact (V : Long_Float) return String is
      Total     : constant Natural :=
        Natural (Long_Float'Rounding (V * 100.0));
      Int_Part  : constant Natural  := Total / 100;
      Frac_Part : constant Natural  := Total mod 100;
      D1        : constant Character :=
        Character'Val (Character'Pos ('0') + Frac_Part / 10);
      D2        : constant Character :=
        Character'Val (Character'Pos ('0') + Frac_Part mod 10);
   begin
      if Frac_Part = 0 then
         return Natural_Image (Int_Part);
      elsif Frac_Part mod 10 = 0 then
         return Natural_Image (Int_Part) & "." & (1 => D1);
      else
         return Natural_Image (Int_Part) & "." & (D1 & D2);
      end if;
   end Format_Compact;

   function Format_SI_Count (N : Natural) return String is
      V : constant Long_Float := Long_Float (N);
   begin
      if N >= 1_000_000_000 then
         return Format_Compact (V / 1_000_000_000.0) & "G";
      elsif N >= 1_000_000 then
         return Format_Compact (V / 1_000_000.0) & "M";
      elsif N >= 1_000 then
         return Format_Compact (V / 1_000.0) & "k";
      else
         return Natural_Image (N);
      end if;
   end Format_SI_Count;

   function Format_SI_Price (Per_MTok : Long_Float) return String is
   begin
      if Per_MTok <= 0.0 then
         return "";
      elsif Per_MTok >= 1.0 then
         return "$" & Format_Compact (Per_MTok) & UC_MICRO;
      elsif Per_MTok >= 0.001 then
         return "$" & Format_Compact (Per_MTok * 1_000.0) & "n";
      else
         return "$" & Format_Compact (Per_MTok * 1_000_000.0) & "p";
      end if;
   end Format_SI_Price;

   function Format_Model_Price
     (Input_Per_MTok       : Long_Float;
      Output_Per_MTok      : Long_Float;
      Cache_Read_Per_MTok  : Long_Float;
      Cache_Write_Per_MTok : Long_Float) return String
   is
      Result : Ada.Strings.Unbounded.Unbounded_String;

      procedure Append_Field (Label : String; Per_MTok : Long_Float) is
         Price : constant String := Format_SI_Price (Per_MTok);
      begin
         if Price'Length = 0 then
            return;
         end if;
         if Length (Result) > 0 then
            Append (Result, " ");
         end if;
         Append (Result, Label & " " & Price);
      end Append_Field;

   begin
      Append_Field ("in",  Input_Per_MTok);
      Append_Field ("out", Output_Per_MTok);
      Append_Field ("cr",  Cache_Read_Per_MTok);
      Append_Field ("cw",  Cache_Write_Per_MTok);

      if Length (Result) = 0 then
         return "";
      end if;

      Append (Result, " /tok");
      return To_String (Result);
   end Format_Model_Price;

   function Format_Cost (Dmil : Natural) return String is

      function Pad4 (N : Natural) return String is
         Buf : String (1 .. 4) := "0000";
         V   : Natural         := N;
      begin
         Buf (4) := Character'Val (Character'Pos ('0') + V mod 10);
         V       := V / 10;
         Buf (3) := Character'Val (Character'Pos ('0') + V mod 10);
         V       := V / 10;
         Buf (2) := Character'Val (Character'Pos ('0') + V mod 10);
         V       := V / 10;
         Buf (1) := Character'Val (Character'Pos ('0') + V mod 10);
         return Buf;
      end Pad4;

   begin
      return "$"
             & Natural_Image (Dmil / 10_000)
             & "."
             & Pad4 (Dmil mod 10_000);
   end Format_Cost;

   function Agent_Stem (Path : String) return String is
      Slash : Natural := 0;
   begin
      for I in reverse Path'Range loop
         if Path (I) = '/' then
            Slash := I;
            exit;
         end if;
      end loop;
      declare
         Base   : constant String := Path (Slash + 1 .. Path'Last);
         Suffix : constant String := ".agent.md";
         Dot    : constant Natural :=
           (if Base'Length > Suffix'Length
              and then Base
                         (Base'Last - Suffix'Length + 1 .. Base'Last)
                       = Suffix
            then Base'Last - Suffix'Length
            else Base'Last);
      begin
         return Base (Base'First .. Dot);
      end;
   end Agent_Stem;

   function Nth_Field (Text : String; N : Positive) return String is
      Count   : Natural := 0;
      Start   : Natural := 0;
      In_Tok  : Boolean := False;
   begin
      for I in Text'Range loop
         if Text (I) in ' ' | ASCII.HT then
            if In_Tok then
               if Count = N then
                  return Text (Start .. I - 1);
               end if;
               In_Tok := False;
            end if;
         else
            if not In_Tok then
               In_Tok := True;
               Count  := Count + 1;
               Start  := I;
            end if;
         end if;
      end loop;
      if In_Tok and then Count = N then
         return Text (Start .. Text'Last);
      end if;
      return "";
   end Nth_Field;

   function Parse_Fork_Token
     (Data       : String;
      Pid_Prefix : String;
      UUID       : out Unbounded_String;
      Turn_N     : out Positive) return Boolean
   is
      Prefix_End : constant Natural :=
        Data'First + Pid_Prefix'Length - 1;
      Last_Slash : Natural := 0;
   begin
      if Data'Length <= Pid_Prefix'Length
        or else Data (Data'First .. Prefix_End) /= Pid_Prefix
      then
         return False;
      end if;

      for I in reverse Prefix_End + 1 .. Data'Last loop
         if Data (I) = '/' then
            Last_Slash := I;
            exit;
         end if;
      end loop;

      if Last_Slash = 0 or else Last_Slash <= Prefix_End + 1 then
         return False;
      end if;

      if Last_Slash = Data'Last then
         return False;
      end if;

      declare
         UUID_Text : constant String :=
           Data (Prefix_End + 1 .. Last_Slash - 1);
         Turn_Text : constant String :=
           Data (Last_Slash + 1 .. Data'Last);
         Turn      : Positive;
      begin
         if UUID_Text'Length = 0 or else Turn_Text'Length = 0 then
            return False;
         end if;

         begin
            Turn := Positive'Value (Turn_Text);
         exception
            when Constraint_Error =>
               return False;
         end;

         UUID   := To_Unbounded_String (UUID_Text);
         Turn_N := Turn;
         return True;
      end;
   end Parse_Fork_Token;

   function Hash_Tool_Id (Tool_Id : String) return String is
   begin
      return GNAT.SHA256.Digest (Tool_Id) (1 .. 16);
   end Hash_Tool_Id;

   --  ── Edit_Diff_Lines ───────────────────────────────────────────────────
   --
   --  Run `diff -u` on Old_Text vs New_Text, strip the ---/+++/@@ header
   --  lines produced by unified diff, and return the remaining body lines
   --  joined by ASCII.LF.  Truncates to Max_L body lines and appends a
   --  trailer ("… N more lines") when the diff exceeds the limit.
   --
   --  Returns "(no changes)" when Old_Text = New_Text or when the diff
   --  produces no body lines.  Returns "(diff error)" if the subprocess
   --  cannot be started.
   --
   --  Matches the behaviour of the Python reference's edit_diff_lines().

   function Edit_Diff_Lines
     (Old_Text : String;
      New_Text : String;
      Max_L    : Positive := 30) return String
   is
      use GNATCOLL.OS.FS;
      use GNATCOLL.OS.Process;

      Pid_S  : constant String :=
        Natural_Image (Natural (Getpid));
      Old_F  : constant String :=
        "/tmp/coyote-diff-" & Pid_S & "-old";
      New_F  : constant String :=
        "/tmp/coyote-diff-" & Pid_S & "-new";

      --  Write Text to a temporary file at Path using binary stream I/O.
      --  Ada.Streams.Stream_IO is used instead of Ada.Text_IO so that the
      --  raw UTF-8 bytes are written as-is.  Ada.Text_IO.Put with -gnatW8
      --  re-encodes each Latin-1 byte > 16#7F# as a UTF-8 sequence,
      --  double-encoding content that is already UTF-8.
      procedure Write_Temp (Path : String; Text : String) is
         use Ada.Streams.Stream_IO;
         File : File_Type;
      begin
         Create (File, Out_File, Path);
         String'Write (Stream (File), Text);
         Close (File);
      end Write_Temp;

      Buffer : Unbounded_String;

   begin
      if Old_Text = New_Text then
         return "(no changes)";
      end if;

      Write_Temp (Old_F, Old_Text);
      Write_Temp (New_F, New_Text);

      --  Spawn diff -u and capture stdout.
      declare
         Stdout_R, Stdout_W : File_Descriptor;
         Null_In  : constant File_Descriptor :=
           Open (Null_File, Read_Mode);
         Null_Out : constant File_Descriptor :=
           Open (Null_File, Write_Mode);
         Args     : Argument_List;
         Handle   : Process_Handle;
         Chunk    : String (1 .. 4096);
         N        : Integer;
      begin
         Open_Pipe (Stdout_R, Stdout_W);
         Args.Append ("diff");
         Args.Append ("-u");
         Args.Append (Old_F);
         Args.Append (New_F);
         Handle := Start (Args   => Args,
                          Stdin  => Null_In,
                          Stdout => Stdout_W,
                          Stderr => Null_Out);
         Close (Null_In);
         Close (Stdout_W);
         Close (Null_Out);
         loop
            N := Read (Stdout_R, Chunk);
            exit when N <= 0;
            Append (Buffer, Chunk (1 .. N));
         end loop;
         Close (Stdout_R);
         declare
            Dummy : constant Integer := Wait (Handle);
            pragma Unreferenced (Dummy);
         begin
            null;
         end;
      end;

      --  Delete temp files (ignore errors).
      begin
         Ada.Directories.Delete_File (Old_F);
      exception
         when others => null;
      end;
      begin
         Ada.Directories.Delete_File (New_F);
      exception
         when others => null;
      end;

      --  Parse diff output: skip ---/+++/@@ lines; collect body lines;
      --  truncate to Max_L with an ellipsis trailer.
      declare
         Raw        : constant String  := To_String (Buffer);
         Result     : Unbounded_String;
         Line_Start : Natural          := Raw'First;
         Line_Count : Natural          := 0;
         Skipped    : Natural          := 0;

         --  Append one body line (without its terminating newline) to
         --  Result, respecting the Max_L truncation limit.
         procedure Process_Line (L : String) is
            Skip : constant Boolean :=
              (L'Length >= 3
                 and then L (L'First .. L'First + 2) = "---")
              or else (L'Length >= 3
                 and then L (L'First .. L'First + 2) = "+++")
              or else (L'Length >= 2
                 and then L (L'First .. L'First + 1) = "@@")
              or else (L'Length >= 1
                 and then L (L'First) = '\');
         begin
            if Skip then
               return;
            end if;
            if Line_Count < Max_L then
               if Length (Result) > 0 then
                  Append (Result, ASCII.LF);
               end if;
               Append (Result, L);
               Line_Count := Line_Count + 1;
            else
               Skipped := Skipped + 1;
            end if;
         end Process_Line;

      begin
         for I in Raw'Range loop
            if Raw (I) = ASCII.LF then
               Process_Line (Raw (Line_Start .. I - 1));
               Line_Start := I + 1;
            end if;
         end loop;
         --  Last line when the diff output has no trailing newline.
         if Line_Start <= Raw'Last then
            Process_Line (Raw (Line_Start .. Raw'Last));
         end if;
         if Skipped > 0 then
            if Length (Result) > 0 then
               Append (Result, ASCII.LF);
            end if;
            Append
              (Result,
               UC_ELLIP & " " & Natural_Image (Skipped) & " more lines");
         end if;
         if Length (Result) = 0 then
            return "(no changes)";
         end if;
         return To_String (Result);
      end;
   exception
      when others => return "(diff error)";
   end Edit_Diff_Lines;

   --  ── Extract_Plumb_Data ────────────────────────────────────────────────
   --
   --  A plumb message is 7 newline-separated fields:
   --  src, dst, wdir, type, attr, ndata, data

   function Extract_Plumb_Data (Raw : Byte_Array) return String is
      Count   : Natural := 0;
      Start   : Natural := Raw'First;
      N_Data  : Natural := 0;
   begin
      for I in Raw'Range loop
         if Raw (I) = Uint8 (Character'Pos (ASCII.LF)) then
            Count := Count + 1;
            if Count = 6 then
               --  Field 5 (0-indexed) is ndata; parse it, then return
               --  the data field that immediately follows this newline.
               declare
                  N_Data_String : String (1 .. I - Start);
               begin
                  for J in N_Data_String'Range loop
                     N_Data_String (J) :=
                       Character'Val (Raw (Start + J - 1));
                  end loop;
                  begin
                     N_Data := Natural'Value (N_Data_String);
                  exception
                     when Constraint_Error => N_Data := 0;
                  end;
               end;
               --  Data field starts at I + 1 (the byte after this \n).
               --  Use N_Data to bound it; this strips any trailing \n
               --  that the plumber appends to the message.
               declare
                  Data_Start : constant Natural := I + 1;
                  Available  : constant Natural :=
                    (if Data_Start <= Raw'Last
                     then Raw'Last - Data_Start + 1
                     else 0);
                  Length     : constant Natural :=
                    (if N_Data > 0
                     then Natural'Min (N_Data, Available)
                     else Available);
                  Result     : String (1 .. Length);
               begin
                  for J in Result'Range loop
                     Result (J) := Character'Val (Raw (Data_Start + J - 1));
                  end loop;
                  return Result;
               end;
            end if;
            Start := I + 1;
         end if;
      end loop;
      return "";
   end Extract_Plumb_Data;

   --  ── Apply_Prompt_Filter ───────────────────────────────────────────────
   --
   --  Pipe Raw through the shell command Filter and return stdout.
   --  Falls back to Raw on any error, populating Warn_Buf with a message.

   function Apply_Prompt_Filter
     (Raw      : String;
      Filter   : String;
      Warn_Buf : out Ada.Strings.Unbounded.Unbounded_String) return String
   is
      use GNATCOLL.OS.FS;
      use GNATCOLL.OS.Process;
   begin
      Warn_Buf := Null_Unbounded_String;

      if Filter'Length = 0 then
         return Raw;
      end if;

      declare
         Stdin_R,  Stdin_W  : File_Descriptor;
         Stdout_R, Stdout_W : File_Descriptor;
         Stderr_Null        : constant File_Descriptor :=
           Open (Null_File, Write_Mode);
         Args               : Argument_List;
         Handle             : Process_Handle;
         Exit_Code          : Integer;
         Output_Buf         : Unbounded_String;
         Chunk              : String (1 .. 4_096);
         N                  : Integer;
      begin
         Open_Pipe (Stdin_R,  Stdin_W);
         Open_Pipe (Stdout_R, Stdout_W);

         declare
            Shell : constant String :=
              Ada.Environment_Variables.Value ("SHELL", "sh");
         begin
            Args.Append (Shell);
         end;
         Args.Append ("-c");
         Args.Append (Filter);

         Handle := Start
           (Args   => Args,
            Stdin  => Stdin_R,
            Stdout => Stdout_W,
            Stderr => Stderr_Null);

         Close (Stdin_R);
         Close (Stdout_W);
         Close (Stderr_Null);

         --  Write the raw prompt to the child's stdin then close the pipe
         --  so the child sees EOF.
         declare
            Bytes_Written : Integer;
            pragma Unreferenced (Bytes_Written);
         begin
            Bytes_Written := Write (Stdin_W, Raw);
         end;
         Close (Stdin_W);

         --  Read child stdout.
         loop
            N := Read (Stdout_R, Chunk);
            exit when N <= 0;
            Append (Output_Buf, Chunk (1 .. N));
         end loop;
         Close (Stdout_R);

         Exit_Code := Wait (Handle);

         if Exit_Code /= 0 then
            Warn_Buf :=
              To_Unbounded_String
                ("prompt filter exited with status "
                 & Natural_Image (Natural (Exit_Code))
                 & " -- sending raw prompt");
            return Raw;
         end if;

         --  Trim leading/trailing whitespace from the output.
         declare
            Output : constant String := To_String (Output_Buf);
            First  : Natural         := Output'First;
            Last   : Natural         := Output'Last;
         begin
            while First <= Last
              and then Output (First) in ' ' | ASCII.HT | ASCII.LF | ASCII.CR
            loop
               First := First + 1;
            end loop;
            while Last >= First
              and then Output (Last) in ' ' | ASCII.HT | ASCII.LF | ASCII.CR
            loop
               Last := Last - 1;
            end loop;

            if First > Last then
               Warn_Buf :=
                 To_Unbounded_String
                   ("prompt filter returned empty output"
                    & " -- sending raw prompt");
               return Raw;
            end if;

            return Output (First .. Last);
         end;
      end;
   exception
      when Ex : others =>
         Warn_Buf :=
           To_Unbounded_String
             ("prompt filter failed: "
              & Ada.Exceptions.Exception_Message (Ex)
              & " -- sending raw prompt");
         return Raw;
   end Apply_Prompt_Filter;

   function Format_Turn_Summary
     (Input_Tokens      : Natural;
      Output_Tokens     : Natural;
      Ctx_Window        : Natural;
      Model_Text        : String;
      Turn_Cost_Dmil    : Natural := 0;
      Session_Cost_Dmil : Natural := 0) return String
   is
      Parts : Unbounded_String;
   begin
      if Input_Tokens > 0 and then Ctx_Window > 0 then
         Append
           (Parts,
            "ctx "
            & Format_SI_Count (Input_Tokens)
            & "/" & Format_SI_Count (Ctx_Window)
            & " ("
            & Natural_Image (Input_Tokens * 100 / Ctx_Window)
            & "%)");
      end if;
      if Output_Tokens > 0 then
         if Length (Parts) > 0 then
            Append (Parts, " | ");
         end if;
         Append
           (Parts,
            "^" & Format_SI_Count (Output_Tokens)
            & " out");
      end if;
      if Turn_Cost_Dmil > 0 then
         if Length (Parts) > 0 then
            Append (Parts, " | ");
         end if;
         Append (Parts, Format_Cost (Turn_Cost_Dmil) & " turn");
      end if;
      if Session_Cost_Dmil > 0 then
         if Length (Parts) > 0 then
            Append (Parts, " | ");
         end if;
         Append (Parts, Format_Cost (Session_Cost_Dmil) & " session");
      end if;
      if Model_Text'Length > 0 then
         if Length (Parts) > 0 then
            Append (Parts, " | ");
         end if;
         Append (Parts, Model_Text);
      end if;
      return
        (if Length (Parts) > 0
         then "[" & To_String (Parts) & "]"
         else "");
   end Format_Turn_Summary;

   function Format_Turn_Footer
     (Turn_N            : Positive;
      UUID              : String;
      PID               : String;
      Input_Tokens      : Natural := 0;
      Output_Tokens     : Natural := 0;
      Ctx_Window        : Natural := 0;
      Model_Text        : String  := "";
      Turn_Cost_Dmil    : Natural := 0;
      Session_Cost_Dmil : Natural := 0) return String
   is
      Summary : constant String :=
        Format_Turn_Summary
          (Input_Tokens      => Input_Tokens,
           Output_Tokens     => Output_Tokens,
           Ctx_Window        => Ctx_Window,
           Model_Text        => Model_Text,
           Turn_Cost_Dmil    => Turn_Cost_Dmil,
           Session_Cost_Dmil => Session_Cost_Dmil);
   begin
      return ASCII.LF & ASCII.LF
             & (if Summary'Length > 0 then Summary & " " else "")
             & "coyote-fork+" & PID & "/" & UUID & "/"
             & Natural_Image (Turn_N) & ASCII.LF
             & Str_Repeat (UC_DBL_H, 60)
             & ASCII.LF & ASCII.LF;
   end Format_Turn_Footer;

   --  ── JSON field helpers ────────────────────────────────────────────────

   function Get_String
     (Val   : JSON_Value;
      Field : UTF8_String) return String
   is
   begin
      if Val.Has_Field (Field)
        and then Val.Get (Field).Kind = JSON_String_Type
      then
         return Val.Get (Field).Get;
      end if;
      return "";
   end Get_String;

   function Get_Integer
     (Val   : JSON_Value;
      Field : UTF8_String) return Natural
   is
   begin
      if Val.Has_Field (Field)
        and then Val.Get (Field).Kind = JSON_Int_Type
      then
         return Natural (Long_Integer'(Val.Get (Field).Get));
      end if;
      return 0;
   end Get_Integer;

   function Get_Cost_Dmil
     (Val   : JSON_Value;
      Field : UTF8_String) return Natural
   is
   begin
      if not Val.Has_Field (Field) then
         return 0;
      end if;
      declare
         F : constant JSON_Value := Val.Get (Field);
      begin
         if F.Kind = JSON_Float_Type then
            declare
               Cost : constant Long_Float := Get_Long_Float (F);
            begin
               if Cost > 0.0 then
                  return Natural
                    (Long_Float'Floor (Cost * 10_000.0 + 0.5));
               end if;
            end;
         elsif F.Kind = JSON_Int_Type then
            declare
               Cost_I : constant Long_Integer := Long_Integer'(F.Get);
            begin
               if Cost_I > 0 then
                  return Natural (Cost_I) * 10_000;
               end if;
            end;
         end if;
      end;
      return 0;
   end Get_Cost_Dmil;

   function Get_Boolean
     (Val   : JSON_Value;
      Field : UTF8_String) return Boolean
   is
   begin
      if Val.Has_Field (Field)
        and then Val.Get (Field).Kind = JSON_Boolean_Type
      then
         return Val.Get (Field).Get;
      end if;
      return False;
   end Get_Boolean;

   function Get_Object
     (Val   : JSON_Value;
      Field : UTF8_String) return JSON_Value
   is
   begin
      if Val.Has_Field (Field)
        and then Val.Get (Field).Kind = JSON_Object_Type
      then
         return Val.Get (Field);
      end if;
      return JSON_Null;
   end Get_Object;

   function JSON_Scalar_Image (Val : JSON_Value) return String is
   begin
      if Val.Kind = JSON_String_Type then
         return Val.Get;
      elsif Val.Kind in
        JSON_Int_Type | JSON_Boolean_Type | JSON_Float_Type
      then
         return Val.Write;
      else
         return "...";
      end if;
   end JSON_Scalar_Image;

   function Format_Tool_Field
     (Name    : String;
      Value   : String;
      Max_Len : Positive := 200) return String
   is
      Trimmed : constant String :=
        (if Value'Length > Max_Len
         then Value (Value'First .. Value'First + Max_Len - 4) & UC_ELLIP
         else Value);
      Result  : Unbounded_String;
      Pos     : Natural := Trimmed'First;
      First   : Boolean := True;
   begin
      for I in Trimmed'Range loop
         if Trimmed (I) = ASCII.LF then
            if First then
               Append
                 (Result,
                  UC_BOX_V & " " & Name & ": "
                  & Trimmed (Pos .. I - 1));
               First := False;
            else
               Append
                 (Result,
                  "" & ASCII.LF & UC_BOX_V & " "
                  & Trimmed (Pos .. I - 1));
            end if;
            Pos := I + 1;
         end if;
      end loop;
      --  Remainder after the last newline (or the whole value when there
      --  are no newlines).
      if First then
         Append
           (Result,
            UC_BOX_V & " " & Name & ": "
            & Trimmed (Pos .. Trimmed'Last));
      else
         Append
           (Result,
            "" & ASCII.LF & UC_BOX_V & " "
            & Trimmed (Pos .. Trimmed'Last));
      end if;
      return To_String (Result);
   end Format_Tool_Field;

end Coyote_App.Utils;
