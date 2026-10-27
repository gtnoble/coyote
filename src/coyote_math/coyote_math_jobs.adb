with Ada.Exceptions;
with Ada.Real_Time;
with Ada.Strings.Unbounded;
with Ada.Unchecked_Deallocation;
with Math_Model;
with Math_Painter;
with Math_Raster;
with Math_Syntax;

package body Coyote_Math_Jobs is
   use Ada.Strings.Unbounded;
   use type Ada.Real_Time.Time;
   use type Result_Access;
   use type Math_Layout.Math_Style;
   Max_Jobs : constant := 128;
   type Slot is record
      Used, Taken, Cancelled, Done, Abandoned : Boolean := False;
      Job : Request_Id := 0;
      View : View_Generation := 0;
      Text : Unbounded_String;
      Style : Math_Layout.Math_Style := Math_Layout.Text_Style;
      Color_Enabled : Boolean := False;
      Color : Math_Color := (others => 0.0);
      Raster_Requested : Boolean := False;
      Em_Pixels : Long_Float := 16.0;
      Font_Directory : Unbounded_String;
      Deadline : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      State : Job_Status := Pending;
      Timing_Value : Job_Timing := (others => 0);
      Submitted_At : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      Started_At : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      Finished_At : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      Timing_Ready : Boolean := False;
      Value : Result_Access := null;
   end record;
   type Slot_Array is array (Positive range 1 .. Max_Jobs) of Slot;
   procedure Free_Result (Item : in out Result_Access);
   protected Control is
      procedure Begin_Run (Pause_Work : Boolean);
      procedure Enable_Work;
      procedure Add (Text : String; Id : out Request_Id;
        View : View_Generation; Style : Math_Layout.Math_Style;
        Color_Enabled : Boolean; Color : Math_Color;
        Raster_Requested : Boolean; Em_Pixels : Long_Float;
        Font_Directory : String;
        Shared : Boolean; State : out Job_Status);
      entry Take (Index : out Positive; Stop : out Boolean;
        Job : out Request_Id; View : out View_Generation;
        Text : out Unbounded_String; Style : out Math_Layout.Math_Style;
        Color_Enabled : out Boolean; Color : out Math_Color;
        Raster_Requested : out Boolean; Em_Pixels : out Long_Float;
        Font_Directory : out Unbounded_String;
        Deadline : out Ada.Real_Time.Time);
      procedure Complete (Index : Positive; Job : Request_Id;
        View : View_Generation; State : Job_Status;
        Value : Result_Access; Discard : out Result_Access);
      procedure Cancel_Job (Id : Request_Id; View : View_Generation);
      function Is_Cancelled (Id : Request_Id; View : View_Generation)
        return Boolean;
      procedure Abandon_Job (Id : Request_Id; View : View_Generation;
        Discard : out Result_Access);
      procedure Drain (Values : out Slot_Array);
      procedure Read_Job (Id : Request_Id; View : View_Generation;
        State : out Job_Status; Value : out Result_Access);
      procedure Read_Timing (Id : Request_Id; View : View_Generation;
        Value : out Job_Timing; Found : out Boolean);
      procedure Record_Cleanup (Index : Positive; Job : Request_Id;
        View : View_Generation; Elapsed : Natural);
      procedure Mark_Stop;
   private
      Items : Slot_Array;
      Next_Id : Request_Id := 0;
      Retained_Source_Bytes : Natural := 0;
      Running, Stopping, Paused : Boolean := False;
   end Control;
   protected body Control is
      procedure Begin_Run (Pause_Work : Boolean) is
      begin
         if not Running then
            Running := True;
            Stopping := False;
            Paused := Pause_Work;
            Next_Id := 0;
            Retained_Source_Bytes := 0;
            Items := (others => <>);
         end if;
      end Begin_Run;
      procedure Enable_Work is
      begin
         Paused := False;
      end Enable_Work;
      procedure Add (Text : String; Id : out Request_Id;
        View : View_Generation; Style : Math_Layout.Math_Style;
        Color_Enabled : Boolean; Color : Math_Color;
        Raster_Requested : Boolean; Em_Pixels : Long_Float;
        Font_Directory : String;
        Shared : Boolean; State : out Job_Status) is
      begin
         Id := 0;
         if Color_Enabled and then
           (not Color.Red'Valid or else not Color.Green'Valid or else
            not Color.Blue'Valid or else not Color.Alpha'Valid or else
            not (Color.Red >= 0.0 and Color.Red <= 1.0 and
              Color.Green >= 0.0 and Color.Green <= 1.0 and
              Color.Blue >= 0.0 and Color.Blue <= 1.0 and
              Color.Alpha >= 0.0 and Color.Alpha <= 1.0))
         then
            State := Invalid;
            return;
         end if;
         if Raster_Requested and then
           (not Em_Pixels'Valid or else Em_Pixels <= 0.0 or else
            Em_Pixels > 256.0 or else Font_Directory'Length = 0)
         then
            State := Invalid;
            return;
         end if;
         if not Running or Stopping or Shared or
           Text'Length > Math_Syntax.Max_Source_Bytes then
            State := (if Shared then Shared_Context_Unsupported else Busy);
            return;
         end if;
         if Text'Length > Source_Ledger_Capacity -
           Retained_Source_Bytes
         then
            State := Busy;
            return;
         end if;
         declare
            Pending_Count : Natural := 0;
         begin
            for I in Items'Range loop
               if Items (I).Used and not Items (I).Taken and
                 not Items (I).Done then
                  Pending_Count := Pending_Count + 1;
               end if;
            end loop;
            if Pending_Count >= Queue_Capacity then
               State := Busy;
               return;
            end if;
         end;
         for I in Items'Range loop
            if not Items (I).Used then
               Next_Id := Next_Id + 1;
               if Next_Id = 0 then Next_Id := 1; end if;
               declare
                  Submitted : constant Ada.Real_Time.Time :=
                    Ada.Real_Time.Clock;
               begin
                  Items (I) := (Used => True, Job => Next_Id, View => View,
                    Text => To_Unbounded_String (Text), Style => Style,
                    Color_Enabled => Color_Enabled, Color => Color,
                    Raster_Requested => Raster_Requested,
                    Em_Pixels => Em_Pixels,
                    Font_Directory => To_Unbounded_String (Font_Directory),
                    Deadline => Submitted +
                      Ada.Real_Time.Milliseconds (Budget_Milliseconds),
                    Submitted_At => Submitted,
                    State => Pending, others => <>);
               end;
               Retained_Source_Bytes := Retained_Source_Bytes + Text'Length;
               Id := Next_Id; State := Pending; return;
            end if;
         end loop;
         State := Busy;
      end Add;
      entry Take (Index : out Positive; Stop : out Boolean;
        Job : out Request_Id; View : out View_Generation;
        Text : out Unbounded_String; Style : out Math_Layout.Math_Style;
        Color_Enabled : out Boolean; Color : out Math_Color;
        Raster_Requested : out Boolean; Em_Pixels : out Long_Float;
        Font_Directory : out Unbounded_String;
        Deadline : out Ada.Real_Time.Time)
        when Stopping or else (Running and then not Paused and then
          (for some I in Items'Range => Items (I).Used and
             not Items (I).Taken and not Items (I).Done)) is
      begin
         Stop := Stopping; Index := Items'First; Job := 0; View := 0;
         Text := Null_Unbounded_String; Style := Math_Layout.Text_Style;
         Color_Enabled := False; Color := (others => 0.0);
         Raster_Requested := False;
         Em_Pixels := 16.0;
         Font_Directory := Null_Unbounded_String;
         Deadline := Ada.Real_Time.Time_First;
         if not Stop then
            for I in Items'Range loop
               if Items (I).Used and not Items (I).Taken and
                 not Items (I).Done then
                  Items (I).Taken := True; Index := I;
                  Items (I).Started_At := Ada.Real_Time.Clock;
                  Job := Items (I).Job; View := Items (I).View;
                  Text := Items (I).Text; Style := Items (I).Style;
                  Color_Enabled := Items (I).Color_Enabled;
                  Color := Items (I).Color;
                  Raster_Requested := Items (I).Raster_Requested;
                  Em_Pixels := Items (I).Em_Pixels;
                  Font_Directory := Items (I).Font_Directory;
                  Deadline := Items (I).Deadline; return;
               end if;
            end loop;
         end if;
      end Take;
      procedure Complete (Index : Positive; Job : Request_Id;
        View : View_Generation; State : Job_Status;
        Value : Result_Access; Discard : out Result_Access) is
      begin
         Discard := Value;
         if not Items (Index).Used or else Items (Index).Job /= Job or else
           Items (Index).View /= View
         then
            return;
         end if;
         Items (Index).Finished_At := Ada.Real_Time.Clock;
         Items (Index).Timing_Value.Queue_Milliseconds := Natural'Max (0,
           Integer (Ada.Real_Time.To_Duration
             (Items (Index).Started_At - Items (Index).Submitted_At) * 1_000.0));
         Items (Index).Timing_Value.Execution_Milliseconds := Natural'Max (0,
           Integer (Ada.Real_Time.To_Duration
             (Items (Index).Finished_At - Items (Index).Started_At) * 1_000.0));
         Items (Index).Timing_Value.Total_Milliseconds := Natural'Max (0,
           Integer (Ada.Real_Time.To_Duration
             (Items (Index).Finished_At - Items (Index).Submitted_At) * 1_000.0));
         Items (Index).Timing_Value.Cleanup_Milliseconds := 0;
         Items (Index).State :=
           (if Items (Index).Cancelled or Items (Index).Abandoned
            then Cancelled
            else (if Ada.Real_Time.Clock > Items (Index).Deadline
              then Expired
            else (if Items (Index).Raster_Requested and then State = Valid
              and then (Value = null or else not Value.Raster_Ready)
             then Expired else State)));
         Items (Index).Done := True;
         if Items (Index).Cancelled or Items (Index).Abandoned then
            if Items (Index).Abandoned then
               Retained_Source_Bytes := Retained_Source_Bytes -
                 Length (Items (Index).Text);
               Items (Index) := (others => <>);
            else
               Items (Index).Value := null;
            end if;
         else
            Items (Index).Value := Value;
            Discard := null;
         end if;
      end Complete;
      procedure Cancel_Job (Id : Request_Id; View : View_Generation) is
      begin
         for I in Items'Range loop
            if Items (I).Used and Items (I).Job = Id and Items (I).View = View then
               Items (I).Cancelled := True;
               if not Items (I).Taken then
                  Items (I).Done := True; Items (I).State := Cancelled;
               end if;
            end if;
         end loop;
      end Cancel_Job;
      function Is_Cancelled (Id : Request_Id; View : View_Generation)
        return Boolean is
      begin
         for I in Items'Range loop
            if Items (I).Used and Items (I).Job = Id and
              Items (I).View = View
            then
               return Items (I).Cancelled or Items (I).Abandoned;
            end if;
         end loop;
         return True;
      end Is_Cancelled;
      procedure Abandon_Job (Id : Request_Id; View : View_Generation;
        Discard : out Result_Access) is
      begin
         Discard := null;
         for I in Items'Range loop
            if Items (I).Used and Items (I).Job = Id and
              Items (I).View = View
            then
               Items (I).Cancelled := True;
               Items (I).Abandoned := True;
               if Items (I).Done then
                  Discard := Items (I).Value;
                  Retained_Source_Bytes := Retained_Source_Bytes -
                    Length (Items (I).Text);
                  Items (I) := (others => <>);
               elsif not Items (I).Taken then
                  Retained_Source_Bytes := Retained_Source_Bytes -
                    Length (Items (I).Text);
                  Items (I) := (others => <>);
               end if;
               return;
            end if;
         end loop;
      end Abandon_Job;
      procedure Drain (Values : out Slot_Array) is
      begin
         Values := Items;
         Items := (others => <>);
         Retained_Source_Bytes := 0;
         Running := False;
         Stopping := False;
         Paused := False;
      end Drain;
      procedure Read_Job (Id : Request_Id; View : View_Generation;
        State : out Job_Status; Value : out Result_Access) is
      begin
         State := Unknown; Value := null;
         for I in Items'Range loop
            if Items (I).Used and Items (I).Job = Id and Items (I).View = View then
               State := Items (I).State;
               if Items (I).Done then
                  Value := Items (I).Value;
                  Items (I).Value := null;
                  Retained_Source_Bytes := Retained_Source_Bytes -
                    Length (Items (I).Text);
                  Items (I) := (others => <>);
               end if;
               return;
            end if;
         end loop;
      end Read_Job;
      procedure Read_Timing (Id : Request_Id; View : View_Generation;
        Value : out Job_Timing; Found : out Boolean) is
      begin
         Value := (others => 0);
         Found := False;
         for I in Items'Range loop
            if Items (I).Used and Items (I).Job = Id and
              Items (I).View = View
            then
               Value := Items (I).Timing_Value;
               Found := Items (I).Timing_Ready;
               return;
            end if;
         end loop;
      end Read_Timing;
      procedure Record_Cleanup (Index : Positive; Job : Request_Id;
        View : View_Generation; Elapsed : Natural) is
      begin
         if Items (Index).Used and Items (Index).Job = Job and
           Items (Index).View = View
         then
            Items (Index).Timing_Value.Cleanup_Milliseconds := Elapsed;
            Items (Index).Timing_Value.Total_Milliseconds :=
              Items (Index).Timing_Value.Total_Milliseconds + Elapsed;
            Items (Index).Timing_Ready := True;
         end if;
      end Record_Cleanup;
      procedure Mark_Stop is
      begin
         Stopping := True;
         for I in Items'Range loop
            if Items (I).Used and not Items (I).Taken then
               Items (I).Done := True; Items (I).State := Cancelled;
            else Items (I).Cancelled := True; end if;
         end loop;
      end Mark_Stop;
   end Control;
   procedure Free_Result (Item : in out Result_Access) is
      procedure Dealloc is new Ada.Unchecked_Deallocation (Job_Result, Result_Access);
   begin if Item /= null then Dealloc (Item); end if; end Free_Result;
   task type Worker is
      pragma Storage_Size (16 * 1_024 * 1_024);
   end Worker;
   type Worker_Access is access Worker;
   procedure Dispose_Worker is new Ada.Unchecked_Deallocation
     (Worker, Worker_Access);
   Workers : array (1 .. Worker_Count) of Worker_Access := (others => null);
   task body Worker is
      Index : Positive;
      Stop : Boolean;
      Job : Request_Id;
      View : View_Generation;
      Text : Unbounded_String;
      Style : Math_Layout.Math_Style;
      Color_Enabled : Boolean;
      Color : Math_Color;
      Raster_Requested : Boolean;
      Em_Pixels : Long_Float;
      Font_Directory : Unbounded_String;
      Deadline : Ada.Real_Time.Time;
      Parse_Settings : Math_Syntax.Options;
      R : Result_Access;
      State : Job_Status;
      Discard : Result_Access;
   begin
      loop
         Control.Take
           (Index, Stop, Job, View, Text, Style, Color_Enabled, Color,
            Raster_Requested, Em_Pixels, Font_Directory, Deadline);
         exit when Stop;
         R := null;
         State := Failed;
         begin
            if Control.Is_Cancelled (Job, View) then
               State := Cancelled;
            else
               R := new Job_Result;
               R.Job := Job;
               R.View := View;
               R.Text := Text;
               Parse_Settings.Display_Mode :=
                 Style = Math_Layout.Display_Style;
               R.Parsed := Math_Syntax.Parse
                 (To_String (Text), Parse_Settings);
               if Math_Syntax.Is_Valid (R.Parsed) then
                  R.Meaning := Math_Semantics.Project (R.Parsed);
                  R.Geometry := Math_Layout.Build (R.Parsed, Style);
                  if Color_Enabled then
                     for I in R.Geometry.Commands.First_Index ..
                       R.Geometry.Commands.Last_Index
                     loop
                        declare
                           Command : Math_Layout.Draw_Command :=
                             R.Geometry.Commands (I);
                        begin
                           if not Command.Has_Color then
                              Command.Has_Color := True;
                              Command.Red := Color.Red;
                              Command.Green := Color.Green;
                              Command.Blue := Color.Blue;
                              Command.Alpha := Color.Alpha;
                              R.Geometry.Commands.Replace_Element (I, Command);
                           end if;
                        end;
                     end loop;
                  end if;
                  if not Math_Semantics.Is_Valid (R.Meaning) then
                     R.Message := To_Unbounded_String
                       (Math_Semantics.Error (R.Meaning));
                  end if;
                  State := (if R.Geometry.Valid and then
                    Math_Semantics.Is_Valid (R.Meaning) then Valid else Invalid);
                  if State = Valid and then Raster_Requested and then
                    Ada.Real_Time.Clock <= Deadline
                  then
                     declare
                        Fonts : Math_Painter.Font_Set;
                        Foreground : Math_Model.Color_Value :=
                          (Alpha => 1.0, others => 0.0);
                     begin
                        if Color_Enabled then
                           Foreground :=
                             (Red => Color.Red, Green => Color.Green,
                              Blue => Color.Blue, Alpha => Color.Alpha);
                        end if;
                        Math_Painter.Load
                          (Fonts, To_String (Font_Directory));
                        R.Pixels := Math_Raster.Render
                          (Fonts, R.Geometry, Em_Pixels, Foreground);
                        R.Raster_Baseline_Value := Natural
                          (Long_Float'Ceiling
                             (R.Geometry.Ascent * Em_Pixels));
                        R.Raster_Ready := True;
                     end;
                  end if;
               else
                  R.Message := To_Unbounded_String
                    (Math_Syntax.Error (R.Parsed));
                  State := Invalid;
               end if;
               if Ada.Real_Time.Clock > Deadline
               then
                  State := Expired;
               elsif Raster_Requested and then State = Valid and then
                 not R.Raster_Ready
               then
                  State := Expired;
               end if;
            end if;
         exception
            when E : others =>
               if R /= null then
                  R.Message := To_Unbounded_String
                    (Ada.Exceptions.Exception_Message (E));
               end if;
               State := Failed;
         end;
         begin
            declare
               Cleanup_Start : constant Ada.Real_Time.Time :=
                 Ada.Real_Time.Clock;
            begin
            Control.Complete (Index, Job, View, State, R, Discard);
            R := null;
            Free_Result (Discard);
            Control.Record_Cleanup
              (Index, Job, View, Natural'Max (0,
                 Integer (Ada.Real_Time.To_Duration
                   (Ada.Real_Time.Clock - Cleanup_Start) * 1_000.0)));
         exception
            when others =>
               Free_Result (R);
               Free_Result (Discard);
               raise;
         end;
         end;
      end loop;
   end Worker;
   procedure Start (Paused : Boolean := False) is
   begin
      Control.Begin_Run (Paused);
      for I in Workers'Range loop
         if Workers (I) = null then Workers (I) := new Worker; end if;
      end loop;
   end Start;

   procedure Resume is
   begin
      Control.Enable_Work;
   end Resume;
   procedure Shutdown is
      Orphans : Slot_Array;
   begin
      Control.Mark_Stop;
      for I in Workers'Range loop
         if Workers (I) /= null then
            while not Workers (I)'Terminated loop
               delay 0.001;
            end loop;
            Dispose_Worker (Workers (I));
         end if;
      end loop;
      Control.Drain (Orphans);
      for I in Orphans'Range loop
         Free_Result (Orphans (I).Value);
      end loop;
   end Shutdown;
   procedure Submit (Source : String; Id : out Request_Id;
      Generation : View_Generation; Style : Math_Layout.Math_Style;
      Color_Enabled : Boolean := False; Color : Math_Color := (others => 0.0);
      Shared_Context_Requested : Boolean := False; Status : out Job_Status;
      Request_Raster : Boolean := False; Em_Pixels : Long_Float := 16.0;
      Font_Directory : String := "") is
   begin
      Control.Add
        (Source, Id, Generation, Style, Color_Enabled, Color,
         Request_Raster, Em_Pixels, Font_Directory,
         Shared_Context_Requested, Status);
   end Submit;
   procedure Cancel (Id : Request_Id; Generation : View_Generation) is
   begin Control.Cancel_Job (Id, Generation); end Cancel;
   procedure Abandon (Id : Request_Id; Generation : View_Generation) is
      Discard : Result_Access;
   begin
      Control.Abandon_Job (Id, Generation, Discard);
      Free_Result (Discard);
   end Abandon;
   procedure Poll (Id : Request_Id; Generation : View_Generation;
      Status : out Job_Status; Item : out Result_Access) is
   begin Control.Read_Job (Id, Generation, Status, Item); end Poll;
   procedure Release (Item : in out Result_Access) is begin Free_Result (Item); end Release;
   procedure Timing (Id : Request_Id; Generation : View_Generation;
      Value : out Job_Timing; Found : out Boolean) is
   begin
      Control.Read_Timing (Id, Generation, Value, Found);
   end Timing;
   function Source (Item : Job_Result) return String is (To_String (Item.Text));
   function Id (Item : Job_Result) return Request_Id is (Item.Job);
   function Generation (Item : Job_Result) return View_Generation is (Item.View);
   function Parse_Document (Item : Job_Result) return Math_Syntax.Document is (Item.Parsed);
   function Layout (Item : Job_Result) return Math_Layout.Box is (Item.Geometry);
   function Semantics (Item : Job_Result) return Math_Semantics.Document is (Item.Meaning);
   function Error (Item : Job_Result) return String is (To_String (Item.Message));
   function Has_Raster (Item : Job_Result) return Boolean is
     (Item.Raster_Ready);
   function Raster_Width (Item : Job_Result) return Natural is
     (Math_Raster.Width (Item.Pixels));
   function Raster_Height (Item : Job_Result) return Natural is
     (Math_Raster.Height (Item.Pixels));
   function Raster_Baseline (Item : Job_Result) return Natural is
     (Item.Raster_Baseline_Value);
   function Raster_Pixel
     (Item : Job_Result; X, Y : Natural) return Interfaces.Unsigned_32 is
     (Math_Raster.Get_Pixel (Item.Pixels, X, Y));
end Coyote_Math_Jobs;
