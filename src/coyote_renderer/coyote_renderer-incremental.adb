--  Coyote_Renderer.Incremental body.
--
--  CSM deliberately has a small grammar in this implementation. Text outside
--  recognised tags is emitted immediately. Intrinsically incomplete table,
--  math, and code blocks remain buffered until their closing element arrives.
--
--  Project: coyote

with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;

package body Coyote_Renderer.Incremental is

   procedure Emit
     (Handler : Event_Handler;
      Kind    : Event_Kind;
      Text    : String := "")
   is
   begin
      Handler.all
        ((Kind => Kind,
          Text => To_Unbounded_String (Text)));
   end Emit;

   procedure Emit_Text
     (Handler : Event_Handler;
      Text    : String)
   is
   begin
      if Text'Length > 0 then
         Emit (Handler, Text_Event, Text);
      end if;
   end Emit_Text;

   function Closing_Tag
     (Block : Block_Kind) return String
   is
   begin
      case Block is
         when Table_Block =>
            return "</table>";
         when Math_Block =>
            return "</math>";
         when Code_Block =>
            return "</code>";
         when No_Block =>
            return "";
      end case;
   end Closing_Tag;

   function Event_For
     (Block : Block_Kind) return Event_Kind
   is
   begin
      case Block is
         when Table_Block =>
            return Table_Event;
         when Math_Block =>
            return Math_Event;
         when Code_Block =>
            return Code_Event;
         when No_Block =>
            return Invalid_Event;
      end case;
   end Event_For;

   procedure Reset (Parser : in out Instance) is
   begin
      Parser.Pending := Null_Unbounded_String;
      Parser.Block := No_Block;
      Parser.Buffer := Null_Unbounded_String;
   end Reset;

   procedure Feed_Block
     (Parser  : in out Instance;
      Data    :        String;
      Handler :        Event_Handler)
   is
      Source : Unbounded_String := Parser.Buffer;
      Close  : Natural;
   begin
      Append (Source, Data);
      Close := Ada.Strings.Fixed.Index
        (To_String (Source), Closing_Tag (Parser.Block));
      if Close = 0 then
         Parser.Buffer := Source;
         return;
      end if;

      declare
         Raw : constant String := To_String (Source);
         End_Tag : constant String := Closing_Tag (Parser.Block);
         Open_End : constant Natural :=
           Ada.Strings.Fixed.Index (Raw, ">", Raw'First);
         Block_Last : constant Natural := Close + End_Tag'Length - 1;
         Block_Source : constant String := Raw (Raw'First .. Block_Last);
      begin
         if Open_End = 0 or else Close < Open_End + 1 then
            Emit (Handler, Invalid_Event, Block_Source);
         else
            Emit (Handler, Event_For (Parser.Block), Block_Source);
         end if;
         Parser.Block := No_Block;
         Parser.Buffer := Null_Unbounded_String;
         if Close + End_Tag'Length <= Raw'Last then
            Parser.Pending := To_Unbounded_String
              (Raw (Close + End_Tag'Length .. Raw'Last));
         end if;
         if Length (Parser.Pending) > 0 then
            declare
               Trailing : constant String := To_String (Parser.Pending);
            begin
               Parser.Pending := Null_Unbounded_String;
               Feed (Parser, Trailing, Handler);
            end;
         end if;
      end;
   end Feed_Block;

   procedure Feed
     (Parser  : in out Instance;
      Data    :        String;
      Handler :        Event_Handler)
   is
      Input  : Unbounded_String := Parser.Pending;
      Cursor : Natural;
   begin
      Parser.Pending := Null_Unbounded_String;
      Append (Input, Data);

      if Parser.Block /= No_Block then
         Feed_Block (Parser, To_String (Input), Handler);
         return;
      end if;

      Cursor := 1;
      while Cursor <= Length (Input) loop
         declare
            Source : constant String := To_String (Input);
            Open   : constant Natural :=
              Ada.Strings.Fixed.Index (Source, "<", Cursor);
         begin
            if Open = 0 then
               Emit_Text (Handler, Source (Cursor .. Source'Last));
               exit;
            end if;

            if Open > Cursor then
               Emit_Text (Handler, Source (Cursor .. Open - 1));
            end if;

            if Ada.Strings.Fixed.Index
                 (Source, "<table>", Open) = Open
            then
               Parser.Block := Table_Block;
               Parser.Buffer := To_Unbounded_String
                 (Source (Open .. Source'Last));
               Feed_Block (Parser, "", Handler);
               exit;
            elsif Ada.Strings.Fixed.Index
                    (Source, "<code>", Open) = Open
            then
               Parser.Block := Code_Block;
               Parser.Buffer := To_Unbounded_String
                 (Source (Open .. Source'Last));
               Feed_Block (Parser, "", Handler);
               exit;
            elsif Ada.Strings.Fixed.Index
                    (Source, "<math", Open) = Open
                 and then
                   (Ada.Strings.Fixed.Index
                      (Source, ">", Open) > Open
                  and then
                   Source (Open + 5) in ' ' | ASCII.HT | '>')
            then
               declare
                  Open_End : constant Natural :=
                    Ada.Strings.Fixed.Index (Source, ">", Open);
               begin
                  if Open_End = 0 then
                     Parser.Pending :=
                       To_Unbounded_String (Source (Open .. Source'Last));
                     exit;
                  end if;
                  Parser.Block := Math_Block;
                  Parser.Buffer := To_Unbounded_String
                    (Source (Open .. Source'Last));
                  Feed_Block (Parser, "", Handler);
                  exit;
               end;
            end if;

            declare
               Close : constant Natural :=
                 Ada.Strings.Fixed.Index (Source, ">", Open);
            begin
               if Close = 0 then
                  Parser.Pending :=
                    To_Unbounded_String (Source (Open .. Source'Last));
                  exit;
               end if;

               declare
                  Tag : constant String := Source (Open .. Close);
               begin
                  if Tag = "<p>" then
                     Emit (Handler, Paragraph_Begin_Event);
                  elsif Tag = "</p>" then
                     Emit (Handler, Paragraph_End_Event);
                  elsif Tag = "<br/>" or else Tag = "<br />" then
                     Emit (Handler, Line_Break_Event);
                  elsif Tag = "<text>" or else Tag = "</text>" then
                     null;
                  elsif Tag = "<hr/>" or else Tag = "<hr />" then
                     Emit (Handler, Horizontal_Rule_Event);
                  else
                     Emit (Handler, Invalid_Event, Tag);
                  end if;
                  Cursor := Close + 1;
               end;
            end;
         end;
      end loop;
   end Feed;

   procedure Flush
     (Parser  : in out Instance;
      Handler :        Event_Handler)
   is
      Text : Unbounded_String := Parser.Pending;
   begin
      if Parser.Block /= No_Block then
         Append (Text, Parser.Buffer);
      end if;
      if Length (Text) > 0 then
         Emit (Handler, Invalid_Event, To_String (Text));
      end if;
      Reset (Parser);
   end Flush;

end Coyote_Renderer.Incremental;
