--  Coyote_SQC.Metrics — derive Session_Metrics_Record from Session_Record.
--
--  Computed once at load time and cached alongside the session.
--
--  Project: coyote

with Coyote_SQC.Data_Model;

package Coyote_SQC.Metrics is

   --  Compute and return the metrics record for Session.
   function Compute
     (Session : Coyote_SQC.Data_Model.Session_Record)
      return Coyote_SQC.Data_Model.Session_Metrics_Record;

end Coyote_SQC.Metrics;
