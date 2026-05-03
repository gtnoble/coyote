--  Nine_P_Mock_Server — in-process TCP 9P2000 mock server for unit tests.
--
--  Provides a Mock_Server task type that binds a real TCP port and runs
--  one Scenario_Kind against the first accepted connection without
--  spawning an external process.  Results (recorded events and any error
--  string) are returned through a Server_Result protected object so that
--  the calling test can inspect them after the server finishes.
--
--  Typical usage:
--
--    Result : aliased Nine_P_Mock_Server.Server_Result;
--    Srv    : Nine_P_Mock_Server.Mock_Server;
--    ...
--    Srv.Start (Nine_P_Mock_Server.Read_Once, Port, Result'Access);
--    --  exercise Nine_P.Client against Port here …
--    Result.Wait_Done;
--    Assert (Result.Error = "", "server error: " & Result.Error);
--    Assert (Count_Events (Result.Events, "Tread") = 1, "…");
--
--  The server socket is bound inside the Start rendezvous, so Start
--  returns only once the OS accept queue is active and the caller may
--  connect immediately.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Nine_P;

package Nine_P_Mock_Server is

   --  ── Scenario_Kind ─────────────────────────────────────────────────────
   --
   --  Selects which 9P2000 exchange sequence the server executes.

   type Scenario_Kind is
     (Read_Once,
      --  version + attach + walk + open; reply Rread("hello"); drain
      Read_Aggregate,
      --  version + attach + walk + open;
      --  reply Rread("abcd"), Rread("EFGH"), Rread(""); drain
      Write_Split,
      --  version(msize=64) + attach + walk + open; drain(allow_write)
      Read_Error,
      --  version + attach + walk + open;
      --  reply Rerror("permission denied") to Tread; drain
      Walk_Failure,
      --  version + attach; reply Rerror("file not found") to Twalk; drain
      Rversion_Fail,
      --  reply Rversion("unknown") then close
      Finalize_Clunk);
      --  version + attach + walk + open; drain (expect Tclunk pairs)

   --  ── Event_Record ──────────────────────────────────────────────────────
   --
   --  One recorded incoming 9P2000 message.  Msg_Type holds the human-
   --  readable message-kind name (e.g. "Tread").  Extra fields are
   --  populated only for the message types whose values tests need to
   --  inspect; all other fields default to zero.

   type Event_Record is record
      --  Human-readable message-kind name ("Tversion", "Tread", …).
      Msg_Type   : Ada.Strings.Unbounded.Unbounded_String;
      --  Twrite: byte offset of this write chunk within the file.
      Wr_Offset  : Nine_P.Uint64 := 0;
      --  Twrite: number of data bytes in this write chunk.
      Wr_Count   : Natural       := 0;
      --  Tclunk / Tremove / Tstat: file identifier being operated on.
      Simple_Fid : Nine_P.Uint32 := 0;
   end record;

   package Event_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Event_Record);

   --  ── Server_Result ─────────────────────────────────────────────────────
   --
   --  Protected container for the event log and optional error string
   --  produced by one Mock_Server run.  Wait_Done blocks until the server
   --  task calls Mark_Done.

   protected type Server_Result is

      --  Append a fully-populated event record to the log.
      procedure Append_Event (Rec : Event_Record);

      --  Store an error description (overwrites any previous value).
      procedure Set_Error (Msg : String);

      --  Return the complete event log accumulated so far.
      function Events return Event_Vectors.Vector;

      --  Return the error string; "" when no error has been recorded.
      function Error return String;

      --  Signal that the server task has completed its scenario.
      procedure Mark_Done;

      --  Block until Mark_Done has been called.
      entry Wait_Done;

   private
      Event_List : Event_Vectors.Vector;
      Err        : Ada.Strings.Unbounded.Unbounded_String;
      Done       : Boolean := False;
   end Server_Result;

   --  ── Mock_Server ───────────────────────────────────────────────────────
   --
   --  A task that listens on a TCP port and runs one Scenario against the
   --  first accepted connection.  Result.Mark_Done is always called when
   --  the scenario finishes, whether normally or due to an error.
   --
   --  Result is passed as a discriminant (not an entry parameter) because
   --  Ada prohibits access parameters on task entries.  The server socket
   --  is bound inside the Start rendezvous body so the entry returns only
   --  after the OS accept queue is active.

   task type Mock_Server
     (Result : not null access Server_Result)
   is

      --  Bind Port and begin the chosen Scenario.  Returns once the
      --  listening socket is ready so the caller may connect immediately.
      entry Start
        (Scenario : Scenario_Kind;
         Port     : Positive);

   end Mock_Server;

end Nine_P_Mock_Server;
