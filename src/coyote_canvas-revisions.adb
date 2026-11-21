with Interfaces.C.Strings;
with Ada.Strings.Fixed;

package body Coyote_Canvas.Revisions is
   use type Interfaces.C.Strings.chars_ptr;
   use type Ada.Containers.Count_Type;
   use type Document.Rectangle;

   function G_UUID_String_Random return Interfaces.C.Strings.chars_ptr
     with Import, Convention => C, External_Name => "g_uuid_string_random";
   procedure G_Free (Pointer : Interfaces.C.Strings.chars_ptr)
     with Import, Convention => C, External_Name => "g_free";

   MAX_EDITS : constant := 256;

   function New_UUID return Stable_Id is
      Pointer : Interfaces.C.Strings.chars_ptr := G_UUID_String_Random;
   begin
      if Pointer = Interfaces.C.Strings.Null_Ptr then
         raise Storage_Error with "UUID generation failed";
      end if;
      declare
         Text : constant String := Interfaces.C.Strings.Value (Pointer);
      begin
         G_Free (Pointer);
         Pointer := Interfaces.C.Strings.Null_Ptr;
         return Stable_Id (Text);
      exception
         when others =>
            if Pointer /= Interfaces.C.Strings.Null_Ptr then
               G_Free (Pointer);
            end if;
            raise;
      end;
   end New_UUID;

   function Unique_UUID (W : Workspace) return Stable_Id is
      Key : Stable_Id;
   begin
      loop
         Key := New_UUID;
         declare
            Found : Boolean := False;
         begin
            for Node of W.Revisions loop
               Found := Found or else Node.Key = Key;
            end loop;
            if not Found then
               return Key;
            end if;
         end;
      end loop;
   end Unique_UUID;

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

   function Revision_Key (W : Workspace; Id : Revision_Id) return Stable_Id is
     (W.Revisions (Id).Key);

   function Drawing_Key (W : Workspace; Id : Revision_Id) return Stable_Id is
      Root : Revision_Id := Id;
   begin
      while W.Revisions (Root).Parent /= NO_REVISION loop
         Root := W.Revisions (Root).Parent;
      end loop;
      return W.Revisions (Root).Key;
   end Drawing_Key;

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

   procedure Add_Originals
     (W : in out Workspace; Sizes : Image_Sizes; First_Id : out Revision_Id)
   is
      Before : constant Natural := Count (W);
   begin
      First_Id := NO_REVISION;
      if Sizes'Length = 0 then
         return;
      elsif Sizes'Length > MAX_REVISIONS - Before then
         raise Capacity_Error with "Canvas revision limit reached";
      end if;
      Reserve_Revisions (W, Sizes'Length);
      for Size of Sizes loop
         W.Revisions.Append
           (Revision'
              (Parent  => NO_REVISION,
               Key     => Unique_UUID (W),
               Content =>
                 (Extent => Document.Full_Extent (Size.Width, Size.Height),
                  Image  => Count (W) + 1,
                  others => <>), others => <>));
      end loop;
      First_Id := Before + 1;
   exception
      when others =>
         if Count (W) > Before then
            W.Revisions.Delete_Last
              (Ada.Containers.Count_Type (Count (W) - Before));
         end if;
         raise;
   end Add_Originals;

   procedure Set_Original_Label (W : in out Workspace; Id : Revision_Id;
                                 Label : String) is
   begin
      if Parent (W, Id) /= NO_REVISION or else Label'Length > 64 then
         raise Constraint_Error;
      end if;
      for Ch of Label loop
         if Ch not in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | ' ' | '_' | '-' | '.' then
            raise Constraint_Error;
         end if;
      end loop;
      W.Revisions (Id).Label := Ada.Strings.Fixed.Head (Label, 64);
   end Set_Original_Label;

   function Original_Label (W : Workspace; Id : Revision_Id) return String is
     (Ada.Strings.Fixed.Trim (W.Revisions (Id).Label, Ada.Strings.Right));

   function Background
     (W : Workspace; Id : Revision_Id := NO_REVISION) return Revision_Id is
     (if Id = NO_REVISION then W.Draft.Image
      else W.Revisions (Id).Content.Image);

   procedure Save (W : in out Workspace) is
   begin
      if Changed (W) then
         Reserve_Revisions (W, 1);
         W.Revisions.Append
           (Revision'
              (Parent => W.Base_Id, Key => Unique_UUID (W),
               Content => W.Draft, others => <>));
         W.Base_Id := Count (W);
      end if;
   end Save;

   procedure New_Drawing (W : in out Workspace; Width, Height : Positive) is
      Blank : constant Drawing_State :=
        (Extent => Document.Full_Extent (Width, Height), others => <>);
      Save_Changed : constant Boolean := Changed (W);
      Before       : constant Natural := Count (W);
      Saved_Key    : Stable_Id := (others => ' ');
      New_Key      : Stable_Id := (others => ' ');
   begin
      Reserve_Revisions (W, (if Save_Changed then 2 else 1));
      if Save_Changed then
         Saved_Key := Unique_UUID (W);
      end if;
      loop
         New_Key := Unique_UUID (W);
         exit when not Save_Changed or else New_Key /= Saved_Key;
      end loop;
      if Save_Changed then
         W.Revisions.Append
           (Revision'(Parent => W.Base_Id, Key => Saved_Key,
                      Content => W.Draft, others => <>));
      end if;
      W.Revisions.Append
        (Revision'(Parent => NO_REVISION, Key => New_Key, Content => Blank,
                    others => <>));
      W.Draft   := Blank;
      W.Base_Id := Count (W);
      W.Past.Clear;
      W.Future.Clear;
   exception
      when others =>
         if Count (W) > Before then
            W.Revisions.Delete_Last
              (Ada.Containers.Count_Type (Count (W) - Before));
         end if;
         raise;
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

   procedure Add_Stroke
     (W : in out Workspace; Points : Samples.Vector;
      Operation : Ink_Operation := Paint) is
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
         W.Strokes.Append (Stroke'(Stored, Operation));
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
      Process : not null access procedure
        (Points : Samples.Vector; Operation : Ink_Operation))
   is
   begin
      if Id = NO_REVISION then
         for Index of W.Draft.Ink loop
            Process (W.Strokes (Index).Points, W.Strokes (Index).Operation);
         end loop;
      else
         for Index of W.Revisions (Id).Content.Ink loop
            Process (W.Strokes (Index).Points, W.Strokes (Index).Operation);
         end loop;
      end if;
   end Visit_Source;
end Coyote_Canvas.Revisions;
