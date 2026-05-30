--  Coyote_SQC.UI.Chart_Settings_Dialog — per-chart settings dialog.
--
--  Accessible via View → Chart Settings… (Ctrl+,) or by right-clicking
--  the chart canvas (§8.5 of the requirements).
--
--  The dialog presents three collapsible expanders:
--    • Box-Cox Transformation
--    • Estimation Method
--    • EWMA Parameters (EWMA chart kinds only)
--  plus a "Reset to Defaults" button and OK/Cancel.
--
--  All changes affect only the active chart; other charts are unchanged.
--  On OK the chart settings map is updated sparsely (default entries are
--  removed) and Recompute_Chart (Kind) is called.
--
--  Project: coyote

with Coyote_SQC.Charts;

package Coyote_SQC.UI.Chart_Settings_Dialog is

   --  Show the Chart Settings dialog for Kind, modal over the application
   --  main window.  Returns after the user clicks OK or Cancel.
   --
   --  On OK:
   --    • Writes the new Chart_Settings_Record into
   --      App_State.Workspace.Chart_Settings (Kind), using Include or
   --      deleting the entry when all fields are at default.
   --    • Sets App_State.Modified := True.
   --    • Calls Coyote_SQC.App.Recompute_Chart (Kind).
   --    • Queues a canvas redraw.
   --
   --  On Cancel: no changes are made.
   procedure Show (Kind : Coyote_SQC.Charts.Chart_Kind);

end Coyote_SQC.UI.Chart_Settings_Dialog;
