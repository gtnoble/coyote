package body Coyote_GUI.Conversation.Testing is

   function Strip_Pango_Markup (S : String) return String is
      R      : Unbounded_String;
      In_Tag : Boolean := False;
      I      : Natural := S'First;
   begin
      while I <= S'Last loop
         if S (I) = '<' then
            In_Tag := True;
         elsif S (I) = '>' then
            In_Tag := False;
         elsif not In_Tag then
            Append (R, S (I));
         end if;
         I := I + 1;
      end loop;
      return To_String (R);
   end Strip_Pango_Markup;

   function Line_Count (C : Instance) return Natural is
   begin
      return Natural (C.Lines.Length);
   end Line_Count;

   function Vis_Count_At (C : Instance; Index : Positive) return Natural is
   begin
      return C.Lines (Index).Vis_Count;
   end Vis_Count_At;

   function Total_Vis_Lines (C : Instance) return Natural is
   begin
      return C.Total_Vis_Lines;
   end Total_Vis_Lines;

   function Line_Height_Px (C : Instance) return Glib.Gint is
   begin
      return C.Line_Height_Px;
   end Line_Height_Px;

   function Is_In_Text_Block (C : Instance) return Boolean is
   begin
      return C.In_Text_Block;
   end Is_In_Text_Block;

   function Stream_Buffer (C : Instance) return String is
   begin
      return To_String (C.Stream_Buf);
   end Stream_Buffer;

   function Is_In_Thinking (C : Instance) return Boolean is
   begin
      return C.In_Thinking;
   end Is_In_Thinking;

   function Cache_Width_Px (C : Instance) return Glib.Gint is
   begin
      return C.Cache_Width_Px;
   end Cache_Width_Px;

   function Cached_Line_Count (C : Instance) return Natural is
   begin
      return C.Cached_Line_Count;
   end Cached_Line_Count;

   function Has_Markup_Flag (C : Instance; Index : Positive) return Boolean is
   begin
      return C.Lines (Index).Has_Markup;
   end Has_Markup_Flag;

   function Get_Line_Text (C : Instance; Index : Positive) return String is
      Raw : constant String := To_String (C.Lines (Index).Text);
   begin
      if C.Lines (Index).Has_Markup then
         return Strip_Pango_Markup (Raw);
      else
         return Raw;
      end if;
   end Get_Line_Text;

   function Selection_Visible (C : Instance) return Boolean is
   begin
      return C.Sel_Visible;
   end Selection_Visible;

   procedure Set_Selection
     (C           : in out Instance;
      Start_Line  :        Natural;
      Start_Byte  :        Natural;
      End_Line    :        Natural;
      End_Byte    :        Natural)
   is
   begin
      C.Sel_Visible    := True;
      C.Sel_Start_Line := Start_Line;
      C.Sel_Start_Byte := Start_Byte;
      C.Sel_End_Line   := End_Line;
      C.Sel_End_Byte   := End_Byte;
   end Set_Selection;

   function Extract_Text
     (C          : in out Instance;
      Start_Line :        Natural;
      Start_Byte :        Natural;
      End_Line   :        Natural;
      End_Byte   :        Natural) return String
   is
      Text : Unbounded_String;
   begin
      for I in Start_Line .. End_Line loop
         if I <= Positive (C.Lines.Length) then
            declare
               Raw_Text  : constant String :=
                 To_String (C.Lines (I).Text);
               Line_Text : constant String :=
                 (if C.Lines (I).Has_Markup
                  then Strip_Pango_Markup (Raw_Text)
                  else Raw_Text);
               S_Byte    : constant Natural :=
                 (if I = Start_Line then Start_Byte else 0);
               E_Byte    : constant Natural :=
                 (if I = End_Line
                  then Natural'Min (End_Byte, Line_Text'Length)
                  else Line_Text'Length);
            begin
               if S_Byte < E_Byte
                 and then S_Byte <= Line_Text'Length
               then
                  if Length (Text) > 0 then
                     Append (Text, ASCII.LF);
                  end if;
                  Append (Text,
                    Line_Text
                      (Line_Text'First + S_Byte
                       .. Line_Text'First + E_Byte - 1));
               end if;
            end;
         end if;
      end loop;
      return To_String (Text);
   end Extract_Text;

end Coyote_GUI.Conversation.Testing;
