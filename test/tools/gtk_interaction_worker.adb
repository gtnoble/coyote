--  Gtk_Interaction_Worker — isolated native conversation interaction probe.
--  Project: coyote

with Ada.Command_Line;
with Ada.Exceptions;
with Ada.Real_Time;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Coyote_App.Utils;
with Coyote_GUI;
with Coyote_GUI.Conversation_Stack;
with Coyote_GUI.Conversation_Stack.Testing;
with Coyote_Math_Jobs;
with Gdk.Pixbuf;
with Gdk.Rectangle;
with Glib;
with Gtk.Adjustment;
with Gtk.Clipboard;
with Gtk.Enums;
with Gtk.Main;
with Gtk.Text_Buffer;
with Gtk.Text_Iter;
with Gtk.Text_View;
with Gtk.Window;
with Pango.Font;

procedure Gtk_Interaction_Worker is
   use type Ada.Real_Time.Time;
   use type Glib.Gint;
   use type Glib.Gdouble;
   use type Gdk.Pixbuf.Gdk_Pixbuf;
   use type Gtk.Text_View.Gtk_Text_View;
   use type Gtk.Window.Gtk_Window;

   package Stack renames Coyote_GUI.Conversation_Stack;
   package Testing renames Coyote_GUI.Conversation_Stack.Testing;

   Window : Gtk.Window.Gtk_Window;
   Conversation : aliased Stack.Instance;
   Name : constant String :=
     (if Ada.Command_Line.Argument_Count = 1
      then Ada.Command_Line.Argument (1) else "");

   procedure Check (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Check;

   procedure Drain is
      Continue : Boolean;
      pragma Unreferenced (Continue);
   begin
      for Index in 1 .. 80 loop
         Continue := Gtk.Main.Main_Iteration_Do (False);
         delay 0.001;
      end loop;
   end Drain;

   procedure Wait_For_Pixbuf (View : Gtk.Text_View.Gtk_Text_View) is
      Buffer : constant Gtk.Text_Buffer.Gtk_Text_Buffer := View.Get_Buffer;
      Iter : Gtk.Text_Iter.Gtk_Text_Iter;
      Moved : Boolean;
      Deadline : constant Ada.Real_Time.Time :=
        Ada.Real_Time.Clock + Ada.Real_Time.Seconds (2);
   begin
      loop
         Buffer.Get_Start_Iter (Iter);
         while not Gtk.Text_Iter.Is_End (Iter) loop
            if Gtk.Text_Iter.Get_Pixbuf (Iter) /= null then
               return;
            end if;
            Gtk.Text_Iter.Forward_Char (Iter, Moved);
            exit when not Moved;
         end loop;
         Check (Ada.Real_Time.Clock < Deadline,
                "inline pixbuf did not arrive within two seconds");
         Drain;
      end loop;
   end Wait_For_Pixbuf;

   procedure Hit_Test (View : Gtk.Text_View.Gtk_Text_View) is
      Buffer : constant Gtk.Text_Buffer.Gtk_Text_Buffer := View.Get_Buffer;
      Position : Gtk.Text_Iter.Gtk_Text_Iter;
      Hit : aliased Gtk.Text_Iter.Gtk_Text_Iter;
      Rect : Gdk.Rectangle.Gdk_Rectangle;
      Found : Boolean;
      pragma Unreferenced (Found);
   begin
      Check (View.Get_Realized, "hit-test view must be realized");
      Check (View.Get_Pixels_Below_Lines = 0, "unsafe below-line padding");
      for Index in 0 .. Glib.Gint'Min (Buffer.Get_Char_Count, 120) loop
         Buffer.Get_Iter_At_Offset (Position, Index);
         View.Get_Iter_Location (Position, Rect);
         Found := View.Get_Iter_At_Location
           (Hit'Access, Rect.X, Rect.Y + Rect.Height / 2);
         --  Hidden text and end-of-line positions need not be inside glyphs.
         Check
           (Gtk.Text_Iter.Get_Offset (Hit) in 0 .. Buffer.Get_Char_Count,
            "character hit-test escaped buffer");
      end loop;
      for Y in 0 .. View.Get_Allocated_Height loop
         for X of Glib.Gint_Array'(0, 8, 100, 300) loop
            Found := View.Get_Iter_At_Location (Hit'Access, X, Y);
            Check
              (Gtk.Text_Iter.Get_Offset (Hit) in 0 .. Buffer.Get_Char_Count,
               "line-boundary hit-test escaped buffer");
         end loop;
      end loop;
   end Hit_Test;

   function Source return String is
   begin
      if Name = "plain" then
         return "Selectable plain text with enough words to wrap.";
      elsif Name = "unicode" then
         return "Unicode " & Coyote_App.Utils.UC_CHECK
           & " caf" & Character'Val (16#C3#) & Character'Val (16#A9#)
           & " " & Coyote_App.Utils.UC_MICRO;
      elsif Name = "bidi" then
         return "English "
           & Character'Val (16#D8#) & Character'Val (16#B3#)
           & Character'Val (16#D9#) & Character'Val (16#84#)
           & Character'Val (16#D8#) & Character'Val (16#A7#)
           & Character'Val (16#D9#) & Character'Val (16#85#)
           & " trailing English";
      elsif Name = "inline-math" then
         return "Formula $\frac{1}{2}$ and $x$." & ASCII.LF
           & ASCII.LF & "Short.";
      elsif Name = "multiline" then
         return "First line with enough content to wrap." & ASCII.LF
           & "Second line with more content to wrap." & ASCII.LF
           & ASCII.LF & "A final paragraph.";
      else
         raise Program_Error with "unknown scenario: " & Name;
      end if;
   end Source;

   procedure Exercise is
      Text : constant String := Source;
      View : Gtk.Text_View.Gtk_Text_View;
      Buffer : Gtk.Text_Buffer.Gtk_Text_Buffer;
      First, Last : Gtk.Text_Iter.Gtk_Text_Iter;
      Adjustment : Gtk.Adjustment.Gtk_Adjustment;
      Font : Pango.Font.Pango_Font_Description;
   begin
      for Round in 1 .. 2 loop
         Stack.Begin_Request (Conversation, "request", Coyote_GUI.Prompt);
         Stack.Append_Text (Conversation, Text);
         Stack.End_Text_Block (Conversation);
         Stack.Complete_Request (Conversation, Coyote_GUI.Completed);
         Window.Show_All;
         Drain;
         View := Testing.Active_Text_View (Conversation);
         Check (View /= null, "response view missing");
         if Name = "inline-math" then
            Wait_For_Pixbuf (View);
         end if;
         Hit_Test (View);
         Buffer := View.Get_Buffer;
         Buffer.Get_Bounds (First, Last);
         Buffer.Select_Range (First, Last);
         Stack.Copy_Selection (Conversation);
         declare
            Copy : constant String :=
              Gtk.Clipboard.Wait_For_Text (Gtk.Clipboard.Get);
         begin
            Check
              (Copy = Buffer.Get_Text (First, Last, True),
               "selection copy did not preserve complete buffer source");
            if Name /= "multiline" then
               Check (Ada.Strings.Fixed.Index (Copy, Text) = 1,
                      "copy lost formula or Unicode source");
            else
               Check (Ada.Strings.Fixed.Index (Copy, "Second line") > 0
                        and then Ada.Strings.Fixed.Index
                          (Copy, "A final paragraph.") > 0,
                      "copy lost multiline content");
            end if;
         end;
         Window.Resize (Glib.Gint (340 + Round * 90), 180);
         Font := Pango.Font.From_String
           ((if Round = 1 then "sans 14" else "sans 10"));
         Stack.Set_Font (Conversation, Font, Math_Scale => 1.25);
         Pango.Font.Free (Font);
         Drain;
         Hit_Test (View);
         Adjustment := Stack.Widget (Conversation).Get_Vadjustment;
         Adjustment.Set_Value
           (Glib.Gdouble'Max
              (Adjustment.Get_Lower,
               Adjustment.Get_Upper - Adjustment.Get_Page_Size));
         Drain;
         Adjustment.Set_Value (Adjustment.Get_Lower);
         Drain;
         Stack.Clear (Conversation);
         Check (not Testing.Has_Exchange (Conversation),
                "clear retained an exchange");
      end loop;
   end Exercise;
begin
   Check (Name /= "", "expected one scenario name");
   Gtk.Main.Init;
   Gtk.Window.Gtk_New (Window, Gtk.Enums.Window_Toplevel);
   Window.Set_Default_Size (340, 180);
   Stack.Create (Conversation, Window.all'Access);
   Window.Add (Stack.Widget (Conversation));
   Exercise;
   Stack.Clear (Conversation);
   Coyote_Math_Jobs.Shutdown;
   Window.Destroy;
   Ada.Text_IO.Put_Line ("PASS " & Name);
exception
   when E : others =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "FAIL " & Name & ": " & Ada.Exceptions.Exception_Information (E));
      Coyote_Math_Jobs.Shutdown;
      if Window /= null then
         Stack.Clear (Conversation);
         Window.Destroy;
      end if;
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Gtk_Interaction_Worker;
