--  Coyote_GUI.Streaming_Response.Testing body.
--
--  Project: coyote

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Coyote_GUI.Semantic_Response_Presenter;
with Gtk.Box;
with Gtk.Text_Iter;

package body Coyote_GUI.Streaming_Response.Testing is

   use type Gtk.Box.Gtk_Box;

   function Live_Owner_Count return Natural is
   begin
      return Coyote_GUI.Streaming_Response.Live_Owner_Count;
   end Live_Owner_Count;

   function Is_Open (R : Handle) return Boolean is
   begin
      return R.Node.Value.Open;
   end Is_Open;

   function Is_Finished (R : Handle) return Boolean is
   begin
      return R.Node.Value.Finished;
   end Is_Finished;

   function Selection_View (R : Handle) return Gtk.Text_View.Gtk_Text_View is
   begin
      return R.Node.Value.Active_View_Handle;
   end Selection_View;

   function Source (R : Handle) return String is
   begin
      return To_String (R.Node.Value.Source_Text);
   end Source;

   function Presented_Response_Present (R : Handle) return Boolean is
   begin
      return R.Node.Value.Open
        and then R.Node.Value.Presenter.Root /= null;
   end Presented_Response_Present;

   function Presented_Text (R : Handle) return String is
   begin
      if Coyote_GUI.Semantic_Response_Presenter.Text_View_Count
        (R.Node.Value.Presenter) = 0
      then
         return "";
      end if;
      declare
         Result : Unbounded_String;
      begin
         for Index in 1 ..
           Coyote_GUI.Semantic_Response_Presenter.Text_View_Count
             (R.Node.Value.Presenter)
         loop
            declare
               View : constant Gtk.Text_View.Gtk_Text_View :=
                 Coyote_GUI.Semantic_Response_Presenter.Text_View_At
                   (R.Node.Value.Presenter, Index);
               Buffer : constant Gtk.Text_Buffer.Gtk_Text_Buffer :=
                 View.Get_Buffer;
               Start_Iter : Gtk.Text_Iter.Gtk_Text_Iter;
               End_Iter : Gtk.Text_Iter.Gtk_Text_Iter;
            begin
               Buffer.Get_Start_Iter (Start_Iter);
               Buffer.Get_End_Iter (End_Iter);
               Append (Result, Buffer.Get_Text (Start_Iter, End_Iter));
            end;
         end loop;
         return To_String (Result);
      end;
   end Presented_Text;

   function Presented_Invalid_Event_Count (R : Handle) return Natural is
   begin
      return Coyote_GUI.Semantic_Response_Presenter.Invalid_Event_Count
        (R.Node.Value.Presenter);
   end Presented_Invalid_Event_Count;


   function Text_View_Count (R : Handle) return Natural is
   begin
      return Coyote_GUI.Semantic_Response_Presenter.Text_View_Count
        (R.Node.Value.Presenter);
   end Text_View_Count;

   function Text_View_At
     (R : Handle; Index : Positive) return Gtk.Text_View.Gtk_Text_View
   is
   begin
      return Coyote_GUI.Semantic_Response_Presenter.Text_View_At
        (R.Node.Value.Presenter, Index);
   end Text_View_At;

   function Table_Count (R : Handle) return Natural is
   begin
      return Coyote_GUI.Semantic_Response_Presenter.Table_Count
        (R.Node.Value.Presenter);
   end Table_Count;

   function Table_Grid_At
     (R : Handle; Index : Positive) return Gtk.Grid.Gtk_Grid
   is
   begin
      return Coyote_GUI.Semantic_Response_Presenter.Table_Grid_At
        (R.Node.Value.Presenter, Index);
   end Table_Grid_At;

   function Math_Element_Count (R : Handle) return Natural is
   begin
      return Coyote_GUI.Semantic_Response_Presenter.Math_Element_Count
        (R.Node.Value.Presenter);
   end Math_Element_Count;

   function Math_Element_At
     (R : Handle; Index : Positive)
      return Coyote_GUI.Math_Element.Instance_Access
   is
   begin
      return Coyote_GUI.Semantic_Response_Presenter.Math_Element_At
        (R.Node.Value.Presenter, Index);
   end Math_Element_At;

end Coyote_GUI.Streaming_Response.Testing;
