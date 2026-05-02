--  LLM.Auth.GitHub_Copilot body.
--
--  Project: pi_acme
--  For revision history, see the project version-control log.

with Ada.Calendar;
with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with GNATCOLL.JSON;
with LLM.HTTP;

package body LLM.Auth.GitHub_Copilot is

   use type GNATCOLL.JSON.JSON_Value_Type;

   DEFAULT_BASE_URL : constant String :=
     "https://api.individual.githubcopilot.com";
   DEFAULT_TOKEN_URL : constant String :=
     "https://api.github.com/copilot_internal/v2/token";

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
      return Ada.Environment_Variables.Value
        ("PI_ACME_GITHUB_COPILOT_TOKEN_URL", DEFAULT_TOKEN_URL);
   end Token_Endpoint;

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

   function Token_Expired (Creds : Provider_Credentials) return Boolean is
   begin
      return Creds.Expires_Ms <= Current_Unix_Ms + 300_000;
   end Token_Expired;

   function Get_Base_Url (Token : String) return String is
      Marker      : constant String  := "proxy-ep=";
      Marker_Pos  : constant Natural :=
        Ada.Strings.Fixed.Index (Token, Marker);
      Value_First : Natural;
      Value_Last  : Natural := Token'Last;
   begin
      if Marker_Pos = 0 then
         return DEFAULT_BASE_URL;
      end if;

      Value_First := Marker_Pos + Marker'Length;

      if Value_First > Token'Last then
         return DEFAULT_BASE_URL;
      end if;

      for I in Value_First .. Token'Last loop
         if Token (I) = ';' then
            Value_Last := I - 1;
            exit;
         end if;
      end loop;

      if Value_Last < Value_First then
         return DEFAULT_BASE_URL;
      end if;

      declare
         Host : constant String := Token (Value_First .. Value_Last);
      begin
         if Host'Length = 0 then
            return DEFAULT_BASE_URL;
         elsif Host'Length >= 6
           and then Host (Host'First .. Host'First + 5) = "proxy."
         then
            return "https://api." & Host (Host'First + 6 .. Host'Last);
         elsif Host'Length >= 4
           and then Host (Host'First .. Host'First + 3) = "api."
         then
            return "https://" & Host;
         else
            return "https://api." & Host;
         end if;
      end;
   end Get_Base_Url;

   procedure Refresh_Token (Creds : in out Provider_Credentials) is
      Headers  : LLM.HTTP.Header_List;
      Status   : Natural := 0;
      Response_Body : Unbounded_String;
      Root     : GNATCOLL.JSON.JSON_Value;
      Parsed   : GNATCOLL.JSON.Read_Result;
      Token    : Unbounded_String;
      Expires  : Long_Long_Integer := 0;

      procedure On_Chunk (Data : String) is
      begin
         Append (Response_Body, Data);
      end On_Chunk;
   begin
      if Length (Creds.Refresh_Token) = 0 then
         raise Auth_Error with "GitHub Copilot refresh token is missing";
      end if;

      LLM.HTTP.Add_Header
        (Headers,
         "Authorization",
         "Bearer " & To_String (Creds.Refresh_Token));
      LLM.HTTP.Add_Header
        (Headers, "User-Agent", "GitHubCopilotChat/0.35.0");
      LLM.HTTP.Add_Header
        (Headers, "Editor-Version", "vscode/1.107.0");
      LLM.HTTP.Add_Header
        (Headers, "Editor-Plugin-Version", "copilot-chat/0.35.0");
      LLM.HTTP.Add_Header
        (Headers, "Copilot-Integration-Id", "vscode-chat");

      LLM.HTTP.Get
        (URL      => Token_Endpoint,
         Headers  => Headers,
         On_Chunk => On_Chunk'Access,
         Status   => Status);

      if Status /= 200 then
         raise Auth_Error with
           "GitHub Copilot token refresh failed with HTTP"
           & Natural'Image (Status)
           & ": "
           & To_String (Response_Body);
      end if;

      Parsed := GNATCOLL.JSON.Read (To_String (Response_Body));

      if not Parsed.Success then
         raise Auth_Error with
           "Invalid GitHub Copilot token refresh response: "
           & GNATCOLL.JSON.Format_Parsing_Error (Parsed.Error);
      end if;

      Root := Parsed.Value;
      Token := To_Unbounded_String (Get_String_Field (Root, "token"));
      Expires := Get_Long_Long_Field (Root, "expires_at");

      if Length (Token) = 0 or else Expires <= 0 then
         raise Auth_Error with
           "GitHub Copilot token refresh response is missing fields";
      end if;

      Creds.Access_Token := Token;
      Creds.Expires_Ms := Expires * 1000;
      Save_Credentials ("github-copilot", Creds);
   exception
      when Auth_Error =>
         raise;
      when E : others =>
         raise Auth_Error with Ada.Exceptions.Exception_Message (E);
   end Refresh_Token;

   procedure Ensure_Valid (Creds : in out Provider_Credentials) is
   begin
      if not Token_Expired (Creds) then
         return;
      end if;

      Guard.Acquire;

      begin
         if Token_Expired (Creds) then
            declare
               Latest : constant Provider_Credentials :=
                 Load_Credentials ("github-copilot");
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

end LLM.Auth.GitHub_Copilot;
