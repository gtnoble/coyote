with Ada.Unchecked_Deallocation;
with Cairo.Image_Surface;
with Cairo.Surface;
with Coyote_Canvas.Document;
with Coyote_Canvas.Images;
with Coyote_Canvas.Ink;
with Coyote_Canvas.Rasters;
with Glib;
with Interfaces.C;
with System;

package body Coyote_Canvas.Composite is
   use Ada.Streams;
   use Interfaces.C;
   use type Cairo.Cairo_Context;
   use type Cairo.Cairo_Status;
   use type Cairo.Cairo_Surface;
   use type System.Address;
   use Coyote_Canvas.Images;

   procedure Free is new Ada.Unchecked_Deallocation
     (Stream_Element_Array, Pixel_Buffer);
   procedure Free_Native (Data : System.Address)
     with Import, Convention => C, External_Name => "free";

   procedure Compose_RGBA
     (Output, Background : System.Address; Stride, Channels : int;
      Left, Top, Width, Height : int; Mask : Cairo.Cairo_Surface;
      Color : int)
     with Import, Convention => C,
          External_Name => "coyote_canvas_compose_rgba";

   function New_Surface
     (Data : System.Address; Width, Height : int) return Cairo.Cairo_Surface
     with Import, Convention => C,
          External_Name => "coyote_canvas_rgba_surface";

   function Write_PNG
     (Pixels : System.Address; Width, Height : int; Limit : size_t;
      Data : out System.Address; Length : out size_t) return int
     with Import, Convention => C,
          External_Name => "coyote_canvas_encode_png";

   procedure Clear (I : in out Image) is
   begin
      Free (I.Data);
      I.W := 0;
      I.H := 0;
   end Clear;

   overriding procedure Finalize (I : in out Image) is
   begin
      Clear (I);
   end Finalize;

   function Width (I : Image) return Natural is (I.W);
   function Height (I : Image) return Natural is (I.H);
   function Pixels (I : Image) return Stream_Element_Array is
     (if I.Data = null then (1 .. 0 => 0) else I.Data.all);

   procedure Preview_Region
     (Display_Data, Source_Data, Mask_Data : System.Address;
      Display_Stride, Source_Stride, Channels, Mask_Stride : int;
      Source_Left, Source_Top, Display_Left, Display_Top : int;
      Width, Height : int; Color : int)
     with Import, Convention => C,
       External_Name => "coyote_canvas_preview_region";

   procedure Clear (P : in out Erase_Preview) is
   begin
      if P.Context /= Cairo.Null_Context then
         Cairo.Destroy (P.Context);
         P.Context := Cairo.Null_Context;
      end if;
      if P.Mask /= Cairo.Null_Surface then
         Cairo.Surface_Destroy (P.Mask);
         P.Mask := Cairo.Null_Surface;
      end if;
      if P.Display /= Cairo.Null_Surface then
         Cairo.Surface_Destroy (P.Display);
         P.Display := Cairo.Null_Surface;
      end if;
      P.Drawing_Id := Revisions.NO_REVISION;
      P.Left := 0;
      P.Top := 0;
      P.Width := 0;
      P.Height := 0;
      P.Source_Stride := 1;
      P.Channels := 1;
      P.Point_Count := 0;
      P.Ready := False;
   end Clear;

   overriding procedure Finalize (P : in out Erase_Preview) is
   begin
      Clear (P);
   end Finalize;

   procedure Render_Internal
     (W : Revisions.Workspace; Id : Revisions.Revision_Id;
      Source : System.Address; Source_Length : Stream_Element_Count;
      Stride, Channels : Positive; Result : in out Image;
      Include_Ink : Boolean)
   is
      R, Original : Document.Rectangle;
      Source_W, Source_H : Positive;
      Out_W, Out_H : Positive;
      Mask : Cairo.Cairo_Surface := Cairo.Null_Surface;
      Context : Cairo.Cairo_Context := Cairo.Null_Context;
      Buffer : Pixel_Buffer;

      procedure Draw
        (Points : Revisions.Samples.Vector; Operation : Revisions.Ink_Operation)
      is
         use type Revisions.Ink_Operation;
      begin
         if Context = Cairo.Null_Context and then Operation = Revisions.Erase then
            return;
         end if;
         if Context = Cairo.Null_Context then
            Mask := Cairo.Image_Surface.Create
              (Cairo.Image_Surface.Cairo_Format_A8,
               Glib.Gint (Source_W), Glib.Gint (Source_H));
            if Cairo.Surface.Status (Mask) /= Cairo.Cairo_Status_Success
            then
               raise Render_Error with "Cannot allocate Canvas ink mask";
            end if;
            Context := Cairo.Create (Mask);
            Cairo.Set_Source_Rgb (Context, 1.0, 1.0, 1.0);
         end if;
         Cairo.Set_Operator
           (Context, (if Operation = Revisions.Erase
                      then Cairo.Cairo_Operator_Dest_Out
                      else Cairo.Cairo_Operator_Over));
         Ink.Draw (Points, Context);
      end Draw;
   begin
      if Id > Revisions.Count (W) then
         raise Invalid_Buffer with "Canvas revision is unavailable";
      end if;
      R := Revisions.Extent (W, Id);
      if not Document.Is_Nonempty (R) then
         raise Invalid_Buffer with "Canvas has no drawing to compose";
      end if;
      declare
         Background : constant Revisions.Revision_Id :=
           Revisions.Background (W, Id);
      begin
         if (Background = Revisions.NO_REVISION) /=
           (Source = System.Null_Address)
         then
            raise Invalid_Buffer with "Canvas background kind mismatch";
         end if;
         if Background /= Revisions.NO_REVISION then
            Original := Revisions.Extent (W, Background);
         else
            --  A blank has no source bytes. Reproduce the root grid by
            --  walking the selected revision (or draft base) to its root.
            declare
               Root : Revisions.Revision_Id :=
                 (if Id = Revisions.NO_REVISION then Revisions.Base (W)
                  else Id);
            begin
               while Revisions.Parent (W, Root) /= Revisions.NO_REVISION loop
                  Root := Revisions.Parent (W, Root);
               end loop;
               Original := Revisions.Extent (W, Root);
            end;
         end if;
      end;
      Source_W := Original.Right;
      Source_H := Original.Bottom;
      if not Document.Is_Within (R, Original)
        or else Source_W > Rasters.MAX_SIDE
        or else Source_H > Rasters.MAX_SIDE
        or else Source_H > Rasters.MAX_PIXELS / Source_W
      then
         raise Invalid_Buffer with "Canvas composition exceeds image bounds";
      end if;
      if Source /= System.Null_Address then
         declare
            Row : constant Positive := Source_W * Channels;
         begin
            if Stride < Row
              or else Source_Length <
                Stream_Element_Count (Source_H - 1) *
                  Stream_Element_Count (Stride) + Stream_Element_Count (Row)
            then
               raise Invalid_Buffer with "Invalid Canvas background layout";
            end if;
         end;
      end if;
      Out_W := R.Right - R.Left;
      Out_H := R.Bottom - R.Top;
      if Include_Ink then
         Revisions.Visit_Source (W, Id, Draw'Access);
         if Context /= Cairo.Null_Context then
            if Cairo.Status (Context) /= Cairo.Cairo_Status_Success then
               raise Render_Error with "Cannot rasterize Canvas ink";
            end if;
            Cairo.Destroy (Context);
            Context := Cairo.Null_Context;
         end if;
      end if;
      Buffer := new Stream_Element_Array
        (1 .. Stream_Element_Offset (Packed_Byte_Count (Out_W, Out_H)));
      Compose_RGBA
        (Buffer (1)'Address, Source, int (Stride), int (Channels),
         int (R.Left), int (R.Top), int (Out_W), int (Out_H), Mask, Ink.RGB);
      if Mask /= Cairo.Null_Surface then
         Cairo.Surface_Destroy (Mask);
         Mask := Cairo.Null_Surface;
      end if;
      Clear (Result);
      Result.Data := Buffer;
      Result.W := Out_W;
      Result.H := Out_H;
   exception
      when others =>
         if Context /= Cairo.Null_Context then
            Cairo.Destroy (Context);
         end if;
         if Mask /= Cairo.Null_Surface then
            Cairo.Surface_Destroy (Mask);
         end if;
         Free (Buffer);
         raise;
   end Render_Internal;

   procedure Render
     (W : Revisions.Workspace; Id : Revisions.Revision_Id;
      Result : in out Image; Include_Ink : Boolean := True) is
   begin
      Render_Internal
        (W, Id, System.Null_Address, 0, 1, 4, Result, Include_Ink);
   end Render;

   procedure Render
     (W : Revisions.Workspace; Id : Revisions.Revision_Id;
      Source : Stream_Element_Array; Source_Stride : Positive;
      Has_Alpha : Boolean; Result : in out Image;
      Include_Ink : Boolean := True) is
   begin
      if Source'Length = 0 then
         raise Invalid_Buffer with "Canvas source buffer is empty";
      end if;
      Render_Internal
        (W, Id, Source (Source'First)'Address, Source'Length, Source_Stride,
         (if Has_Alpha then 4 else 3), Result, Include_Ink);
   end Render;

   procedure Update_Preview
     (P : in out Erase_Preview; W : Revisions.Workspace;
      Id : Revisions.Revision_Id; Points : Revisions.Samples.Vector;
      Source : System.Address; Source_Length : Stream_Element_Count;
      Source_Stride, Channels : Positive)
   is
      R : Document.Rectangle;
      Initializing : Boolean := False;
      Dirty_Left, Dirty_Top, Dirty_Right, Dirty_Bottom : Natural;
      Start_Index : Natural;
      Previous : Revisions.Sample;
      Source_W, Source_H : Positive;
      Out_W, Out_H : Natural;

      procedure Replay
        (Ink_Points : Revisions.Samples.Vector;
         Operation : Revisions.Ink_Operation)
      is
         use type Revisions.Ink_Operation;
      begin
         Cairo.Set_Operator
           (P.Context, (if Operation = Revisions.Erase
                  then Cairo.Cairo_Operator_Dest_Out
                  else Cairo.Cairo_Operator_Over));
         Ink.Draw (Ink_Points, P.Context);
      end Replay;

      procedure Include_Bounds
        (First, Last : Revisions.Sample; Is_Dot : Boolean)
      is
         Radius : constant Long_Float :=
           (if Is_Dot then First.Width / 2.0
            else Long_Float'Max (First.Width, Last.Width) / 2.0) + 1.0;
         Min_X : constant Long_Float :=
           (if Is_Dot then First.X else Long_Float'Min (First.X, Last.X));
         Min_Y : constant Long_Float :=
           (if Is_Dot then First.Y else Long_Float'Min (First.Y, Last.Y));
         Max_X : constant Long_Float :=
           (if Is_Dot then First.X else Long_Float'Max (First.X, Last.X));
         Max_Y : constant Long_Float :=
           (if Is_Dot then First.Y else Long_Float'Max (First.Y, Last.Y));
         Left_Edge : constant Natural := Natural (Long_Float'Min
           (Long_Float (Out_W), Long_Float'Max
             (0.0, Long_Float'Floor
               (Min_X - Long_Float (R.Left) - Radius))));
         Top_Edge : constant Natural := Natural (Long_Float'Min
           (Long_Float (Out_H), Long_Float'Max
             (0.0, Long_Float'Floor
               (Min_Y - Long_Float (R.Top) - Radius))));
         Right_Edge : constant Natural := Natural (Long_Float'Min
           (Long_Float (Out_W), Long_Float'Max
             (0.0, Long_Float'Ceiling
               (Max_X - Long_Float (R.Left) + Radius) + 1.0)));
         Bottom_Edge : constant Natural := Natural (Long_Float'Min
           (Long_Float (Out_H), Long_Float'Max
             (0.0, Long_Float'Ceiling
               (Max_Y - Long_Float (R.Top) + Radius) + 1.0)));
      begin
         Dirty_Left := Natural'Min (Dirty_Left, Left_Edge);
         Dirty_Top := Natural'Min (Dirty_Top, Top_Edge);
         Dirty_Right := Natural'Max (Dirty_Right, Right_Edge);
         Dirty_Bottom := Natural'Max (Dirty_Bottom, Bottom_Edge);
      end Include_Bounds;

      procedure Compose_Region
        (Left, Top, Width, Height : Natural) is
      begin
         Cairo.Surface.Flush (P.Display);
         Cairo.Surface.Flush (P.Mask);
         Preview_Region
           (Cairo.Image_Surface.Get_Data_Generic (P.Display), Source,
            Cairo.Image_Surface.Get_Data_Generic (P.Mask),
            int (Cairo.Image_Surface.Get_Stride (P.Display)),
            int (P.Source_Stride), int (P.Channels),
            int (Cairo.Image_Surface.Get_Stride (P.Mask)),
            int (P.Left + Left), int (P.Top + Top), int (Left), int (Top),
            int (Width), int (Height), Ink.RGB);
         Cairo.Surface.Mark_Dirty_Rectangle
           (P.Display, Glib.Gint (Left), Glib.Gint (Top),
            Glib.Gint (Width), Glib.Gint (Height));
      end Compose_Region;
   begin
      if Id > Revisions.Count (W) then
         raise Invalid_Buffer with "Canvas revision is unavailable";
      end if;
      if Points.Is_Empty then
         return;
      end if;
      R := Revisions.Extent (W, Id);
      if not Document.Is_Nonempty (R) then
         raise Invalid_Buffer with "Canvas has no drawing to compose";
      end if;
      Out_W := R.Right - R.Left;
      Out_H := R.Bottom - R.Top;
      if Source /= System.Null_Address and then Source_Length <
        Stream_Element_Count (R.Bottom - 1) *
          Stream_Element_Count (Source_Stride) +
          Stream_Element_Count (R.Right * Channels)
      then
         raise Invalid_Buffer with "Invalid Canvas preview source length";
      end if;
      if P.Ready and then
        (P.Drawing_Id /= Id or else P.Left /= R.Left or else
         P.Top /= R.Top or else P.Width /= Out_W or else
         P.Height /= Out_H or else P.Source_Stride /= Source_Stride or else
         P.Channels /= Channels or else
         (Source = System.Null_Address and then
          Revisions.Background (W, Id) /= Revisions.NO_REVISION))
      then
         Clear (P);
      end if;
      if P.Ready and then Natural (Points.Length) = P.Point_Count then
         return;
      end if;
      if Natural (Points.Length) < P.Point_Count then
         Clear (P);
      end if;
      Initializing := not P.Ready;
      if Initializing then
         Check_Source : declare
            Background : constant Revisions.Revision_Id :=
              Revisions.Background (W, Id);
            Original : Document.Rectangle;
            Source_Count : constant Natural :=
              (if Channels = 4 then 4 else 3);
            Row_Bytes : Positive;
         begin
            if Background /= Revisions.NO_REVISION then
               Original := Revisions.Extent (W, Background);
            else
               declare
                  Root : Revisions.Revision_Id :=
                    (if Id = Revisions.NO_REVISION then Revisions.Base (W)
                     else Id);
               begin
                  while Revisions.Parent (W, Root) /=
                    Revisions.NO_REVISION
                  loop
                     Root := Revisions.Parent (W, Root);
                  end loop;
                  Original := Revisions.Extent (W, Root);
               end;
            end if;
            Source_W := Original.Right;
            Source_H := Original.Bottom;
            if not Document.Is_Within (R, Original)
              or else Source_W > Rasters.MAX_SIDE
              or else Source_H > Rasters.MAX_SIDE
              or else Source_H > Rasters.MAX_PIXELS / Source_W
            then
               raise Invalid_Buffer with "Canvas preview exceeds image bounds";
            end if;
            Row_Bytes := Source_W * Source_Count;
            if Source = System.Null_Address then
               if Background /= Revisions.NO_REVISION then
                  raise Invalid_Buffer with "Canvas background kind mismatch";
               end if;
            elsif Source_Stride < Row_Bytes or else Source_Length <
              Stream_Element_Count (Source_H - 1) *
                Stream_Element_Count (Source_Stride) +
                Stream_Element_Count (Row_Bytes)
            then
               raise Invalid_Buffer with "Invalid Canvas background layout";
            end if;
         end Check_Source;
         P.Drawing_Id := Id;
         P.Left := R.Left;
         P.Top := R.Top;
         P.Width := Out_W;
         P.Height := Out_H;
         P.Source_Stride := Source_Stride;
         P.Channels := Channels;
         --  Keep canonical source-space clipping and antialiasing even
         --  when the displayed rectangle is a crop of the original.
         P.Mask := Cairo.Image_Surface.Create
           (Cairo.Image_Surface.Cairo_Format_A8,
            Glib.Gint (Source_W), Glib.Gint (Source_H));
         P.Display := Cairo.Image_Surface.Create
           (Cairo.Image_Surface.Cairo_Format_ARGB32,
            Glib.Gint (Out_W), Glib.Gint (Out_H));
         if Cairo.Surface.Status (P.Mask) /= Cairo.Cairo_Status_Success or
           else Cairo.Surface.Status (P.Display) /= Cairo.Cairo_Status_Success
         then
            raise Render_Error with "Cannot allocate erase preview surfaces";
         end if;
         P.Context := Cairo.Create (P.Mask);
         if Cairo.Status (P.Context) /= Cairo.Cairo_Status_Success then
            raise Render_Error with "Cannot create erase preview context";
         end if;
         Cairo.Set_Source_Rgb (P.Context, 1.0, 1.0, 1.0);
         Revisions.Visit_Source (W, Id, Replay'Access);
         if Cairo.Status (P.Context) /= Cairo.Cairo_Status_Success then
            raise Render_Error with "Cannot rasterize preview ink";
         end if;
         P.Ready := True;
      end if;

      Cairo.Set_Source_Rgb (P.Context, 1.0, 1.0, 1.0);
      Cairo.Set_Line_Cap (P.Context, Cairo.Cairo_Line_Cap_Round);
      Cairo.Set_Operator (P.Context, Cairo.Cairo_Operator_Dest_Out);
      Start_Index := P.Point_Count + 1;
      Previous := (if P.Point_Count = 0 then (0.0, 0.0, 1.0)
                   else P.Previous);
      Dirty_Left := Out_W;
      Dirty_Top := Out_H;
      Dirty_Right := 0;
      Dirty_Bottom := 0;
      for I in Start_Index .. Natural (Points.Length) loop
         declare
            Local_Point : constant Revisions.Sample := Points (I);
            Source_Point : constant Revisions.Sample :=
              (X => Local_Point.X + Long_Float (R.Left),
               Y => Local_Point.Y + Long_Float (R.Top),
               Width => Local_Point.Width);
            Previous_Source : constant Revisions.Sample :=
              (X => Previous.X + Long_Float (R.Left),
               Y => Previous.Y + Long_Float (R.Top),
               Width => Previous.Width);
            Is_Dot : constant Boolean := I = 1;
         begin
            if Is_Dot then
               Ink.Draw_Dot (Source_Point, P.Context);
               Include_Bounds (Source_Point, Source_Point, True);
            else
               Ink.Draw_Segment (Previous_Source, Source_Point, P.Context);
               Include_Bounds (Previous_Source, Source_Point, False);
            end if;
            Previous := Local_Point;
            P.Previous := Local_Point;
         end;
      end loop;
      if Cairo.Status (P.Context) /= Cairo.Cairo_Status_Success then
         raise Render_Error with "Cannot rasterize erase preview";
      end if;
      P.Point_Count := Natural (Points.Length);
      if Initializing then
         Compose_Region (0, 0, Out_W, Out_H);
      elsif Dirty_Left < Dirty_Right and then Dirty_Top < Dirty_Bottom then
         Compose_Region
           (Dirty_Left, Dirty_Top, Dirty_Right - Dirty_Left,
            Dirty_Bottom - Dirty_Top);
      end if;
   exception
      when others =>
         Clear (P);
         raise;
   end Update_Preview;

   function Display_Surface (I : Image) return Cairo.Cairo_Surface is
      Surface : Cairo.Cairo_Surface;
   begin
      if I.Data = null then
         raise Invalid_Buffer with "Canvas composite is empty";
      end if;
      Surface := New_Surface (I.Data (1)'Address, int (I.W), int (I.H));
      if Cairo.Surface.Status (Surface) /= Cairo.Cairo_Status_Success then
         Cairo.Surface_Destroy (Surface);
         raise Render_Error with "Cannot allocate Canvas display surface";
      end if;
      return Surface;
   end Display_Surface;

   procedure Update_Erase
     (P : in out Erase_Preview; W : Revisions.Workspace;
      Id : Revisions.Revision_Id; Points : Revisions.Samples.Vector)
   is
   begin
      Update_Preview
        (P, W, Id, Points, System.Null_Address, 0, 1, 4);
   end Update_Erase;

   procedure Update_Erase
     (P : in out Erase_Preview; W : Revisions.Workspace;
      Id : Revisions.Revision_Id; Points : Revisions.Samples.Vector;
      Source : Stream_Element_Array; Source_Stride : Positive;
      Has_Alpha : Boolean)
   is
   begin
      if Source'Length = 0 then
         raise Invalid_Buffer with "Canvas source buffer is empty";
      end if;
      Update_Preview
        (P, W, Id, Points, Source (Source'First)'Address, Source'Length,
         Source_Stride, (if Has_Alpha then 4 else 3));
   end Update_Erase;

   function Surface (P : Erase_Preview) return Cairo.Cairo_Surface is
   begin
      return P.Display;
   end Surface;

   function Encode_PNG (I : Image; Limit : Positive := MAX_PNG_BYTES)
      return Ada.Strings.Unbounded.Unbounded_String
   is
      Data : System.Address := System.Null_Address;
      Size : size_t;
      Status : int;
      Result : Ada.Strings.Unbounded.Unbounded_String;
   begin
      if I.Data = null then
         raise Invalid_Buffer with "Canvas composite is empty";
      end if;
      Status := Write_PNG
        (I.Data (1)'Address, int (I.W), int (I.H),
         size_t (Positive'Min (MAX_PNG_BYTES, Limit)), Data, Size);
      if Status = 1 then
         raise PNG_Limit_Error with "Canvas PNG exceeds its byte budget";
      elsif Status /= 0 then
         raise PNG_Error with "Cannot encode Canvas PNG";
      end if;
      declare
         Bytes : String (1 .. Natural (Size))
           with Import, Address => Data;
      begin
         Result := Ada.Strings.Unbounded.To_Unbounded_String (Bytes);
      end;
      Free_Native (Data);
      Data := System.Null_Address;
      return Result;
   exception
      when others =>
         Free_Native (Data);
         raise;
   end Encode_PNG;
end Coyote_Canvas.Composite;
