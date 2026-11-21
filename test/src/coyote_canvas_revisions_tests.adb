with AUnit.Assertions; use AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Coyote_Canvas.Document;
with Coyote_Canvas.Revisions;

package body Coyote_Canvas_Revisions_Tests is
   use Coyote_Canvas.Document;
   use Coyote_Canvas.Revisions;

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   Seen_Count : Natural := 0;
   Seen_Point : Sample;

   procedure Collect (Points : Samples.Vector) is
   begin
      Seen_Count := Seen_Count + 1;
      Seen_Point := Points.First_Element;
   end Collect;

   procedure Independent_Revisions (T : in out Test) is
      pragma Unreferenced (T);
      W      : Workspace;
      A, B   : Revision_Id;
      Stroke : Samples.Vector;
   begin
      New_Drawing (W, 40, 30);
      Stroke.Append ((X => 3.0, Y => 4.0, Width => 1.5));
      Add_Stroke (W, Stroke);
      Save (W);
      A := Base (W);
      Assert
        (A /= NO_REVISION and then not Changed (W),
         "save creates a clean base revision");
      Crop (W, (1, 2, 20, 18));
      Save (W);
      B := Base (W);
      Assert (Parent (W, B) = A, "new revision links to prior base");
      Assert
        (Extent (W, A) = Full_Extent (40, 30),
         "prior revision extent remains immutable");
      Assert
        (Extent (W, B) = (1, 2, 20, 18),
         "cropped revision extent uses source coordinates");
      Seen_Count := 0;
      Visit_Source (W, B, Collect'Access);
      Assert (Seen_Count = 1, "stroke visible in crop");
      Assert
        (Seen_Point.X = 3.0 and then Seen_Point.Y = 4.0,
         "visit preserves original pixel-grid phase");
      Edit (W, A);
      Assert
        (Extent (W) = Full_Extent (40, 30),
         "editing older revision restores its independent extent");
      Assert (Parent (W, A) = 1, "saved ink is a child of the Original");
   end Independent_Revisions;

   procedure Checkpoint_Dirty_Draft (T : in out Test) is
      pragma Unreferenced (T);
      W     : Workspace;
      First : Revision_Id;
   begin
      New_Drawing (W, 8, 8);
      Save (W);
      First := Base (W);
      Crop (W, (1, 1, 7, 7));
      Edit (W, First);
      Assert (Count (W) = 2, "dirty draft checkpointed before switching");
      Assert
        (Base (W) = First and then Parent (W, 2) = First,
         "checkpoint parent is the prior base");
   end Checkpoint_Dirty_Draft;

   procedure Undo_Redo_Crop (T : in out Test) is
      pragma Unreferenced (T);
      W : Workspace;
   begin
      New_Drawing (W, 12, 10);
      Crop (W, (2, 1, 10, 9));
      Assert (Extent (W) = (2, 1, 10, 9), "crop changes draft only");
      Undo (W);
      Assert (Extent (W) = Full_Extent (12, 10), "undo restores crop");
      Redo (W);
      Assert (Extent (W) = (2, 1, 10, 9), "redo reapplies crop");
      Clear (W);
      Seen_Count := 0;
      Visit_Source (W, NO_REVISION, Collect'Access);
      Assert
        (Seen_Count = 0 and then Count (W) = 0,
         "clear resets state and empty draft is not visited");
   end Undo_Redo_Crop;

   procedure Branch_And_Undo (T : in out Test) is
      pragma Unreferenced (T);
      W : Workspace;
   begin
      New_Drawing (W, 40, 30);
      Crop (W, (2, 3, 35, 25));
      Crop (W, (1, 1, 30, 20));
      Undo (W);
      Undo (W);
      Assert (Extent (W) = Full_Extent (40, 30), "two undo steps");
      Redo (W);
      Redo (W);
      Assert (Extent (W) = (3, 4, 32, 23), "two redo steps");
      Save (W);
      Save (W);
      Assert (Count (W) = 2, "unchanged save does not duplicate a node");
      Edit (W, 1);
      Crop (W, (0, 0, 5, 6));
      New_Drawing (W, 22, 23);
      Assert
        (Count (W) = 4 and then Parent (W, 2) = 1 and then Parent (W, 3) = 1
         and then Parent (W, 4) = NO_REVISION,
         "new root follows retained sibling revisions");
      Assert
        (not Can_Undo (W) and then not Can_Redo (W),
         "undo history does not leak across drafts");
   end Branch_And_Undo;

   package Caller is new AUnit.Test_Caller (Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test
        (Caller.Create
           ("Canvas revisions are independent", Independent_Revisions'Access));
      Result.Add_Test
        (Caller.Create
           ("Canvas edit checkpoints dirty draft",
            Checkpoint_Dirty_Draft'Access));
      Result.Add_Test
        (Caller.Create ("Canvas crop undo and redo", Undo_Redo_Crop'Access));
      Result.Add_Test
        (Caller.Create
           ("Canvas retains branches and multi-step undo",
            Branch_And_Undo'Access));
      return Result;
   end Suite;
end Coyote_Canvas_Revisions_Tests;
