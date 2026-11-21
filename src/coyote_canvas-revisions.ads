with Ada.Containers.Vectors;
with Coyote_Canvas.Document;

--  In-memory blank-canvas revision history and draft editing.
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

   type Workspace is limited private;

   --  Add a read-only Original without switching the draft or its edit log.
   --  The caller owns pixels keyed by Id; descendants share that background.
   procedure Add_Original
     (W : in out Workspace; Width, Height : Positive; Id : out Revision_Id);
   function Background
     (W : Workspace; Id : Revision_Id := NO_REVISION) return Revision_Id;

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
   procedure Add_Stroke (W : in out Workspace; Points : Samples.Vector);
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
      Process : not null access procedure (Points : Samples.Vector));

private
   package Stroke_Lists is new Ada.Containers.Vectors
     (Positive, Samples.Vector, Samples."=");
   package Stroke_Ids is new Ada.Containers.Vectors (Positive, Positive);

   type Drawing_State is record
      Extent : Document.Rectangle := Document.EMPTY_RECTANGLE;
      Image  : Revision_Id := NO_REVISION;
      Ink    : Stroke_Ids.Vector;
   end record;
   package States is new Ada.Containers.Vectors (Positive, Drawing_State);

   type Revision is record
      Parent  : Revision_Id;
      Content : Drawing_State;
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
