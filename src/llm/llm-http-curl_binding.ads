--  LLM.HTTP.Curl_Binding — thin Ada import layer over libcurl easy API.
--
--  Exposes the subset of libcurl needed by LLM.HTTP plus the exported
--  Ada write callback used for streaming response chunks back into Ada.
--
--  Project: pi_acme
--  For revision history, see the project version-control log.

with Interfaces.C;
with Interfaces.C.Strings;
with System;

package LLM.HTTP.Curl_Binding is

   subtype Size_T is Interfaces.C.size_t;
   subtype Code is Interfaces.C.int;

   type Handle is new System.Address;
   type Slist is new System.Address;

   NULL_HANDLE         : constant Handle            :=
     Handle (System.Null_Address);
   NULL_SLIST          : constant Slist             :=
     Slist (System.Null_Address);
   CURLE_OK            : constant Code              := 0;
   CURL_GLOBAL_DEFAULT : constant Interfaces.C.long := 3;

   --  C-convention write callback type.
   type Write_Func is
     access function
       (Buffer    : System.Address; Size : Size_T; NMemb : Size_T;
        User_Data : System.Address) return Size_T with
     Convention => C;

   --  Process-wide libcurl initialization.
   function Global_Init (Flags : Interfaces.C.long) return Code with
     Import, Convention => C, External_Name => "curl_global_init";

   procedure Global_Cleanup with
     Import, Convention => C, External_Name => "curl_global_cleanup";

   --  curl easy API.
   function Easy_Init return Handle with
     Import, Convention => C, External_Name => "curl_easy_init";

   procedure Easy_Cleanup (H : Handle) with
     Import, Convention => C, External_Name => "curl_easy_cleanup";

   function Easy_Perform (H : Handle) return Code with
     Import, Convention => C, External_Name => "curl_easy_perform";

   --  Non-variadic setopt/getinfo wrappers implemented in thin_curl.c.
   function Set_URL
     (H : Handle; V : Interfaces.C.Strings.chars_ptr) return Code with
     Import, Convention => C, External_Name => "curl_set_url";

   function Set_Post (H : Handle; V : Interfaces.C.long) return Code with
     Import, Convention => C, External_Name => "curl_set_post";

   function Set_Post_Fields
     (H : Handle; V : Interfaces.C.Strings.chars_ptr) return Code with
     Import, Convention => C, External_Name => "curl_set_postfields";

   function Set_Post_Size (H : Handle; V : Interfaces.C.long) return Code with
     Import, Convention => C, External_Name => "curl_set_postfieldsize";

   function Set_Http_Header (H : Handle; V : Slist) return Code with
     Import, Convention => C, External_Name => "curl_set_httpheader";

   function Set_Write_Function (H : Handle; V : Write_Func) return Code with
     Import, Convention => C, External_Name => "curl_set_writefunction";

   function Set_Write_Data (H : Handle; V : System.Address) return Code with
     Import, Convention => C, External_Name => "curl_set_writedata";

   function Set_No_Signal (H : Handle; V : Interfaces.C.long) return Code with
     Import, Convention => C, External_Name => "curl_set_nosignal";

   function Get_Response_Code
     (H : Handle; Out_Code : access Interfaces.C.long) return Code with
     Import, Convention => C, External_Name => "curl_get_response_code";

   --  curl_slist helpers for request headers.
   function Slist_Append
     (L : Slist; S : Interfaces.C.Strings.chars_ptr) return Slist with
     Import, Convention => C, External_Name => "curl_slist_append";

   procedure Slist_Free_All (L : Slist) with
     Import, Convention => C, External_Name => "curl_slist_free_all";

   function Strerror (C : Code) return Interfaces.C.Strings.chars_ptr with
     Import, Convention => C, External_Name => "curl_easy_strerror";

   --  The single library-level C-convention write callback.
   --  User_Data must point to an LLM.HTTP.Write_Context value.
   function Ada_Write_Callback
     (Buffer    : System.Address; Size : Size_T; NMemb : Size_T;
      User_Data : System.Address) return Size_T with
     Export, Convention => C, External_Name => "ada_curl_write_cb";

end LLM.HTTP.Curl_Binding;
