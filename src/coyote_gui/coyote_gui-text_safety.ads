--  Coyote_GUI.Text_Safety — conversation text-buffer boundary policy.
--  Project: coyote

with Ada.Strings.Unbounded;
with Coyote_App.Utils;
with Gtk.Text_Buffer;
with Gtk.Text_View;

package Coyote_GUI.Text_Safety is

   --  The first Configure binds the boundary to its calling Ada task, which
   --  must be the GTK main task. Later Configure/Set_Text/Append calls from
   --  another task raise Program_Error before invoking GTK. This guards this
   --  boundary, not every GTK operation in the application. Apply before
   --  inserting hidden-source or embedded-image text.
   procedure Configure
     (View : not null access Gtk.Text_View.Gtk_Text_View_Record'Class);

   --  Replace invalid UTF-8 and embedded NUL with U+FFFD. Unlike arbitrary
   --  byte streams, GTK strings must not contain NUL (which truncates them).
   --  This policy affects presentation only, never persisted source data.
   function Clean (Text : String) return String;

   procedure Set_Text
     (Buffer : not null access Gtk.Text_Buffer.Gtk_Text_Buffer_Record'Class;
      Text : String);

   --  Acquire a fresh end iterator for each mutation. No iterator escapes.
   procedure Append
     (Buffer : not null access Gtk.Text_Buffer.Gtk_Text_Buffer_Record'Class;
      Text : String);

   type Stream is limited private;
   procedure Reset (Decoder : in out Stream);
   procedure Feed
     (Decoder : in out Stream;
      Data : String;
      Output : out Ada.Strings.Unbounded.Unbounded_String);
   --  Emit only complete, NUL-free UTF-8; retain an incomplete trailing
   --  sequence for the next Feed. Invalid bytes become U+FFFD.
   procedure Flush
     (Decoder : in out Stream;
      Output : out Ada.Strings.Unbounded.Unbounded_String);
   --  Replace any incomplete final sequence with U+FFFD and reset.

private
   type Stream is limited record
      Decoder : Coyote_App.Utils.UTF8_Stream.Instance;
   end record;
end Coyote_GUI.Text_Safety;
