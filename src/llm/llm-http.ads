--  LLM.HTTP — streaming HTTP helpers built on libcurl.
--
--  Provides simple GET and POST operations with a chunk callback suitable
--  for feeding streaming APIs such as SSE parsers.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Containers.Indefinite_Vectors;
with Ada.Strings.Unbounded;
with System;

package LLM.HTTP is

   type Header_List is limited private;

   --  Append a request header in "Name: Value" form.
   procedure Add_Header
     (H : in out Header_List; Name : String; Value : String);

   --  POST URL with a streaming response callback.
   --  On_Chunk is called for each chunk of response bytes received.
   --  Status receives the HTTP response code.
   --  Raises Curl_Error on transport or TLS failures.
   procedure Post
     (URL      :     String; Headers : Header_List; Payload : String;
      On_Chunk :     not null access procedure (Data : String);
      Status   : out Natural);

   --  GET URL with a streaming response callback.
   --  On_Chunk is called for each chunk of response bytes received.
   --  Status receives the HTTP response code.
   --  Raises Curl_Error on transport or TLS failures.
   procedure Get
     (URL      :     String; Headers : Header_List;
      On_Chunk :     not null access procedure (Data : String);
      Status   : out Natural);

   Curl_Error : exception;

private

   package Header_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type => Positive, Element_Type => String);

   type Header_List is limited record
      Headers : Header_Vectors.Vector;
   end record;

   --  Passed as CURLOPT_WRITEDATA; shared between Perform_Request and the
   --  C-convention write callback.  If the chunk handler raises an exception,
   --  the callback stores it here rather than letting libcurl see a non-zero
   --  return (which would report the uninformative CURLE_WRITE_ERROR instead).
   type Write_Context is record
      On_Chunk_Address   : System.Address                          :=
        System.Null_Address;
      Exception_Occurred : Boolean                                 := False;
      Exception_Message  : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;
   end record;

end LLM.HTTP;
