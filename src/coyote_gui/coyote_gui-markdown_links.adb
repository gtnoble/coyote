--  Coyote_GUI.Markdown_Links body.
--
--  Link destinations live in GtkTextTag names so click handlers can resolve
--  them from the clicked buffer range without per-view callback state.

with Ada.Strings.Fixed;
with Ada.Characters.Handling;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Coyote_Spawn;
with Gdk.Event;
with GNATCOLL.OS.Process;
with Glib;
with Glib.Properties;
with Gtk.Enums;
with Gtk.Text_Iter;
with Gtk.Text_View;
with Gtk.Text_Tag_Table;
with Gtk.Text_Tag;
with Gtk.Widget;

package body Coyote_GUI.Markdown_Links is

   use type Glib.Guint;
   use type Gtk.Enums.Gtk_Text_Window_Type;
   use type Glib.Gint;
   use type Gtk.Text_Tag.Text_Tag_List.GSlist;
   use type Gtk.Text_Tag.Gtk_Text_Tag;

   function Is_Safe_Destination (Destination : String) return Boolean is
      Colon : constant Natural := Ada.Strings.Fixed.Index (Destination, ":");
      Scheme : constant String :=
        (if Colon > 0 then
           Ada.Characters.Handling.To_Lower
             (Destination (Destination'First .. Colon - 1))
         else "");
   begin
      if Destination'Length = 0 then
         return False;
      end if;
      for C of Destination loop
         if Character'Pos (C) < 32 or else Character'Pos (C) = 127 then
            return False;
         end if;
      end loop;
      if Colon = 0 then
         return True;
      end if;
      return Scheme = "http" or else Scheme = "https"
        or else Scheme = "mailto" or else Scheme = "file";
   end Is_Safe_Destination;

   procedure Open_Destination (Destination : String) is
      use GNATCOLL.OS.Process;
      Args : Argument_List;
   begin
      if not Is_Safe_Destination (Destination) then
         return;
      end if;
      Args.Append ("xdg-open");
      Args.Append (Destination);
      declare
         Launched : constant Boolean := Coyote_Spawn.Spawn_Detached (Args);
         pragma Unreferenced (Launched);
      begin
         null;
      end;
   end Open_Destination;

   function On_Button_Release
     (Self  : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event_Button) return Boolean
   is
      View : constant Gtk.Text_View.Gtk_Text_View :=
        Gtk.Text_View.Gtk_Text_View (Self);
      Window_Type : Gtk.Enums.Gtk_Text_Window_Type;
      Buffer_X : Glib.Gint;
      Buffer_Y : Glib.Gint;
      Iter : aliased Gtk.Text_Iter.Gtk_Text_Iter;
      Trailing : aliased Glib.Gint := 0;
      Found : Boolean;
      Tags : Gtk.Text_Tag.Text_Tag_List.GSlist;
   begin
      if Event.Button /= 1 then
         return False;
      end if;
      Window_Type := View.Get_Window_Type (Event.Window);
      if Window_Type /= Gtk.Enums.Text_Window_Widget then
         return False;
      end if;
      View.Window_To_Buffer_Coords
        (Window_Type, Glib.Gint (Event.X), Glib.Gint (Event.Y),
         Buffer_X, Buffer_Y);
      Found := View.Get_Iter_At_Position
        (Iter'Access, Trailing'Access, Buffer_X, Buffer_Y);
      if not Found then
         return False;
      end if;
      Tags := Gtk.Text_Iter.Get_Tags (Iter);
      while Tags /= Gtk.Text_Tag.Text_Tag_List.Null_List loop
         declare
            Tag : constant Gtk.Text_Tag.Gtk_Text_Tag :=
              Gtk.Text_Tag.Convert
                (Gtk.Text_Tag.Text_Tag_List.Get_Data_Address (Tags));
            Name : constant String := Glib.Properties.Get_Property
              (Tag, Gtk.Text_Tag.Name_Property);
            Prefix : constant String := "coyote-link:";
         begin
            if Name'Length > Prefix'Length
              and then Name (Name'First .. Name'First + Prefix'Length - 1)
                = Prefix
            then
               Open_Destination
                 (Name (Name'First + Prefix'Length .. Name'Last));
               Gtk.Text_Tag.Text_Tag_List.Free (Tags);
               return True;
            end if;
         end;
         Tags := Gtk.Text_Tag.Text_Tag_List.Next (Tags);
      end loop;
      Gtk.Text_Tag.Text_Tag_List.Free (Tags);
      return False;
   end On_Button_Release;

   procedure Connect
     (View : not null access Gtk.Text_View.Gtk_Text_View_Record'Class)
   is
   begin
      View.Add_Events (Gdk.Event.Button_Release_Mask);
      Gtk.Widget.On_Button_Release_Event
        (Gtk.Widget.Gtk_Widget (View), On_Button_Release'Access);
   end Connect;

   procedure Insert
     (Buffer : not null access Gtk.Text_Buffer.Gtk_Text_Buffer_Record'Class;
      Result : Coyote_Renderer.Markup.Render_Result;
      Clear  : Boolean := False)
   is
      Insert_Iter : Gtk.Text_Iter.Gtk_Text_Iter;
      Match_Start : Gtk.Text_Iter.Gtk_Text_Iter;
      Match_End : Gtk.Text_Iter.Gtk_Text_Iter;
      Cursor : Gtk.Text_Iter.Gtk_Text_Iter;
      Found : Boolean;
      Start_Offset : Glib.Gint;
      Prefix : constant String := "coyote-link:";
   begin
      if Clear then
         Buffer.Set_Text ("");
      end if;
      Start_Offset := Buffer.Get_Char_Count;
      Buffer.Get_End_Iter (Insert_Iter);
      Buffer.Insert_Markup
        (Insert_Iter, To_String (Result.Markup), -1);
      Buffer.Get_Iter_At_Offset (Cursor, Start_Offset);
      for Link of Result.Links loop
         declare
            Label : constant String := To_String (Link.Label);
            Dest : constant String := To_String (Link.Destination);
         begin
            if Label'Length > 0 and then Is_Safe_Destination (Dest) then
               Gtk.Text_Iter.Forward_Search
                 (Cursor, Label, Gtk.Text_Iter.Text_Only,
                  Match_Start, Match_End, Result => Found);
               if Found then
                  declare
                     Tag : Gtk.Text_Tag.Gtk_Text_Tag;
                  begin
                     Tag := Gtk.Text_Tag_Table.Lookup
                       (Buffer.Get_Tag_Table, Prefix & Dest);
                     if Tag = null then
                        Gtk.Text_Tag.Gtk_New (Tag, Prefix & Dest);
                        Glib.Properties.Set_Property
                          (Tag, Gtk.Text_Tag.Foreground_Property, "#204a87");
                        Buffer.Get_Tag_Table.Add (Tag);
                     end if;
                     Buffer.Apply_Tag (Tag, Match_Start, Match_End);
                     Cursor := Match_End;
                  end;
               end if;
            end if;
         end;
      end loop;
   end Insert;

end Coyote_GUI.Markdown_Links;
