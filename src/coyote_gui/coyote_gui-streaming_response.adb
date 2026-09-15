--  Coyote_GUI.Streaming_Response body.
--
--  Project: coyote

with Ada.Finalization;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Unchecked_Deallocation;
with Coyote_GUI.Semantic_Response_Presenter;
with Coyote_Renderer.Incremental;
with Gtk.Box;
with Gtk.Label;
with Gtk.Text_Buffer;
with Gtk.Text_View;
with Gtk.Widget;
with Pango.Font;

package body Coyote_GUI.Streaming_Response is

   use type Gtk.Box.Gtk_Box;
   use type Gtk.Text_Buffer.Gtk_Text_Buffer;
   use type Gtk.Text_View.Gtk_Text_View;
   use type Gtk.Widget.Gtk_Widget;

   Live_Nodes : Natural := 0;

   procedure Clear_Transaction (R : in out Instance) is
   begin
      Coyote_GUI.Semantic_Response_Presenter.Clear (R.Presenter);
      if R.Response_Section /= null
        and then R.Parent /= null
        and then R.Response_Section.Get_Parent =
          Gtk.Widget.Gtk_Widget (R.Parent)
      then
         R.Parent.Remove (R.Response_Section);
      end if;
      Coyote_Renderer.Incremental.Reset (R.Parser);
      Coyote_Renderer.Semantics.Clear (R.Document);
      R.Parent             := null;
      R.Response_Section   := null;
      R.Active_Text        := null;
      R.Active_View_Handle := null;
      R.Source_Text        := Null_Unbounded_String;
      R.Open               := False;
      R.Finished           := False;
   end Clear_Transaction;

   procedure Release_Node (N : in out Node_Access) is
      procedure Free is new Ada.Unchecked_Deallocation
        (Node, Node_Access);
   begin
      if N = null then
         return;
      end if;
      if N.Count = 0 then
         N := null;
         return;
      end if;
      N.Count := N.Count - 1;
      if N.Count = 0 then
         Clear_Transaction (N.Value);
         Free (N);
         if Live_Nodes > 0 then
            Live_Nodes := Live_Nodes - 1;
         end if;
      end if;
      N := null;
   exception
      when others =>
         N := null;
   end Release_Node;

   function New_Handle return Handle is
      N : Node_Access;
   begin
      if Live_Nodes = Natural'Last then
         raise Storage_Error;
      end if;
      N := new Node;
      Live_Nodes := Live_Nodes + 1;
      return (Ada.Finalization.Controlled with Node => N);
   end New_Handle;

   procedure Adjust (R : in out Handle) is
   begin
      if R.Node /= null then
         if R.Node.Count = Natural'Last then
            raise Storage_Error;
         end if;
         R.Node.Count := R.Node.Count + 1;
      end if;
   end Adjust;

   procedure Finalize (R : in out Handle) is
   begin
      Release_Node (R.Node);
   end Finalize;

   procedure Reset (R : in out Handle) is
   begin
      Release_Node (R.Node);
   end Reset;

   function Is_Empty (R : Handle) return Boolean is
   begin
      return R.Node = null;
   end Is_Empty;

   function "=" (Left, Right : Handle) return Boolean is
   begin
      return Left.Node = Right.Node;
   end "=";

   function Live_Owner_Count return Natural is
   begin
      return Live_Nodes;
   end Live_Owner_Count;

   procedure Begin_Response
     (R      : in out Handle;
      Parent : not null access Gtk.Box.Gtk_Box_Record'Class)
   is
      Value : access Instance;
   begin
      if R.Node = null then
         return;
      end if;
      Value := R.Node.Value'Access;
      Clear_Transaction (Value.all);
      Value.Parent := Gtk.Box.Gtk_Box (Parent);
      Gtk.Box.Gtk_New_Vbox
        (Value.Response_Section, Homogeneous => False, Spacing => 0);
      declare
         Caption : Gtk.Label.Gtk_Label;
      begin
         Gtk.Label.Gtk_New (Caption, "Response");
         Caption.Set_Xalign (0.0);
         Caption.Set_Selectable (True);
         Value.Response_Section.Pack_Start
           (Caption, Expand => False, Fill => False, Padding => 2);
      end;
      Coyote_GUI.Semantic_Response_Presenter.Create
        (Value.Presenter, Value.Response_Section.all'Access);
      Parent.Pack_Start
        (Value.Response_Section, Expand => False, Fill => True, Padding => 4);
      if Length (Value.Font_Name) > 0 then
         declare
            Description : Pango.Font.Pango_Font_Description :=
              Pango.Font.From_String (To_String (Value.Font_Name));
         begin
            Coyote_GUI.Semantic_Response_Presenter.Set_Font
              (Value.Presenter, Description, Value.Math_Scale);
            Pango.Font.Free (Description);
         end;
      end if;
      Value.Active_Text :=
        Coyote_GUI.Semantic_Response_Presenter.Active_Buffer
          (Value.Presenter);
      Value.Active_View_Handle :=
        Coyote_GUI.Semantic_Response_Presenter.Active_View (Value.Presenter);
      Value.Open := True;
   end Begin_Response;

   procedure Reconcile (R : in out Instance) is
   begin
      Coyote_Renderer.Incremental.Snapshot (R.Parser, R.Document);
      Coyote_GUI.Semantic_Response_Presenter.Reconcile
        (R.Presenter, R.Document, Normalize_Terminal_Math => True);
      R.Active_Text :=
        Coyote_GUI.Semantic_Response_Presenter.Active_Buffer (R.Presenter);
      R.Active_View_Handle :=
        Coyote_GUI.Semantic_Response_Presenter.Active_View (R.Presenter);
   end Reconcile;

   procedure Append (R : in out Handle; Text : String) is
      Value : access Instance;
      procedure Handle_Event
        (Event : Coyote_Renderer.Incremental.Semantic_Event) is
      begin
         Coyote_GUI.Semantic_Response_Presenter.Mark_Dirty
           (Value.Presenter, Event.Root_Id);
         if Event.Kind in
           Coyote_Renderer.Incremental.Semantic_Root_Replace_Invalid_Event
           | Coyote_Renderer.Incremental.Semantic_Localized_Recovery_Event
         then
            Coyote_GUI.Semantic_Response_Presenter.Record_Invalid
              (Value.Presenter);
         end if;
         if Event.Root_Id /= 0
           and then Event.Kind in
             Coyote_Renderer.Incremental.Semantic_Root_Commit_Event
             | Coyote_Renderer.Incremental.Semantic_Root_Replace_Invalid_Event
         then
            Coyote_GUI.Semantic_Response_Presenter.Commit_Root
              (Value.Presenter, Event.Root_Id);
         end if;
      end Handle_Event;
   begin
      if R.Node = null then
         return;
      end if;
      Value := R.Node.Value'Access;
      if not Value.Open or else Value.Finished then
         return;
      end if;
      Append (Value.Source_Text, Text);
      Coyote_Renderer.Incremental.Feed
        (Parser => Value.Parser, Data => Text,
         Handler => Handle_Event'Unrestricted_Access);
      Reconcile (Value.all);
   end Append;

   procedure Finish (R : in out Handle) is
      Value : access Instance;
      procedure Handle_Event
        (Event : Coyote_Renderer.Incremental.Semantic_Event) is
      begin
         Coyote_GUI.Semantic_Response_Presenter.Mark_Dirty
           (Value.Presenter, Event.Root_Id);
         if Event.Kind in
           Coyote_Renderer.Incremental.Semantic_Root_Replace_Invalid_Event
           | Coyote_Renderer.Incremental.Semantic_Localized_Recovery_Event
         then
            Coyote_GUI.Semantic_Response_Presenter.Record_Invalid
              (Value.Presenter);
         end if;
         if Event.Root_Id /= 0
           and then Event.Kind in
             Coyote_Renderer.Incremental.Semantic_Root_Commit_Event
             | Coyote_Renderer.Incremental.Semantic_Root_Replace_Invalid_Event
         then
            Coyote_GUI.Semantic_Response_Presenter.Commit_Root
              (Value.Presenter, Event.Root_Id);
         end if;
      end Handle_Event;
   begin
      if R.Node = null then
         return;
      end if;
      Value := R.Node.Value'Access;
      if not Value.Open or else Value.Finished then
         return;
      end if;
      Coyote_Renderer.Incremental.Flush
        (Parser => Value.Parser, Handler => Handle_Event'Unrestricted_Access);
      Reconcile (Value.all);
      Value.Open := False;
      Value.Finished := True;
   end Finish;

   procedure Discard (R : in out Handle) is
   begin
      if R.Node /= null then
         Clear_Transaction (R.Node.Value);
      end if;
   end Discard;

   procedure Set_Font
     (R          : in out Handle;
      Desc       :        Pango.Font.Pango_Font_Description;
      Math_Scale :        Long_Float := 1.0)
   is
   begin
      if R.Node = null then
         return;
      end if;
      R.Node.Value.Font_Name :=
        To_Unbounded_String (Pango.Font.To_String (Desc));
      R.Node.Value.Math_Scale := Long_Float'Max (Math_Scale, 0.01);
      Coyote_GUI.Semantic_Response_Presenter.Set_Font
        (R.Node.Value.Presenter, Desc, R.Node.Value.Math_Scale);
   end Set_Font;

   function Section (R : Handle) return Gtk.Box.Gtk_Box is
   begin
      return (if R.Node = null then null else R.Node.Value.Response_Section);
   end Section;

   function Active_Buffer (R : Handle) return Gtk.Text_Buffer.Gtk_Text_Buffer is
   begin
      return (if R.Node = null then null else R.Node.Value.Active_Text);
   end Active_Buffer;

   function Active_View (R : Handle) return Gtk.Text_View.Gtk_Text_View is
   begin
      return
        (if R.Node = null then null else R.Node.Value.Active_View_Handle);
   end Active_View;

   function Response_Box (R : Handle) return Gtk.Box.Gtk_Box is
   begin
      return
        (if R.Node = null
         then null
         else Coyote_GUI.Semantic_Response_Presenter.Root
           (R.Node.Value.Presenter));
   end Response_Box;

end Coyote_GUI.Streaming_Response;
