--  Coyote_SQC.Statistics — root statistics package.
--
--  All computation operates on Long_Float to match
--  Ada.Numerics.Long_Elementary_Functions.
--
--  Project: coyote

with Coyote_SQC.Charts;
with Coyote_SQC.Data_Model;

package Coyote_SQC.Statistics is

   --  Control-limit output record.
   type Limits_Record is record
      UCL    : Long_Float;
      CL     : Long_Float;
      LCL    : Long_Float;
      --  True when limits could not be computed (e.g. n=1, p denominator=0).
      --  True when the UCL can be drawn (limits were successfully computed).
      Has_UCL : Boolean := False;
      --  True when the LCL can be drawn (limits computed and LCL > 0).
      Has_LCL : Boolean := False;
   end record;

   --  Parameter estimates derived from the setup interval.
   type Setup_Parameters is record
      Grand_Mean : Long_Float := 0.0;
      Pooled_S   : Long_Float := 0.0;
      Grand_P    : Long_Float := 0.0;
      Mean_MR    : Long_Float := 0.0;
   end record;

   --  Estimate grand mean / pooled s (Xbar/s charts) or grand p (p charts)
   --  from the setup-interval session metrics.  Only metrics whose
   --  Session_Id is in Setup_Ids are used; when Setup_Ids is empty, all
   --  metrics in the vector are used (retrospective mode).
   procedure Estimate_Parameters
     (Metrics    :     Coyote_SQC.Data_Model.Metrics_Vectors.Vector;
      Setup_Ids  :     Coyote_SQC.Data_Model.UUID_Set;
      Kind       :     Coyote_SQC.Charts.Chart_Kind;
      Parameters : out Setup_Parameters);

end Coyote_SQC.Statistics;
