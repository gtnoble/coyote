with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Interfaces.C.Strings;
with Glib.Object;
with System;

package body Coyote_Image_Decoder is
   use type Interfaces.C.int;
   use type Interfaces.C.Strings.chars_ptr;
   use type System.Address;

   function Pixbuf_Loader_New return Loader_Handle with
     Import, Convention => C, External_Name => "gdk_pixbuf_loader_new";
   function Pixbuf_Loader_Write
     (Loader : Loader_Handle;
      Data   : System.Address;
      Count  : Interfaces.C.size_t;
      Error  : access System.Address)
      return Interfaces.C.int with
     Import, Convention => C, External_Name => "gdk_pixbuf_loader_write";
   function Pixbuf_Loader_Close
     (Loader : Loader_Handle;
      Error  : access System.Address)
      return Interfaces.C.int with
     Import, Convention => C, External_Name => "gdk_pixbuf_loader_close";
   function Pixbuf_Loader_Get_Pixbuf
     (Loader : Loader_Handle) return System.Address with
     Import, Convention => C, External_Name => "gdk_pixbuf_loader_get_pixbuf";
   function Pixbuf_Loader_Get_Format
     (Loader : Loader_Handle) return Format_Handle with
     Import, Convention => C, External_Name => "gdk_pixbuf_loader_get_format";
   function Pixbuf_Format_Get_Name
     (Format : Format_Handle) return Interfaces.C.Strings.chars_ptr with
     Import, Convention => C, External_Name => "gdk_pixbuf_format_get_name";
   function Object_Ref (Object : System.Address) return System.Address with
     Import, Convention => C, External_Name => "g_object_ref";
   procedure Object_Unref (Object : System.Address) with
     Import, Convention => C, External_Name => "g_object_unref";
   procedure Error_Free (Error : System.Address) with
     Import, Convention => C, External_Name => "g_error_free";
   function Error_Message
     (Error : System.Address) return Interfaces.C.Strings.chars_ptr with
     Import,
     Convention    => C,
     External_Name => "coyote_image_decoder_error_message";
   procedure Connect_Size
     (Loader   : Loader_Handle;
      Callback : Size_Callback;
      State    : State_Access) with
     Import,
     Convention    => C,
     External_Name => "coyote_image_io_connect_size_prepared";
   procedure C_Set_Size
     (Loader : Loader_Handle;
      Width  : Interfaces.C.int;
      Height : Interfaces.C.int) with
     Import, Convention => C, External_Name => "gdk_pixbuf_loader_set_size";

   function Null_Loader return Loader_Handle is
     (Loader_Handle (System.Null_Address));

   function Is_Null (Loader : Loader_Handle) return Boolean is
     (System.Address (Loader) = System.Null_Address);

   function New_Loader return Loader_Handle is (Pixbuf_Loader_New);

   procedure Connect_Size_Prepared
     (Loader : Loader_Handle; Callback : Size_Callback; State : State_Access)
   is
   begin
      Connect_Size (Loader, Callback, State);
   end Connect_Size_Prepared;

   procedure Set_Size
     (Loader : Loader_Handle;
      Width  : Interfaces.C.int;
      Height : Interfaces.C.int)
   is
   begin
      C_Set_Size (Loader, Width, Height);
   end Set_Size;

   function Take_Error (Error : in out System.Address) return String is
      Result : Unbounded_String :=
        To_Unbounded_String ("Image decoding failed");
   begin
      if Error /= System.Null_Address then
         declare
            Message : constant Interfaces.C.Strings.chars_ptr :=
              Error_Message (Error);
         begin
            if Message /= Interfaces.C.Strings.Null_Ptr then
               Result :=
                 To_Unbounded_String (Interfaces.C.Strings.Value (Message));
            end if;
         end;
         Error_Free (Error);
         Error := System.Null_Address;
      end if;
      return To_String (Result);
   end Take_Error;

   function Write (Loader : Loader_Handle; Data : String) return String is
      Error  : aliased System.Address := System.Null_Address;
      Status : Interfaces.C.int;
   begin
      Status :=
        Pixbuf_Loader_Write
          (Loader,
           Data'Address,
           Interfaces.C.size_t (Data'Length),
           Error'Access);
      if Status = 0 then
         return Take_Error (Error);
      elsif Error /= System.Null_Address then
         Error_Free (Error);
      end if;
      return "";
   end Write;

   function Close (Loader : Loader_Handle) return String is
      Error  : aliased System.Address := System.Null_Address;
      Status : Interfaces.C.int;
   begin
      Status := Pixbuf_Loader_Close (Loader, Error'Access);
      if Status = 0 then
         return Take_Error (Error);
      elsif Error /= System.Null_Address then
         Error_Free (Error);
      end if;
      return "";
   end Close;

   function Get_Format (Loader : Loader_Handle) return Format_Handle is
     (Pixbuf_Loader_Get_Format (Loader));

   function Format_Name (Format : Format_Handle) return String is
      Name   : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.Null_Ptr;
      Result : Unbounded_String;
   begin
      if System.Address (Format) /= System.Null_Address then
         Name := Pixbuf_Format_Get_Name (Format);
      end if;
      if Name /= Interfaces.C.Strings.Null_Ptr then
         Result := To_Unbounded_String (Interfaces.C.Strings.Value (Name));
         declare
            procedure G_Free (Pointer : Interfaces.C.Strings.chars_ptr) with
              Import, Convention => C, External_Name => "g_free";
         begin
            G_Free (Name);
         end;
      end if;
      return To_String (Result);
   end Format_Name;

   function Null_Pixbuf return Pixbuf_Handle is
     (Pixbuf_Handle (System.Null_Address));

   function Is_Null (Pixbuf : Pixbuf_Handle) return Boolean is
     (System.Address (Pixbuf) = System.Null_Address);

   function Get_Raw_Pixbuf (Loader : Loader_Handle) return Pixbuf_Handle is
      Raw : constant System.Address := Pixbuf_Loader_Get_Pixbuf (Loader);
   begin
      if Raw = System.Null_Address then
         return Null_Pixbuf;
      end if;
      return Pixbuf_Handle (Object_Ref (Raw));
   end Get_Raw_Pixbuf;

   function Adopt (Pixbuf : in out Pixbuf_Handle) return Gdk.Pixbuf.Gdk_Pixbuf
   is
      Raw    : constant System.Address := System.Address (Pixbuf);
      Stub   : Gdk.Pixbuf.Gdk_Pixbuf_Record;
      Result : Gdk.Pixbuf.Gdk_Pixbuf   := null;
   begin
      if Raw /= System.Null_Address then
         Result :=
           Gdk.Pixbuf.Gdk_Pixbuf (Glib.Object.Get_User_Data (Raw, Stub));
         Pixbuf := Null_Pixbuf;
      end if;
      return Result;
   end Adopt;

   procedure Release (Pixbuf : in out Pixbuf_Handle) is
   begin
      if not Is_Null (Pixbuf) then
         Object_Unref (System.Address (Pixbuf));
         Pixbuf := Null_Pixbuf;
      end if;
   end Release;

   procedure Free (Loader : in out Loader_Handle) is
   begin
      if not Is_Null (Loader) then
         Object_Unref (System.Address (Loader));
         Loader := Null_Loader;
      end if;
   end Free;
end Coyote_Image_Decoder;
