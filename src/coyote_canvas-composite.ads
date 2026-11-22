with Ada.Finalization;
with Ada.Streams;
with Ada.Strings.Unbounded;
with Cairo;
with Coyote_Canvas.Revisions;

--  Native-size straight-alpha RGBA, independent of display transforms.
package Coyote_Canvas.Composite is
   type Image is limited private;
   MAX_PNG_BYTES : constant := 8 * 1_024 * 1_024;
   Render_Error, PNG_Error, PNG_Limit_Error : exception;

   --  An empty or mismatched source/extent raises Images.Invalid_Buffer.
   --  Id = NO_REVISION denotes the working copy. Failure leaves Result
   --  unchanged. The workspace and source must be stable for the call.
   procedure Render
     (W : Revisions.Workspace; Id : Revisions.Revision_Id;
      Result : in out Image; Include_Ink : Boolean := True);

   --  Source is the full immutable Original in RGB or RGBA row order, with
   --  arbitrary array bounds and optional padding (not on the last row).
   procedure Render
     (W : Revisions.Workspace; Id : Revisions.Revision_Id;
      Source : Ada.Streams.Stream_Element_Array; Source_Stride : Positive;
      Has_Alpha : Boolean; Result : in out Image;
      Include_Ink : Boolean := True);

   procedure Clear (I : in out Image);
   function Width (I : Image) return Natural;
   function Height (I : Image) return Natural;
   function Pixels (I : Image) return Ada.Streams.Stream_Element_Array;

   --  Returns a new, owned premultiplied surface for display only.
   function Display_Surface (I : Image) return Cairo.Cairo_Surface;

   --  The byte limit is enforced during compression, without a partial
   --  result; a caller may supply a stricter cap, never a larger one.
   function Encode_PNG (I : Image; Limit : Positive := MAX_PNG_BYTES)
      return Ada.Strings.Unbounded.Unbounded_String;

   --  A preview uses one unchanged revision or working copy and its
   --  original background. Append points in displayed-local coordinates.
   --  Clear when the displayed content changes or the gesture ends.
   --  Source bytes are borrowed only for each call, never retained.
   type Erase_Preview is limited private;
   procedure Clear (P : in out Erase_Preview);
   procedure Update_Erase
     (P : in out Erase_Preview; W : Revisions.Workspace;
      Id : Revisions.Revision_Id; Points : Revisions.Samples.Vector);
   procedure Update_Erase
     (P : in out Erase_Preview; W : Revisions.Workspace;
      Id : Revisions.Revision_Id; Points : Revisions.Samples.Vector;
      Source : Ada.Streams.Stream_Element_Array;
      Source_Stride : Positive; Has_Alpha : Boolean);
   --  The returned surface is borrowed and remains owned by P.
   function Surface (P : Erase_Preview) return Cairo.Cairo_Surface;

private
   type Pixel_Buffer is access Ada.Streams.Stream_Element_Array;
   type Image is new Ada.Finalization.Limited_Controlled with record
      Data : Pixel_Buffer;
      W, H : Natural := 0;
   end record;
   overriding procedure Finalize (I : in out Image);

   type Erase_Preview is
     new Ada.Finalization.Limited_Controlled with record
      Ink_Layer  : Cairo.Cairo_Surface := Cairo.Null_Surface;
      Display    : Cairo.Cairo_Surface := Cairo.Null_Surface;
      Context    : Cairo.Cairo_Context := Cairo.Null_Context;
      Drawing_Id : Revisions.Revision_Id := Revisions.NO_REVISION;
      Left, Top  : Natural := 0;
      Width, Height : Natural := 0;
      Source_Stride, Channels : Positive := 1;
      Point_Count : Natural := 0;
      Previous : Revisions.Sample := (0.0, 0.0, 1.0, 1.0);
      Ready : Boolean := False;
   end record;
   overriding procedure Finalize (P : in out Erase_Preview);
end Coyote_Canvas.Composite;
