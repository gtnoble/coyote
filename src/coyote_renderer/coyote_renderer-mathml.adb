--  Coyote_Renderer.MathML body.
--
--  cmark-gfm remains the authority for code-block boundaries.  The second
--  pass is only responsible for the Coyote display-math convention, which
--  cmark itself does not define.
--
--  Project: coyote

with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Coyote_Cmark;
with Interfaces.C;
with System;

package body Coyote_Renderer.MathML is

   use type Interfaces.C.int;
   use type System.Address;

   type Source_Range is record
      First : Positive;
      Last  : Positive;
   end record;

   package Source_Range_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Source_Range);

   function Parse_Source (Markdown : String) return Coyote_Cmark.Node_Ptr is
      C_Text : constant Interfaces.C.char_array :=
        Interfaces.C.To_C (Markdown, Append_Nul => True);
   begin
      return Coyote_Cmark.Parse_Document
        (C_Text, Interfaces.C.size_t (Markdown'Length),
         Coyote_Cmark.OPT_DEFAULT);
   end Parse_Source;

   function Code_Ranges (Markdown : String)
     return Source_Range_Vectors.Vector
   is
      Result : Source_Range_Vectors.Vector;
      Doc    : constant Coyote_Cmark.Node_Ptr := Parse_Source (Markdown);
      It     : Coyote_Cmark.Iter_Ptr;
      Ev     : Coyote_Cmark.Event_Type_Int;
      Node   : Coyote_Cmark.Node_Ptr;
   begin
      if Doc = System.Null_Address then
         return Result;
      end if;

      It := Coyote_Cmark.Iter_New (Doc);
      loop
         Ev := Coyote_Cmark.Iter_Next (It);
         exit when Ev = Coyote_Cmark.EVENT_DONE;
         if Ev = Coyote_Cmark.EVENT_ENTER then
            Node := Coyote_Cmark.Iter_Get_Node (It);
            if Coyote_Cmark.Node_Get_Type (Node) =
              Coyote_Cmark.NODE_CODE_BLOCK
            then
               declare
                  First : constant Interfaces.C.int :=
                    Coyote_Cmark.Node_Get_Start_Line (Node);
                  Last  : constant Interfaces.C.int :=
                    Coyote_Cmark.Node_Get_End_Line (Node);
               begin
                  if First > 0 and then Last >= First then
                     Result.Append
                       ((Positive (First), Positive (Last)));
                  end if;
               end;
            end if;
         end if;
      end loop;
      Coyote_Cmark.Iter_Free (It);
      Coyote_Cmark.Node_Free (Doc);
      return Result;
   end Code_Ranges;

   function Is_Protected
     (Ranges : Source_Range_Vectors.Vector;
      Line   : Positive) return Boolean
   is
   begin
      for Range_Index in Ranges.Iterate loop
         declare
            Item : constant Source_Range := Ranges (Range_Index);
         begin
            if Line in Item.First .. Item.Last then
               return True;
            end if;
         end;
      end loop;
      return False;
   end Is_Protected;

   function MathML_Source (Source : String) return String is
      First_Content : constant Natural := Source'First + 3;
      Last_Content  : constant Natural := Source'Last - 2;
   begin
      if Source'Length <= 5 then
         return "";
      end if;
      return Source (First_Content .. Last_Content);
   end MathML_Source;

   function Extract_Display_Math
     (Markdown : String) return Extraction_Result
   is
      Result       : Extraction_Result;
      Protected_Ranges : constant Source_Range_Vectors.Vector :=
        Code_Ranges (Markdown);
      Math_Open    : Boolean := False;
      Math_Buffer  : Unbounded_String;
      Math_Source  : Unbounded_String;
      Start        : Natural := Markdown'First;
      Line_Number  : Positive := 1;

      procedure Append_Line (Line : String) is
      begin
         Append (Result.Masked_Text, Line);
         Append (Result.Masked_Text, ASCII.LF);
      end Append_Line;

      procedure Preserve_Open_Block (Current_Line : String) is
      begin
         Append_Line (To_String (Math_Source));
         Append (Result.Masked_Text, To_String (Math_Buffer));
         Append_Line (Current_Line);
         Math_Open   := False;
         Math_Source := Null_Unbounded_String;
         Math_Buffer := Null_Unbounded_String;
      end Preserve_Open_Block;
   begin
      if Markdown'Length = 0 then
         return Result;
      end if;

      for I in Markdown'Range loop
         if Markdown (I) = ASCII.LF
           or else I = Markdown'Last
         then
            declare
               Last : constant Natural :=
                 (if Markdown (I) = ASCII.LF then I - 1 else I);
               Line : constant String :=
                 (if Last >= Start then Markdown (Start .. Last) else "");
               Trimmed : constant String :=
                 Ada.Strings.Fixed.Trim (Line, Ada.Strings.Both);
               Protected_Line : constant Boolean :=
                 Is_Protected (Protected_Ranges, Line_Number);
            begin
               if Protected_Line then
                  if Math_Open then
                     Preserve_Open_Block (Line);
                  else
                     Append_Line (Line);
                  end if;
               elsif not Math_Open and then Trimmed = "$$" then
                  Math_Open  := True;
                  Math_Source := To_Unbounded_String (Trimmed);
                  Math_Buffer := Null_Unbounded_String;
               elsif Math_Open and then Trimmed = "$$" then
                  if Length (Math_Buffer) > 0 then
                     declare
                        Source : Unbounded_String := Math_Source;
                     begin
                        Append (Source, ASCII.LF);
                        Append (Source, Math_Buffer);
                        Append (Source, Trimmed);
                        Result.Blocks.Append
                          ((Source => Source,
                            MathML => To_Unbounded_String
                              (MathML_Source (To_String (Source)))));
                        Append_Line
                          ("COYOTE_MATH_BLOCK_"
                           & Ada.Strings.Fixed.Trim
                               (Natural'Image
                                  (Natural (Result.Blocks.Length)),
                                Ada.Strings.Both)
                           & "__");
                     end;
                  else
                     Append_Line (To_String (Math_Source));
                     Append_Line (Trimmed);
                  end if;
                  Math_Open   := False;
                  Math_Source := Null_Unbounded_String;
                  Math_Buffer := Null_Unbounded_String;
               elsif Math_Open then
                  Append (Math_Buffer, Line);
                  Append (Math_Buffer, ASCII.LF);
               else
                  Append_Line (Line);
               end if;
            end;
            Start       := I + 1;
            Line_Number := Line_Number + 1;
         end if;
      end loop;

      if Math_Open then
         Append_Line (To_String (Math_Source));
         Append (Result.Masked_Text, To_String (Math_Buffer));
      end if;
      return Result;
   end Extract_Display_Math;

end Coyote_Renderer.MathML;
