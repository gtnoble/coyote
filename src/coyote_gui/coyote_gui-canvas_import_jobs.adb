with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Coyote_Canvas.SVG;
with Coyote_Canvas.Tiles;
with System.Storage_Elements;
with Coyote_Image_Decoder;
with Coyote_Image_IO;
with Glib.Main;
with Glib.Object;
with Interfaces.C;

package body Coyote_GUI.Canvas_Import_Jobs is
   use Ada.Strings.Unbounded;
   use type Gdk.Pixbuf.Gdk_Pixbuf;
   use type Coyote_Canvas.Rasters.Format;
   use type Glib.Main.G_Source_Id;
   use type Interfaces.C.int;
   use type Interfaces.Unsigned_64;
   use type Coyote_Canvas.Tiles.Result;
   use type System.Address;
   use type System.Storage_Elements.Integer_Address;

   subtype Slot_Index is Positive range 1 .. Max_Outstanding;
   subtype File_Index is Positive range 1 .. MAX_FILES;
   type Source_Kind is
     (Bytes_Source, Files_Source, Tiled_Files_Source, Batch_Source);
   type Job_State is (Free, Queued, Running, Complete);
   type Stored_Path_List is array (File_Index) of Unbounded_String;
   type Raw_Pixbuf_List is
     array (File_Index) of Coyote_Image_Decoder.Pixbuf_Handle;

   function Raw_Width (Pixbuf : Coyote_Image_Decoder.Pixbuf_Handle)
      return Interfaces.C.int
     with Import, Convention => C,
       External_Name => "gdk_pixbuf_get_width";
   function Raw_Height (Pixbuf : Coyote_Image_Decoder.Pixbuf_Handle)
      return Interfaces.C.int
     with Import, Convention => C,
       External_Name => "gdk_pixbuf_get_height";
   function Raw_Rowstride (Pixbuf : Coyote_Image_Decoder.Pixbuf_Handle)
      return Interfaces.C.int
     with Import, Convention => C,
       External_Name => "gdk_pixbuf_get_rowstride";

   type Raw_Tile_List is array (File_Index) of Tile_Source;
   type Tiled_Callback_Access is access procedure
     (Token : System.Address; Pixels : Image_List; Tiles : Tile_List;
      Error : String);

   function C_Close (FD : Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C, External_Name => "close";
   function C_Cancel (User : System.Address) return Interfaces.C.int
     with Convention => C;
   procedure Close_FD (FD : in out Interfaces.C.int) is
      Ignore : Interfaces.C.int;
   begin
      if FD >= 0 then
         Ignore := C_Close (FD);
         FD := -1;
      end if;
   end Close_FD;

   type Callback_Access is access procedure
     (Token : System.Address;
      Pixels : Image_List;
      Error : String);
   type Job_Record is record
      State       : Job_State := Free;
      Cancelled   : Boolean := False;
      Kind        : Source_Kind := Bytes_Source;
      Data        : Unbounded_String;
      Paths       : Stored_Path_List := (others => Null_Unbounded_String);
      Path_Count  : Natural := 0;
      Expected    : Coyote_Canvas.Rasters.Format :=
        Coyote_Canvas.Rasters.Unknown;
      Token       : System.Address := System.Null_Address;
      Callback    : Callback_Access := null;
      Tiled_Callback : Tiled_Callback_Access := null;
      Tiles : Raw_Tile_List := (others => (FD => -1, Width => 0, Height => 0));
      Tile_Count : Natural := 0;
      Pixels      : Raw_Pixbuf_List :=
        (others => Coyote_Image_Decoder.Null_Pixbuf);
      Pixel_Count : Natural := 0;
      Error       : Unbounded_String;
   end record;
   type Job_Array is array (Slot_Index) of Job_Record;

   protected Queue is
      procedure Add_Bytes
        (Data     : Unbounded_String;
         Expected : Coyote_Canvas.Rasters.Format;
         Token    : System.Address;
         Callback : Completion;
         Index    : out Natural);
      procedure Add_Files
        (Paths    : Path_List;
         Token    : System.Address;
         Callback : Completion;
         Index    : out Natural);
      procedure Add_Tiled_Files
        (Paths : Path_List; Token : System.Address;
         Callback : On_Tiled_Complete; Index : out Natural);
      procedure Add_Batch
        (Data : Coyote_Canvas.Import_Service.Text_List;
         Token : System.Address; Callback : Completion; Index : out Natural);
      procedure Cancel_Files (Token : System.Address);
      function Cancelled (Index : Slot_Index) return Boolean;
      procedure Claim (Index : out Natural; Found : out Boolean);
      procedure Restore (Index : Slot_Index);
      procedure Get
        (Index    : Slot_Index;
         Kind     : out Source_Kind;
         Data     : out Unbounded_String;
         Paths    : out Stored_Path_List;
         Path_Count : out Natural;
         Expected : out Coyote_Canvas.Rasters.Format);
      procedure Finish
        (Index  : Slot_Index;
         Pixels : Raw_Pixbuf_List;
         Count : Natural; Error : String;
         Tiles : Raw_Tile_List; Tile_Count : Natural);
      procedure Next_Complete (Index : out Natural; Found : out Boolean);
      procedure Take_Complete
        (Index      : Slot_Index;
         Token      : out System.Address;
         Callback   : out Callback_Access;
         Pixels     : out Raw_Pixbuf_List;
         Pixel_Count : out Natural;
         Error : out Unbounded_String;
         Tiled_Callback : out Tiled_Callback_Access;
         Tiles : out Raw_Tile_List; Tile_Count : out Natural);
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
                 (State       => Queued,
                  Kind        => Bytes_Source,
                  Cancelled   => False,
                  Data        => Data,
                  Paths       => (others => Null_Unbounded_String),
                  Path_Count  => 0,
                  Expected    => Expected,
                  Token       => Token,
                  Callback    => Callback_Access (Callback),
                  Tiled_Callback => null,
                  Tiles => (others => (FD => -1, Width => 0, Height => 0)),
                  Tile_Count => 0,
                  Pixels      =>
                    (others => Coyote_Image_Decoder.Null_Pixbuf),
                  Pixel_Count => 0,
                  Error       => Null_Unbounded_String);
               Index := I;
               return;
            end if;
         end loop;
      end Add_Bytes;

      procedure Add_Files
        (Paths    : Path_List;
         Token    : System.Address;
         Callback : Completion;
         Index    : out Natural)
      is
      begin
         Index := 0;
         for I in Items'Range loop
            if Items (I).State = Free then
               Items (I) :=
                 (State       => Queued,
                  Kind        => Files_Source,
                  Cancelled   => False,
                  Data        => Null_Unbounded_String,
                  Paths       => (others => Null_Unbounded_String),
                  Path_Count  => Paths'Length,
                  Expected    => Coyote_Canvas.Rasters.Unknown,
                  Token       => Token,
                  Callback    => Callback_Access (Callback),
                  Tiled_Callback => null,
                  Tiles => (others => (FD => -1, Width => 0, Height => 0)),
                  Tile_Count => 0,
                  Pixels      =>
                    (others => Coyote_Image_Decoder.Null_Pixbuf),
                  Pixel_Count => 0,
                  Error       => Null_Unbounded_String);
               for J in Paths'Range loop
                  Items (I).Paths (J - Paths'First + 1) := Paths (J);
               end loop;
               Index := I;
               return;
            end if;
         end loop;
      end Add_Files;

      procedure Add_Tiled_Files
        (Paths : Path_List; Token : System.Address;
         Callback : On_Tiled_Complete; Index : out Natural)
      is
      begin
         Index := 0;
         for I in Items'Range loop
            if Items (I).State = Free then
               Items (I) :=
                 (State => Queued, Kind => Tiled_Files_Source,
                  Path_Count => Paths'Length, Token => Token,
                  Tiled_Callback => Tiled_Callback_Access (Callback),
                  others => <>);
               for J in Paths'Range loop
                  Items (I).Paths (J - Paths'First + 1) := Paths (J);
               end loop;
               Index := I;
               return;
            end if;
         end loop;
      end Add_Tiled_Files;

      procedure Add_Batch
        (Data : Coyote_Canvas.Import_Service.Text_List;
         Token : System.Address; Callback : Completion; Index : out Natural)
      is
      begin
         Index := 0;
         for I in Items'Range loop
            if Items (I).State = Free then
               Items (I) :=
                 (State => Queued, Kind => Batch_Source,
                  Path_Count => Data'Length, Token => Token,
                  Callback => Callback_Access (Callback), others => <>);
               for J in Data'Range loop
                  Items (I).Paths (J - Data'First + 1) := Data (J);
               end loop;
               Index := I;
               return;
            end if;
         end loop;
      end Add_Batch;

      procedure Cancel_Files (Token : System.Address) is
      begin
         for Item of Items loop
            if Item.State /= Free
              and then (Item.Kind = Files_Source
                        or else Item.Kind = Tiled_Files_Source)
              and then Item.Token = Token
            then
               Item.Cancelled := True;
            end if;
         end loop;
      end Cancel_Files;

      function Cancelled (Index : Slot_Index) return Boolean is
        (Items (Index).Cancelled);

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
        (Index      : Slot_Index;
         Kind       : out Source_Kind;
         Data       : out Unbounded_String;
         Paths      : out Stored_Path_List;
         Path_Count : out Natural;
         Expected   : out Coyote_Canvas.Rasters.Format)
      is
      begin
         Kind := Items (Index).Kind;
         Data := Items (Index).Data;
         Paths := Items (Index).Paths;
         Path_Count := Items (Index).Path_Count;
         Expected := Items (Index).Expected;
      end Get;

      procedure Finish
        (Index  : Slot_Index;
         Pixels : Raw_Pixbuf_List;
         Count : Natural; Error : String;
         Tiles : Raw_Tile_List; Tile_Count : Natural)
      is
      begin
         Items (Index).Pixels := Pixels;
         Items (Index).Pixel_Count := Count;
         Items (Index).Tiles := Tiles;
         Items (Index).Tile_Count := Tile_Count;
         Items (Index).Error := To_Unbounded_String (Error);
         Items (Index).Data := Null_Unbounded_String;
         Items (Index).Paths := (others => Null_Unbounded_String);
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

      procedure Take_Complete
        (Index       : Slot_Index;
         Token       : out System.Address;
         Callback    : out Callback_Access;
         Pixels      : out Raw_Pixbuf_List;
         Pixel_Count : out Natural;
         Error : out Unbounded_String;
         Tiled_Callback : out Tiled_Callback_Access;
         Tiles : out Raw_Tile_List; Tile_Count : out Natural)
      is
      begin
         Token := Items (Index).Token;
         Callback := Items (Index).Callback;
         Tiled_Callback := Items (Index).Tiled_Callback;
         Tiles := Items (Index).Tiles;
         Tile_Count := Items (Index).Tile_Count;
         Items (Index).Tiles :=
           (others => (FD => -1, Width => 0, Height => 0));
         Error := Items (Index).Error;
         Pixel_Count := Items (Index).Pixel_Count;
         Pixels := Items (Index).Pixels;
         Items (Index).Pixels := (others => Coyote_Image_Decoder.Null_Pixbuf);
      end Take_Complete;

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

   function C_Cancel (User : System.Address) return Interfaces.C.int is
      Number : constant System.Storage_Elements.Integer_Address :=
        System.Storage_Elements.To_Integer (User);
   begin
      if Number < System.Storage_Elements.Integer_Address
        (Slot_Index'First)
        or else Number > System.Storage_Elements.Integer_Address
          (Slot_Index'Last)
      then
         return 1;
      end if;
      return
        (if Queue.Cancelled (Slot_Index (Integer (Number))) then 1 else 0);
   end C_Cancel;

   function Pending_Count return Natural is (Queue.Count);

   procedure Cancel_Files (Token : System.Address) is
   begin
      Queue.Cancel_Files (Token);
   end Cancel_Files;

   task Worker is
      entry Start (Job_Index : Slot_Index);
   end Worker;

   Pump_Active : Boolean := False;
   Pump_Source : Glib.Main.G_Source_Id := 0;

   function Pump return Boolean;
   procedure Start_Pump;
   function Pixel_Bytes
     (Pixels : Coyote_Image_Decoder.Pixbuf_Handle) return Natural;
   procedure Release_All (Pixels : in out Raw_Pixbuf_List);

   function Pixel_Bytes
     (Pixels : Coyote_Image_Decoder.Pixbuf_Handle) return Natural
   is
      Width, Height, Rowstride : Interfaces.C.int;
      Total : Long_Long_Integer;
   begin
      if Coyote_Image_Decoder.Is_Null (Pixels) then
         return MAX_BATCH_DECODED_BYTES + 1;
      end if;
      Width := Raw_Width (Pixels);
      Height := Raw_Height (Pixels);
      Rowstride := Raw_Rowstride (Pixels);
      if Width <= 0 or else Height <= 0 or else Rowstride <= 0 then
         return MAX_BATCH_DECODED_BYTES + 1;
      end if;
      Total := Long_Long_Integer (Rowstride) * Long_Long_Integer (Height);
      if Total > Long_Long_Integer (MAX_BATCH_DECODED_BYTES) then
         return MAX_BATCH_DECODED_BYTES + 1;
      end if;
      return Natural (Total);
   end Pixel_Bytes;

   procedure Release_All (Pixels : in out Raw_Pixbuf_List) is
   begin
      for I in Pixels'Range loop
         Coyote_Image_Decoder.Release (Pixels (I));
      end loop;
   end Release_All;

   procedure Decode_File
     (Path      : String;
      Job       : Slot_Index;
      SVG_Total : in out Natural;
      Allow_Tiles : Boolean;
      Staging_Total : in out Interfaces.Unsigned_64;
      Tile : out Tile_Source;
      Pixels    : out Coyote_Image_Decoder.Pixbuf_Handle;
      Error     : out Unbounded_String)
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
      Oversized : Boolean;
      Signature : String (1 .. 8);
      Filled : Natural := 0;
      Stage : Interfaces.C.int := -1;
      TILE_BUDGET : constant := 2 * 1_024 * 1_024 * 1_024;
      SVG_Limit : constant Natural :=
        Natural'Min (Coyote_Canvas.Rasters.MAX_ENCODED_BYTES,
                     MAX_BATCH_ENCODED_BYTES - SVG_Total);

      function Read_Chunk (Data : out String) return Integer is
        (if Queue.Cancelled (Job) then -1 else Read (File, Data));

      function Rewind_File return Boolean is
        (not Queue.Cancelled (Job) and then Rewind (File));
   begin
      Tile := (others => <>);
      Pixels := Coyote_Image_Decoder.Null_Pixbuf;
      Error := Null_Unbounded_String;
      if Queue.Cancelled (Job) then
         Error := To_Unbounded_String ("Image import cancelled.");
         return;
      end if;
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
         Error := To_Unbounded_String ("Could not open the selected image.");
         return;
      end if;
      Open_File (Root, To_String (Leaf), File);
      if File = Invalid_Descriptor then
         Error := To_Unbounded_String ("Could not open the selected image.");
      else
         Attributes (File, Attributes_Result);
         if not Attributes_Result.Is_Regular then
            Error := To_Unbounded_String ("Select a regular image file.");
         else
            while Filled < Signature'Length loop
               Count_Read := Read_Chunk (Signature (Filled + 1 .. 8));
               exit when Count_Read <= 0;
               Filled := Filled + Count_Read;
            end loop;
            if not Rewind_File then
               Error := To_Unbounded_String ("Could not read the image file.");
            elsif Coyote_Canvas.Rasters.Detect (Signature (1 .. Filled)) /=
              Coyote_Canvas.Rasters.Unknown
            then
               Coyote_Canvas.Rasters.Decode_Stream
                 (Read_Chunk'Access, Rewind_File'Access, Pixels,
                  Width, Height, Error, Oversized);
               if Allow_Tiles and then Oversized then
                  Stage := Coyote_Canvas.Tiles.Stage;
                  if Stage < 0 then
                     Error := To_Unbounded_String
                       ("Cannot create temporary tile storage.");
                  else
                     declare
                        Info : Coyote_Canvas.Tiles.Dimensions;
                        Status : Coyote_Canvas.Tiles.Result;
                     begin
                        Coyote_Canvas.Tiles.Import
                          (Borrow (File), Stage, TILE_BUDGET - Staging_Total,
                           Status, Info, C_Cancel'Access,
                           System.Storage_Elements.To_Address
                             (System.Storage_Elements.Integer_Address (Job)));
                        case Status is
                           when Coyote_Canvas.Tiles.Success =>
                              Staging_Total := Staging_Total + 16 + 4 *
                                Interfaces.Unsigned_64 (Info.Width) *
                                Interfaces.Unsigned_64 (Info.Height);
                              Tile := (Stage, Natural (Info.Width),
                                       Natural (Info.Height));
                              Stage := -1;
                              Error := Null_Unbounded_String;
                           when Coyote_Canvas.Tiles.Unsupported =>
                              Error := To_Unbounded_String
                                ("This image encoding cannot be tiled.");
                           when Coyote_Canvas.Tiles.Limit_Exceeded =>
                              Error := To_Unbounded_String
                                ("Tiled import exceeds the 32,768-pixel side " &
                                 "or 2 GiB batch limit.");
                           when Coyote_Canvas.Tiles.Cancelled =>
                              Error := To_Unbounded_String
                                ("Image import cancelled.");
                           when others =>
                              Error := To_Unbounded_String
                                ("Could not decode or stage the tiled image.");
                        end case;
                     end;
                  end if;
               end if;
            elsif Attributes_Result.Size > Long_Long_Integer (SVG_Limit) then
               Error := To_Unbounded_String ("SVG input exceeds the size limit.");
            else
               loop
                  Count_Read := Read_Chunk (Buffer);
                  exit when Count_Read = 0;
                  if Count_Read < 0 then
                     Error := To_Unbounded_String
                       ("Could not read the image file.");
                     exit;
                  elsif Natural (Count_Read) > SVG_Limit - Length (Contents)
                  then
                     Error := To_Unbounded_String
                       ("SVG input exceeds the size limit.");
                     exit;
                  end if;
                  Append (Contents, Buffer (1 .. Count_Read));
               end loop;
               if Length (Error) = 0 then
                  SVG_Total := SVG_Total + Length (Contents);
                  Coyote_Canvas.SVG.Decode
                    (To_String (Contents), Pixels, Error);
               end if;
            end if;
         end if;
      end if;
      Close_FD (Stage);
      Close (File);
      Close (Root);
   exception
      when others =>
         Close_FD (Stage);
         Close_FD (Tile.FD);
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

   procedure Submit_Batch
     (Data     : Coyote_Canvas.Import_Service.Text_List;
      Token    : System.Address;
      Callback : Completion;
      Accepted : out Boolean)
   is
      Index : Natural;
      Total : Natural := 0;
   begin
      Accepted := False;
      if Data'Length not in 1 .. MAX_FILES then
         return;
      end if;
      for Image of Data loop
         if Length (Image) not in 1 .. Coyote_Canvas.Rasters.MAX_ENCODED_BYTES
           or else Length (Image) > MAX_BATCH_ENCODED_BYTES - Total
         then
            return;
         end if;
         Total := Total + Length (Image);
      end loop;
      Queue.Add_Batch (Data, Token, Callback, Index);
      if Index /= 0 then
         begin
            Start_Pump;
            Accepted := True;
         exception
            when others => Queue.Release (Slot_Index (Index));
         end;
      end if;
   end Submit_Batch;

   function Submit_Tiled_Files
     (Paths : Path_List; Token : System.Address;
      Callback : On_Tiled_Complete) return Boolean
   is
      Index : Natural;
   begin
      if Paths'Length not in 1 .. MAX_FILES then
         return False;
      end if;
      for Path of Paths loop
         declare
            Name : constant String := To_String (Path);
            Slash : constant Natural := Ada.Strings.Fixed.Index
              (Name, "/", Ada.Strings.Backward);
         begin
            if Slash = 0 or else Slash = Name'Last then
               return False;
            end if;
         end;
      end loop;
      Queue.Add_Tiled_Files (Paths, Token, Callback, Index);
      if Index = 0 then
         return False;
      end if;
      begin
         Start_Pump;
         return True;
      exception
         when others =>
            Queue.Release (Slot_Index (Index));
            return False;
      end;
   end Submit_Tiled_Files;

   procedure Submit_Files
     (Paths    :        Path_List;
      Token    :        System.Address;
      Callback :        Completion;
      Accepted :    out Boolean)
   is
      Index : Natural;
   begin
      Accepted := False;
      if Paths'Length = 0 or else Paths'Length > MAX_FILES then
         return;
      end if;
      for Path of Paths loop
         if Length (Path) = 0 then
            return;
         end if;
      end loop;
      Queue.Add_Files (Paths, Token, Callback, Index);
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
   end Submit_Files;

   function Pump return Boolean is
      Index : Natural;
      Found : Boolean;
      Token : System.Address;
      Callback : Callback_Access;
      Raw : Raw_Pixbuf_List :=
        (others => Coyote_Image_Decoder.Null_Pixbuf);
      Pixel_Count : Natural;
      Tiles : Raw_Tile_List := (others => (FD => -1, Width => 0, Height => 0));
      Tile_Count : Natural := 0;
      Tiled_Callback : Tiled_Callback_Access;
      Tile_Results : Tile_List (1 .. MAX_FILES) :=
        (others => (FD => -1, Width => 0, Height => 0));
      Error : Unbounded_String;
      Images : Image_List (1 .. MAX_FILES) := (others => null);
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
         Queue.Take_Complete
           (Slot_Index (Index), Token, Callback, Raw, Pixel_Count, Error,
            Tiled_Callback, Tiles, Tile_Count);
         if Queue.Cancelled (Slot_Index (Index)) then
            Error := To_Unbounded_String ("Image import cancelled.");
         end if;
         if Length (Error) = 0 then
            begin
               for I in 1 .. Pixel_Count loop
                  if not Coyote_Image_Decoder.Is_Null (Raw (I)) then
                     Images (I) := Coyote_Image_Decoder.Adopt (Raw (I));
                  end if;
               end loop;
            exception
               when others =>
                  Error := To_Unbounded_String ("Image import failed");
            end;
         end if;
         begin
            if Length (Error) = 0 then
               if Tiled_Callback /= null then
                  for I in 1 .. Tile_Count loop
                     Tile_Results (I) := Tiles (I);
                  end loop;
                  Tiled_Callback.all
                    (Token, Images (1 .. Pixel_Count),
                     Tile_Results (1 .. Tile_Count), "");
               else
                  Callback.all (Token, Images (1 .. Pixel_Count), "");
               end if;
            else
               if Tiled_Callback /= null then
                  Tiled_Callback.all
                    (Token, Image_List'(1 .. 0 => null),
                     Tile_List'(1 .. 0 =>
                       (FD => -1, Width => 0, Height => 0)),
                     To_String (Error));
               else
                  Callback.all (Token, Image_List'(1 .. 0 => null),
                                To_String (Error));
               end if;
            end if;
         exception
            when others =>
               null;
         end;
         for I in Images'Range loop
            if Images (I) /= null then
               Glib.Object.Unref (Glib.Object.GObject (Images (I)));
               Images (I) := null;
            end if;
         end loop;
         Release_All (Raw);
         for I in Tiles'Range loop
            Close_FD (Tiles (I).FD);
         end loop;
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
         Release_All (Raw);
         for I in Tiles'Range loop
            Close_FD (Tiles (I).FD);
         end loop;
         return Queue.Count > 0;
   end Pump;

   task body Worker is
      Index : Slot_Index;
      Kind : Source_Kind;
      Data : Unbounded_String;
      Paths : Stored_Path_List;
      Path_Count : Natural;
      Expected : Coyote_Canvas.Rasters.Format;
      Raw : Raw_Pixbuf_List :=
        (others => Coyote_Image_Decoder.Null_Pixbuf);
      Tiles : Raw_Tile_List := (others => (FD => -1, Width => 0, Height => 0));
      Tile_Count : Natural := 0;
      Pixel_Count : Natural := 0;
      Decoded_Total : Natural := 0;
      SVG_Total : Natural := 0;
      Staging_Total : Interfaces.Unsigned_64 := 0;
      Width : Natural;
      Height : Natural;
      Error : Unbounded_String;
      Item_Error : Unbounded_String;
      Path : Unbounded_String;
   begin
      loop
         select
            accept Start (Job_Index : Slot_Index) do
               Index := Job_Index;
            end Start;
            begin
               Queue.Get
                 (Index, Kind, Data, Paths, Path_Count, Expected);
               Raw := (others => Coyote_Image_Decoder.Null_Pixbuf);
               Pixel_Count := 0;
               Tile_Count := 0;
               Tiles := (others => (FD => -1, Width => 0, Height => 0));
               Decoded_Total := 0;
               SVG_Total := 0;
               Staging_Total := 0;
               Error := Null_Unbounded_String;
               if Kind = Bytes_Source then
                  Coyote_Canvas.Rasters.Decode
                    (To_String (Data), Expected, Raw (1), Width, Height,
                     Error);
                  if Length (Error) = 0 then
                     Pixel_Count := 1;
                     Decoded_Total := Pixel_Bytes (Raw (1));
                     if Decoded_Total > MAX_BATCH_DECODED_BYTES then
                        Error := To_Unbounded_String
                          ("Decoded image exceeds 128 MiB.");
                     end if;
                  end if;
               else
                  for I in 1 .. Path_Count loop
                     if Queue.Cancelled (Index) then
                        Error := To_Unbounded_String
                          ("Image import cancelled.");
                        exit;
                     end if;
                     Path := Paths (I);
                     if Kind in Files_Source | Tiled_Files_Source then
                        Decode_File
                          (To_String (Path), Index, SVG_Total,
                           Kind = Tiled_Files_Source, Staging_Total,
                           Tiles (I), Raw (I), Item_Error);
                     elsif Coyote_Canvas.Rasters.Detect (To_String (Path)) =
                       Coyote_Canvas.Rasters.Unknown
                     then
                        Coyote_Canvas.SVG.Decode
                          (To_String (Path), Raw (I), Item_Error);
                     else
                        Coyote_Canvas.Rasters.Decode
                          (To_String (Path), Coyote_Canvas.Rasters.Unknown,
                           Raw (I), Width, Height, Item_Error);
                     end if;
                     if Length (Item_Error) /= 0 then
                        Error := To_Unbounded_String
                          ("Image " & Ada.Strings.Fixed.Trim
                             (Positive'Image (I), Ada.Strings.Both) &
                           ": " & To_String (Item_Error));
                        exit;
                     end if;
                     Pixel_Count := I;
                     if Kind = Tiled_Files_Source then
                        Tile_Count := I;
                     end if;
                     if Kind /= Tiled_Files_Source or else
                       not Coyote_Image_Decoder.Is_Null (Raw (I))
                     then
                        Decoded_Total := Decoded_Total + Pixel_Bytes (Raw (I));
                     end if;
                     if Decoded_Total > MAX_BATCH_DECODED_BYTES then
                        Error := To_Unbounded_String
                          ("Image " & Ada.Strings.Fixed.Trim
                             (Positive'Image (I), Ada.Strings.Both) &
                           ": decoded image batch exceeds 128 MiB.");
                        exit;
                     end if;
                  end loop;
               end if;
               Paths := (others => Null_Unbounded_String);
               Path := Null_Unbounded_String;
               if Queue.Cancelled (Index) then
                  Error := To_Unbounded_String ("Image import cancelled.");
               end if;
               if Length (Error) /= 0 then
                  Release_All (Raw);
                  Pixel_Count := 0;
                  for I in Tiles'Range loop Close_FD (Tiles (I).FD); end loop;
                  Tile_Count := 0;
               end if;
               Queue.Finish (Index, Raw, Pixel_Count, To_String (Error),
                             Tiles, Tile_Count);
               Raw := (others => Coyote_Image_Decoder.Null_Pixbuf);
            exception
               when others =>
                  Release_All (Raw);
                  for I in Tiles'Range loop Close_FD (Tiles (I).FD); end loop;
                  Queue.Finish
                    (Index, (others => Coyote_Image_Decoder.Null_Pixbuf), 0,
                     "Image import failed", Tiles, 0);
            end;
            Data := Null_Unbounded_String;
            Paths := (others => Null_Unbounded_String);
            Path := Null_Unbounded_String;
            Item_Error := Null_Unbounded_String;
            Error := Null_Unbounded_String;
         or
            terminate;
         end select;
      end loop;
   end Worker;

end Coyote_GUI.Canvas_Import_Jobs;
