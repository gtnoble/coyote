--  Coyote_GUI.Rich_Text body.
--
--  Image jobs retain their widgets until destruction, while their completion
--  callback runs only on the GTK main context (or synchronously on rejection).

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Unchecked_Deallocation;
with Coyote_GUI.Markdown_Links;
with Coyote_Image_Jobs;
with Gdk.Pixbuf;
with Glib;
with Glib.Object;
with Gtk.Image;
with Gtk.Widget;
with Gtk.Enums;
with Gtk.Text_Buffer;
with Gtk.Text_Child_Anchor;
with Gtk.Text_Iter;
with Gtk.Handlers;

package body Coyote_GUI.Rich_Text is

   use type Gtk.Image.Gtk_Image;
   use type Glib.Gint;

   Max_Images : constant := 16;
   Max_Width  : constant := 640;

   type Job;
   type Job_Access is access all Job;

   type Job is new Coyote_Image_Jobs.Consumer with record
      Image   : Gtk.Image.Gtk_Image;
      Tooltip : Unbounded_String;
      Alive   : Boolean := True;
      Pending : Boolean := True;
   end record;

   overriding procedure Completed
     (Target : in out Job;
      Pixbuf : Gdk.Pixbuf.Gdk_Pixbuf;
      Error  : String);

   procedure Free is new Ada.Unchecked_Deallocation (Job, Job_Access);

   package Destroy_Callback is new Gtk.Handlers.User_Callback
     (Gtk.Image.Gtk_Image_Record, Job_Access);

   procedure Release (Data : Job_Access) is
      Item : Job_Access := Data;
   begin
      Free (Item);
   end Release;

   procedure On_Destroy
     (Image : access Gtk.Image.Gtk_Image_Record'Class;
      Data  : Job_Access);

   function Is_Local (Destination : String) return Boolean is
      Colon : Natural;
   begin
      if Destination'Length >= 2
        and then Destination (Destination'First ..
          Destination'First + 1) = "//"
      then
         return False;
      end if;
      Colon := 0;
      for Index in Destination'Range loop
         if Destination (Index) = ':' then
            Colon := Index;
            exit;
         elsif Destination (Index) = '/' then
            return True;
         end if;
      end loop;
      if Colon = 0 then
         return True;
      end if;
      return Destination (Destination'First .. Colon) = "file:";
   end Is_Local;

   function Tooltip (Info : Coyote_Renderer.Markup.Image_Info)
      return String
   is
      Title : constant String := To_String (Info.Title);
      Alt   : constant String := To_String (Info.Alt_Text);
   begin
      if Title'Length = 0 then
         return Alt;
      elsif Alt'Length = 0 then
         return Title;
      else
         return Title & " - " & Alt;
      end if;
   end Tooltip;

   procedure On_Destroy
     (Image : access Gtk.Image.Gtk_Image_Record'Class;
      Data  : Job_Access)
   is
      pragma Unreferenced (Image);
   begin
      if Data = null then
         return;
      end if;
      Data.Alive := False;
      Data.Image := null;
      if not Data.Pending then
         Release (Data);
      end if;
   exception
      when others =>
         null;
   end On_Destroy;

   overriding procedure Completed
     (Target : in out Job;
      Pixbuf : Gdk.Pixbuf.Gdk_Pixbuf;
      Error  : String)
   is
      Data : constant Job_Access := Target'Unchecked_Access;
      use type Gdk.Pixbuf.Gdk_Pixbuf;
   begin
      Data.Pending := False;
      if Data.Alive and then Data.Image /= null then
         if Pixbuf /= null then
            Gtk.Image.Set (Data.Image, Pixbuf);
         else
            Data.Image.Set_From_Icon_Name
              ("image-missing", Gtk.Enums.Icon_Size_Button);
         end if;
         if Error'Length > 0 then
            Data.Image.Set_Tooltip_Text
              (To_String (Data.Tooltip) & ASCII.LF & Error);
         end if;
      end if;
      if not Data.Alive then
         Release (Data);
      end if;
   exception
      when others =>
         Data.Pending := False;
         if not Data.Alive then
            Release (Data);
         end if;
   end Completed;

   procedure Add_Image
     (View       : not null access
        Gtk.Text_View.Gtk_Text_View_Record'Class;
      Buffer     : not null access
        Gtk.Text_Buffer.Gtk_Text_Buffer_Record'Class;
      Info       : Coyote_Renderer.Markup.Image_Info;
      Base_Chars : Natural;
      Root       : String)
   is
      Offset : Natural := 0;
      Iter   : Gtk.Text_Iter.Gtk_Text_Iter;
      Anchor : Gtk.Text_Child_Anchor.Gtk_Text_Child_Anchor;
      Image  : Gtk.Image.Gtk_Image := null;
      Job_Data : Job_Access := null;
      Width   : Glib.Gint := View.Get_Allocated_Width;
      Submitted : Boolean := False;
   begin
      if Base_Chars > Natural (Buffer.Get_Char_Count)
        or else Info.End_Char < Info.Start_Char
        or else Info.End_Char >
          Natural (Buffer.Get_Char_Count) - Base_Chars
      then
         return;
      end if;
      Offset := Base_Chars + Info.Start_Char;
      Buffer.Get_Iter_At_Offset (Iter, Glib.Gint (Offset));
      Anchor := Buffer.Create_Child_Anchor (Iter);
      Gtk.Image.Gtk_New_From_Icon_Name
        (Image, "image-loading", Gtk.Enums.Icon_Size_Button);
      Image.Set_Name ("coyote-response-image");
      Image.Set_Tooltip_Text (Tooltip (Info));
      Image.Set_No_Show_All (True);
      View.Add_Child_At_Anchor (Image, Anchor);
      Image.Show;
      Job_Data := new Job'
        (Image   => Image,
         Tooltip => To_Unbounded_String (Tooltip (Info)),
         Alive   => True,
         Pending => True);
      Destroy_Callback.Connect (Image, "destroy", On_Destroy'Access, Job_Data);
      if Width <= 64 then
         Width := Max_Width;
      else
         Width := Glib.Gint'Min (Width, Max_Width);
      end if;
      Width := Glib.Gint'Max (1, Width - 8);
      Coyote_Image_Jobs.Submit
        (Root, To_String (Info.Destination), Positive (Width),
         Coyote_Image_Jobs.Consumer_Access (Job_Data));
      Submitted := True;
      Image.Set_Size_Request (-1, -1);
   exception
      when others =>
         if not Submitted then
            if Job_Data /= null then
               Job_Data.Pending := False;
            end if;
            if Image /= null then
               Gtk.Widget.Destroy (Gtk.Widget.Gtk_Widget (Image));
            elsif Job_Data /= null then
               Release (Job_Data);
            end if;
         end if;
   end Add_Image;

   procedure Insert
     (View             : not null access
        Gtk.Text_View.Gtk_Text_View_Record'Class;
      Result           : Coyote_Renderer.Markup.Render_Result;
      Source_Directory : String;
      Images_Remaining : in out Natural;
      Clear            : Boolean := False)
   is
      Buffer : constant Gtk.Text_Buffer.Gtk_Text_Buffer := View.Get_Buffer;
      Base   : Natural;
      Count  : Natural := 0;
   begin
      if Clear then
         Buffer.Set_Text ("");
      end if;
      Base := Natural (Buffer.Get_Char_Count);
      Coyote_GUI.Markdown_Links.Insert (Buffer, Result);
      if Source_Directory'Length = 0 or else Result.Images.Is_Empty
        or else Images_Remaining = 0
      then
         return;
      end if;
      for Index in reverse Result.Images.First_Index ..
        Result.Images.Last_Index
      loop
         exit when Count = Natural'Min (Max_Images, Images_Remaining);
         declare
            Info : constant Coyote_Renderer.Markup.Image_Info :=
              Result.Images (Index);
            Destination : constant String := To_String (Info.Destination);
         begin
            if Is_Local (Destination) then
               Add_Image (View, Buffer, Info, Base, Source_Directory);
               Count := Count + 1;
            end if;
         end;
      end loop;
      Images_Remaining := Images_Remaining - Count;
   end Insert;

end Coyote_GUI.Rich_Text;
