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
