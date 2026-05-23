--  Coyote_SQC.Workspace.Integrity — setup interval integrity checks.
--
--  When the workspace model filter or source directory list is changed,
--  this package checks whether any setup session is no longer present in
--  the filtered session set.
--
--  Project: coyote

with Coyote_SQC.Data_Model;

package Coyote_SQC.Workspace.Integrity is

   --  Result of an integrity check.
   type Check_Result is record
      Missing_Count : Natural := 0;
      --  Number of setup session IDs absent from the filtered session set.
   end record;

   --  Check whether all sessions in Workspace.Setup_Session_Ids are present
   --  in Sessions.  Returns the count of missing sessions.
   function Check
     (Workspace : Coyote_SQC.Data_Model.Workspace_Record;
      Sessions  : Coyote_SQC.Data_Model.Session_Vectors.Vector)
      return Check_Result;

   --  Remove all setup session IDs that are not present in Sessions.
   --  Modifies Workspace in place.
   procedure Remove_Missing
     (Workspace : in out Coyote_SQC.Data_Model.Workspace_Record;
      Sessions  :        Coyote_SQC.Data_Model.Session_Vectors.Vector);

end Coyote_SQC.Workspace.Integrity;
