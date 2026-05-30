--  Coyote_SQC_Integrity_Tests body.
--
--  Project: coyote

with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with AUnit.Assertions;
with Coyote_SQC.Data_Model;
with Coyote_SQC.Workspace.Integrity;

package body Coyote_SQC_Integrity_Tests is

   use AUnit.Assertions;
   use Coyote_SQC.Data_Model;

   --  ── Check tests ───────────────────────────────────────────────────────

   --  All setup sessions are present in the filtered set → Missing_Count = 0.
   procedure Test_Check_All_Present (T : in out Test) is
      pragma Unreferenced (T);
      W   : Workspace_Record;
      Ses : Session_Vectors.Vector;
      R   : Coyote_SQC.Workspace.Integrity.Check_Result;

      procedure Add_Ses (ID : String) is
         S : Session_Record;
      begin
         S.Session_Id := To_Unbounded_String (ID);
         Ses.Append (S);
      end Add_Ses;
   begin
      W.Setup_Session_Ids.Include (To_Unbounded_String ("aaa"));
      W.Setup_Session_Ids.Include (To_Unbounded_String ("bbb"));
      W.Setup_Session_Ids.Include (To_Unbounded_String ("ccc"));
      Add_Ses ("aaa"); Add_Ses ("bbb"); Add_Ses ("ccc"); Add_Ses ("ddd");

      R := Coyote_SQC.Workspace.Integrity.Check (W, Ses);
      Assert (R.Missing_Count = 0,
              "All present: Missing_Count should be 0; got "
              & Natural'Image (R.Missing_Count));
   end Test_Check_All_Present;

   --  One setup session absent from the filtered set → Missing_Count = 1.
   procedure Test_Check_Some_Missing (T : in out Test) is
      pragma Unreferenced (T);
      W   : Workspace_Record;
      Ses : Session_Vectors.Vector;
      R   : Coyote_SQC.Workspace.Integrity.Check_Result;

      procedure Add_Ses (ID : String) is
         S : Session_Record;
      begin
         S.Session_Id := To_Unbounded_String (ID);
         Ses.Append (S);
      end Add_Ses;
   begin
      W.Setup_Session_Ids.Include (To_Unbounded_String ("aaa"));
      W.Setup_Session_Ids.Include (To_Unbounded_String ("bbb"));
      W.Setup_Session_Ids.Include (To_Unbounded_String ("missing"));
      Add_Ses ("aaa"); Add_Ses ("bbb");

      R := Coyote_SQC.Workspace.Integrity.Check (W, Ses);
      Assert (R.Missing_Count = 1,
              "One missing: Missing_Count should be 1; got "
              & Natural'Image (R.Missing_Count));
   end Test_Check_Some_Missing;

   --  All setup sessions absent → Missing_Count = N.
   procedure Test_Check_All_Missing (T : in out Test) is
      pragma Unreferenced (T);
      W   : Workspace_Record;
      Ses : Session_Vectors.Vector;
      R   : Coyote_SQC.Workspace.Integrity.Check_Result;

      procedure Add_Ses (ID : String) is
         S : Session_Record;
      begin
         S.Session_Id := To_Unbounded_String (ID);
         Ses.Append (S);
      end Add_Ses;
   begin
      W.Setup_Session_Ids.Include (To_Unbounded_String ("x"));
      W.Setup_Session_Ids.Include (To_Unbounded_String ("y"));
      W.Setup_Session_Ids.Include (To_Unbounded_String ("z"));
      Add_Ses ("aaa"); Add_Ses ("bbb");

      R := Coyote_SQC.Workspace.Integrity.Check (W, Ses);
      Assert (R.Missing_Count = 3,
              "All missing: Missing_Count should be 3; got "
              & Natural'Image (R.Missing_Count));
   end Test_Check_All_Missing;

   --  Empty setup interval → Missing_Count = 0 regardless of sessions.
   procedure Test_Check_Empty_Setup (T : in out Test) is
      pragma Unreferenced (T);
      W   : Workspace_Record;
      Ses : Session_Vectors.Vector;
      R   : Coyote_SQC.Workspace.Integrity.Check_Result;

      procedure Add_Ses (ID : String) is
         S : Session_Record;
      begin
         S.Session_Id := To_Unbounded_String (ID);
         Ses.Append (S);
      end Add_Ses;
   begin
      Add_Ses ("aaa"); Add_Ses ("bbb");

      R := Coyote_SQC.Workspace.Integrity.Check (W, Ses);
      Assert (R.Missing_Count = 0,
              "Empty setup: Missing_Count should be 0; got "
              & Natural'Image (R.Missing_Count));
   end Test_Check_Empty_Setup;

   --  ── Remove_Missing tests ──────────────────────────────────────────────

   --  Partial removal: one missing ID removed, others retained.
   procedure Test_Remove_Missing_Partial (T : in out Test) is
      pragma Unreferenced (T);
      W   : Workspace_Record;
      Ses : Session_Vectors.Vector;

      procedure Add_Ses (ID : String) is
         S : Session_Record;
      begin
         S.Session_Id := To_Unbounded_String (ID);
         Ses.Append (S);
      end Add_Ses;
   begin
      W.Setup_Session_Ids.Include (To_Unbounded_String ("aaa"));
      W.Setup_Session_Ids.Include (To_Unbounded_String ("bbb"));
      W.Setup_Session_Ids.Include (To_Unbounded_String ("gone"));
      Add_Ses ("aaa"); Add_Ses ("bbb");

      Coyote_SQC.Workspace.Integrity.Remove_Missing (W, Ses);

      Assert (W.Setup_Session_Ids.Contains (To_Unbounded_String ("aaa")),
              "Remove_Missing partial: ""aaa"" must be retained");
      Assert (W.Setup_Session_Ids.Contains (To_Unbounded_String ("bbb")),
              "Remove_Missing partial: ""bbb"" must be retained");
      Assert
        (not W.Setup_Session_Ids.Contains (To_Unbounded_String ("gone")),
         "Remove_Missing partial: ""gone"" must be removed");
      Assert (Natural (W.Setup_Session_Ids.Length) = 2,
              "Remove_Missing partial: Length should be 2; got "
              & Natural'Image (Natural (W.Setup_Session_Ids.Length)));
   end Test_Remove_Missing_Partial;

   --  All IDs missing: Setup_Session_Ids becomes empty.
   procedure Test_Remove_Missing_All (T : in out Test) is
      pragma Unreferenced (T);
      W   : Workspace_Record;
      Ses : Session_Vectors.Vector;
   begin
      W.Setup_Session_Ids.Include (To_Unbounded_String ("x"));
      W.Setup_Session_Ids.Include (To_Unbounded_String ("y"));
      W.Setup_Session_Ids.Include (To_Unbounded_String ("z"));

      Coyote_SQC.Workspace.Integrity.Remove_Missing (W, Ses);
      Assert (W.Setup_Session_Ids.Is_Empty,
              "Remove_Missing all: Setup_Session_Ids must be empty after "
              & "removing all missing IDs");
   end Test_Remove_Missing_All;

   --  No IDs missing: Setup_Session_Ids is unchanged.
   procedure Test_Remove_Missing_None (T : in out Test) is
      pragma Unreferenced (T);
      W   : Workspace_Record;
      Ses : Session_Vectors.Vector;

      procedure Add_Ses (ID : String) is
         S : Session_Record;
      begin
         S.Session_Id := To_Unbounded_String (ID);
         Ses.Append (S);
      end Add_Ses;
   begin
      W.Setup_Session_Ids.Include (To_Unbounded_String ("aaa"));
      W.Setup_Session_Ids.Include (To_Unbounded_String ("bbb"));
      Add_Ses ("aaa"); Add_Ses ("bbb"); Add_Ses ("extra");

      Coyote_SQC.Workspace.Integrity.Remove_Missing (W, Ses);
      Assert (Natural (W.Setup_Session_Ids.Length) = 2,
              "Remove_Missing none: Length must still be 2; got "
              & Natural'Image (Natural (W.Setup_Session_Ids.Length)));
      Assert (W.Setup_Session_Ids.Contains (To_Unbounded_String ("aaa")),
              "Remove_Missing none: ""aaa"" must still be present");
      Assert (W.Setup_Session_Ids.Contains (To_Unbounded_String ("bbb")),
              "Remove_Missing none: ""bbb"" must still be present");
   end Test_Remove_Missing_None;

end Coyote_SQC_Integrity_Tests;
