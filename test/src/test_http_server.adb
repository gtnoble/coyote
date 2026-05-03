--  Test_HTTP_Server body — in-process HTTP/1.1 mock server implementation.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Characters.Handling;
with GNAT.Sockets;

package body Test_HTTP_Server is

   use Ada.Strings.Unbounded;
   use GNAT.Sockets;

   --  CR-LF sequence used throughout HTTP/1.1 framing.
   CRLF : constant String := ASCII.CR & ASCII.LF;

   --  ── Private helpers ───────────────────────────────────────────────────

   --  Convert a non-negative integer to its decimal string without the
   --  leading space that Ada's 'Image attribute inserts.
   function Natural_Image (N : Natural) return String is
      S : constant String := Natural'Image (N);
   begin
      return S (S'First + 1 .. S'Last);
   end Natural_Image;

   --  Return the standard HTTP/1.1 reason phrase for a numeric status code.
   --  Falls back to "Unknown" for codes that are not listed here.
   function Reason_Phrase (Status : Natural) return String is
   begin
      case Status is
         when 100    => return "Continue";
         when 101    => return "Switching Protocols";
         when 200    => return "OK";
         when 201    => return "Created";
         when 202    => return "Accepted";
         when 204    => return "No Content";
         when 301    => return "Moved Permanently";
         when 302    => return "Found";
         when 304    => return "Not Modified";
         when 400    => return "Bad Request";
         when 401    => return "Unauthorized";
         when 403    => return "Forbidden";
         when 404    => return "Not Found";
         when 405    => return "Method Not Allowed";
         when 408    => return "Request Timeout";
         when 500    => return "Internal Server Error";
         when 501    => return "Not Implemented";
         when 502    => return "Bad Gateway";
         when 503    => return "Service Unavailable";
         when others => return "Unknown";
      end case;
   end Reason_Phrase;

   --  ── Get_Header ────────────────────────────────────────────────────────

   function Get_Header
     (Headers : Header_List;
      Name    : String) return String
   is
      Name_Upper : constant String :=
        Ada.Characters.Handling.To_Upper (Name);
   begin
      for HP of Headers loop
         if Ada.Characters.Handling.To_Upper
              (To_String (HP.Name)) = Name_Upper
         then
            return To_String (HP.Value);
         end if;
      end loop;
      return "";
   end Get_Header;

   --  ── Process_Request ───────────────────────────────────────────────────

   --  Read one HTTP/1.1 request from Socket, invoke Handler, then write
   --  the HTTP/1.1 response back.  Raises GNAT.Sockets.Socket_Error (or
   --  Ada.IO_Exceptions.End_Error) if the receive timeout fires or the
   --  connection drops mid-request; the caller is responsible for closing
   --  the socket.
   procedure Process_Request
     (Socket  : Socket_Type;
      Handler : not null Request_Handler)
   is
      Sock_Stream : Stream_Access := GNAT.Sockets.Stream (Socket);
      Req         : Request;
      Res         : Response;

      --  Read characters from the stream until a CR-LF pair; return the
      --  accumulated line without the terminating CR-LF.
      function Read_Line return String is
         Buffer : Unbounded_String;
         Ch     : Character;
      begin
         Read_Line_Loop : loop
            Character'Read (Sock_Stream, Ch);
            if Ch = ASCII.CR then
               Character'Read (Sock_Stream, Ch);   --  consume LF
               exit Read_Line_Loop;
            end if;
            Append (Buffer, Ch);
         end loop Read_Line_Loop;
         return To_String (Buffer);
      end Read_Line;

      --  Write a String to the socket stream one character at a time.
      procedure Put (S : String) is
      begin
         for Ch of S loop
            Character'Write (Sock_Stream, Ch);
         end loop;
      end Put;

   begin
      --  ── Parse request line ────────────────────────────────────────────
      --  Expected format: METHOD SP /path SP HTTP/1.1 CR-LF

      declare
         Line : constant String := Read_Line;
         I1   : Natural         := 0;   --  position of first space
         I2   : Natural         := 0;   --  position of second space
      begin
         Find_Spaces : for I in Line'Range loop
            if Line (I) = ' ' then
               if I1 = 0 then
                  I1 := I;
               elsif I2 = 0 then
                  I2 := I;
                  exit Find_Spaces;
               end if;
            end if;
         end loop Find_Spaces;

         --  If the request line is malformed, abandon the connection.
         if I1 = 0 or else I2 = 0 then
            GNAT.Sockets.Free (Sock_Stream);
            return;
         end if;

         Req.Method := To_Unbounded_String (Line (Line'First .. I1 - 1));
         Req.Path   := To_Unbounded_String (Line (I1 + 1 .. I2 - 1));
      end;

      --  ── Parse headers ─────────────────────────────────────────────────
      --  Read Name: Value lines until the blank line that ends the headers.

      Headers_Loop : loop
         declare
            Line : constant String := Read_Line;
         begin
            exit Headers_Loop when Line = "";

            Parse_Header : for I in Line'Range loop
               if Line (I) = ':' then
                  declare
                     HP : Header_Pair;
                     J  : Natural := I + 1;
                  begin
                     HP.Name :=
                       To_Unbounded_String (Line (Line'First .. I - 1));

                     --  Skip optional leading whitespace in the header value.
                     Skip_WS : while J <= Line'Last
                       and then Line (J) = ' '
                     loop
                        J := J + 1;
                     end loop Skip_WS;

                     HP.Value :=
                       To_Unbounded_String (Line (J .. Line'Last));
                     Req.Headers.Append (HP);
                  end;
                  exit Parse_Header;
               end if;
            end loop Parse_Header;
         end;
      end loop Headers_Loop;

      --  ── Read body ─────────────────────────────────────────────────────
      --  If a Content-Length header is present, read exactly that many bytes.

      declare
         CL_Str : constant String :=
           Get_Header (Req.Headers, "Content-Length");
      begin
         if CL_Str /= "" then
            declare
               Content_Length : constant Natural := Natural'Value (CL_Str);
               Body_Buf       : String (1 .. Content_Length);
               Ch             : Character;
            begin
               for I in 1 .. Content_Length loop
                  Character'Read (Sock_Stream, Ch);
                  Body_Buf (I) := Ch;
               end loop;
               Req.Body_Data := To_Unbounded_String (Body_Buf);
            end;
         end if;
      end;

      --  ── Dispatch to handler ───────────────────────────────────────────

      Handler (Req, Res);

      --  ── Write response ────────────────────────────────────────────────
      --  Format: status line, Content-Length, extra headers, blank line, body.

      declare
         Body_Str : constant String := To_String (Res.Body_Data);
      begin
         Put ("HTTP/1.1 " & Natural_Image (Res.Status)
              & " " & Reason_Phrase (Res.Status) & CRLF);
         Put ("Content-Length: "
              & Natural_Image (Body_Str'Length) & CRLF);
         for HP of Res.Headers loop
            Put (To_String (HP.Name) & ": "
                 & To_String (HP.Value) & CRLF);
         end loop;
         Put (CRLF);
         Put (Body_Str);
      end;

      GNAT.Sockets.Free (Sock_Stream);

   exception
      when others =>
         if Sock_Stream /= null then
            GNAT.Sockets.Free (Sock_Stream);
         end if;
         raise;
   end Process_Request;

   --  ── Server task body ──────────────────────────────────────────────────

   task body Server is

      Server_Socket : Socket_Type := No_Socket;

      --  Create the listening socket: set SO_REUSEADDR, bind to Port on
      --  all local interfaces, then activate the connection queue.
      procedure Setup_Socket (Port : Positive) is
         Addr : Sock_Addr_Type;
      begin
         Create_Socket (Server_Socket, Family_Inet, Socket_Stream);
         Set_Socket_Option
           (Server_Socket, Socket_Level,
            (Name => Reuse_Address, Enabled => True));
         Addr.Addr := Any_Inet_Addr;
         Addr.Port := Port_Type (Port);
         Bind_Socket (Server_Socket, Addr);
         Listen_Socket (Server_Socket, 5);
      end Setup_Socket;

   begin
      --  Block until the caller calls Bind.  The socket setup happens
      --  inside the rendezvous so that the entry returns only once the
      --  socket is bound and the OS accept queue is ready.
      accept Bind (Port : in Positive) do
         Setup_Socket (Port);
      end Bind;

      Main_Loop : loop

         --  Non-blocking check of the Stop entry before waiting for a
         --  connection; this ensures Stop is honoured between requests.
         select
            accept Stop;
            exit Main_Loop;
         else
            null;
         end select;

         --  Wait up to 100 ms for an incoming connection.  The short
         --  timeout keeps the loop responsive to Stop without burning
         --  CPU in a spin loop.
         declare
            Selector   : Selector_Type;
            R_Set      : Socket_Set_Type;
            W_Set      : Socket_Set_Type;
            Sel_Status : Selector_Status;
         begin
            Create_Selector (Selector);
            Empty (R_Set);
            Empty (W_Set);
            Set (R_Set, Server_Socket);
            Check_Selector (Selector, R_Set, W_Set, Sel_Status, 0.1);
            Close_Selector (Selector);

            if Sel_Status = Completed
              and then Is_Set (R_Set, Server_Socket)
            then
               declare
                  Client_Socket : Socket_Type;
                  Client_Addr   : Sock_Addr_Type;
               begin
                  Accept_Socket
                    (Server_Socket, Client_Socket, Client_Addr);

                  --  Prevent a misbehaving client from blocking the
                  --  server task indefinitely.
                  Set_Socket_Option
                    (Client_Socket, Socket_Level,
                     (Name => Receive_Timeout, Timeout => 5.0));

                  begin
                     Process_Request (Client_Socket, Handler);
                  exception
                     when others => null;
                  end;

                  Close_Socket (Client_Socket);

               exception
                  when Socket_Error => null;
               end;
            end if;
         end;

      end loop Main_Loop;

      Close_Socket (Server_Socket);

   exception
      when others =>
         if Server_Socket /= No_Socket then
            Close_Socket (Server_Socket);
         end if;
   end Server;

end Test_HTTP_Server;
