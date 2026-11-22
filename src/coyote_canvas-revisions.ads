with Ada.Containers.Vectors;
with Coyote_Canvas.Document;

--  In-memory Canvas revision history and draft editing.
--  Project: coyote
--  Revision identifiers are stable only within one Workspace lifetime.
--
--  New_Drawing checkpoints a dirty draft, then adds a blank Original.
--  Edit checkpoints a dirty draft before opening the selected revision.
--  Save retains draft undo history; switching the edit base resets it.
--  Capacity_Error is raised when a revision or retained-point limit is met;
--  invalid identifiers and invalid crop regions raise Constraint_Error.
--  Allocation failures propagate. No external effects or hidden tasks occur.
--  Retains at most 256 revisions, 512 strokes, 256 undoable edits and
--  100,000 samples until workspace reset.
package Coyote_Canvas.Revisions is
   subtype Revision_Id is Natural;
   NO_REVISION : constant Revision_Id := 0;
   MAX_REVISIONS : constant := 256;
   subtype Stable_Id is String (1 .. 36);

   type Workspace is limited private;

   type Image_Size is record
      Width, Height : Positive;
   end record;
   type Image_Sizes is array (Positive range <>) of Image_Size;

   --  Append all Originals in order, without switching or editing the draft.
   --  First_Id identifies the first consecutive background asset. Capacity
   --  or allocation failure leaves the workspace unchanged.
   procedure Add_Originals
     (W : in out Workspace; Sizes : Image_Sizes; First_Id : out Revision_Id);
   procedure Set_Original_Label (W : in out Workspace; Id : Revision_Id;
                                 Label : String);
   function Original_Label (W : Workspace; Id : Revision_Id) return String;
   function Background
     (W : Workspace; Id : Revision_Id := NO_REVISION) return Revision_Id;
   function Revision_Key (W : Workspace; Id : Revision_Id) return Stable_Id;
   function Drawing_Key (W : Workspace; Id : Revision_Id) return Stable_Id;

   type Sample is record
      X, Y, Width : Long_Float;
   end record;

   package Samples is new Ada.Containers.Vectors (Positive, Sample);

   Capacity_Error : exception;

   procedure Clear (W : in out Workspace);
   function Count (W : Workspace) return Natural;
   function Parent (W : Workspace; Id : Revision_Id) return Revision_Id;
   function Extent
     (W : Workspace; Id : Revision_Id := NO_REVISION)
      return Coyote_Canvas.Document.Rectangle;
   function Base (W : Workspace) return Revision_Id;
   function Changed (W : Workspace) return Boolean;

   procedure New_Drawing (W : in out Workspace; Width, Height : Positive);
   procedure Edit (W : in out Workspace; Id : Revision_Id);
   procedure Save (W : in out Workspace);
   type Ink_Color is range 0 .. 16#FF_FF_FF#;
   DEFAULT_INK_COLOR : constant Ink_Color := 16#0D_0D_0D#;
   type Ink_Operation is (Paint, Erase);
   --  Both operations take draft-local samples; they are retained in source
   --  coordinates and replayed in order. Erase never changes the background.
   procedure Add_Stroke
     (W : in out Workspace; Points : Samples.Vector;
      Operation : Ink_Operation := Paint;
      Color : Ink_Color := DEFAULT_INK_COLOR);
   procedure Crop
     (W : in out Workspace; Region : Coyote_Canvas.Document.Rectangle);
   procedure Undo (W : in out Workspace);
   procedure Redo (W : in out Workspace);

   function Can_Undo (W : Workspace) return Boolean;
   function Can_Redo (W : Workspace) return Boolean;

   --  Replay unmodified source coordinates. The renderer clips to Extent
   --  before translating, preserving segments crossing either crop edge.
   procedure Visit_Source
     (W       : Workspace; Id : Revision_Id;
      Process : not null access procedure
        (Points : Samples.Vector; Operation : Ink_Operation;
         Color : Ink_Color));

private
   MAX_STROKES : constant := 512;
   MAX_POINTS  : constant := 100_000;

   use type Samples.Vector;
   type Stroke is record
      Points : Samples.Vector;
      Operation : Ink_Operation := Paint;
      Color : Ink_Color := DEFAULT_INK_COLOR;
   end record;
   package Stroke_Lists is new Ada.Containers.Vectors (Positive, Stroke);
   package Stroke_Ids is new Ada.Containers.Vectors (Positive, Positive);

   type Drawing_State is record
      Extent : Document.Rectangle := Document.EMPTY_RECTANGLE;
      Image  : Revision_Id := NO_REVISION;
      Ink    : Stroke_Ids.Vector;
   end record;
   package States is new Ada.Containers.Vectors (Positive, Drawing_State);

   type Revision is record
      Parent  : Revision_Id;
      Key     : Stable_Id;
      Content : Drawing_State;
      Label : String (1 .. 64) := (others => ' ');
   end record;
   package Revision_Lists is new Ada.Containers.Vectors (Positive, Revision);

   type Workspace is limited record
      Revisions : Revision_Lists.Vector;
      Strokes   : Stroke_Lists.Vector;
      Points    : Natural     := 0;
      Draft     : Drawing_State;
      Base_Id   : Revision_Id := NO_REVISION;
      Past      : States.Vector;
      Future    : States.Vector;
   end record;
end Coyote_Canvas.Revisions;
