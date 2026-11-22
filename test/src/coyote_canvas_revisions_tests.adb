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
   Seen_Color : Ink_Color := DEFAULT_INK_COLOR;

   procedure Collect
     (Points : Samples.Vector; Operation : Ink_Operation;
      Color : Ink_Color; Rendering : Stroke_Rendering) is
      pragma Unreferenced (Rendering);
      pragma Unreferenced (Operation);
   begin
      Seen_Count := Seen_Count + 1;
      Seen_Point := Points.First_Element;
      Seen_Color := Color;
   end Collect;

   procedure Independent_Revisions (T : in out Test) is
      pragma Unreferenced (T);
      W      : Workspace;
      A, B   : Revision_Id;
      Stroke : Samples.Vector;
   begin
      New_Drawing (W, 40, 30);
      Stroke.Append ((X => 3.0, Y => 4.0, Width => 1.5, Alpha => 1.0));
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
      Assert (Seen_Color = DEFAULT_INK_COLOR,
              "default paint retains the default color");
      Stroke.Clear;
      Stroke.Append ((X => 1.0, Y => 1.0, Width => 1.0, Alpha => 1.0));
      Add_Stroke (W, Stroke, Color => 16#FF_00_00#);
      Save (W);
      Visit_Source (W, Base (W), Collect'Access);
      Assert (Seen_Color = 16#FF_00_00#,
              "custom paint color is retained on revision");
      Add_Stroke (W, Stroke, Erase, 16#FF_FF_FF#);
      Visit_Source (W, NO_REVISION, Collect'Access);
      Assert (Seen_Color = DEFAULT_INK_COLOR,
              "erase normalizes its color to the default");
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

   procedure Add_Originals_Preserve_Draft (T : in out Test) is
      pragma Unreferenced (T);
      W             : Workspace;
      First         : Revision_Id;
      Capacity      : Workspace;
      Capacity_First : Revision_Id;
      Rejected      : Boolean := False;
      Sizes         : constant Image_Sizes :=
        (1 => (Width => 40, Height => 30),
         2 => (Width => 90, Height => 70));
      Full          : Image_Sizes (1 .. 254) :=
        (others => (Width => 1, Height => 1));
      Batch         : constant Image_Sizes :=
        (1 => (Width => 5, Height => 6),
         2 => (Width => 7, Height => 8));
   begin
      New_Drawing (W, 20, 16);
      Crop (W, (1, 1, 19, 15));
      Crop (W, (2, 2, 18, 14));
      Undo (W);
      Assert
        (Can_Undo (W) and then Can_Redo (W),
         "setup retains both undo and redo history");

      Add_Originals (W, Sizes, First);
      Assert
        (First = 2 and then Count (W) = 3,
         "batch publishes two consecutive revisions in order");
      Assert
        (Parent (W, First) = NO_REVISION
         and then Parent (W, First + 1) = NO_REVISION,
         "each Original is an independent root");
      Assert
        (Extent (W, First) = Full_Extent (40, 30)
         and then Extent (W, First + 1) = Full_Extent (90, 70),
         "Original backgrounds retain their ordered dimensions");
      Assert
        (Background (W, First) = First
         and then Background (W, First + 1) = First + 1,
         "each Original retains its own background identity");
      Assert
        (Base (W) = 1 and then Changed (W)
         and then Extent (W) = (1, 1, 19, 15),
         "adding Originals neither checkpoints nor switches draft");
      Assert
        (Can_Undo (W) and then Can_Redo (W),
         "adding Originals preserves draft undo and redo history");

      Add_Originals (Capacity, Full, Capacity_First);
      New_Drawing (Capacity, 20, 16);
      Crop (Capacity, (1, 1, 19, 15));
      Crop (Capacity, (2, 2, 18, 14));
      Undo (Capacity);
      Assert
        (Count (Capacity) = MAX_REVISIONS - 1
         and then Can_Undo (Capacity) and then Can_Redo (Capacity),
         "capacity setup leaves one slot with undo and redo history");
      begin
         Add_Originals (Capacity, Batch, Capacity_First);
      exception
         when Capacity_Error =>
            Rejected := True;
      end;
      Assert (Rejected, "two-item batch exceeds remaining capacity");
      Assert
        (Count (Capacity) = MAX_REVISIONS - 1
         and then Base (Capacity) = 255
         and then Changed (Capacity)
         and then Background (Capacity) = NO_REVISION
         and then Extent (Capacity) = (1, 1, 19, 15),
         "rejected batch leaves revision count and draft unchanged");
      Assert
        (Can_Undo (Capacity) and then Can_Redo (Capacity),
         "rejected batch leaves undo and redo history unchanged");
   end Add_Originals_Preserve_Draft;

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
        (Caller.Create
           ("Canvas Add_Originals preserves draft and capacity state",
            Add_Originals_Preserve_Draft'Access));
      Result.Add_Test
        (Caller.Create ("Canvas crop undo and redo", Undo_Redo_Crop'Access));
      Result.Add_Test
        (Caller.Create
           ("Canvas retains branches and multi-step undo",
            Branch_And_Undo'Access));
      return Result;
   end Suite;
end Coyote_Canvas_Revisions_Tests;
