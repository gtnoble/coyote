--  LLM.Auth.Codex body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Calendar;
with Ada.Characters.Handling;
with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Numerics.Discrete_Random;
with Ada.Streams;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNATCOLL.JSON;
with Interfaces;
use type Interfaces.Unsigned_32;
with LLM.HTTP;
with SHA2;

package body LLM.Auth.Codex is

   use type GNATCOLL.JSON.JSON_Value_Type;

   --  Byte value used for random PKCE and state material.
   type Random_Byte_Type is mod 256;

   package Byte_Random is new Ada.Numerics.Discrete_Random
     (Random_Byte_Type);

   protected type Refresh_Mutex is
      entry Acquire;
      procedure Release;
   private
      Busy : Boolean := False;
   end Refresh_Mutex;

   protected body Refresh_Mutex is

      entry Acquire when not Busy is
      begin
         Busy := True;
      end Acquire;

      procedure Release is
      begin
         Busy := False;
      end Release;

   end Refresh_Mutex;

   Guard : Refresh_Mutex;

   function Random_Byte return Ada.Streams.Stream_Element is
      Generator : Byte_Random.Generator;
      Value     : Random_Byte_Type;
   begin
      --  Reset per call so distinct material does not share a
      --  deterministic sequence position.
      Byte_Random.Reset (Generator);
      Value := Byte_Random.Random (Generator);
      return Ada.Streams.Stream_Element (Random_Byte_Type'Pos (Value));
   end Random_Byte;

   function Current_Unix_Ms return Long_Long_Integer is
      use Ada.Calendar;

      Epoch : constant Time :=
        Time_Of
          (Year    => 1970,
           Month   => 1,
           Day     => 1,
           Seconds => 0.0);
   begin
      return Long_Long_Integer ((Clock - Epoch) * 1000.0);
   end Current_Unix_Ms;

   function Token_Endpoint return String is
   begin
      if Ada.Environment_Variables.Exists ("COYOTE_CODEX_TOKEN_URL") then
         declare
            Value : constant String :=
              Ada.Environment_Variables.Value ("COYOTE_CODEX_TOKEN_URL");
         begin
            if Value'Length > 0 then
               return Value;
            end if;
         end;
      end if;
      return Token_Url;
   end Token_Endpoint;

   function Hex_Digit (Value : Natural) return Character is
   begin
      if Value < 10 then
         return Character'Val (Character'Pos ('0') + Value);
      else
         return Character'Val (Character'Pos ('a') + Value - 10);
      end if;
   end Hex_Digit;

   function Byte_Hex
     (Value : Ada.Streams.Stream_Element) return String is
      Uns : constant Natural :=
        Natural (Ada.Streams.Stream_Element'Pos (Value));
   begin
      return ""
        & Hex_Digit (Uns / 16) & Hex_Digit (Uns mod 16);
   end Byte_Hex;

   function Base64url_Encode
     (Data : Ada.Streams.Stream_Element_Array) return String
   is
      --  Base64 alphabet with URL-safe substitutions and no padding.
      Alphabet  : constant String :=
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
      Result    : Unbounded_String;
      Group     : array (0 .. 2) of Natural := (others => 0);
      Group_Len : Natural := 0;
   begin
      for Byte_Value of Data loop
         Group (Group_Len) := Natural (Byte_Value);
         Group_Len := Group_Len + 1;

         if Group_Len = 3 then
            Append (Result, Alphabet (Group (0) / 4 + Alphabet'First));
            Append
              (Result,
               Alphabet
                 ((Group (0) mod 4) * 16 + Group (1) / 16
                  + Alphabet'First));
            Append
              (Result,
               Alphabet
                 ((Group (1) mod 16) * 4 + Group (2) / 64
                  + Alphabet'First));
            Append (Result, Alphabet (Group (2) mod 64 + Alphabet'First));
            Group := (others => 0);
            Group_Len := 0;
         end if;
      end loop;

      if Group_Len = 1 then
         Append (Result, Alphabet (Group (0) / 4 + Alphabet'First));
         Append
           (Result,
            Alphabet ((Group (0) mod 4) * 16 + Alphabet'First));
      elsif Group_Len = 2 then
         Append (Result, Alphabet (Group (0) / 4 + Alphabet'First));
         Append
           (Result,
            Alphabet
              ((Group (0) mod 4) * 16 + Group (1) / 16
               + Alphabet'First));
         Append
           (Result,
            Alphabet ((Group (1) mod 16) * 4 + Alphabet'First));
      end if;

      return To_String (Result);
   end Base64url_Encode;

   function Base64_Value (Char : Character) return Natural is
   begin
      case Char is
         when 'A' .. 'Z' =>
            return Character'Pos (Char) - Character'Pos ('A');
         when 'a' .. 'z' =>
            return Character'Pos (Char) - Character'Pos ('a') + 26;
         when '0' .. '9' =>
            return Character'Pos (Char) - Character'Pos ('0') + 52;
         when '+' =>
            return 62;
         when '/' =>
            return 63;
         when '-' =>
            return 62;
         when '_' =>
            return 63;
         when others =>
            return 0;
      end case;
   end Base64_Value;

   --  Decode an unpadded base64url string (standard alphabet accepted
   --  too) into raw bytes.
   function Base64url_Decode (Text : String) return String is
      Result : Unbounded_String;
      Group  : Interfaces.Unsigned_32 := 0;
      Bits   : Natural := 0;
      Sixty4 : constant Interfaces.Unsigned_32 := 64;
      Two55  : constant Interfaces.Unsigned_32 := 256;
   begin
      for Char of Text loop
         if Char /= '=' then
            Group :=
              Group * Sixty4
              + Interfaces.Unsigned_32 (Base64_Value (Char));
            Bits := Bits + 6;
            if Bits >= 8 then
               Bits := Bits - 8;
               declare
                  Byte : constant Interfaces.Unsigned_32 :=
                    Interfaces.Shift_Right (Group, Bits) mod Two55;
               begin
                  Append (Result, Character'Val (Natural (Byte)));
               end;
            end if;
         end if;
      end loop;

      return To_String (Result);
   end Base64url_Decode;

   --  Percent-encode a value for an application/x-www-form-urlencoded
   --  body.  Unreserved characters are kept; everything else becomes
   --  %XX with uppercase hex.
   function Encode_Form (Value : String) return String is
      use Ada.Characters.Handling;

      Result : Unbounded_String;
   begin
      for Char of Value loop
         if Is_Alphanumeric (Char)
           or else Char = '-'
           or else Char = '_'
           or else Char = '.'
           or else Char = '~'
         then
            Append (Result, Char);
         else
            declare
               Code : constant Natural := Character'Pos (Char);
            begin
               Append (Result, '%');
               Append (Result, Hex_Digit (Code / 16));
               Append
                 (Result,
                  Ada.Characters.Handling.To_Upper
                    (Hex_Digit (Code mod 16)));
            end;
         end if;
      end loop;

      return To_String (Result);
   end Encode_Form;

   function Build_Authorize_Url
     (Code_Challenge : String;
      State          : String) return String
   is
   begin
      return Authorize_Url
        & "?response_type=code"
        & "&client_id=" & Encode_Form (Client_Id)
        & "&redirect_uri=" & Encode_Form (Redirect_Uri)
        & "&scope=" & Encode_Form (Scope)
        & "&code_challenge=" & Encode_Form (Code_Challenge)
        & "&code_challenge_method=S256"
        & "&state=" & Encode_Form (State)
        & "&id_token_add_organizations=true"
        & "&codex_cli_simplified_flow=true"
        & "&originator=coyote";
   end Build_Authorize_Url;

   function New_State return String is
      Bytes : array (1 .. 16) of Ada.Streams.Stream_Element;
   begin
      for I in Bytes'Range loop
         Bytes (I) := Random_Byte;
      end loop;

      return Result : String (1 .. 32) do
         for I in Bytes'Range loop
            declare
               Pair : constant String := Byte_Hex (Bytes (I));
            begin
               Result (2 * I - 1) := Pair (1);
               Result (2 * I) := Pair (2);
            end;
         end loop;
      end return;
   end New_State;

   procedure Make_Pkce
     (Verifier  :    out Ada.Strings.Unbounded.Unbounded_String;
      Challenge :    out Ada.Strings.Unbounded.Unbounded_String)
   is
      --  Unreserved characters used by the reference clients for PKCE
      --  verifier material.
      Charset : constant String :=
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~";
      Bytes   : array (1 .. 43) of Ada.Streams.Stream_Element;
   begin
      for I in Bytes'Range loop
         Bytes (I) := Random_Byte;
      end loop;

      for I in Bytes'Range loop
         Append
           (Verifier,
            Charset
              (Natural (Bytes (I)) mod Charset'Length + Charset'First));
      end loop;

      Challenge :=
        To_Unbounded_String
          (Base64url_Encode (SHA2.SHA_256.Hash (To_String (Verifier))));
   end Make_Pkce;

   function Account_Id_From_Jwt (Access_Token : String) return String is
      use GNATCOLL.JSON;

      First_Sep  : Natural := 0;
      Second_Sep : Natural := 0;
   begin
      if Access_Token'Length = 0 then
         return "";
      end if;

      for I in Access_Token'Range loop
         if Access_Token (I) = '.' then
            if First_Sep = 0 then
               First_Sep := I;
            elsif Second_Sep = 0 then
               Second_Sep := I;
               exit;
            end if;
         end if;
      end loop;

      if First_Sep = 0
        or else Second_Sep = 0
        or else Second_Sep - First_Sep < 2
      then
         return "";
      end if;

      declare
         Payload_B64 : constant String :=
           Access_Token (First_Sep + 1 .. Second_Sep - 1);
         Payload_Json : constant String :=
           Base64url_Decode (Payload_B64);
         Parsed       : constant GNATCOLL.JSON.Read_Result :=
           GNATCOLL.JSON.Read (Payload_Json);
      begin
         if not Parsed.Success
           or else Parsed.Value.Kind /= GNATCOLL.JSON.JSON_Object_Type
         then
            return "";
         end if;

         --  Strict rule: the ChatGPT account id must live in the
         --  namespaced auth claim.  Tokens without it are treated as
         --  unparseable so the caller can hard-fail login/refresh.
         if Parsed.Value.Has_Field (Jwt_Claim_Path)
           and then Parsed.Value.Get (Jwt_Claim_Path).Kind
             = GNATCOLL.JSON.JSON_Object_Type
           and then Parsed.Value.Get (Jwt_Claim_Path).Has_Field
             ("chatgpt_account_id")
           and then Parsed.Value.Get (Jwt_Claim_Path)
                      .Get ("chatgpt_account_id").Kind
             = GNATCOLL.JSON.JSON_String_Type
         then
            return Parsed.Value.Get (Jwt_Claim_Path)
                     .Get ("chatgpt_account_id").Get;
         end if;

         return "";
      end;
   exception
      when others =>
         return "";
   end Account_Id_From_Jwt;

   function Get_String_Field
     (Value : GNATCOLL.JSON.JSON_Value;
      Field : String) return String
   is
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind = GNATCOLL.JSON.JSON_String_Type
      then
         return Value.Get (Field).Get;
      end if;

      return "";
   end Get_String_Field;

   function Get_Long_Long_Field
     (Value : GNATCOLL.JSON.JSON_Value;
      Field : String) return Long_Long_Integer
   is
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind = GNATCOLL.JSON.JSON_Int_Type
      then
         declare
            Raw : constant Long_Integer := Value.Get (Field).Get;
         begin
            return Long_Long_Integer (Raw);
         end;
      end if;

      return 0;
   end Get_Long_Long_Field;

   procedure Parse_Token_Response
     (Body_Text   :     String;
      What        :     String;
      Creds       : out LLM.Auth.Provider_Credentials)
   is
      use GNATCOLL.JSON;

      Parsed     : constant GNATCOLL.JSON.Read_Result :=
        GNATCOLL.JSON.Read (Body_Text);
      Root       : GNATCOLL.JSON.JSON_Value;
      Access_Str : Unbounded_String;
      Refresh_Str : Unbounded_String;
      Expires_In : Long_Long_Integer := 0;
   begin
      Creds := (others => <>);

      if not Parsed.Success
        or else Parsed.Value.Kind /= GNATCOLL.JSON.JSON_Object_Type
      then
         raise Auth_Error with "Invalid OpenAI Codex " & What & " response";
      end if;

      Root := Parsed.Value;

      Access_Str :=
        To_Unbounded_String (Get_String_Field (Root, "access_token"));
      Refresh_Str :=
        To_Unbounded_String (Get_String_Field (Root, "refresh_token"));
      Expires_In := Get_Long_Long_Field (Root, "expires_in");

      if Length (Access_Str) = 0
        or else Length (Refresh_Str) = 0
        or else Expires_In <= 0
      then
         raise Auth_Error with
           "OpenAI Codex " & What & " response missing fields";
      end if;

      Creds :=
        (Credential_Type => To_Unbounded_String ("oauth"),
         Refresh_Token   => Refresh_Str,
         Access_Token    => Access_Str,
         Expires_Ms      => Current_Unix_Ms + Expires_In * 1000,
         Account_Id      =>
           To_Unbounded_String
             (Account_Id_From_Jwt (To_String (Access_Str))));
   exception
      when Auth_Error =>
         raise;
      when E : others =>
         raise Auth_Error with
           "OpenAI Codex " & What & " response parse error: "
           & Ada.Exceptions.Exception_Message (E);
   end Parse_Token_Response;

   procedure Exchange_Code
     (Code                  :     String;
      Code_Verifier         :     String;
      Redirect_Uri_Override :     String := "";
      Creds                 : out LLM.Auth.Provider_Credentials)
   is
      Headers       : LLM.HTTP.Header_List;
      Status        : Natural := 0;
      Response_Body : Unbounded_String;
      Form          : Unbounded_String;
      Redirect      : constant String :=
        (if Redirect_Uri_Override'Length > 0
         then Redirect_Uri_Override
         else Redirect_Uri);

      procedure On_Chunk (Data : String) is
      begin
         Append (Response_Body, Data);
      end On_Chunk;
   begin
      Append (Form, "grant_type=authorization_code");
      Append (Form, "&code=" & Encode_Form (Code));
      Append (Form, "&redirect_uri=" & Encode_Form (Redirect));
      Append (Form, "&client_id=" & Encode_Form (Client_Id));
      Append (Form, "&code_verifier=" & Encode_Form (Code_Verifier));

      LLM.HTTP.Add_Header
        (Headers, "Content-Type", "application/x-www-form-urlencoded");
      LLM.HTTP.Add_Header (Headers, "User-Agent", User_Agent_Value);

      LLM.HTTP.Post
        (URL      => Token_Endpoint,
         Headers  => Headers,
         Payload  => To_String (Form),
         On_Chunk => On_Chunk'Access,
         Status   => Status);

      if Status /= 200 then
         --  Diagnostics: log the failing request geometry (never token
         --  secrets) so exchange failures are actionable.
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "[!] OpenAI Codex token exchange request:"
            & " grant_type=authorization_code"
            & " code_len" & Natural'Image (Code'Length)
            & " verifier_len" & Natural'Image (Code_Verifier'Length)
            & " redirect=" & Redirect
            & " endpoint=" & Token_Endpoint);
         raise Auth_Error with
           "OpenAI Codex token exchange failed with HTTP"
           & Natural'Image (Status)
           & ": "
           & To_String (Response_Body);
      end if;

      Parse_Token_Response
        (To_String (Response_Body), "exchange", Creds);
   exception
      when Auth_Error =>
         raise;
      when E : others =>
         raise Auth_Error with Ada.Exceptions.Exception_Message (E);
   end Exchange_Code;

   procedure Refresh_Token (Creds : in out LLM.Auth.Provider_Credentials) is
      Headers       : LLM.HTTP.Header_List;
      Status        : Natural := 0;
      Response_Body : Unbounded_String;
      Form          : Unbounded_String;

      procedure On_Chunk (Data : String) is
      begin
         Append (Response_Body, Data);
      end On_Chunk;
   begin
      if Length (Creds.Refresh_Token) = 0 then
         raise Auth_Error with "OpenAI Codex refresh token is missing";
      end if;

      Append (Form, "grant_type=refresh_token");
      Append
        (Form,
         "&refresh_token="
         & Encode_Form (To_String (Creds.Refresh_Token)));
      Append (Form, "&client_id=" & Encode_Form (Client_Id));

      LLM.HTTP.Add_Header
        (Headers, "Content-Type", "application/x-www-form-urlencoded");
      LLM.HTTP.Add_Header (Headers, "User-Agent", User_Agent_Value);

      LLM.HTTP.Post
        (URL      => Token_Endpoint,
         Headers  => Headers,
         Payload  => To_String (Form),
         On_Chunk => On_Chunk'Access,
         Status   => Status);

      if Status /= 200 then
         raise Auth_Error with
           "OpenAI Codex token refresh failed with HTTP"
           & Natural'Image (Status)
           & ": "
           & To_String (Response_Body);
      end if;

      declare
         Fresh : LLM.Auth.Provider_Credentials;
      begin
         Parse_Token_Response
           (To_String (Response_Body), "refresh", Fresh);

         --  The refresh endpoint may omit refresh_token (rotation is
         --  optional); keep the previous refresh token in that case.
         --  The account id is re-extracted from the new access token and
         --  may rotate; when the fresh token does not carry the claim,
         --  retain the previously stored account id.
         if Length (Fresh.Account_Id) > 0 then
            Creds.Account_Id := Fresh.Account_Id;
         end if;
         Creds.Access_Token := Fresh.Access_Token;
         Creds.Expires_Ms := Fresh.Expires_Ms;
         Creds.Refresh_Token := Fresh.Refresh_Token;
      end;

      LLM.Auth.Save_Credentials ("codex", Creds);
   exception
      when E : others =>
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "[!] OpenAI Codex token refresh failed: "
            & Ada.Exceptions.Exception_Message (E));
         raise;
   end Refresh_Token;

   function Token_Expired (Creds : LLM.Auth.Provider_Credentials)
      return Boolean is
   begin
      return Creds.Expires_Ms <= Current_Unix_Ms + 300_000;
   end Token_Expired;

   procedure Ensure_Valid (Creds : in out LLM.Auth.Provider_Credentials) is
   begin
      if not Token_Expired (Creds) then
         return;
      end if;

      Guard.Acquire;

      begin
         if Token_Expired (Creds) then
            declare
               Latest : constant LLM.Auth.Provider_Credentials :=
                 LLM.Auth.Load_Credentials ("codex");
            begin
               if Length (Latest.Refresh_Token) > 0
                 or else Length (Latest.Access_Token) > 0
               then
                  Creds := Latest;
               end if;
            end;

            if Token_Expired (Creds) then
               Refresh_Token (Creds);
            end if;
         end if;

         Guard.Release;
      exception
         when others =>
            Guard.Release;
            raise;
      end;
   end Ensure_Valid;

end LLM.Auth.Codex;
