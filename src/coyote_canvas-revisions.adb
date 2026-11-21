with Ada.Containers;

package body Coyote_Canvas.Revisions is
   use type Ada.Containers.Count_Type;
   use type Document.Rectangle;

   MAX_REVISIONS : constant := 256;
   MAX_STROKES   : constant := 512;
   MAX_EDITS     : constant := 256;
   MAX_POINTS    : constant := 100_000;

   procedure Clear (W : in out Workspace) is
   begin
      W.Revisions.Clear;
      W.Past.Clear;
      W.Future.Clear;
      W.Strokes.Clear;
      W.Draft   := (others => <>);
      W.Points  := 0;
      W.Base_Id := NO_REVISION;
   end Clear;

   function Count (W : Workspace) return Natural is
     (Natural (W.Revisions.Length));

   function Parent (W : Workspace; Id : Revision_Id) return Revision_Id is
     (W.Revisions (Id).Parent);

   function Extent
     (W : Workspace; Id : Revision_Id := NO_REVISION)
      return Document.Rectangle is
     (if Id = NO_REVISION then W.Draft.Extent
      else W.Revisions (Id).Content.Extent);

   function Base (W : Workspace) return Revision_Id is (W.Base_Id);

   function Changed (W : Workspace) return Boolean is
     (W.Base_Id /= NO_REVISION
      and then W.Draft /= W.Revisions (W.Base_Id).Content);

   procedure Reserve_Revisions (W : in out Workspace; Need : Positive) is
   begin
      if Count (W) > MAX_REVISIONS - Need then
         raise Capacity_Error with "Canvas revision limit reached";
      end if;
      W.Revisions.Reserve_Capacity
        (Ada.Containers.Count_Type (Count (W) + Need));
   end Reserve_Revisions;

   procedure Save (W : in out Workspace) is
   begin
      if Changed (W) then
         Reserve_Revisions (W, 1);
         W.Revisions.Append
           (Revision'(Parent => W.Base_Id, Content => W.Draft));
         W.Base_Id := Count (W);
      end if;
   end Save;

   procedure New_Drawing (W : in out Workspace; Width, Height : Positive) is
      Blank : constant Drawing_State :=
        (Extent => Document.Full_Extent (Width, Height), others => <>);
   begin
      Reserve_Revisions (W, (if Changed (W) then 2 else 1));
      Save (W);
      W.Revisions.Append (Revision'(Parent => NO_REVISION, Content => Blank));
      W.Draft   := Blank;
      W.Base_Id := Count (W);
      W.Past.Clear;
      W.Future.Clear;
   end New_Drawing;

   procedure Edit (W : in out Workspace; Id : Revision_Id) is
      Chosen : constant Drawing_State := W.Revisions (Id).Content;
   begin
      Save (W);
      W.Draft   := Chosen;
      W.Base_Id := Id;
      W.Past.Clear;
      W.Future.Clear;
   end Edit;

   procedure Remember (W : in out Workspace) is
   begin
      if W.Past.Length = MAX_EDITS then
         raise Capacity_Error with "Canvas draft edit limit reached";
      end if;
      W.Past.Append (W.Draft);
      W.Future.Clear;
   end Remember;

   procedure Add_Stroke (W : in out Workspace; Points : Samples.Vector) is
   begin
      if W.Base_Id = NO_REVISION then
         raise Constraint_Error with "Cannot draw without an Original";
      elsif Points.Is_Empty then
         return;
      elsif W.Strokes.Length = MAX_STROKES
        or else Points.Length >
          Ada.Containers.Count_Type (MAX_POINTS - W.Points)
      then
         raise Capacity_Error with "Canvas ink limit reached";
      end if;

      Collect :
      declare
         Stored : Samples.Vector;
      begin
         Stored.Reserve_Capacity (Points.Length);
         for Point of Points loop
            if not
              (Point.X >= 0.0 and then Point.Y >= 0.0
               and then Point.X <=
                 Long_Float (W.Draft.Extent.Right - W.Draft.Extent.Left)
               and then Point.Y <=
                 Long_Float (W.Draft.Extent.Bottom - W.Draft.Extent.Top)
               and then Point.Width > 0.0 and then Point.Width <= 64.0)
            then
               raise Constraint_Error with "Invalid Canvas sample";
            end if;
            Stored.Append
              (Sample'
                 (X     => Point.X + Long_Float (W.Draft.Extent.Left),
                  Y     => Point.Y + Long_Float (W.Draft.Extent.Top),
                  Width => Point.Width));
         end loop;
         W.Draft.Ink.Reserve_Capacity (W.Draft.Ink.Length + 1);
         W.Strokes.Reserve_Capacity (W.Strokes.Length + 1);
         Remember (W);
         W.Strokes.Append (Stored);
         W.Draft.Ink.Append (W.Strokes.Last_Index);
         W.Points := W.Points + Natural (Points.Length);
      end Collect;
   end Add_Stroke;

   procedure Crop (W : in out Workspace; Region : Document.Rectangle) is
      Next : constant Document.Rectangle :=
        Document.Source_Extent (W.Draft.Extent, Region);
   begin
      if Next = Document.EMPTY_RECTANGLE then
         raise Constraint_Error with "Crop is empty or outside the Canvas";
      elsif Next /= W.Draft.Extent then
         Remember (W);
         W.Draft.Extent := Next;
      end if;
   end Crop;

   function Can_Undo (W : Workspace) return Boolean is (not W.Past.Is_Empty);
   function Can_Redo (W : Workspace) return Boolean is (not W.Future.Is_Empty);

   procedure Undo (W : in out Workspace) is
   begin
      if Can_Undo (W) then
         W.Future.Append (W.Draft);
         W.Draft := W.Past.Last_Element;
         W.Past.Delete_Last;
      end if;
   end Undo;

   procedure Redo (W : in out Workspace) is
   begin
      if Can_Redo (W) then
         W.Past.Append (W.Draft);
         W.Draft := W.Future.Last_Element;
         W.Future.Delete_Last;
      end if;
   end Redo;

   procedure Visit_Source
     (W       : Workspace; Id : Revision_Id;
      Process : not null access procedure (Points : Samples.Vector))
   is
   begin
      if Id = NO_REVISION then
         for Index of W.Draft.Ink loop
            Process (W.Strokes (Index));
         end loop;
      else
         for Index of W.Revisions (Id).Content.Ink loop
            Process (W.Strokes (Index));
         end loop;
      end if;
   end Visit_Source;
end Coyote_Canvas.Revisions;
