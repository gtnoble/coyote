--  LLM.Auth.Codex.Login body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Calendar;
with Ada.Exceptions;
with Ada.Streams;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNAT.Sockets;
with LLM.Auth.Codex;

package body LLM.Auth.Codex.Login is

   --  Whole browser round trip budget.
   Login_Timeout_Seconds : constant Duration := 300.0;

   protected type Login_State is
      procedure Set_Code (Code : String);
      procedure Set_Cancelled;
      function Pending_Code return String;
      function Was_Cancelled return Boolean;
   private
      Manual_Code    : Unbounded_String := Null_Unbounded_String;
      Cancelled_Flag : Boolean          := False;
   end Login_State;

   protected body Login_State is

      procedure Set_Code (Code : String) is
      begin
         Manual_Code := To_Unbounded_String (Code);
      end Set_Code;

      procedure Set_Cancelled is
      begin
         Cancelled_Flag := True;
      end Set_Cancelled;

      function Pending_Code return String is
      begin
         return To_String (Manual_Code);
      end Pending_Code;

      function Was_Cancelled return Boolean is
      begin
         return Cancelled_Flag;
      end Was_Cancelled;

   end Login_State;

   Shared_State : Login_State;

   procedure Provide_Manual_Code (Code : String) is
   begin
      Shared_State.Set_Code (Code);
   end Provide_Manual_Code;

   procedure Cancel is
   begin
      Shared_State.Set_Cancelled;
   end Cancel;

   --  Decode %XX escapes and "+" (query-string spaces) in a raw query
   --  parameter value.  Browser callbacks percent-encode code, state,
   --  and scope values; pi and opencode both consume decoded values
   --  (URLSearchParams.get) before the token exchange, and the token
   --  endpoint re-encodes the form, so sending the raw value would
   --  double-encode any escape present in the code.
   function Percent_Decode (Value : String) return String is
      function Hex (C : Character) return Natural is
      begin
         if C in '0' .. '9' then
            return Character'Pos (C) - Character'Pos ('0');
         elsif C in 'a' .. 'f' then
            return Character'Pos (C) - Character'Pos ('a') + 10;
         elsif C in 'A' .. 'F' then
            return Character'Pos (C) - Character'Pos ('A') + 10;
         else
            return 0;
         end if;
      end Hex;

      Result : Unbounded_String;
      I      : Positive := Value'First;
      Code   : Natural;
   begin
      while I <= Value'Last loop
         if Value (I) = '%' and then I + 2 <= Value'Last
           and then Value (I + 1) in '0' .. '9' | 'a' .. 'f' | 'A' .. 'F'
           and then Value (I + 2) in '0' .. '9' | 'a' .. 'f' | 'A' .. 'F'
         then
            Code := Hex (Value (I + 1)) * 16 + Hex (Value (I + 2));
            Append (Result, Character'Val (Code));
            I := I + 3;
         elsif Value (I) = '+' then
            Append (Result, ' ');
            I := I + 1;
         else
            Append (Result, Value (I));
            I := I + 1;
         end if;
      end loop;
      return To_String (Result);
   end Percent_Decode;

   function Extract_Query_Param
     (Request : String; Param : String) return String
   is
      Marker     : constant String := Param & "=";
      Marker_Pos : Natural         := 0;
      Value_Last : Natural;
   begin
      if Request'Length = 0 or else Param'Length = 0 then
         return "";
      end if;

      for I in Request'First .. Request'Last - Marker'Length + 1 loop
         if Request (I .. I + Marker'Length - 1) = Marker then
            Marker_Pos := I + Marker'Length;
            exit;
         end if;
      end loop;

      if Marker_Pos = 0 then
         return "";
      end if;

      Value_Last := Marker_Pos - 1;
      for I in Marker_Pos .. Request'Last loop
         exit when Request (I) = ' ' or else Request (I) = '&'
           or else Request (I) = ASCII.CR or else Request (I) = ASCII.LF;
         Value_Last := I;
      end loop;

      if Value_Last < Marker_Pos then
         return "";
      end if;

      return Percent_Decode (Request (Marker_Pos .. Value_Last));
   end Extract_Query_Param;

   --  Read the client's HTTP request head from the accepted socket.
   --  Returns "" on read failure or when the peer closes early.
   function Read_Request (Client : GNAT.Sockets.Socket_Type) return String is
      use GNAT.Sockets;
      use Ada.Streams;

      Buffer : Stream_Element_Array (1 .. 4_096);
      Last   : Stream_Element_Offset;
      Data   : Unbounded_String;
      Text   : Unbounded_String;
   begin
      loop
         Receive_Socket (Client, Buffer, Last);

         exit when Last < Buffer'First;

         for I in Buffer'First .. Last loop
            Append (Data, Character'Val (Natural (Buffer (I))));
         end loop;

         --  The request head ends with a blank line.  HTTP uses CRLF
         --  line endings, so the terminator is CRLF CRLF; accept a bare
         --  LF LF as well for lenient clients.
         declare
            Head : constant String := To_String (Data);
         begin
            exit when Ada.Strings.Fixed.Index
                (Head, "" & ASCII.CR & ASCII.LF & ASCII.CR & ASCII.LF)
              > 0
              or else Ada.Strings.Fixed.Index (Head, "" & ASCII.LF & ASCII.LF)
                > 0;
         end;
      end loop;

      Text := Data;
      return To_String (Text);
   exception
      when Socket_Error =>
         return To_String (Data);
   end Read_Request;

   function State_Matches (Request : String; State : String) return Boolean is
      Expected : constant String := "state=" & State;
   begin
      return Ada.Strings.Fixed.Index (Request, Expected) > 0;
   end State_Matches;

   --  Send a minimal 200 response and close.
   procedure Write_Callback_Response
     (Client : GNAT.Sockets.Socket_Type; Body_Text : String)
   is
      use GNAT.Sockets;
      use Ada.Streams;

      Content : constant String :=
        "HTTP/1.1 200 OK" & ASCII.CR & ASCII.LF & "Content-Type: text/html"
        & ASCII.CR & ASCII.LF & "Content-Length:"
        & Ada.Strings.Fixed.Trim
          (Natural'Image (Body_Text'Length), Ada.Strings.Both)
        & ASCII.CR & ASCII.LF & "Connection: close" & ASCII.CR & ASCII.LF
        & ASCII.CR & ASCII.LF & Body_Text;

      Buffer : Stream_Element_Array (1 .. Content'Length);
      Last   : Stream_Element_Offset;
   begin
      for I in Content'Range loop
         Buffer (Stream_Element_Offset (I)) :=
           Stream_Element (Character'Pos (Content (I)));
      end loop;

      GNAT.Sockets.Send_Socket (Client, Buffer, Last);
   exception
      when others =>
         null;
   end Write_Callback_Response;

   procedure Browser_Login
     (Open_Authorize_Url :     access procedure (Url : String);
      On_Progress        :     access procedure
        (Phase : Progress_Kind; Detail : String) :=
        null;
      Creds              : out LLM.Auth.Provider_Credentials)
   is
      use GNAT.Sockets;
      use type Ada.Calendar.Time;

      Verifier  : Unbounded_String;
      Challenge : Unbounded_String;
      State     : constant String := LLM.Auth.Codex.New_State;

      Server    : Socket_Type;
      Client    : Socket_Type;
      Address   : Sock_Addr_Type;
      Selector  : Selector_Type;
      Read_Set  : Socket_Set_Type;
      Status    : Selector_Status;
      Deadline  : constant Ada.Calendar.Time :=
        Ada.Calendar.Clock + Login_Timeout_Seconds;
      Authorize : Unbounded_String;

      Code     : Unbounded_String := Null_Unbounded_String;
      Got_Code : Boolean          := False;

      procedure Report (Phase : Progress_Kind; Detail : String := "") is
      begin
         if On_Progress /= null then
            On_Progress.all (Phase, Detail);
         end if;
      end Report;

   begin
      Creds := (others => <>);

      LLM.Auth.Codex.Make_Pkce (Verifier, Challenge);

      Authorize :=
        To_Unbounded_String
          (LLM.Auth.Codex.Build_Authorize_Url (To_String (Challenge), State));

      Report
        (Listening,
         "local callback port "
         & Positive'Image (LLM.Auth.Codex.Redirect_Port));

      Create_Socket (Socket => Server);
      Address :=
        GNAT.Sockets.Sock_Addr_Type'
          (Family => GNAT.Sockets.Family_Inet,
           Addr   => GNAT.Sockets.Inet_Addr (LLM.Auth.Codex.Redirect_Host),
           Port   => GNAT.Sockets.Port_Type (LLM.Auth.Codex.Redirect_Port));
           --  SO_REUSEADDR lets an immediately-retried login rebind the
           --  callback port when the previous listener ended in TIME_WAIT.
      Set_Socket_Option
        (Server,
         Socket_Level,
        (Reuse_Address,
          True));
      Bind_Socket (Server, Address);
      Listen_Socket (Server, 1);
      Create_Selector (Selector);

      if Open_Authorize_Url /= null then
         Open_Authorize_Url.all (To_String (Authorize));
      end if;
      Report (Waiting_For_Browser, To_String (Authorize));

      Wait_Loop :
      loop
         exit Wait_Loop when Got_Code;
         exit Wait_Loop when Shared_State.Was_Cancelled;
         exit Wait_Loop when Ada.Calendar.Clock > Deadline;

         --  Manual code supplied through the callback interface?
         declare
            Manual : constant String := Shared_State.Pending_Code;
         begin
            if Manual'Length > 0 then
               Code     := To_Unbounded_String (Manual);
               Got_Code := True;
               exit Wait_Loop;
            end if;
         end;

         Empty (Read_Set);
         Set (Read_Set, Server);
         Check_Selector
           (Selector     => Selector,
            R_Socket_Set => Read_Set,
            W_Socket_Set => Read_Set,
            Status       => Status,
            Timeout      => 1.0);

         if Status = Completed then
            Accept_Socket (Server, Client, Address);

            declare
               Request     : constant String := Read_Request (Client);
               Query_Code  : constant String :=
                 Extract_Query_Param (Request, "code");
               Query_Error : constant String :=
                 Extract_Query_Param (Request, "error");
            begin
               if Query_Error'Length > 0 then
                  Close_Socket (Client);
                  raise Login_Error
                    with "Authorization server returned an error: "
                    & Query_Error;
               end if;

               if Query_Code'Length > 0 and then State_Matches (Request, State)
               then
                  Code     := To_Unbounded_String (Query_Code);
                  Got_Code := True;
                  Report (Callback_Received);
               end if;

               Write_Callback_Response
                 (Client,
                  "<html><body><h2>Login complete.</h2>"
                  & "<p>You can close this window and return "
                  & "to coyote.</p></body></html>");
               Close_Socket (Client);
            end;
         elsif Status = Expired then
            null;
         else
            Close_Selector (Selector);
            raise Login_Error with "Login selector failed";
         end if;
      end loop Wait_Loop;

      Close_Socket (Server);
      Close_Selector (Selector);

      if Shared_State.Was_Cancelled and then not Got_Code then
         raise Login_Error with "Login cancelled";
      end if;

      if Ada.Calendar.Clock > Deadline and then not Got_Code then
         raise Login_Error with "Login timed out";
      end if;

      if not Got_Code then
         raise Login_Error with "No authorization code received";
      end if;

      Report (Exchanging_Token);
      LLM.Auth.Codex.Exchange_Code
        (Code                  => To_String (Code),
         Code_Verifier         => To_String (Verifier),
         Redirect_Uri_Override => "",
         Creds                 => Creds);

      if Length (Creds.Account_Id) = 0 then
         raise Login_Error
           with "OpenAI Codex access token does not carry a "
           & "chatgpt_account_id claim; sign in again";
      end if;

      LLM.Auth.Save_Credentials ("codex", Creds);
      Report (Done);
   exception
      when E : others =>
         --  Do not leak the listener on an error path: a leaked bound
         --  socket keeps the callback port unavailable for the rest of
         --  the process lifetime (Socket_Type is not controlled), so
         --  every later login would fail with Address already in use.
         begin
            if Server /= No_Socket then
               Close_Socket (Server);
            end if;
            Close_Selector (Selector);
         exception
            when others =>
               null;
         end;
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "[!] OpenAI Codex login failed: "
            & Ada.Exceptions.Exception_Message (E));
         raise;
   end Browser_Login;

end LLM.Auth.Codex.Login;
