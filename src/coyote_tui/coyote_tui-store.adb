--  Coyote_TUI.Store body.
with Ada.Strings.Unbounded;
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Coyote_TUI.Segment_Ops;

package body Coyote_TUI.Store is

   protected body Conversation is

      procedure Append_Assistant_Text (Text : String) is
         use Coyote_TUI.Segments;
         use Ada.Strings.Unbounded;
      begin
         if not Vec.Is_Empty
           and then Vec.Last_Element.Kind = Assistant_Text
           and then not Vec.Last_Element.Complete
         then
            Coyote_TUI.Segment_Ops.Update_Last_Content (Vec, Text);
         else
            declare
               S : constant Segment :=
                 (Kind     => Assistant_Text,
                  Complete => False,
                  Content  => To_Unbounded_String (Text),
                  others   => <>);
            begin
               Coyote_TUI.Segment_Ops.Append_New (Vec, S);
            end;
         end if;
      end Append_Assistant_Text;

      procedure Append_Thinking_Text (Text : String) is
         use Coyote_TUI.Segments;
         use Ada.Strings.Unbounded;
      begin
         if not Vec.Is_Empty
           and then Vec.Last_Element.Kind = Thinking_Block
         then
            Coyote_TUI.Segment_Ops.Update_Last_Content (Vec, Text);
         else
            declare
               S : constant Segment :=
                 (Kind     => Thinking_Block,
                  Content  => To_Unbounded_String (Text),
                  others   => <>);
            begin
               Coyote_TUI.Segment_Ops.Append_New (Vec, S);
            end;
         end if;
      end Append_Thinking_Text;

      procedure Append_New (S : Coyote_TUI.Segments.Segment) is
      begin
         Coyote_TUI.Segment_Ops.Append_New (Vec, S);
      end Append_New;

      procedure Update_Last_Content (Text : String) is
      begin
         Coyote_TUI.Segment_Ops.Update_Last_Content (Vec, Text);
      end Update_Last_Content;

      procedure Set_Last_Complete is
      begin
         Coyote_TUI.Segment_Ops.Set_Last_Complete (Vec);
      end Set_Last_Complete;

      procedure End_Tool
        (Tool_Id : String;
         Result  : String;
         Stat    : Coyote_TUI.Segments.Tool_Run_Status)
      is
      begin
         Coyote_TUI.Segment_Ops.End_Tool (Vec, Tool_Id, Result, Stat);
      end End_Tool;

      function Snapshot return Coyote_TUI.Segments.Vector is
      begin
         return Vec;
      end Snapshot;

      function Count return Natural is
      begin
         return Natural (Vec.Length);
      end Count;

      procedure Clear is
      begin
         Vec.Clear;
      end Clear;

   end Conversation;

end Coyote_TUI.Store;
