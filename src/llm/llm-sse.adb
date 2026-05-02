--  LLM.SSE body.
--
--  Project: pi_acme
--  For revision history, see the project version-control log.

with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package body LLM.SSE is

   function Starts_With (Text : String; Prefix : String) return Boolean is
   begin
      return
        Text'Length >= Prefix'Length
        and then Text (Text'First .. Text'First + Prefix'Length - 1) = Prefix;
   end Starts_With;

   function Strip_Optional_Space (Text : String) return String is
   begin
      if Text'Length = 0 then
         return "";
      elsif Text (Text'First) = ' ' then
         return Text (Text'First + 1 .. Text'Last);
      else
         return Text;
      end if;
   end Strip_Optional_Space;

   function Strip_Trailing_CR (Text : String) return String is
   begin
      if Text'Length > 0 and then Text (Text'Last) = ASCII.CR then
         return Text (Text'First .. Text'Last - 1);
      else
         return Text;
      end if;
   end Strip_Trailing_CR;

   function Find_Delimiter
     (Buffer_String     : String;
      Delimiter_Length  :    out Natural)
      return Natural
   is
      LF_Delimiter   : constant String := ASCII.LF & ASCII.LF;
      CRLF_Delimiter : constant String :=
        ASCII.CR & ASCII.LF & ASCII.CR & ASCII.LF;
      LF_Position    : constant Natural :=
        Ada.Strings.Fixed.Index (Buffer_String, LF_Delimiter);
      CRLF_Position  : constant Natural :=
        Ada.Strings.Fixed.Index (Buffer_String, CRLF_Delimiter);
   begin
      if LF_Position = 0 and then CRLF_Position = 0 then
         Delimiter_Length := 0;
         return 0;
      elsif LF_Position /= 0
        and then (CRLF_Position = 0 or else LF_Position < CRLF_Position)
      then
         Delimiter_Length := LF_Delimiter'Length;
         return LF_Position;
      else
         Delimiter_Length := CRLF_Delimiter'Length;
         return CRLF_Position;
      end if;
   end Find_Delimiter;

   procedure Parse_Block
     (Block      :     String;
      Event_Name :    out Unbounded_String;
      Data       :    out Unbounded_String)
   is
      Position : Positive := Block'First;
   begin
      Event_Name := Null_Unbounded_String;
      Data := Null_Unbounded_String;

      if Block'Length = 0 then
         return;
      end if;

      Parse_Lines :
      loop
         declare
            Line_End : Natural := Position;
         begin
            while Line_End <= Block'Last
              and then Block (Line_End) /= ASCII.LF
            loop
               Line_End := Line_End + 1;
            end loop;

            declare
               Raw_Line : constant String :=
                 Block (Position .. Line_End - 1);
               Line     : constant String := Strip_Trailing_CR (Raw_Line);
            begin
               if Starts_With (Line, "event:") then
                  Event_Name :=
                    To_Unbounded_String
                      (Strip_Optional_Space
                         (Line (Line'First + 6 .. Line'Last)));
               elsif Starts_With (Line, "data:") then
                  if Length (Data) > 0 then
                     Append (Data, ASCII.LF);
                  end if;
                  Append
                    (Data,
                     Strip_Optional_Space
                       (Line (Line'First + 5 .. Line'Last)));
               end if;
            end;

            exit Parse_Lines when Line_End > Block'Last;
            Position := Line_End + 1;
            exit Parse_Lines when Position > Block'Last;
         end;
      end loop Parse_Lines;
   end Parse_Block;

   procedure Feed (P : in out Parser; Data : String) is
   begin
      Append (P.Buffer, Data);
   end Feed;

   function Next_Event
     (P          : in out Parser;
      Event_Name :    out Unbounded_String;
      Data       :    out Unbounded_String)
      return Boolean
   is
   begin
      Event_Name := Null_Unbounded_String;
      Data := Null_Unbounded_String;

      Find_Event :
      loop
         declare
            Buffer_String     : constant String := To_String (P.Buffer);
            Delimiter_Length  : Natural;
            Block_End         : constant Natural :=
              Find_Delimiter (Buffer_String, Delimiter_Length);
         begin
            if Block_End = 0 then
               return False;
            end if;

            declare
               Block : constant String :=
                 (if Block_End = Buffer_String'First
                  then ""
                  else Buffer_String (Buffer_String'First .. Block_End - 1));
            begin
               if Block_End + Delimiter_Length <= Buffer_String'Last then
                  P.Buffer :=
                    To_Unbounded_String
                      (Buffer_String
                         (Block_End + Delimiter_Length
                            .. Buffer_String'Last));
               else
                  P.Buffer := Null_Unbounded_String;
               end if;

               Parse_Block (Block, Event_Name, Data);

               if To_String (Event_Name) = "ping" then
                  Event_Name := Null_Unbounded_String;
                  Data := Null_Unbounded_String;
               elsif Length (Event_Name) = 0 and then Length (Data) = 0 then
                  null;
               else
                  return True;
               end if;
            end;
         end;
      end loop Find_Event;
   end Next_Event;

   procedure Reset (P : in out Parser) is
   begin
      P.Buffer := Null_Unbounded_String;
   end Reset;

end LLM.SSE;
