with Cairo;
with Math_Model;
with Math_Work_Control;

--  Worker-local Pango shaping for bounded Unicode fallback text runs.
package Math_Text_Shaping is
   type Metrics is record
      Advance : Long_Float := 0.0;
      Ascent  : Long_Float := 0.0;
      Descent : Long_Float := 0.0;
   end record;

   function Is_Valid_Profile
     (Profile : Math_Model.Script_Profile) return Boolean;
   function Measure
     (Text : String; Profile : Math_Model.Script_Profile;
      Pixel_Em : Long_Float := 0.0;
      Work : Math_Work_Control.Context_Access := null) return Metrics;
   --  Pixel_Em selects the absolute Pango font size; zero uses 16 pixels.
   --  Returned metrics are normalized to that size. Work is borrowed only
   --  for the call and cancellation/deadline exceptions propagate.
   procedure Draw
     (Context : Cairo.Cairo_Context;
      Text : String;
      Profile : Math_Model.Script_Profile;
      X, Baseline, Em, Scale : Long_Float;
      Work : Math_Work_Control.Context_Access := null);
end Math_Text_Shaping;
