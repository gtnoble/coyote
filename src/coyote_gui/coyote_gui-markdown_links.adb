--  Coyote_GUI.Markdown_Links body.
--
--  Link destinations live in GtkTextTag names so click handlers can resolve
--  them from the clicked buffer range without per-view callback state.

with Ada.Strings.Fixed;
with Ada.Characters.Handling;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Coyote_Spawn;
with Cairo;
with Gdk.Cursor;
with Gdk.Device;
with Gdk.Display;
with Gdk.Event;
with Gdk.Seat;
with Gdk.Window;
with GNATCOLL.OS.Process;
with Glib;
with Glib.Properties;
with Glib.Object;
with Gtk.Adjustment;
with Gtk.Scrolled_Window;
with Gtk.Enums;
with Gtk.Tooltip;
with Gtk.Text_Iter;
with Gtk.Text_Tag_Table;
with Gtk.Text_Tag;
with Gtk.Widget;

package body Coyote_GUI.Markdown_Links is

   use type Glib.Guint;
   use type Gdk.Gdk_Window;
   use type Gdk.Gdk_Cursor;
   use type Gdk.Cursor.Gdk_Cursor_Type;
   use type Gdk.Device.Gdk_Device;
   use type Gdk.Seat.Gdk_Seat;
   use type Gdk.Event.Gdk_Event_Mask;
   use type Gtk.Enums.Gtk_Text_Window_Type;
   use type Glib.Gint;
   use type Gtk.Text_Tag.Text_Tag_List.GSlist;
   use type Gtk.Text_Tag.Gtk_Text_Tag;
   use type Gtk.Widget.Gtk_Widget;

   package Hover_Data is new Glib.Object.User_Data (Unbounded_String);
   Hover_Key : constant String := "coyote-markdown-hover";

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

   function Destination_At
     (View        : not null access Gtk.Text_View.Gtk_Text_View_Record'Class;
      Window_Type : Gtk.Enums.Gtk_Text_Window_Type;
      X, Y        : Glib.Gint) return String
   is
      Buffer_X : Glib.Gint;
      Buffer_Y : Glib.Gint;
      Iter : aliased Gtk.Text_Iter.Gtk_Text_Iter;
      Trailing : aliased Glib.Gint := 0;
      Tags : Gtk.Text_Tag.Text_Tag_List.GSlist;
      Tag_Cursor : Gtk.Text_Tag.Text_Tag_List.GSlist;
      Destination : Unbounded_String;
   begin
      --  Borders must not be mapped onto nearby tagged text.
      if Window_Type /= Gtk.Enums.Text_Window_Text
        and then Window_Type /= Gtk.Enums.Text_Window_Widget
      then
         return "";
      end if;
      View.Window_To_Buffer_Coords
        (Window_Type, X, Y, Buffer_X, Buffer_Y);
      if not View.Get_Iter_At_Position
        (Iter'Access, Trailing'Access, Buffer_X, Buffer_Y)
      then
         return "";
      end if;
      Tags := Gtk.Text_Iter.Get_Tags (Iter);
      Tag_Cursor := Tags;
      while Tag_Cursor /= Gtk.Text_Tag.Text_Tag_List.Null_List loop
         declare
            Tag : constant Gtk.Text_Tag.Gtk_Text_Tag :=
              Gtk.Text_Tag.Convert
                (Gtk.Text_Tag.Text_Tag_List.Get_Data_Address (Tag_Cursor));
            Name : constant String := Glib.Properties.Get_Property
              (Tag, Gtk.Text_Tag.Name_Property);
            Prefix : constant String := "coyote-link:";
         begin
            if Name'Length > Prefix'Length
              and then Name (Name'First .. Name'First + Prefix'Length - 1)
                = Prefix
              and then Is_Safe_Destination
                (Name (Name'First + Prefix'Length .. Name'Last))
            then
               Destination := To_Unbounded_String
                 (Name (Name'First + Prefix'Length .. Name'Last));
               exit;
            end if;
         end;
         Tag_Cursor := Gtk.Text_Tag.Text_Tag_List.Next (Tag_Cursor);
      end loop;
      Gtk.Text_Tag.Text_Tag_List.Free (Tags);
      return To_String (Destination);
   end Destination_At;

   procedure Set_Link_Cursor
     (View    : not null access Gtk.Text_View.Gtk_Text_View_Record'Class;
      On_Link : Boolean)
   is
      Window : constant Gdk.Gdk_Window :=
        View.Get_Window (Gtk.Enums.Text_Window_Text);
      Kind : constant Gdk.Cursor.Gdk_Cursor_Type :=
        (if On_Link then Gdk.Cursor.Hand2 else Gdk.Cursor.Xterm);
      Cursor : Gdk.Gdk_Cursor;
   begin
      if Window = null then
         return;
      end if;
      Cursor := Gdk.Window.Get_Cursor (Window);
      if Cursor /= null
        and then Gdk.Cursor.Get_Cursor_Type (Cursor) = Kind
      then
         return;
      end if;
      Gdk.Cursor.Gdk_New_For_Display (Cursor, View.Get_Display, Kind);
      Gdk.Window.Set_Cursor (Window, Cursor);
      Gdk.Cursor.Unref (Cursor);
   end Set_Link_Cursor;

   procedure Update_Hover
     (View        : not null access Gtk.Text_View.Gtk_Text_View_Record'Class;
      Destination : String)
   is
      Previous : constant Unbounded_String :=
        Hover_Data.Get (View, Hover_Key, Null_Unbounded_String);
   begin
      Set_Link_Cursor (View, Destination /= "");
      if To_String (Previous) /= Destination then
         Hover_Data.Set (View, To_Unbounded_String (Destination), Hover_Key);
         --  Re-query only on a target change, including stationary scrolling.
         View.Trigger_Tooltip_Query;
      end if;
   end Update_Hover;

   function On_Button_Release
     (Self  : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event_Button) return Boolean
   is
      View : constant Gtk.Text_View.Gtk_Text_View :=
        Gtk.Text_View.Gtk_Text_View (Self);
   begin
      if Event.Button /= 1 then
         return False;
      end if;
      declare
         Destination : constant String := Destination_At
           (View, View.Get_Window_Type (Event.Window),
            Glib.Gint (Event.X), Glib.Gint (Event.Y));
      begin
         if Destination = "" then
            return False;
         end if;
         Open_Destination (Destination);
         return True;
      end;
   end On_Button_Release;

   function On_Motion
     (Self  : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event_Motion) return Boolean
   is
      View : constant Gtk.Text_View.Gtk_Text_View :=
        Gtk.Text_View.Gtk_Text_View (Self);
   begin
      Update_Hover
        (View, Destination_At
           (View, View.Get_Window_Type (Event.Window),
            Glib.Gint (Event.X), Glib.Gint (Event.Y)));
      return False;
   end On_Motion;

   function On_Leave
     (Self  : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event_Crossing) return Boolean
   is
      pragma Unreferenced (Event);
   begin
      Update_Hover (Gtk.Text_View.Gtk_Text_View (Self), "");
      return False;
   end On_Leave;

   function On_Draw
     (Self : access Gtk.Widget.Gtk_Widget_Record'Class;
      Cr   : Cairo.Cairo_Context) return Boolean
   is
      pragma Unreferenced (Cr);
      View : constant Gtk.Text_View.Gtk_Text_View :=
        Gtk.Text_View.Gtk_Text_View (Self);
      Seat : constant Gdk.Seat.Gdk_Seat := Gdk.Seat.Gdk_Seat
        (View.Get_Display.Get_Default_Seat);
      Pointer : Gdk.Device.Gdk_Device;
      Window : Gdk.Gdk_Window;
      X, Y : Glib.Gint;
   begin
      --  Scrolling or replacing text can change the link under a stationary
      --  pointer. A view-owned draw callback avoids dangling scroll closures.
      if Seat = null then
         return False;
      end if;
      Pointer := Seat.Get_Pointer;
      if Pointer = null then
         return False;
      end if;
      Pointer.Get_Window_At_Position (X, Y, Window);
      if Window /= null
        and then Window = View.Get_Window (Gtk.Enums.Text_Window_Text)
      then
         Update_Hover
           (View, Destination_At (View, Gtk.Enums.Text_Window_Text, X, Y));
      else
         Update_Hover (View, "");
      end if;
      return False;
   end On_Draw;

   function On_Query_Tooltip
     (Self          : access Gtk.Widget.Gtk_Widget_Record'Class;
      X, Y          : Glib.Gint;
      Keyboard_Mode : Boolean;
      Tooltip       : not null access Glib.Object.GObject_Record'Class)
      return Boolean
   is
   begin
      if Keyboard_Mode then
         return False;
      end if;
      declare
         Destination : constant String := Destination_At
           (Gtk.Text_View.Gtk_Text_View (Self),
            Gtk.Enums.Text_Window_Widget, X, Y);
      begin
         if Destination = "" then
            return False;
         end if;
         --  Destinations are data, never Pango markup.
         Gtk.Tooltip.Set_Text (Gtk.Tooltip.Gtk_Tooltip (Tooltip), Destination);
         return True;
      end;
   end On_Query_Tooltip;

   procedure On_Scroll (Self : access Glib.Object.GObject_Record'Class) is
   begin
      --  Moving a viewport can reuse pixels without drawing its text child.
      Gtk.Widget.Queue_Draw (Gtk.Widget.Gtk_Widget (Self));
   end On_Scroll;

   procedure On_Realize (Self : access Gtk.Widget.Gtk_Widget_Record'Class) is
      Parent : Gtk.Widget.Gtk_Widget := Self.Get_Parent;
   begin
      while Parent /= null loop
         if Parent.all in Gtk.Scrolled_Window.Gtk_Scrolled_Window_Record'Class
         then
            declare
               Scroll : constant Gtk.Scrolled_Window.Gtk_Scrolled_Window :=
                 Gtk.Scrolled_Window.Gtk_Scrolled_Window (Parent);
            begin
               --  Slot connections disconnect when the view is finalized.
               Scroll.Get_Vadjustment.On_Value_Changed
                 (On_Scroll'Access, Slot => Self, After => True);
               Scroll.Get_Hadjustment.On_Value_Changed
                 (On_Scroll'Access, Slot => Self, After => True);
            end;
         end if;
         Parent := Parent.Get_Parent;
      end loop;
   end On_Realize;

   procedure Connect
     (View : not null access Gtk.Text_View.Gtk_Text_View_Record'Class)
   is
   begin
      if Hover_Data.Is_Set (View, Hover_Key) then
         return;
      end if;
      Hover_Data.Set (View, Null_Unbounded_String, Hover_Key);
      View.Add_Events
        (Gdk.Event.Button_Release_Mask or Gdk.Event.Pointer_Motion_Mask
         or Gdk.Event.Leave_Notify_Mask);
      View.Set_Has_Tooltip (True);
      Gtk.Widget.On_Button_Release_Event
        (Gtk.Widget.Gtk_Widget (View), On_Button_Release'Access);
      Gtk.Widget.On_Motion_Notify_Event
        (Gtk.Widget.Gtk_Widget (View), On_Motion'Access);
      Gtk.Widget.On_Leave_Notify_Event
        (Gtk.Widget.Gtk_Widget (View), On_Leave'Access);
      Gtk.Widget.On_Draw
        (Gtk.Widget.Gtk_Widget (View), On_Draw'Access, After => True);
      Gtk.Widget.On_Realize
        (Gtk.Widget.Gtk_Widget (View), On_Realize'Access);
      if View.Get_Realized then
         On_Realize (Gtk.Widget.Gtk_Widget (View));
      end if;
      Gtk.Widget.On_Query_Tooltip
        (Gtk.Widget.Gtk_Widget (View), On_Query_Tooltip'Access);
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
