with AUnit.Assertions;
with AUnit.Test_Caller;
with Ada.Directories;
with Ada.Real_Time;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Task_Identification;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Coyote_Image_Jobs;
with Coyote_Temp_Files;
with GNAT.OS_Lib;
with Gdk.Pixbuf;
with Glib;
with Glib.Error;
with Glib.Object;
with Gtk.Main;

package body Coyote_Image_Jobs_Tests is

   use AUnit.Assertions;
   use type Ada.Task_Identification.Task_Id;
   use type Gdk.Pixbuf.Gdk_Pixbuf;
   use type Glib.Error.GError;
   use type Glib.Gint;
   use type GNAT.OS_Lib.File_Descriptor;

   type Probe is new Coyote_Image_Jobs.Consumer with record
      Calls          : Natural                         := 0;
      Successes      : Natural                         := 0;
      Failures       : Natural                         := 0;
      Rejected       : Natural                         := 0;
      Raise_Callback : Boolean                         := False;
      Caller_Task    : Ada.Task_Identification.Task_Id :=
        Ada.Task_Identification.Null_Task_Id;
      Wrong_Task     : Boolean                         := False;
   end record;

   overriding procedure Completed
     (Target : in out Probe; Pixbuf : Gdk.Pixbuf.Gdk_Pixbuf; Error : String);

   overriding procedure Completed
     (Target : in out Probe; Pixbuf : Gdk.Pixbuf.Gdk_Pixbuf; Error : String)
   is
   begin
      Target.Calls := Target.Calls + 1;
      if Ada.Task_Identification.Current_Task /= Target.Caller_Task then
         Target.Wrong_Task := True;
      end if;
      if Error = "image job queue is full" then
         Target.Rejected := Target.Rejected + 1;
      elsif Pixbuf = null then
         Target.Failures := Target.Failures + 1;
      else
         Target.Successes := Target.Successes + 1;
         Assert
           (Gdk.Pixbuf.Get_Width (Pixbuf) > 0,
            "borrowed pixbuf is usable during callback");
      end if;
      if Target.Raise_Callback then
         raise Program_Error with "intentional callback failure";
      end if;
   end Completed;

   type Probe_Array is
     array (Positive range <>)
     of aliased Probe;

   procedure Write_Bytes (Path : String; Data : String) is
      use Ada.Streams;
      use Ada.Streams.Stream_IO;
      File  : File_Type;
      Bytes : Stream_Element_Array (1 .. Stream_Element_Offset (Data'Length));
   begin
      for Index in Data'Range loop
         Bytes (Stream_Element_Offset (Index - Data'First + 1)) :=
           Stream_Element (Character'Pos (Data (Index)));
      end loop;
      Create (File, Out_File, Path);
      Write (File, Bytes);
      Close (File);
   end Write_Bytes;

   procedure Write_PNG (Path : String) is
      Pixbuf : constant Gdk.Pixbuf.Gdk_Pixbuf :=
        Gdk.Pixbuf.Gdk_New
          (Colorspace      => Gdk.Pixbuf.Colorspace_RGB,
           Has_Alpha       => True,
           Bits_Per_Sample => 8,
           Width           => 2,
           Height          => 2);
      Error  : Glib.Error.GError;
   begin
      Gdk.Pixbuf.Fill (Pixbuf, 16#FF00_FFFF#);
      Gdk.Pixbuf.Save (Pixbuf, Path, Gdk.Pixbuf.PNG, Error);
      Assert (Error = null, "PNG fixture encoded");
      if Error /= null then
         Glib.Error.Error_Free (Error);
      end if;
      Glib.Object.Unref (Glib.Object.GObject (Pixbuf));
   end Write_PNG;

   procedure Wait_For (Expected : Natural) is
      use Ada.Real_Time;
      Deadline : constant Time := Clock + Seconds (5);
   begin
      while Coyote_Image_Jobs.Pending_Count /= Expected
        and then Clock < Deadline
      loop
         declare
            Handled : Boolean;
         begin
            Handled := Gtk.Main.Main_Iteration_Do (False);
            if not Handled then
               delay 0.002;
            end if;
         end;
      end loop;
      Assert
        (Coyote_Image_Jobs.Pending_Count = Expected,
         "image jobs drain before timeout");
   end Wait_For;

   overriding procedure Set_Up (T : in out Test) is
      FD   : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
      Path : Unbounded_String;
   begin
      Coyote_Temp_Files.Create (FD, Path);
      Assert (FD /= GNAT.OS_Lib.Invalid_FD, "temporary root created");
      GNAT.OS_Lib.Close (FD);
      Ada.Directories.Delete_File (To_String (Path));
      Ada.Directories.Create_Directory (To_String (Path));
      T.Root := Path;
      Write_PNG (To_String (T.Root) & "/ok.png");
      Write_Bytes (To_String (T.Root) & "/bad.png", "not an image");
   end Set_Up;

   overriding procedure Tear_Down (T : in out Test) is
   begin
      Wait_For (0);
      Ada.Directories.Delete_Tree (To_String (T.Root));
      T.Root := Null_Unbounded_String;
   end Tear_Down;

   procedure Test_Queue_Bounds_And_Synchronous_Rejection (T : in out Test) is
      Items       : aliased Probe_Array (1 .. Coyote_Image_Jobs.Max_Jobs);
      Rejected    : aliased Probe;
      Start_Count : Natural := 0;
   begin
      for Item of Items loop
         Item.Caller_Task := Ada.Task_Identification.Current_Task;
      end loop;
      Rejected.Caller_Task := Ada.Task_Identification.Current_Task;
      for Index in Items'Range loop
         Coyote_Image_Jobs.Submit
           (To_String (T.Root),
            "missing.png",
            32,
            Items (Index)'Unchecked_Access);
      end loop;
      Start_Count := Coyote_Image_Jobs.Pending_Count;
      Assert
        (Start_Count = Coyote_Image_Jobs.Max_Jobs,
         "all 32 fixed slots are occupied before GLib pump");
      Coyote_Image_Jobs.Submit
        (To_String (T.Root), "missing.png", 32, Rejected'Unchecked_Access);
      Assert
        (Rejected.Calls = 1 and then Rejected.Rejected = 1,
         "33rd request is rejected synchronously");
      Assert
        (Coyote_Image_Jobs.Pending_Count = Start_Count,
         "queue rejection does not occupy a slot");
      Wait_For (0);
      Assert
        (not Rejected.Wrong_Task,
         "synchronous rejection runs on submitting task");
      for Index in Items'Range loop
         Assert
           (Items (Index).Calls = 1 and then Items (Index).Failures = 1,
            "accepted missing image reports one failure");
         Assert
           (not Items (Index).Wrong_Task,
            "accepted callback runs on main task");
      end loop;
   end Test_Queue_Bounds_And_Synchronous_Rejection;

   procedure Test_Success_And_Failure_Release_Capacity (T : in out Test) is
      Good : aliased Probe;
      Bad  : aliased Probe;
   begin
      Good.Caller_Task := Ada.Task_Identification.Current_Task;
      Bad.Caller_Task  := Ada.Task_Identification.Current_Task;
      Coyote_Image_Jobs.Submit
        (To_String (T.Root), "ok.png", 32, Good'Unchecked_Access);
      Coyote_Image_Jobs.Submit
        (To_String (T.Root), "bad.png", 32, Bad'Unchecked_Access);
      Wait_For (0);
      Assert
        (Good.Calls = 1 and then Good.Successes = 1,
         "valid image is delivered once");
      Assert
        (Bad.Calls = 1 and then Bad.Failures = 1,
         "invalid image is delivered once as failure");
      Assert
        (not Good.Wrong_Task and then not Bad.Wrong_Task,
         "callbacks execute on the pumping task");
      Coyote_Image_Jobs.Submit
        (To_String (T.Root), "ok.png", 32, Good'Unchecked_Access);
      Wait_For (0);
      Assert
        (Good.Calls = 2, "released success and failure slots can be reused");
   end Test_Success_And_Failure_Release_Capacity;

   procedure Test_Callback_Exception_Does_Not_Strands_Jobs (T : in out Test) is
      Raises : aliased Probe :=
        (Raise_Callback => True,
         others         => <>);
      Later  : aliased Probe;
   begin
      Raises.Caller_Task := Ada.Task_Identification.Current_Task;
      Later.Caller_Task  := Ada.Task_Identification.Current_Task;
      Coyote_Image_Jobs.Submit
        (To_String (T.Root), "ok.png", 32, Raises'Unchecked_Access);
      Coyote_Image_Jobs.Submit
        (To_String (T.Root), "ok.png", 32, Later'Unchecked_Access);
      Wait_For (0);
      Assert (Raises.Calls = 1, "raising callback was attempted exactly once");
      Assert
        (Later.Calls = 1 and then Later.Successes = 1,
         "later completion is delivered after callback exception");
   end Test_Callback_Exception_Does_Not_Strands_Jobs;

   package Caller is new AUnit.Test_Caller (Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test
        (Caller.Create
           ("Coyote.Image_Jobs bounded queue and synchronous rejection",
            Test_Queue_Bounds_And_Synchronous_Rejection'Access));
      Result.Add_Test
        (Caller.Create
           ("Coyote.Image_Jobs success, failure, and capacity reuse",
            Test_Success_And_Failure_Release_Capacity'Access));
      Result.Add_Test
        (Caller.Create
           ("Coyote.Image_Jobs callback exception recovery",
            Test_Callback_Exception_Does_Not_Strands_Jobs'Access));
      return Result;
   end Suite;

end Coyote_Image_Jobs_Tests;
