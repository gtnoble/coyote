with Ada.Containers;
with Ada.Containers.Vectors;
with Interfaces;
with Math_Layout;
with Math_Model;
with Math_Painter;

--  No-GTK Cairo image rasterization with independently owned pixels.
package Math_Raster is
   Raster_Error : exception;
   subtype Byte is Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_8;
   package Byte_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Byte);
   type Image is private;
   function Width (Item : Image) return Natural;
   function Height (Item : Image) return Natural;
   function Stride (Item : Image) return Natural;
   function Get_Pixel
     (Item : Image; X, Y : Natural) return Interfaces.Unsigned_32;
   function Row_Data (Item : Image; Y : Natural) return Byte_Vectors.Vector;
   function Render
     (Fonts : Math_Painter.Font_Set;
      Layout : Math_Layout.Box;
      Em_Scale : Long_Float;
      Color : Math_Model.Color_Value) return Image;
   function Render_Tile
     (Fonts : Math_Painter.Font_Set;
      Layout : Math_Layout.Box;
      Em_Scale : Long_Float;
      Color : Math_Model.Color_Value;
      Viewport_X, Viewport_Y, Tile_Width, Tile_Height : Natural)
      return Image;
private
   type Image is record
      Pixel_Width : Natural := 0;
      Pixel_Height : Natural := 0;
      Pixel_Stride : Natural := 0;
      Pixels : Byte_Vectors.Vector;
   end record;
end Math_Raster;
