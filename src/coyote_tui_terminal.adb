--  Coyote_TUI_Terminal body — pragma Import wrappers for the residual
--  C helpers in coyote_tui_terminal_c.c.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Interfaces;
with Interfaces.C;  use Interfaces.C;
package body Coyote_TUI_Terminal is

   --  ── Internal C bindings ───────────────────────────────────────────────
   function C_Wcwidth
     (CP : Interfaces.C.unsigned) return Interfaces.C.int;
   pragma Import (C, C_Wcwidth, "tui_wcwidth");


   function C_Is_TTY return Interfaces.C.int;
   pragma Import (C, C_Is_TTY, "tui_stdout_isatty");

   function C_Make_Tempfile
     (Path : in out Tmp_Path_Buf;
      Cap  :        Interfaces.C.int) return Interfaces.C.int;
   pragma Import (C, C_Make_Tempfile, "tui_make_tempfile");

   procedure C_Close_FD (FD : Interfaces.C.int);
   pragma Import (C, C_Close_FD, "tui_close_fd");

   --  ── Is_TTY ────────────────────────────────────────────────────────────

   function Is_TTY return Boolean is
   begin
      return C_Is_TTY /= 0;
   end Is_TTY;

   --  ── Make_Tempfile ─────────────────────────────────────────────────────

   procedure Make_Tempfile
     (Path : out Tmp_Path_Buf;
      FD   : out Integer)
   is
      Buf    : Tmp_Path_Buf  := (others => Interfaces.C.char'Val (0));
      Raw_FD : Interfaces.C.int := 0;
   begin
      Raw_FD := C_Make_Tempfile (Buf, Interfaces.C.int (TMP_PATH_CAP));
      Path   := Buf;
      FD     := Integer (Raw_FD);
   end Make_Tempfile;

   --  ── Close_FD ─────────────────────────────────────────────────────────

   procedure Close_FD (FD : Integer) is
   begin
      C_Close_FD (Interfaces.C.int (FD));
   end Close_FD;

   --  ── Wcwidth ───────────────────────────────────────────────────────────

   function Wcwidth (CP : Natural) return Integer is
   begin
      return Integer (C_Wcwidth (Interfaces.C.unsigned (CP)));
   end Wcwidth;

   --  ── Utf8_Display_Width ────────────────────────────────────────────────

   function Utf8_Display_Width (S : String) return Natural is
      use Interfaces;
      Width : Natural := 0;
      I     : Natural := S'First;
      CP    : Unsigned_32;
      B0    : Unsigned_32;
   begin
      while I <= S'Last loop
         B0 := Unsigned_32 (Character'Pos (S (I)));
         if B0 < 16#80# then
            CP := B0;
            I  := I + 1;
         elsif B0 < 16#E0# then
            exit when I + 1 > S'Last;
            CP := (B0 and 16#1F#) * 16#40#
                  + (Unsigned_32 (Character'Pos (S (I + 1))) and 16#3F#);
            I  := I + 2;
         elsif B0 < 16#F0# then
            exit when I + 2 > S'Last;
            CP := (B0 and 16#0F#) * 16#1000#
                  + (Unsigned_32 (Character'Pos (S (I + 1))) and 16#3F#) * 16#40#
                  + (Unsigned_32 (Character'Pos (S (I + 2))) and 16#3F#);
            I  := I + 3;
         else
            exit when I + 3 > S'Last;
            CP := (B0 and 16#07#) * 16#40000#
                  + (Unsigned_32 (Character'Pos (S (I + 1))) and 16#3F#) * 16#1000#
                  + (Unsigned_32 (Character'Pos (S (I + 2))) and 16#3F#) * 16#40#
                  + (Unsigned_32 (Character'Pos (S (I + 3))) and 16#3F#);
            I  := I + 4;
         end if;
         declare
            W : constant Integer := Wcwidth (Natural (CP));
         begin
            if W > 0 then
               Width := Width + Natural (W);
            end if;
         end;
      end loop;
      return Width;
   end Utf8_Display_Width;

end Coyote_TUI_Terminal;
