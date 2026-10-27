--  Coyote_GUI.Rich_Text body.
--
--  Image jobs retain their widgets until destruction, while their completion
--  callback runs only on the GTK main context (or synchronously on rejection).

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Containers.Vectors;
with Ada.Real_Time;
with Ada.Unchecked_Deallocation;
with Coyote_GUI.Markdown_Links;
with Coyote_GUI.Math_Element;
with Coyote_Math_Jobs;
with Math_Layout;
with Math_Syntax;
with Coyote_Image_Jobs;
with Gdk.Pixbuf;
with Gdk.RGBA;
with Glib;
with Glib.Object;
with Glib.Properties;
with Glib.Main;
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
   use type Glib.Main.G_Source_Id;
   use type Coyote_Math_Jobs.Request_Id;
   use type Coyote_Math_Jobs.Job_Status;
   use type Coyote_Math_Jobs.Result_Access;
   use type Ada.Real_Time.Time;
   use type Ada.Real_Time.Time_Span;
   use type Gtk.Text_View.Gtk_Text_View;
   use type Glib.Main.G_Source;
   use type Coyote_Math_Jobs.View_Generation;
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
      Parsed_Doc : Math_Syntax.Document;
      Layout_Box : Math_Layout.Box;
      Pending_Job_Id : Coyote_Math_Jobs.Request_Id := 0;
      Generation : Coyote_Math_Jobs.View_Generation := 0;
      Cache_Valid : Boolean := False;
   end record;
   subtype Math_Span is Coyote_Renderer.Markup.Math_Span;

   package Formula_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Formula_State);
   type Render_State is tagged record
      Formulas : Formula_Vectors.Vector;
      Scale : Long_Float := 1.0;
      View : Gtk.Text_View.Gtk_Text_View;
      Poll_Source_Id : Glib.Main.G_Source_Id := 0;
      Alive : Boolean := True;
      Generation : Coyote_Math_Jobs.View_Generation := 1;
      Next_Formula : Positive := 1;
   end record;
   type Render_State_Access is access all Render_State;
   package Render_States is new Glib.Object.User_Data (Render_State_Access);
   procedure Free_State is new Ada.Unchecked_Deallocation
     (Render_State, Render_State_Access);
   package State_Destroy_Callback is new Gtk.Handlers.User_Callback
     (Gtk.Widget.Gtk_Widget_Record, Render_State_Access);
   package State_Poll_Sources is new Glib.Main.Generic_Sources
     (Render_State_Access);
   procedure Set_Formula_Visible
     (Buffer : not null access
        Gtk.Text_Buffer.Gtk_Text_Buffer_Record'Class;
      Formula : Formula_State;
      Visible : Boolean);
   procedure Remove_Formula_Image
     (Buffer : not null access
        Gtk.Text_Buffer.Gtk_Text_Buffer_Record'Class;
      Formula : Formula_State);
   procedure Render_Formula
     (View : not null access
        Gtk.Text_View.Gtk_Text_View_Record'Class;
      Buffer : not null access
        Gtk.Text_Buffer.Gtk_Text_Buffer_Record'Class;
      Formula : in out Formula_State);
   procedure On_State_Destroy
     (Widget : access Gtk.Widget.Gtk_Widget_Record'Class;
      State : Render_State_Access);
   function Poll_Formulas (State : Render_State_Access) return Boolean;
   function Ensure_State
     (View : not null access Gtk.Text_View.Gtk_Text_View_Record'Class)
      return Render_State_Access;

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

   procedure Abandon_Formula (Formula : in out Formula_State) is
   begin
      if Formula.Pending_Job_Id /= 0 then
         Coyote_Math_Jobs.Abandon
           (Formula.Pending_Job_Id, Formula.Generation);
         Formula.Pending_Job_Id := 0;
      end if;
   end Abandon_Formula;

   function Ensure_State
     (View : not null access Gtk.Text_View.Gtk_Text_View_Record'Class)
      return Render_State_Access
   is
      State : Render_State_Access := Render_States.Get
        (View, "coyote-inline-math-state", null);
   begin
      if State = null then
         State := new Render_State;
         State.View := Gtk.Text_View.Gtk_Text_View'(View.all'Unchecked_Access);
         Render_States.Set (View, State, "coyote-inline-math-state");
         State_Destroy_Callback.Connect
           (State.View, Gtk.Widget.Signal_Destroy, On_State_Destroy'Access, State);
      end if;
      return State;
   end Ensure_State;

   procedure On_State_Destroy
     (Widget : access Gtk.Widget.Gtk_Widget_Record'Class;
      State : Render_State_Access)
   is
      Owned_State : Render_State_Access := State;
   begin
      if State = null then
         return;
      end if;
      State.Alive := False;
      if State.Poll_Source_Id /= 0 then
         if Glib.Main.Find_Source_By_Id (State.Poll_Source_Id) /= null then
            Glib.Main.Remove (State.Poll_Source_Id);
         end if;
         State.Poll_Source_Id := 0;
      end if;
      for Formula of State.Formulas loop
         Abandon_Formula (Formula);
      end loop;
      Render_States.Remove
        (Widget, "coyote-inline-math-state");
      State.View := null;
      Free_State (Owned_State);
   exception
      when others =>
         null;
   end On_State_Destroy;

   function Poll_Formulas (State : Render_State_Access) return Boolean is
      Started : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
      Processed : Natural := 0;
      Buffer : Gtk.Text_Buffer.Gtk_Text_Buffer;
      Elapsed : Ada.Real_Time.Time_Span;
      Count : Natural;
      Index : Positive;
      Pending : Boolean := False;
      Item : Coyote_Math_Jobs.Result_Access := null;
   begin
      if State = null or else not State.Alive or else State.View = null then
         return False;
      end if;
      Buffer := State.View.Get_Buffer;
      Count := Natural (State.Formulas.Length);
      if Count = 0 then
         State.Poll_Source_Id := 0;
         return False;
      end if;
      loop
         Elapsed := Ada.Real_Time.Clock - Started;
         exit when Processed >= 8
           or else Elapsed >= Ada.Real_Time.Milliseconds (5);
         if State.Next_Formula > Count then
            State.Next_Formula := 1;
         end if;
         Index := State.Next_Formula;
         State.Next_Formula := (if Index = Count then 1 else Index + 1);
         Processed := Processed + 1;
         declare
            Formula : Formula_State := State.Formulas (Index);
         begin
            if Formula.Pending_Job_Id /= 0 then
               Pending := True;
               declare
                  Status : Coyote_Math_Jobs.Job_Status;
                  Current : constant Coyote_Math_Jobs.Request_Id :=
                    Formula.Pending_Job_Id;
                  First, Last : Gtk.Text_Iter.Gtk_Text_Iter;
                  Current_Source : Unbounded_String;
               begin
                  Item := null;
                  Coyote_Math_Jobs.Poll
                    (Current, Formula.Generation, Status, Item);
                  if Status /= Coyote_Math_Jobs.Pending then
                     Formula.Pending_Job_Id := 0;
                     if Item /= null then
                        Current_Source := To_Unbounded_String
                          (Coyote_Math_Jobs.Source (Item.all));
                        if Status = Coyote_Math_Jobs.Valid
                          and then Coyote_Math_Jobs.Id (Item.all) = Current
                          and then Coyote_Math_Jobs.Generation (Item.all) =
                            Formula.Generation
                          and then To_String (Current_Source) =
                            To_String (Formula.LaTeX)
                          and then Formula.Source_Start /= null
                          and then Formula.Source_End /= null
                          and then not Gtk.Text_Mark.Get_Deleted
                            (Formula.Source_Start)
                          and then not Gtk.Text_Mark.Get_Deleted
                            (Formula.Source_End)
                        then
                           Buffer.Get_Iter_At_Mark
                             (First, Formula.Source_Start);
                           Buffer.Get_Iter_At_Mark (Last, Formula.Source_End);
                           if Buffer.Get_Text (First, Last, True) =
                             To_String (Formula.Source)
                           then
                              Formula.Parsed_Doc :=
                                Coyote_Math_Jobs.Parse_Document (Item.all);
                              Formula.Layout_Box :=
                                Coyote_Math_Jobs.Layout (Item.all);
                              Formula.Cache_Valid := True;
                           end if;
                        end if;
                        Coyote_Math_Jobs.Release (Item);
                     end if;
                     if Formula.Cache_Valid then
                        Remove_Formula_Image (Buffer, Formula);
                        Set_Formula_Visible (Buffer, Formula, True);
                        Render_Formula (State.View, Buffer, Formula);
                     end if;
                     State.Formulas.Replace_Element (Index, Formula);
                  end if;
               end;
            end if;
         end;
      end loop;
      Pending := (for some Formula of State.Formulas =>
        Formula.Pending_Job_Id /= 0);
      if not Pending then
         State.Poll_Source_Id := 0;
         return False;
      end if;
      return State.Alive;
   exception
      when others =>
         if Item /= null then
            Coyote_Math_Jobs.Release (Item);
         end if;
         if State /= null then
            State.Poll_Source_Id := 0;
            if State.Alive and then State.View /= null then
               Buffer := State.View.Get_Buffer;
            end if;
            for Index in State.Formulas.First_Index ..
              State.Formulas.Last_Index
            loop
               declare
                  Formula : Formula_State := State.Formulas (Index);
               begin
                  Abandon_Formula (Formula);
                  if State.Alive and then State.View /= null then
                     Set_Formula_Visible (Buffer, Formula, True);
                  end if;
                  State.Formulas.Replace_Element (Index, Formula);
               end;
            end loop;
         end if;
         return False;
   end Poll_Formulas;

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
      State : constant Render_State_Access := Ensure_State (View);
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
      if not Formula.Cache_Valid then
         Set_Formula_Visible (Buffer, Formula, True);
         return;
      end if;
      Pixbuf := Coyote_GUI.Math_Element.Render_Layout_Inline
        (Formula.Parsed_Doc, Formula.Layout_Box, Baseline, 1.0,
         Em_Pixels, Color);
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
      State : constant Render_State_Access := Ensure_State (View);
   begin
      for Index in reverse State.Formulas.First_Index ..
        State.Formulas.Last_Index
      loop
         declare
            Formula : Formula_State := State.Formulas (Index);
         begin
            Remove_Formula_Image (Buffer, Formula);
            Set_Formula_Visible (Buffer, Formula, True);
            if Formula.Cache_Valid then
               Render_Formula (View, Buffer, Formula);
            end if;
            State.Formulas.Replace_Element (Index, Formula);
         end;
      end loop;
      State.Scale := Math_Scale;
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
      State : constant Render_State_Access := Ensure_State (View);
      Images : Image_Vectors.Vector;
      Base : Natural;
      Count : Natural := 0;
      First_New_Formula : Positive;
   begin
      if Clear then
         State.Generation := Coyote_Math_Jobs.View_Generation
           (Natural (State.Generation) + 1);
         for Formula of State.Formulas loop
            Abandon_Formula (Formula);
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
                  Formula.Generation := State.Generation;
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
         for Index in First_New_Formula .. State.Formulas.Last_Index loop
            declare
               Formula : Formula_State := State.Formulas (Index);
               Status : Coyote_Math_Jobs.Job_Status;
            begin
               Coyote_Math_Jobs.Start;
               Coyote_Math_Jobs.Submit
                 (To_String (Formula.LaTeX), Formula.Pending_Job_Id,
                  Formula.Generation, Math_Layout.Text_Style,
                  Status => Status);
               if Status /= Coyote_Math_Jobs.Pending then
                  Formula.Pending_Job_Id := 0;
               end if;
               State.Formulas.Replace_Element (Index, Formula);
            end;
         end loop;
      end if;
      State.Scale := Math_Scale;
      if not State.Formulas.Is_Empty
        and then not Copy_Connected.Is_Set (View, "coyote-inline-copy")
      then
         Copy_Connected.Set (View, True, "coyote-inline-copy");
         Gtk.Text_View.On_Copy_Clipboard (View, On_Copy'Access);
      end if;
      if State.Poll_Source_Id = 0
        and then (for some Formula of State.Formulas =>
          Formula.Pending_Job_Id /= 0)
      then
         State.Poll_Source_Id := State_Poll_Sources.Timeout_Add
           (10, Poll_Formulas'Access, State);
      end if;
      Images_Remaining := Images_Remaining - Count;
   end Insert;

end Coyote_GUI.Rich_Text;
