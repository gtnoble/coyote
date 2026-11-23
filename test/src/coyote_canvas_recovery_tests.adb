with Ada.Directories;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Text_IO;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with AUnit.Assertions; use AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Coyote_Canvas.Document;
with Coyote_Canvas.Revisions;
with Coyote_Canvas.Revisions.Recovery;
with Coyote_Canvas.Store;
with Coyote_Canvas.Store.Workspaces;
with Coyote_Session_Transactions;
with Coyote_Temp_Files;
with GNAT.OS_Lib;
with Interfaces;
with Interfaces.C;
with System;

package body Coyote_Canvas_Recovery_Tests is
   use Coyote_Canvas.Document;
   use Coyote_Canvas.Revisions;
   use Coyote_Canvas.Revisions.Recovery;
   use Coyote_Canvas.Store;
   package Disk renames Coyote_Canvas.Store.Workspaces;

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;
   UUID_A : constant String := "550e8400-e29b-41d4-a716-446655440000";
   UUID_B : constant String := "550e8400-e29b-41d4-a716-446655440001";

   procedure Make_Tile_File (Path : String; Width : Positive := 9_000) is
      use Ada.Streams;
      use Ada.Streams.Stream_IO;
      File : File_Type;
      Bytes : Stream_Element_Array
        (1 .. Stream_Element_Offset (16 + Width * 4));
   begin
      Bytes (1 .. 8) :=
        (Stream_Element (Character'Pos ('C')),
         Stream_Element (Character'Pos ('Y')),
         Stream_Element (Character'Pos ('T')),
         Stream_Element (Character'Pos ('I')),
         Stream_Element (Character'Pos ('L')),
         Stream_Element (Character'Pos ('E')),
         0, 1);
      Bytes (9 .. 12) :=
        (Stream_Element (Width / 16#100_0000#),
         Stream_Element (Width / 16#1_0000# mod 16#100#),
         Stream_Element (Width / 16#100# mod 16#100#),
         Stream_Element (Width mod 16#100#));
      Bytes (13 .. 16) := (0, 0, 0, 1);
      for Index in 17 .. Bytes'Last loop
         Bytes (Index) := Stream_Element ((Index - 17) mod 256);
      end loop;
      Create (File, Out_File, Path);
      Write (File, Bytes);
      Close (File);
   end Make_Tile_File;

   function Make_Temp_Directory
     (Template : System.Address) return System.Address
      with Import, Convention => C, External_Name => "mkdtemp";

   procedure Set_Up_Directory (Root : out Unbounded_String) is
      use type System.Address;
      Template : String := "/tmp/coyote-canvas-recovery-XXXXXX"
        & ASCII.NUL;
      Found : constant System.Address := Make_Temp_Directory
        (Template'Address);
   begin
      Assert (Found /= System.Null_Address, "create temporary directory");
      Root := To_Unbounded_String (Template (1 .. Template'Last - 1));
   end Set_Up_Directory;

   procedure Remove_Directory (Root : Unbounded_String) is
      Alias_Path : constant String := To_String (Root) & "/" & UUID_B & ".canvas";
      Removed : Boolean;
   begin
      if Length (Root) > 0
        and then Ada.Directories.Exists (To_String (Root))
      then
         if GNAT.OS_Lib.Is_Symbolic_Link (Alias_Path) then
            GNAT.OS_Lib.Delete_File (Alias_Path, Removed);
            Assert (Removed, "unlink sidecar alias fixture");
         end if;
         Ada.Directories.Delete_Tree (To_String (Root));
      end if;
   end Remove_Directory;

   procedure Make_Workspace (W : in out Workspace) is
      First_Original : Revision_Id;
      Points         : Samples.Vector;
   begin
      Add_Originals
        (W, (1 => (Width => 40, Height => 30),
             2 => (Width => 90, Height => 70)), First_Original);
      Edit (W, First_Original + 1);
      Points.Append
        ((X => Long_Float'Adjacent (3.25, 4.0), Y => 4.5, Width => 1.75,
          Alpha => 1.0));
      Points.Append ((X => 8.0, Y => 9.125, Width => 2.5, Alpha => 1.0));
      Add_Stroke (W, Points);
      Save (W);
      Crop (W, (2, 3, 45, 50));
      Save (W);
      Edit (W, First_Original + 1);
      Crop (W, (1, 2, 80, 60));
      Save (W);
      Crop (W, (2, 3, 45, 50));
   end Make_Workspace;

   function Replace_First
     (Source, Before, After : String) return String is
      Position : Natural := 0;
   begin
      if Before'Length = 0 or else Before'Length > Source'Length then
         return Source;
      end if;
      for Index in Source'First .. Source'Last - Before'Length + 1 loop
         if Source (Index .. Index + Before'Length - 1) = Before then
            Position := Index;
            exit;
         end if;
      end loop;
      if Position = 0 then
         return Source;
      end if;
      return Source (Source'First .. Position - 1) & After
        & Source (Position + Before'Length .. Source'Last);
   end Replace_First;

   procedure Roundtrip_Revisions_And_Draft (T : in out Test) is
      pragma Unreferenced (T);
      Source      : Workspace;
      Restored    : Workspace;
      Encoded     : Unbounded_String;
      Before_Count : Natural;
      Original_Ink, Recovered_Ink : Samples.Vector;

      Original_Color, Recovered_Color : Ink_Color := DEFAULT_INK_COLOR;
      Original_Rendering, Recovered_Rendering : Stroke_Rendering := Classic;

      procedure Capture_Original
        (Points : Samples.Vector; Operation : Ink_Operation;
         Color : Ink_Color; Rendering : Stroke_Rendering) is
         pragma Unreferenced (Operation);
      begin
         Original_Ink := Points;
         Original_Color := Color;
         Original_Rendering := Rendering;
      end Capture_Original;

      procedure Capture_Recovered
        (Points : Samples.Vector; Operation : Ink_Operation;
         Color : Ink_Color; Rendering : Stroke_Rendering) is
         pragma Unreferenced (Operation);
      begin
         Recovered_Ink := Points;
         Recovered_Color := Color;
         Recovered_Rendering := Rendering;
      end Capture_Recovered;
   begin
      Make_Workspace (Source);
      Before_Count := Count (Source);
      Encoded := To_Unbounded_String (Encode (Source));
      Decode (To_String (Encoded), Restored);
      Assert (Count (Restored) = Before_Count,
              "recovery does not create revision nodes");
      Assert (Base (Restored) = Base (Source), "draft base is retained");
      Assert (Changed (Restored), "dirty draft is retained");
      Assert (Extent (Restored) = Extent (Source),
              "draft extent is retained");
      Assert (Extent (Restored, 2) = Extent (Source, 2),
              "saved revision extent is retained");
      Assert (Parent (Restored, 4) = 3 and then Parent (Restored, 5) = 2,
              "sibling branch ancestry is retained");
      Assert (Background (Restored, 2) = Background (Source, 2),
              "Original asset index is retained");
      Visit_Source (Source, 3, Capture_Original'Access);
      Visit_Source (Restored, 3, Capture_Recovered'Access);
      Assert (not Original_Ink.Is_Empty
              and then Samples."=" (Original_Ink, Recovered_Ink)
              and then Original_Ink (1).Alpha = Recovered_Ink (1).Alpha,
              "source sample coordinates round-trip without rounding");
      Assert (Original_Color = DEFAULT_INK_COLOR
              and then Recovered_Color = DEFAULT_INK_COLOR
              and then Original_Rendering = Classic
              and then Recovered_Rendering = Classic,
              "legacy/default paint uses the default ink color");
      Assert (Encode (Restored) = To_String (Encoded),
              "strokes, exact samples, assets and states roundtrip");
   end Roundtrip_Revisions_And_Draft;

   procedure Color_Version_And_Legacy_Recovery (T : in out Test) is
      pragma Unreferenced (T);
      Source, Restored : Workspace;
      Points : Samples.Vector;
      First : Revision_Id;
      Color : Ink_Color := DEFAULT_INK_COLOR;
      Operation : Ink_Operation := Paint;
      Data : Unbounded_String;
      Bad_Data : Unbounded_String;
      Rejected : Boolean := False;

      procedure Capture
        (Samples_In : Samples.Vector; Ink : Ink_Operation;
         Ink_Color_Value : Ink_Color; Rendering : Stroke_Rendering) is
         pragma Unreferenced (Rendering);
         pragma Unreferenced (Samples_In);
      begin
         Operation := Ink;
         Color := Ink_Color_Value;
      end Capture;
   begin
      Add_Originals (Source, (1 => (Width => 8, Height => 8)),
                     First_Id => First);
      Edit (Source, First);
      Points.Append ((X => 1.0, Y => 2.0, Width => 1.0, Alpha => 1.0));
      Add_Stroke (Source, Points, Color => 0);
      Save (Source);
      Data := To_Unbounded_String (Encode (Source));
      Assert (Index (Data, """version"":4") /= 0,
              "nondefault paint selects snapshot v4");
      Assert (Index (Data, "[1,[") /= 0,
              "explicit black uses packed color plus one marker");
      Decode (To_String (Data), Restored);
      Visit_Source (Restored, Base (Restored), Capture'Access);
      Assert (Operation = Paint and then Color = 0,
              "v4 color and operation round-trip");

      Bad_Data := To_Unbounded_String
        (Replace_First (To_String (Data), "[1,[", "[16777217,["));
      Rejected := False;
      begin
         Decode (To_String (Bad_Data), Restored);
      exception
         when Invalid_Snapshot =>
            Rejected := True;
      end;
      Assert (Rejected and then Encode (Restored) = To_String (Data),
              "Out-of-range packed color is rejected atomically");

      Bad_Data := To_Unbounded_String
        (Replace_First (To_String (Data), "[1,[", "[0,["));
      Decode (To_String (Bad_Data), Restored);
      Visit_Source (Restored, Base (Restored), Capture'Access);
      Assert (Operation = Erase and then Color = DEFAULT_INK_COLOR,
              "v4 retains the v3 erase marker");

      Data := To_Unbounded_String
        (Replace_First (To_String (Data), """version"":4", """version"":3"));
      Rejected := False;
      begin
         Decode (To_String (Data), Restored);
      exception
         when Invalid_Snapshot =>
            Rejected := True;
      end;
      Assert (Rejected, "v3 rejects the v4 paint marker");

      Clear (Source);
      New_Drawing (Source, 8, 8);
      Points.Clear;
      Points.Append ((X => 1.0, Y => 2.0, Width => 1.0, Alpha => 1.0));
      Add_Stroke (Source, Points);
      Save (Source);
      Data := To_Unbounded_String (Encode (Source));
      Assert (Index (Data, """version"":2") /= 0,
              "default paint retains v2 encoding");
      Decode (To_String (Data), Restored);
      Visit_Source (Restored, Base (Restored), Capture'Access);
      Assert (Color = DEFAULT_INK_COLOR,
              "v2 recovery supplies default paint color");

      Add_Stroke (Source, Points, Erase);
      Save (Source);
      Data := To_Unbounded_String (Encode (Source));
      Assert (Index (Data, """version"":3") /= 0,
              "erase-only extension retains v3 encoding");
      Decode (To_String (Data), Restored);
      Visit_Source (Restored, Base (Restored), Capture'Access);
      Assert (Operation = Erase and then Color = DEFAULT_INK_COLOR,
              "v3 erase recovers with default color");
   end Color_Version_And_Legacy_Recovery;

   procedure Deposited_Version_Recovery (T : in out Test) is
      pragma Unreferenced (T);
      Source, Restored : Workspace;
      Points : Samples.Vector;
      First : Revision_Id;
      Data, Bad_Data, Baseline : Unbounded_String;
      Got_Points : Samples.Vector;
      Got_Rendering : Stroke_Rendering := Classic;
      Got_Operation : Ink_Operation := Erase;
      Rejected : Boolean := False;
      package Real_IO is new Ada.Text_IO.Float_IO (Long_Float);
      Alpha_Text, Invalid_Alpha_Text : String (1 .. 32);

      procedure Capture
        (Samples_In : Samples.Vector; Operation : Ink_Operation;
         Color : Ink_Color; Rendering : Stroke_Rendering) is
         pragma Unreferenced (Color);
      begin
         if Rendering = Deposited then
            Got_Points := Samples_In;
            Got_Operation := Operation;
            Got_Rendering := Rendering;
         end if;
      end Capture;
   begin
      Add_Originals (Source, (1 => (Width => 8, Height => 8)), First);
      Edit (Source, First);
      Points.Append ((X => 1.0, Y => 2.0, Width => 1.5, Alpha => 0.25));
      Add_Stroke (Source, Points, Color => 16#123456#,
                  Rendering => Deposited);
      Points.Clear;
      Points.Append ((X => 3.0, Y => 4.0, Width => 2.0, Alpha => 1.0));
      Add_Stroke (Source, Points, Color => 16#010203#);
      Save (Source);
      Data := To_Unbounded_String (Encode (Source));
      Assert (Index (Data, """version"":5") /= 0,
              "deposited paint selects snapshot v5");
      Decode (To_String (Data), Restored);
      Visit_Source (Restored, Base (Restored), Capture'Access);
      Assert (Got_Operation = Paint and then Got_Rendering = Deposited
              and then Got_Points (1).X = 1.0
              and then Got_Points (1).Y = 2.0
              and then Got_Points (1).Width = 1.5
              and then Got_Points (1).Alpha = 0.25,
              "v5 preserves source coordinates, alpha, and rendering");
      Baseline := To_Unbounded_String (Encode (Restored));
      Assert (Index (Data, "[66052,[") /= 0 and then Baseline = Data,
              "v5 preserves the classic stroke and color marker");
      Real_IO.Put (Alpha_Text, 0.25, Aft => 17, Exp => 4);
      Real_IO.Put (Invalid_Alpha_Text, 1.25, Aft => 17, Exp => 4);
      Bad_Data := To_Unbounded_String
        (Replace_First (To_String (Data), Alpha_Text, Invalid_Alpha_Text));
      Assert (Bad_Data /= Data, "invalid-alpha fixture changes snapshot");
      Rejected := False;
      begin
         Decode (To_String (Bad_Data), Restored);
      exception
         when Invalid_Snapshot =>
            Rejected := True;
      end;
      Assert (Rejected and then Encode (Restored) = To_String (Baseline),
              "v5 rejects out-of-range alpha atomically");
      Bad_Data := To_Unbounded_String
        (Replace_First (To_String (Data), "17970264", "33554434"));
      Rejected := False;
      begin
         Decode (To_String (Bad_Data), Restored);
      exception
         when Invalid_Snapshot =>
            Rejected := True;
      end;
      Assert (Rejected, "v5 rejects out-of-range rendering/color marker");
   end Deposited_Version_Recovery;

   procedure Recovery_Clears_Undo_Redo (T : in out Test) is
      pragma Unreferenced (T);
      Source   : Workspace;
      Restored : Workspace;
      Data     : Unbounded_String;
   begin
      New_Drawing (Source, 20, 20);
      Crop (Source, (1, 1, 18, 18));
      Crop (Source, (1, 1, 12, 12));
      Undo (Source);
      Assert (Can_Undo (Source) and then Can_Redo (Source),
              "fixture contains undo and redo history");
      Data := To_Unbounded_String (Encode (Source));
      Decode (To_String (Data), Restored);
      Assert (not Can_Undo (Restored) and then not Can_Redo (Restored),
              "recovery resets transient undo and redo history");
   end Recovery_Clears_Undo_Redo;

   procedure Reject_Invalid_Without_Mutation (T : in out Test) is
      pragma Unreferenced (T);
      Target    : Workspace;
      Baseline  : Unbounded_String;
      Rejected  : Boolean;
      Bad_Data  : Unbounded_String;
   begin
      New_Drawing (Target, 12, 13);
      Crop (Target, (1, 2, 10, 11));
      Baseline := To_Unbounded_String (Encode (Target));
      Bad_Data := To_Unbounded_String ("{}");
      for Index in 1 .. 10 loop
         case Index is
            when 1 => Bad_Data := To_Unbounded_String ("{");
            when 2 => Bad_Data := To_Unbounded_String
              (Replace_First (To_String (Baseline), """version"":2",
                              """version"":1"));
            when 3 => Bad_Data := To_Unbounded_String
              (Replace_First (To_String (Baseline), """base"":1",
                              """base"":99"));
            when 4 => Bad_Data := To_Unbounded_String
              (Replace_First (To_String (Baseline), "[[0,", "[[1,"));
            when 5 => Bad_Data := To_Unbounded_String
              (Replace_First (To_String (Baseline), """draft"":",
                              """draft"":[[[[[[[0]]]]]]],""unused"":"));
            when 6 => Bad_Data := Baseline & " {}";
            when 7 => Bad_Data := To_Unbounded_String
              (Replace_First (To_String (Baseline), """version"":2",
                              """version"":1,""version"":2"));
            when 8 => Bad_Data := To_Unbounded_String
              (Replace_First (To_String (Baseline),
                              '"' & Revision_Key (Target, 1) & '"', "0"));
            when 9 => Bad_Data := To_Unbounded_String
              (Replace_First (To_String (Baseline), Revision_Key (Target, 1),
                              UUID_A (1 .. 14) & "1" & UUID_A (16 .. 36)));
            when others => Bad_Data := To_Unbounded_String
              (Replace_First (To_String (Baseline), """draft"":[1,2,10,11,0,[]]",
                              """draft"":[1,2,10,11,0,[1]]"));
         end case;
         Assert (Bad_Data /= Baseline, "fixture modifies the snapshot");
         Rejected := False;
         begin
            Decode (To_String (Bad_Data), Target);
         exception
            when Invalid_Snapshot =>
               Rejected := True;
         end;
         Assert (Rejected, "malformed snapshot rejected " &
                   Natural'Image (Index));
         Assert (Encode (Target) = To_String (Baseline),
                 "failed recovery preserves target workspace");
      end loop;
   end Reject_Invalid_Without_Mutation;

   procedure Disk_Read_Write_And_Isolation (T : in out Test) is
      pragma Unreferenced (T);
      Root       : Unbounded_String;
      Source     : Workspace;
      Restored   : Workspace;
      Data       : Unbounded_String;
      Read_Data  : Unbounded_String;
      Status     : Result;
   begin
      Set_Up_Directory (Root);
      Make_Workspace (Source);
      Data := To_Unbounded_String (Encode (Source));
      for Index in 1 .. 3 loop
         Write
           (To_String (Root), UUID_A,
            To_String (Data), Status);
         Assert (Status = Ok, "snapshot write succeeds repeatedly");
         Read
           (To_String (Root), UUID_A,
            Read_Data, Status);
         Assert (Status = Ok and then Read_Data = Data,
                 "snapshot read returns published data");
      end loop;
      Decode (To_String (Read_Data), Restored);
      Assert (Encode (Restored) = To_String (Data),
              "disk snapshot recovers revision graph");
      Read (To_String (Root), "missing-canvas-id", Read_Data, Status);
      Assert (Status = Invalid, "malformed UUID is not treated as missing");
      Read (To_String (Root), UUID_B, Read_Data, Status);
      Assert (Status = Missing and then Length (Read_Data) = 0,
              "different UUID has no manifest in the same parent");
      Ada.Directories.Create_Directory (To_String (Root) & "/other");
      Read
        (To_String (Root) & "/other",
         UUID_A, Read_Data, Status);
      Assert (Status = Missing, "snapshots are isolated by parent");
      Remove_Directory (Root);
   exception
      when others =>
         Remove_Directory (Root);
         raise;
   end Disk_Read_Write_And_Isolation;

   procedure Disk_Rollback_And_Unsafe_Entries (T : in out Test) is
      pragma Unreferenced (T);
      use GNAT.OS_Lib;
      use Interfaces.C;
      Root   : Unbounded_String;
      Data   : Unbounded_String;
      Status : Result;
      Lock   : File_Descriptor := Invalid_FD;

      function Flock (FD, Mode : int) return int
        with Import, Convention => C, External_Name => "flock";
      function Symlink (Target, Name : char_array) return int
        with Import, Convention => C, External_Name => "symlink";
      LOCK_EX_NB : constant int := 2 + 4;
   begin
      Set_Up_Directory (Root);
      declare
         Parent   : constant String := To_String (Root);
         Sidecar  : constant String := Parent & "/" & UUID_A & ".canvas";
         Manifest : constant String := Sidecar & "/canvas.json";
         Temp     : constant String := Sidecar & "/.canvas.tmp";
         FD       : File_Descriptor;
      begin
         Write (Parent, UUID_A, "first", Status);
         Assert (Status = Ok, "publish prior manifest");
         Lock := Open_Read_Write (Sidecar & "/.writer", Binary);
         Assert (Lock /= Invalid_FD, "open manifest writer lock");
         Assert (Flock (int (Lock), LOCK_EX_NB) = 0, "hold writer lock");
         FD := Create_New_File (Temp, Binary);
         Assert (FD /= Invalid_FD, "simulate interrupted temp publication");
         Close (FD);
         Write (Parent, UUID_A, "blocked", Status);
         Assert (Status = Busy, "second writer does not wait or publish");
         Read (Parent, UUID_A, Data, Status);
         Assert (Status = Ok and then Data = "first",
                 "reader ignores temp and sees previous data during write");
         Close (Lock);
         Lock := Invalid_FD;
         Write (Parent, UUID_A, "next", Status);
         Assert (Status = Ok and then not Ada.Directories.Exists (Temp),
                 "next writer replaces the manifest and cleans stale temp");
         Ada.Directories.Rename (Manifest, Manifest & ".prior");
         Assert (Symlink (To_C (Manifest & ".prior"), To_C (Manifest)) = 0,
                 "install symlink fixture");
         Read (Parent, UUID_A, Data, Status);
         Assert (Status = Invalid and then Length (Data) = 0,
                 "reader rejects a manifest symlink");
         Write (Parent, UUID_A, "rejected", Status);
         Assert (Status = Invalid and then Is_Symbolic_Link (Manifest),
                 "writer leaves an invalid existing entry intact");
         Ada.Directories.Delete_File (Manifest);
         Ada.Directories.Rename (Manifest & ".prior", Manifest);
         Read (Parent, UUID_A, Data, Status);
         Assert (Status = Ok and then Data = "next",
                 "refused write leaves the published bytes unchanged");
         Assert (Symlink (To_C (Sidecar),
                          To_C (Parent & "/" & UUID_B & ".canvas")) = 0,
                 "install sidecar alias fixture");
         Read (Parent, UUID_B, Data, Status);
         Assert (Status = Invalid, "sidecar alias cannot read another UUID");
         Write (Parent, UUID_B, "rejected", Status);
         Assert (Status = Invalid, "sidecar alias cannot write another UUID");
      end;
      Remove_Directory (Root);
   exception
      when others =>
         if Lock /= Invalid_FD then
            Close (Lock);
         end if;
         Remove_Directory (Root);
         raise;
   end Disk_Rollback_And_Unsafe_Entries;

   procedure Complete_Workspace_Roundtrip (T : in out Test) is
      pragma Unreferenced (T);
      use type Disk.Raster_Set;
      Root, Manifest : Unbounded_String;
      W, Loaded : Workspace;
      A, Got : Disk.Raster_Set;
      Refs : Asset_References;
      First : Revision_Id;
      Status : Result;
      Points : Samples.Vector;
      Data : constant String :=
        ASCII.NUL & Character'Val (201) & "X" & ASCII.NUL &
        "ABC" & Character'Val (1) & "DEF" & Character'Val (255) &
        "GHI" & Character'Val (127);
   begin
      Set_Up_Directory (Root);
      New_Drawing (W, 12, 11);
      Add_Originals (W, (1 => (2, 2), 2 => (2, 2), 3 => (4, 1)), First);
      A (First) := To_Unbounded_String (Data);
      A (First + 1) := A (First);
      A (First + 2) := A (First);
      Edit (W, First);
      Crop (W, (0, 0, 1, 2));
      Save (W);
      Crop (W, (0, 1, 1, 2));
      Points.Append ((0.5, 0.5, 1.0, 1.0));
      Add_Stroke (W, Points);
      Add_Stroke (W, Points, Erase);
      Disk.Save (To_String (Root), UUID_A, W, A, Status);
      Assert (Status = Ok, "persist complete workspace");
      Disk.Save (To_String (Root), UUID_A, W, A, Status);
      Assert (Status = Ok, "repeat save reuses verified immutable assets");
      Disk.Load (To_String (Root), UUID_A, Loaded, Got, Status);
      Assert (Status = Ok and then A = Got, "exact RGBA8 recovery");
      Assert (Encode (Loaded) = Encode (W), "recover branches and dirty draft");
      Assert (not Can_Undo (Loaded), "restore does not synthesize edit history");
      for Id in 1 .. Count (W) loop
         Assert (Revision_Key (W, Id) = Revision_Key (Loaded, Id),
                 "revision keys survive recovery");
         Assert (Drawing_Key (W, Id) = Drawing_Key (Loaded, Id),
                 "drawing keys survive recovery");
      end loop;
      Assert (Drawing_Key (Loaded, Base (Loaded)) = Revision_Key (W, First)
              and then Revision_Key (Loaded, Base (Loaded)) /=
                Revision_Key (W, First) and then
                Drawing_Key (Loaded, First) /= Drawing_Key (Loaded, First + 1),
              "descendants keep drawing identity; duplicate pixels do not merge roots");
      Read (To_String (Root), UUID_A, Manifest, Status);
      Assert (Status = Ok, "read committed manifest");
      Decode (To_String (Manifest), Loaded, Refs);
      Assert (Refs (1) = NO_ASSET and then Refs (Base (W)) = NO_ASSET,
              "blank Original and checkpoint need no asset");
      Assert (Refs (First) = Refs (First + 1)
              and then Refs (First) /= Refs (First + 2),
              "deduplicate equal layout; bind digest to dimensions");
      Remove_Directory (Root);
   exception
      when others =>
         Remove_Directory (Root);
         raise;
   end Complete_Workspace_Roundtrip;

   procedure Asset_Failures_Are_Atomic (T : in out Test) is
      pragma Unreferenced (T);
      Root, Previous, Current, Bytes : Unbounded_String;
      W, Loaded : Workspace;
      A, Got : Disk.Raster_Set;
      Refs : Asset_References;
      First : Revision_Id;
      Status : Result;
      Valid : constant String := "ABC" & ASCII.NUL;
      Bad   : constant String := "ABD" & ASCII.NUL;
   begin
      Set_Up_Directory (Root);
      Add_Originals (W, (1 => (1, 1)), First);
      A (First) := To_Unbounded_String (Valid);
      Disk.Save (To_String (Root), UUID_A, W, A, Status);
      Assert (Status = Ok, "publish valid workspace");
      Read (To_String (Root), UUID_A, Previous, Status);
      Assert (Status = Ok, "read valid manifest");
      Decode (To_String (Previous), Loaded, Refs);
      Write_Asset (To_String (Root), UUID_A, Refs (First), Bad, Status);
      Assert (Status = Invalid, "immutable asset cannot be overwritten");
      New_Drawing (Loaded, 8, 9);
      declare
         Baseline : constant String := Encode (Loaded);
         Asset_Path : constant String := To_String (Root) & "/" & UUID_A &
           ".canvas/" & Refs (First) & ".rgba";
      begin
         Got (First) := To_Unbounded_String ("sentinel");
         Ada.Directories.Delete_File (Asset_Path);
         Disk.Load (To_String (Root), UUID_A, Loaded, Got, Status);
         Assert (Status = Invalid and then Encode (Loaded) = Baseline
                 and then Got (First) = "sentinel", "missing asset is atomic");
         Write_Asset (To_String (Root), UUID_A, Refs (First), Bad, Status);
         Assert (Status = Ok, "install same-length corrupted asset fixture");
         Disk.Load (To_String (Root), UUID_A, Loaded, Got, Status);
         Assert (Status = Invalid and then Encode (Loaded) = Baseline
                 and then Got (First) = "sentinel", "digest failure is atomic");
         Edit (W, First);
         Disk.Save (To_String (Root), UUID_A, W, A, Status);
         Assert (Status = Invalid, "save detects a corrupted referenced asset");
         Read (To_String (Root), UUID_A, Current, Status);
         Assert (Status = Ok and then Current = Previous,
                 "failed asset publication does not replace the manifest");
         Read_Asset (To_String (Root), UUID_A, Refs (First), 4, Bytes, Status);
         Assert (Status = Ok and then Bytes = Bad,
                 "failed asset publication does not mutate the existing file");
      end;
      Remove_Directory (Root);
   exception
      when others =>
         Remove_Directory (Root);
         raise;
   end Asset_Failures_Are_Atomic;

   procedure Workspace_Read_Holds_Session_Guard (T : in out Test) is
      pragma Unreferenced (T);
      package Tx renames Coyote_Session_Transactions;
      use type Tx.Result;
      Root : Unbounded_String;
      Stored, Loaded : Workspace;
      Rasters, Loaded_Rasters : Disk.Raster_Set;
      First : Revision_Id;
      Status : Result;
      Pixels : constant String := "rgb" & ASCII.NUL;
   begin
      Set_Up_Directory (Root);
      Add_Originals (Stored, (1 => (1, 1)), First);
      Rasters (First) := To_Unbounded_String (Pixels);
      Disk.Save (To_String (Root), UUID_A, Stored, Rasters, Status);
      Assert (Status = Ok, "store raster before testing read exclusion");
      New_Drawing (Loaded, 8, 9);
      Loaded_Rasters (First) := To_Unbounded_String ("sentinel");
      declare
         Lock : Tx.Guard;
         Locked : Tx.Result;
         Parent : constant String := To_String (Root);
      begin
         Tx.Try_Lock (Parent, UUID_A, Lock, Locked);
         Assert (Locked = Tx.Acquired, "hold session transaction guard");
         Disk.Load (Parent, UUID_A, Loaded, Loaded_Rasters, Status);
         Assert (Status = Busy and then Extent (Loaded) = (0, 0, 8, 9)
                 and then Loaded_Rasters (First) = "sentinel",
                 "unguarded load cannot adopt a competing snapshot");
         Disk.Load_Locked (Parent, UUID_A, Loaded, Loaded_Rasters, Status);
         Assert (Status = Ok and then Loaded_Rasters (First) = Pixels
                 and then Revision_Key (Loaded, First) =
                   Revision_Key (Stored, First),
                 "guard owner restores the exact graph and original pixels");
      end;
      Disk.Load (To_String (Root), UUID_A, Loaded, Loaded_Rasters, Status);
      Assert (Status = Ok, "restore can retry after guard is released");
      Remove_Directory (Root);
   exception
      when others =>
         Remove_Directory (Root);
         raise;
   end Workspace_Read_Holds_Session_Guard;

   procedure Tiled_Recovery_Failures_Selection_And_Copy
     (T : in out Test) is
      pragma Unreferenced (T);
      use type Interfaces.C.int;
      use type GNAT.OS_Lib.File_Descriptor;
      use type Interfaces.Unsigned_64;
      Root, Tile_Path, Mismatch_Path : Unbounded_String;
      Source, Loaded, Failed : Workspace;
      Assets, Loaded_Assets, Sentinel_Assets : Disk.Raster_Set;
      Source_Tiles, Loaded_Tiles, Copy_Tiles : Disk.Tile_Set;
      First, Second : Revision_Id;
      Status : Result;
      Tile_FD : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
      Digest, Mismatch_Digest : Tile_Digest;
      Manifest, Baseline : Unbounded_String;
      Decoded_Assets : Asset_References;
      Decoded_Tiles : Tile_References;
      Requested : References (1 .. 2);
      One_Requested : References (1 .. 1);
      Rejected : Boolean := False;
   begin
      Set_Up_Directory (Root);
      Coyote_Temp_Files.Create (Tile_FD, Tile_Path);
      Assert (Tile_FD /= GNAT.OS_Lib.Invalid_FD,
              "tile fixture file is created");
      GNAT.OS_Lib.Close (Tile_FD);
      Tile_FD := GNAT.OS_Lib.Invalid_FD;
      Make_Tile_File (To_String (Tile_Path));
      Tile_FD := GNAT.OS_Lib.Open_Read_Write
        (To_String (Tile_Path), GNAT.OS_Lib.Binary);
      Assert (Tile_FD /= GNAT.OS_Lib.Invalid_FD,
              "checked 9000 by 1 tile fixture opens");
      Write_Tile (To_String (Root), UUID_A, Interfaces.C.int (Tile_FD),
                  Digest, Status);
      Assert (Status = Ok, "publish checked tiled Original");
      GNAT.OS_Lib.Close (Tile_FD);
      Tile_FD := GNAT.OS_Lib.Invalid_FD;

      Add_Originals
        (Source, (1 => (Width => 9_000, Height => 1),
                  2 => (Width => 1, Height => 1)), First);
      Second := First + 1;
      Assets (Second) := To_Unbounded_String ("rgba");
      Source_Tiles.Parent := Root;
      Source_Tiles.UUID := To_Unbounded_String (UUID_A);
      Source_Tiles.References (First) := Digest;
      Disk.Save (To_String (Root), UUID_A, Source, Assets, Source_Tiles,
                 Status);
      Assert (Status = Ok, "save mixed raster and tiled manifest");
      Read (To_String (Root), UUID_A, Manifest, Status);
      Assert (Status = Ok, "read mixed manifest");
      declare
         Temp : constant String :=
           To_String (Root) & "/" & UUID_A & ".canvas/.canvas.tmp";
         Check_FD : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
         No_Digest : Tile_Digest;
         Current : Unbounded_String;
      begin
         Ada.Directories.Create_Directory (Temp);
         Check_FD := GNAT.OS_Lib.Open_Read_Write
           (To_String (Tile_Path), GNAT.OS_Lib.Binary);
         Assert (Check_FD /= GNAT.OS_Lib.Invalid_FD, "open staged tile");
         Write_Tile (To_String (Root), UUID_A, Interfaces.C.int (Check_FD),
                     No_Digest, Status);
         Assert (Status = IO_Error and then No_Digest = NO_ASSET,
                 "blocked staging must not report a successful tile write");
         GNAT.OS_Lib.Close (Check_FD);
         Check_FD := GNAT.OS_Lib.Invalid_FD;
         Ada.Directories.Delete_Directory (Temp);
         Read (To_String (Root), UUID_A, Current, Status);
         Assert (Status = Ok and then Current = Manifest,
                 "failed tile write leaves the committed manifest unchanged");
      exception
         when others =>
            if Check_FD /= GNAT.OS_Lib.Invalid_FD then
               GNAT.OS_Lib.Close (Check_FD);
            end if;
            raise;
      end;
      Recovery.Copy (Failed, Source);
      Baseline := To_Unbounded_String (Encode (Failed));
      Rejected := False;
      begin
         Decode (To_String (Manifest), Failed, Decoded_Assets);
      exception
         when Invalid_Snapshot =>
            Rejected := True;
      end;
      Assert (Rejected and then Encode (Failed) = To_String (Baseline),
              "legacy raster-only decoder refuses tileV1 atomically");

      Disk.Load (To_String (Root), UUID_A, Failed, Sentinel_Assets, Status);
      Assert (Status = Invalid and then Encode (Failed) = To_String (Baseline),
              "legacy workspace load refuses mixed manifests atomically");

      Requested :=
        (1 => (Drawing => Drawing_Key (Source, First),
               Revision => Revision_Key (Source, First)),
         2 => (Drawing => Drawing_Key (Source, Second),
               Revision => Revision_Key (Source, Second)));
      Disk.Load_Selection
        (To_String (Root), UUID_A, Requested, Loaded, Loaded_Assets,
         Loaded_Tiles, Status);
      Assert (Status = Ok and then Count (Loaded) = 2,
              "selection restores tiled and raster Originals");
      Assert (Loaded_Assets (2) = "rgba"
              and then Loaded_Tiles.References (1) = Digest,
              "selection maps both asset kinds to destination indices");
      Recovery.Decode
        (To_String (Manifest), Failed, Decoded_Assets, Decoded_Tiles);
      Assert (Decoded_Assets (Second) /= NO_ASSET
              and then Decoded_Tiles (First) = Digest,
              "current decoder reads both manifests");

      One_Requested (1) :=
        (Drawing => Drawing_Key (Source, First),
         Revision => Revision_Key (Source, First));
      Copy_Tiles.References (First) := Digest;
      Disk.Load_Selection
        (To_String (Root), UUID_A, One_Requested, Failed, Sentinel_Assets,
         Copy_Tiles, Status);
      Assert (Status = Ok and then Count (Failed) = 1,
              "selection retains requested tiled Original only");
      Assert (Revision_Key (Failed, 1) = Revision_Key (Source, First)
              and then Copy_Tiles.References (1) = Digest,
              "selection remaps the tile to its new revision index");

      Recovery.Copy (Failed, Source);
      Baseline := To_Unbounded_String (Encode (Failed));
      Copy_Tiles := (Parent => Root,
                     UUID => To_Unbounded_String (UUID_A),
                     References => (others => NO_ASSET));
      Sentinel_Assets (First) := To_Unbounded_String ("asset-sentinel");
      Copy_Tiles.References (First) := Tile_Digest'(others => 'x');
      declare
         Tile_Pathname : constant String := To_String (Root) & "/" & UUID_A
           & ".canvas/" & Digest & ".tile";
         Byte : aliased Ada.Streams.Stream_Element := 255;
      begin
         Tile_FD := GNAT.OS_Lib.Open_Read_Write
           (Tile_Pathname, GNAT.OS_Lib.Binary);
         Assert (Tile_FD /= GNAT.OS_Lib.Invalid_FD, "open tile to corrupt");
         GNAT.OS_Lib.Lseek (Tile_FD, 16, GNAT.OS_Lib.Seek_Set);
         Assert (GNAT.OS_Lib.Write (Tile_FD, Byte'Address, 1) = 1,
                 "change one payload byte without changing asset length");
         GNAT.OS_Lib.Close (Tile_FD);
         Tile_FD := GNAT.OS_Lib.Invalid_FD;
         Disk.Load_Selection
           (To_String (Root), UUID_A, One_Requested, Failed, Sentinel_Assets,
            Copy_Tiles, Status);
         Assert (Status = Invalid and then Encode (Failed) = To_String (Baseline)
                 and then Sentinel_Assets (First) = "asset-sentinel"
                 and then Copy_Tiles.References (First) = Tile_Digest'(others => 'x'),
                 "corrupt tile rejection preserves every output");
         Ada.Directories.Delete_File (Tile_Pathname);
         Disk.Load_Selection
           (To_String (Root), UUID_A, One_Requested, Failed, Sentinel_Assets,
            Copy_Tiles, Status);
         Assert (Status = Invalid and then Encode (Failed) = To_String (Baseline)
                 and then Sentinel_Assets (First) = "asset-sentinel"
                 and then Copy_Tiles.References (First) = Tile_Digest'(others => 'x'),
                 "missing tile rejection preserves every output");
      end;
      Tile_FD := GNAT.OS_Lib.Open_Read_Write
        (To_String (Tile_Path), GNAT.OS_Lib.Binary);
      Assert (Tile_FD /= GNAT.OS_Lib.Invalid_FD,
              "reopen source tile after negative checks");
      Write_Tile (To_String (Root), UUID_A, Interfaces.C.int (Tile_FD),
                  Digest, Status);
      Assert (Status = Ok, "restore source tile after negative checks");
      GNAT.OS_Lib.Close (Tile_FD);
      Tile_FD := GNAT.OS_Lib.Invalid_FD;

      Coyote_Temp_Files.Create (Tile_FD, Mismatch_Path);
      Assert (Tile_FD /= GNAT.OS_Lib.Invalid_FD,
              "dimension-mismatch tile staging file is created");
      GNAT.OS_Lib.Close (Tile_FD);
      Tile_FD := GNAT.OS_Lib.Invalid_FD;
      Make_Tile_File (To_String (Mismatch_Path), 8_999);
      Tile_FD := GNAT.OS_Lib.Open_Read_Write
        (To_String (Mismatch_Path), GNAT.OS_Lib.Binary);
      Write_Tile (To_String (Root), UUID_A, Interfaces.C.int (Tile_FD),
                  Mismatch_Digest, Status);
      Assert (Status = Ok, "publish valid tile with mismatched dimensions");
      GNAT.OS_Lib.Close (Tile_FD);
      Tile_FD := GNAT.OS_Lib.Invalid_FD;
      declare
         Mismatched : constant String := Replace_First
           (To_String (Manifest), Digest, Mismatch_Digest);
      begin
         Assert (Mismatched /= To_String (Manifest),
                 "mismatch fixture changes the manifest digest");
         Write (To_String (Root), UUID_A, Mismatched, Status);
      end;
      Assert (Status = Ok, "publish controlled mismatched-dimension manifest");
      Disk.Load_Selection
        (To_String (Root), UUID_A, One_Requested, Failed, Sentinel_Assets,
         Copy_Tiles, Status);
      Assert (Status = Invalid and then Encode (Failed) = To_String (Baseline)
              and then Sentinel_Assets (First) = "asset-sentinel"
              and then Copy_Tiles.References (First) = Tile_Digest'(others => 'x'),
              "dimension mismatch rejection preserves every output");
      Write (To_String (Root), UUID_A, To_String (Manifest), Status);
      Assert (Status = Ok, "restore original valid manifest");
      Sentinel_Assets (First) := Null_Unbounded_String;
      Sentinel_Assets (Second) := To_Unbounded_String ("rgba");
      Copy_Tiles.References (First) := Digest;
      Copy_Tiles.Parent := Root;
      Copy_Tiles.UUID := To_Unbounded_String (UUID_A);
      Disk.Save (To_String (Root), UUID_B, Failed, Sentinel_Assets,
                 Copy_Tiles, Status);
      Assert (Status = Ok, "copy selected tile to a new UUID");
      declare
         Copy_Loaded : Workspace;
         Copy_Assets : Disk.Raster_Set;
         Copy_Read : Disk.Tile_Set;
      begin
         Disk.Load (To_String (Root), UUID_B, Copy_Loaded, Copy_Assets,
                    Copy_Read, Status);
         Assert (Status = Ok and then Copy_Read.References (1) = Digest,
                 "new UUID owns a verified copy of the selected tile");
      end;

      declare
         Header : Ada.Text_IO.File_Type;
         Report : Reclaim_Report;
      begin
         Ada.Text_IO.Create
           (Header, Ada.Text_IO.Out_File,
            To_String (Root) & "/" & UUID_A & ".jsonl");
         Ada.Text_IO.Put_Line
           (Header, "{""id"":""" & UUID_A & """,""version"":3}");
         Ada.Text_IO.Close (Header);
         Disk.Reclaim (To_String (Root), UUID_A, Orphan => False,
                       Apply => True, Report => Report, Status => Status);
         Assert (Status = Ok and then Report.Files = 1
                 and then Report.Bytes =
                   Interfaces.Unsigned_64 (16 + 8_999 * 4),
                 "mixed reclaim removes only the exact unreferenced tile");
         Disk.Load_Selection
           (To_String (Root), UUID_A, Requested, Failed, Sentinel_Assets,
            Copy_Tiles, Status);
         Assert (Status = Ok and then Copy_Tiles.References (First) = Digest
                 and then Sentinel_Assets (Second) = "rgba",
                 "mixed reclaim retains referenced tile and raster");
      end;

      Remove_Directory (Root);
      Coyote_Temp_Files.Delete (To_String (Tile_Path));
      Coyote_Temp_Files.Delete (To_String (Mismatch_Path));
   exception
      when others =>
         if Tile_FD /= GNAT.OS_Lib.Invalid_FD then
            GNAT.OS_Lib.Close (Tile_FD);
         end if;
         Coyote_Temp_Files.Delete (To_String (Tile_Path));
         Coyote_Temp_Files.Delete (To_String (Mismatch_Path));
         Remove_Directory (Root);
         raise;
   end Tiled_Recovery_Failures_Selection_And_Copy;

   package Caller is new AUnit.Test_Caller (Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test
        (Caller.Create
           ("Canvas recovery roundtrips revisions and draft",
            Roundtrip_Revisions_And_Draft'Access));
      Result.Add_Test
        (Caller.Create
           ("Canvas color versions and legacy recovery",
            Color_Version_And_Legacy_Recovery'Access));
      Result.Add_Test
        (Caller.Create
           ("Canvas deposited v5 recovery", Deposited_Version_Recovery'Access));
      Result.Add_Test
        (Caller.Create
           ("Canvas recovery resets undo and redo",
            Recovery_Clears_Undo_Redo'Access));
      Result.Add_Test
        (Caller.Create
           ("Canvas recovery rejects malformed snapshots atomically",
            Reject_Invalid_Without_Mutation'Access));
      Result.Add_Test
        (Caller.Create
           ("Canvas store reads and writes isolated snapshots",
            Disk_Read_Write_And_Isolation'Access));
      Result.Add_Test
        (Caller.Create
           ("Canvas store preserves published bytes and refuses aliases",
            Disk_Rollback_And_Unsafe_Entries'Access));
      Result.Add_Test
        (Caller.Create ("Canvas store complete workspace and stable IDs",
                        Complete_Workspace_Roundtrip'Access));
      Result.Add_Test
        (Caller.Create ("Canvas store asset failures are atomic",
                        Asset_Failures_Are_Atomic'Access));
      Result.Add_Test
        (Caller.Create ("Canvas store guards the entire workspace restore",
                        Workspace_Read_Holds_Session_Guard'Access));
      Result.Add_Test
        (Caller.Create
           ("Canvas store tiled recovery, selection, failures, and copy",
            Tiled_Recovery_Failures_Selection_And_Copy'Access));
      return Result;
   end Suite;
end Coyote_Canvas_Recovery_Tests;
