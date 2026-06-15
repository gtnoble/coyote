--  LLM.Providers.GitHub_Copilot.Catalogue body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Calendar;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNAT.OS_Lib;
with GNATCOLL.JSON;
with LLM.Auth.GitHub_Copilot;
with LLM.HTTP;
with LLM.Settings;
with Coyote_Utils;

package body LLM.Providers.GitHub_Copilot.Catalogue is

   use type GNATCOLL.JSON.JSON_Value_Type;

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

      return Base & "/github_copilot_models_cache.json";
   end Cache_Path;

   function Normalize_Base_Url (Base_Url : String) return String is
   begin
      if Base_Url'Length > 0 and then Base_Url (Base_Url'Last) = '/' then
         return Base_Url (Base_Url'First .. Base_Url'Last - 1);
      end if;

      return Base_Url;
   end Normalize_Base_Url;

   function Endpoint_Url (Base_Url : String) return String is
      Normalized : constant String := Normalize_Base_Url (Base_Url);
   begin
      if Normalized'Length = 0 then
         return "/models";
      end if;

      return Normalized & "/models";
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
      Tmp_Path : constant String := Temp_Path (Path);
      Renamed  : Boolean         := False;
      Dir_Path : constant String :=
        Ada.Directories.Containing_Directory (Path);
   begin
      if Path'Length = 0 then
         return;
      end if;

      Ada.Directories.Create_Path (Dir_Path);
      Delete_If_Exists (Tmp_Path);

      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Tmp_Path);
      Ada.Text_IO.Put (File, Content);
      Ada.Text_IO.Close (File);

      GNAT.OS_Lib.Rename_File (Tmp_Path, Path, Renamed);

      if not Renamed then
         Delete_If_Exists (Tmp_Path);
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "[!] Failed to replace GitHub Copilot catalogue cache");
      end if;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;

         Delete_If_Exists (Tmp_Path);
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "[!] Failed to write GitHub Copilot catalogue cache");
   end Write_Atomically;

   function Current_Unix_S return Long_Long_Integer is
      use Ada.Calendar;

      Epoch : constant Time :=
        Time_Of
          (Year    => 1970,
           Month   => 1,
           Day     => 1,
           Seconds => 0.0);
   begin
      return Long_Long_Integer (Clock - Epoch);
   end Current_Unix_S;

   function Is_Fresh
     (Fetched_At    : Long_Long_Integer;
      Max_Age_Hours : Natural) return Boolean
   is
      Age_Limit : constant Long_Long_Integer :=
        Long_Long_Integer (Max_Age_Hours) * 3600;
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

   function Get_Object_Field
     (Value : GNATCOLL.JSON.JSON_Value;
      Field : String) return GNATCOLL.JSON.JSON_Value
   is
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind = GNATCOLL.JSON.JSON_Object_Type
      then
         return Value.Get (Field);
      end if;

      return GNATCOLL.JSON.JSON_Null;
   end Get_Object_Field;

   function Get_Array_Field
     (Value : GNATCOLL.JSON.JSON_Value;
      Field : String) return GNATCOLL.JSON.JSON_Array
   is
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind = GNATCOLL.JSON.JSON_Array_Type
      then
         return Value.Get (Field).Get;
      end if;

      return GNATCOLL.JSON.Empty_Array;
   end Get_Array_Field;

   function Get_String_Field
     (Value   : GNATCOLL.JSON.JSON_Value;
      Field   : String;
      Default : String := "") return String
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
      Default : Natural) return Natural
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

   function Get_Boolean_Field
     (Value   : GNATCOLL.JSON.JSON_Value;
      Field   : String;
      Default : Boolean) return Boolean
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

   function Array_Contains
     (Items : GNATCOLL.JSON.JSON_Array;
      Want  : String) return Boolean
   is
   begin
      for I in 1 .. GNATCOLL.JSON.Length (Items) loop
         declare
            Item : constant GNATCOLL.JSON.JSON_Value :=
              GNATCOLL.JSON.Get (Items, I);
         begin
            if Item.Kind = GNATCOLL.JSON.JSON_String_Type then
               declare
                  Item_Str : constant String := Item.Get;
               begin
                  if Item_Str = Want then
                     return True;
                  end if;
               end;
            end if;
         end;
      end loop;

      return False;
   end Array_Contains;

   function Parse_Model
     (Value : GNATCOLL.JSON.JSON_Value) return Model_Capability_Info
   is
      Result     : Model_Capability_Info;
      Caps       : constant GNATCOLL.JSON.JSON_Value :=
        Get_Object_Field (Value, "capabilities");
      Limits     : constant GNATCOLL.JSON.JSON_Value :=
        Get_Object_Field (Caps, "limits");
      Supports   : constant GNATCOLL.JSON.JSON_Value :=
        Get_Object_Field (Caps, "supports");
      Endpoints  : constant GNATCOLL.JSON.JSON_Array :=
        Get_Array_Field (Value, "supported_endpoints");
      Reasoning  : constant GNATCOLL.JSON.JSON_Array :=
        Get_Array_Field (Supports, "reasoning_effort");
   begin
      Result.Model_Id := To_Unbounded_String (Get_String_Field (Value, "id"));
      Result.Name := To_Unbounded_String (Get_String_Field (Value, "name"));
      Result.Context_Window :=
        Get_Natural_Field
          (Limits, "max_context_window_tokens", Result.Context_Window);
      Result.Max_Tokens :=
        Get_Natural_Field (Limits, "max_output_tokens", Result.Max_Tokens);
      Result.Supports_Tools :=
        Get_Boolean_Field (Supports, "tool_calls", Result.Supports_Tools);
      Result.Supports_Images :=
        Get_Boolean_Field (Supports, "vision", Result.Supports_Images);
      Result.Reasoning := GNATCOLL.JSON.Length (Reasoning) > 0;
      Result.Max_Thinking_Budget :=
        Get_Natural_Field
          (Supports, "max_thinking_budget", Result.Max_Thinking_Budget);
      Result.Min_Thinking_Budget :=
        Get_Natural_Field
          (Supports, "min_thinking_budget", Result.Min_Thinking_Budget);
      Result.Supports_Anthropic :=
        Array_Contains (Endpoints, "/v1/messages");
      Result.Supports_OpenAI :=
        Array_Contains (Endpoints, "/chat/completions");
      return Result;
   end Parse_Model;

   procedure Parse_Models
     (Items  :     GNATCOLL.JSON.JSON_Array;
      Models : out Catalogue_Vectors.Vector)
   is
   begin
      Models.Clear;

      for I in 1 .. GNATCOLL.JSON.Length (Items) loop
         declare
            Item : constant GNATCOLL.JSON.JSON_Value :=
              GNATCOLL.JSON.Get (Items, I);
            Caps : constant GNATCOLL.JSON.JSON_Value :=
              Get_Object_Field (Item, "capabilities");
         begin
            if Get_String_Field (Caps, "type") = "chat" then
               Models.Append (Parse_Model (Item));
            end if;
         end;
      end loop;
   end Parse_Models;

   procedure Add_Header_Line
     (Headers : in out LLM.HTTP.Header_List;
      Header  : String)
   is
      Separator : constant Natural :=
        Ada.Strings.Fixed.Index (Header, ": ");
   begin
      if Separator = 0 then
         return;
      end if;

      LLM.HTTP.Add_Header
        (Headers,
         Header (Header'First .. Separator - 1),
         Header (Separator + 2 .. Header'Last));
   end Add_Header_Line;

   function Fetch_Live
     (Base_Url : String;
      Token    : String;
      Models   : out Catalogue_Vectors.Vector;
      Data     : out GNATCOLL.JSON.JSON_Value) return Boolean
   is
      Headers  : LLM.HTTP.Header_List;
      Status   : Natural := 0;
      Response_Body : Unbounded_String;
      Parsed   : GNATCOLL.JSON.Read_Result;
      Root     : GNATCOLL.JSON.JSON_Value;

      procedure On_Chunk (Chunk : String) is
      begin
         Append (Response_Body, Chunk);
      end On_Chunk;
   begin
      Models.Clear;
      Data := GNATCOLL.JSON.JSON_Null;

      LLM.HTTP.Add_Header (Headers, "Authorization", "Bearer " & Token);
      Add_Header_Line
        (Headers, LLM.Auth.GitHub_Copilot.User_Agent_Header);
      Add_Header_Line
        (Headers, LLM.Auth.GitHub_Copilot.Editor_Version_Header);
      Add_Header_Line
        (Headers, LLM.Auth.GitHub_Copilot.Editor_Plugin_Header);
      Add_Header_Line
        (Headers, LLM.Auth.GitHub_Copilot.Integration_Id_Header);
      Add_Header_Line
        (Headers, LLM.Auth.GitHub_Copilot.Intent_Header);

      LLM.HTTP.Get
        (URL      => Endpoint_Url (Base_Url),
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
        or else not Root.Has_Field ("data")
        or else Root.Get ("data").Kind /= GNATCOLL.JSON.JSON_Array_Type
      then
         return False;
      end if;

      Data := Root.Get ("data");
      Parse_Models (Root.Get ("data").Get, Models);
      return True;
   exception
      when others =>
         Models.Clear;
         Data := GNATCOLL.JSON.JSON_Null;
         return False;
   end Fetch_Live;

   procedure Save_Cache
     (Base_Url : String;
      Data     : GNATCOLL.JSON.JSON_Value)
   is
      Path : constant String := Cache_Path;
      Root : constant GNATCOLL.JSON.JSON_Value := GNATCOLL.JSON.Create_Object;
   begin
      if Path'Length = 0
        or else Data.Kind /= GNATCOLL.JSON.JSON_Array_Type
      then
         return;
      end if;

      Root.Set_Field ("fetched_at", Long_Integer (Current_Unix_S));
      Root.Set_Field ("base_url", Normalize_Base_Url (Base_Url));

      declare
         Data_Array : constant GNATCOLL.JSON.JSON_Array := Data.Get;
      begin
         Root.Set_Field ("data", Data_Array);
      end;

      Write_Atomically (Path, GNATCOLL.JSON.Write (Root));
   end Save_Cache;

   function Load_Cache
     (Base_Url      : String;
      Max_Age_Hours : Natural) return Cache_Load_Result
   is
      Path       : constant String := Cache_Path;
      Content    : constant String := Read_File (Path);
      Parsed     : GNATCOLL.JSON.Read_Result;
      Root       : GNATCOLL.JSON.JSON_Value;
      Cached_Url : Unbounded_String;
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

      if Root.Kind /= GNATCOLL.JSON.JSON_Object_Type then
         return Result;
      end if;

      Cached_Url := To_Unbounded_String (Get_String_Field (Root, "base_url"));
      Fetched_At := Get_Long_Long_Field (Root, "fetched_at");

      if To_String (Cached_Url) /= Normalize_Base_Url (Base_Url)
        or else not Root.Has_Field ("data")
        or else Root.Get ("data").Kind /= GNATCOLL.JSON.JSON_Array_Type
      then
         return Result;
      end if;

      Result.Found := True;
      Result.Fresh := Is_Fresh (Fetched_At, Max_Age_Hours);
      Parse_Models (Root.Get ("data").Get, Result.Models);
      return Result;
   exception
      when others =>
         return Result;
   end Load_Cache;

   procedure Load_Catalogue
     (Base_Url      :     String;
      Token         :     String;
      Models        : out Catalogue_Vectors.Vector;
      Max_Age_Hours :     Natural := 24)
   is
      Cache_Result : constant Cache_Load_Result :=
        Load_Cache (Base_Url, Max_Age_Hours);
      Live_Models  : Catalogue_Vectors.Vector;
      Live_Data    : GNATCOLL.JSON.JSON_Value;
   begin
      if Cache_Result.Found and then Cache_Result.Fresh then
         Models := Cache_Result.Models;
         return;
      end if;

      if Fetch_Live
           (Base_Url => Base_Url,
            Token    => Token,
            Models   => Live_Models,
            Data     => Live_Data)
      then
         Models := Live_Models;
         Save_Cache (Base_Url, Live_Data);
         return;
      end if;

      if Cache_Result.Found then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "[!] GitHub Copilot model catalogue fetch failed; "
            & "using stale cache");
         Models := Cache_Result.Models;
      else
         Models.Clear;
      end if;
   end Load_Catalogue;

end LLM.Providers.GitHub_Copilot.Catalogue;
