--  Coyote_GUI.Zoom body.
--
--  Project: coyote

package body Coyote_GUI.Zoom is

   function Clamp (Value, Lo, Hi : Integer) return Integer is
   begin
      if Value < Lo then
         return Lo;
      elsif Value > Hi then
         return Hi;
      else
         return Value;
      end if;
   end Clamp;

   ----------------
   --  Step_Zoom --
   ----------------

   procedure Step_Zoom
     (Level     : in out Integer;
      Steps     :        Integer;
      Base_Pt   :        Integer;
      Changed   :    out Boolean)
   is
      Old_Size : constant Integer := Effective_Size_Pt (Level, Base_Pt);
   begin
      if Steps > 0 then
         Level := Level + Steps;
         --  Walk back out of the clamp plateau: leave Level at the
         --  first level whose effective size is Max_Size_Pt, so huge
         --  step requests cannot run the level away without bound.
         while Effective_Size_Pt (Level, Base_Pt) = Max_Size_Pt
           and then Effective_Size_Pt (Level - 1, Base_Pt) = Max_Size_Pt
         loop
            Level := Level - 1;
         end loop;
      elsif Steps < 0 then
         Level := Level + Steps;
         while Effective_Size_Pt (Level, Base_Pt) = Min_Size_Pt
           and then Effective_Size_Pt (Level + 1, Base_Pt) = Min_Size_Pt
         loop
            Level := Level + 1;
         end loop;
      end if;

      Changed := Effective_Size_Pt (Level, Base_Pt) /= Old_Size;
   end Step_Zoom;

   --------------------------
   --  Effective_Size_Pt  --
   --------------------------

   function Effective_Size_Pt
     (Level   : Integer;
      Base_Pt : Integer) return Integer
   is
   begin
      return Clamp (Base_Pt + Level * Zoom_Step_Pt,
                    Min_Size_Pt, Max_Size_Pt);
   end Effective_Size_Pt;

   -----------------------
   --  Clamped_Base_Pt  --
   -----------------------

   function Clamped_Base_Pt (Base_Pt : Integer) return Integer is
   begin
      return Clamp (Base_Pt, Min_Size_Pt, Max_Size_Pt);
   end Clamped_Base_Pt;

end Coyote_GUI.Zoom;
