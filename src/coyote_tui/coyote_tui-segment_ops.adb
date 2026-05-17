--  Coyote_TUI.Segment_Ops body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package body Coyote_TUI.Segment_Ops is

   use Coyote_TUI.Segments;

   --  ── Append_New ───────────────────────────────────────────────────────

   procedure Append_New
     (Vec : in out Vector;
      S   :        Segment)
   is
   begin
      Vec.Append (S);
   end Append_New;

   --  ── Update_Last_Content ──────────────────────────────────────────────

   procedure Update_Last_Content
     (Vec  : in out Vector;
      Text :        String)
   is
   begin
      if Vec.Is_Empty then
         return;
      end if;
      declare
         S : Segment := Vec.Last_Element;
      begin
         Append (S.Content, Text);
         Vec.Replace_Element (Vec.Last_Index, S);
      end;
   end Update_Last_Content;

   --  ── Set_Last_Complete ────────────────────────────────────────────────

   procedure Set_Last_Complete (Vec : in out Vector) is
   begin
      if Vec.Is_Empty then
         return;
      end if;
      declare
         S : Segment := Vec.Last_Element;
      begin
         S.Complete := True;
         Vec.Replace_Element (Vec.Last_Index, S);
      end;
   end Set_Last_Complete;

   --  ── Find_Tool ────────────────────────────────────────────────────────

   function Find_Tool
     (Vec     : Vector;
      Tool_Id : String) return Natural
   is
   begin
      for I in reverse Vec.First_Index .. Vec.Last_Index loop
         if Vec (I).Kind = Tool_Segment
           and then To_String (Vec (I).Tool_Id) = Tool_Id
         then
            return I;
         end if;
      end loop;
      return 0;
   end Find_Tool;

   --  ── End_Tool ─────────────────────────────────────────────────────────

   procedure End_Tool
     (Vec     : in out Vector;
      Tool_Id :        String;
      Result  :        String;
      Stat    :        Tool_Run_Status)
   is
      Idx : constant Natural := Find_Tool (Vec, Tool_Id);
   begin
      if Idx = 0 then
         return;
      end if;
      declare
         S : Segment := Vec (Idx);
      begin
         S.T_Status := Stat;
         S.Content  := To_Unbounded_String (Result);
         Vec.Replace_Element (Idx, S);
      end;
   end End_Tool;

   --  ── Last_Kind ────────────────────────────────────────────────────────

   function Last_Kind (Vec : Vector) return Segment_Kind is
   begin
      if Vec.Is_Empty then
         return System_Notice;
      end if;
      return Vec.Last_Element.Kind;
   end Last_Kind;

end Coyote_TUI.Segment_Ops;
