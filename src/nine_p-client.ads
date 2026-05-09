--  Nine_P.Client — synchronous 9P2000 client.
--
--  Fs and File are Limited_Controlled: the socket is closed and fids
--  are clunked automatically when the objects go out of scope.
--  No explicit Free or Close calls are required.
--
--  Typical usage:
--
--    declare
--       FS   : Nine_P.Client.Fs   := Nine_P.Client.Ns_Mount ("acme");
--       Ctl  : Nine_P.Client.File :=
--                Nine_P.Client.Open (FS'Access, "/new/ctl");
--       Data : Nine_P.Byte_Array  := Nine_P.Client.Read (Ctl'Access);
--    begin
--       ...
--    end;  --  Ctl clunked, FS socket closed here
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Finalization;
with Ada.Streams;
with Ada.Strings.Unbounded;
with GNAT.Sockets;

package Nine_P.Client is

   --  ── Fs ───────────────────────────────────────────────────────────────

   type Fs is tagged limited private;

   --  ── File ─────────────────────────────────────────────────────────────

   type File is tagged limited private;

   --  ── Connection ───────────────────────────────────────────────────────

   --  Return the plan9port namespace directory.
   --  Uses $NAMESPACE; falls back to /tmp/ns.<USER>.<DISPLAY>.
   function Namespace return String;

   --  Connect using plan9port dial(3) notation:
   --    "unix!/path/to/socket"  or  "tcp!host!port"
   function Dial (Addr  : String;
                  Aname : String := "";
                  Uname : String := "") return Fs;

   --  Connect to a named service in the plan9port namespace.
   function Ns_Mount (Name  : String;
                      Aname : String := "";
                      Uname : String := "") return Fs;

   --  ── File operations ──────────────────────────────────────────────────

   --  Walk + open a path; caller passes Fs'Access.
   --  Using Fs'Class avoids a dual-dispatch conflict between Fs and File.
   function Open (Filesystem : not null access Fs'Class;
                  Path       : String;
                  Mode       : Uint8 := O_READ) return File;

   --  Connect an already-declared (or previously disconnected) Fs to the
   --  named service in the plan9port namespace.  Equivalent to the result
   --  of Ns_Mount applied in place.  Safe to call on a default-initialised
   --  Fs (Socket = No_Socket) or on one that has already been connected
   --  and finalised.
   procedure Connect
     (Filesystem : in out Fs;
      Name       : String;
      Aname      : String := "";
      Uname      : String := "");

   --  Call Connect up to Max_Retries times, waiting Retry_Delay between
   --  attempts.  Returns normally on the first successful connection.
   --  Only P9_Error and GNAT.Sockets.Socket_Error are retried; all other
   --  exceptions propagate immediately.  Re-raises the last exception if
   --  all attempts fail.  Pass Retry_Delay => 0.0 in tests to avoid
   --  wall-clock delays.
   procedure Connect_With_Retry
     (Filesystem  : in out Fs;
      Name        : String;
      Max_Retries : Positive := 5;
      Retry_Delay : Duration := 0.0);

   --  Walk and open Path on Filesystem, storing the result in F in place.
   --  F must not currently be open (Is_Open must be False).  Raises
   --  P9_Error if the walk or open fails.
   procedure Open
     (F          : in out File;
      Filesystem : not null access Fs'Class;
      Path       : String;
      Mode       : Uint8 := O_READ);

   --  Read up to N bytes (N < 0 → read until EOF).
   --  Uses Byte_Vectors internally for chunk accumulation;
   --  returns a flat Byte_Array.
   function Read (F : not null access File'Class;
                  N : Integer := -1) return Byte_Array;

   --  Issue exactly one Tread RPC and return whatever bytes the server
   --  sends back (up to the file's IOunit).  Unlike Read, this never
   --  loops: it returns as soon as one response arrives, which is
   --  essential for pseudo-files (acme event, plumb ports) that block
   --  until data is ready but return partial results each time.
   --  Returns an empty array on EOF.
   function Read_Once (F : not null access File'Class) return Byte_Array;

   --  Write bytes; return number of bytes written.
   --  A zero-length Data still sends one Twrite message so that servers
   --  such as acme's data VFS file can act on the current addr selection
   --  (replacing it with nothing effectively deletes the addressed text).
   function Write (F    : not null access File'Class;
                   Data : Byte_Array) return Natural;

   --  Write a String as raw bytes.
   function Write (F    : not null access File'Class;
                   Data : String) return Natural;

   --  ── Stream-level framing (also useful for testing) ───────────────────

   --  Read exactly one complete 9P message from S.
   --  Reads the 4-byte little-endian size prefix first.
   function Read_Message
     (S : not null access Ada.Streams.Root_Stream_Type'Class)
     return Byte_Array;

   --  Write one complete 9P message to S.
   procedure Write_Message
     (S    : not null access Ada.Streams.Root_Stream_Type'Class;
      Data : Byte_Array);

private

   use Ada.Strings.Unbounded;

   type Fs is new Ada.Finalization.Limited_Controlled with record
      Socket   : GNAT.Sockets.Socket_Type := GNAT.Sockets.No_Socket;
      Stream   : GNAT.Sockets.Stream_Access := null;
      Next_Tag : Uint16 := 1;
      Next_Fid : Uint32 := 2;
      Root_Fid : Uint32 := 1;
      MSize    : Uint32 := 65536;
      Uname    : Unbounded_String;
   end record;

   overriding procedure Finalize (Object : in out Fs);

   type File is new Ada.Finalization.Limited_Controlled with record
      Filesystem : access Fs   := null;
      Fid        : Uint32      := 0;
      IOunit     : Natural     := 0;
      Mode       : Uint8       := O_READ;
      Offset     : Uint64      := 0;
      Is_Open    : Boolean     := False;
   end record;

   overriding procedure Finalize (Object : in out File);

end Nine_P.Client;
