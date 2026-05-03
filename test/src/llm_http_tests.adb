with AUnit.Assertions;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with LLM.HTTP;
with Test_HTTP_Server;

package body LLM_HTTP_Tests is

   use AUnit.Assertions;

   procedure Post_With_Retry
     (URL      :     String; Headers : LLM.HTTP.Header_List;
      Payload  :     String;
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
      Response    : Unbounded_String;
      Chunk_Count : Natural           := 0;
      Headers     : LLM.HTTP.Header_List;
      Status      : Natural           := 0;

      procedure Collect (Data : String) is
      begin
         Append (Response, Data);
         Chunk_Count := Chunk_Count + 1;
      end Collect;

      procedure Post_Handler
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Res.Status := 201;
         Append (Res.Body_Data, "hello chunk");
      end Post_Handler;

      Server : Test_HTTP_Server.Server
        (Handler => Post_Handler'Unrestricted_Access);

   begin
      Server.Bind (Port);
      LLM.HTTP.Add_Header (Headers, "Content-Type", "text/plain");

      Post_With_Retry
        (URL      => "http://127.0.0.1:18765/", Headers => Headers,
         Payload  => "ping", On_Chunk => Collect'Access,
         Status   => Status);

      Server.Stop;

      Assert (Status = 201, "POST should return HTTP 201");
      Assert (Chunk_Count > 0, "POST should invoke On_Chunk at least once");
      Assert
        (To_String (Response) = "hello chunk",
         "POST response body should be collected in full");
   end Test_Post_Status_And_Chunk;

   procedure Test_Get_Status_And_Chunk (T : in out Test) is
      pragma Unreferenced (T);

      Port        : constant Positive := 18_766;
      Response    : Unbounded_String;
      Chunk_Count : Natural           := 0;
      Headers     : LLM.HTTP.Header_List;
      Status      : Natural           := 0;

      procedure Collect (Data : String) is
      begin
         Append (Response, Data);
         Chunk_Count := Chunk_Count + 1;
      end Collect;

      procedure Get_Handler
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Res.Status := 200;
         Append (Res.Body_Data, "hello get");
      end Get_Handler;

      Server : Test_HTTP_Server.Server
        (Handler => Get_Handler'Unrestricted_Access);

   begin
      Server.Bind (Port);
      LLM.HTTP.Add_Header (Headers, "Accept", "text/plain");

      Get_With_Retry
        (URL      => "http://127.0.0.1:18766/", Headers => Headers,
         On_Chunk => Collect'Access, Status => Status);

      Server.Stop;

      Assert (Status = 200, "GET should return HTTP 200");
      Assert (Chunk_Count > 0, "GET should invoke On_Chunk at least once");
      Assert
        (To_String (Response) = "hello get",
         "GET response body should be collected in full");
   end Test_Get_Status_And_Chunk;

   procedure Test_HTTP_Non_200_Returns_Status_And_Body
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Port        : constant Positive := 18_767;
      Response    : Unbounded_String;
      Chunk_Count : Natural           := 0;
      Headers     : LLM.HTTP.Header_List;
      Status      : Natural           := 0;

      procedure Collect (Data : String) is
      begin
         Append (Response, Data);
         Chunk_Count := Chunk_Count + 1;
      end Collect;

      procedure Error_Handler
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Res.Status := 400;
         Append (Res.Body_Data, "bad request");
      end Error_Handler;

      Server : Test_HTTP_Server.Server
        (Handler => Error_Handler'Unrestricted_Access);

   begin
      Server.Bind (Port);
      LLM.HTTP.Add_Header (Headers, "Content-Type", "text/plain");

      Post_With_Retry
        (URL      => "http://127.0.0.1:18767/", Headers => Headers,
         Payload  => "ping", On_Chunk => Collect'Access,
         Status   => Status);

      Server.Stop;

      Assert (Status = 400, "POST should return HTTP 400 without raising");
      Assert
        (Chunk_Count > 0,
         "POST non-200 responses should still invoke On_Chunk");
      Assert
        (To_String (Response) = "bad request",
         "POST non-200 responses should deliver the response body");
   end Test_HTTP_Non_200_Returns_Status_And_Body;

end LLM_HTTP_Tests;
