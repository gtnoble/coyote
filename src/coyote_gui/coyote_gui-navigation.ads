--  Coyote_GUI.Navigation — display-independent viewport navigation policy.
--
--  Project: coyote

with Glib;

package Coyote_GUI.Navigation is

   type Movement is
     (Line_Up,
      Line_Down,
      Page_Up,
      Page_Down,
      To_Top,
      To_Bottom);

   --  Return the clamped adjustment value for Movement.  Lower and Upper
   --  describe the adjustment range; Page_Size is its visible extent.
   function Target_Value
     (Current   : Glib.Gdouble;
      Lower     : Glib.Gdouble;
      Upper     : Glib.Gdouble;
      Page_Size : Glib.Gdouble;
      Line_Size : Glib.Gdouble;
      Move      : Movement) return Glib.Gdouble;

end Coyote_GUI.Navigation;
