--  Coyote_SQC.UI.Hover_Tooltip — hover popover over chart points.
--
--  Project: coyote

with Gtk.Drawing_Area;

package Coyote_SQC.UI.Hover_Tooltip is

   --  Attach tooltip popover to the given drawing area.
   --  Call once during canvas setup.
   procedure Attach
     (Canvas : not null access Gtk.Drawing_Area.Gtk_Drawing_Area_Record'Class);

   --  Show or refresh the tooltip for the session at screen position (X, Y).
   procedure Show_For_Session
     (Session_Id : String;
      Screen_X   : Long_Float;
      Screen_Y   : Long_Float);

   --  Hide the tooltip.
   procedure Hide;

   --  Return True if the tooltip is currently visible.
   function Is_Visible return Boolean;

end Coyote_SQC.UI.Hover_Tooltip;
