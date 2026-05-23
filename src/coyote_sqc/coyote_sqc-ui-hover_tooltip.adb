--  Coyote_SQC.UI.Hover_Tooltip body.
--
--  Project: coyote

with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Coyote_SQC.Data_Model;
with Gtk.Drawing_Area;
with Coyote_SQC.App;
with Glib;           use Glib;
with Gdk.Rectangle;
with Gtk.Label;
with Gtk.Popover;
with Coyote_Renderer.Markup;
with Gtk.Widget;

package body Coyote_SQC.UI.Hover_Tooltip is
   use type Coyote_SQC.App.App_State_Access;
   use type Gtk.Popover.Gtk_Popover;

   The_Popover  : Gtk.Popover.Gtk_Popover := null;
   The_Label    : Gtk.Label.Gtk_Label    := null;
   The_Canvas   : Gtk.Drawing_Area.Gtk_Drawing_Area := null;
   Tooltip_Visible : Boolean := False;

   function Is_Visible return Boolean is (Tooltip_Visible);

   procedure Attach
     (Canvas : not null access Gtk.Drawing_Area.Gtk_Drawing_Area_Record'Class)
   is
      use Gtk.Popover;
      use Gtk.Label;
   begin
      The_Canvas := Gtk.Drawing_Area.Gtk_Drawing_Area (Canvas);
      Gtk.Popover.Gtk_New (The_Popover, The_Canvas);
      The_Popover.Set_Modal (False);
      Gtk.Label.Gtk_New (The_Label, "");
      The_Label.Set_Use_Markup (True);
      The_Popover.Add (The_Label);
   end Attach;

   function Format_Number (N : Long_Long_Integer) return String is
      use Ada.Strings.Fixed;
   begin
      return Trim (N'Image, Ada.Strings.Left);
   end Format_Number;

   procedure Show_For_Session
     (Session_Id : String;
      Screen_X   : Long_Float;
      Screen_Y   : Long_Float)
   is
      use Ada.Calendar;
      use Ada.Calendar.Formatting;
      use Ada.Strings.Fixed;
      use Ada.Strings.Unbounded;

      --  Find the session.
      Sess_Found : Boolean := False;
      S_Idx      : Natural := 0;
   begin
      if The_Popover = null or else Coyote_SQC.App.State = null then
         return;
      end if;

      for I in 1 .. Positive (Coyote_SQC.App.State.Sessions.Length) loop
         if To_String
              (Coyote_SQC.App.State.Sessions.Element (I).Session_Id)
            = Session_Id
         then
            Sess_Found := True;
            S_Idx := I;
            exit;
         end if;
      end loop;

      if not Sess_Found then
         return;
      end if;

      declare
         Sess : constant Coyote_SQC.Data_Model.Session_Record :=
           Coyote_SQC.App.State.Sessions.Element (S_Idx);
         Ts   : constant String := Ada.Calendar.Formatting.Image
           (Sess.Start_Time, Time_Zone => 0);
         TS14 : constant String := Ts (Ts'First .. Ts'First + 15);
         Model_Str : constant String := To_String (Sess.Model);
         Src_Str   : constant String := To_String (Sess.Source_Directory);
         Prompt    : constant String := To_String (Sess.First_User_Message);
         P_Len     : constant Natural := Natural'Min (Prompt'Length, 80);
         P_Display : constant String :=
           Prompt (Prompt'First .. Prompt'First + P_Len - 1)
           & (if Prompt'Length > 80 then "..." else "");

         --  Comment count
         N_Comments : Natural := 0;
      begin
         for C of Coyote_SQC.App.State.Workspace.Comments loop
            if To_String (C.Session_Id) = Session_Id then
               N_Comments := N_Comments + 1;
            end if;
         end loop;

         declare
            --  XML-escape variable strings to prevent Pango markup errors.
            Esc_Model  : constant String :=
              Coyote_Renderer.Markup.Xml_Escape (Model_Str);
            Esc_Src    : constant String :=
              Coyote_Renderer.Markup.Xml_Escape (Src_Str);
            Esc_Prompt : constant String :=
              Coyote_Renderer.Markup.Xml_Escape (P_Display);
            Markup : constant String :=
              "<b>" & TS14 & "</b>"
              & "  " & Esc_Model & ASCII.LF
              & Esc_Src & ASCII.LF & ASCII.LF
              & "&quot;" & Esc_Prompt & "&quot;" & ASCII.LF & ASCII.LF
              & "Input: "
              & Format_Number (Long_Long_Integer (Sess.Total_Input_Tokens))
              & " tokens   Output: "
              & Format_Number (Long_Long_Integer (Sess.Total_Output_Tokens))
              & " tokens"
              & (if N_Comments > 0
                 then ASCII.LF & "Comments: "
                      & Trim (N_Comments'Image, Ada.Strings.Left)
                 else "");
         begin
            The_Label.Set_Markup (Markup);
         end;

         --  Position the popover at the cursor.
         declare
            Rect : Gdk.Rectangle.Gdk_Rectangle :=
              (X      => Glib.Gint (Integer (Screen_X)),
               Y      => Glib.Gint (Integer (Screen_Y)),
               Width  => 1,
               Height => 1);
         begin
            The_Popover.Set_Pointing_To (Rect);
         end;
         The_Popover.Show_All;
         Tooltip_Visible := True;
      end;
   end Show_For_Session;

   procedure Hide is
   begin
      if The_Popover /= null and then Tooltip_Visible then
         The_Popover.Popdown;
         Tooltip_Visible := False;
      end if;
      if Coyote_SQC.App.State /= null then
         Coyote_SQC.App.State.Canvas_St.Hovered_Session_Id :=
           Ada.Strings.Unbounded.Null_Unbounded_String;
      end if;
   end Hide;

end Coyote_SQC.UI.Hover_Tooltip;
