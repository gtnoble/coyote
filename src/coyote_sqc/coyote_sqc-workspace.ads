--  Coyote_SQC.Workspace — workspace file load/save and modification tracking.
--
--  Project: coyote

with Coyote_SQC.Data_Model;

package Coyote_SQC.Workspace is

   Workspace_Error : exception;

   --  Load a workspace from a .sqcw JSON file.
   --  Raises Workspace_Error on version > 1 or file I/O failure.
   procedure Load
     (Path      :     String;
      Workspace     : out Coyote_SQC.Data_Model.Workspace_Record;
      Version_Found : out Natural);

   --  Save a workspace to a .sqcw JSON file.
   --  Raises Workspace_Error on file I/O failure.
   procedure Save
     (Path      : String;
      Workspace : Coyote_SQC.Data_Model.Workspace_Record);

   --  Generate a new UUIDv4 string.
   function New_UUID return String;

end Coyote_SQC.Workspace;
