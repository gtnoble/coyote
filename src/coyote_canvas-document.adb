package body Coyote_Canvas.Document is

   function Full_Extent (Width, Height : Positive) return Rectangle is
     (Left => 0, Top => 0, Right => Width, Bottom => Height);

   function Is_Nonempty (Region : Rectangle) return Boolean is
     (Region.Left < Region.Right and then Region.Top < Region.Bottom);

   function Is_Within (Region, Extent : Rectangle) return Boolean is
     (Is_Nonempty (Region)
      and then Region.Left >= Extent.Left and then Region.Top >= Extent.Top
      and then Region.Right <= Extent.Right
      and then Region.Bottom <= Extent.Bottom);

   function From_Fields
     (X, Y, Width, Height      : Integer;
      Image_Width, Image_Height : Positive) return Rectangle
   is
   begin
      if X < 0 or else Y < 0 or else Width <= 0 or else Height <= 0
        or else Width > Image_Width - X or else Height > Image_Height - Y
      then
         return EMPTY_RECTANGLE;
      end if;
      return (Left => X, Top => Y, Right => X + Width, Bottom => Y + Height);
   end From_Fields;

   function Rounded_Edge (Coordinate : Long_Float; Limit : Positive)
      return Natural
   is
   begin
      if not (Coordinate > 0.0) then
         return 0;
      elsif Coordinate >= Long_Float (Limit) then
         return Limit;
      end if;
      return Natural (Coordinate);
   end Rounded_Edge;

   function From_Drag
     (X1, Y1, X2, Y2            : Long_Float;
      Image_Width, Image_Height : Positive) return Rectangle
   is
      AX : constant Natural := Rounded_Edge (X1, Image_Width);
      AY : constant Natural := Rounded_Edge (Y1, Image_Height);
      BX : constant Natural := Rounded_Edge (X2, Image_Width);
      BY : constant Natural := Rounded_Edge (Y2, Image_Height);
   begin
      if AX = BX or else AY = BY then
         return EMPTY_RECTANGLE;
      end if;
      return
        (Left   => Natural'Min (AX, BX),
         Top    => Natural'Min (AY, BY),
         Right  => Natural'Max (AX, BX),
         Bottom => Natural'Max (AY, BY));
   end From_Drag;

   function Move
     (Region                    : Rectangle;
      X, Y                      : Integer;
      Image_Width, Image_Height : Positive) return Rectangle
   is
   begin
      if not Is_Within (Region, Full_Extent (Image_Width, Image_Height)) then
         return EMPTY_RECTANGLE;
      end if;
      Position : declare
         Width  : constant Positive := Region.Right - Region.Left;
         Height : constant Positive := Region.Bottom - Region.Top;
         Left   : constant Natural :=
           Natural'Max (0, Natural'Min (X, Image_Width - Width));
         Top    : constant Natural :=
           Natural'Max (0, Natural'Min (Y, Image_Height - Height));
      begin
         return (Left, Top, Left + Width, Top + Height);
      end Position;
   end Move;

   function Source_Extent
     (Current, Relative : Rectangle) return Rectangle
   is
   begin
      if not Is_Nonempty (Current)
        or else not Is_Within
          (Relative,
           Full_Extent (Current.Right - Current.Left,
                        Current.Bottom - Current.Top))
      then
         return EMPTY_RECTANGLE;
      end if;
      return
        (Left   => Current.Left + Relative.Left,
         Top    => Current.Top + Relative.Top,
         Right  => Current.Left + Relative.Right,
         Bottom => Current.Top + Relative.Bottom);
   end Source_Extent;

end Coyote_Canvas.Document;
