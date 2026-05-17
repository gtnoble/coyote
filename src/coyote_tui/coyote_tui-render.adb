--  Coyote_TUI.Render body.
--
--  Design note: this body imports Coyote_Ncurses solely to query A_Bold,
--  A_Dim, A_Reverse, and A_Normal integer constants (thin C wrappers around
--  ncurses macros that require no initialisation).  No window or terminal
--  state is touched here.  All output goes through the Sink interface.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Characters.Latin_1;
with Ada.Characters.Handling;
with Ada.Containers.Vectors;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;          use Ada.Strings.Unbounded;
with Interfaces.C;
with Interfaces.C.Strings;
with System;

with Coyote_Cmark;
with Coyote_Ncurses;
with Coyote_App.Utils;               use Coyote_App.Utils;
with Coyote_TUI.Scroll;
with Coyote_TUI.Sink.String_Sink;
with GNATCOLL.JSON;

package body Coyote_TUI.Render is

   LF : constant Character := Ada.Characters.Latin_1.LF;

   --  Colour-pair indices.  Must match what UI_Task initialises at startup.
   PAIR_YELLOW : constant := 1;
   PAIR_RED    : constant := 2;

   --  ── Render_Wrapped_Text ───────────────────────────────────────────────
   --
   --  Emit Text to Output preceded by Prefix on every output line, splitting
   --  only at embedded newline characters.  If Match_Start >= 0 and
   --  Match_Len > 0, the indicated byte range within Text is highlighted.
   --  Returns lines emitted.

   function Render_Wrapped_Text
     (Output      : in out Sink.Instance'Class;
      Text        :        String;
      Prefix      :        String  := "";
      Match_Start :        Integer := -1;
      Match_Len   :        Natural := 0;
      Skip_Lines  :        Natural := 0) return Natural
   is
      A_Rev     : constant Integer := Coyote_Ncurses.A_Reverse;
      Rows_Out  : Natural          := 0;
      Skip_Left : Natural          := Skip_Lines;

      M_First : constant Integer :=
        (if Match_Start >= 0 and then Match_Len > 0
         then Text'First + Match_Start else -1);
      M_Last  : constant Integer :=
        (if M_First >= 0 then M_First + Integer (Match_Len) - 1 else -1);

      procedure Emit_Line (Content : String) is
      begin
         if Skip_Left > 0 then
            Skip_Left := Skip_Left - 1;
            return;
         end if;
         Output.Put (Prefix);
         if M_First >= 0 and then Content'Length > 0 then
            declare
               Hl_First : constant Integer :=
                 Integer'Max (M_First, Content'First);
               Hl_Last  : constant Integer :=
                 Integer'Min (M_Last, Content'Last);
            begin
               if Hl_First <= Hl_Last then
                  if Hl_First > Content'First then
                     Output.Put (Content (Content'First .. Hl_First - 1));
                  end if;
                  Output.Attr_On (A_Rev);
                  Output.Put (Content (Hl_First .. Hl_Last));
                  Output.Attr_Off (A_Rev);
                  if Hl_Last < Content'Last then
                     Output.Put (Content (Hl_Last + 1 .. Content'Last));
                  end if;
               else
                  Output.Put (Content);
               end if;
            end;
         elsif Content'Length > 0 then
            Output.Put (Content);
         end if;
         Output.New_Line;
         Rows_Out := Rows_Out + 1;
      end Emit_Line;

      Line_Start : Natural := Text'First;
      I          : Natural := Text'First;
   begin
      if Text'Length = 0 then
         Emit_Line ("");
         return Rows_Out;
      end if;
      while I <= Text'Last loop
         if Text (I) = LF then
            Emit_Line (Text (Line_Start .. I - 1));
            Line_Start := I + 1;
         end if;
         I := I + 1;
      end loop;
      Emit_Line (Text (Line_Start .. Text'Last));
      return Rows_Out;
   end Render_Wrapped_Text;

   --  ── Render_Markdown_To_Sink ───────────────────────────────────────────

   function Render_Markdown_To_Sink
     (Output     : in out Sink.Instance'Class;
      Text       :        String;
      Cols       :        Positive;
      Use_Color  :        Boolean;
      Skip_Lines :        Natural := 0) return Natural
   is
      use Coyote_Cmark;
      use Interfaces.C;
      use Interfaces.C.Strings;

      A_Bold_V : constant Integer := Coyote_Ncurses.A_Bold;
      A_Dim_V  : constant Integer := Coyote_Ncurses.A_Dim;
      A_Rev_V  : constant Integer := Coyote_Ncurses.A_Reverse;

      Lines_Used : Natural := 0;
      Skip_Left  : Natural := Skip_Lines;

      Max_List_Depth : constant := 8;
      type List_Kind is (Bullet_List, Ordered_List);
      type List_Entry is record
         Kind    : List_Kind;
         Counter : Positive;
      end record;
      type List_Stack_Array is array (1 .. Max_List_Depth) of List_Entry;
      List_Stack  : List_Stack_Array;
      List_Depth  : Natural := 0;
      Quote_Depth : Natural := 0;
      In_Table    : Natural := 0;

      procedure Emit_LF is
      begin
         if Skip_Left > 0 then
            Skip_Left := Skip_Left - 1;
            return;
         end if;
         Output.New_Line;
         Lines_Used := Lines_Used + 1;
      end Emit_LF;

      procedure Put (S : String) is
      begin
         if Skip_Left = 0 then
            Output.Put (S);
         end if;
      end Put;

      procedure Do_On (A : Integer) is
      begin
         if Use_Color and then Skip_Left = 0 then
            Output.Attr_On (A);
         end if;
      end Do_On;

      procedure Do_Off (A : Integer) is
      begin
         if Use_Color and then Skip_Left = 0 then
            Output.Attr_Off (A);
         end if;
      end Do_Off;

      function Literal (Node : Node_Ptr) return String is
         Ptr : constant chars_ptr := Node_Get_Literal (Node);
      begin
         return (if Ptr = Null_Ptr then "" else Value (Ptr));
      end Literal;

      procedure Emit_Lines (S : String; Prefix : String) is
         Line_Start : Positive := S'First;
         J          : Positive;
      begin
         if S'Length = 0 then
            return;
         end if;
         J := S'First;
         while J <= S'Last loop
            if S (J) = LF then
               Put (Prefix);
               Put (S (Line_Start .. J - 1));
               Emit_LF;
               Line_Start := J + 1;
            end if;
            J := J + 1;
         end loop;
         if Line_Start <= S'Last then
            Put (Prefix);
            Put (S (Line_Start .. S'Last));
            Emit_LF;
         end if;
      end Emit_Lines;

      function Type_String (Node : Node_Ptr) return String is
         Ptr : constant chars_ptr := Node_Get_Type_String (Node);
      begin
         return (if Ptr = Null_Ptr then "" else Value (Ptr));
      end Type_String;

      function Cell_Text (N : Node_Ptr) return String is
         use System;
         Result : Unbounded_String;
         Child  : Node_Ptr;
         NT_N   : Node_Type_Int;
      begin
         if N = Null_Address then
            return "";
         end if;
         NT_N := Node_Get_Type (N);
         if NT_N = NODE_TEXT or else NT_N = NODE_CODE then
            Append (Result, Literal (N));
         elsif NT_N = NODE_SOFTBREAK then
            Append (Result, " ");
         else
            Child := Node_First_Child (N);
            while Child /= Null_Address loop
               Append (Result, Cell_Text (Child));
               Child := Node_Next (Child);
            end loop;
         end if;
         return To_String (Result);
      end Cell_Text;

      procedure Render_Table (Table_Node : Node_Ptr) is
         use System;
         Max_Cols_Const : constant := 64;

         package SV is new Ada.Containers.Vectors
           (Index_Type   => Positive,
            Element_Type => Unbounded_String);
         package RV is new Ada.Containers.Vectors
           (Index_Type   => Positive,
            Element_Type => SV.Vector,
            "="          => SV."=");

         Rows       : RV.Vector;
         N_Cols     : Natural := 0;
         subtype Col_Range is Positive range 1 .. Max_Cols_Const;
         type Width_Array is array (Col_Range) of Natural;
         Col_Widths : Width_Array := (others => 0);
         Row_Node   : Node_Ptr;
         Cell_Node  : Node_Ptr;

         procedure Draw_H_Rule (L, M, R : String) is
         begin
            Put (L);
            for C in 1 .. N_Cols loop
               for K in 1 .. Col_Widths (C) + 2 loop
                  Put (UC_HORIZ);
               end loop;
               if C < N_Cols then
                  Put (M);
               end if;
            end loop;
            Put (R);
            Emit_LF;
         end Draw_H_Rule;

         procedure Draw_Row (Row : SV.Vector; Is_Header : Boolean) is
         begin
            if Is_Header then
               Do_On (A_Bold_V);
            end if;
            Put (UC_BOX_V);
            for C in 1 .. N_Cols loop
               Put (" ");
               declare
                  Cell_US : constant Unbounded_String :=
                    (if C <= Positive (Row.Length)
                     then Row.Element (C)
                     else Null_Unbounded_String);
                  S     : constant String  := To_String (Cell_US);
                  Width : constant Natural := Col_Widths (C);
               begin
                  if S'Length > Width then
                     Put (S (S'First .. S'First + Width - 2));
                     Put (UC_ELLIP);
                  else
                     Put (S);
                     for K in 1 .. Width - S'Length loop
                        Put (" ");
                     end loop;
                  end if;
               end;
               Put (" ");
               Put (UC_BOX_V);
            end loop;
            if Is_Header then
               Do_Off (A_Bold_V);
            end if;
            Emit_LF;
         end Draw_Row;

      begin
         Row_Node := Node_First_Child (Table_Node);
         while Row_Node /= Null_Address loop
            declare
               Row_Cells : SV.Vector;
               Col_Idx   : Natural := 0;
            begin
               Cell_Node := Node_First_Child (Row_Node);
               while Cell_Node /= Null_Address loop
                  Col_Idx := Col_Idx + 1;
                  declare
                     C_Text_Val : constant String := Cell_Text (Cell_Node);
                  begin
                     Row_Cells.Append (To_Unbounded_String (C_Text_Val));
                     if Col_Idx <= Max_Cols_Const then
                        if C_Text_Val'Length > Col_Widths (Col_Idx) then
                           Col_Widths (Col_Idx) := C_Text_Val'Length;
                        end if;
                        if Col_Idx > N_Cols then
                           N_Cols := Col_Idx;
                        end if;
                     end if;
                  end;
                  Cell_Node := Node_Next (Cell_Node);
               end loop;
               Rows.Append (Row_Cells);
            end;
            Row_Node := Node_Next (Row_Node);
         end loop;

         if N_Cols = 0 or else Rows.Is_Empty then
            return;
         end if;

         declare
            Border_Overhead : constant Natural := N_Cols + 1 + N_Cols * 2;
            Available       : constant Natural :=
              (if Cols > Border_Overhead then Cols - Border_Overhead else 0);
            Per_Col         : constant Natural :=
              (if Available > 0 and then N_Cols > 0
               then Available / N_Cols else 0);
         begin
            if Per_Col > 0 then
               for C in 1 .. N_Cols loop
                  if Col_Widths (C) > Per_Col then
                     Col_Widths (C) := Per_Col;
                  end if;
               end loop;
            end if;
         end;

         Draw_H_Rule (UC_BOX_TL, UC_BOX_T, UC_BOX_TR);
         for R in 1 .. Positive (Rows.Length) loop
            declare
               Row    : constant SV.Vector := Rows.Element (R);
               Is_Hdr : constant Boolean   :=
                 R = 1
                 and then Integer (Table_Row_Is_Header
                   (Node_First_Child (Table_Node))) /= 0;
            begin
               Draw_Row (Row, Is_Hdr);
               if Is_Hdr then
                  Draw_H_Rule (UC_BOX_L, UC_BOX_X, UC_BOX_R);
               end if;
            end;
         end loop;
         Draw_H_Rule (UC_BOX_BL, UC_BOX_B, UC_BOX_BR);
      end Render_Table;

      C_Text : constant char_array :=
        Interfaces.C.To_C (Text, Append_Nul => True);
      Doc    : Node_Ptr;
      Iter   : Iter_Ptr;
      Ev     : Event_Type_Int;
      Node   : Node_Ptr;
      NT     : Node_Type_Int;
   begin
      Doc  := Parse_Document
                (C_Text, size_t (Text'Length), OPT_DEFAULT);
      Iter := Iter_New (Doc);
      loop
         Ev := Iter_Next (Iter);
         exit when Ev = EVENT_DONE;
         Node := Iter_Get_Node (Iter);
         NT   := Node_Get_Type (Node);

         if In_Table > 0 then
            if Ev = EVENT_EXIT and then Type_String (Node) = "table" then
               In_Table := 0;
            end if;
            goto Next_Event;
         end if;

         if Ev = EVENT_ENTER then

            if NT = NODE_HEADING then
               declare
                  Level : constant Integer :=
                    Integer (Node_Get_Heading_Level (Node));
               begin
                  Do_On (A_Bold_V);
                  for K in 1 .. Level loop
                     Put ("#");
                  end loop;
                  Put (" ");
               end;

            elsif NT = NODE_THEMATIC_BREAK then
               for K in 1 .. Cols loop
                  Put (UC_HORIZ);
               end loop;
               Emit_LF;

            elsif NT = NODE_BLOCK_QUOTE then
               Quote_Depth := Quote_Depth + 1;
               Do_On (A_Dim_V);

            elsif NT = NODE_LIST then
               if List_Depth < Max_List_Depth then
                  List_Depth := List_Depth + 1;
                  if Node_Get_List_Type (Node) = LIST_ORDERED then
                     List_Stack (List_Depth) :=
                       (Kind    => Ordered_List,
                        Counter => Positive (Node_Get_List_Start (Node)));
                  else
                     List_Stack (List_Depth) :=
                       (Kind => Bullet_List, Counter => 1);
                  end if;
               end if;

            elsif NT = NODE_ITEM then
               if List_Depth > 0 then
                  for K in 2 .. List_Depth loop
                     Put ("  ");
                  end loop;
                  case List_Stack (List_Depth).Kind is
                     when Bullet_List =>
                        Put (UC_BULLET & " ");
                     when Ordered_List =>
                        declare
                           N_Img : constant String :=
                             Ada.Strings.Fixed.Trim
                               (Positive'Image
                                  (List_Stack (List_Depth).Counter),
                                Ada.Strings.Left);
                        begin
                           Put (N_Img & ". ");
                           List_Stack (List_Depth).Counter :=
                             List_Stack (List_Depth).Counter + 1;
                        end;
                  end case;
               end if;

            elsif NT = NODE_CODE_BLOCK then
               Do_On (A_Dim_V);
               Emit_Lines (Literal (Node), "  ");
               Do_Off (A_Dim_V);

            elsif NT = NODE_EMPH   then Do_On (A_Dim_V);
            elsif NT = NODE_STRONG then Do_On (A_Bold_V);

            elsif NT = NODE_CODE then
               Do_On (A_Rev_V);
               Put (Literal (Node));
               Do_Off (A_Rev_V);

            elsif NT = NODE_TEXT      then Put (Literal (Node));
            elsif NT = NODE_SOFTBREAK then Put (" ");
            elsif NT = NODE_LINEBREAK then Emit_LF;

            elsif Type_String (Node) = "table" then
               Render_Table (Node);
               In_Table := 1;

            elsif Type_String (Node) = "strikethrough" then
               Do_On (A_Dim_V);
            end if;

         elsif Ev = EVENT_EXIT then

            if    NT = NODE_HEADING then
               Do_Off (A_Bold_V);
               Emit_LF;

            elsif NT = NODE_BLOCK_QUOTE then
               if Quote_Depth > 0 then
                  Quote_Depth := Quote_Depth - 1;
               end if;
               Do_Off (A_Dim_V);

            elsif NT = NODE_PARAGRAPH then
               Emit_LF;
               if List_Depth = 0 and then Quote_Depth = 0 then
                  Emit_LF;
               end if;

            elsif NT = NODE_LIST then
               if List_Depth > 0 then
                  List_Depth := List_Depth - 1;
               end if;

            elsif NT = NODE_EMPH   then Do_Off (A_Dim_V);
            elsif NT = NODE_STRONG then Do_Off (A_Bold_V);

            elsif Type_String (Node) = "strikethrough" then
               Do_Off (A_Dim_V);
            end if;
         end if;
      <<Next_Event>>
      end loop;
      Iter_Free (Iter);
      Node_Free (Doc);
      return (if Lines_Used = 0 then 1 else Lines_Used);
   end Render_Markdown_To_Sink;

   --  ── Measure_Segment ──────────────────────────────────────────────────

   function Measure_Segment
     (S    : Segment;
      Cols : Positive) return Positive
   is
      function NL_Count (Str : String) return Natural is
         N : Natural := 0;
      begin
         for C of Str loop
            if C = LF then
               N := N + 1;
            end if;
         end loop;
         return N;
      end NL_Count;

      Content : constant String := To_String (S.Content);
   begin
      case S.Kind is
         when User_Turn | Steer_Turn | Thinking_Block =>
            return Positive'Max (1, NL_Count (Content) + 1);

         when Assistant_Text =>
            if S.Complete then
               declare
                  Counting : Coyote_TUI.Sink.String_Sink.Instance;
               begin
                  return Positive'Max
                    (1,
                     Render_Markdown_To_Sink
                       (Counting, Content, Cols,
                        Use_Color  => False,
                        Skip_Lines => 0));
               end;
            else
               return Positive'Max (1, NL_Count (Content) + 1);
            end if;

         when Tool_Segment =>
            return Positive'Max
              (1, NL_Count (To_String (S.Tool_Args)) + 3);

         when Turn_Footer | System_Notice =>
            return Positive'Max (1, NL_Count (Content) + 1);
      end case;
   end Measure_Segment;

   --  ── Render_Segment ───────────────────────────────────────────────────

   function Render_Segment
     (S           :        Segment;
      Output      : in out Sink.Instance'Class;
      Cols        :        Positive;
      Use_Color   :        Boolean  := True;
      Skip_Lines  :        Natural  := 0;
      Match_Start :        Integer  := -1;
      Match_Len   :        Natural  := 0) return Natural
   is
      A_Bold_V : constant Integer := Coyote_Ncurses.A_Bold;
      A_Dim_V  : constant Integer := Coyote_Ncurses.A_Dim;
      Content  : constant String  := To_String (S.Content);
   begin
      case S.Kind is

         when User_Turn =>
            if Use_Color then
               Output.Attr_On (A_Bold_V);
            end if;
            declare
               N : constant Natural :=
                 Render_Wrapped_Text
                   (Output, Content,
                    Prefix      => UC_TRI_R & " ",
                    Match_Start => Match_Start,
                    Match_Len   => Match_Len,
                    Skip_Lines  => Skip_Lines);
            begin
               Output.Reset_Attrs;
               return N;
            end;

         when Steer_Turn =>
            if Use_Color then
               Output.Attr_On (A_Bold_V);
            end if;
            declare
               N : constant Natural :=
                 Render_Wrapped_Text
                   (Output, Content,
                    Prefix      => UC_HOOK_L & " ",
                    Match_Start => Match_Start,
                    Match_Len   => Match_Len,
                    Skip_Lines  => Skip_Lines);
            begin
               Output.Reset_Attrs;
               return N;
            end;

         when Assistant_Text =>
            if S.Complete then
               return Render_Markdown_To_Sink
                 (Output, Content, Cols, Use_Color, Skip_Lines);
            else
               return Render_Wrapped_Text
                 (Output, Content,
                  Match_Start => Match_Start,
                  Match_Len   => Match_Len,
                  Skip_Lines  => Skip_Lines);
            end if;

         when Thinking_Block =>
            if Use_Color then
               Output.Attr_On (A_Dim_V);
            end if;
            declare
               N : constant Natural :=
                 Render_Wrapped_Text
                   (Output, Content,
                    Prefix      => UC_BOX_V & " ",
                    Match_Start => Match_Start,
                    Match_Len   => Match_Len,
                    Skip_Lines  => Skip_Lines);
            begin
               Output.Reset_Attrs;
               return N;
            end;

         when Tool_Segment =>
            declare
               Sk   : Natural := Skip_Lines;
               Used : Natural := 0;

               procedure Maybe_Header is
               begin
                  if Sk > 0 then
                     Sk := Sk - 1;
                     return;
                  end if;
                  if Use_Color then
                     Output.Attr_On (A_Bold_V);
                  end if;
                  Output.Put (UC_BOX_TL & " " & UC_GEAR & " "
                              & To_String (S.Tool_Name));
                  Output.New_Line;
                  Output.Reset_Attrs;
                  Used := Used + 1;
               end Maybe_Header;

               procedure Maybe_Status is
               begin
                  if Sk > 0 then
                     Sk := Sk - 1;
                     return;
                  end if;
                  case S.T_Status is
                     when Running =>
                        Output.Put (UC_BOX_BL & " " & UC_ELLIP);
                        Output.New_Line;
                     when Success =>
                        Output.Put (UC_BOX_BL & " " & UC_CHECK);
                        Output.New_Line;
                     when Error =>
                        declare
                           Preview : constant String  := To_String (S.Content);
                           Plen    : constant Natural :=
                             Natural'Min (80, Preview'Length);
                        begin
                           Output.Put
                             (UC_BOX_BL & " " & UC_CROSS & " "
                              & Preview (Preview'First
                                         .. Preview'First + Plen - 1));
                           Output.New_Line;
                        end;
                     when Cancelled =>
                        Output.Put (UC_BOX_BL & " " & UC_CROSS & " cancelled");
                        Output.New_Line;
                  end case;
                  Used := Used + 1;
               end Maybe_Status;

            begin
               Maybe_Header;
               declare
                  use GNATCOLL.JSON;
                  Args_Result : constant Read_Result :=
                    Read (To_String (S.Tool_Args));
                  Args        : constant JSON_Value :=
                    (if Args_Result.Success
                     then Args_Result.Value
                     else Create_Object);
               begin
                  if Args.Kind = JSON_Object_Type then
                     declare
                        procedure Show_Field
                          (Field_Name  : UTF8_String;
                           Field_Value : JSON_Value)
                        is
                           Line  : constant String :=
                             Format_Tool_Field
                               (Field_Name,
                                JSON_Scalar_Image (Field_Value));
                           NLs   : Natural := 0;
                           FLns  : Natural;
                        begin
                           for C of Line loop
                              if C = LF then
                                 NLs := NLs + 1;
                              end if;
                           end loop;
                           FLns := NLs + 1;
                           if Sk > 0 then
                              if Sk >= FLns then
                                 Sk := Sk - FLns;
                              else
                                 Sk := 0;
                              end if;
                              return;
                           end if;
                           Output.Put (Line);
                           Output.New_Line;
                           Used := Used + FLns;
                        end Show_Field;
                     begin
                        Args.Map_JSON_Object (Show_Field'Access);
                     end;
                  end if;
               end;
               Maybe_Status;
               return Used;
            end;

         when Turn_Footer =>
            if Skip_Lines > 0 then
               return 0;
            end if;
            Output.Put (Content);
            Output.New_Line;
            return 1;

         when System_Notice =>
            if Skip_Lines > 0 then
               return 0;
            end if;
            case S.Sev is
               when Info =>
                  Output.Put (UC_BULLET & " " & Content);
                  Output.New_Line;
               when Warning =>
                  if Use_Color then
                     Output.Color_On (PAIR_YELLOW);
                  end if;
                  Output.Put (UC_WARN & " " & Content);
                  Output.New_Line;
                  Output.Reset_Attrs;
               when Error =>
                  if Use_Color then
                     Output.Color_On (PAIR_RED);
                  end if;
                  Output.Put ("[!] " & Content);
                  Output.New_Line;
                  Output.Reset_Attrs;
            end case;
            return 1;

      end case;
   end Render_Segment;

   --  ── Render_Frame ─────────────────────────────────────────────────────

   procedure Render_Frame
     (Content_Out  : in out Sink.Instance'Class;
      Status_Out   : in out Sink.Instance'Class;
      Snap         :        Segments.Vector;
      VP           :        Cursor;
      Heights      : in out Height_Array_Access;
      Win_Name     :        String;
      Status_Text  :        String;
      Is_Following :        Boolean;
      Search_Seg   :        Natural;
      Search_Off   :        Natural;
      Search_Len   :        Natural;
      Cols         :        Positive;
      Rows         :        Positive;
      Use_Color    :        Boolean)
   is
      Count        : constant Natural  := Natural (Snap.Length);
      Visible_Rows : constant Positive := Positive'Max (1, Rows - 1);

      procedure Ensure_Heights is
      begin
         if Heights = null or else Heights'Length < Count then
            declare
               New_Cache : constant Height_Array_Access :=
                 new Height_Array (1 .. Integer'Max (Count, 64));
            begin
               New_Cache.all := (others => 0);
               if Heights /= null then
                  for I in Heights'Range loop
                     exit when I > New_Cache'Last;
                     New_Cache (I) := Heights (I);
                  end loop;
               end if;
               Heights := New_Cache;
            end;
         end if;
      end Ensure_Heights;

      procedure Populate_Heights is
      begin
         for I in 1 .. Count loop
            if Heights (I) = 0 then
               Heights (I) := Natural (Measure_Segment (Snap (I), Cols));
            end if;
         end loop;
      end Populate_Heights;

      Start_C : Cursor;
      Used    : Natural := 0;
   begin
      Content_Out.Erase;

      if Count = 0 then
         goto Draw_Status;
      end if;

      Ensure_Heights;
      Populate_Heights;

      declare
         H_Arr : Height_Array (1 .. Count);
      begin
         for I in 1 .. Count loop
            H_Arr (I) := Heights (I);
         end loop;

         if Is_Following or else Viewport.Is_Following (VP) then
            Start_C := Coyote_TUI.Scroll.Follow_Start
                         (Snap, H_Arr, Visible_Rows);
         else
            Start_C := VP;
         end if;

         --  Render segments from Start_C.Seg onward.
         declare
            I : Natural := (if Start_C.Seg = 0 then 1 else Start_C.Seg);
         begin
            while I <= Count and then Used < Visible_Rows loop
               declare
                  S  : constant Segment := Snap (I);
                  Hi : constant Boolean :=
                    Search_Seg /= 0 and then I = Search_Seg;
                  MS : constant Integer :=
                    (if Hi then Integer (Search_Off) else -1);
                  ML : constant Natural :=
                    (if Hi then Search_Len else 0);
                  Sk : constant Natural :=
                    (if I = Start_C.Seg then Start_C.Offset else 0);
                  N  : constant Natural :=
                    Render_Segment
                      (S, Content_Out, Cols,
                       Use_Color   => Use_Color,
                       Skip_Lines  => Sk,
                       Match_Start => MS,
                       Match_Len   => ML);
               begin
                  Used := Used + N;
               end;
               I := I + 1;
            end loop;
         end;
      end;

      <<Draw_Status>>
      declare
         Nav_Pfx  : constant String :=
           (if not Is_Following then "[SCROLL] " else "");
         Bar_Text : constant String :=
           Nav_Pfx & Win_Name & "  " & Status_Text;
      begin
         Status_Out.Erase;
         Status_Out.Move (0, 0);
         Status_Out.Put (Bar_Text);
         Status_Out.Refresh;
      end;

      Content_Out.Refresh;
   end Render_Frame;

end Coyote_TUI.Render;
