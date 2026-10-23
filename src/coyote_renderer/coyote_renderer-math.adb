--  Coyote_Renderer.Math body.
--
--  cmark-gfm identifies Markdown code blocks; this scanner recognizes the
--  display delimiters not defined by Markdown.
--
--  Project: coyote

with Ada.Containers;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Coyote_Cmark;
with Interfaces.C;

package body Coyote_Renderer.Math is

   use type Ada.Containers.Count_Type;
   use type Interfaces.C.int;

   type Source_Range is record
      First : Positive;
      Last  : Positive;
   end record;

   package Source_Range_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Source_Range);

   function Code_Ranges (Markdown : String) return Source_Range_Vectors.Vector
   is
      Result : Source_Range_Vectors.Vector;
      Doc    : Coyote_Cmark.Document;
      It     : Coyote_Cmark.Iterator;
      Text   : constant Interfaces.C.char_array :=
        Interfaces.C.To_C (Markdown, Append_Nul => True);
      Event  : Coyote_Cmark.Event_Type_Int;
      Node   : Coyote_Cmark.Node_Ptr;
   begin
      Coyote_Cmark.Parse
        (Doc, Text, Interfaces.C.size_t (Markdown'Length),
         Coyote_Cmark.OPT_DEFAULT);
      if Coyote_Cmark.Is_Null (Coyote_Cmark.Root (Doc)) then
         return Result;
      end if;
      Coyote_Cmark.Start (It, Coyote_Cmark.Root (Doc));
      if Coyote_Cmark.Is_Null (Coyote_Cmark.Handle (It)) then
         return Result;
      end if;
      loop
         Event := Coyote_Cmark.Iter_Next (Coyote_Cmark.Handle (It));
         exit when Event = Coyote_Cmark.EVENT_DONE;
         if Event = Coyote_Cmark.EVENT_ENTER then
            Node := Coyote_Cmark.Iter_Get_Node (Coyote_Cmark.Handle (It));
            if Coyote_Cmark.Node_Get_Type (Node) = Coyote_Cmark.NODE_CODE_BLOCK
            then
               declare
                  First : constant Interfaces.C.int :=
                    Coyote_Cmark.Node_Get_Start_Line (Node);
                  Last : constant Interfaces.C.int :=
                    Coyote_Cmark.Node_Get_End_Line (Node);
               begin
                  if First > 0 and then Last >= First then
                     Result.Append ((Positive (First), Positive (Last)));
                  end if;
               end;
            end if;
         end if;
      end loop;
      return Result;
   end Code_Ranges;

   function Is_Protected
     (Ranges : Source_Range_Vectors.Vector; Line : Positive) return Boolean
   is
   begin
      for Index in Ranges.Iterate loop
         if Line in Ranges (Index).First .. Ranges (Index).Last then
            return True;
         end if;
      end loop;
      return False;
   end Is_Protected;

   function Delimiter (Line : String) return String is
      Trimmed : constant String := Ada.Strings.Fixed.Trim
        (Line, Ada.Strings.Both);
   begin
      if Trimmed = "$$" then
         return "$$";
      elsif Trimmed = "\[" then
         return "\[";
      elsif Trimmed = "\]" then
         return "\]";
      else
         return "";
      end if;
   end Delimiter;

   function Strip_Delimiters (Source, Open : String) return String is
      Closing : constant String := (if Open = "$$" then "$$" else "\]");
   begin
      if Source'Length < Open'Length + Closing'Length then
         return "";
      end if;
      return Source (Source'First + Open'Length ..
                     Source'Last - Closing'Length);
   end Strip_Delimiters;

   function Placeholder
     (Markdown : String; Number : Natural) return Unbounded_String
   is
      Candidate : Unbounded_String;
      Counter : Natural := Number;
   begin
      loop
         Candidate := To_Unbounded_String
           ("COYOTE_MATH_BLOCK_" &
            Ada.Strings.Fixed.Trim
              (Natural'Image (Counter), Ada.Strings.Both) & "__");
         exit when Ada.Strings.Fixed.Index
           (Markdown, To_String (Candidate)) = 0;
         Counter := Counter + 1;
      end loop;
      return Candidate;
   end Placeholder;

   function Extract_Inline_Line
     (Line : String; Markdown : String;
      Blocks : in out Display_Math_Vectors.Vector;
      Code_Ticks : in out Natural;
      Next_Token : in out Natural) return String
   is
      Output : Unbounded_String;
      Index : Integer := Line'First;
      In_Destination : Boolean := False;
      Destination_Depth : Natural := 0;
      In_URL : Boolean := False;
      In_HTML : Boolean := False;

      function Escaped (Position : Integer) return Boolean is
         Backslashes : Natural := 0;
         Cursor : Integer := Position - 1;
      begin
         while Cursor >= Line'First and then
           Line (Cursor) = ASCII.Back_Slash loop
            Backslashes := Backslashes + 1;
            Cursor := Cursor - 1;
         end loop;
         return Backslashes mod 2 = 1;
      end Escaped;

   begin
      while Index <= Line'Last loop
         if Line (Index) = '`' then
            declare
               Finish : Integer := Index;
            begin
               while Finish <= Line'Last and then Line (Finish) = '`' loop
                  Finish := Finish + 1;
               end loop;
               if Code_Ticks = 0 then
                  Code_Ticks := Finish - Index;
               elsif Finish - Index = Code_Ticks then
                  Code_Ticks := 0;
               end if;
               Append (Output, Line (Index .. Finish - 1));
               Index := Finish;
            end;
         elsif In_HTML then
            Append (Output, Line (Index));
            if Line (Index) = '>' then
               In_HTML := False;
            end if;
            Index := Index + 1;
         elsif Code_Ticks = 0 and then Line (Index) = '<' then
            In_HTML := True;
            Append (Output, Line (Index));
            Index := Index + 1;
         elsif Line (Index) = '(' and then Index > Line'First
           and then Line (Index - 1) = ']'
         then
            In_Destination := True;
            Destination_Depth := 1;
            Append (Output, Line (Index));
            Index := Index + 1;
         elsif In_Destination then
            Append (Output, Line (Index));
            if Line (Index) = '(' then
               Destination_Depth := Destination_Depth + 1;
            elsif Line (Index) = ')' then
               Destination_Depth := Destination_Depth - 1;
               In_Destination := Destination_Depth > 0;
            end if;
            Index := Index + 1;
         elsif (Index = Line'First or else
                Line (Index - 1) in ' ' | ASCII.HT)
           and then Index + 6 <= Line'Last
           and then Line (Index .. Index + 6) = "http://"
         then
            In_URL := True;
            Append (Output, Line (Index));
            Index := Index + 1;
         elsif (Index = Line'First or else
                Line (Index - 1) in ' ' | ASCII.HT)
           and then Index + 7 <= Line'Last
           and then Line (Index .. Index + 7) = "https://"
         then
            In_URL := True;
            Append (Output, Line (Index));
            Index := Index + 1;
         elsif In_URL and then Line (Index) in ' ' | ASCII.HT then
            In_URL := False;
            Append (Output, Line (Index));
            Index := Index + 1;
         elsif Code_Ticks = 0 and then not In_URL and then
           not Escaped (Index) and then Index < Line'Last and then
           (Line (Index .. Index + 1) = "$$" or else
            (Line (Index) = '\' and then Line (Index + 1) = '['))
         then
            declare
               Open : constant String := Line (Index .. Index + 1);
               Close : constant String :=
                 (if Open = "$$" then "$$" else "\]");
               Start : constant Integer := Index;
               Finish : Integer := Index + 2;
            begin
               while Finish + 1 <= Line'Last loop
                  exit when Line (Finish .. Finish + 1) = Close;
                  Finish := Finish + 1;
               end loop;
               if Finish + 1 <= Line'Last and then Finish > Start + 2 then
                  if Blocks.Length < 64 then
                     declare
                        Source : constant String := Line (Start .. Finish + 1);
                        Latex : constant String :=
                          Line (Start + 2 .. Finish - 1);
                        Number : Natural := Next_Token;
                        Token : Unbounded_String;
                     begin
                        loop
                           Token := Placeholder (Markdown, Number);
                           exit when Ada.Strings.Fixed.Index
                             (Markdown, To_String (Token)) = 0
                             and then (Blocks.Is_Empty or else
                               (for all Existing of Blocks =>
                                 To_String (Existing.Placeholder) /=
                                   To_String (Token)));
                           Number := Number + 1;
                        end loop;
                        Next_Token := Number + 1;
                        Blocks.Append
                          ((Source => To_Unbounded_String (Source),
                            LaTeX => To_Unbounded_String (Latex),
                            Placeholder => Token));
                        Append (Output, To_String (Token));
                        Index := Finish + 2;
                     end;
                  else
                     Append (Output, Line (Start .. Finish + 1));
                     Index := Finish + 2;
                  end if;
               else
                  Append (Output, Line (Index));
                  Index := Index + 1;
               end if;
            end;
         else
            Append (Output, Line (Index));
            Index := Index + 1;
         end if;
      end loop;
      return To_String (Output);
   end Extract_Inline_Line;

   function Extract_Display_Math (Markdown : String) return Extraction_Result
   is
      Result : Extraction_Result;
      Protected_Ranges : constant Source_Range_Vectors.Vector :=
        Code_Ranges (Markdown);
      Open : Unbounded_String;
      Buffer : Unbounded_String;
      Start : Natural := Markdown'First;
      Line_Number : Positive := 1;
      Code_Ticks : Natural := 0;
      Next_Token : Natural := 1;

      procedure Append_Line (Value : String) is
      begin
         Append (Result.Masked_Text, Value);
         Append (Result.Masked_Text, ASCII.LF);
      end Append_Line;

      procedure Preserve_Open (Current : String) is
      begin
         Append_Line (To_String (Open));
         Append (Result.Masked_Text, To_String (Buffer));
         Append_Line (Current);
         Open := Null_Unbounded_String;
         Buffer := Null_Unbounded_String;
      end Preserve_Open;
   begin
      if Markdown'Length = 0 then
         return Result;
      end if;
      for I in Markdown'Range loop
         if Markdown (I) = ASCII.LF or else I = Markdown'Last then
            declare
               Last : constant Natural :=
                 (if Markdown (I) = ASCII.LF then I - 1 else I);
               Line : constant String :=
                 (if Last >= Start then Markdown (Start .. Last) else "");
               Mark : constant String := Delimiter (Line);
            begin
               if Is_Protected (Protected_Ranges, Line_Number) then
                  if Length (Open) > 0 then
                     Preserve_Open (Line);
                  else
                     Append_Line (Line);
                  end if;
               elsif Length (Open) = 0 and then
                 Result.Blocks.Length < 64 and then
                 (Mark = "$$" or else Mark = "\[")
               then
                  Open := To_Unbounded_String (Mark);
               elsif Length (Open) > 0 and then
                 ((To_String (Open) = "$$" and then Mark = "$$") or else
                  (To_String (Open) = "\[" and then Mark = "\]"))
               then
                  declare
                     Source : constant Unbounded_String := To_Unbounded_String
                       (To_String (Open) & ASCII.LF & To_String (Buffer)
                        & Mark);
                     Latex : constant String := Strip_Delimiters
                       (To_String (Source), To_String (Open));
                  begin
                     if Latex'Length > 0 and then
                       Result.Blocks.Length < 64
                     then
                        declare
                           Number : Natural := Next_Token;
                           Token : Unbounded_String;
                        begin
                           loop
                              Token := Placeholder (Markdown, Number);
                              exit when Ada.Strings.Fixed.Index
                                (Markdown, To_String (Token)) = 0
                                and then (Result.Blocks.Is_Empty or else
                                  (for all Existing of Result.Blocks =>
                                    To_String (Existing.Placeholder) /=
                                      To_String (Token)));
                              Number := Number + 1;
                           end loop;
                           Next_Token := Number + 1;
                           Result.Blocks.Append
                             ((Source => Source,
                               LaTeX => To_Unbounded_String (Latex),
                               Placeholder => Token));
                           Append_Line (To_String (Token));
                        end;
                     else
                        Append_Line (To_String (Source));
                     end if;
                  end;
                  Open := Null_Unbounded_String;
                  Buffer := Null_Unbounded_String;
               elsif Length (Open) > 0 then
                  Append (Buffer, Line & ASCII.LF);
               else
                  Append_Line
                    (Extract_Inline_Line
                       (Line, Markdown, Result.Blocks, Code_Ticks,
                        Next_Token));
               end if;
            end;
            Start := I + 1;
            Line_Number := Line_Number + 1;
         end if;
      end loop;
      if Length (Open) > 0 then
         Append_Line ("" & To_String (Open));
         Append (Result.Masked_Text, To_String (Buffer));
      end if;
      return Result;
   end Extract_Display_Math;

end Coyote_Renderer.Math;
