--  LLM.HTTP.Curl_Binding body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Exceptions;
with Interfaces.C;

package body LLM.HTTP.Curl_Binding is

   use type System.Address;
   use type Interfaces.C.long;
   use type Code;

   function Ada_Write_Callback
     (Buffer    : System.Address;
      Size      : Size_T;
      NMemb     : Size_T;
      User_Data : System.Address)
      return Size_T
   is
      use type Interfaces.C.size_t;

      Bytes : constant Size_T := Size * NMemb;
   begin
      if User_Data = System.Null_Address then
         return 0;
      end if;

      --  Overlay Ctx on the caller's Write_Context so that any exception
      --  caught below is stored there for Perform_Request to re-raise with
      --  the real message, rather than surfacing as CURLE_WRITE_ERROR.
      declare
         Ctx : Write_Context;
         for Ctx'Address use User_Data;
         pragma Import (Ada, Ctx);
      begin
         if Bytes > 0 then
            declare
               Data : String (1 .. Natural (Bytes));
               for Data'Address use Buffer;
               pragma Import (Ada, Data);
            begin
               if Ctx.On_Chunk_Status_Address /= System.Null_Address then
                  declare
                     Easy_Handle : Handle;
                     for Easy_Handle'Address use Ctx.Handle_Address;
                     pragma Import (Ada, Easy_Handle);

                     Response : aliased Interfaces.C.long := 0;
                     Result   : constant Code :=
                       Get_Response_Code (Easy_Handle, Response'Access);
                  begin
                     if Result /= 0 then
                        raise LLM.HTTP.Curl_Error with
                          "curl_easy_getinfo(CURLINFO_RESPONSE_CODE) failed"
                          & Code'Image (Result);
                     end if;

                     declare
                        Handler : access procedure
                          (Data : String; Status : Natural);
                        for Handler'Address use
                          Ctx.On_Chunk_Status_Address;
                        pragma Import (Ada, Handler);

                        Status : constant Natural :=
                          (if Response < 0 then 0 else Natural (Response));
                     begin
                        if Handler /= null then
                           Handler.all (Data, Status);
                        end if;
                     end;
                  end;
               else
                  declare
                     Handler : access procedure (Data : String);
                     for Handler'Address use Ctx.On_Chunk_Address;
                     pragma Import (Ada, Handler);
                  begin
                     if Handler /= null then
                        Handler.all (Data);
                     end if;
                  end;
               end if;
            end;
         end if;

         return Bytes;
      exception
         when E : others =>
            Ctx.Exception_Occurred := True;
            Ctx.Exception_Message  :=
              Ada.Strings.Unbounded.To_Unbounded_String
                (Ada.Exceptions.Exception_Information (E));
            return 0;
      end;
   end Ada_Write_Callback;

end LLM.HTTP.Curl_Binding;
