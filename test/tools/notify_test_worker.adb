--  Notify_Test_Worker — isolated smoke test for notification lifecycle.
--
--  Project: coyote

with Coyote_Notify;

procedure Notify_Test_Worker is
   Ignore_Result : Boolean;
   pragma Unreferenced (Ignore_Result);
begin
   Ignore_Result := Coyote_Notify.Show_Completion;
   Ignore_Result := Coyote_Notify.Show_Completion;
   Coyote_Notify.Finalize;
   Coyote_Notify.Finalize;
   Ignore_Result := Coyote_Notify.Show_Completion;
   Coyote_Notify.Finalize;
end Notify_Test_Worker;
