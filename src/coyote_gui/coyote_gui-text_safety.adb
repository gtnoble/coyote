--  Coyote_GUI.Text_Safety body.
--  Project: coyote

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Task_Identification;
with Gtk.Enums;
with Gtk.Text_Iter;

package body Coyote_GUI.Text_Safety is

   use type Ada.Task_Identification.Task_Id;

   protected Owner is
      procedure Bind (Caller : Ada.Task_Identification.Task_Id);
      function Is_Owner (Caller : Ada.Task_Identification.Task_Id)
         return Boolean;
   private
      Task_Id : Ada.Task_Identification.Task_Id :=
        Ada.Task_Identification.Null_Task_Id;
   end Owner;

   protected body Owner is
      procedure Bind (Caller : Ada.Task_Identification.Task_Id) is
      begin
         if Task_Id = Ada.Task_Identification.Null_Task_Id then
            Task_Id := Caller;
         elsif Task_Id /= Caller then
            raise Program_Error with "conversation GTK task mismatch";
         end if;
      end Bind;

      function Is_Owner (Caller : Ada.Task_Identification.Task_Id)
         return Boolean
      is
      begin
         return Task_Id = Caller;
      end Is_Owner;
   end Owner;

   procedure Require_Owner is
   begin
      if not Owner.Is_Owner (Ada.Task_Identification.Current_Task) then
         raise Program_Error with "conversation GTK mutation off owner task";
      end if;
   end Require_Owner;

   Replacement : constant String :=
     Character'Val (16#EF#) & Character'Val (16#BF#)
     & Character'Val (16#BD#);

   procedure Configure
     (View : not null access Gtk.Text_View.Gtk_Text_View_Record'Class)
   is
   begin
      Owner.Bind (Ada.Task_Identification.Current_Task);
      View.Set_Editable (False);
      View.Set_Cursor_Visible (False);
      View.Set_Wrap_Mode (Gtk.Enums.Wrap_Word_Char);
      View.Set_Accepts_Tab (False);
      View.Set_Left_Margin (8);
      View.Set_Right_Margin (8);
      View.Set_Pixels_Above_Lines (2);
      --  GTK 3.24 below-line hit testing mixes raw and visible byte counts
      --  with hidden math source (PCR-127). Keep spacing above instead.
      View.Set_Pixels_Below_Lines (0);
   end Configure;

   function Without_NUL (Text : String) return String is
      Result : Unbounded_String;
   begin
      for C of Text loop
         if C = ASCII.NUL then
            Ada.Strings.Unbounded.Append (Result, Replacement);
         else
            Ada.Strings.Unbounded.Append (Result, C);
         end if;
      end loop;
      return To_String (Result);
   end Without_NUL;

   function Clean (Text : String) return String is
   begin
      return Without_NUL (Coyote_App.Utils.Sanitize_UTF8 (Text));
   end Clean;

   procedure Set_Text
     (Buffer : not null access Gtk.Text_Buffer.Gtk_Text_Buffer_Record'Class;
      Text : String)
   is
   begin
      Require_Owner;
      Buffer.Set_Text (Clean (Text));
   end Set_Text;

   procedure Append
     (Buffer : not null access Gtk.Text_Buffer.Gtk_Text_Buffer_Record'Class;
      Text : String)
   is
      Value : constant String := Clean (Text);
      Iter : Gtk.Text_Iter.Gtk_Text_Iter;
   begin
      Require_Owner;
      if Value'Length > 0 then
         Buffer.Get_End_Iter (Iter);
         Buffer.Insert (Iter, Value);
      end if;
   end Append;

   procedure Reset (Decoder : in out Stream) is
   begin
      Coyote_App.Utils.UTF8_Stream.Reset (Decoder.Decoder);
   end Reset;

   procedure Feed
     (Decoder : in out Stream;
      Data : String;
      Output : out Unbounded_String)
   is
      Decoded : Unbounded_String;
   begin
      Coyote_App.Utils.UTF8_Stream.Feed (Decoder.Decoder, Data, Decoded);
      Output := To_Unbounded_String (Without_NUL (To_String (Decoded)));
   end Feed;

   procedure Flush
     (Decoder : in out Stream;
      Output : out Unbounded_String)
   is
   begin
      Coyote_App.Utils.UTF8_Stream.Flush (Decoder.Decoder, Output);
   end Flush;

end Coyote_GUI.Text_Safety;
