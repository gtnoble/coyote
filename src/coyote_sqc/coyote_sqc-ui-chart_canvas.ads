--  Coyote_SQC.UI.Chart_Canvas — Cairo-based chart renderer.
--
--  Creates and manages the GtkDrawingArea used for chart display.
--  All interaction (pan, zoom, rubber-band select, hover) is handled here.
--
--  Project: coyote

with Gtk.Drawing_Area;

package Coyote_SQC.UI.Chart_Canvas is

   --  Create the drawing area, connect signals, and return it.
   function Build return Gtk.Drawing_Area.Gtk_Drawing_Area;

   --  Request a canvas redraw (calls Queue_Draw on the drawing area).
   procedure Queue_Redraw;
   --  Update X_Min/X_Max in Canvas_State to match App_State.Date_From/Date_To.
   procedure Sync_X_From_Dates;


   --  Reset X and Y ranges to show all sessions.
   procedure Reset_View;
   --  Switch the x-axis scale mode.  Converts the current X_Min/X_Max viewport
   --  from the old coordinate space to the new, updates State.Run_Sequence_Mode,
   --  syncs the From/To toolbar pickers, and requests a redraw.
   --  Pass the desired new mode (True = Run Sequence, False = Time Scale).
   procedure Switch_X_Scale_Mode (New_Run_Sequence : Boolean);

   --  Convert data-space x (Unix seconds) to screen x.
   function Data_To_Screen_X (DX : Long_Float) return Long_Float;
   function Data_To_Screen_Y (DY : Long_Float) return Long_Float;
   function Screen_To_Data_X (SX : Long_Float) return Long_Float;
   function Screen_To_Data_Y (SY : Long_Float) return Long_Float;

end Coyote_SQC.UI.Chart_Canvas;
