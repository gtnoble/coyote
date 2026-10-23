--  Coyote_GUI.Rich_Text body.
--
--  Image jobs retain their widgets until destruction, while their completion
--  callback runs only on the GTK main context (or synchronously on rejection).

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Containers.Vectors;
with Ada.Unchecked_Deallocation;
with Coyote_GUI.Markdown_Links;
with Coyote_GUI.Math_Element;
with Coyote_Image_Jobs;
with Gdk.Pixbuf;
with Gdk.RGBA;
with Glib;
with Glib.Object;
with Glib.Properties;
with Gtk.Image;
with Gtk.Widget;
with Gtk.Enums;
with Gtk.Style_Context;
with Gtk.Text_Buffer;
with Pango.Context;
with Pango.Font;
with Gtk.Text_Child_Anchor;
with Gtk.Text_Iter;
with Gtk.Text_Mark;
with Gtk.Text_Tag;
with Gtk.Text_Tag_Table;
with Gtk.Clipboard;
with Gtk.Handlers;

package body Coyote_GUI.Rich_Text is

   use type Gtk.Image.Gtk_Image;
   use type Glib.Gint;
   use type Gtk.Clipboard.Gtk_Clipboard;
   use type Gtk.Text_Tag.Gtk_Text_Tag;
   use type Ada.Containers.Count_Type;
   use type Gtk.Text_Mark.Gtk_Text_Mark;
   use type Gdk.Pixbuf.Gdk_Pixbuf;

   Max_Images : constant := 16;
   Max_Width  : constant := 640;

   package Copy_Connected is new Glib.Object.User_Data (Boolean);

   Max_Formulas : constant := 64;

   type Formula_State is record
      LaTeX : Unbounded_String;
      Source : Unbounded_String;
      Source_Start : Gtk.Text_Mark.Gtk_Text_Mark;
      Source_End : Gtk.Text_Mark.Gtk_Text_Mark;
      Image_Start : Gtk.Text_Mark.Gtk_Text_Mark;
      Image_End : Gtk.Text_Mark.Gtk_Text_Mark;
      Hidden : Gtk.Text_Tag.Gtk_Text_Tag;
      Rise : Gtk.Text_Tag.Gtk_Text_Tag;
   end record;
   subtype Math_Span is Coyote_Renderer.Markup.Math_Span;

   package Formula_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Formula_State);
   type Render_State is record
      Formulas : Formula_Vectors.Vector;
      Scale : Long_Float := 1.0;
   end record;
   package Render_States is new Glib.Object.User_Data (Render_State);

   type Image_State is record
      Info : Coyote_Renderer.Markup.Image_Info;
      Anchor : Gtk.Text_Mark.Gtk_Text_Mark;
   end record;
   package Image_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Image_State);

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
      Anchor_Mark : Gtk.Text_Mark.Gtk_Text_Mark;
      Root        : String)
   is
      Iter   : Gtk.Text_Iter.Gtk_Text_Iter;
      Anchor : Gtk.Text_Child_Anchor.Gtk_Text_Child_Anchor;
      Image  : Gtk.Image.Gtk_Image := null;
      Job_Data : Job_Access := null;
      Width   : Glib.Gint := View.Get_Allocated_Width;
      Submitted : Boolean := False;
   begin
      if Anchor_Mark = null
        or else Gtk.Text_Mark.Get_Deleted (Anchor_Mark)
      then
         return;
      end if;
      Buffer.Get_Iter_At_Mark (Iter, Anchor_Mark);
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

   procedure On_Copy
     (View : access Gtk.Text_View.Gtk_Text_View_Record'Class);

   procedure On_Copy
     (View : access Gtk.Text_View.Gtk_Text_View_Record'Class)
   is
   begin
      Copy_Selection (View);
      Gtk.Handlers.Emit_Stop_By_Name (View, "copy-clipboard");
   end On_Copy;

   procedure Copy_Selection
     (View : not null access Gtk.Text_View.Gtk_Text_View_Record'Class)
   is
      Buffer : constant Gtk.Text_Buffer.Gtk_Text_Buffer := View.Get_Buffer;
      First : Gtk.Text_Iter.Gtk_Text_Iter;
      Last : Gtk.Text_Iter.Gtk_Text_Iter;
      Source_First : Gtk.Text_Iter.Gtk_Text_Iter;
      Source_Last : Gtk.Text_Iter.Gtk_Text_Iter;
      Image_First : Gtk.Text_Iter.Gtk_Text_Iter;
      Image_Last : Gtk.Text_Iter.Gtk_Text_Iter;
      Selected : Boolean;
      State : constant Render_State := Render_States.Get
        (View, "coyote-inline-math-state", (others => <>));
      Text : Unbounded_String;
      Clipboard : constant Gtk.Clipboard.Gtk_Clipboard := Gtk.Clipboard.Get;
   begin
      Buffer.Get_Selection_Bounds (First, Last, Selected);
      if not Selected then
         return;
      end if;
      for Index in State.Formulas.First_Index ..
        State.Formulas.Last_Index
      loop
         declare
            Formula : constant Formula_State := State.Formulas (Index);
            Selection_Start : constant Glib.Gint :=
              Gtk.Text_Iter.Get_Offset (First);
            Selection_End : constant Glib.Gint :=
              Gtk.Text_Iter.Get_Offset (Last);
         begin
            if Formula.Source_Start /= null
              and then Formula.Source_End /= null
              and then Formula.Image_Start /= null
              and then Formula.Image_End /= null
              and then not Gtk.Text_Mark.Get_Deleted
                (Formula.Source_Start)
              and then not Gtk.Text_Mark.Get_Deleted
                (Formula.Source_End)
              and then not Gtk.Text_Mark.Get_Deleted
                (Formula.Image_Start)
              and then not Gtk.Text_Mark.Get_Deleted
                (Formula.Image_End)
            then
               Buffer.Get_Iter_At_Mark (Source_First, Formula.Source_Start);
               Buffer.Get_Iter_At_Mark (Source_Last, Formula.Source_End);
               Buffer.Get_Iter_At_Mark (Image_First, Formula.Image_Start);
               Buffer.Get_Iter_At_Mark (Image_Last, Formula.Image_End);
               if (Selection_Start < Gtk.Text_Iter.Get_Offset (Image_Last)
                   and then Selection_End >
                     Gtk.Text_Iter.Get_Offset (Image_First))
                 or else (Selection_Start <
                            Gtk.Text_Iter.Get_Offset (Source_Last)
                          and then Selection_End >
                            Gtk.Text_Iter.Get_Offset (Source_First))
               then
                  if Gtk.Text_Iter.Get_Offset (Source_First) <
                    Gtk.Text_Iter.Get_Offset (First)
                  then
                     First := Source_First;
                  end if;
                  if Gtk.Text_Iter.Get_Offset (Source_Last) >
                    Gtk.Text_Iter.Get_Offset (Last)
                  then
                     Last := Source_Last;
                  end if;
               end if;
            end if;
         end;
      end loop;
      Append
        (Text, Buffer.Get_Text
           (First, Last, Include_Hidden_Chars => True));
      Gtk.Clipboard.Set_Text (Clipboard, To_String (Text));
   end Copy_Selection;

   procedure Set_Formula_Visible
     (Buffer : not null access
        Gtk.Text_Buffer.Gtk_Text_Buffer_Record'Class;
      Formula : Formula_State;
      Visible : Boolean)
   is
      First : Gtk.Text_Iter.Gtk_Text_Iter;
      Last : Gtk.Text_Iter.Gtk_Text_Iter;
   begin
      if Formula.Hidden = null or else Formula.Source_Start = null
        or else Formula.Source_End = null
        or else Gtk.Text_Mark.Get_Deleted (Formula.Source_Start)
        or else Gtk.Text_Mark.Get_Deleted (Formula.Source_End)
      then
         return;
      end if;
      Buffer.Get_Iter_At_Mark (First, Formula.Source_Start);
      Buffer.Get_Iter_At_Mark (Last, Formula.Source_End);
      if Visible then
         Buffer.Remove_Tag (Formula.Hidden, First, Last);
      else
         Buffer.Apply_Tag (Formula.Hidden, First, Last);
      end if;
   end Set_Formula_Visible;

   procedure Remove_Formula_Image
     (Buffer : not null access
        Gtk.Text_Buffer.Gtk_Text_Buffer_Record'Class;
      Formula : Formula_State)
   is
      First : Gtk.Text_Iter.Gtk_Text_Iter;
      Last : Gtk.Text_Iter.Gtk_Text_Iter;
   begin
      if Formula.Image_Start = null or else Formula.Image_End = null
        or else Gtk.Text_Mark.Get_Deleted (Formula.Image_Start)
        or else Gtk.Text_Mark.Get_Deleted (Formula.Image_End)
      then
         return;
      end if;
      Buffer.Get_Iter_At_Mark (First, Formula.Image_Start);
      Buffer.Get_Iter_At_Mark (Last, Formula.Image_End);
      if Gtk.Text_Iter.Get_Pixbuf (First) /= null then
         Buffer.Delete (First, Last);
      end if;
   end Remove_Formula_Image;

   procedure Render_Formula
     (View : not null access
        Gtk.Text_View.Gtk_Text_View_Record'Class;
      Buffer : not null access
        Gtk.Text_Buffer.Gtk_Text_Buffer_Record'Class;
      Formula : in out Formula_State)
   is
      Source_Start : Gtk.Text_Iter.Gtk_Text_Iter;
      Source_End : Gtk.Text_Iter.Gtk_Text_Iter;
      Image_At : Gtk.Text_Iter.Gtk_Text_Iter;
      Image_End : Gtk.Text_Iter.Gtk_Text_Iter;
      Pixbuf : Gdk.Pixbuf.Gdk_Pixbuf := null;
      Baseline : Natural := 0;
      Font_Size : Glib.Gint;
      Em_Pixels : Long_Float;
      Color : Gdk.RGBA.Gdk_RGBA;
   begin
      if Formula.Source_Start = null or else Formula.Source_End = null
        or else Gtk.Text_Mark.Get_Deleted (Formula.Source_Start)
        or else Gtk.Text_Mark.Get_Deleted (Formula.Source_End)
      then
         return;
      end if;
      Buffer.Get_Iter_At_Mark (Source_Start, Formula.Source_Start);
      Buffer.Get_Iter_At_Mark (Source_End, Formula.Source_End);
      if Buffer.Get_Text (Source_Start, Source_End,
                          Include_Hidden_Chars => True)
        /= To_String (Formula.Source)
      then
         Set_Formula_Visible (Buffer, Formula, True);
         return;
      end if;
      Font_Size := Pango.Font.Get_Size
        (Pango.Context.Get_Font_Description (View.Get_Pango_Context));
      Em_Pixels := Long_Float (Font_Size) / 1_024.0 / 0.75;
      Gtk.Style_Context.Get_Style_Context (View).Get_Color
        (Gtk.Enums.Gtk_State_Flag_Normal, Color);
      Pixbuf := Coyote_GUI.Math_Element.Render_Inline
        (To_String (Formula.LaTeX), Baseline, 1.0, Em_Pixels, Color);
      if Pixbuf = null then
         Set_Formula_Visible (Buffer, Formula, True);
         return;
      end if;
      Set_Formula_Visible (Buffer, Formula, False);
      Image_At := Source_End;
      Buffer.Insert_Pixbuf (Image_At, Pixbuf);
      Buffer.Get_Iter_At_Mark (Image_At, Formula.Image_Start);
      Buffer.Get_Iter_At_Offset
        (Image_End, Gtk.Text_Iter.Get_Offset (Image_At) + 1);
      Buffer.Move_Mark (Formula.Image_End, Image_End);
      Glib.Properties.Set_Property
        (Formula.Rise, Gtk.Text_Tag.Rise_Property,
         -(Glib.Gint
           (Gdk.Pixbuf.Get_Height (Pixbuf) - Glib.Gint (Baseline))
           * 1_024));
      Buffer.Apply_Tag (Formula.Rise, Image_At, Image_End);
      Glib.Object.Unref (Glib.Object.GObject (Pixbuf));
   exception
      when others =>
         if Pixbuf /= null then
            Glib.Object.Unref (Glib.Object.GObject (Pixbuf));
         end if;
         Set_Formula_Visible (Buffer, Formula, True);
   end Render_Formula;

   procedure Reflow
     (View : not null access Gtk.Text_View.Gtk_Text_View_Record'Class;
      Math_Scale : Long_Float)
   is
      Buffer : constant Gtk.Text_Buffer.Gtk_Text_Buffer := View.Get_Buffer;
      State : Render_State := Render_States.Get
        (View, "coyote-inline-math-state", (others => <>));
   begin
      for Index in reverse State.Formulas.First_Index ..
        State.Formulas.Last_Index
      loop
         declare
            Formula : Formula_State := State.Formulas (Index);
         begin
            Remove_Formula_Image (Buffer, Formula);
            Set_Formula_Visible (Buffer, Formula, True);
            Render_Formula (View, Buffer, Formula);
            State.Formulas.Replace_Element (Index, Formula);
         end;
      end loop;
      State.Scale := Math_Scale;
      Render_States.Set (View, State, "coyote-inline-math-state");
   end Reflow;

   procedure Insert
     (View             : not null access
        Gtk.Text_View.Gtk_Text_View_Record'Class;
      Result           : Coyote_Renderer.Markup.Render_Result;
      Source_Directory : String;
      Images_Remaining : in out Natural;
      Clear            : Boolean := False;
      Math_Scale       : Long_Float := 1.0)
   is
      Buffer : constant Gtk.Text_Buffer.Gtk_Text_Buffer := View.Get_Buffer;
      State : Render_State := Render_States.Get
        (View, "coyote-inline-math-state", (others => <>));
      Images : Image_Vectors.Vector;
      Base : Natural;
      Count : Natural := 0;
      First_New_Formula : Positive;
   begin
      if Clear then
         for Formula of State.Formulas loop
            Remove_Formula_Image (Buffer, Formula);
            if Formula.Source_Start /= null
              and then not Gtk.Text_Mark.Get_Deleted (Formula.Source_Start)
            then
               Buffer.Delete_Mark (Formula.Source_Start);
            end if;
            if Formula.Source_End /= null
              and then not Gtk.Text_Mark.Get_Deleted (Formula.Source_End)
            then
               Buffer.Delete_Mark (Formula.Source_End);
            end if;
            if Formula.Image_Start /= null
              and then not Gtk.Text_Mark.Get_Deleted (Formula.Image_Start)
            then
               Buffer.Delete_Mark (Formula.Image_Start);
            end if;
            if Formula.Image_End /= null
              and then not Gtk.Text_Mark.Get_Deleted (Formula.Image_End)
            then
               Buffer.Delete_Mark (Formula.Image_End);
            end if;
            if Formula.Hidden /= null then
               Gtk.Text_Tag_Table.Remove
                 (Buffer.Get_Tag_Table, Formula.Hidden);
            end if;
            if Formula.Rise /= null then
               Gtk.Text_Tag_Table.Remove
                 (Buffer.Get_Tag_Table, Formula.Rise);
            end if;
         end loop;
         State.Formulas.Clear;
         Buffer.Set_Text ("");
      end if;
      First_New_Formula :=
        (if State.Formulas.Is_Empty then 1
         else State.Formulas.Last_Index + 1);
      Base := Natural (Buffer.Get_Char_Count);
      Coyote_GUI.Markdown_Links.Insert (Buffer, Result);
      if not Result.Maths.Is_Empty then
         for Index in Result.Maths.First_Index ..
           Result.Maths.Last_Index
         loop
            exit when State.Formulas.Length >= Max_Formulas;
            declare
               Span : constant Math_Span := Result.Maths (Index);
               First : Gtk.Text_Iter.Gtk_Text_Iter;
               Last : Gtk.Text_Iter.Gtk_Text_Iter;
               Formula : Formula_State;
            begin
               if Span.End_Char > Span.Start_Char
                 and then Span.End_Char <= Natural (Buffer.Get_Char_Count)
                   - Base
               then
                  Buffer.Get_Iter_At_Offset
                    (First, Glib.Gint (Base + Span.Start_Char));
                  Buffer.Get_Iter_At_Offset
                    (Last, Glib.Gint (Base + Span.End_Char));
                  Formula.LaTeX := Span.LaTeX;
                  Formula.Source := Span.Source;
                  Formula.Source_Start := Buffer.Create_Mark
                    ("", First, Left_Gravity => True);
                  Formula.Source_End := Buffer.Create_Mark
                    ("", Last, Left_Gravity => True);
                  Formula.Image_Start := Buffer.Create_Mark
                    ("", Last, Left_Gravity => True);
                  Formula.Image_End := Buffer.Create_Mark
                    ("", Last, Left_Gravity => False);
                  Formula.Hidden := Buffer.Create_Tag;
                  Formula.Rise := Buffer.Create_Tag;
                  Glib.Properties.Set_Property
                    (Formula.Hidden, Gtk.Text_Tag.Invisible_Property, True);
                  State.Formulas.Append (Formula);
               end if;
            end;
         end loop;
      end if;
      if Source_Directory'Length > 0 and then not Result.Images.Is_Empty
        and then Images_Remaining > 0
      then
         for Index in Result.Images.First_Index ..
           Result.Images.Last_Index
         loop
            exit when Count >= Natural'Min (Max_Images, Images_Remaining);
            declare
               Info : constant Coyote_Renderer.Markup.Image_Info :=
                 Result.Images (Index);
               Destination : constant String := To_String (Info.Destination);
            begin
               if Is_Local (Destination)
                 and then Info.Start_Char <= Info.End_Char
                 and then Info.Start_Char <=
                   Natural (Buffer.Get_Char_Count) - Base
               then
                  declare
                     Anchor_Iter : Gtk.Text_Iter.Gtk_Text_Iter;
                     Anchor_Mark : Gtk.Text_Mark.Gtk_Text_Mark;
                  begin
                     Buffer.Get_Iter_At_Offset
                       (Anchor_Iter, Glib.Gint (Base + Info.Start_Char));
                     Anchor_Mark := Buffer.Create_Mark
                       ("", Anchor_Iter, Left_Gravity => True);
                     Images.Append ((Info => Info, Anchor => Anchor_Mark));
                     Count := Count + 1;
                  end;
               end if;
            end;
         end loop;
      end if;
      for Item of Images loop
         Add_Image (View, Buffer, Item.Info, Item.Anchor, Source_Directory);
         if Item.Anchor /= null
           and then not Gtk.Text_Mark.Get_Deleted (Item.Anchor)
         then
            Buffer.Delete_Mark (Item.Anchor);
         end if;
      end loop;
      if First_New_Formula <= State.Formulas.Last_Index then
         for Index in reverse First_New_Formula .. State.Formulas.Last_Index
         loop
            declare
               Formula : Formula_State := State.Formulas (Index);
            begin
               Render_Formula (View, Buffer, Formula);
               State.Formulas.Replace_Element (Index, Formula);
            end;
         end loop;
      end if;
      State.Scale := Math_Scale;
      Render_States.Set (View, State, "coyote-inline-math-state");
      if not State.Formulas.Is_Empty
        and then not Copy_Connected.Is_Set (View, "coyote-inline-copy")
      then
         Copy_Connected.Set (View, True, "coyote-inline-copy");
         Gtk.Text_View.On_Copy_Clipboard (View, On_Copy'Access);
      end if;
      Images_Remaining := Images_Remaining - Count;
   end Insert;

end Coyote_GUI.Rich_Text;
