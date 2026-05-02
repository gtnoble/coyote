--  LLM.HTTP body.
--
--  Project: pi_acme
--  For revision history, see the project version-control log.

with Interfaces.C;
with Interfaces.C.Strings;
with LLM.HTTP.Curl_Binding;
with System;

package body LLM.HTTP is

   use type Curl_Binding.Code;
   use type Curl_Binding.Handle;
   use type Curl_Binding.Slist;
   use type Interfaces.C.long;
   use type Interfaces.C.Strings.chars_ptr;

   function Curl_Message (Result : Curl_Binding.Code) return String is
      Ptr : constant Interfaces.C.Strings.chars_ptr :=
        Curl_Binding.Strerror (Result);
   begin
      if Ptr = Interfaces.C.Strings.Null_Ptr then
         return "unknown curl error";
      end if;

      return Interfaces.C.Strings.Value (Ptr);
   end Curl_Message;

   procedure Check (Result : Curl_Binding.Code; What : String) is
   begin
      if Result /= Curl_Binding.CURLE_OK then
         raise Curl_Error with What & ": " & Curl_Message (Result);
      end if;
   end Check;

   --  Package elaboration is single-threaded, so initializing libcurl here
   --  satisfies its process-wide one-time setup requirement without extra
   --  synchronization.
   procedure Initialize_Curl is
   begin
      Check
        (Curl_Binding.Global_Init (Curl_Binding.CURL_GLOBAL_DEFAULT),
         "curl_global_init");
   end Initialize_Curl;

   function Build_Slist (Headers : Header_List) return Curl_Binding.Slist is
      Result : Curl_Binding.Slist := Curl_Binding.NULL_SLIST;
   begin
      for Header of Headers.Headers loop
         declare
            Header_C : Interfaces.C.Strings.chars_ptr :=
              Interfaces.C.Strings.New_String (Header);
            Next     : constant Curl_Binding.Slist    :=
              Curl_Binding.Slist_Append (Result, Header_C);
         begin
            Interfaces.C.Strings.Free (Header_C);

            if Next = Curl_Binding.NULL_SLIST then
               if Result /= Curl_Binding.NULL_SLIST then
                  Curl_Binding.Slist_Free_All (Result);
               end if;

               raise Curl_Error with "curl_slist_append failed";
            end if;

            Result := Next;
         end;
      end loop;

      return Result;
   end Build_Slist;

   procedure Cleanup
     (H : in out Curl_Binding.Handle; Headers : in out Curl_Binding.Slist;
      URL_C     : in out Interfaces.C.Strings.chars_ptr;
      Payload_C : in out Interfaces.C.Strings.chars_ptr)
   is
   begin
      if Payload_C /= Interfaces.C.Strings.Null_Ptr then
         Interfaces.C.Strings.Free (Payload_C);
         Payload_C := Interfaces.C.Strings.Null_Ptr;
      end if;

      if URL_C /= Interfaces.C.Strings.Null_Ptr then
         Interfaces.C.Strings.Free (URL_C);
         URL_C := Interfaces.C.Strings.Null_Ptr;
      end if;

      if Headers /= Curl_Binding.NULL_SLIST then
         Curl_Binding.Slist_Free_All (Headers);
         Headers := Curl_Binding.NULL_SLIST;
      end if;

      if H /= Curl_Binding.NULL_HANDLE then
         Curl_Binding.Easy_Cleanup (H);
         H := Curl_Binding.NULL_HANDLE;
      end if;
   end Cleanup;

   procedure Perform_Request
     (URL     :     String; Headers : Header_List; Use_Post : Boolean;
      Payload : String; On_Chunk : not null access procedure (Data : String);
      Status  : out Natural)
   is
      H         : Curl_Binding.Handle            := Curl_Binding.Easy_Init;
      Header_S  : Curl_Binding.Slist             := Curl_Binding.NULL_SLIST;
      URL_C : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.Null_Ptr;
      Payload_C : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.Null_Ptr;
      Ctx : aliased Write_Context := (On_Chunk_Address => On_Chunk'Address);
      Response  : aliased Interfaces.C.long      := 0;
   begin
      if H = Curl_Binding.NULL_HANDLE then
         raise Curl_Error with "curl_easy_init failed";
      end if;

      URL_C    := Interfaces.C.Strings.New_String (URL);
      Header_S := Build_Slist (Headers);

      Check
        (Curl_Binding.Set_No_Signal (H, 1),
         "curl_easy_setopt(CURLOPT_NOSIGNAL)");
      Check (Curl_Binding.Set_URL (H, URL_C), "curl_easy_setopt(CURLOPT_URL)");

      if Header_S /= Curl_Binding.NULL_SLIST then
         Check
           (Curl_Binding.Set_Http_Header (H, Header_S),
            "curl_easy_setopt(CURLOPT_HTTPHEADER)");
      end if;

      Check
        (Curl_Binding.Set_Write_Function
           (H, Curl_Binding.Ada_Write_Callback'Access),
         "curl_easy_setopt(CURLOPT_WRITEFUNCTION)");
      Check
        (Curl_Binding.Set_Write_Data (H, Ctx'Address),
         "curl_easy_setopt(CURLOPT_WRITEDATA)");

      if Use_Post then
         Payload_C := Interfaces.C.Strings.New_String (Payload);

         Check
           (Curl_Binding.Set_Post (H, 1), "curl_easy_setopt(CURLOPT_POST)");
         Check
           (Curl_Binding.Set_Post_Fields (H, Payload_C),
            "curl_easy_setopt(CURLOPT_POSTFIELDS)");
         Check
           (Curl_Binding.Set_Post_Size (H, Interfaces.C.long (Payload'Length)),
            "curl_easy_setopt(CURLOPT_POSTFIELDSIZE)");
      end if;

      Check (Curl_Binding.Easy_Perform (H), "curl_easy_perform");
      Check
        (Curl_Binding.Get_Response_Code (H, Response'Access),
         "curl_easy_getinfo(CURLINFO_RESPONSE_CODE)");

      if Response < 0 then
         Status := 0;
      else
         Status := Natural (Response);
      end if;

      Cleanup (H, Header_S, URL_C, Payload_C);
   exception
      when others =>
         Cleanup (H, Header_S, URL_C, Payload_C);
         raise;
   end Perform_Request;

   procedure Add_Header (H : in out Header_List; Name : String; Value : String)
   is
   begin
      H.Headers.Append (Name & ": " & Value);
   end Add_Header;

   procedure Post
     (URL      :     String; Headers : Header_List; Payload : String;
      On_Chunk :     not null access procedure (Data : String);
      Status   : out Natural)
   is
   begin
      Perform_Request
        (URL => URL, Headers => Headers, Use_Post => True, Payload => Payload,
         On_Chunk => On_Chunk, Status => Status);
   end Post;

   procedure Get
     (URL      :     String; Headers : Header_List;
      On_Chunk :     not null access procedure (Data : String);
      Status   : out Natural)
   is
   begin
      Perform_Request
        (URL      => URL, Headers => Headers, Use_Post => False, Payload => "",
         On_Chunk => On_Chunk, Status => Status);
   end Get;

begin
   Initialize_Curl;
end LLM.HTTP;
