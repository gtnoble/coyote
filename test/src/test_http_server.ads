--  Test_HTTP_Server — in-process HTTP/1.1 mock server for unit tests.
--
--  Provides a Server task type and associated request/response record
--  types so that unit tests can stand up a real TCP listener without
--  spawning an external process.  A caller-supplied Request_Handler
--  callback receives each parsed HTTP/1.1 request and fills in a
--  Response that the server sends back to the client.
--
--  Typical usage:
--
--    procedure My_Handler (Req :     Test_HTTP_Server.Request;
--                          Res : out Test_HTTP_Server.Response) is
--    begin
--       Res.Status := 200;
--       Ada.Strings.Unbounded.Append (Res.Body_Data, "hello");
--    end My_Handler;
--
--    S : Test_HTTP_Server.Server (My_Handler'Access);
--    ...
--    S.Bind (8080);   --  socket bound and listening on return
--    ...              --  exercise client under test
--    S.Stop;          --  accept loop exits after current request
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

package Test_HTTP_Server is

   use Ada.Strings.Unbounded;

   --  ── Header collection ─────────────────────────────────────────────────

   --  A single HTTP header name/value pair.
   type Header_Pair is record
      Name  : Unbounded_String;
      Value : Unbounded_String;
   end record;

   package Header_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Header_Pair);

   --  Ordered list of header name/value pairs.  Any Header_Vectors.Vector
   --  operation (Append, Iterate, …) may be used directly; Get_Header
   --  provides a convenient case-insensitive lookup by name.
   subtype Header_List is Header_Vectors.Vector;

   --  Return the value of the first header in Headers whose name compares
   --  equal to Name under a case-insensitive ASCII comparison.
   --  Returns "" when no matching header is found.
   function Get_Header
     (Headers : Header_List;
      Name    : String) return String;

   --  ── Request ───────────────────────────────────────────────────────────

   --  Parsed representation of an incoming HTTP/1.1 request.
   --  Body_Data is populated from the entity body when a Content-Length
   --  header is present; otherwise it is empty.
   type Request is record
      Method    : Unbounded_String;
      Path      : Unbounded_String;
      Headers   : Header_List;
      Body_Data : Unbounded_String;
   end record;

   --  ── Response ──────────────────────────────────────────────────────────

   --  The HTTP/1.1 response that the handler wishes to send.
   --  Content-Length is computed automatically from Body_Data; callers
   --  do not need to add it to Headers.
   type Response is record
      Status    : Natural := 200;
      Headers   : Header_List;
      Body_Data : Unbounded_String;
   end record;

   --  ── Handler callback ──────────────────────────────────────────────────

   --  Called synchronously from the server task for each accepted request.
   --  The procedure must populate Res before returning.
   type Request_Handler is access procedure
     (Req :     Request;
      Res : out Response);

   --  ── Server task type ──────────────────────────────────────────────────

   --  A task that listens for TCP connections on a caller-chosen port and
   --  dispatches each HTTP/1.1 request to Handler.  The task type (not a
   --  singleton) allows multiple independent server instances to coexist
   --  within a single test run.
   task type Server (Handler : not null Request_Handler) is

      --  Bind a listening socket to Port and begin accepting connections.
      --  Returns only after the socket is bound and the OS accept queue
      --  is active, so callers may connect immediately after this entry
      --  returns.
      entry Bind (Port : Positive);

      --  Signal the accept loop to exit.  If a request is currently being
      --  processed, the loop completes that request before stopping.
      entry Stop;

   end Server;

end Test_HTTP_Server;
