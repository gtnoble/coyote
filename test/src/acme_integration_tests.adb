with AUnit.Assertions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with GNATCOLL.OS.FS;
with GNATCOLL.OS.Process;    use GNATCOLL.OS.Process;
with Nine_P;                 use Nine_P;
with Nine_P.Client;          use Nine_P.Client;
with Acme;
with Acme.Window;
with Acme.Event_Parser;
with Acme.Raw_Events;
with Coyote_App;
with Coyote_App.Dispatch;    use Coyote_App.Dispatch;

package body Acme_Integration_Tests is

   use AUnit.Assertions;

   function Acme_Running return Boolean is
   begin
      declare
         FS : Nine_P.Client.Fs := Ns_Mount ("acme");
         pragma Unreferenced (FS);
      begin
         return True;
      end;
   exception
      when others =>
         return False;
   end Acme_Running;

   --  Natural'Image without the leading space.
   function Natural_Image (N : Natural) return String is
      Image : constant String := Natural'Image (N);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end Natural_Image;

   function Bytes_To_String (Data : Byte_Array) return String is
   begin
      if Data'Length = 0 then
         return "";
      end if;

      return Result : String (1 .. Data'Length) do
         for I in Data'Range loop
            Result (I - Data'First + 1) := Character'Val (Data (I));
         end loop;
      end return;
   end Bytes_To_String;

   function First_Token (Text : String) return String is
      Start : Natural := Text'First;
   begin
      if Text'Length = 0 then
         return "";
      end if;

      while Start <= Text'Last
        and then Text (Start) in ' ' | ASCII.LF | ASCII.CR | ASCII.HT
      loop
         Start := Start + 1;
      end loop;

      if Start > Text'Last then
         return "";
      end if;

      declare
         Stop : Natural := Start;
      begin
         while Stop <= Text'Last
           and then Text (Stop)
                      not in ' ' | ASCII.LF | ASCII.CR | ASCII.HT
         loop
            Stop := Stop + 1;
         end loop;
         return Text (Start .. Stop - 1);
      end;
   end First_Token;

   function Read_Path
     (FS   : not null access Nine_P.Client.Fs;
      Path : String) return String
   is
      F    : aliased Nine_P.Client.File := Open (FS, Path, O_READ);
      Data : constant Byte_Array := Read (F'Access);
   begin
      return Bytes_To_String (Data);
   end Read_Path;

   function Read_Window_File
     (FS   : not null access Nine_P.Client.Fs;
      Id   : Acme.Window_Id;
      File : String) return String
   is
   begin
      return Read_Path (FS, Acme.Win_File_Path (Id, File));
   end Read_Window_File;

   procedure Write_Window_File
     (FS   : not null access Nine_P.Client.Fs;
      Id   : Acme.Window_Id;
      File : String;
      Data : String)
   is
      F     : aliased Nine_P.Client.File :=
        Open (FS, Acme.Win_File_Path (Id, File), O_WRITE);
      Dummy : constant Natural := Write (F'Access, Data);
      pragma Unreferenced (Dummy);
   begin
      null;
   end Write_Window_File;

   procedure Clear_Body
     (Win : in out Acme.Window.Win;
      FS  : not null access Nine_P.Client.Fs)
   is
   begin
      Acme.Window.Replace_Match (Win, FS, "1,$", "");
   end Clear_Body;

   function Index_Contains_Window_Id
     (Index_Text : String;
      Id         : Acme.Window_Id) return Boolean
   is
      Target     : constant String := Natural_Image (Id);
      Line_Start : Natural := Index_Text'First;
      Line_End   : Natural;
   begin
      if Index_Text'Length = 0 then
         return False;
      end if;

      while Line_Start <= Index_Text'Last loop
         Line_End := Line_Start;
         while Line_End <= Index_Text'Last
           and then Index_Text (Line_End) /= ASCII.LF
         loop
            Line_End := Line_End + 1;
         end loop;

         if Line_End > Line_Start
           and then First_Token
                      (Index_Text (Line_Start .. Line_End - 1)) = Target
         then
            return True;
         end if;

         Line_Start := Line_End + 1;
      end loop;

      return False;
   end Index_Contains_Window_Id;

   --  Run 9p read and return the output as a String.
   function Read_Via_9p (Path : String) return String is
      use GNATCOLL.OS.FS;
      Stdout_R, Stdout_W : File_Descriptor;
      Args               : Argument_List;
      Handle             : Process_Handle;
   begin
      Open_Pipe (Stdout_R, Stdout_W);
      Args.Append ("/usr/local/plan9/bin/9p");
      Args.Append ("read");
      Args.Append (Path);
      Handle := Start (Args   => Args,
                       Stdout => Stdout_W,
                       Stderr => Null_FD);
      Close (Stdout_W);
      declare
         Result : constant Unbounded_String :=
           GNATCOLL.OS.FS.Read (Stdout_R);
         Dummy  : constant Integer := Wait (Handle);
         pragma Unreferenced (Dummy);
      begin
         Close (Stdout_R);
         return To_String (Result);
      end;
   end Read_Via_9p;

   --  ── New_Win ───────────────────────────────────────────────────────────

   procedure Test_New_Win_Has_Valid_Id (T : in out Test) is
      pragma Unreferenced (T);
   begin
      if not Acme_Running then
         return;
      end if;
      declare
         FS  : aliased Nine_P.Client.Fs := Ns_Mount ("acme");
         Win : Acme.Window.Win          :=
           Acme.Window.New_Win (FS'Access);
      begin
         --  A usable window ID must resolve to a live ctl file.
         declare
            Id_String : constant String :=
              Natural_Image (Acme.Window.Id (Win));
            Ctl       : constant String :=
              Read_Via_9p ("acme/" & Id_String & "/ctl");
         begin
            Assert (Ctl'Length > 0,
                    "9p should see the new window's ctl file");
         end;
         Acme.Window.Delete (Win, FS'Access);
      end;
   end Test_New_Win_Has_Valid_Id;

   --  ── Append visible via 9p ────────────────────────────────────────────

   procedure Test_Append_Visible_Via_9p (T : in out Test) is
      pragma Unreferenced (T);
      Marker : constant String := "acme_ada_test_content";
   begin
      if not Acme_Running then
         return;
      end if;
      declare
         FS  : aliased Nine_P.Client.Fs := Ns_Mount ("acme");
         Win : Acme.Window.Win          :=
           Acme.Window.New_Win (FS'Access);
         Id  : constant String :=
           Natural_Image (Acme.Window.Id (Win));
      begin
         Acme.Window.Append (Win, FS'Access, Marker);
         --  Verify via 9p
         declare
            Body_Via_9p : constant String :=
              Read_Via_9p ("acme/" & Id & "/body");
         begin
            Assert
              (Ada.Strings.Fixed.Index (Body_Via_9p, Marker) > 0,
               "9p should see text appended by Acme.Window.Append");
         end;
         Acme.Window.Delete (Win, FS'Access);
      end;
   end Test_Append_Visible_Via_9p;

   --  ── Append_Tag visible via direct 9P read ───────────────────────────

   procedure Test_Append_Tag_Visible_Via_9p (T : in out Test) is
      pragma Unreferenced (T);
      Marker : constant String := "MyTag";
   begin
      if not Acme_Running then
         return;
      end if;
      declare
         FS        : aliased Nine_P.Client.Fs := Ns_Mount ("acme");
         Verify_FS : aliased Nine_P.Client.Fs := Ns_Mount ("acme");
         Win       : Acme.Window.Win          :=
           Acme.Window.New_Win (FS'Access);
      begin
         Acme.Window.Append_Tag (Win, FS'Access, " " & Marker);
         declare
            Tag_Text : constant String :=
              Read_Window_File
                (Verify_FS'Access, Acme.Window.Id (Win), "tag");
         begin
            Assert
              (Ada.Strings.Fixed.Index (Tag_Text, Marker) > 0,
               "tag file should contain text appended by "
               & "Acme.Window.Append_Tag");
         end;
         Acme.Window.Delete (Win, FS'Access);
      end;
   end Test_Append_Tag_Visible_Via_9p;

   --  ── Set_Name ─────────────────────────────────────────────────────────

   procedure Test_Set_Name (T : in out Test) is
      pragma Unreferenced (T);
      Name : constant String := "/tmp/+ada_test_win";
   begin
      if not Acme_Running then
         return;
      end if;
      declare
         FS  : aliased Nine_P.Client.Fs := Ns_Mount ("acme");
         Win : Acme.Window.Win          :=
           Acme.Window.New_Win (FS'Access);
         Id  : constant String :=
           Natural_Image (Acme.Window.Id (Win));
      begin
         Acme.Window.Set_Name (Win, FS'Access, Name);
         declare
            Tag : constant String :=
              Read_Via_9p ("acme/" & Id & "/tag");
         begin
            Assert
              (Ada.Strings.Fixed.Index (Tag, "+ada_test_win") > 0,
               "tag file should contain the new window name");
         end;
         Acme.Window.Delete (Win, FS'Access);
      end;
   end Test_Set_Name;

   --  ── Replace_Line1 rewrites only the first line ───────────────────────

   procedure Test_Replace_Line1_Only_Rewrites_First_Line
     (T : in out Test)
   is
      pragma Unreferenced (T);
      Body_Text : constant String :=
        "first line" & ASCII.LF
        & "second line" & ASCII.LF
        & "third line" & ASCII.LF;
      First_Line : constant String := "REPLACED";
   begin
      if not Acme_Running then
         return;
      end if;
      declare
         FS        : aliased Nine_P.Client.Fs := Ns_Mount ("acme");
         Verify_FS : aliased Nine_P.Client.Fs := Ns_Mount ("acme");
         Win       : Acme.Window.Win          :=
           Acme.Window.New_Win (FS'Access);
      begin
         Clear_Body (Win, FS'Access);
         Acme.Window.Append (Win, FS'Access, Body_Text);
         Acme.Window.Replace_Line1 (Win, FS'Access, First_Line);
         declare
            Updated_Body : constant String :=
              Acme.Window.Read_Body (Win, Verify_FS'Access);
         begin
            Assert
              (Updated_Body'Length >= First_Line'Length
               and then
                 Updated_Body
                   (Updated_Body'First
                    .. Updated_Body'First + First_Line'Length - 1)
                 = First_Line,
               "Replace_Line1 should rewrite the first line only");
            Assert
              (Ada.Strings.Fixed.Index (Updated_Body, "second line") > 0,
               "Replace_Line1 should preserve the second line");
            Assert
              (Ada.Strings.Fixed.Index (Updated_Body, "third line") > 0,
               "Replace_Line1 should preserve the third line");
         end;
         Acme.Window.Delete (Win, FS'Access);
      end;
   end Test_Replace_Line1_Only_Rewrites_First_Line;

   --  ── Delete removes the window from /index ───────────────────────────

   procedure Test_Delete_Removes_Window_From_Index (T : in out Test) is
      pragma Unreferenced (T);
   begin
      if not Acme_Running then
         return;
      end if;
      declare
         FS        : aliased Nine_P.Client.Fs := Ns_Mount ("acme");
         Verify_FS : aliased Nine_P.Client.Fs := Ns_Mount ("acme");
         Win       : Acme.Window.Win          :=
           Acme.Window.New_Win (FS'Access);
         Win_Id    : constant Acme.Window_Id := Acme.Window.Id (Win);
      begin
         Acme.Window.Delete (Win, FS'Access);
         declare
            Removed : Boolean := False;
         begin
            for Attempt in 1 .. 10 loop
               declare
                  Index_Text : constant String :=
                    Read_Path (Verify_FS'Access, "/index");
               begin
                  Removed :=
                    not Index_Contains_Window_Id (Index_Text, Win_Id);
               end;

               exit when Removed;

               if Attempt < 10 then
                  delay 0.05;
               end if;
            end loop;

            Assert (Removed,
                    "Deleted window id should not appear in acme /index");
         end;
      end;
   end Test_Delete_Removes_Window_From_Index;

   --  ── Read_Body returns the full body text ─────────────────────────────

   procedure Test_Read_Body_Returns_Full_Content (T : in out Test) is
      pragma Unreferenced (T);
      Expected : constant String :=
        "alpha" & ASCII.LF
        & "beta" & ASCII.LF
        & "gamma" & ASCII.LF;
   begin
      if not Acme_Running then
         return;
      end if;
      declare
         FS        : aliased Nine_P.Client.Fs := Ns_Mount ("acme");
         Verify_FS : aliased Nine_P.Client.Fs := Ns_Mount ("acme");
         Win       : Acme.Window.Win          :=
           Acme.Window.New_Win (FS'Access);
      begin
         Clear_Body (Win, FS'Access);
         Acme.Window.Append (Win, FS'Access, Expected);
         declare
            Body_Text : constant String :=
              Acme.Window.Read_Body (Win, Verify_FS'Access);
         begin
            Assert (Body_Text = Expected,
                    "Read_Body should return the full body text");
         end;
         Acme.Window.Delete (Win, FS'Access);
      end;
   end Test_Read_Body_Returns_Full_Content;

   --  ── Read_Chars returns the selected subrange ────────────────────────

   procedure Test_Read_Chars_Returns_Subrange (T : in out Test) is
      pragma Unreferenced (T);
      Full_Text : constant String := "abcdefghij" & ASCII.LF;
      Expected  : constant String := "abcd";
   begin
      if not Acme_Running then
         return;
      end if;
      declare
         FS        : aliased Nine_P.Client.Fs := Ns_Mount ("acme");
         Verify_FS : aliased Nine_P.Client.Fs := Ns_Mount ("acme");
         Win       : Acme.Window.Win          :=
           Acme.Window.New_Win (FS'Access);
      begin
         Clear_Body (Win, FS'Access);
         Acme.Window.Append (Win, FS'Access, Full_Text);
         declare
            Slice : constant String :=
              Acme.Window.Read_Chars (Win, Verify_FS'Access, 0, 4);
         begin
            Assert (Slice = Expected,
                    "Read_Chars should return the requested subrange");
         end;
         Acme.Window.Delete (Win, FS'Access);
      end;
   end Test_Read_Chars_Returns_Subrange;

   --  ── Selection_Text returns empty for a fresh window ───────────────────

   procedure Test_Selection_Empty (T : in out Test) is
      pragma Unreferenced (T);
   begin
      if not Acme_Running then
         return;
      end if;
      declare
         FS  : aliased Nine_P.Client.Fs := Ns_Mount ("acme");
         Win : Acme.Window.Win          :=
           Acme.Window.New_Win (FS'Access);
      begin
         declare
            Sel : constant String :=
              Acme.Window.Selection_Text (Win, FS'Access);
         begin
            Assert (Sel = "",
                    "Fresh window selection should be empty");
         end;
         Acme.Window.Delete (Win, FS'Access);
      end;
   end Test_Selection_Empty;

   --  ── Selection_Text after dot=addr ────────────────────────────────────

   procedure Test_Selection_Text_After_Set_Dot (T : in out Test) is
      pragma Unreferenced (T);
      Content  : constant String := "hello world" & ASCII.LF;
      Expected : constant String := "hello";
   begin
      if not Acme_Running then
         return;
      end if;
      declare
         FS        : aliased Nine_P.Client.Fs := Ns_Mount ("acme");
         Verify_FS : aliased Nine_P.Client.Fs := Ns_Mount ("acme");
         Win       : Acme.Window.Win          :=
           Acme.Window.New_Win (FS'Access);
         Win_Id    : constant Acme.Window_Id := Acme.Window.Id (Win);
      begin
         Clear_Body (Win, FS'Access);
         Acme.Window.Append (Win, FS'Access, Content);
         Write_Window_File (Verify_FS'Access, Win_Id, "addr", "#0,#5");
         Write_Window_File (Verify_FS'Access, Win_Id, "ctl",
                            "dot=addr" & ASCII.LF);
         declare
            Sel : constant String :=
              Acme.Window.Selection_Text (Win, Verify_FS'Access);
         begin
            Assert (Sel = Expected,
                    "Selection_Text should return the active dot text");
         end;
         Acme.Window.Delete (Win, FS'Access);
      end;
   end Test_Selection_Text_After_Set_Dot;

   --  ── Raw event parser with a live event file ───────────────────────────
   --
   --  We create a window then validate that the raw parser can decode
   --  a known-good event byte sequence correctly.

   procedure Test_Raw_Event_From_Live (T : in out Test) is
      pragma Unreferenced (T);
   begin
      if not Acme_Running then
         return;
      end if;
      declare
         FS  : aliased Nine_P.Client.Fs := Ns_Mount ("acme");
         Win : Acme.Window.Win          :=
           Acme.Window.New_Win (FS'Access);

         --  Build a valid raw event: "MX0 4 0 4 Send\n"
         Raw_Event : constant Byte_Array :=
           (Character'Pos ('M'), Character'Pos ('X'),
            Character'Pos ('0'), Character'Pos (' '),
            Character'Pos ('4'), Character'Pos (' '),
            Character'Pos ('0'), Character'Pos (' '),
            Character'Pos ('4'), Character'Pos (' '),
            Character'Pos ('S'), Character'Pos ('e'),
            Character'Pos ('n'), Character'Pos ('d'),
            Character'Pos (ASCII.LF));

         Parser : Acme.Raw_Events.Event_Parser;
         Ev     : Acme.Event_Parser.Event;
      begin
         --  Feed raw bytes directly to the parser (no I/O needed).
         Acme.Raw_Events.Feed (Parser, Raw_Event);
         Assert (Acme.Raw_Events.Next_Event (Parser, Ev),
                 "Parser should decode injected raw event");
         Assert (Ev.C1 = 'M',                  "C1 = M");
         Assert (Ev.C2 = 'X',                  "C2 = X");
         Assert (To_String (Ev.Text) = "Send", "Text = Send");
         Acme.Window.Delete (Win, FS'Access);
      end;
   end Test_Raw_Event_From_Live;

   --  ── Replace_Match: pattern found ─────────────────────────────────────
   --
   --  Write a body containing a unique placeholder token, replace it in-
   --  place, and verify that the substitution is visible and the
   --  surrounding text is preserved.

   procedure Test_Replace_Match_Simple (T : in out Test) is
      pragma Unreferenced (T);
      Before  : constant String := "line one" & ASCII.LF;
      Pending : constant String := "PENDING:abc123ef";
      After   : constant String := ASCII.LF & "line three" & ASCII.LF;
   begin
      if not Acme_Running then
         return;
      end if;
      declare
         FS  : aliased Nine_P.Client.Fs := Ns_Mount ("acme");
         Win : Acme.Window.Win          :=
           Acme.Window.New_Win (FS'Access);
         Id  : constant String :=
           Natural_Image (Acme.Window.Id (Win));
      begin
         Acme.Window.Append (Win, FS'Access,
                             Before & Pending & After);
         Acme.Window.Replace_Match (Win, FS'Access,
                                    "/" & Pending & "/",
                                    "DONE");
         declare
            Body_Text : constant String :=
              Read_Via_9p ("acme/" & Id & "/body");
         begin
            Assert
              (Ada.Strings.Fixed.Index (Body_Text, "DONE") > 0,
               "Replacement text should appear in body");
            Assert
              (Ada.Strings.Fixed.Index (Body_Text, Pending) = 0,
               "Placeholder should be gone after replacement");
            Assert
              (Ada.Strings.Fixed.Index (Body_Text, "line one") > 0,
               "Text before placeholder should be preserved");
            Assert
              (Ada.Strings.Fixed.Index (Body_Text, "line three") > 0,
               "Text after placeholder should be preserved");
         end;
         Acme.Window.Delete (Win, FS'Access);
      end;
   end Test_Replace_Match_Simple;

   --  ── Replace_Match: pattern absent ────────────────────────────────────
   --
   --  Calling Replace_Match when the pattern does not exist should be
   --  silent: no exception, and the body must be unchanged.

   procedure Test_Replace_Match_No_Match (T : in out Test) is
      pragma Unreferenced (T);
      Content : constant String := "unchanged content" & ASCII.LF;
   begin
      if not Acme_Running then
         return;
      end if;
      declare
         FS  : aliased Nine_P.Client.Fs := Ns_Mount ("acme");
         Win : Acme.Window.Win          :=
           Acme.Window.New_Win (FS'Access);
         Id  : constant String :=
           Natural_Image (Acme.Window.Id (Win));
      begin
         Acme.Window.Append (Win, FS'Access, Content);
         --  Pattern that is not present — must not raise.
         Acme.Window.Replace_Match (Win, FS'Access,
                                    "/NOMATCH_XYZ_99/",
                                    "REPLACED");
         declare
            Body_Text : constant String :=
              Read_Via_9p ("acme/" & Id & "/body");
         begin
            Assert
              (Ada.Strings.Fixed.Index (Body_Text, Content) > 0,
               "Original content must be intact after a no-match replace");
            Assert
              (Ada.Strings.Fixed.Index (Body_Text, "REPLACED") = 0,
               "Replacement text must not appear when pattern is absent");
         end;
         Acme.Window.Delete (Win, FS'Access);
      end;
   end Test_Replace_Match_No_Match;

   --  ── Replace_Match: parallel tool blocks ──────────────────────────────
   --
   --  Simulate two tool blocks whose start events arrive before either
   --  end event — the interleaved-parallel case.  Each placeholder is
   --  uniquely identified by a token embedded in the pending-close line,
   --  so closing them out-of-order still leaves the blocks sequential and
   --  correctly attributed.

   procedure Test_Replace_Match_Parallel_Blocks (T : in out Test) is
      pragma Unreferenced (T);
      Tok1     : constant String := "PENDING:tok1a2b3c";
      Tok2     : constant String := "PENDING:tok2d4e5f";
      Block1   : constant String :=
        ASCII.LF & "[tool1]" & ASCII.LF & Tok1 & ASCII.LF;
      Block2   : constant String :=
        ASCII.LF & "[tool2]" & ASCII.LF & Tok2 & ASCII.LF;
   begin
      if not Acme_Running then
         return;
      end if;
      declare
         FS  : aliased Nine_P.Client.Fs := Ns_Mount ("acme");
         Win : Acme.Window.Win          :=
           Acme.Window.New_Win (FS'Access);
         Id  : constant String :=
           Natural_Image (Acme.Window.Id (Win));
      begin
         --  Both tool blocks open before either closes.
         Acme.Window.Append (Win, FS'Access, Block1);
         Acme.Window.Append (Win, FS'Access, Block2);

         --  tool2 finishes first.
         Acme.Window.Replace_Match (Win, FS'Access,
                                    "/" & Tok2 & "/", "DONE2");
         --  tool1 finishes second.
         Acme.Window.Replace_Match (Win, FS'Access,
                                    "/" & Tok1 & "/", "DONE1");

         declare
            Body_Text : constant String :=
              Read_Via_9p ("acme/" & Id & "/body");
            Pos_Tool1 : constant Natural :=
              Ada.Strings.Fixed.Index (Body_Text, "[tool1]");
            Pos_Done1 : constant Natural :=
              Ada.Strings.Fixed.Index (Body_Text, "DONE1");
            Pos_Tool2 : constant Natural :=
              Ada.Strings.Fixed.Index (Body_Text, "[tool2]");
            Pos_Done2 : constant Natural :=
              Ada.Strings.Fixed.Index (Body_Text, "DONE2");
         begin
            Assert (Pos_Tool1 > 0, "[tool1] header present");
            Assert (Pos_Done1 > 0, "DONE1 close present");
            Assert (Pos_Tool2 > 0, "[tool2] header present");
            Assert (Pos_Done2 > 0, "DONE2 close present");

            --  Placeholders must be gone.
            Assert
              (Ada.Strings.Fixed.Index (Body_Text, Tok1) = 0,
               "Placeholder tok1 must be replaced");
            Assert
              (Ada.Strings.Fixed.Index (Body_Text, Tok2) = 0,
               "Placeholder tok2 must be replaced");

            --  Block order in body: tool1 before tool2
            --  (appended in that order; replacements do not reorder).
            Assert (Pos_Tool1 < Pos_Tool2,
                    "[tool1] must appear before [tool2]");
            Assert (Pos_Done1 < Pos_Tool2,
                    "DONE1 must appear before [tool2] header");
            Assert (Pos_Done2 > Pos_Tool2,
                    "DONE2 must appear after [tool2] header");
         end;
         Acme.Window.Delete (Win, FS'Access);
      end;
   end Test_Replace_Match_Parallel_Blocks;

   --  ── Clear: erase content ─────────────────────────────────────────────
   --
   --  Replace_Match ("1,$", "") must remove all existing body text, leaving
   --  the window empty.  This is the first step of the Clear tag command.

   procedure Test_Clear_Body_Erases_Content (T : in out Test) is
      pragma Unreferenced (T);
      Content : constant String :=
        "turn 1 response" & ASCII.LF
        & "turn 2 response" & ASCII.LF;
   begin
      if not Acme_Running then
         return;
      end if;
      declare
         FS  : aliased Nine_P.Client.Fs := Ns_Mount ("acme");
         Win : Acme.Window.Win          :=
           Acme.Window.New_Win (FS'Access);
         Id  : constant String :=
           Natural_Image (Acme.Window.Id (Win));
      begin
         Acme.Window.Append (Win, FS'Access, Content);
         --  Step 1 of the Clear command: erase the whole body.
         Acme.Window.Replace_Match (Win, FS'Access, "1,$", "");
         declare
            Body_Text : constant String :=
              Read_Via_9p ("acme/" & Id & "/body");
         begin
            Assert
              (Ada.Strings.Fixed.Index (Body_Text, "turn 1 response") = 0,
               "Body must not contain old content after Replace_Match "
               & """1,$""");
            Assert
              (Ada.Strings.Fixed.Index (Body_Text, "turn 2 response") = 0,
               "Body must not contain old content after Replace_Match "
               & """1,$""");
         end;
         Acme.Window.Delete (Win, FS'Access);
      end;
   end Test_Clear_Body_Erases_Content;

   --  ── Clear: full two-step sequence ────────────────────────────────────
   --
   --  The Clear tag command is: Replace_Match ("1,$", "") then
   --  Append (status_line & LF).  After the sequence the old conversation
   --  text must be gone and the new status line must be the only content.

   procedure Test_Clear_Body_Restores_Status (T : in out Test) is
      pragma Unreferenced (T);
      --  Sentinel strings that must NOT survive Clear.
      Old_Content : constant String :=
        "old conversation content" & ASCII.LF;
      --  Plain ASCII status marker; avoids raw multi-byte UTF-8 literals.
      Status_Line : constant String :=
        "CLEAR_STATUS_MARKER" & ASCII.LF;
   begin
      if not Acme_Running then
         return;
      end if;
      declare
         FS  : aliased Nine_P.Client.Fs := Ns_Mount ("acme");
         Win : Acme.Window.Win          :=
           Acme.Window.New_Win (FS'Access);
         Id  : constant String :=
           Natural_Image (Acme.Window.Id (Win));
      begin
         Acme.Window.Append (Win, FS'Access, Old_Content);
         --  Replicate the Clear command: erase then write status line.
         Acme.Window.Replace_Match (Win, FS'Access, "1,$", "");
         Acme.Window.Append        (Win, FS'Access, Status_Line);
         declare
            Body_Text : constant String :=
              Read_Via_9p ("acme/" & Id & "/body");
         begin
            Assert
              (Ada.Strings.Fixed.Index (Body_Text,
                                        "old conversation content") = 0,
               "Old content must be absent after the Clear sequence");
            Assert
              (Ada.Strings.Fixed.Index (Body_Text,
                                        "CLEAR_STATUS_MARKER") > 0,
               "Status line must be present after the Clear sequence");
         end;
         Acme.Window.Delete (Win, FS'Access);
      end;
   end Test_Clear_Body_Restores_Status;

   --  ── Clear on an already-empty body ───────────────────────────────────
   --
   --  Invoking the Clear sequence on a window whose body is already empty
   --  must not raise an exception.  Replace_Match silently ignores address
   --  errors; the subsequent Append must still place the status line in the
   --  body.

   procedure Test_Clear_Body_On_Empty_Body (T : in out Test) is
      pragma Unreferenced (T);
      --  Plain ASCII status marker; avoids raw multi-byte UTF-8 literals.
      Status_Line : constant String := "CLEAR_STATUS_MARKER" & ASCII.LF;
   begin
      if not Acme_Running then
         return;
      end if;
      declare
         FS  : aliased Nine_P.Client.Fs := Ns_Mount ("acme");
         Win : Acme.Window.Win          :=
           Acme.Window.New_Win (FS'Access);
         Id  : constant String :=
           Natural_Image (Acme.Window.Id (Win));
      begin
         --  Body is empty — Clear must not raise.
         Acme.Window.Replace_Match (Win, FS'Access, "1,$", "");
         Acme.Window.Append        (Win, FS'Access, Status_Line);
         declare
            Body_Text : constant String :=
              Read_Via_9p ("acme/" & Id & "/body");
         begin
            Assert
              (Ada.Strings.Fixed.Index (Body_Text,
                                        "CLEAR_STATUS_MARKER") > 0,
               "Status line must be present even when body was empty");
         end;
         Acme.Window.Delete (Win, FS'Access);
      end;
   end Test_Clear_Body_On_Empty_Body;

   --  ── Live get_session_stats footer formatting ────────────────────────
   --
   --  The live get_session_stats path calls Append_Live_Turn_Footer,
   --  which must place the bracketed summary and fork token on one line,
   --  then the double-line separator rule on the next line.

   procedure Test_Append_Live_Turn_Footer (T : in out Test) is
      pragma Unreferenced (T);
      Session_Id : constant String :=
        "ca8add79-7902-415c-af1d-b4b4e93bb12b";
      PID        : constant String := "36546";
      --  UC_DBL_H  U+2550
      UC_Dbl_H : constant String :=
        Character'Val (16#E2#)
        & Character'Val (16#95#)
        & Character'Val (16#90#);
   begin
      if not Acme_Running then
         return;
      end if;
      declare
         FS    : aliased Nine_P.Client.Fs := Ns_Mount ("acme");
         Win   : Acme.Window.Win          :=
           Acme.Window.New_Win (FS'Access);
         State : Coyote_App.App_State;
         Id    : constant String :=
           Natural_Image (Acme.Window.Id (Win));
      begin
         State.Set_Session_Id (Session_Id);
         State.Set_Model ("github-copilot/gpt-5.3-codex");
         State.Set_Context_Window (400_000);
         State.Set_Turn_Tokens (24_000, 537);

         Append_Live_Turn_Footer
           (Win   => Win,
            FS    => FS'Access,
            State => State,
            PID   => PID);

         declare
            Body_Text : constant String :=
              Read_Via_9p ("acme/" & Id & "/body");
            Footer    : constant String :=
              "] coyote-fork+" & PID & "/" & Session_Id & "/1";
         begin
            Assert (State.Turn_Count = 1,
                    "Append_Live_Turn_Footer must increment Turn_Count");
            Assert
              (Ada.Strings.Fixed.Index (Body_Text, Footer) > 0,
               "Summary block and fork token must share one line");
            Assert
              (Ada.Strings.Fixed.Index
                 (Body_Text, ASCII.LF & ASCII.LF & "coyote-fork+") = 0,
               "fork token must not start a standalone line when summary "
               & "exists");
            Assert
              (Ada.Strings.Fixed.Index (Body_Text, UC_Dbl_H) > 0,
               "Double-line separator rule must be present");
         end;

         Acme.Window.Delete (Win, FS'Access);
      end;
   end Test_Append_Live_Turn_Footer;

   --  Verify that non-zero Turn_Cost_Dmil and Session_Cost_Dmil produce
   --  "$X.XXXX turn" and "$X.XXXX session" segments in the footer body.
   --  This also exercises Format_Cost and Format_Turn_Summary end-to-end.
   procedure Test_Append_Live_Turn_Footer_With_Cost (T : in out Test) is
      pragma Unreferenced (T);
      Session_Id : constant String :=
        "ca8add79-7902-415c-af1d-b4b4e93bb12b";
      PID        : constant String := "36546";
   begin
      if not Acme_Running then
         return;
      end if;
      declare
         FS    : aliased Nine_P.Client.Fs := Ns_Mount ("acme");
         Win   : Acme.Window.Win          :=
           Acme.Window.New_Win (FS'Access);
         State : Coyote_App.App_State;
         Id    : constant String :=
           Natural_Image (Acme.Window.Id (Win));
      begin
         State.Set_Session_Id (Session_Id);
         State.Set_Model ("github-copilot/gpt-5.3-codex");
         State.Set_Context_Window (400_000);
         State.Set_Turn_Tokens (24_000, 537);
         --  0.0234 dollars per turn; 0.1560 dollars session total.
         State.Set_Turn_Cost (234);
         State.Set_Session_Stats
           (Cost_Dmil   => 1_560,
            Input       => 50_000,
            Output      => 2_000,
            Cache_Read  => 0,
            Cache_Write => 0,
            Total       => 52_000);

         Append_Live_Turn_Footer
           (Win   => Win,
            FS    => FS'Access,
            State => State,
            PID   => PID);

         declare
            Body_Text    : constant String :=
              Read_Via_9p ("acme/" & Id & "/body");
            Turn_Seg     : constant String := "$0.0234 turn";
            Session_Seg  : constant String := "$0.1560 session";
         begin
            Assert
              (Ada.Strings.Fixed.Index (Body_Text, Turn_Seg) > 0,
               "Footer must contain ""$0.0234 turn"" per-turn cost segment");
            Assert
              (Ada.Strings.Fixed.Index (Body_Text, Session_Seg) > 0,
               "Footer must contain ""$0.1560 session"" cumulative cost "
               & "segment");
            --  Both cost segments must appear before the fork token on the
            --  same summary line.
            declare
               Turn_Pos    : constant Natural :=
                 Ada.Strings.Fixed.Index (Body_Text, Turn_Seg);
               Session_Pos : constant Natural :=
                 Ada.Strings.Fixed.Index (Body_Text, Session_Seg);
               Fork_Pos    : constant Natural :=
                 Ada.Strings.Fixed.Index
                   (Body_Text, "coyote-fork+" & PID & "/" & Session_Id & "/1");
            begin
               Assert (Turn_Pos > 0 and then Session_Pos > 0
                       and then Fork_Pos > 0,
                       "All three markers must be present");
               Assert (Turn_Pos < Fork_Pos,
                       "Turn cost must precede fork token");
               Assert (Session_Pos < Fork_Pos,
                       "Session cost must precede fork token");
            end;
         end;

         Acme.Window.Delete (Win, FS'Access);
      end;
   end Test_Append_Live_Turn_Footer_With_Cost;

end Acme_Integration_Tests;
