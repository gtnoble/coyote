--  Coyote_GUI.Streaming_Response — one response-scoped CSM transaction.
--
--  The instance owns the parser, semantic snapshot, live subtree, and final
--  response renderer for one response.  All operations run on the GTK main
--  task.
--
--  Project: coyote

with Ada.Finalization;
with Ada.Strings.Unbounded;
with Coyote_GUI.Semantic_Response_Presenter;
with Coyote_Renderer.Incremental;
with Coyote_Renderer.Semantics;
with Gtk.Box;
with Gtk.Text_Buffer;
with Gtk.Text_View;
with Pango.Font;

package Coyote_GUI.Streaming_Response is

   type Handle is tagged private;

   function "=" (Left, Right : Handle) return Boolean;

   --  Return one controlled owner.  Copies share the response node and each
   --  copy contributes one reference until Reset or finalization.
   function New_Handle return Handle;

   --  Reset releases this handle.  If it is the last handle, GTK transaction
   --  cleanup runs before the response node is reclaimed.
   procedure Reset (R : in out Handle);
   function Is_Empty (R : Handle) return Boolean;

   --  Empty handles are accepted as no-ops by all response operations.
   procedure Begin_Response
     (R      : in out Handle;
      Parent : not null access Gtk.Box.Gtk_Box_Record'Class);

   procedure Append (R : in out Handle; Text : String);
   procedure Finish (R : in out Handle);
   procedure Discard (R : in out Handle);

   procedure Set_Font
     (R          : in out Handle;
      Desc       :        Pango.Font.Pango_Font_Description;
      Math_Scale :        Long_Float := 1.0);

   function Section (R : Handle) return Gtk.Box.Gtk_Box;
   function Active_Buffer (R : Handle) return Gtk.Text_Buffer.Gtk_Text_Buffer;
   function Active_View (R : Handle) return Gtk.Text_View.Gtk_Text_View;
   function Response_Box (R : Handle) return Gtk.Box.Gtk_Box;
private

   --  Visible only to the private test child; no response node escapes.
   --  The result is the number of allocated response nodes, not handles.
   function Live_Owner_Count return Natural;

   type Instance is tagged limited record
      Parent             : Gtk.Box.Gtk_Box;
      Response_Section   : Gtk.Box.Gtk_Box;
      Active_Text        : Gtk.Text_Buffer.Gtk_Text_Buffer;
      Active_View_Handle : Gtk.Text_View.Gtk_Text_View;
      Source_Text        : Ada.Strings.Unbounded.Unbounded_String;
      Font_Name          : Ada.Strings.Unbounded.Unbounded_String;
      Parser             : Coyote_Renderer.Incremental.Instance;
      Document           : Coyote_Renderer.Semantics.Document;
      Presenter          : Coyote_GUI.Semantic_Response_Presenter.Instance;
      Math_Scale         : Long_Float := 1.0;
      Open               : Boolean := False;
      Finished           : Boolean := False;
   end record;

   type Node is record
      Value : aliased Instance;
      Count : Natural := 1;
   end record;
   type Node_Access is access all Node;

   type Handle is new Ada.Finalization.Controlled with record
      Node : Node_Access;
   end record;

   overriding procedure Adjust (R : in out Handle);
   overriding procedure Finalize (R : in out Handle);

end Coyote_GUI.Streaming_Response;
