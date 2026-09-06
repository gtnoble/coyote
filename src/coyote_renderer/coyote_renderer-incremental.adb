--  Coyote_Renderer.Incremental body.
--
--  CSM deliberately has a small grammar in this first implementation.  Text
--  outside recognised tags is emitted immediately, while an incomplete tag
--  remains in Pending until the next provider delta.
--
--  Project: coyote

with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;

package body Coyote_Renderer.Incremental is

   procedure Emit_Text
     (Handler : Event_Handler;
      Text    : String) is
   begin
      if Text'Length > 0 then
         Handler.all
           ((Kind => Text_Event,
             Text => To_Unbounded_String (Text)));
      end if;
   end Emit_Text;

   procedure Reset (Parser : in out Instance) is
   begin
      Parser.Pending := Null_Unbounded_String;
   end Reset;

   procedure Feed
     (Parser  : in out Instance;
      Data    :        String;
      Handler :        Event_Handler)
   is
      Input : Unbounded_String := Parser.Pending;
      Cursor : Natural;
   begin
      Append (Input, Data);
      Parser.Pending := Null_Unbounded_String;
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
                     Handler.all
                       ((Kind => Paragraph_Begin_Event,
                         Text => Null_Unbounded_String));
                  elsif Tag = "</p>" then
                     Handler.all
                       ((Kind => Paragraph_End_Event,
                         Text => Null_Unbounded_String));
                  elsif Tag = "<br/>" or else Tag = "<br />" then
                     Handler.all
                       ((Kind => Line_Break_Event,
                         Text => Null_Unbounded_String));
                  elsif Tag = "<text>" or else Tag = "</text>" then
                     null;
                  else
                     Handler.all
                       ((Kind => Invalid_Event,
                         Text => To_Unbounded_String (Tag)));
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
      Text : constant String := To_String (Parser.Pending);
   begin
      if Text'Length > 0 then
         Handler.all
           ((Kind => Invalid_Event,
             Text => To_Unbounded_String (Text)));
      end if;
      Reset (Parser);
   end Flush;

end Coyote_Renderer.Incremental;
