with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Coyote_Image_Decoder;
with Coyote_Image_IO;
with Glib.Main;
with Glib.Object;

package body Coyote_GUI.Canvas_Import_Jobs is
   use Ada.Strings.Unbounded;
   use type Gdk.Pixbuf.Gdk_Pixbuf;
   use type Glib.Main.G_Source_Id;
   use type System.Address;

   subtype Slot_Index is Positive range 1 .. Max_Outstanding;
   type Source_Kind is (Bytes_Source, File_Source);
   type Job_State is (Free, Queued, Running, Complete);

   type Callback_Access is access procedure
     (Token : System.Address;
      Pixels : Gdk.Pixbuf.Gdk_Pixbuf;
      Error : String);
   type Job_Record is record
      State    : Job_State := Free;
      Kind     : Source_Kind := Bytes_Source;
      Data     : Unbounded_String;
      Path     : Unbounded_String;
      Expected : Coyote_Canvas.Rasters.Format :=
        Coyote_Canvas.Rasters.Unknown;
      Token    : System.Address := System.Null_Address;
      Callback : Callback_Access := null;
      Pixels   : Coyote_Image_Decoder.Pixbuf_Handle :=
        Coyote_Image_Decoder.Null_Pixbuf;
      Error    : Unbounded_String;
   end record;
   type Job_Array is array (Slot_Index) of Job_Record;

   protected Queue is
      procedure Add_Bytes
        (Data     : Unbounded_String;
         Expected : Coyote_Canvas.Rasters.Format;
         Token    : System.Address;
         Callback : Completion;
         Index    : out Natural);
      procedure Add_File
        (Path     : String;
         Token    : System.Address;
         Callback : Completion;
         Index    : out Natural);
      procedure Claim (Index : out Natural; Found : out Boolean);
      procedure Restore (Index : Slot_Index);
      procedure Get
        (Index    : Slot_Index;
         Kind     : out Source_Kind;
         Data     : out Unbounded_String;
         Path     : out Unbounded_String;
         Expected : out Coyote_Canvas.Rasters.Format);
      procedure Finish
        (Index  : Slot_Index;
         Pixels : Coyote_Image_Decoder.Pixbuf_Handle;
         Error  : String);
      procedure Next_Complete (Index : out Natural; Found : out Boolean);
      procedure Read_Complete
        (Index    : Slot_Index;
         Token    : out System.Address;
         Callback : out Callback_Access;
         Pixels   : out Coyote_Image_Decoder.Pixbuf_Handle;
         Error    : out Unbounded_String);
      procedure Release (Index : Slot_Index);
      function Count return Natural;
   private
      Items : Job_Array;
   end Queue;

   protected body Queue is
      procedure Add_Bytes
        (Data     : Unbounded_String;
         Expected : Coyote_Canvas.Rasters.Format;
         Token    : System.Address;
         Callback : Completion;
         Index    : out Natural)
      is
      begin
         Index := 0;
         for I in Items'Range loop
            if Items (I).State = Free then
               Items (I) :=
                 (State    => Queued,
                  Kind     => Bytes_Source,
                  Data     => Data,
                  Path     => Null_Unbounded_String,
                  Expected => Expected,
                  Token    => Token,
                  Callback => Callback_Access (Callback),
                  Pixels   => Coyote_Image_Decoder.Null_Pixbuf,
                  Error    => Null_Unbounded_String);
               Index := I;
               return;
            end if;
         end loop;
      end Add_Bytes;

      procedure Add_File
        (Path     : String;
         Token    : System.Address;
         Callback : Completion;
         Index    : out Natural)
      is
      begin
         Index := 0;
         for I in Items'Range loop
            if Items (I).State = Free then
               Items (I) :=
                 (State    => Queued,
                  Kind     => File_Source,
                  Data     => Null_Unbounded_String,
                  Path     => To_Unbounded_String (Path),
                  Expected => Coyote_Canvas.Rasters.Unknown,
                  Token    => Token,
                  Callback => Callback_Access (Callback),
                  Pixels   => Coyote_Image_Decoder.Null_Pixbuf,
                  Error    => Null_Unbounded_String);
               Index := I;
               return;
            end if;
         end loop;
      end Add_File;

      procedure Claim (Index : out Natural; Found : out Boolean) is
      begin
         Index := 0;
         Found := False;
         for I in Items'Range loop
            if Items (I).State = Queued then
               Items (I).State := Running;
               Index := I;
               Found := True;
               return;
            end if;
         end loop;
      end Claim;

      procedure Restore (Index : Slot_Index) is
      begin
         if Items (Index).State = Running then
            Items (Index).State := Queued;
         end if;
      end Restore;

      procedure Get
        (Index    : Slot_Index;
         Kind     : out Source_Kind;
         Data     : out Unbounded_String;
         Path     : out Unbounded_String;
         Expected : out Coyote_Canvas.Rasters.Format)
      is
      begin
         Kind := Items (Index).Kind;
         Data := Items (Index).Data;
         Path := Items (Index).Path;
         Expected := Items (Index).Expected;
      end Get;

      procedure Finish
        (Index  : Slot_Index;
         Pixels : Coyote_Image_Decoder.Pixbuf_Handle;
         Error  : String)
      is
      begin
         Items (Index).Pixels := Pixels;
         Items (Index).Error := To_Unbounded_String (Error);
         Items (Index).Data := Null_Unbounded_String;
         Items (Index).Path := Null_Unbounded_String;
         Items (Index).State := Complete;
      end Finish;

      procedure Next_Complete (Index : out Natural; Found : out Boolean) is
      begin
         Index := 0;
         Found := False;
         for I in Items'Range loop
            if Items (I).State = Complete then
               Items (I).State := Running;
               Index := I;
               Found := True;
               return;
            end if;
         end loop;
      end Next_Complete;

      procedure Read_Complete
        (Index    : Slot_Index;
         Token    : out System.Address;
         Callback : out Callback_Access;
         Pixels   : out Coyote_Image_Decoder.Pixbuf_Handle;
         Error    : out Unbounded_String)
      is
      begin
         Token := Items (Index).Token;
         Callback := Items (Index).Callback;
         Pixels := Items (Index).Pixels;
         Error := Items (Index).Error;
      end Read_Complete;

      procedure Release (Index : Slot_Index) is
      begin
         Items (Index) := (others => <>);
      end Release;

      function Count return Natural is
         Result : Natural := 0;
      begin
         for Item of Items loop
            if Item.State /= Free then
               Result := Result + 1;
            end if;
         end loop;
         return Result;
      end Count;
   end Queue;

   function Pending_Count return Natural is (Queue.Count);

   task Worker is
      entry Start (Job_Index : Slot_Index);
   end Worker;

   Pump_Active : Boolean := False;
   Pump_Source : Glib.Main.G_Source_Id := 0;

   function Pump return Boolean;
   procedure Start_Pump;
   procedure Decode_File
     (Path   : String;
      Pixels : out Coyote_Image_Decoder.Pixbuf_Handle;
      Error  : out Unbounded_String);

   procedure Decode_File
     (Path   : String;
      Pixels : out Coyote_Image_Decoder.Pixbuf_Handle;
      Error  : out Unbounded_String)
   is
      use Coyote_Image_IO;
      Separator : constant Natural := Ada.Strings.Fixed.Index
        (Path, "/", Ada.Strings.Backward);
      Parent_Path : Unbounded_String;
      Leaf : Unbounded_String;
      Root : Descriptor := Invalid_Descriptor;
      File : Descriptor := Invalid_Descriptor;
      Attributes_Result : File_Attributes;
      Buffer : String (1 .. 65_536);
      Contents : Unbounded_String;
      Count_Read : Integer;
      Width : Natural;
      Height : Natural;
      Source_Size : Natural;
   begin
      Pixels := Coyote_Image_Decoder.Null_Pixbuf;
      Error := Null_Unbounded_String;
      if Separator = 0 or else Separator = Path'Last
        or else Separator < Path'First
      then
         Error := To_Unbounded_String ("Image import failed");
         return;
      end if;
      if Separator = Path'First then
         Parent_Path := To_Unbounded_String ("/");
      else
         Parent_Path :=
           To_Unbounded_String (Path (Path'First .. Separator - 1));
      end if;
      Leaf := To_Unbounded_String (Path (Separator + 1 .. Path'Last));
      Open_Root (To_String (Parent_Path), Root);
      if Root = Invalid_Descriptor then
         Error := To_Unbounded_String ("Image import failed");
         return;
      end if;
      Open_File (Root, To_String (Leaf), File);
      if File = Invalid_Descriptor then
         Error := To_Unbounded_String ("Could not open the selected image.");
      else
         Attributes (File, Attributes_Result);
         if not Attributes_Result.Is_Regular then
            Error := To_Unbounded_String ("Select a regular image file.");
         elsif Attributes_Result.Size < 0 or else Attributes_Result.Size >
           Coyote_Canvas.Rasters.MAX_ENCODED_BYTES
         then
            Error := To_Unbounded_String ("Encoded image exceeds 8 MiB.");
         else
            loop
               Count_Read := Read (File, Buffer);
               exit when Count_Read = 0;
               if Count_Read < 0 then
                  Error := To_Unbounded_String ("Could not read the image file.");
                  exit;
               end if;
               Source_Size := Length (Contents);
               if Source_Size + Natural (Count_Read) >
                 Coyote_Canvas.Rasters.MAX_ENCODED_BYTES
               then
                  Error := To_Unbounded_String ("Encoded image exceeds 8 MiB.");
                  exit;
               end if;
               Append (Contents, Buffer (1 .. Count_Read));
            end loop;
            if Length (Error) = 0 then
               Coyote_Canvas.Rasters.Decode
                 (To_String (Contents), Coyote_Canvas.Rasters.Unknown,
                  Pixels, Width, Height, Error);
            end if;
         end if;
      end if;
      Close (File);
      Close (Root);
   exception
      when others =>
         Close (File);
         Close (Root);
         Coyote_Image_Decoder.Release (Pixels);
         Error := To_Unbounded_String ("Image import failed");
   end Decode_File;

   procedure Start_Pump is
   begin
      if not Pump_Active then
         Pump_Source := Glib.Main.Timeout_Add (10, Pump'Access);
         Pump_Active := Pump_Source /= 0;
         if not Pump_Active then
            Pump_Source := 0;
            raise Program_Error;
         end if;
      end if;
   end Start_Pump;

   procedure Submit_Bytes
     (Data     : in out Unbounded_String;
      Expected :        Coyote_Canvas.Rasters.Format;
      Token    :        System.Address;
      Callback :        Completion;
      Accepted :    out Boolean)
   is
      Index : Natural;
   begin
      Accepted := False;
      if Length (Data) > Coyote_Canvas.Rasters.MAX_ENCODED_BYTES then
         return;
      end if;
      Queue.Add_Bytes (Data, Expected, Token, Callback, Index);
      if Index = 0 then
         return;
      end if;
      begin
         Start_Pump;
         Accepted := True;
         Data := Null_Unbounded_String;
      exception
         when others =>
            Queue.Release (Slot_Index (Index));
      end;
   end Submit_Bytes;

   procedure Submit_File
     (Path     : String;
      Token    : System.Address;
      Callback : Completion;
      Accepted : out Boolean)
   is
      Index : Natural;
   begin
      Accepted := False;
      if Path'Length = 0 then
         return;
      end if;
      Queue.Add_File (Path, Token, Callback, Index);
      if Index = 0 then
         return;
      end if;
      begin
         Start_Pump;
         Accepted := True;
      exception
         when others =>
            Queue.Release (Slot_Index (Index));
      end;
   end Submit_File;

   function Pump return Boolean is
      Index : Natural;
      Found : Boolean;
      Token : System.Address;
      Callback : Callback_Access;
      Raw : Coyote_Image_Decoder.Pixbuf_Handle;
      Error : Unbounded_String;
      Image : Gdk.Pixbuf.Gdk_Pixbuf;
   begin
      Queue.Claim (Index, Found);
      if Found then
         select
            Worker.Start (Slot_Index (Index));
         else
            Queue.Restore (Slot_Index (Index));
         end select;
      end if;
      loop
         Queue.Next_Complete (Index, Found);
         exit when not Found;
         Queue.Read_Complete
           (Slot_Index (Index), Token, Callback, Raw, Error);
         begin
            Image := Coyote_Image_Decoder.Adopt (Raw);
         exception
            when others =>
               Image := null;
               Coyote_Image_Decoder.Release (Raw);
               Error := To_Unbounded_String ("Image import failed");
         end;
         begin
            Callback.all (Token, Image, To_String (Error));
         exception
            when others =>
               null;
         end;
         if Image /= null then
            Glib.Object.Unref (Glib.Object.GObject (Image));
         end if;
         Coyote_Image_Decoder.Release (Raw);
         Queue.Release (Slot_Index (Index));
      end loop;
      if Queue.Count = 0 then
         Pump_Active := False;
         Pump_Source := 0;
         return False;
      end if;
      return True;
   exception
      when others =>
         return Queue.Count > 0;
   end Pump;

   task body Worker is
      Index : Slot_Index;
      Kind : Source_Kind;
      Data : Unbounded_String;
      Path : Unbounded_String;
      Expected : Coyote_Canvas.Rasters.Format;
      Raw : Coyote_Image_Decoder.Pixbuf_Handle :=
        Coyote_Image_Decoder.Null_Pixbuf;
      Width : Natural;
      Height : Natural;
      Error : Unbounded_String;
   begin
      loop
         select
            accept Start (Job_Index : Slot_Index) do
               Index := Job_Index;
            end Start;
            begin
               Queue.Get (Index, Kind, Data, Path, Expected);
               Raw := Coyote_Image_Decoder.Null_Pixbuf;
               Error := Null_Unbounded_String;
               if Kind = Bytes_Source then
                  Coyote_Canvas.Rasters.Decode
                    (To_String (Data), Expected, Raw, Width, Height, Error);
               else
                  Decode_File (To_String (Path), Raw, Error);
               end if;
               if not Coyote_Image_Decoder.Is_Null (Raw)
                 and then Length (Error) /= 0
               then
                  Coyote_Image_Decoder.Release (Raw);
               end if;
               Queue.Finish (Index, Raw, To_String (Error));
               Raw := Coyote_Image_Decoder.Null_Pixbuf;
            exception
               when others =>
                  Coyote_Image_Decoder.Release (Raw);
                  Queue.Finish
                    (Index, Coyote_Image_Decoder.Null_Pixbuf,
                     "Image import failed");
            end;
            Data := Null_Unbounded_String;
            Path := Null_Unbounded_String;
            Error := Null_Unbounded_String;
         or
            terminate;
         end select;
      end loop;
   end Worker;

end Coyote_GUI.Canvas_Import_Jobs;
