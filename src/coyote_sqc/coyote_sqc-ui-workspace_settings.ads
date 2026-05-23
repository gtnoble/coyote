--  Coyote_SQC.UI.Workspace_Settings — workspace settings dialog.
--
--  Accessible via Workspace → Workspace Settings…
--
--  Project: coyote

package Coyote_SQC.UI.Workspace_Settings is

   --  Show the workspace settings dialog modally.
   --  On OK, applies changes, triggers session reload and integrity check.
   procedure Show_Dialog;

end Coyote_SQC.UI.Workspace_Settings;
