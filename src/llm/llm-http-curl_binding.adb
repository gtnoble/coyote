--  LLM.HTTP.Curl_Binding body.
--
--  Project: pi_acme
--  For revision history, see the project version-control log.

with System;

package body LLM.HTTP.Curl_Binding is

   use type System.Address;

   function Ada_Write_Callback
     (Buffer    : System.Address; Size : Size_T; NMemb : Size_T;
      User_Data : System.Address) return Size_T
   is
      use type Interfaces.C.size_t;

      Bytes : constant Size_T := Size * NMemb;
   begin
      if User_Data = System.Null_Address then
         return 0;
      end if;

      if Bytes > 0 then
         declare
            Ctx : Write_Context;
            for Ctx'Address use User_Data;
            pragma Import (Ada, Ctx);

            Handler : access procedure (Data : String);
            for Handler'Address use Ctx.On_Chunk_Address;
            pragma Import (Ada, Handler);

            Data : String (1 .. Natural (Bytes));
            for Data'Address use Buffer;
            pragma Import (Ada, Data);
         begin
            if Handler /= null then
               Handler.all (Data);
            end if;
         end;
      end if;

      return Bytes;
   exception
      when others =>
         return 0;
   end Ada_Write_Callback;

end LLM.HTTP.Curl_Binding;
