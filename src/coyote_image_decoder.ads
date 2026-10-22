--  Coyote_Image_Decoder — typed interface to the GdkPixbuf loader.
with Gdk.Pixbuf;
with Interfaces.C;
with System;

package Coyote_Image_Decoder is
   type Loader_Handle is private;
   type Format_Handle is private;
   type Pixbuf_Handle is private;
   type Decode_State is record
      Invalid   : Boolean  := False;
      Max_Width : Positive := 640;
   end record;
   type State_Access is access all Decode_State;
   type Size_Callback is
     access procedure
       (Loader : Loader_Handle;
        Width  : Interfaces.C.int;
        Height : Interfaces.C.int;
        State  : State_Access);
   pragma Convention (C, Size_Callback);

   function Null_Loader return Loader_Handle;
   function New_Loader return Loader_Handle;
   function Is_Null (Loader : Loader_Handle) return Boolean;
   procedure Connect_Size_Prepared
     (Loader : Loader_Handle; Callback : Size_Callback; State : State_Access);
   procedure Set_Size
     (Loader : Loader_Handle;
      Width  : Interfaces.C.int;
      Height : Interfaces.C.int);
   function Write (Loader : Loader_Handle; Data : String) return String;
   function Close (Loader : Loader_Handle) return String;
   function Get_Format (Loader : Loader_Handle) return Format_Handle;
   function Format_Name (Format : Format_Handle) return String;
   function Null_Pixbuf return Pixbuf_Handle;
   function Is_Null (Pixbuf : Pixbuf_Handle) return Boolean;
   function Get_Raw_Pixbuf (Loader : Loader_Handle) return Pixbuf_Handle;
   --  Adopt transfers the owned raw reference into a GtkAda wrapper.
   --  Call only from the GTK main thread.
   function Adopt (Pixbuf : in out Pixbuf_Handle) return Gdk.Pixbuf.Gdk_Pixbuf;
   --  Release drops the owned raw reference and is safe from any task.
   procedure Release (Pixbuf : in out Pixbuf_Handle);
   procedure Free (Loader : in out Loader_Handle);

private
   type Loader_Handle is new System.Address;
   type Format_Handle is new System.Address;
   type Pixbuf_Handle is new System.Address;
end Coyote_Image_Decoder;
