with Ada.Environment_Variables;
with Interfaces.C;
with Interfaces.C.Strings;

package body Coyote_Canvas.Import_Service is
   use Interfaces.C;
   use Interfaces.C.Strings;
   use type System.Address;

   function Native_Start (Runtime : char_array; Path, Cap : out char_array)
      return System.Address
     with Import, Convention => C, External_Name => "coyote_canvas_import_start";
   procedure Native_Stop (S : System.Address)
     with Import, Convention => C, External_Name => "coyote_canvas_import_stop";
   function Native_Pending (S : System.Address) return int
     with Import, Convention => C, External_Name => "coyote_canvas_import_pending";
   function Native_Take (S : System.Address) return System.Address
     with Import, Convention => C, External_Name => "coyote_canvas_import_take";
   procedure Free_Batch (Batch : System.Address)
     with Import, Convention => C, External_Name => "coyote_canvas_import_free";
   function Native_Count (Batch : System.Address) return unsigned
     with Import, Convention => C, External_Name => "coyote_canvas_import_count";
   function Native_File
     (Batch : System.Address; Index : unsigned; Size : out unsigned;
      Label : out chars_ptr) return System.Address
     with Import, Convention => C, External_Name => "coyote_canvas_import_file";
   procedure Native_Finish (S : System.Address; Status : int; Text : char_array)
     with Import, Convention => C, External_Name => "coyote_canvas_import_finish";
   type C_Files is array (Positive range <>) of chars_ptr with Convention => C;
   function Native_Add
     (Path, Token : char_array; Count : unsigned; Files : C_Files;
      Text : out char_array) return int
     with Import, Convention => C, External_Name => "coyote_canvas_import_client";
   function Euid return unsigned
     with Import, Convention => C, External_Name => "geteuid";

   protected body Binding is
      procedure Set (UUID : String; Value : Endpoint) is
      begin
         Id := To_Unbounded_String (UUID);
         Current := Value;
         Ready := True;
      end Set;

      procedure Clear is
      begin
         Id := Null_Unbounded_String;
         Ready := False;
         Current := (others => Null_Unbounded_String);
      end Clear;

      function Get (UUID : String) return Endpoint is
        (if UUID /= "" and then Id = UUID then Current
         else (others => Null_Unbounded_String));
      entry Await (UUID : String; Value : out Endpoint) when Ready is
      begin
         Value := Get (UUID);
      end Await;
   end Binding;

   procedure Start (Service : in out Listener; Target : out Endpoint) is
      use Ada.Environment_Variables;
      UID : constant String := unsigned'Image (Euid);
      Runtime : constant String := Value
        ("XDG_RUNTIME_DIR", "/run/user/" & UID (UID'First + 1 .. UID'Last));
      Path : char_array (0 .. 107);
      Cap  : char_array (0 .. 64);
   begin
      Stop (Service);
      Target := (others => Null_Unbounded_String);
      Service.Handle := Native_Start (To_C (Runtime), Path, Cap);
      if Running (Service) then
         Target := (To_Unbounded_String (To_Ada (Path)),
                    To_Unbounded_String (To_Ada (Cap)));
      end if;
   exception
      when others =>
         Stop (Service);
         raise;
   end Start;

   procedure Stop (Service : in out Listener) is
   begin
      Native_Stop (Service.Handle);
      Service.Handle := System.Null_Address;
   end Stop;

   function Running (Service : Listener) return Boolean is
     (Service.Handle /= System.Null_Address);

   function Pending (Service : Listener) return Boolean is
     (Running (Service) and then Native_Pending (Service.Handle) /= 0);

   procedure Take (Service : Listener; Data, Labels : out Text_List;
                   Count : out Natural) is
      Batch : System.Address := System.Null_Address;
   begin
      Count := 0;
      if not Running (Service) then
         return;
      end if;
      Batch := Native_Take (Service.Handle);
      if Batch = System.Null_Address then
         return;
      end if;
      Count := Natural (Native_Count (Batch));
      for I in 1 .. Count loop
         declare
            Size : unsigned;
            Label : chars_ptr;
            Ptr : constant System.Address :=
              Native_File (Batch, unsigned (I - 1), Size, Label);
            Bytes : String (1 .. Natural (Size)) with Import, Address => Ptr;
         begin
            Data (Data'First + I - 1) := To_Unbounded_String (Bytes);
            Labels (Labels'First + I - 1) := To_Unbounded_String (Value (Label));
         end;
      end loop;
      Free_Batch (Batch);
   exception
      when others =>
         Free_Batch (Batch);
         Count := 0;
         Finish (Service, Rejected, "Cannot buffer Canvas import");
   end Take;

   procedure Finish (Service : Listener; Status : Result; Text : String) is
   begin
      if Running (Service) then
         Native_Finish (Service.Handle, Result'Pos (Status), To_C (Text));
      end if;
   end Finish;

   procedure Add (Files : Text_List; Status : out Result;
                  Text : out Unbounded_String) is
      use Ada.Environment_Variables;
      Paths : C_Files (Files'Range) := (others => Null_Ptr);
      Message : char_array (0 .. 2_048);
   begin
      for I in Paths'Range loop
         Paths (I) := New_String (To_String (Files (I)));
      end loop;
      Status := Result'Val
        (Native_Add (To_C (Value (SOCKET_ENV, "")),
                     To_C (Value (TOKEN_ENV, "")), unsigned (Files'Length),
                     Paths, Message));
      for P of Paths loop
         Free (P);
      end loop;
      Text := To_Unbounded_String (To_Ada (Message));
   exception
      when others =>
         for P of Paths loop
            Free (P);
         end loop;
         raise;
   end Add;

   procedure Clear_Inherited is
   begin
      Ada.Environment_Variables.Clear (SOCKET_ENV);
      Ada.Environment_Variables.Clear (TOKEN_ENV);
   end Clear_Inherited;
end Coyote_Canvas.Import_Service;
