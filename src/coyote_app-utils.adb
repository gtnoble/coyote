--  Coyote_App.Utils body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with GNAT.SHA256;
with GNATCOLL.JSON;          use GNATCOLL.JSON;
with GNATCOLL.OS.FS;
with GNATCOLL.OS.Process;
with Interfaces;             use Interfaces;
with Nine_P;                 use Nine_P;
with Session_Lister;         use Session_Lister;

package body Coyote_App.Utils is

   --  ── String utilities ─────────────────────────────────────────────────

   --  ── Sanitize_UTF8 ─────────────────────────────────────────────────────

   function Sanitize_UTF8 (Text : String) return String is
      Result       : Unbounded_String;
      I            : Natural := Text'First;
      Replacement : constant String := Character'Val (16#EF#)
                                      & Character'Val (16#BF#)
                                      & Character'Val (16#BD#);  --  U+FFFD
   begin
      while I <= Text'Last loop
         declare
            C : constant Character  := Text (I);
            B : constant Natural    := Character'Pos (C);
         begin
            --  ASCII (0x00..0x7F): single byte, always valid.
            if B <= 16#7F# then
               Append (Result, C);
               I := I + 1;

            --  2-byte sequence leader (0xC2..0xDF).
            --  0xC0 and 0xC1 are excluded — they can only encode overlong
            --  sequences (would represent ASCII in two bytes).
            elsif B >= 16#C2# and then B <= 16#DF# then
               if I + 1 <= Text'Last
                 and then Character'Pos (Text (I + 1)) >= 16#80#
                 and then Character'Pos (Text (I + 1)) <= 16#BF#
               then
                  Append (Result, C);
                  Append (Result, Text (I + 1));
                  I := I + 2;
               else
                  Append (Result, Replacement);
                  I := I + 1;
               end if;

            --  3-byte sequence leader (0xE0..0xEF).
            elsif B >= 16#E0# and then B <= 16#EF# then
               if I + 2 <= Text'Last
                 and then Character'Pos (Text (I + 1)) >= 16#80#
                 and then Character'Pos (Text (I + 1)) <= 16#BF#
                 and then Character'Pos (Text (I + 2)) >= 16#80#
                 and then Character'Pos (Text (I + 2)) <= 16#BF#
                 and then (B /= 16#E0#
                           or else Character'Pos (Text (I + 1)) >= 16#A0#)
                 and then (B /= 16#ED#
                           or else Character'Pos (Text (I + 1)) <= 16#9F#)
               then
                  Append (Result, C);
                  Append (Result, Text (I + 1));
                  Append (Result, Text (I + 2));
                  I := I + 3;
               else
                  Append (Result, Replacement);
                  I := I + 1;
               end if;

            --  4-byte sequence leader (0xF0..0xF4).
            --  0xF5..0xF7 would encode code points beyond U+10FFFF and are
            --  excluded; 0xF8..0xFF are original UTF-8 spec bytes that are
            --  never valid.
            elsif B >= 16#F0# and then B <= 16#F4# then
               if I + 3 <= Text'Last
                 and then Character'Pos (Text (I + 1)) >= 16#80#
                 and then Character'Pos (Text (I + 1)) <= 16#BF#
                 and then Character'Pos (Text (I + 2)) >= 16#80#
                 and then Character'Pos (Text (I + 2)) <= 16#BF#
                 and then Character'Pos (Text (I + 3)) >= 16#80#
                 and then Character'Pos (Text (I + 3)) <= 16#BF#
                 and then (B /= 16#F0#
                           or else Character'Pos (Text (I + 1)) >= 16#90#)
                 and then (B /= 16#F4#
                           or else Character'Pos (Text (I + 1)) <= 16#8F#)
               then
                  Append (Result, C);
                  Append (Result, Text (I + 1));
                  Append (Result, Text (I + 2));
                  Append (Result, Text (I + 3));
                  I := I + 4;
               else
                  Append (Result, Replacement);
                  I := I + 1;
               end if;

            --  Continuation byte without a leader (0x80..0xBF),
            --  overlong leaders (0xC0, 0xC1), out-of-range leaders
            --  (0xF5..0xFF): all invalid.
            else
               Append (Result, Replacement);
               I := I + 1;
            end if;
         end;
      end loop;
      return To_String (Result);
   end Sanitize_UTF8;

   package body UTF8_Stream is

      Replacement : constant String := Character'Val (16#EF#)
                                      & Character'Val (16#BF#)
                                      & Character'Val (16#BD#);

      function Is_Continuation (C : Character) return Boolean is
         B : constant Natural := Character'Pos (C);
      begin
         return B >= 16#80# and then B <= 16#BF#;
      end Is_Continuation;

      function Sequence_Length (C : Character) return Natural is
         B : constant Natural := Character'Pos (C);
      begin
         if B <= 16#7F# then
            return 1;
         elsif B >= 16#C2# and then B <= 16#DF# then
            return 2;
         elsif B >= 16#E0# and then B <= 16#EF# then
            return 3;
         elsif B >= 16#F0# and then B <= 16#F4# then
            return 4;
         else
            return 0;
         end if;
      end Sequence_Length;

      function Valid_Sequence
        (Data : String; First : Positive; Length : Positive)
         return Boolean
      is
         B : constant Natural := Character'Pos (Data (First));
      begin
         if Length = 1 then
            return B <= 16#7F#;
         elsif Length = 2 then
            return Is_Continuation (Data (First + 1));
         elsif Length = 3 then
            return Is_Continuation (Data (First + 1))
              and then Is_Continuation (Data (First + 2))
              and then (B /= 16#E0#
                        or else Character'Pos (Data (First + 1)) >= 16#A0#)
              and then (B /= 16#ED#
                        or else Character'Pos (Data (First + 1)) <= 16#9F#);
         elsif Length = 4 then
            return Is_Continuation (Data (First + 1))
              and then Is_Continuation (Data (First + 2))
              and then Is_Continuation (Data (First + 3))
              and then (B /= 16#F0#
                        or else Character'Pos (Data (First + 1)) >= 16#90#)
              and then (B /= 16#F4#
                        or else Character'Pos (Data (First + 1)) <= 16#8F#);
         else
            return False;
         end if;
      end Valid_Sequence;

      procedure Reset (S : in out Instance) is
      begin
         S.Pending := Null_Unbounded_String;
      end Reset;

      procedure Feed
        (S      : in out Instance;
         Data   : in     String;
         Output :    out Ada.Strings.Unbounded.Unbounded_String)
      is
         Combined : constant String := To_String (S.Pending) & Data;
         I        : Natural := Combined'First;
      begin
         S.Pending := Null_Unbounded_String;
         Output := Null_Unbounded_String;

         while I <= Combined'Last loop
            declare
               Size      : constant Natural :=
                 Sequence_Length (Combined (I));
               Available : constant Natural := Combined'Last - I + 1;
               Check_End : constant Natural :=
                 (if Size > 0
                  then Natural'Min (Combined'Last, I + Size - 1)
                  else I);
               Bad       : Boolean := False;
            begin
               if Size = 0 then
                  Append (Output, Replacement);
                  I := I + 1;
               elsif Size = 1 then
                  Append (Output, Combined (I));
                  I := I + 1;
               else
                  for J in I + 1 .. Check_End loop
                     if not Is_Continuation (Combined (J)) then
                        Bad := True;
                        exit;
                     end if;
                  end loop;

                  if Bad then
                     Append (Output, Replacement);
                     I := I + 1;
                  elsif Available < Size then
                     S.Pending := To_Unbounded_String
                       (Combined (I .. Combined'Last));
                     exit;
                  elsif Valid_Sequence (Combined, I, Size) then
                     Append (Output, Combined (I .. I + Size - 1));
                     I := I + Size;
                  else
                     Append (Output, Replacement);
                     I := I + 1;
                  end if;
               end if;
            end;
         end loop;
      end Feed;

      procedure Flush
        (S      : in out Instance;
         Output :    out Ada.Strings.Unbounded.Unbounded_String)
      is
      begin
         if Length (S.Pending) > 0 then
            Output := To_Unbounded_String (Replacement);
         else
            Output := Null_Unbounded_String;
         end if;
         Reset (S);
      end Flush;

   end UTF8_Stream;

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
      Turn_N     : out Positive;
      Step_N     : out Natural) return Boolean
   is
      Prefix_End : constant Natural :=
        Data'First + Pid_Prefix'Length - 1;
      Last_Slash : Natural := 0;
      Step_Slash : Natural := 0;
   begin
      if Data'Length <= Pid_Prefix'Length
        or else Data (Data'First .. Prefix_End) /= Pid_Prefix
      then
         return False;
      end if;

      --  Find the last slash (the Turn_N separator).  Walk backwards
      --  from the end so we can then check whether there is a second
      --  slash for an optional /Step_N suffix.
      for I in reverse Prefix_End + 1 .. Data'Last loop
         if Data (I) = '/' then
            if Last_Slash = 0 then
               Last_Slash := I;
            else
               Step_Slash := I;
               exit;
            end if;
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
           (if Step_Slash > 0
            then Data (Prefix_End + 1 .. Step_Slash - 1)
            else Data (Prefix_End + 1 .. Last_Slash - 1));
         Turn_Text : constant String :=
           (if Step_Slash > 0
            then Data (Step_Slash + 1 .. Last_Slash - 1)
            else Data (Last_Slash + 1 .. Data'Last));
         Step_Text : constant String :=
           (if Step_Slash > 0
            then Data (Last_Slash + 1 .. Data'Last)
            else "");
         Turn      : Positive;
         Step      : Natural := 0;
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

         if Step_Text'Length > 0 then
            begin
               Step := Natural'Value (Step_Text);
            exception
               when Constraint_Error =>
                  return False;
            end;
         end if;

         UUID   := To_Unbounded_String (UUID_Text);
         Turn_N := Turn;
         Step_N := Step;
         return True;
      end;
   end Parse_Fork_Token;

   function Hash_Tool_Id (Tool_Id : String) return String is
   begin
      return GNAT.SHA256.Digest (Tool_Id) (1 .. 16);
   end Hash_Tool_Id;

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
      Session_Cost_Dmil : Natural := 0;
      Stop_Reason_Text : String  := "") return String
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
      if Stop_Reason_Text'Length > 0 then
         if Length (Parts) > 0 then
            Append (Parts, " | ");
         end if;
         Append (Parts, Stop_Reason_Text);
      end if;
      return
        (if Length (Parts) > 0
         then "[" & To_String (Parts) & "]"
         else "");
   end Format_Turn_Summary;

   function Format_Turn_Footer_Display
     (Input_Tokens      : Natural := 0;
      Output_Tokens     : Natural := 0;
      Ctx_Window        : Natural := 0;
      Model_Text        : String  := "";
      Turn_Cost_Dmil    : Natural := 0;
      Session_Cost_Dmil : Natural := 0;
      Stop_Reason_Text : String  := "";
      Is_Step           : Boolean := False) return String
   is
      Summary : constant String :=
        Format_Turn_Summary
          (Input_Tokens      => Input_Tokens,
           Output_Tokens     => Output_Tokens,
           Ctx_Window        => Ctx_Window,
           Model_Text        => Model_Text,
           Turn_Cost_Dmil    => Turn_Cost_Dmil,
           Session_Cost_Dmil => Session_Cost_Dmil,
           Stop_Reason_Text => Stop_Reason_Text);
      Sep     : constant String :=
        (if Is_Step
         then Str_Repeat (UC_HORIZ, 60)
         else Str_Repeat (UC_DBL_H, 60));
   begin
      return ASCII.LF & ASCII.LF
             & (if Summary'Length > 0 then Summary & " " else "")
             & ASCII.LF
             & Sep
             & ASCII.LF & ASCII.LF;
   end Format_Turn_Footer_Display;

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

   --  ── Format_Session_List ──────────────────────────────────────────────

   function Format_Session_List
     (Sessions : Session_Lister.Session_Vectors.Vector) return String
   is

      --  ↳  U+21B3 DOWNWARDS ARROW WITH TIP RIGHTWARDS
      UC_HOOK_R : constant String :=
        Character'Val (16#E2#) & Character'Val (16#86#)
        & Character'Val (16#B3#);

      --  ⎇  U+2387 ALTERNATIVE KEY SYMBOL (branch/fork)
      UC_FORK_R : constant String :=
        Character'Val (16#E2#) & Character'Val (16#8E#)
        & Character'Val (16#87#);

      Result : Unbounded_String;

      --  Render one session and, recursively, all of its descendants.
      --  Depth = 0 means top-level (no indent); each additional level adds
      --  two spaces before a connector: "↳ " for subagents, "⎇ " for forks.
      procedure Render_Session
        (Info  : Session_Info;
         Depth : Natural)
      is
         Connector : constant String :=
           (if Info.Is_Fork then UC_FORK_R else UC_HOOK_R);
         Indent    : constant String :=
           (if Depth = 0 then ""
            else Str_Repeat ("  ", Depth) & Connector & " ");
      begin
         Append
           (Result,
            Indent
            & "coyote-session+" & To_String (Info.UUID)
            & ASCII.HT & To_String (Info.Name)
            & ASCII.HT & To_String (Info.Date)
            & ASCII.HT & To_String (Info.Snippet)
            & ASCII.LF);

         --  Render direct children in input order.
         for Child of Sessions loop
            if To_String (Child.Parent_Id) = To_String (Info.UUID) then
               Render_Session (Child, Depth + 1);
            end if;
         end loop;
      end Render_Session;

      --  Return True when the session's parent UUID is present in Sessions.
      function Parent_In_List (Info : Session_Info) return Boolean is
      begin
         if Length (Info.Parent_Id) = 0 then
            return False;
         end if;

         for Other of Sessions loop
            if To_String (Other.UUID) = To_String (Info.Parent_Id) then
               return True;
            end if;
         end loop;

         return False;
      end Parent_In_List;

   begin
      Append
        (Result,
         "# Button-3 any coyote-session+ token to load that session."
         & ASCII.LF & ASCII.LF);

      --  Render roots: sessions with no parent, or whose parent UUID does
      --  not appear in this list (e.g. a subagent of a cross-CWD session).
      for Info of Sessions loop
         if not Parent_In_List (Info) then
            Render_Session (Info, 0);
         end if;
      end loop;

      return To_String (Result);
   end Format_Session_List;
   --  ── Thinking-text collapse ───────────────────────────────────────────


   function Collapse_Thinking_Delta (Text : String) return String is
      use Ada.Strings.Unbounded;
      Result     : Unbounded_String;
      I          : Natural := Text'First;
      First_NZ   : Natural := 0;
      Last_NZ    : Natural := 0;
   begin
      --  Find first and last positions that are not LF, CR, or HT.
      --  Spaces are treated as content (they carry word-boundary
      --  information from providers like Anthropic).
      for J in Text'Range loop
         if Text (J) /= ASCII.LF
           and then Text (J) /= ASCII.CR
           and then Text (J) /= ASCII.HT
         then
            if First_NZ = 0 then
               First_NZ := J;
            end if;
            Last_NZ := J;
         end if;
      end loop;

      --  If all LF/CR/HT (or empty), return empty.
      if First_NZ = 0 then
         return "";
      end if;

      --  Process trimmed text: collapse single newlines to spaces,
      --  but preserve paragraph breaks (\n\n).
      I := First_NZ;
      while I <= Last_NZ loop
         if Text (I) = ASCII.LF or else Text (I) = ASCII.CR then
            --  Check for paragraph break: \n\n or \r\n\r\n or similar.
            declare
               J : Natural := I + 1;
               Found_Another_LF : Boolean := False;
            begin
               --  Skip any CR/LF after the current one.
               while J <= Last_NZ
                 and then (Text (J) = ASCII.LF or else Text (J) = ASCII.CR)
               loop
                  if Text (J) = ASCII.LF then
                     Found_Another_LF := True;
                  end if;
                  J := J + 1;
               end loop;

               --  If we found a second LF (indicating \n\n or \r\r or mixed),
               --  it's a paragraph break: emit it.
               if Found_Another_LF then
                  Append (Result, "" & ASCII.LF & ASCII.LF);
                  I := J;
               else
                  --  Single newline: collapse to space.
                  Append (Result, " ");
                  I := I + 1;
               end if;
            end;
         else
            Append (Result, Text (I .. I));
            I := I + 1;
         end if;
      end loop;

      return To_String (Result);
   end Collapse_Thinking_Delta;
   --  ── Streaming thinking tokenizer ────────────────────────────────────

   package body Thinking_Tokenizer is

      --  ── Feed ─────────────────────────────────────────────────────────

      procedure Feed
        (T      : in out Instance;
         Delt   : in     String;
         Output :    out Ada.Strings.Unbounded.Unbounded_String)
      is
         B : constant String := To_String (T.Buf) & Delt;
         I : Natural := B'First;
      begin
         Output := Null_Unbounded_String;

         if B'Length = 0 then
            return;
         end if;

         --  Skip leading whitespace before any content has been emitted.
         if not T.Started then
            while I <= B'Last
              and then (B (I) = ASCII.LF
                        or else B (I) = ASCII.CR
                        or else B (I) = ASCII.HT)
            loop
               I := I + 1;
            end loop;
            if I > B'Last then
               --  All whitespace so far; buffer nothing for next call.
               T.Buf := Null_Unbounded_String;
               return;
            end if;
            T.Started := True;
         end if;

         --  Process content, stopping before a trailing single newline
         --  that may be the first half of a paragraph break.
         declare
            Last_Safe : Natural := B'Last;
         begin
            --  If the buffer ends with a single newline (not part of
            --  a \n\n pair), hold it back for the next Feed call.
            if B'Last > 0
              and then (B (B'Last) = ASCII.LF or else B (B'Last) = ASCII.CR)
            then
               --  Walk back to see if this is \n\n or just \n.
               declare
                  J : Natural := B'Last - 1;
                  Found_Prior_LF : Boolean := False;
               begin
                  while J >= I
                    and then (B (J) = ASCII.LF
                              or else B (J) = ASCII.CR)
                  loop
                     if B (J) = ASCII.LF then
                        Found_Prior_LF := True;
                        exit;  --  \n\n or similar; keep both
                     end if;
                     J := J - 1;
                  end loop;

                  if not Found_Prior_LF then
                     --  Single trailing newline: hold it back.
                     Last_Safe := B'Last - 1;
                     while Last_Safe >= I
                       and then (B (Last_Safe) = ASCII.HT)
                     loop
                        Last_Safe := Last_Safe - 1;
                     end loop;
                  end if;
               end;
            end if;

            if I > Last_Safe then
               --  All remaining text is trailing whitespace we're holding.
               T.Buf := To_Unbounded_String (B (I .. B'Last));
               return;
            end if;

            --  Emit the safe range: collapse single newlines to spaces,
            --  preserve paragraph breaks.
            while I <= Last_Safe loop
               if B (I) = ASCII.LF or else B (I) = ASCII.CR then
                  declare
                     J          : Natural := I + 1;
                     Second_LF  : Boolean := False;
                  begin
                     while J <= Last_Safe
                       and then (B (J) = ASCII.LF
                                 or else B (J) = ASCII.CR
                                 or else B (J) = ASCII.HT)
                     loop
                        if B (J) = ASCII.LF then
                           Second_LF := True;
                        end if;
                        J := J + 1;
                     end loop;

                     if Second_LF then
                        --  Paragraph break.
                        Append (Output, "" & ASCII.LF & ASCII.LF);
                        I := J;
                     else
                        --  Single newline: collapse to space.
                        Append (Output, " ");
                        I := I + 1;
                     end if;
                  end;
               else
                  Append (Output, B (I .. I));
                  I := I + 1;
               end if;
            end loop;

            --  Buffer trailing text for next call.
            if Last_Safe < B'Last then
               T.Buf := To_Unbounded_String (B (Last_Safe + 1 .. B'Last));
            else
               T.Buf := Null_Unbounded_String;
            end if;
         end;
      end Feed;

      --  ── Flush ────────────────────────────────────────────────────────

      procedure Flush
        (T      : in out Instance;
         Output :    out Ada.Strings.Unbounded.Unbounded_String)
      is
         B : constant String := To_String (T.Buf);
      begin
         Output := Null_Unbounded_String;
         if B'Length = 0 then
            return;
         end if;

         --  Strip trailing LF, CR, and HT from the buffer.
         --  A single trailing newline was held back from the last
         --  Feed and should now be discarded.
         declare
            Last : Natural := B'Last;
         begin
            while Last >= B'First
              and then (B (Last) = ASCII.LF
                        or else B (Last) = ASCII.CR
                        or else B (Last) = ASCII.HT)
            loop
               Last := Last - 1;
            end loop;

            if Last >= B'First then
               Output := To_Unbounded_String (B (B'First .. Last));
            end if;
         end;
      end Flush;

      --  ── Reset ───────────────────────────────────────────────────────

      procedure Reset (T : in out Instance) is
      begin
         T.Buf     := Null_Unbounded_String;
         T.Started := False;
      end Reset;

   end Thinking_Tokenizer;
end Coyote_App.Utils;
