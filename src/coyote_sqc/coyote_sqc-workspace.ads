--  Coyote_SQC.Workspace — workspace file load/save and modification tracking.
--
--  Project: coyote

with Coyote_SQC.Charts;
with Coyote_SQC.Data_Model;

package Coyote_SQC.Workspace is

   Workspace_Error : exception;

   --  Load a workspace from a .sqcw JSON file.
   --  Raises Workspace_Error on version > 10 or file I/O failure.
   --  Workspace files at version ≤ 9 are automatically migrated to version 10
   --  (v1–6: shared Box-Cox / estimation-method fields are broadcast to per-chart
   --  entries; v7–8: logYMode defaulted to False) and the caller should re-save.
   --  (shared Box-Cox / estimation-method fields are broadcast to per-chart
   --  entries) and the caller should re-save.  Version_Found is set to the
   --  version stored in the file (0 if absent); Migrated is True when an
   --  older-format file was upgraded so the caller can prompt a resave.
   procedure Load
     (Path          :     String;
      Workspace     : out Coyote_SQC.Data_Model.Workspace_Record;
      Version_Found : out Natural;
      Migrated      : out Boolean);

   --  Save a workspace to a .sqcw JSON file at version 10.
   --  Raises Workspace_Error on file I/O failure.
   procedure Save
     (Path      : String;
      Workspace : Coyote_SQC.Data_Model.Workspace_Record);

   --  Return the Chart_Settings_Record for Kind, falling back to the
   --  all-default record when Kind is absent from the workspace map.
   function Chart_Settings
     (W    : Coyote_SQC.Data_Model.Workspace_Record;
      Kind : Coyote_SQC.Charts.Chart_Kind)
      return Coyote_SQC.Data_Model.Chart_Settings_Record;

   --  Return True if the settings record is entirely at default values
   --  (Box-Cox disabled, Classical estimation, EWMA_Weight=0.2, EWMA_L=3.0).
   --  Charts at default settings are omitted from the workspace file.
   function Is_Default
     (Rec : Coyote_SQC.Data_Model.Chart_Settings_Record) return Boolean;

   --  Generate a new UUIDv4 string.
   function New_UUID return String;

end Coyote_SQC.Workspace;
