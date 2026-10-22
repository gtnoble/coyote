with AUnit.Test_Caller;
--  Coyote_GUI_Conversation_Stack_Tests body.
--
--  Project: coyote

with Ada.Calendar;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Text_IO;
with Interfaces.C;
with Interfaces.C.Strings;
with System;
with Coyote_Temp_Files;
with Gdk.Event;
with Gdk.Device;
with Gdk.Display;
with Gdk.Seat;
with Gdk.Rectangle;
with Gdk.Window;
with Gdk.Cursor;
with Gtk.Text_Iter;
with Gtk.Text_Child_Anchor;
with GNAT.OS_Lib;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Glib;
with Glib.Object;
with Ada.Unchecked_Deallocation;
with AUnit.Assertions;
with Gtk.Box;
with Gtk.Button;
with Gtk.Container;
with Gtk.Widget;
with Coyote_App.Utils;
with Coyote_GUI;
with Coyote_GUI.Conversation_Stack.Testing;
with Coyote_GUI.Markdown_Links;
with Gtk.Enums;
with Gtk.Flow_Box;
with Gtk.Flow_Box_Child;
with Gtk.Frame;
with Gtk.Grid;
with Gtk.Label;
with Gtk.Image;
with Gdk.Pixbuf;
with Gtk.Main;
with Gtk.Scrolled_Window;
with Gtk.Separator;
with Gtk.Text_Buffer;
with Gtk.Tooltip;
with Gtk.Text_Tag;
with Gtk.Text_Tag_Table;
with Gtk.Text_View;
with Pango.Context;
with Pango.Font;

package body Coyote_GUI_Conversation_Stack_Tests is

   use type Glib.Gfloat;
   use type System.Address;
   use type Ada.Calendar.Time;
   use type Gdk.Pixbuf.Gdk_Pixbuf;
   use type Ada.Directories.File_Size;
   use type GNAT.OS_Lib.File_Descriptor;
   use type Glib.Gint;
   use type Glib.Guint;
   use type Interfaces.C.int;
   use type Gdk.Cursor.Gdk_Cursor_Type;
   use type Gtk.Box.Gtk_Box;
   use type Gtk.Image.Gtk_Image;
   use type Gtk.Image.Gtk_Image_Type;
   use type Gtk.Enums.Gtk_Orientation;
   use type Gtk.Flow_Box.Gtk_Flow_Box;
   use type Gtk.Flow_Box_Child.Gtk_Flow_Box_Child;
   use type Gtk.Frame.Gtk_Frame;
   use type Gtk.Grid.Gtk_Grid;
   use type Gtk.Label.Gtk_Label;
   use type Gtk.Scrolled_Window.Gtk_Scrolled_Window;
   use type Gtk.Text_View.Gtk_Text_View;
   use type Gtk.Text_Tag.Gtk_Text_Tag;
   use type Gtk.Window.Gtk_Window;
   use type Gtk.Separator.Gtk_Separator;
   use type Gtk.Button.Gtk_Button;
   use Ada.Strings.Fixed;
   use Ada.Strings.Unbounded;
   use type Gtk.Widget.Widget_List.Glist;
   use type Gtk.Widget.Gtk_Widget;
   use type Gtk.Image.Gtk_Image;

   Inline_View_Destroyed : Boolean := False;

   procedure On_Inline_View_Destroy
     (Widget : access Gtk.Widget.Gtk_Widget_Record'Class)
   is
      pragma Unreferenced (Widget);
   begin
      Inline_View_Destroyed := True;
   end On_Inline_View_Destroy;

   Fork_Called : Boolean  := False;
   Fork_UUID   : Unbounded_String;
   Fork_Turn   : Positive := 1;
   Fork_Step   : Natural  := 0;

   procedure Capture_Fork (UUID : String; Turn_N : Positive; Step_N : Natural)
   is
   begin
      Fork_Called := True;
      Fork_UUID   := To_Unbounded_String (UUID);
      Fork_Turn   := Turn_N;
      Fork_Step   := Step_N;
   end Capture_Fork;
   use AUnit.Assertions;
   use Coyote_GUI;
   use Coyote_GUI.Conversation_Stack;
   use Coyote_GUI.Conversation_Stack.Testing;

   Image_Data : constant String :=
     "iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFElEQVR4nGP4"
     & "z8DAAMIg4j8QMAAAM94G+lX/f/AAAAAASUVORK5CYII=";

   function Decode_PNG return String is
      function Value_Of (C : Character) return Integer is
      begin
         case C is
            when 'A' .. 'Z' =>
               return Character'Pos (C) - Character'Pos ('A');
            when 'a' .. 'z' =>
               return 26 + Character'Pos (C) - Character'Pos ('a');
            when '0' .. '9' =>
               return 52 + Character'Pos (C) - Character'Pos ('0');
            when '+' =>
               return 62;
            when '/' =>
               return 63;
            when others =>
               return -1;
         end case;
      end Value_Of;
      Output : String (1 .. (Image_Data'Length * 3) / 4);
      Count  : Natural := 0;
      Pos    : Natural := Image_Data'First;
      A      : Integer;
      B      : Integer;
      C      : Integer;
      D      : Integer;
   begin
      while Pos + 3 <= Image_Data'Last loop
         A := Value_Of (Image_Data (Pos));
         B := Value_Of (Image_Data (Pos + 1));
         C := Value_Of (Image_Data (Pos + 2));
         D := Value_Of (Image_Data (Pos + 3));
         Count := Count + 1;
         Output (Count) := Character'Val (A * 4 + B / 16);
         if Image_Data (Pos + 2) /= '=' then
            Count := Count + 1;
            Output (Count) := Character'Val ((B mod 16) * 16 + C / 4);
         end if;
         if Image_Data (Pos + 3) /= '=' then
            Count := Count + 1;
            Output (Count) := Character'Val ((C mod 4) * 64 + D);
         end if;
         Pos := Pos + 4;
      end loop;
      return Output (1 .. Count);
   end Decode_PNG;

   procedure Write_PNG (Path : String) is
      use Ada.Streams;
      use Ada.Streams.Stream_IO;
      File : File_Type;
      Bytes : constant String := Decode_PNG;
      Data : Stream_Element_Array (1 .. Stream_Element_Offset (Bytes'Length));
   begin
      for Index in Bytes'Range loop
         Data (Stream_Element_Offset (Index)) :=
           Stream_Element (Character'Pos (Bytes (Index)));
      end loop;
      Create (File, Out_File, Path);
      Write (File, Data);
      Close (File);
   end Write_PNG;

   function Find_Image_Count
     (Root : Gtk.Widget.Gtk_Widget) return Natural
   is
      Children : Gtk.Widget.Widget_List.Glist;
      Node     : Gtk.Widget.Widget_List.Glist;
      Count    : Natural := 0;
      Child    : Gtk.Widget.Gtk_Widget;
   begin
      if Root = null then
         return 0;
      end if;
      if Root.Get_Name = "coyote-response-image"
        and then Root.all in Gtk.Image.Gtk_Image_Record'Class
      then
         declare
            Image : constant Gtk.Image.Gtk_Image :=
              Gtk.Image.Gtk_Image (Root);
         begin
            if Gtk.Image.Get_Storage_Type (Image) = Gtk.Image.Image_Pixbuf then
               declare
                  Pixbuf : constant Gdk.Pixbuf.Gdk_Pixbuf :=
                    Gtk.Image.Get (Image);
               begin
                  if Pixbuf /= null then
                     Count := 1;
                  end if;
               end;
            end if;
         end;
      end if;
      if Root.all not in Gtk.Container.Gtk_Container_Record'Class then
         return Count;
      end if;
      Children := Gtk.Container.Get_Children
        (Gtk.Container.Gtk_Container (Root));
      Node := Gtk.Widget.Widget_List.First (Children);
      while Node /= Gtk.Widget.Widget_List.Null_List loop
         Child := Gtk.Widget.Widget_List.Get_Data (Node);
         Count := Count + Find_Image_Count (Child);
         Node := Gtk.Widget.Widget_List.Next (Node);
      end loop;
      Gtk.Widget.Widget_List.Free (Children);
      return Count;
   end Find_Image_Count;

   procedure Pump_Until_Images (T : Test; Expected : Natural) is
      Deadline : constant Ada.Calendar.Time := Ada.Calendar.Clock + 3.0;
      Quit     : Boolean;
      pragma Unreferenced (Quit);
   begin
      while Ada.Calendar.Clock < Deadline
        and then Find_Image_Count
          (Gtk.Widget.Gtk_Widget (Widget (T.Stack.all))) < Expected
      loop
         if Gtk.Main.Events_Pending then
            Quit := Gtk.Main.Main_Iteration_Do (False);
         else
            delay 0.01;
         end if;
      end loop;
   end Pump_Until_Images;

   function Child_Anchor_At
     (Iter : System.Address) return System.Address;
   pragma Import
     (C, Child_Anchor_At, "gtk_text_iter_get_child_anchor");

   procedure Assert_Image_Anchor_At
     (T : Test; Offset : Glib.Gint; Message : String)
   is
      View   : constant Gtk.Text_View.Gtk_Text_View :=
        Active_Text_View (T.Stack.all);
      Buffer : constant Gtk.Text_Buffer.Gtk_Text_Buffer :=
        Gtk.Text_View.Get_Buffer (View);
      Iter   : Gtk.Text_Iter.Gtk_Text_Iter;
   begin
      Gtk.Text_Buffer.Get_Iter_At_Offset (Buffer, Iter, Offset);
      Assert
        (Child_Anchor_At (Iter'Address) /= System.Null_Address, Message);
   end Assert_Image_Anchor_At;

   procedure Drain_Gtk_Events is
      Quit : Boolean;
      pragma Unreferenced (Quit);
   begin
      for Attempt in 1 .. 300 loop
         if Gtk.Main.Events_Pending then
            Quit := Gtk.Main.Main_Iteration_Do (False);
         else
            delay 0.01;
         end if;
      end loop;
   end Drain_Gtk_Events;

   function Display_Available return Boolean is
   begin
      return
        Ada.Environment_Variables.Exists ("DISPLAY")
        or else Ada.Environment_Variables.Exists ("WAYLAND_DISPLAY");
   exception
      when others =>
         return False;
   end Display_Available;

   overriding procedure Set_Up (T : in out Test) is
      FD   : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
      Path : Unbounded_String;
   begin
      if Display_Available then
         Coyote_Temp_Files.Create (FD, Path);
         Assert (FD /= GNAT.OS_Lib.Invalid_FD,
                 "temporary image root is created");
         GNAT.OS_Lib.Close (FD);
         Ada.Directories.Delete_File (To_String (Path));
         Ada.Directories.Create_Directory (To_String (Path));
         T.Image_Root := Path;
         Gtk.Main.Init;
         T.Display_Available := True;
         Gtk.Window.Gtk_New (T.Parent, Gtk.Enums.Window_Toplevel);
         T.Stack := new Coyote_GUI.Conversation_Stack.Instance;
         Create (T.Stack.all, T.Parent.all'Access);
         T.Parent.Add (Widget (T.Stack.all));
         Set_Render_Markdown (T.Stack.all, True);
      end if;
   end Set_Up;

   overriding procedure Tear_Down (T : in out Test) is
   begin
      if T.Display_Available then
         Clear (T.Stack.all);
         T.Parent.Destroy;
         T.Parent := null;
         Free_Stack : declare
            procedure Free is new Ada.Unchecked_Deallocation
              (Coyote_GUI.Conversation_Stack.Instance, Stack_Access);
         begin
            Free (T.Stack);
         end Free_Stack;
      end if;
      if Length (T.Image_Root) > 0 then
         begin
            Ada.Directories.Delete_Tree (To_String (T.Image_Root));
         exception
            when others =>
               null;
         end;
         T.Image_Root := Null_Unbounded_String;
      end if;
   end Tear_Down;

   procedure Test_Begin_Request_Finalizes_Open_Text_Block
     (T : in out Test)
   is
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text (T.Stack.all, "partial");
      Assert (Text_Block_Open (T.Stack.all),
              "streaming opens the response text block");
      Assert (Response_Stream_Present (T.Stack.all),
              "streaming realizes the response text view");
      Begin_Request (T.Stack.all, "next request", Prompt);
      Assert (not Text_Block_Open (T.Stack.all),
              "a new request finalizes the open text block");
      Assert (Active_Text (T.Stack.all) = "next request",
              "a new request leaves no active response text");
   end Test_Begin_Request_Finalizes_Open_Text_Block;

   procedure Test_Clear_Removes_Active_Stream_Mark (T : in out Test) is
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text (T.Stack.all, "partial");
      Assert (Text_Block_Open (T.Stack.all),
              "streaming opens the response text block");
      Clear (T.Stack.all);
      Assert (not Has_Focus (T.Stack.all),
              "clear removes focus before removing conversation widgets");
      Assert (not Text_Block_Open (T.Stack.all),
              "clear closes the active text block");
      Assert (Active_Text (T.Stack.all) = "",
              "clear removes the active response text");
      Begin_Request (T.Stack.all, "after clear", Prompt);
      Append_Text (T.Stack.all, "partial again");
      Assert (Text_Block_Open (T.Stack.all),
              "streaming reopens a text block after clear");
      End_Text_Block (T.Stack.all);
      Assert (Index (Active_Text (T.Stack.all), "partial again") > 0,
              "text after clear streams into a fresh view");
   end Test_Clear_Removes_Active_Stream_Mark;

   procedure Test_Set_Font_Applies_To_New_Response_Views (T : in out Test) is
      Font : Pango.Font.Pango_Font_Description :=
        Pango.Font.From_String ("sans 18");
   begin
      if not T.Display_Available then
         Pango.Font.Free (Font);
         return;
      end if;
      Set_Font (T.Stack.all, Font, Math_Scale => 1.0);
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text (T.Stack.all, "styled");
      End_Text_Block (T.Stack.all);
      Assert (Active_Text_View (T.Stack.all) /= null,
              "font set before streaming leaves a response view");
      declare
         use type Pango.Context.Pango_Context;
         Context : constant Pango.Context.Pango_Context :=
           Active_Text_View (T.Stack.all).Get_Pango_Context;
      begin
         Assert
           (Pango.Font.To_String
              (Pango.Context.Get_Font_Description (Context)) = "sans 18",
            "new streamed response views inherit the configured font");
      end;
      Pango.Font.Free (Font);
   end Test_Set_Font_Applies_To_New_Response_Views;

   procedure Test_Set_Font_Applies_To_New_Table_Labels (T : in out Test) is
      Font   : Pango.Font.Pango_Font_Description :=
        Pango.Font.From_String ("sans 18");
      Source : constant String :=
        "| Name | Value |" & ASCII.LF & "| --- | --- |" & ASCII.LF
        & "| alpha | 42 |";
   begin
      if not T.Display_Available then
         Pango.Font.Free (Font);
         return;
      end if;
      Set_Font (T.Stack.all, Font, Math_Scale => 1.0);
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text (T.Stack.all, Source);
      End_Text_Block (T.Stack.all);
      declare
         use type Pango.Context.Pango_Context;
         Context : constant Pango.Context.Pango_Context :=
           Table_Cell (T.Stack.all, 1, 1, 1).Get_Pango_Context;
      begin
         Assert
           (Pango.Font.To_String
              (Pango.Context.Get_Font_Description (Context)) = "sans 18",
            "new native table labels inherit the configured font");
      end;
      Pango.Font.Free (Font);
   end Test_Set_Font_Applies_To_New_Table_Labels;

   procedure Test_Native_Footer_Uses_Status_Row_And_Fork_Button
     (T : in out Test)
   is
      Summary : constant String := "[ctx 24k/400k (6%) | ^537 out | stop]";
   begin
      if not T.Display_Available then
         return;
      end if;
      Fork_Called := False;
      Fork_UUID   := Null_Unbounded_String;
      Fork_Turn   := 1;
      Fork_Step   := 0;
      Set_Fork_Handler (T.Stack.all, Capture_Fork'Access);
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text (T.Stack.all, "response");
      End_Text_Block (T.Stack.all);
      Append_Turn_Footer
        (C       => T.Stack.all,
         Text    => "formatted footer" & ASCII.LF & Coyote_App.Utils.UC_HORIZ,
         Kind    => Final_Footer,
         Summary => Summary);
      Append_Fork_Action (T.Stack.all, "legacy label", "session-42", 3, 2);

      Assert
        (Footer_Separator (T.Stack.all) /= null,
         "footer uses a native GTK separator widget");
      Assert
        (Footer_Heading (T.Stack.all) = "Turn summary",
         "final footer uses a semantic summary heading");
      Assert
        (Footer_Summary (T.Stack.all) = Summary,
         "footer summary is rendered as a native label");
      Assert
        (not Footer_Summary_Selectable (T.Stack.all),
         "footer status label is not a selectable text control");
      Assert
        (Index (Footer_Summary (T.Stack.all), Coyote_App.Utils.UC_HORIZ) = 0,
         "footer summary does not contain a terminal separator");
      Assert
        (Fork_Button (T.Stack.all) /= null,
         "footer provides a native Fork button");
      Assert
        (Fork_Button (T.Stack.all).Get_Label = "Fork",
         "fork action uses a stable active-verb label");
      Assert
        (Fork_Button (T.Stack.all).Get_Can_Focus,
         "fork action is keyboard focusable");

      Fork_Button (T.Stack.all).Clicked;
      Assert (Fork_Called, "Fork button invokes the registered callback");
      Assert
        (To_String (Fork_UUID) = "session-42",
         "Fork callback receives the session UUID");
      Assert
        (Fork_Turn = 3 and then Fork_Step = 2,
         "Fork callback receives the turn and step");
   end Test_Native_Footer_Uses_Status_Row_And_Fork_Button;

   procedure Test_Creates_Single_Outer_Host (T : in out Test) is
   begin
      if not T.Display_Available then
         return;
      end if;
      Assert
        (Host_Widget (T.Stack.all) /= null,
         "stack creates one outer scrolled window");
   end Test_Creates_Single_Outer_Host;

   procedure Test_Request_And_Streaming_Are_Incremental (T : in out Test) is
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text (T.Stack.all, "first");
      Append_Text (T.Stack.all, " second");
      End_Text_Block (T.Stack.all);
      Assert (Has_Exchange (T.Stack.all), "request creates an exchange");
      Assert
        (Active_Text_View (T.Stack.all) /= null
         and then Active_Text_View (T.Stack.all).Get_Visible,
         "dynamically-created native text is visible");
   end Test_Request_And_Streaming_Are_Incremental;

   procedure Test_Markdown_Link_Destination_Policy (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert
        (Coyote_GUI.Markdown_Links.Is_Safe_Destination
           ("https://example.invalid/path"),
         "HTTPS destinations are accepted");
      Assert
        (Coyote_GUI.Markdown_Links.Is_Safe_Destination ("./README.md"),
         "relative file paths are accepted");
      Assert
        (Coyote_GUI.Markdown_Links.Is_Safe_Destination ("mailto:a@b.test"),
         "mailto destinations are accepted");
      Assert
        (not Coyote_GUI.Markdown_Links.Is_Safe_Destination
           ("javascript:alert(1)"),
         "unsupported schemes are rejected");
      Assert
        (not Coyote_GUI.Markdown_Links.Is_Safe_Destination
           ("https://host/" & ASCII.LF & "evil"),
         "control characters are rejected");
   end Test_Markdown_Link_Destination_Policy;

   procedure Test_Native_Markdown_Link_Click_Dispatches
     (T : in out Test)
   is
      Destination : constant String :=
        "https://example.invalid/path?query=one#section-2";
      Capture_FD : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
      Script_FD : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
      Capture_Path : Unbounded_String;
      Script_Path : Unbounded_String;
      Directory_Path : Unbounded_String;
      Old_Path : constant String :=
        Ada.Environment_Variables.Value ("PATH", "");
      Path_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("PATH");
      View : Gtk.Text_View.Gtk_Text_View;
      Buffer : Gtk.Text_Buffer.Gtk_Text_Buffer;

      procedure Restore_Path is
      begin
         if Path_Was_Set then
            Ada.Environment_Variables.Set ("PATH", Old_Path);
         else
            Ada.Environment_Variables.Clear ("PATH");
         end if;
      end Restore_Path;

      procedure Cleanup is
      begin
         Restore_Path;
         if Capture_FD /= GNAT.OS_Lib.Invalid_FD then
            GNAT.OS_Lib.Close (Capture_FD);
            Capture_FD := GNAT.OS_Lib.Invalid_FD;
         end if;
         if Script_FD /= GNAT.OS_Lib.Invalid_FD then
            GNAT.OS_Lib.Close (Script_FD);
            Script_FD := GNAT.OS_Lib.Invalid_FD;
         end if;
         Coyote_Temp_Files.Delete (To_String (Capture_Path));
         Coyote_Temp_Files.Delete (To_String (Script_Path));
         if To_String (Directory_Path)'Length > 0
           and then Ada.Directories.Exists (To_String (Directory_Path))
         then
            Ada.Directories.Delete_Directory
              (To_String (Directory_Path));
         end if;
      end Cleanup;

      procedure Dispatch_Motion (Offset : Glib.Gint) is
         Iter     : Gtk.Text_Iter.Gtk_Text_Iter;
         Location : Gdk.Rectangle.Gdk_Rectangle;
         Window_X : Glib.Gint;
         Window_Y : Glib.Gint;
         Event    : Gdk.Event.Gdk_Event;
         Pointer  : constant Gdk.Device.Gdk_Device :=
           Gdk.Seat.Get_Pointer
             (Gdk.Seat.Convert
                (Glib.Object.Convert
                   (Gdk.Display.Get_Default_Seat (Gdk.Display.Get_Default))));
      begin
         Buffer.Get_Iter_At_Offset (Iter, Offset);
         View.Get_Iter_Location (Iter, Location);
         View.Buffer_To_Window_Coords
           (Gtk.Enums.Text_Window_Text,
            Location.X + Location.Width / 2,
            Location.Y + Location.Height / 2,
            Window_X, Window_Y);
         Event := Gdk.Event.Gdk_Event_New (Gdk.Event.Motion_Notify);
         Event.Motion.Window := View.Get_Window (Gtk.Enums.Text_Window_Text);
         Gdk.Window.Ref (Event.Motion.Window);
         Event.Motion.Send_Event := 1;
         Event.Motion.Time := 1;
         Event.Motion.X := Glib.Gdouble (Window_X);
         Event.Motion.Y := Glib.Gdouble (Window_Y);
         Event.Motion.X_Root := Glib.Gdouble (Window_X);
         Event.Motion.Y_Root := Glib.Gdouble (Window_Y);
         Gdk.Device.Set_Device (Event, Pointer);
         Gtk.Main.Main_Do_Event (Event);
         Gdk.Event.Free (Event);
      end Dispatch_Motion;

      procedure Dispatch_Button
        (Button : Glib.Guint; Offset : Glib.Gint)
      is
         Iter : Gtk.Text_Iter.Gtk_Text_Iter;
         Location : Gdk.Rectangle.Gdk_Rectangle;
         Window_X : Glib.Gint;
         Window_Y : Glib.Gint;
         Press_Event : Gdk.Event.Gdk_Event;
         Release_Event : Gdk.Event.Gdk_Event;
         Pointer_Device : constant Gdk.Device.Gdk_Device :=
           Gdk.Seat.Get_Pointer
             (Gdk.Seat.Convert
                (Glib.Object.Convert
                   (Gdk.Display.Get_Default_Seat (Gdk.Display.Get_Default))));
      begin
         Buffer.Get_Iter_At_Offset (Iter, Offset);
         View.Get_Iter_Location (Iter, Location);
         View.Buffer_To_Window_Coords
           (Gtk.Enums.Text_Window_Text,
            Location.X + Location.Width / 2,
            Location.Y + Location.Height / 2,
            Window_X, Window_Y);
         Press_Event :=
           Gdk.Event.Gdk_Event_New (Gdk.Event.Button_Press);
         Press_Event.Button.Window :=
           View.Get_Window (Gtk.Enums.Text_Window_Text);
         Gdk.Window.Ref (Press_Event.Button.Window);
         Press_Event.Button.Send_Event := 1;
         Press_Event.Button.Time := 1;
         Press_Event.Button.X := Glib.Gdouble (Window_X);
         Press_Event.Button.Y := Glib.Gdouble (Window_Y);
         Press_Event.Button.Button := Button;
         Press_Event.Button.X_Root := Glib.Gdouble (Window_X);
         Press_Event.Button.Y_Root := Glib.Gdouble (Window_Y);
         Release_Event :=
           Gdk.Event.Gdk_Event_New (Gdk.Event.Button_Release);
         Release_Event.Button := Press_Event.Button;
         Gdk.Window.Ref (Release_Event.Button.Window);
         Release_Event.Button.The_Type := Gdk.Event.Button_Release;
         Gdk.Device.Set_Device (Press_Event, Pointer_Device);
         Gdk.Device.Set_Device (Release_Event, Pointer_Device);
         Gtk.Main.Main_Do_Event (Press_Event);
         Gtk.Main.Main_Do_Event (Release_Event);
         Gdk.Event.Free (Press_Event);
         Gdk.Event.Free (Release_Event);
         while Gtk.Main.Events_Pending loop
            declare
               Continue : constant Boolean := Gtk.Main.Main_Iteration;
               pragma Unreferenced (Continue);
            begin
               null;
            end;
         end loop;
      end Dispatch_Button;
   begin
      if not T.Display_Available then
         return;
      end if;
      Coyote_Temp_Files.Create (Capture_FD, Capture_Path);
      GNAT.OS_Lib.Close (Capture_FD);
      Capture_FD := GNAT.OS_Lib.Invalid_FD;
      Coyote_Temp_Files.Create (Script_FD, Script_Path);
      GNAT.OS_Lib.Close (Script_FD);
      Script_FD := GNAT.OS_Lib.Invalid_FD;
      Coyote_Temp_Files.Delete (To_String (Script_Path));
      Directory_Path := Script_Path;
      Ada.Directories.Create_Directory (To_String (Directory_Path));
      Script_Path := Directory_Path & "/xdg-open";
      declare
         Path_Name : constant String := To_String (Script_Path);
         File : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path_Name);
         Ada.Text_IO.Put_Line (File, "#!/bin/sh");
         Ada.Text_IO.Put_Line
           (File, "printf '%s\n' ""$@"" >> '" &
            To_String (Capture_Path) & "'");
         Ada.Text_IO.Close (File);
         GNAT.OS_Lib.Set_Executable (Path_Name);
      end;
      Ada.Environment_Variables.Set
        ("PATH", To_String (Directory_Path) & ":" & Old_Path);

      T.Parent.Set_Default_Size (640, 220);
      T.Parent.Show_All;
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text
        (T.Stack.all,
         "outside [open link](" & Destination & ") after");
      End_Text_Block (T.Stack.all);
      while Gtk.Main.Events_Pending loop
         declare
            Continue : constant Boolean := Gtk.Main.Main_Iteration;
            pragma Unreferenced (Continue);
         begin
            null;
         end;
      end loop;
      View := Active_Text_View (T.Stack.all);
      Buffer := View.Get_Buffer;
      Dispatch_Motion (9);
      Assert
        (Ada.Directories.Size (To_String (Capture_Path)) = 0,
         "hovering a rendered link must not launch a destination");
      Dispatch_Button (2, 10);
      Assert
        (Ada.Directories.Size (To_String (Capture_Path)) = 0,
         "non-left clicks must not launch a destination");
      Dispatch_Button (1, 0);
      Assert
        (Ada.Directories.Size (To_String (Capture_Path)) = 0,
         "left clicks on untagged text must not launch a destination");
      Dispatch_Button (1, 9);
      for Attempt in 1 .. 100 loop
         exit when Ada.Directories.Size (To_String (Capture_Path)) > 0;
         delay 0.01;
      end loop;
      Assert
        (Ada.Directories.Size (To_String (Capture_Path)) > 0,
         "left-click on a rendered link launches xdg-open");
      declare
         File : Ada.Text_IO.File_Type;
         Command : String (1 .. 1_024);
         Last : Natural;
      begin
         Ada.Text_IO.Open
           (File, Ada.Text_IO.In_File, To_String (Capture_Path));
         Ada.Text_IO.Get_Line (File, Command, Last);
         Assert
           (Command (1 .. Last) = Destination,
            "left-click launches exact destination including query/fragment");
         Assert
           (Ada.Text_IO.End_Of_File (File),
            "fake xdg-open receives only one destination argument");
         Ada.Text_IO.Close (File);
      exception
         when others =>
            if Ada.Text_IO.Is_Open (File) then
               Ada.Text_IO.Close (File);
            end if;
            raise;
      end;
      Cleanup;
   exception
      when others =>
         Cleanup;
         raise;
   end Test_Native_Markdown_Link_Click_Dispatches;

   procedure Test_Native_Markdown_Link_Hover_Cursor (T : in out Test) is
      Destination : constant String := "https://example.invalid/path";
      View        : Gtk.Text_View.Gtk_Text_View;
      Buffer      : Gtk.Text_Buffer.Gtk_Text_Buffer;
      Tooltip     : constant Gtk.Tooltip.Gtk_Tooltip :=
        new Gtk.Tooltip.Gtk_Tooltip_Record;

      procedure Emit_Query_Tooltip
        (Instance      : System.Address;
         Signal_Name   : Interfaces.C.Strings.chars_ptr;
         X, Y          : Interfaces.C.int;
         Keyboard_Mode : Interfaces.C.int;
         Tooltip_Obj   : System.Address;
         Return_Value  : System.Address);
      pragma Import (C, Emit_Query_Tooltip, "g_signal_emit_by_name");

      function Query_Tooltip
        (Offset        : Glib.Gint;
         Keyboard_Mode : Boolean) return Boolean
      is
         Iter        : Gtk.Text_Iter.Gtk_Text_Iter;
         Location    : Gdk.Rectangle.Gdk_Rectangle;
         Widget_X    : Glib.Gint;
         Widget_Y    : Glib.Gint;
         Handled     : aliased Interfaces.C.int := 0;
         Mode        : constant Interfaces.C.int :=
           (if Keyboard_Mode then 1 else 0);
         Signal_Name : Interfaces.C.Strings.chars_ptr :=
           Interfaces.C.Strings.New_String ("query-tooltip");
      begin
         Buffer.Get_Iter_At_Offset (Iter, Offset);
         View.Get_Iter_Location (Iter, Location);
         View.Buffer_To_Window_Coords
           (Gtk.Enums.Text_Window_Widget,
            Location.X + Location.Width / 2,
            Location.Y + Location.Height / 2,
            Widget_X, Widget_Y);
         Emit_Query_Tooltip
           (Glib.Object.Get_Object (Gtk.Widget.Gtk_Widget (View)),
            Signal_Name,
            Interfaces.C.int (Widget_X), Interfaces.C.int (Widget_Y), Mode,
            Glib.Object.Get_Object (Tooltip), Handled'Address);
         Interfaces.C.Strings.Free (Signal_Name);
         return Handled /= 0;
      exception
         when others =>
            Interfaces.C.Strings.Free (Signal_Name);
            raise;
      end Query_Tooltip;

      procedure Dispatch_Motion (Offset : Glib.Gint) is
         Iter     : Gtk.Text_Iter.Gtk_Text_Iter;
         Location : Gdk.Rectangle.Gdk_Rectangle;
         Window_X : Glib.Gint;
         Window_Y : Glib.Gint;
         Event    : Gdk.Event.Gdk_Event;
         Pointer  : constant Gdk.Device.Gdk_Device :=
           Gdk.Seat.Get_Pointer
             (Gdk.Seat.Convert
                (Glib.Object.Convert
                   (Gdk.Display.Get_Default_Seat (Gdk.Display.Get_Default))));
      begin
         Buffer.Get_Iter_At_Offset (Iter, Offset);
         View.Get_Iter_Location (Iter, Location);
         View.Buffer_To_Window_Coords
           (Gtk.Enums.Text_Window_Text,
            Location.X + Location.Width / 2,
            Location.Y + Location.Height / 2,
            Window_X, Window_Y);
         Event := Gdk.Event.Gdk_Event_New (Gdk.Event.Motion_Notify);
         Event.Motion.Window := View.Get_Window (Gtk.Enums.Text_Window_Text);
         Gdk.Window.Ref (Event.Motion.Window);
         Event.Motion.Send_Event := 1;
         Event.Motion.Time := 1;
         Event.Motion.X := Glib.Gdouble (Window_X);
         Event.Motion.Y := Glib.Gdouble (Window_Y);
         Event.Motion.X_Root := Glib.Gdouble (Window_X);
         Event.Motion.Y_Root := Glib.Gdouble (Window_Y);
         Gdk.Device.Set_Device (Event, Pointer);
         Gtk.Main.Main_Do_Event (Event);
         Gdk.Event.Free (Event);
      end Dispatch_Motion;

      function Cursor_Type return Gdk.Cursor.Gdk_Cursor_Type is
         Cursor : constant Gdk.Gdk_Cursor :=
           Gdk.Window.Get_Cursor
             (View.Get_Window (Gtk.Enums.Text_Window_Text));
      begin
         return Gdk.Cursor.Get_Cursor_Type (Cursor);
      end Cursor_Type;
   begin
      if not T.Display_Available then
         return;
      end if;
      T.Parent.Set_Default_Size (640, 220);
      T.Parent.Show_All;
      Glib.Object.G_New (Tooltip, Gtk.Tooltip.Get_Type);
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text
        (T.Stack.all,
         "outside [open link](" & Destination
         & ") and [unsafe](javascript:alert(1)) after");
      End_Text_Block (T.Stack.all);
      while Gtk.Main.Events_Pending loop
         declare
            Continue : constant Boolean := Gtk.Main.Main_Iteration;
            pragma Unreferenced (Continue);
         begin
            null;
         end;
      end loop;
      View := Active_Text_View (T.Stack.all);
      Buffer := View.Get_Buffer;

      Dispatch_Motion (9);
      Assert
        (Cursor_Type = Gdk.Cursor.Hand2,
         "motion over a Markdown link uses the hand cursor");
      Assert
        (Query_Tooltip (9, Keyboard_Mode => False),
         "query-tooltip handles a safe rendered link");
      Assert
        (not Query_Tooltip (0, Keyboard_Mode => False),
         "query-tooltip declines ordinary text");
      Assert
        (not Query_Tooltip (22, Keyboard_Mode => False),
         "query-tooltip declines an unsafe rendered link");
      Assert
        (not Query_Tooltip (9, Keyboard_Mode => True),
         "query-tooltip declines keyboard-mode queries");
      Dispatch_Motion (22);
      Assert
        (Cursor_Type = Gdk.Cursor.Xterm,
         "unsafe rendered links do not advertise activation");
      Dispatch_Motion (0);
      Assert
        (Cursor_Type = Gdk.Cursor.Xterm,
         "motion over ordinary text restores the text cursor");

      Dispatch_Motion (9);
      declare
         Event   : Gdk.Event.Gdk_Event;
         Pointer : constant Gdk.Device.Gdk_Device :=
           Gdk.Seat.Get_Pointer
             (Gdk.Seat.Convert
                (Glib.Object.Convert
                   (Gdk.Display.Get_Default_Seat (Gdk.Display.Get_Default))));
      begin
         Event := Gdk.Event.Gdk_Event_New (Gdk.Event.Leave_Notify);
         Event.Crossing.Window := View.Get_Window (Gtk.Enums.Text_Window_Text);
         Gdk.Window.Ref (Event.Crossing.Window);
         Event.Crossing.Send_Event := 1;
         Event.Crossing.Time := 1;
         Gdk.Device.Set_Device (Event, Pointer);
         Gtk.Main.Main_Do_Event (Event);
         Gdk.Event.Free (Event);
      end;
      Assert
        (Cursor_Type = Gdk.Cursor.Xterm,
         "leaving the text view restores the text cursor");
      Tooltip.Unref;
   end Test_Native_Markdown_Link_Hover_Cursor;

   procedure Test_Native_Markdown_Renders_After_Streaming (T : in out Test) is
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text
        (T.Stack.all,
         "**bold** and [link](https://example.invalid/path) and `code`");
      End_Text_Block (T.Stack.all);
      declare
         Text : constant String := Active_Text (T.Stack.all);
      begin
         Assert
           (Index (Text, "bold and link and code") > 0,
            "native Markdown renders visible text after streaming");
         Assert
           (Index (Text, "**") = 0,
            "native Markdown removes strong delimiters");
         Assert
           (Index (Text, "`") = 0, "native Markdown removes code delimiters");
         declare
            Buffer : constant Gtk.Text_Buffer.Gtk_Text_Buffer :=
              Active_Text_View (T.Stack.all).Get_Buffer;
            Link_Tag : constant Gtk.Text_Tag.Gtk_Text_Tag :=
              Gtk.Text_Tag_Table.Lookup
                (Buffer.Get_Tag_Table,
                 "coyote-link:https://example.invalid/path");
         begin
            Assert (Link_Tag /= null, "rendered Markdown creates a link tag");
         end;
      end;
   end Test_Native_Markdown_Renders_After_Streaming;

   procedure Test_Native_Markdown_Toggle_Disables_Rendering (T : in out Test)
   is
   begin
      if not T.Display_Available then
         return;
      end if;
      Set_Render_Markdown (T.Stack.all, False);
      Assert
        (not Get_Render_Markdown (T.Stack.all),
         "native Markdown rendering can be disabled");
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text (T.Stack.all, "**bold**");
      End_Text_Block (T.Stack.all);
      declare
         Text : constant String := Active_Text (T.Stack.all);
      begin
         Assert
           (Index (Text, "**bold**") > 0,
            "disabled native Markdown preserves source text");
      end;
   end Test_Native_Markdown_Toggle_Disables_Rendering;

   procedure Test_Native_Table_Realizes_Grid (T : in out Test) is
      Source : constant String :=
        "| Name | Count | Ratio |" & ASCII.LF & "| :--- | :---: | ---: |"
        & ASCII.LF & "| alpha | 42 | 0.5 |";
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text (T.Stack.all, Source);
      End_Text_Block (T.Stack.all);
      Assert
        (Table_Count (T.Stack.all) = 1,
         "completed table should create one native grid");
      Assert
        (Table_Grid (T.Stack.all, 1) /= null,
         "native table grid should be retained");
      Assert
        (Table_Cell (T.Stack.all, 1, 1, 1) /= null,
         "native table header cell should exist");
      Assert
        (Table_Cell (T.Stack.all, 1, 2, 3) /= null,
         "native table body cell should exist");
      Assert
        (Table_Cell (T.Stack.all, 1, 2, 3).Get_Text = "0.5",
         "native table cell should retain copied text");
      Assert
        (Table_Cell (T.Stack.all, 1, 1, 1).Get_Use_Markup,
         "native table header should use Pango markup");
      Assert
        (Table_Cell (T.Stack.all, 1, 1, 1).Get_Text = "Name",
         "native table header should retain visible text");
      Assert
        (Table_Cell (T.Stack.all, 1, 2, 1).Get_Xalign = 0.0,
         "left-aligned table column should use left alignment");
      Assert
        (Table_Cell (T.Stack.all, 1, 2, 2).Get_Xalign = 0.5,
         "center-aligned table column should use center alignment");
      Assert
        (Table_Cell (T.Stack.all, 1, 2, 3).Get_Xalign = 1.0,
         "right-aligned table column should use right alignment");
      Assert
        (not Response_Stream_Present (T.Stack.all),
         "native table replacement removes the raw stream view");
   end Test_Native_Table_Realizes_Grid;

   procedure Test_Native_Table_Toggle_Disables_Rendering (T : in out Test) is
      Source : constant String :=
        "| Name | Value |" & ASCII.LF & "| --- | --- |" & ASCII.LF
        & "| alpha | 42 |";
   begin
      if not T.Display_Available then
         return;
      end if;
      Set_Render_Markdown (T.Stack.all, False);
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text (T.Stack.all, Source);
      End_Text_Block (T.Stack.all);
      Assert
        (Table_Count (T.Stack.all) = 0,
         "disabled Markdown should not create a native table");
      Assert
        (Index (Active_Text (T.Stack.all), "| Name | Value |") > 0,
         "disabled Markdown should preserve table source");
   end Test_Native_Table_Toggle_Disables_Rendering;

   procedure Test_Native_Response_Table_Skips_Whitespace_Blocks
     (T : in out Test)
   is
      Source   : constant String :=
        "| Name | Value |" & ASCII.LF & "| --- | --- |" & ASCII.LF
        & "| alpha | 42 |";
      Children : Gtk.Widget.Widget_List.Glist;
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text (T.Stack.all, Source);
      End_Text_Block (T.Stack.all);
      Children :=
        Gtk.Container.Get_Children
          (Gtk.Container.Gtk_Container (Response_Box (T.Stack.all)));
      Assert
        (Gtk.Widget.Widget_List.Length (Children) = 1,
         "table-only response should not create whitespace text blocks");
   end Test_Native_Response_Table_Skips_Whitespace_Blocks;

   procedure Test_Native_Response_Mixed_Blocks_Skip_Whitespace
     (T : in out Test)
   is
      Source   : constant String :=
        "before" & ASCII.LF & ASCII.LF & "| Name | Value |" & ASCII.LF
        & "| --- | --- |" & ASCII.LF & "| alpha | 42 |" & ASCII.LF & ASCII.LF
        & "after";
      Children : Gtk.Widget.Widget_List.Glist;
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text (T.Stack.all, Source);
      End_Text_Block (T.Stack.all);
      Children :=
        Gtk.Container.Get_Children
          (Gtk.Container.Gtk_Container (Response_Box (T.Stack.all)));
      Assert
        (Gtk.Widget.Widget_List.Length (Children) = 3,
         "mixed response should contain only text-table-text blocks");
   end Test_Native_Response_Mixed_Blocks_Skip_Whitespace;

   procedure Test_Assistant_Content_Uses_Visible_Step_Frame (T : in out Test)
   is
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack.all, "request", Prompt);
      Begin_Thinking (T.Stack.all);
      Append_Thinking (T.Stack.all, "thinking");
      End_Thinking (T.Stack.all);
      Append_Text (T.Stack.all, "response");
      End_Text_Block (T.Stack.all);
      Assert
        (Step_Frame_Count (T.Stack.all) = 1,
         "assistant content creates one step frame");
      Assert
        (Active_Step_Frame (T.Stack.all) /= null
         and then Active_Step_Frame (T.Stack.all).Get_Visible,
         "step frame is visible while streaming");
   end Test_Assistant_Content_Uses_Visible_Step_Frame;

   procedure Test_Footer_Closes_Step_Before_Next_Step (T : in out Test) is
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text (T.Stack.all, "first response");
      End_Text_Block (T.Stack.all);
      Append_Turn_Footer (T.Stack.all, "step", Step_Footer);
      Assert
        (Footer_Heading (T.Stack.all) = "Step 1 summary",
         "step footer uses a numbered semantic summary heading");
      Append_Fork_Action (T.Stack.all, "fork step", "session", 1, 1);
      Assert
        (Step_Frame_Count (T.Stack.all) = 1,
         "step footer and fork remain in the first frame");
      Assert
        (Active_Step_Frame (T.Stack.all) = null,
         "completed step is no longer the active target");
      Append_Text (T.Stack.all, "final response");
      End_Text_Block (T.Stack.all);
      Assert
        (Step_Frame_Count (T.Stack.all) = 2,
         "next assistant response creates a second step frame");
      Append_Turn_Footer (T.Stack.all, "final", Final_Footer);
      Append_Fork_Action (T.Stack.all, "fork turn", "session", 1, 0);
      Complete_Request (T.Stack.all, Completed);
      Assert
        (Is_Completed (T.Stack.all),
         "final completion closes the exchange after its step");
   end Test_Footer_Closes_Step_Before_Next_Step;

   procedure Test_Cancelled_Tool_Closes_Step_Without_Footer
     (T : in out Test)
   is
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text (T.Stack.all, "tool preamble");
      End_Text_Block (T.Stack.all);
      Begin_Tool
        (C              => T.Stack.all,
         Name           => "shell",
         Args           => "{}",
         Session_Id     => "session",
         Tool_Id        => "cancelled-step",
         Initial_Status => Running);
      End_Tool
        (C       => T.Stack.all,
         Tool_Id => "cancelled-step",
         Status  => Cancelled,
         Result  => "aborted");
      End_Step (T.Stack.all);
      Assert
        (Step_Frame_Count (T.Stack.all) = 1,
         "cancelled step boundary does not add a frame or footer");
      Assert
        (Active_Step_Frame (T.Stack.all) = null,
         "cancelled step boundary finalizes the active frame");
      Assert
        (not Is_Completed (T.Stack.all),
         "cancelled step boundary leaves the exchange active");
      Append_Text (T.Stack.all, "response after cancellation");
      End_Text_Block (T.Stack.all);
      Assert
        (Step_Frame_Count (T.Stack.all) = 2,
         "assistant output after cancellation gets a new step frame");
      Assert
        (Footer_Heading (T.Stack.all) = "",
         "cancelled tool does not create a summary footer");
   end Test_Cancelled_Tool_Closes_Step_Without_Footer;

   procedure Test_New_Request_Resets_Step_Frames (T : in out Test) is
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack.all, "first request", Prompt);
      Append_Text (T.Stack.all, "first response");
      End_Text_Block (T.Stack.all);
      Assert
        (Step_Frame_Count (T.Stack.all) = 1,
         "first request creates one step frame");

      Begin_Request (T.Stack.all, "second request", Prompt);
      Assert
        (Step_Frame_Count (T.Stack.all) = 0,
         "new request clears prior step-frame bookkeeping");
      Append_Text (T.Stack.all, "second response");
      End_Text_Block (T.Stack.all);
      Assert
        (Step_Frame_Count (T.Stack.all) = 1,
         "second request creates a fresh step frame");
   end Test_New_Request_Resets_Step_Frames;

   procedure Test_Tool_Updates_By_Stable_Id (T : in out Test) is
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack.all, "request", Prompt);
      Begin_Tool
        (C          => T.Stack.all,
         Name       => "shell",
         Args       => "{""command"":""true""}",
         Session_Id => "session",
         Tool_Id    => "tool-1");
      Begin_Tool
        (C          => T.Stack.all,
         Name       => "shell",
         Args       => "{}",
         Session_Id => "session",
         Tool_Id    => "tool-2");
      End_Tool (T.Stack.all, "tool-1", Success, "one");
      Assert
        (Tool_Count (T.Stack.all) = 2,
         "tool starts are retained by stable tool ID");
      End_Tool (T.Stack.all, "tool-2", Error, "two");
      Assert
        (Tool_Count (T.Stack.all) = 2,
         "tool completion updates existing card by ID");
   end Test_Tool_Updates_By_Stable_Id;

   procedure Test_Tool_Status_Transitions (T : in out Test) is
      Info           : Coyote_GUI.Tool_Info;
      Summary        : String (1 .. 1_024);
      Summary_Length : Natural;
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack.all, "request", Prompt);
      Begin_Tool
        (C              => T.Stack.all,
         Name           => "shell",
         Args           => "{""command"":""sleep 2""}",
         Session_Id     => "session",
         Tool_Id        => "tool-status",
         Initial_Status => Queued);
      Info :=
        Coyote_GUI.Conversation_Stack.Testing.Tool_Detail
          (T.Stack.all, "tool-status");
      Assert
        (Info.Result_Status = Queued and then not Info.Completed,
         "new card retains queued status");
      Summary_Length                :=
        Coyote_GUI.Conversation_Stack.Testing.Tool_Summary
          (T.Stack.all, "tool-status")'
          Length;
      Summary (1 .. Summary_Length) :=
        Coyote_GUI.Conversation_Stack.Testing.Tool_Summary
          (T.Stack.all, "tool-status");
      Assert
        (Index (Summary (1 .. Summary_Length), "Status: Queued") > 0,
         "queued status is visible in the compact card");
      Assert
        (Tool_Status_Label (T.Stack.all, "tool-status") = "Status: Queued",
         "queued status is visible in the native status label");

      Set_Tool_Status (T.Stack.all, "tool-status", Running);
      Info :=
        Coyote_GUI.Conversation_Stack.Testing.Tool_Detail
          (T.Stack.all, "tool-status");
      Assert
        (Info.Result_Status = Running and then not Info.Completed,
         "running transition retains an active card");
      Assert
        (Index
           (Coyote_GUI.Conversation_Stack.Testing.Tool_Summary
              (T.Stack.all, "tool-status"),
            "Status: Running")
         > 0,
         "running status is visible in the compact card");

      End_Tool
        (C       => T.Stack.all,
         Tool_Id => "tool-status",
         Status  => Timed_Out,
         Result  => "[command timed out after 2 seconds]");
      Info :=
        Coyote_GUI.Conversation_Stack.Testing.Tool_Detail
          (T.Stack.all, "tool-status");
      Assert
        (Info.Result_Status = Timed_Out and then Info.Completed,
         "timed-out transition closes the card");
      Assert
        (Index
           (Coyote_GUI.Conversation_Stack.Testing.Tool_Summary
              (T.Stack.all, "tool-status"),
            "Status: Timed out")
         > 0,
         "timed-out status is visible in the compact card");
   end Test_Tool_Status_Transitions;

   procedure Test_Request_Completion_Closes_Active_Tools (T : in out Test) is
      Info : Coyote_GUI.Tool_Info;
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack.all, "request", Prompt);
      Begin_Tool
        (C              => T.Stack.all,
         Name           => "shell",
         Args           => "{""command"":""sleep 2""}",
         Session_Id     => "session",
         Tool_Id        => "unfinished",
         Initial_Status => Running);
      Complete_Request (T.Stack.all, Failed);
      Info := Coyote_GUI.Conversation_Stack.Testing.Tool_Detail
        (T.Stack.all, "unfinished");
      Assert
        (Info.Result_Status = Cancelled and then Info.Completed,
         "request completion closes an unfinished tool");
      Assert
        (Tool_Status_Label (T.Stack.all, "unfinished") = "Status: Cancelled",
         "request completion updates the unfinished tool label");
   end Test_Request_Completion_Closes_Active_Tools;

   procedure Test_Tool_Abort_Controls_Follow_Status (T : in out Test) is
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack.all, "request", Prompt);
      Begin_Tool
        (C              => T.Stack.all,
         Name           => "shell",
         Args           => "{""command"":""sleep 10""}",
         Session_Id     => "session",
         Tool_Id        => "abort-controls",
         Initial_Status => Queued);
      Assert
        (Abort_Enabled (T.Stack.all, "abort-controls"),
         "Abort is enabled for queued tools");
      Assert
        (Abort_Message_Enabled (T.Stack.all, "abort-controls"),
         "Abort With Message is enabled for queued tools");
      Set_Tool_Status (T.Stack.all, "abort-controls", Running);
      Assert
        (Abort_Enabled (T.Stack.all, "abort-controls"),
         "Abort remains enabled while running");
      End_Tool
        (C       => T.Stack.all,
         Tool_Id => "abort-controls",
         Status  => Cancelled,
         Result  => "cancelled by test");
      Assert
        (not Abort_Enabled (T.Stack.all, "abort-controls"),
         "Abort is disabled after cancellation");
      Assert
        (not Abort_Message_Enabled (T.Stack.all, "abort-controls"),
         "Abort With Message is disabled after cancellation");
      Assert
        (Details_Enabled (T.Stack.all, "abort-controls"),
         "View Details remains enabled after cancellation");
   end Test_Tool_Abort_Controls_Follow_Status;

   procedure Test_Tool_Action_Buttons_Use_Horizontal_Row (T : in out Test) is
      Action_Box : Gtk.Box.Gtk_Box;
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack.all, "request", Prompt);
      Begin_Tool
        (C          => T.Stack.all,
         Name       => "shell",
         Args       => "{""command"":""true""}",
         Session_Id => "session",
         Tool_Id    => "action-row");

      Action_Box := Tool_Action_Box (T.Stack.all, "action-row");
      Assert (Action_Box /= null, "tool card creates an action row");
      Assert
        (Action_Box.Get_Orientation = Gtk.Enums.Orientation_Horizontal,
         "tool card action row is horizontal");
      Assert
        (Gtk.Widget.Widget_List.Length
           (Gtk.Container.Get_Children
              (Gtk.Container.Gtk_Container (Action_Box))) = 3,
         "tool card action row contains three buttons");
      Assert
        (Gtk.Button.Gtk_Button (Action_Box.Get_Child (0)).Get_Label
           = "View Details",
         "action row starts with View Details");
      Assert
        (Gtk.Button.Gtk_Button (Action_Box.Get_Child (1)).Get_Label = "Abort",
         "action row places Abort beside View Details");
      Assert
        (Gtk.Button.Gtk_Button (Action_Box.Get_Child (2)).Get_Label
           = "Abort With Message...",
         "action row places message abort beside View Details");
   end Test_Tool_Action_Buttons_Use_Horizontal_Row;

   procedure Test_Tool_Cards_Use_Responsive_Flow (T : in out Test) is
      Flow         : Gtk.Flow_Box.Gtk_Flow_Box;
      First_Child  : Gtk.Flow_Box_Child.Gtk_Flow_Box_Child;
      Second_Child : Gtk.Flow_Box_Child.Gtk_Flow_Box_Child;
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack.all, "request", Prompt);
      Begin_Tool
        (C          => T.Stack.all,
         Name       => "shell",
         Args       => "{""command"":""one""}",
         Session_Id => "session",
         Tool_Id    => "tool-flow-1");
      Begin_Tool
        (C          => T.Stack.all,
         Name       => "shell",
         Args       => "{""command"":""two""}",
         Session_Id => "session",
         Tool_Id    => "tool-flow-2");

      Flow := Tool_Flow (T.Stack.all);
      Assert (Flow /= null, "tool cards create a native flow host");
      Assert
        (not Flow.Get_Homogeneous, "tool flow preserves natural card widths");
      Assert
        (Flow.Get_Row_Spacing = 4, "tool flow uses four pixels between rows");
      Assert
        (Flow.Get_Column_Spacing = 4,
         "tool flow uses four pixels between columns");
      Assert
        (Flow.Get_Child_At_Index (0) /= null
         and then Flow.Get_Child_At_Index (1) /= null,
         "two tool cards are inserted into the same flow host");
      First_Child  := Flow.Get_Child_At_Index (0);
      Second_Child := Flow.Get_Child_At_Index (1);
      Assert
        (First_Child.Get_Index = 0 and then Second_Child.Get_Index = 1,
         "tool cards retain insertion order in the flow host");
   end Test_Tool_Cards_Use_Responsive_Flow;

   procedure Test_Tool_Card_Uses_Native_Labels (T : in out Test) is
      Summary        : String (1 .. 4_096);
      Summary_Length : Natural;
      Info           : Coyote_GUI.Tool_Info;
      Tool_Args      : constant String :=
        "{""command"":""printf hello"",""timeout"":5,"
        & """run_group"":0,""stdin"":"""",""media_type"":null}";
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack.all, "request", Prompt);
      Begin_Tool
        (C                => T.Stack.all,
         Name             => "shell",
         Args             => Tool_Args,
         Session_Id       => "session-1",
         Tool_Id          => "tool-summary",
         Model            => "provider/model",
         Source_Directory => "/tmp/project",
         Session_Start    => "2026-08-24 12:00:00",
         Turn_Index       => 3,
         Call_In_Turn     => 2);
      Assert
        (Details_Enabled (T.Stack.all, "tool-summary"),
         "View Details is enabled while the tool is running");
      Assert
        (Details_Label (T.Stack.all, "tool-summary") = "View Details",
         "tool action uses an active verb");
      Info :=
        Coyote_GUI.Conversation_Stack.Testing.Tool_Detail
          (T.Stack.all, "tool-summary");
      Assert
        (not Info.Completed, "active retained details are marked incomplete");
      Assert
        (To_String (Info.Tool_Id) = "tool-summary",
         "active retained details preserve the tool ID");
      Assert
        (To_String (Info.Session_Id) = "session-1",
         "active retained details preserve the session ID");
      declare
         Summary_Text : constant String :=
           Coyote_GUI.Conversation_Stack.Testing.Tool_Summary
             (T.Stack.all, "tool-summary");
      begin
         Summary_Length                := Summary_Text'Length;
         Summary (1 .. Summary_Length) := Summary_Text;
      end;
      Assert
        (Index (Summary (1 .. Summary_Length), "Status: Running") > 0,
         "summary exposes running status text");
      Assert
        (Index (Summary (1 .. Summary_Length), "shell") > 0,
         "summary contains the tool name");
      Assert
        (Index (Summary (1 .. Summary_Length), "command: printf hello") > 0,
         "summary contains compact argument fields");
      Assert
        (Index (Summary (1 .. Summary_Length), "timeout: 5") > 0,
         "summary contains each visible top-level argument field");
      Assert
        (Index (Summary (1 .. Summary_Length), "run_group: 0") = 0,
         "summary hides the default run group");
      Assert
        (Index (Summary (1 .. Summary_Length), "stdin:") = 0,
         "summary hides empty stdin");
      Assert
        (Index (Summary (1 .. Summary_Length), "media_type:") = 0,
         "summary hides null media type");
      Assert
        (Index (Summary (1 .. Summary_Length), "printf hello") > 0,
         "summary contains argument value");
      Assert
        (Index (Summary (1 .. Summary_Length), "full-result-sentinel") = 0,
         "summary does not contain the full result");
      Assert
        (Index (Summary (1 .. Summary_Length), "{""command""") = 0,
         "summary does not contain raw argument JSON");
      Assert
        (Index (Summary (1 .. Summary_Length), Coyote_App.Utils.UC_BOX_TL) = 0,
         "summary does not use top box-drawing decoration");
      Assert
        (Index (Summary (1 .. Summary_Length), Coyote_App.Utils.UC_BOX_BL) = 0,
         "summary does not use bottom box-drawing decoration");

      End_Tool
        (C          => T.Stack.all,
         Tool_Id    => "tool-summary",
         Status     => Success,
         Result     => "full-result-sentinel",
         Media_Type => "image/png");
      Assert
        (Details_Enabled (T.Stack.all, "tool-summary"),
         "Details remains enabled after tool completion");
      Info :=
        Coyote_GUI.Conversation_Stack.Testing.Tool_Detail
          (T.Stack.all, "tool-summary");
      Assert
        (Info.Completed, "completed retained details are marked complete");
      Assert
        (To_String (Info.Tool_Id) = "tool-summary",
         "completed retained details preserve the tool ID");
      Assert
        (To_String (Info.Session_Id) = "session-1",
         "completed retained details preserve the session ID");
      Assert
        (To_String (Info.Name) = "shell",
         "retained details preserve the tool name");
      Assert
        (To_String (Info.Args) = Tool_Args,
         "retained details preserve raw arguments including hidden fields");
      Assert
        (To_String (Info.Result_Text) = "full-result-sentinel",
         "retained details preserve the full result");
      Assert
        (To_String (Info.Media_Type) = "image/png",
         "retained details preserve result media type");
      Assert
        (To_String (Info.Model) = "provider/model",
         "retained details preserve model metadata");
      Assert
        (To_String (Info.Source_Directory) = "/tmp/project",
         "retained details preserve source metadata");
      Assert
        (To_String (Info.Session_Start) = "2026-08-24 12:00:00",
         "retained details preserve session metadata");
      Assert
        (Info.Turn_Index = 3 and then Info.Call_In_Turn = 2,
         "retained details preserve call position");
   end Test_Tool_Card_Uses_Native_Labels;

   procedure Test_Tool_Image_Thumbnail (T : in out Test) is
      Image_Data : constant String :=
        "iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFElEQVR4nGP4"
        & "z8DAAMIg4j8QMAAAM94G+lX/f/AAAAAASUVORK5CYII=";
      Thumbnail : Gtk.Image.Gtk_Image;
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack.all, "request", Prompt);
      Begin_Tool
        (C => T.Stack.all, Name => "screenshot", Args => "{}",
         Session_Id => "session", Tool_Id => "image-tool");
      End_Tool
        (C => T.Stack.all, Tool_Id => "image-tool", Status => Success,
         Result => Image_Data, Media_Type => "image/png");
      Thumbnail := Tool_Thumbnail (T.Stack.all, "image-tool");
      Assert
        (Thumbnail /= null, "valid image creates a thumbnail widget");
      Assert
        (Gtk.Image.Get_Storage_Type (Thumbnail) = Gtk.Image.Image_Pixbuf,
         "thumbnail displays a decoded pixbuf");
      declare
         Pixbuf : constant Gdk.Pixbuf.Gdk_Pixbuf :=
           Gtk.Image.Get (Thumbnail);
      begin
         Assert
           (Gdk.Pixbuf.Get_Width (Pixbuf) <= 320
              and then Gdk.Pixbuf.Get_Height (Pixbuf) <= 320,
            "thumbnail dimensions stay within the image bound");
      end;
      Assert
        (Index
           (Tool_Status_Label (T.Stack.all, "image-tool"), Image_Data) = 0,
         "image base64 is not exposed in the status label");
      declare
         Info : constant Coyote_GUI.Tool_Info :=
           Coyote_GUI.Conversation_Stack.Testing.Tool_Detail
             (T.Stack.all, "image-tool");
      begin
         Assert
           (To_String (Info.Result_Text) = Image_Data,
            "full base64 payload remains captured for Details");
      end;

      Begin_Tool
        (C => T.Stack.all, Name => "screenshot", Args => "{}",
         Session_Id => "session", Tool_Id => "invalid-image");
      End_Tool
        (C => T.Stack.all, Tool_Id => "invalid-image", Status => Success,
         Result => "not-base64", Media_Type => "image/png");
      Assert
        (Tool_Thumbnail (T.Stack.all, "invalid-image") = null,
         "invalid image data does not add a thumbnail");
      Assert
        (Tool_Image_Fallback_Visible (T.Stack.all, "invalid-image"),
         "invalid image data shows a fallback label");
      Assert
        (Index
           (Tool_Status_Label (T.Stack.all, "invalid-image"),
            "not-base64") = 0,
         "invalid image payload is not shown as status text");
   end Test_Tool_Image_Thumbnail;

   procedure Test_Footer_Kind_And_Completion_Are_Explicit (T : in out Test) is
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Turn_Footer (T.Stack.all, "step", Step_Footer);
      Assert
        (not Is_Completed (T.Stack.all),
         "step footer does not complete exchange");
      Append_Turn_Footer (T.Stack.all, "final", Final_Footer);
      Complete_Request (T.Stack.all, Failed);
      Assert
        (Is_Completed (T.Stack.all),
         "explicit completion closes exchange");
      Assert
        (Last_Status (T.Stack.all) = Failed,
         "completion status is retained structurally");
   end Test_Footer_Kind_And_Completion_Are_Explicit;

   procedure Test_Clear_Removes_Exchange_State (T : in out Test) is
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text (T.Stack.all, "content");
      Complete_Request (T.Stack.all, Aborted);
      Clear (T.Stack.all);
      Assert
        (not Has_Exchange (T.Stack.all), "clear removes exchange state");
      Assert
        (not Is_Completed (T.Stack.all), "clear removes terminal state");
   end Test_Clear_Removes_Exchange_State;

   procedure Test_Native_Display_Math_Realizes_Element (T : in out Test) is
      Source : constant String :=
        "before" & ASCII.LF & "$$" & ASCII.LF
        & "<math xmlns=""http://www.w3.org/1998/Math/MathML"">"
        & "<mfrac><mn>1</mn><mn>2</mn></mfrac></math>" & ASCII.LF & "$$"
        & ASCII.LF & "after";
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text (T.Stack.all, Source);
      End_Text_Block (T.Stack.all);
      Assert
        (Math_Element_Count (T.Stack.all) = 1,
         "valid display math creates one native element");
      Assert
        (Math_Is_Valid (T.Stack.all, 1),
         "valid display math is measured successfully");
      Assert
        (Math_Width (T.Stack.all, 1) > 0
         and then Math_Height (T.Stack.all, 1) > 0,
         "native math element has non-zero dimensions");
      Assert
        (Index (Math_Source (T.Stack.all, 1), "$$") > 0,
         "native math element retains delimiter-wrapped source");
      Assert
        (not Response_Stream_Present (T.Stack.all),
         "native MathML replacement removes the raw stream view");
      Assert
        (Active_Text_View (T.Stack.all) /= null,
         "rendered response text remains the active text component");
      Assert
        (Response_Text_Has_Style (T.Stack.all),
         "rendered response text uses the response style");
      Assert
        (Math_Area_Visible (T.Stack.all, 1),
         "valid MathML shows the rendered area");
      Assert
        (not Math_Fallback_Visible (T.Stack.all, 1),
         "valid MathML hides the source fallback");
      Assert
        (Math_Has_Response_Style (T.Stack.all, 1),
         "rendered MathML uses the response style");
      Host_Widget (T.Stack.all).Show_All;
      Assert
        (not Math_Fallback_Visible (T.Stack.all, 1),
         "parent Show_All does not reveal valid MathML source");
   end Test_Native_Display_Math_Realizes_Element;

   procedure Test_Native_Display_Math_Invalid_Falls_Back (T : in out Test) is
      Source : constant String := "$$" & ASCII.LF & "<" & ASCII.LF & "$$";
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text (T.Stack.all, Source);
      End_Text_Block (T.Stack.all);
      Assert
        (Math_Element_Count (T.Stack.all) = 1,
         "invalid display math retains a native fallback element");
      Assert
        (not Math_Is_Valid (T.Stack.all, 1),
         "invalid display math is marked invalid");
      Assert
        (Index (Math_Source (T.Stack.all, 1), "<") > 0,
         "invalid display math retains readable source");
      Assert
        (not Math_Area_Visible (T.Stack.all, 1),
         "invalid MathML hides the rendered area");
      Assert
        (Math_Fallback_Visible (T.Stack.all, 1),
         "invalid MathML shows the source fallback");
   end Test_Native_Display_Math_Invalid_Falls_Back;

   procedure Test_Native_Display_Math_Protects_Code (T : in out Test) is
      Source : constant String :=
        "```" & ASCII.LF & "$$" & ASCII.LF & "<math><mi>x</mi></math>"
        & ASCII.LF & "$$" & ASCII.LF & "```";
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text (T.Stack.all, Source);
      End_Text_Block (T.Stack.all);
      Assert
        (Math_Element_Count (T.Stack.all) = 0,
         "display math inside fenced code is not realized");
      Assert
        (Index (Active_Text (T.Stack.all), "$$") > 0,
         "fenced code retains dollar delimiters");
   end Test_Native_Display_Math_Protects_Code;

   procedure Test_Native_Display_Math_Zooms (T : in out Test) is
      Source        : constant String                   :=
        "$$" & ASCII.LF & "<math xmlns=""http://www.w3.org/1998/Math/MathML"">"
        & "<mi>x</mi></math>" & ASCII.LF & "$$";
      Small_Font    : Pango.Font.Pango_Font_Description :=
        Pango.Font.From_String ("sans 8");
      Large_Font    : Pango.Font.Pango_Font_Description :=
        Pango.Font.From_String ("sans 18");
      Initial_Scale : Long_Float;
   begin
      if not T.Display_Available then
         Pango.Font.Free (Small_Font);
         Pango.Font.Free (Large_Font);
         return;
      end if;
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text (T.Stack.all, Source);
      End_Text_Block (T.Stack.all);
      Initial_Scale := Math_Scale (T.Stack.all, 1);
      Set_Font (T.Stack.all, Small_Font, Math_Scale => 1.0);
      Set_Font (T.Stack.all, Large_Font, Math_Scale => 2.0);
      Assert
        (Math_Scale (T.Stack.all, 1) > Initial_Scale,
         "native MathML scale changes during zoom");
      Assert
        (Math_Height (T.Stack.all, 1) > 0,
         "native MathML remains measured after zoom");
      Pango.Font.Free (Small_Font);
      Pango.Font.Free (Large_Font);
   end Test_Native_Display_Math_Zooms;

   procedure Test_Search_Covers_Request_Thinking_And_Streaming
     (T : in out Test)
   is
      Count : Natural;
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack.all, "Needle in request", Prompt);
      Begin_Thinking (T.Stack.all);
      Append_Thinking (T.Stack.all, "needle in reasoning");
      End_Thinking (T.Stack.all);
      Append_Text (T.Stack.all, "needle in answer");
      Count := Set_Search_Query (T.Stack.all, "needle");
      Assert (Count = 3, "search covers request, thinking, and response");
      Search_Next (T.Stack.all);
      Assert (Search_Match_Count (T.Stack.all) = 3,
              "next navigation retains all matches");
      Search_Previous (T.Stack.all);
      Assert (Search_Match_Count (T.Stack.all) = 3,
              "previous navigation wraps through matches");
      Append_Text (T.Stack.all, " plus needle");
      Assert (Search_Match_Count (T.Stack.all) = 4,
              "search refreshes when streaming text changes");
      Clear_Search (T.Stack.all);
      Assert (Search_Match_Count (T.Stack.all) = 0,
              "clearing search removes the result index");
   end Test_Search_Covers_Request_Thinking_And_Streaming;

   procedure Test_Inline_Markdown_Images_And_Search (T : in out Test) is
      Snow : constant String := Coyote_App.Utils.UC_CHECK;
      Source : constant String :=
        Coyote_App.Utils.UC_MICRO & " before !["
        & Snow & "](images/valid.png) after !["
        & Snow & "](images/valid.png) ";
      Expected_Visible : constant String :=
        Coyote_App.Utils.UC_MICRO & " before " & Snow & " after " & Snow
        & ASCII.LF & ASCII.LF & ASCII.LF & ASCII.LF;
      Root : constant String := To_String (T.Image_Root);
   begin
      if not T.Display_Available then
         return;
      end if;
      Ada.Directories.Create_Directory (Root & "/images");
      Write_PNG (Root & "/images/valid.png");
      Set_Source_Directory (T.Stack.all, Root);
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text (T.Stack.all, Source);
      End_Text_Block (T.Stack.all);
      Pump_Until_Images (T, 2);
      Assert
        (Find_Image_Count
           (Gtk.Widget.Gtk_Widget (Active_Text_View (T.Stack.all))) = 2,
         "each valid inline image creates its anchored image widget");
      Assert_Image_Anchor_At
        (T, 9,
         "first image anchor follows the multibyte UTF-8 prefix");
      Assert_Image_Anchor_At
        (T, 18,
         "second image anchor follows its preceding UTF-8 text");
      Assert
        (Active_Text (T.Stack.all) = Expected_Visible,
         "image alt text remains visible in original UTF-8 order: actual="
         & Active_Text (T.Stack.all) & " length="
         & Natural'Image (Active_Text (T.Stack.all)'Length)
         & " expected=" & Natural'Image (Expected_Visible'Length));
      Assert
        (Set_Search_Query (T.Stack.all, Snow) = 2,
         "search matches each image description");
      Assert
        (Active_Text (T.Stack.all) = Expected_Visible,
         "searching image descriptions does not alter visible text");
   end Test_Inline_Markdown_Images_And_Search;

   procedure Test_Inline_Markdown_Image_Policy (T : in out Test) is
      Root : constant String := To_String (T.Image_Root);
      Source : constant String :=
        "![local](ok.png) ![remote](https://example.invalid/a.png) "
        & "![outside](../outside.png) ![invalid](bad.png)";
      Math_Source : constant String :=
        "before ![first](ok.png)" & ASCII.LF & ASCII.LF
        & "$$" & ASCII.LF
        & "<math xmlns=""http://www.w3.org/1998/Math/MathML"">"
        & "<mn>1</mn></math>" & ASCII.LF & "$$" & ASCII.LF & ASCII.LF
        & "| A | B |" & ASCII.LF & "| --- | --- |" & ASCII.LF
        & "| x | y |" & ASCII.LF & ASCII.LF & "after ![last](ok.png)";
      Image_Run : constant String := "![cap](ok.png) ";
      Native_Split : constant String :=
        ASCII.LF & "$$" & ASCII.LF
        & "<math xmlns=""http://www.w3.org/1998/Math/MathML"">"
        & "<mn>1</mn></math>" & ASCII.LF & "$$" & ASCII.LF & ASCII.LF
        & "| A | B |" & ASCII.LF & "| --- | --- |" & ASCII.LF
        & "| x | y |" & ASCII.LF & ASCII.LF;
   begin
      if not T.Display_Available then
         return;
      end if;
      Write_PNG (Root & "/ok.png");
      Set_Source_Directory (T.Stack.all, Root);
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text (T.Stack.all, Source);
      End_Text_Block (T.Stack.all);
      Pump_Until_Images (T, 1);
      Assert
        (Find_Image_Count
           (Gtk.Widget.Gtk_Widget (Widget (T.Stack.all))) = 1,
         "only the in-root valid image loads successfully");
      Assert
        (Index (Active_Text (T.Stack.all), "local") > 0
         and then Index (Active_Text (T.Stack.all), "remote") > 0
         and then Index (Active_Text (T.Stack.all), "outside") > 0
         and then Index (Active_Text (T.Stack.all), "invalid") > 0,
         "all accepted and rejected descriptions remain readable");
      Drain_Gtk_Events;
      Clear (T.Stack.all);
      Begin_Request (T.Stack.all, "mixed request", Prompt);
      Append_Text (T.Stack.all, Math_Source);
      End_Text_Block (T.Stack.all);
      Pump_Until_Images (T, 2);
      Assert
        (Math_Element_Count (T.Stack.all) = 1
         and then Table_Count (T.Stack.all) = 1,
         "image anchors survive display-math and native-table splits");
      Assert
        (Find_Image_Count
           (Gtk.Widget.Gtk_Widget (Widget (T.Stack.all))) = 2,
         "images on both sides of native segments are retained");
      Assert
        (Set_Search_Query (T.Stack.all, "first") = 1
         and then Set_Search_Query (T.Stack.all, "last") = 1,
         "image alt text remains searchable across native splits");
      Clear (T.Stack.all);
      for Image_Index in 1 .. 17 loop
         if Image_Index = 1 then
            Begin_Request (T.Stack.all, "image cap", Prompt);
         end if;
         if Image_Index = 9 then
            Append_Text (T.Stack.all, Native_Split);
         end if;
         Append_Text (T.Stack.all, Image_Run);
      end loop;
      End_Text_Block (T.Stack.all);
      Pump_Until_Images (T, 16);
      Assert
        (Find_Image_Count
           (Gtk.Widget.Gtk_Widget (Widget (T.Stack.all))) = 16,
         "one response is capped at 16 images across native segments");
      Clear (T.Stack.all);
      Set_Render_Markdown (T.Stack.all, False);
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text (T.Stack.all, "![disabled](ok.png)");
      End_Text_Block (T.Stack.all);
      Pump_Until_Images (T, 1);
      Assert
        (Find_Image_Count
           (Gtk.Widget.Gtk_Widget (Widget (T.Stack.all))) = 0,
         "disabled Markdown rendering creates no inline image widget");
      Assert
        (Index (Active_Text (T.Stack.all), "![disabled](ok.png)") > 0,
         "disabled Markdown rendering retains the source description");
   end Test_Inline_Markdown_Image_Policy;

   procedure Test_Clear_With_Queued_Inline_Image (T : in out Test) is
      View : Gtk.Text_View.Gtk_Text_View;
      Root : constant String := To_String (T.Image_Root);
   begin
      if not T.Display_Available then
         return;
      end if;
      Write_PNG (Root & "/queued.png");
      Set_Source_Directory (T.Stack.all, Root);
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text (T.Stack.all, "![queued](queued.png)");
      End_Text_Block (T.Stack.all);
      View := Active_Text_View (T.Stack.all);
      Inline_View_Destroyed := False;
      View.On_Destroy (On_Inline_View_Destroy'Access);
      Clear (T.Stack.all);
      Assert (Inline_View_Destroyed,
              "clear explicitly destroys the image-owning text view");
      Drain_Gtk_Events;
      Assert
        (Find_Image_Count
           (Gtk.Widget.Gtk_Widget (Active_Text_View (T.Stack.all))) = 0,
         "late image completions do not restore widgets after clear");
      Assert (Active_Text (T.Stack.all) = "",
              "clearing queued image work leaves no stale response text");
      Begin_Request (T.Stack.all, "after clear", Prompt);
      Append_Text (T.Stack.all, "![retained](queued.png)");
      End_Text_Block (T.Stack.all);
      Pump_Until_Images (T, 1);
      Assert
        (Find_Image_Count
           (Gtk.Widget.Gtk_Widget (Active_Text_View (T.Stack.all))) = 1,
         "clear preserves the configured root for later local images");
      Assert
        (Index (Active_Text (T.Stack.all), "retained") > 0,
         "post-clear image alt text remains searchable");
   end Test_Clear_With_Queued_Inline_Image;

   package Coyote_GUI_Conversation_Stack_Caller is new AUnit.Test_Caller
     (Coyote_GUI_Conversation_Stack_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test
        (Coyote_GUI_Conversation_Stack_Caller.Create
           ("Coyote.GUI.Conversation_Stack creates single outer host",
            Coyote_GUI_Conversation_Stack_Tests.Test_Creates_Single_Outer_Host'
              Access));
      Result.Add_Test
        (Coyote_GUI_Conversation_Stack_Caller.Create
           ("Coyote.GUI.Conversation_Stack streams incrementally",
            Coyote_GUI_Conversation_Stack_Tests
              .Test_Request_And_Streaming_Are_Incremental'
              Access));
      Result.Add_Test
        (Coyote_GUI_Conversation_Stack_Caller.Create
           ("Coyote.GUI.Conversation_Stack finalizes an open text block "
            & "for a new request",
            Coyote_GUI_Conversation_Stack_Tests
              .Test_Begin_Request_Finalizes_Open_Text_Block'Access));
      Result.Add_Test
        (Coyote_GUI_Conversation_Stack_Caller.Create
           ("Coyote.GUI.Conversation_Stack removes the active stream mark "
            & "on clear",
            Coyote_GUI_Conversation_Stack_Tests
              .Test_Clear_Removes_Active_Stream_Mark'Access));
      Result.Add_Test
        (Coyote_GUI_Conversation_Stack_Caller.Create
           ("Coyote.GUI.Conversation_Stack applies the configured font "
            & "to new response views",
            Coyote_GUI_Conversation_Stack_Tests
              .Test_Set_Font_Applies_To_New_Response_Views'Access));
      Result.Add_Test
        (Coyote_GUI_Conversation_Stack_Caller.Create
           ("Coyote.GUI.Conversation_Stack applies the configured font "
            & "to new table labels",
            Coyote_GUI_Conversation_Stack_Tests
              .Test_Set_Font_Applies_To_New_Table_Labels'Access));
      Result.Add_Test
        (Coyote_GUI_Conversation_Stack_Caller.Create
           ("Coyote.GUI.Conversation_Stack validates Markdown link targets",
            Coyote_GUI_Conversation_Stack_Tests
              .Test_Markdown_Link_Destination_Policy'Access));
      Result.Add_Test
        (Coyote_GUI_Conversation_Stack_Caller.Create
           ("Coyote.GUI.Conversation_Stack launches Markdown link clicks",
            Test_Native_Markdown_Link_Click_Dispatches'Access));
      Result.Add_Test
        (Coyote_GUI_Conversation_Stack_Caller.Create
           ("Coyote.GUI.Conversation_Stack updates Markdown link cursor",
            Coyote_GUI_Conversation_Stack_Tests
              .Test_Native_Markdown_Link_Hover_Cursor'Access));
      Result.Add_Test
        (Coyote_GUI_Conversation_Stack_Caller.Create
           ("Coyote.GUI.Conversation_Stack renders Markdown",
            Coyote_GUI_Conversation_Stack_Tests
              .Test_Native_Markdown_Renders_After_Streaming'
              Access));
      Result.Add_Test
        (Coyote_GUI_Conversation_Stack_Caller.Create
           ("Coyote.GUI.Conversation_Stack toggles Markdown rendering",
            Coyote_GUI_Conversation_Stack_Tests
              .Test_Native_Markdown_Toggle_Disables_Rendering'
              Access));
      Result.Add_Test
        (Coyote_GUI_Conversation_Stack_Caller.Create
           ("Coyote.GUI.Conversation_Stack realizes native tables",
            Coyote_GUI_Conversation_Stack_Tests
              .Test_Native_Table_Realizes_Grid'
              Access));
      Result.Add_Test
        (Coyote_GUI_Conversation_Stack_Caller.Create
           ("Coyote.GUI.Conversation_Stack toggles native tables",
            Coyote_GUI_Conversation_Stack_Tests
              .Test_Native_Table_Toggle_Disables_Rendering'
              Access));
      Result.Add_Test
        (Coyote_GUI_Conversation_Stack_Caller.Create
           ("Coyote.GUI.Conversation_Stack skips table whitespace blocks",
            Coyote_GUI_Conversation_Stack_Tests
              .Test_Native_Response_Table_Skips_Whitespace_Blocks'
              Access));
      Result.Add_Test
        (Coyote_GUI_Conversation_Stack_Caller.Create
           ("Coyote.GUI.Conversation_Stack skips mixed whitespace blocks",
            Coyote_GUI_Conversation_Stack_Tests
              .Test_Native_Response_Mixed_Blocks_Skip_Whitespace'
              Access));
      Result.Add_Test
        (Coyote_GUI_Conversation_Stack_Caller.Create
           ("Coyote.GUI.Conversation_Stack realizes display MathML",
            Coyote_GUI_Conversation_Stack_Tests
              .Test_Native_Display_Math_Realizes_Element'
              Access));
      Result.Add_Test
        (Coyote_GUI_Conversation_Stack_Caller.Create
           ("Coyote.GUI.Conversation_Stack falls back for invalid MathML",
            Coyote_GUI_Conversation_Stack_Tests
              .Test_Native_Display_Math_Invalid_Falls_Back'
              Access));
      Result.Add_Test
        (Coyote_GUI_Conversation_Stack_Caller.Create
           ("Coyote.GUI.Conversation_Stack protects code MathML",
            Coyote_GUI_Conversation_Stack_Tests
              .Test_Native_Display_Math_Protects_Code'
              Access));
      Result.Add_Test
        (Coyote_GUI_Conversation_Stack_Caller.Create
           ("Coyote.GUI.Conversation_Stack zooms display MathML",
            Coyote_GUI_Conversation_Stack_Tests.Test_Native_Display_Math_Zooms'
              Access));
      Result.Add_Test
        (Coyote_GUI_Conversation_Stack_Caller.Create
           ("Coyote.GUI.Conversation_Stack uses visible step frames",
            Coyote_GUI_Conversation_Stack_Tests
              .Test_Assistant_Content_Uses_Visible_Step_Frame'
              Access));
      Result.Add_Test
        (Coyote_GUI_Conversation_Stack_Caller.Create
           ("Coyote.GUI.Conversation_Stack separates assistant steps",
            Coyote_GUI_Conversation_Stack_Tests
              .Test_Footer_Closes_Step_Before_Next_Step'
              Access));
      Result.Add_Test
        (Coyote_GUI_Conversation_Stack_Caller.Create
           ("Coyote.GUI.Conversation_Stack separates cancelled steps",
            Coyote_GUI_Conversation_Stack_Tests
              .Test_Cancelled_Tool_Closes_Step_Without_Footer'Access));
      Result.Add_Test
        (Coyote_GUI_Conversation_Stack_Caller.Create
           ("Coyote.GUI.Conversation_Stack resets step frames for new "
            & "requests",
            Coyote_GUI_Conversation_Stack_Tests
              .Test_New_Request_Resets_Step_Frames'
              Access));
      Result.Add_Test
        (Coyote_GUI_Conversation_Stack_Caller.Create
           ("Coyote.GUI.Conversation_Stack updates tools by stable ID",
            Coyote_GUI_Conversation_Stack_Tests.Test_Tool_Updates_By_Stable_Id'
              Access));
      Result.Add_Test
        (Coyote_GUI_Conversation_Stack_Caller.Create
           ("Coyote.GUI.Conversation_Stack tracks tool status transitions",
            Coyote_GUI_Conversation_Stack_Tests.Test_Tool_Status_Transitions'
              Access));
      Result.Add_Test
        (Coyote_GUI_Conversation_Stack_Caller.Create
           ("Coyote.GUI.Conversation_Stack closes tools at request completion",
            Coyote_GUI_Conversation_Stack_Tests
              .Test_Request_Completion_Closes_Active_Tools'Access));
      Result.Add_Test
        (Coyote_GUI_Conversation_Stack_Caller.Create
           ("Coyote.GUI.Conversation_Stack tracks abort controls by status",
            Coyote_GUI_Conversation_Stack_Tests
              .Test_Tool_Abort_Controls_Follow_Status'
              Access));
      Result.Add_Test
        (Coyote_GUI_Conversation_Stack_Caller.Create
           ("Coyote.GUI.Conversation_Stack uses horizontal tool actions",
            Coyote_GUI_Conversation_Stack_Tests
              .Test_Tool_Action_Buttons_Use_Horizontal_Row'
              Access));
      Result.Add_Test
        (Coyote_GUI_Conversation_Stack_Caller.Create
           ("Coyote.GUI.Conversation_Stack uses responsive tool flow",
            Coyote_GUI_Conversation_Stack_Tests
              .Test_Tool_Cards_Use_Responsive_Flow'
              Access));
      Result.Add_Test
        (Coyote_GUI_Conversation_Stack_Caller.Create
           ("Coyote.GUI.Conversation_Stack uses native labels and "
            & "View Details action",
            Coyote_GUI_Conversation_Stack_Tests
              .Test_Tool_Card_Uses_Native_Labels'
              Access));
      Result.Add_Test
        (Coyote_GUI_Conversation_Stack_Caller.Create
           ("Coyote.GUI.Conversation_Stack renders tool image thumbnails",
            Coyote_GUI_Conversation_Stack_Tests.Test_Tool_Image_Thumbnail'
              Access));
      Result.Add_Test
        (Coyote_GUI_Conversation_Stack_Caller.Create
           ("Coyote.GUI.Conversation_Stack keeps footer kind explicit",
            Coyote_GUI_Conversation_Stack_Tests
              .Test_Footer_Kind_And_Completion_Are_Explicit'
              Access));
      Result.Add_Test
        (Coyote_GUI_Conversation_Stack_Caller.Create
           ("Coyote.GUI.Conversation_Stack uses native footer status row",
            Coyote_GUI_Conversation_Stack_Tests
              .Test_Native_Footer_Uses_Status_Row_And_Fork_Button'
              Access));
      Result.Add_Test
        (Coyote_GUI_Conversation_Stack_Caller.Create
           ("Coyote.GUI.Conversation_Stack clears exchange state",
            Coyote_GUI_Conversation_Stack_Tests
              .Test_Clear_Removes_Exchange_State'
              Access));

      Result.Add_Test
        (Coyote_GUI_Conversation_Stack_Caller.Create
           ("Coyote.GUI.Conversation_Stack searches request, thinking, and "
            & "streaming response text",
            Coyote_GUI_Conversation_Stack_Tests
              .Test_Search_Covers_Request_Thinking_And_Streaming'Access));
      Result.Add_Test
        (Coyote_GUI_Conversation_Stack_Caller.Create
           ("Coyote.GUI.Conversation_Stack preserves and searches image alt text",
            Coyote_GUI_Conversation_Stack_Tests
              .Test_Inline_Markdown_Images_And_Search'Access));
      Result.Add_Test
        (Coyote_GUI_Conversation_Stack_Caller.Create
           ("Coyote.GUI.Conversation_Stack applies inline image policy",
            Coyote_GUI_Conversation_Stack_Tests
              .Test_Inline_Markdown_Image_Policy'Access));
      Result.Add_Test
        (Coyote_GUI_Conversation_Stack_Caller.Create
           ("Coyote.GUI.Conversation_Stack clears queued image work",
            Coyote_GUI_Conversation_Stack_Tests
              .Test_Clear_With_Queued_Inline_Image'Access));

      return Result;
   end Suite;

end Coyote_GUI_Conversation_Stack_Tests;
