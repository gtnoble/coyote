--  Coyote_GUI.Zoom — zoom-level arithmetic for the GUI frontend.
--
--  Encapsulates the mapping between a zoom level (positive = zoomed in,
--  negative = zoomed out, 0 = baseline) and an effective font point size,
--  so the policy is shared between the menu accelerators and the
--  Ctrl+mouse-wheel handler, and can be unit-tested without a display.
--
--  Project: coyote

package Coyote_GUI.Zoom is

   --  Point-size increment applied per zoom step.
   Zoom_Step_Pt : constant := 1;

   --  Hard bounds for the effective font size.  Zoom levels that would
   --  take the size outside this range are clamped instead.
   Min_Size_Pt : constant := 6;
   Max_Size_Pt : constant := 32;

   --  One wheel notch in the zoom-in direction maps to one zoom step.
   --  Levels that would clamp to the same effective size are skipped, so
   --  every accepted step produces a visible change.
   procedure Step_Zoom
     (Level     : in out Integer;
      Steps     :        Integer;
      Base_Pt   :        Integer;
      Changed   :    out Boolean);
   --  Adjust Level by Steps (positive = zoom in), skipping levels that
   --  clamp to the current effective size.  Changed is True when the
   --  effective point size actually changed.

   function Effective_Size_Pt
     (Level   : Integer;
      Base_Pt : Integer) return Integer;
   --  Effective font point size for a zoom level, clamped to
   --  [Min_Size_Pt, Max_Size_Pt].

   function Clamped_Base_Pt (Base_Pt : Integer) return Integer;
   --  Baseline size clamped to [Min_Size_Pt, Max_Size_Pt]; used as the
   --  reference for the display-math scale factor.

end Coyote_GUI.Zoom;
