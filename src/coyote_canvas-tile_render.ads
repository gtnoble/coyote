with Cairo;
with Coyote_Canvas.Composite;
with Coyote_Canvas.Document;
with Coyote_Canvas.Revisions;
with Interfaces.C;

package Coyote_Canvas.Tile_Render is
   --  Read only tiles intersecting Region and compose the selected revision.
   --  Region uses absolute source coordinates and must fit the original
   --  drawing. Result contains the intersection with the revision extent.
   --  Raises Composite.Render_Error for an invalid tile source.
   procedure Render
     (FD : Interfaces.C.int;
      W : Revisions.Workspace;
      Id : Revisions.Revision_Id;
      Region : Document.Rectangle;
      Result : in out Composite.Image;
      Include_Ink : Boolean := True);
   --  Render an aligned window in a reduced level. Region is expressed in
   --  level pixels; its source mapping is Region * Step, including the
   --  final padded sample cell. The caller clips to the revision extent.
   function Display_Level
     (FD, Original_FD : Interfaces.C.int; W : Revisions.Workspace;
      Id : Revisions.Revision_Id; Region : Document.Rectangle;
      Step : Positive; Include_Ink : Boolean) return Cairo.Cairo_Surface;
end Coyote_Canvas.Tile_Render;
