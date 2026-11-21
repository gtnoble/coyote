with Ada.Directories;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with AUnit.Assertions; use AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Coyote_Canvas.Document;
with Coyote_Canvas.Revisions;
with Coyote_Canvas.Revisions.Recovery;
with Coyote_Canvas.Store;
with GNAT.OS_Lib;
with Interfaces.C;
with System;

package body Coyote_Canvas_Recovery_Tests is
   use Coyote_Canvas.Document;
   use Coyote_Canvas.Revisions;
   use Coyote_Canvas.Revisions.Recovery;
   use Coyote_Canvas.Store;

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;
   UUID_A : constant String := "550e8400-e29b-41d4-a716-446655440000";
   UUID_B : constant String := "550e8400-e29b-41d4-a716-446655440001";

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
        ((X => Long_Float'Adjacent (3.25, 4.0), Y => 4.5, Width => 1.75));
      Points.Append ((X => 8.0, Y => 9.125, Width => 2.5));
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

      procedure Capture_Original (Points : Samples.Vector) is
      begin
         Original_Ink := Points;
      end Capture_Original;

      procedure Capture_Recovered (Points : Samples.Vector) is
      begin
         Recovered_Ink := Points;
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
              and then Samples."=" (Original_Ink, Recovered_Ink),
              "source sample coordinates round-trip without rounding");
      Assert (Encode (Restored) = To_String (Encoded),
              "strokes, exact samples, assets and states roundtrip");
   end Roundtrip_Revisions_And_Draft;

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
      for Index in 1 .. 11 loop
         case Index is
            when 1 => Bad_Data := To_Unbounded_String ("{");
            when 2 => Bad_Data := To_Unbounded_String ("{""version"":1");
            when 3 => Bad_Data := To_Unbounded_String
              (Replace_First (To_String (Baseline), """version"":1",
                              """version"":2"));
            when 4 => Bad_Data := To_Unbounded_String
              ("{""version"":1,""strokes"":[],""revisions"":[[99,[]]],"
               & """base"":1,""draft"":[]}");
            when 5 => Bad_Data := To_Unbounded_String
              ("{""version"":1,""strokes"":[],""revisions"":[[]],"
               & """base"":0,""draft"":[0,0,1,1,9,[]]}");
            when 6 => Bad_Data := To_Unbounded_String
              ("{""version"":1,""strokes"":[],""revisions"":[[]],"
               & """base"":99,""draft"":[0,0,1,1,0,[]]}");
            when 7 => Bad_Data := To_Unbounded_String
              ("{""version"":1,""strokes"":[[[1,1,1]]],"
               & """revisions"":[[0,[0,0,10,10,0,[99]]]],"
               & """base"":1,""draft"":[0,0,10,10,0,[]]}");
            when 8 => Bad_Data := To_Unbounded_String
              ("{""version"":1,""strokes"":[],""revisions"":[],"
               & """base"":0,""draft"":[[[[[[[0]]]]]]]}");
            when 9 => Bad_Data := Baseline & " {}";
            when 10 => Bad_Data := To_Unbounded_String
              (Replace_First (To_String (Baseline), """version"":1",
                              """version"":2,""version"":1"));
            when others => Bad_Data := To_Unbounded_String
              ("{""version"":1,""strokes"":[],""revisions"":["
               & "[0,[0,0,10,10,1,[]]],[1,[0,0,10,10,0,[]]]],"
               & """base"":0,""draft"":[0,0,0,0,0,[]]}");
         end case;
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
      return Result;
   end Suite;
end Coyote_Canvas_Recovery_Tests;
