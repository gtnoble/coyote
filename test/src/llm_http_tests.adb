with AUnit.Assertions;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with GNATCOLL.OS.Process;   use GNATCOLL.OS.Process;
with LLM.HTTP;

package body LLM_HTTP_Tests is

   use AUnit.Assertions;

   function Natural_Image (Value : Natural) return String is
      Image : constant String := Natural'Image (Value);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end Natural_Image;

   function Post_Server_Script (Port : Positive) return String is
   begin
      return
        "import http.server" & ASCII.LF & "class S(http.server.HTTPServer):" &
        ASCII.LF & "    allow_reuse_address = True" & ASCII.LF &
        "class H(http.server.BaseHTTPRequestHandler):" & ASCII.LF &
        "    def do_POST(self):" & ASCII.LF &
        "        self.send_response(201)" & ASCII.LF &
        "        self.send_header('Content-Length', '11')" & ASCII.LF &
        "        self.end_headers()" & ASCII.LF &
        "        self.wfile.write(b'hello ')" & ASCII.LF &
        "        self.wfile.flush()" & ASCII.LF &
        "        self.wfile.write(b'chunk')" & ASCII.LF &
        "        self.wfile.flush()" & ASCII.LF &
        "    def log_message(self, *a): pass" & ASCII.LF &
        "s = S(('127.0.0.1', " & Natural_Image (Port) & "), H)" & ASCII.LF &
        "s.timeout = 3" & ASCII.LF & "s.handle_request()" & ASCII.LF &
        "s.server_close()" & ASCII.LF;
   end Post_Server_Script;

   function Get_Server_Script (Port : Positive) return String is
   begin
      return
        "import http.server" & ASCII.LF & "class S(http.server.HTTPServer):" &
        ASCII.LF & "    allow_reuse_address = True" & ASCII.LF &
        "class H(http.server.BaseHTTPRequestHandler):" & ASCII.LF &
        "    def do_GET(self):" & ASCII.LF &
        "        self.send_response(200)" & ASCII.LF &
        "        self.send_header('Content-Length', '9')" & ASCII.LF &
        "        self.end_headers()" & ASCII.LF &
        "        self.wfile.write(b'hello get')" & ASCII.LF &
        "        self.wfile.flush()" & ASCII.LF &
        "    def log_message(self, *a): pass" & ASCII.LF &
        "s = S(('127.0.0.1', " & Natural_Image (Port) & "), H)" & ASCII.LF &
        "s.timeout = 3" & ASCII.LF & "s.handle_request()" & ASCII.LF &
        "s.server_close()" & ASCII.LF;
   end Get_Server_Script;

   function Spawn_Server (Script : String) return Process_Handle is
      Args : Argument_List;
   begin
      Args.Append ("python3");
      Args.Append ("-u");
      Args.Append ("-c");
      Args.Append (Script);

      return Start (Args => Args);
   end Spawn_Server;

   procedure Post_With_Retry
     (URL      :     String; Headers : LLM.HTTP.Header_List; Payload : String;
      On_Chunk :     not null access procedure (Data : String);
      Status   : out Natural)
   is
   begin
      Retry_Loop :
      for Attempt in 1 .. 20 loop
         begin
            LLM.HTTP.Post
              (URL      => URL, Headers => Headers, Payload => Payload,
               On_Chunk => On_Chunk, Status => Status);
            exit Retry_Loop;
         exception
            when LLM.HTTP.Curl_Error =>
               if Attempt = 20 then
                  raise;
               end if;

               delay 0.05;
         end;
      end loop Retry_Loop;
   end Post_With_Retry;

   procedure Get_With_Retry
     (URL      :     String; Headers : LLM.HTTP.Header_List;
      On_Chunk :     not null access procedure (Data : String);
      Status   : out Natural)
   is
   begin
      Retry_Loop :
      for Attempt in 1 .. 20 loop
         begin
            LLM.HTTP.Get
              (URL    => URL, Headers => Headers, On_Chunk => On_Chunk,
               Status => Status);
            exit Retry_Loop;
         exception
            when LLM.HTTP.Curl_Error =>
               if Attempt = 20 then
                  raise;
               end if;

               delay 0.05;
         end;
      end loop Retry_Loop;
   end Get_With_Retry;

   procedure Test_Post_Status_And_Chunk (T : in out Test) is
      pragma Unreferenced (T);

      Port        : constant Positive := 18_765;
      Handle      : Process_Handle    := Invalid_Handle;
      Response    : Unbounded_String;
      Chunk_Count : Natural           := 0;
      Headers     : LLM.HTTP.Header_List;
      Status      : Natural           := 0;

      procedure Collect (Data : String) is
      begin
         Append (Response, Data);
         Chunk_Count := Chunk_Count + 1;
      end Collect;
   begin
      Handle := Spawn_Server (Post_Server_Script (Port));
      LLM.HTTP.Add_Header (Headers, "Content-Type", "text/plain");

      Post_With_Retry
        (URL     => "http://127.0.0.1:18765/", Headers => Headers,
         Payload => "ping", On_Chunk => Collect'Access, Status => Status);

      declare
         Exit_Code : constant Integer := Wait (Handle);
         pragma Unreferenced (Exit_Code);
      begin
         null;
      end;

      Assert (Status = 201, "POST should return HTTP 201");
      Assert (Chunk_Count > 0, "POST should invoke On_Chunk at least once");
      Assert
        (To_String (Response) = "hello chunk",
         "POST response body should be collected in full");
   end Test_Post_Status_And_Chunk;

   procedure Test_Get_Status_And_Chunk (T : in out Test) is
      pragma Unreferenced (T);

      Port        : constant Positive := 18_766;
      Handle      : Process_Handle    := Invalid_Handle;
      Response    : Unbounded_String;
      Chunk_Count : Natural           := 0;
      Headers     : LLM.HTTP.Header_List;
      Status      : Natural           := 0;

      procedure Collect (Data : String) is
      begin
         Append (Response, Data);
         Chunk_Count := Chunk_Count + 1;
      end Collect;
   begin
      Handle := Spawn_Server (Get_Server_Script (Port));
      LLM.HTTP.Add_Header (Headers, "Accept", "text/plain");

      Get_With_Retry
        (URL      => "http://127.0.0.1:18766/", Headers => Headers,
         On_Chunk => Collect'Access, Status => Status);

      declare
         Exit_Code : constant Integer := Wait (Handle);
         pragma Unreferenced (Exit_Code);
      begin
         null;
      end;

      Assert (Status = 200, "GET should return HTTP 200");
      Assert (Chunk_Count > 0, "GET should invoke On_Chunk at least once");
      Assert
        (To_String (Response) = "hello get",
         "GET response body should be collected in full");
   end Test_Get_Status_And_Chunk;

end LLM_HTTP_Tests;
