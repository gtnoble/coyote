--  LLM.Providers.Codex.Catalogue body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Calendar;
with Ada.Containers;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNAT.OS_Lib;
with GNATCOLL.JSON;
with LLM.Auth;
with LLM.Auth.Codex;
with LLM.HTTP;
with LLM.Settings;
with Coyote_Utils;

package body LLM.Providers.Codex.Catalogue is

   use type GNATCOLL.JSON.JSON_Value_Type;

   --  Client version advertised to the backend.  The Codex catalogue is
   --  version-gated by minimal_client_version, so a future version
   --  selects the fullest available listing.
   Client_Version : constant String := "99.0.0";

   type Cache_Load_Result is record
      Found  : Boolean := False;
      Fresh  : Boolean := False;
      Models : Catalogue_Vectors.Vector;
   end record;

   function Cache_Path return String is
      Base : constant String := LLM.Settings.Agent_Dir;
   begin
      if Base'Length = 0 then
         return "";
      end if;

      return Base & "/codex_models_cache.json";
   end Cache_Path;

   function Base_Url return String is
   begin
      if Ada.Environment_Variables.Exists ("COYOTE_CODEX_BASE_URL") then
         declare
            Value : constant String :=
              Ada.Environment_Variables.Value ("COYOTE_CODEX_BASE_URL");
         begin
            if Value'Length > 0 then
               return Value;
            end if;
         end;
      end if;

      return "https://chatgpt.com/backend-api";
   end Base_Url;

   function Endpoint_Url return String is
      Root : constant String := Base_Url;
   begin
      if Root'Length = 0 then
         return "/codex/models";
      elsif Root (Root'Last) = '/' then
         return Root & "codex/models";
      else
         return Root & "/codex/models";
      end if;
   end Endpoint_Url;

   function Temp_Path (Path : String) return String is
   begin
      return Path & ".tmp";
   end Temp_Path;

   procedure Delete_If_Exists (Path : String) is
   begin
      if Path'Length > 0 and then Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_File (Path);
      end if;
   exception
      when others =>
         null;
   end Delete_If_Exists;

   function Read_File (Path : String) return String is
   begin
      if Path'Length = 0 or else not Ada.Directories.Exists (Path) then
         return "";
      end if;

      return Coyote_Utils.Read_Whole_File (Path);
   end Read_File;

   procedure Write_Atomically (Path : String; Content : String) is
      File     : Ada.Text_IO.File_Type;
      Tmp_Name : constant String := Temp_Path (Path);
      Renamed  : Boolean         := False;
      Dir_Path : constant String :=
        Ada.Directories.Containing_Directory (Path);
   begin
      if Path'Length = 0 then
         return;
      end if;

      Ada.Directories.Create_Path (Dir_Path);
      Delete_If_Exists (Tmp_Name);

      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Tmp_Name);
      Ada.Text_IO.Put (File, Content);
      Ada.Text_IO.Close (File);

      GNAT.OS_Lib.Rename_File (Tmp_Name, Path, Renamed);

      if not Renamed then
         Delete_If_Exists (Tmp_Name);
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "[!] Failed to replace Codex catalogue cache");
      end if;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;

         Delete_If_Exists (Tmp_Name);
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "[!] Failed to write Codex catalogue cache");
   end Write_Atomically;

   function Current_Unix_S return Long_Long_Integer is
      use Ada.Calendar;

      Epoch : constant Time :=
        Time_Of (Year => 1_970, Month => 1, Day => 1, Seconds => 0.0);
   begin
      return Long_Long_Integer (Clock - Epoch);
   end Current_Unix_S;

   function Is_Fresh
     (Fetched_At : Long_Long_Integer; Max_Age_Hours : Natural) return Boolean
   is
      Age_Limit : constant Long_Long_Integer :=
        Long_Long_Integer (Max_Age_Hours) * 3_600;
      Now_S     : constant Long_Long_Integer := Current_Unix_S;
   begin
      if Fetched_At <= 0 then
         return False;
      end if;

      if Fetched_At >= Now_S then
         return True;
      end if;

      return Now_S - Fetched_At <= Age_Limit;
   end Is_Fresh;

   function Get_Long_Long_Field
     (Value : GNATCOLL.JSON.JSON_Value;
      Field : String)
      return Long_Long_Integer
   is
      Raw : Long_Integer;
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind = GNATCOLL.JSON.JSON_Int_Type
      then
         Raw := Value.Get (Field).Get;
         return Long_Long_Integer (Raw);
      end if;

      return 0;
   end Get_Long_Long_Field;

   function Get_String_Field
     (Value   : GNATCOLL.JSON.JSON_Value;
      Field   : String;
      Default : String := "")
      return String
   is
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind = GNATCOLL.JSON.JSON_String_Type
      then
         return Value.Get (Field).Get;
      end if;

      return Default;
   end Get_String_Field;

   function Get_Natural_Field
     (Value   : GNATCOLL.JSON.JSON_Value;
      Field   : String;
      Default : Natural)
      return Natural
   is
      Raw : Long_Integer;
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind = GNATCOLL.JSON.JSON_Int_Type
      then
         Raw := Value.Get (Field).Get;

         if Raw >= 0 then
            return Natural (Raw);
         end if;
      end if;

      return Default;
   end Get_Natural_Field;

   --  True when the object carries a JSON boolean field with the value
   --  True.  The live catalogue encodes capability flags such as
   --  supports_parallel_tool_calls as booleans, not integers, so they
   --  must not be read through the integer helper.
   function Get_Boolean_Field
     (Value   : GNATCOLL.JSON.JSON_Value;
      Field   : String;
      Default : Boolean)
      return Boolean
   is
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind = GNATCOLL.JSON.JSON_Boolean_Type
      then
         return Value.Get (Field).Get;
      end if;

      return Default;
   end Get_Boolean_Field;

   function Is_Listed (Value : GNATCOLL.JSON.JSON_Value) return Boolean is
   begin
      return Get_String_Field (Value, "visibility", "list") = "list";
   end Is_Listed;

   --  Length of a JSON array field; 0 when the field is missing or is
   --  not an array.
   function Array_Field_Length
     (Value : GNATCOLL.JSON.JSON_Value; Field : String) return Natural
   is
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind = GNATCOLL.JSON.JSON_Array_Type
      then
         return GNATCOLL.JSON.Length (Value.Get (Field).Get);
      end if;

      return 0;
   end Array_Field_Length;

   --  True when the string array named Field contains the value Want.
   function Array_Field_Contains
     (Value : GNATCOLL.JSON.JSON_Value;
      Field : String;
      Want  : String)
      return Boolean
   is
   begin
      if Value.Kind /= GNATCOLL.JSON.JSON_Object_Type
        or else not Value.Has_Field (Field)
        or else Value.Get (Field).Kind /= GNATCOLL.JSON.JSON_Array_Type
      then
         return False;
      end if;

      declare
         Items : constant GNATCOLL.JSON.JSON_Array := Value.Get (Field).Get;
      begin
         for I in 1 .. GNATCOLL.JSON.Length (Items) loop
            declare
               Item : constant GNATCOLL.JSON.JSON_Value :=
                 GNATCOLL.JSON.Get (Items, I);
            begin
               if Item.Kind = GNATCOLL.JSON.JSON_String_Type
                 and then To_String (Item.Get) = Want
               then
                  return True;
               end if;
            end;
         end loop;
      end;

      return False;
   end Array_Field_Contains;

   function Parse_Model (Value : GNATCOLL.JSON.JSON_Value) return Model_Info is
      Result : Model_Info;
   begin
      Result.Model_Id           :=
        To_Unbounded_String (Get_String_Field (Value, "slug"));
      Result.Name               :=
        To_Unbounded_String (Get_String_Field (Value, "display_name"));
      Result.Description        :=
        To_Unbounded_String (Get_String_Field (Value, "description"));
      Result.Context_Window := Get_Natural_Field (Value, "context_window", 0);
      Result.Max_Context_Window :=
        Get_Natural_Field (Value, "max_context_window", 0);
      Result.Reasoning          :=
        Array_Field_Length (Value, "supported_reasoning_levels") > 0;
      Result.Supports_Tools     :=
        Get_Boolean_Field (Value, "supports_parallel_tool_calls", False);
      Result.Supports_Images    :=
        Array_Field_Contains (Value, "input_modalities", "image");
      return Result;
   end Parse_Model;

   procedure Parse_Models
     (Items : GNATCOLL.JSON.JSON_Array; Models : out Catalogue_Vectors.Vector)
   is
   begin
      Models.Clear;

      for I in 1 .. GNATCOLL.JSON.Length (Items) loop
         declare
            Item : constant GNATCOLL.JSON.JSON_Value :=
              GNATCOLL.JSON.Get (Items, I);
         begin
            if Item.Kind = GNATCOLL.JSON.JSON_Object_Type
              and then Is_Listed (Item)
              and then Get_String_Field (Item, "slug")'Length > 0
            then
               Models.Append (Parse_Model (Item));
            end if;
         end;
      end loop;
   end Parse_Models;

   function Fetch_Live
     (Models : out Catalogue_Vectors.Vector;
      Data   : out GNATCOLL.JSON.JSON_Value)
      return Boolean
   is
      Creds         : constant LLM.Auth.Provider_Credentials :=
        LLM.Auth.Load_Credentials ("codex");
      Headers       : LLM.HTTP.Header_List;
      Status        : Natural                                := 0;
      Response_Body : Unbounded_String;
      Parsed        : GNATCOLL.JSON.Read_Result;
      Root          : GNATCOLL.JSON.JSON_Value;

      procedure On_Chunk (Chunk : String) is
      begin
         Append (Response_Body, Chunk);
      end On_Chunk;
   begin
      Models.Clear;
      Data := GNATCOLL.JSON.JSON_Null;

      --  Only attempt a live fetch with a cached, non-expired access
      --  token; token refresh stays in LLM.Auth.Codex.Ensure_Valid so
      --  startup refresh remains synchronous and side-effect free.
      if Length (Creds.Access_Token) = 0
        or else LLM.Auth.Codex.Token_Expired (Creds)
      then
         return False;
      end if;

      LLM.HTTP.Add_Header
        (Headers, "Authorization", "Bearer " & To_String (Creds.Access_Token));
      LLM.HTTP.Add_Header
        (Headers, "chatgpt-account-id", To_String (Creds.Account_Id));
      LLM.HTTP.Add_Header (Headers, "originator", "coyote");
      LLM.HTTP.Add_Header (Headers, "User-Agent", "coyote/0.1.0-dev");
      LLM.HTTP.Add_Header (Headers, "Accept", "application/json");

      LLM.HTTP.Get
        (URL      => Endpoint_Url & "?client_version=" & Client_Version,
         Headers  => Headers,
         On_Chunk => On_Chunk'Access,
         Status   => Status);

      if Status /= 200 then
         return False;
      end if;

      Parsed := GNATCOLL.JSON.Read (To_String (Response_Body));

      if not Parsed.Success then
         return False;
      end if;

      Root := Parsed.Value;

      if Root.Kind /= GNATCOLL.JSON.JSON_Object_Type
        or else not Root.Has_Field ("models")
        or else Root.Get ("models").Kind /= GNATCOLL.JSON.JSON_Array_Type
      then
         return False;
      end if;

      Data := Root.Get ("models");
      Parse_Models (Root.Get ("models").Get, Models);
      return True;
   exception
      when others =>
         Models.Clear;
         Data := GNATCOLL.JSON.JSON_Null;
         return False;
   end Fetch_Live;

   procedure Save_Cache (Data : GNATCOLL.JSON.JSON_Value) is
      Path : constant String                   := Cache_Path;
      Root : constant GNATCOLL.JSON.JSON_Value := GNATCOLL.JSON.Create_Object;
   begin
      if Path'Length = 0 or else Data.Kind /= GNATCOLL.JSON.JSON_Array_Type
      then
         return;
      end if;

      Root.Set_Field ("fetched_at", Long_Integer (Current_Unix_S));

      declare
         Data_Array : constant GNATCOLL.JSON.JSON_Array := Data.Get;
      begin
         Root.Set_Field ("models", Data_Array);
      end;

      Write_Atomically (Path, GNATCOLL.JSON.Write (Root));
   end Save_Cache;

   function Load_Cache (Max_Age_Hours : Natural) return Cache_Load_Result is
      Path       : constant String   := Cache_Path;
      Content    : constant String   := Read_File (Path);
      Parsed     : GNATCOLL.JSON.Read_Result;
      Root       : GNATCOLL.JSON.JSON_Value;
      Fetched_At : Long_Long_Integer := 0;
      Result     : Cache_Load_Result;
   begin
      if Content'Length = 0 then
         return Result;
      end if;

      Parsed := GNATCOLL.JSON.Read (Content);

      if not Parsed.Success then
         return Result;
      end if;

      Root := Parsed.Value;

      if Root.Kind /= GNATCOLL.JSON.JSON_Object_Type
        or else not Root.Has_Field ("models")
        or else Root.Get ("models").Kind /= GNATCOLL.JSON.JSON_Array_Type
      then
         return Result;
      end if;

      Fetched_At   := Get_Long_Long_Field (Root, "fetched_at");
      Result.Found := True;
      Result.Fresh := Is_Fresh (Fetched_At, Max_Age_Hours);
      Parse_Models (Root.Get ("models").Get, Result.Models);
      return Result;
   exception
      when others =>
         return Result;
   end Load_Cache;

   procedure Load_Catalogue
     (Models : out Catalogue_Vectors.Vector; Max_Age_Hours : Natural := 24)
   is
      Cache_Result : constant Cache_Load_Result := Load_Cache (Max_Age_Hours);
      Live_Models  : Catalogue_Vectors.Vector;
      Live_Data    : GNATCOLL.JSON.JSON_Value;
   begin
      if Cache_Result.Found and then Cache_Result.Fresh then
         Models := Cache_Result.Models;
         return;
      end if;

      if Fetch_Live (Models => Live_Models, Data => Live_Data) then
         Models := Live_Models;
         Save_Cache (Live_Data);
         return;
      end if;

      --  A live-fetch failure is never silent: it degrades the codex
      --  registry (possibly to an empty model list), so it must leave a
      --  diagnostic on standard error.
      if Cache_Result.Found then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "[!] Codex model catalogue fetch failed; using stale cache");
         Models := Cache_Result.Models;
      else
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "[!] Codex model catalogue fetch failed and no cache is "
            & "available; codex models will be unavailable this run");
         Models.Clear;
      end if;
   end Load_Catalogue;

end LLM.Providers.Codex.Catalogue;
