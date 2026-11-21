with Ada.Containers;
with Ada.Containers.Vectors;
with Interfaces;
with Math_Layout;
with Math_Model;
with Math_Memory_Budget;
with Math_Painter;
with Math_Work_Control;

--  No-GTK Cairo image rasterization with independently owned pixels.
package Math_Raster is
   Raster_Error : exception;
   subtype Byte is Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_8;
   package Byte_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Byte);
   type Image is private;
   type Raster_Bounds is record
      Width, Height : Positive := 1;
      Origin_X, Origin_Y : Natural := 0;
   end record;
   --  Logical top-left is at Origin_X/Y within the full raster. Bounds
   --  retain leading path/rule/glyph metric overflow without changing the
   --  layout box. Glyph bounds use reference metrics, not exact native ink;
   --  shaped text-run ink and complete font fallback remain unqualified.
   function Measure
     (Layout : Math_Layout.Box; Em_Scale : Long_Float;
      Work : Math_Work_Control.Context_Access := null) return Raster_Bounds;
   --  Width/Height include retained overflow. The baseline in a full image
   --  is Origin_Y + Layout.Ascent * Em_Scale pixels from raster row zero.
   function Origin_X (Item : Image) return Integer;
   function Origin_Y (Item : Image) return Integer;
   function Width (Item : Image) return Natural;
   function Height (Item : Image) return Natural;
   function Stride (Item : Image) return Natural;
   --  Free owned pixel storage and reset dimensions/origins. Idempotent.
   procedure Clear (Item : in out Image);
   function Get_Pixel
     (Item : Image; X, Y : Natural) return Interfaces.Unsigned_32;
   function Row_Data (Item : Image; Y : Natural) return Byte_Vectors.Vector;
   --  Work and Memory are borrowed only for this call. Memory must outlive
   --  the call; null uses an independent default workspace ledger. Charges
   --  cover overlapping Cairo image bytes and output vector capacity only,
   --  and end at call completion. Returned images/copies, allocator overhead,
   --  Cairo drawing/font internals and parser/layout data are not covered.
   --  Empty-vector preadmission uses GNAT's requested-capacity allocation;
   --  actual capacity is reconciled afterward, not an allocator/RSS bound.
   --  Budget_Exceeded propagates on ledger rejection. Polling does not
   --  preempt native calls or vector allocation.
   --  Render_Into clears previous output first and leaves it empty on failure;
   --  use it to avoid the function return/assignment copy in worker callers.
   procedure Render_Into
     (Fonts : Math_Painter.Font_Set;
      Layout : Math_Layout.Box;
      Em_Scale : Long_Float;
      Color : Math_Model.Color_Value;
      Result : in out Image;
      Work : Math_Work_Control.Context_Access := null;
      Memory : Math_Memory_Budget.Budget_Access := null);
   function Render
     (Fonts : Math_Painter.Font_Set;
      Layout : Math_Layout.Box;
      Em_Scale : Long_Float;
      Color : Math_Model.Color_Value;
      Work : Math_Work_Control.Context_Access := null;
      Memory : Math_Memory_Budget.Budget_Access := null) return Image;
   --  Tile coordinates index the padded full raster, not the logical box.
   --  Tile Origin_X/Y locate logical top-left relative to tile pixel zero
   --  and can be negative. Whole-tile pixels match the corresponding full
   --  raster pixels; all four overflow sides use the same translation.
   function Render_Tile
     (Fonts : Math_Painter.Font_Set;
      Layout : Math_Layout.Box;
      Em_Scale : Long_Float;
      Color : Math_Model.Color_Value;
      Viewport_X, Viewport_Y, Tile_Width, Tile_Height : Natural;
      Work : Math_Work_Control.Context_Access := null;
      Memory : Math_Memory_Budget.Budget_Access := null) return Image;
private
   type Image is record
      Pixel_Width : Natural := 0;
      Pixel_Height : Natural := 0;
      Pixel_Stride : Natural := 0;
      Logical_X, Logical_Y : Integer := 0;
      Pixels : Byte_Vectors.Vector;
   end record;
end Math_Raster;
