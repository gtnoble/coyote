with Ada.Strings.Unbounded;
with Math_Syntax;
with Math_Layout;
with Math_Semantics;
with Interfaces;
with Math_Raster;
with Math_Raster_Budget;

package Coyote_Math_Jobs is
   Worker_Count : constant := 2;
   Queue_Capacity : constant := 8;
   --  Bounds retained request source accounting, not parser/layout allocations.
   Source_Ledger_Capacity : constant := 256 * 1_024 * 1_024;
   --  Queue and phase-boundary budget; does not preempt active native calls.
   Budget_Milliseconds : constant := 250;
   type Request_Id is new Natural;
   type View_Generation is new Natural;
   type Job_Status is (Pending, Valid, Invalid, Cancelled, Expired,
                       Failed, Busy, Unknown, Shared_Context_Unsupported);
   --  Monotonic elapsed times; cleanup is worker-side result disposal and
   --  completion publication, not allocator or total memory accounting.
   type Job_Timing is record
      Queue_Milliseconds : Natural := 0;
      Execution_Milliseconds : Natural := 0;
      Cleanup_Milliseconds : Natural := 0;
      Total_Milliseconds : Natural := 0;
   end record;
   type Math_Color is record
      Red, Green, Blue, Alpha : Long_Float := 0.0;
   end record;
   type Job_Result is limited private;
   type Result_Access is access all Job_Result;
   --  Start explicitly before Submit. Queue saturation returns Busy.
   --  Paused startup supports deterministic queue management before workers
   --  consume work; call Resume to enable processing.
   procedure Start (Paused : Boolean := False);
   procedure Resume;
   --  Shutdown cancels pending work, joins workers, and discards all retained
   --  jobs/results. Restart begins with an empty queue.
   procedure Shutdown;
   procedure Submit
     (Source : String; Id : out Request_Id;
      Generation : View_Generation; Style : Math_Layout.Math_Style;
      Color_Enabled : Boolean := False;
      Color : Math_Color := (others => 0.0);
      Shared_Context_Requested : Boolean := False;
      Status : out Job_Status;
      Request_Raster : Boolean := False;
      Em_Pixels : Long_Float := 16.0;
      --  Raster requests accept finite scales in (0, 256]; this directory
      --  must be supplied by a trusted caller and is never formula-derived.
      Font_Directory : String := "";
      Fleqn : Boolean := False);
   --  Fleqn affects display presentation only; formula width is unchanged.
   procedure Cancel (Id : Request_Id; Generation : View_Generation);
   --  Cancel and discard a matching request without requiring a later Poll.
   --  Completed results are freed; in-flight work is discarded on completion.
   procedure Abandon (Id : Request_Id; Generation : View_Generation);
   procedure Poll
     (Id : Request_Id; Generation : View_Generation;
      Status : out Job_Status; Item : out Result_Access);
   procedure Release (Item : in out Result_Access);
   --  Read monotonic timing without consuming the retained job result.
   procedure Timing
     (Id : Request_Id; Generation : View_Generation;
      Value : out Job_Timing; Found : out Boolean);
   function Source (Item : Job_Result) return String;
   function Id (Item : Job_Result) return Request_Id;
   function Generation (Item : Job_Result) return View_Generation;
   function Parse_Document (Item : Job_Result) return Math_Syntax.Document;
   function Layout (Item : Job_Result) return Math_Layout.Box;
   function Semantics (Item : Job_Result) return Math_Semantics.Document;
   function Error (Item : Job_Result) return String;
   function Has_Raster (Item : Job_Result) return Boolean;
   --  Retained ARGB32 output is reserved before rendering, then reconciled
   --  with actual stride. Failed results own no pixels or raster lease.
   --  This does not account for transient Cairo/parser/layout allocations.
   function Raster_Retained_Bytes (Item : Job_Result) return Natural;
   --  Peak charged Cairo image/output-vector overlap during rasterization.
   --  The pipeline metric is max(parser, raster); no overlap is implied,
   --  because parser reservations release when Parse returns. Neither metric
   --  includes retained AST/semantics/layout or whole-job allocations.
   function Raster_Workspace_Peak_Bytes (Item : Job_Result) return Natural;
   --  Parser offset-map, token and AST node record-array construction peak.
   --  It excludes nested payloads and retained AST/semantics/layout lifetime.
   function Parse_Workspace_Peak_Bytes (Item : Job_Result) return Natural;
   --  Maximum parser-construction/raster-workspace peak across those phases.
   --  This excludes other job allocations and retained result/cache lifetime.
   function Pipeline_Workspace_Peak_Bytes
     (Item : Job_Result) return Natural;
   function Raster_Width (Item : Job_Result) return Natural;
   function Raster_Height (Item : Job_Result) return Natural;
   --  Raster origins locate the logical top-left inside the full raster.
   function Raster_Origin_X (Item : Job_Result) return Natural;
   function Raster_Origin_Y (Item : Job_Result) return Natural;
   --  Baseline is measured from raster row zero, including the top origin.
   function Raster_Baseline (Item : Job_Result) return Natural;
   function Raster_Pixel
     (Item : Job_Result; X, Y : Natural) return Interfaces.Unsigned_32;
private
   type Job_Result is limited record
      Text : Ada.Strings.Unbounded.Unbounded_String;
      Job : Request_Id := 0;
      View : View_Generation := 0;
      Parsed : Math_Syntax.Document;
      Geometry : Math_Layout.Box;
      Meaning : Math_Semantics.Document;
      Pixels : Math_Raster.Image;
      Raster_Baseline_Value : Natural := 0;
      Raster_Ready : Boolean := False;
      Raster_Workspace_Peak : Natural := 0;
      Parse_Workspace_Peak : Natural := 0;
      Raster_Charge : Math_Raster_Budget.Lease;
      Message : Ada.Strings.Unbounded.Unbounded_String;
   end record;
end Coyote_Math_Jobs;
