with Ada.Exceptions;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Coyote_Image_Loader;
with Coyote_Image_Decoder;
with Glib.Main;
with Glib.Object;

package body Coyote_Image_Jobs is
   use Ada.Strings.Unbounded;
   use type Gdk.Pixbuf.Gdk_Pixbuf;
   use type Glib.Main.G_Source_Id;

   subtype Slot_Index is Positive range 1 .. Max_Jobs;
   subtype Worker_Index is Positive range 1 .. Max_Workers;

   type Slot_State is (Free, Queued, Running, Complete);

   type Job_Record is record
      State       : Slot_State := Free;
      Root        : Unbounded_String;
      Destination : Unbounded_String;
      Width       : Positive := 1;
      Target      : Consumer_Access := null;
      Pixbuf      : Coyote_Image_Decoder.Pixbuf_Handle :=
        Coyote_Image_Decoder.Null_Pixbuf;
      Error       : Unbounded_String;
   end record;

   type Job_Array is array (Slot_Index) of Job_Record;

   protected Jobs is
      procedure Add
        (Root        : String;
         Destination : String;
         Width       : Positive;
         Target      : not null Consumer_Access;
         Index       : out Natural);
      procedure Claim
        (Index : out Natural;
         Found : out Boolean);
      procedure Restore (Index : Slot_Index);
      procedure Fetch
        (Index       : Slot_Index;
         Root        : out Unbounded_String;
         Destination : out Unbounded_String;
         Width       : out Positive);
      procedure Finish
        (Index  : Slot_Index;
         Pixbuf : Coyote_Image_Decoder.Pixbuf_Handle;
         Error  : String);
      procedure Next_Queued
        (Index : out Natural;
         Found : out Boolean);
      procedure Read
        (Index       : Slot_Index;
         Target      : out Consumer_Access;
         Pixbuf      : out Coyote_Image_Decoder.Pixbuf_Handle;
         Error       : out Unbounded_String);
      procedure Release (Index : Slot_Index);
      function Count return Natural;
   private
      Items : Job_Array;
   end Jobs;

   protected body Jobs is
      procedure Add
        (Root        : String;
         Destination : String;
         Width       : Positive;
         Target      : not null Consumer_Access;
         Index       : out Natural)
      is
      begin
         Index := 0;
         for I in Items'Range loop
            if Items (I).State = Free then
               Items (I) :=
                 (State       => Queued,
                  Root        => To_Unbounded_String (Root),
                  Destination => To_Unbounded_String (Destination),
                  Width       => Width,
                  Target      => Target,
                  Pixbuf      => Coyote_Image_Decoder.Null_Pixbuf,
                  Error       => Null_Unbounded_String);
               Index := I;
               return;
            end if;
         end loop;
      end Add;

      procedure Claim
        (Index : out Natural;
         Found : out Boolean)
      is
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

      procedure Fetch
        (Index       : Slot_Index;
         Root        : out Unbounded_String;
         Destination : out Unbounded_String;
         Width       : out Positive)
      is
      begin
         Root        := Items (Index).Root;
         Destination := Items (Index).Destination;
         Width       := Items (Index).Width;
      end Fetch;

      procedure Finish
        (Index  : Slot_Index;
         Pixbuf : Coyote_Image_Decoder.Pixbuf_Handle;
         Error  : String)
      is
      begin
         Items (Index).Pixbuf := Pixbuf;
         Items (Index).Error  := To_Unbounded_String (Error);
         Items (Index).State  := Complete;
      end Finish;

      procedure Next_Queued
        (Index : out Natural;
         Found : out Boolean)
      is
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
      end Next_Queued;

      procedure Read
        (Index       : Slot_Index;
         Target      : out Consumer_Access;
         Pixbuf      : out Coyote_Image_Decoder.Pixbuf_Handle;
         Error       : out Unbounded_String)
      is
      begin
         Target := Items (Index).Target;
         Pixbuf := Items (Index).Pixbuf;
         Error  := Items (Index).Error;
      end Read;

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
   end Jobs;

   task type Worker is
      entry Run (Index : Slot_Index);
   end Worker;

   Workers : array (Worker_Index) of Worker;

   function Pump return Boolean;
   procedure Start_Pump;

   Pump_Active    : Boolean               := False;
   Pump_Source_Id : Glib.Main.G_Source_Id := 0;

   procedure Start_Pump is
   begin
      if not Pump_Active then
         Pump_Source_Id := Glib.Main.Timeout_Add (10, Pump'Access);
         Pump_Active := Pump_Source_Id /= 0;
         if not Pump_Active then
            raise Program_Error with "unable to register image job pump";
         end if;
      end if;
   exception
      when others =>
         Pump_Active := False;
         Pump_Source_Id := 0;
         raise;
   end Start_Pump;

   procedure Complete_With_Error
     (Index : Slot_Index;
      Error : String) is
   begin
      Jobs.Finish
        (Index, Coyote_Image_Decoder.Null_Pixbuf, Error);
   exception
      when others =>
         Jobs.Release (Index);
   end Complete_With_Error;

   procedure Submit
     (Root        : String;
      Destination : String;
      Width       : Positive;
      Target      : not null Consumer_Access)
   is
      Index : Natural;
   begin
      Jobs.Add (Root, Destination, Width, Target, Index);
      if Index = 0 then
         Target.Completed (null, "image job queue is full");
      else
         begin
            Start_Pump;
         exception
            when E : others =>
               Jobs.Release (Slot_Index (Index));
               Target.Completed
                 (null, "unable to start image job pump: "
                  & Ada.Exceptions.Exception_Message (E));
         end;
      end if;
   end Submit;

   function Pending_Count return Natural is
   begin
      return Jobs.Count;
   end Pending_Count;

   function Pump return Boolean is
      Index  : Natural;
      Found  : Boolean;
      Target : Consumer_Access;
      Pixbuf : Coyote_Image_Decoder.Pixbuf_Handle;
      Error  : Unbounded_String;
   begin
      for Worker_Id in Workers'Range loop
         Jobs.Claim (Index, Found);
         exit when not Found;
         select
            Workers (Worker_Id).Run (Slot_Index (Index));
         else
            Jobs.Restore (Slot_Index (Index));
         end select;
      end loop;

      loop
         Jobs.Next_Queued (Index, Found);
         exit when not Found;
         begin
            Jobs.Read (Slot_Index (Index), Target, Pixbuf, Error);
            declare
               Image : Gdk.Pixbuf.Gdk_Pixbuf := null;
            begin
               Image := Coyote_Image_Decoder.Adopt (Pixbuf);
               begin
                  Target.all.Completed (Image, To_String (Error));
               exception
                  when E : others =>
                     Ada.Text_IO.Put_Line
                       (Ada.Text_IO.Standard_Error,
                        "Image completion callback failed: "
                        & Ada.Exceptions.Exception_Message (E));
               end;
               if Image /= null then
                  Glib.Object.Unref (Glib.Object.GObject (Image));
               end if;
            exception
               when others =>
                  Coyote_Image_Decoder.Release (Pixbuf);
                  if Image /= null then
                     Glib.Object.Unref (Glib.Object.GObject (Image));
                  end if;
            end;
         exception
            when others =>
               Coyote_Image_Decoder.Release (Pixbuf);
         end;
         Jobs.Release (Slot_Index (Index));
      end loop;

      if Jobs.Count = 0 then
         Pump_Active := False;
         return False;
      end if;
      return True;
   exception
      when others =>
         Pump_Active := Jobs.Count > 0;
         return Pump_Active;
   end Pump;

   task body Worker is
      Job_Index : Slot_Index;
      Root      : Unbounded_String;
      Dest      : Unbounded_String;
      Width     : Positive;
      Pixbuf    : Coyote_Image_Decoder.Pixbuf_Handle :=
        Coyote_Image_Decoder.Null_Pixbuf;
      Error     : Unbounded_String;
   begin
      loop
         select
            accept Run (Index : Slot_Index) do
               Job_Index := Index;
            end Run;
            begin
               Jobs.Fetch (Job_Index, Root, Dest, Width);
               Pixbuf := Coyote_Image_Decoder.Null_Pixbuf;
               Error := Null_Unbounded_String;
               begin
                  Coyote_Image_Loader.Load_Raw
                    (To_String (Root), To_String (Dest), Width,
                     Pixbuf, Error);
               exception
                  when E : others =>
                     Coyote_Image_Decoder.Release (Pixbuf);
                     Error := To_Unbounded_String
                       (Ada.Exceptions.Exception_Message (E));
               end;
               Jobs.Finish (Job_Index, Pixbuf, To_String (Error));
            exception
               when E : others =>
                  Coyote_Image_Decoder.Release (Pixbuf);
                  Complete_With_Error
                    (Job_Index, Ada.Exceptions.Exception_Message (E));
            end;
         or
            terminate;
         end select;
      end loop;
   end Worker;

end Coyote_Image_Jobs;
