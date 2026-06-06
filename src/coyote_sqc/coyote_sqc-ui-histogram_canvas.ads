--  Coyote_SQC.UI.Histogram_Canvas — distribution histogram for multi-select.
--
--  Renders a Cairo histogram of the active chart's statistic for the
--  currently selected sessions.  The histogram is a fixed-height
--  GtkDrawingArea (160 px) embedded in the multi-select detail panel.
--
--  Project: coyote

with Coyote_SQC.Data_Model;
with Gtk.Drawing_Area;

package Coyote_SQC.UI.Histogram_Canvas is

   --  Maximum number of histogram bins (FD cap).
   Max_Bins : constant := 32;

   --  Array types used in the public API.
   type Long_Float_Array is array (Positive range <>) of Long_Float;
   type Bin_Count_Array  is array (1 .. Max_Bins)     of Natural;

   --  Build the GtkDrawingArea widget (height request 160 px).
   --  Must be called once; the widget handle is stored internally.
   function Build return Gtk.Drawing_Area.Gtk_Drawing_Area;

   --  Update histogram data and queue a redraw.
   --
   --  Values   : statistic values for selected, eligible sessions.
   --  CL       : center-line value; drawn as a solid blue vertical line.
   --  UCL, LCL : control limit values; drawn as red dashed vertical lines
   --             only when Has_UCL / Has_LCL are True.
   --  X_Label  : x-axis label (the active chart's statistic name).
   --  Has_Data : when False the widget shows "No data for active chart"
   --             and ignores all other parameters.
   procedure Refresh
     (Values   : Long_Float_Array;
      CL       : Long_Float;
      UCL      : Long_Float;
      Has_UCL  : Boolean;
      LCL      : Long_Float;
      Has_LCL  : Boolean;
      X_Label  : String;
      Has_Data : Boolean);

   --  Bin computation — exposed for unit testing.
   --
   --  Applies the Freedman-Diaconis rule to Values:
   --    h = 2 * IQR / n^(1/3),  k = max(1, ceil(range / h)), capped at Max_Bins.
   --  When IQR = 0 (heavily concentrated data): N_Bins = 1, Bin_Width = range.
   --  When range = 0 (all values equal): N_Bins = 1, Bin_Width = 1.0.
   --  Counts(1 .. N_Bins) receive the bin populations;
   --  Counts(N_Bins+1 .. Max_Bins) are set to 0.
   --  Precondition: Values'Length >= 1.
   procedure Compute_Bins
     (Values    :     Long_Float_Array;
      N_Bins    : out Positive;
      Bin_Min   : out Long_Float;
      Bin_Width : out Long_Float;
      Counts    : out Bin_Count_Array);


   --  Update histogram data for a two-set overlay and queue a redraw.
   --
   --  Values_A : statistic values for Set A (blue, semi-transparent).
   --  Values_B : statistic values for Set B (orange, semi-transparent).
   --  CL, UCL, LCL, Has_UCL, Has_LCL : control-limit lines derived from the
   --             first contributing Set A point (same rules as single-set Refresh).
   --  X_Label  : x-axis label (active chart's statistic name).
   --  Has_Data : when False the widget shows "No data for active chart".
   --
   --  Bin boundaries are computed from the pooled (Values_A & Values_B) sample
   --  using the Freedman-Diaconis rule; both sets share the same bins.
   procedure Refresh_Two_Set
     (Values_A  : Coyote_SQC.Data_Model.Long_Float_Vectors.Vector;
      Values_B  : Coyote_SQC.Data_Model.Long_Float_Vectors.Vector;
      CL        : Long_Float;
      UCL       : Long_Float;
      Has_UCL   : Boolean;
      LCL       : Long_Float;
      Has_LCL   : Boolean;
      X_Label   : String;
      Has_Data  : Boolean);

end Coyote_SQC.UI.Histogram_Canvas;
