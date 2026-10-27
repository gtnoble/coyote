with Ada.Containers.Vectors;

package Math_Paths is
   Max_Commands : constant := 8_192;
   Max_Draw_Commands : constant := 131_072;
   Max_Input_Bytes : constant := Max_Draw_Commands;
   Max_Coordinate : constant := 1_000_000.0;

   type Point is record
      X : Long_Float := 0.0;
      Y : Long_Float := 0.0;
   end record;

   type Command_Kind is (Move_To, Line_To, Cubic_To, Close_Path);

   type Segment is record
      Kind : Command_Kind := Move_To;
      First : Point;
      Second : Point;
      Third : Point;
   end record;

   type Bounds is record
      Min_X : Long_Float := 0.0;
      Min_Y : Long_Float := 0.0;
      Max_X : Long_Float := 0.0;
      Max_Y : Long_Float := 0.0;
      Valid : Boolean := False;
   end record;

   type Path is private;

   function Parse (Data : String) return Path;
   function Is_Valid (Item : Path) return Boolean;
   function Error (Item : Path) return String;
   function Count (Item : Path) return Natural;
   function Element (Item : Path; Index : Positive) return Segment;
   --  Bounds include Bezier control points and therefore conservatively contain
   --  each curve; they are not the tight mathematical extrema.
   function Extent (Item : Path) return Bounds;
   function Transform
     (Item : Path; XX, YX, XY, YY, DX, DY : Long_Float) return Path;

private
   package Segment_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Segment);
   type Path is record
      Items : Segment_Vectors.Vector;
      Length : Natural := 0;
      Good : Boolean := False;
      Message : String (1 .. 48) := (others => ' ');
   end record;
end Math_Paths;
