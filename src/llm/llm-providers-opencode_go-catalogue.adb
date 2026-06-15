--  LLM.Providers.OpenCode_Go.Catalogue body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Calendar;
with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNAT.OS_Lib;
with GNATCOLL.JSON;
with LLM.HTTP;
with LLM.Providers.OpenRouter.Catalogue;
with LLM.Settings;
with Coyote_Utils;

package body LLM.Providers.OpenCode_Go.Catalogue is

   use type GNATCOLL.JSON.JSON_Value_Type;

   --  Per-model metadata for known OpenCode Go models.
   --  Metadata is obtained by cross-referencing each model ID against
   --  the OpenRouter model catalogue (live or cached).  Models not found
   --  on OpenRouter fall back to conservative defaults.

   function Wire_Format_For (Model_Id : String) return Wire_Kind is
      Lower_Id : constant String :=
        Ada.Characters.Handling.To_Lower (Model_Id);
   begin
      --  MiniMax M2.5 and M2.7 use the Anthropic /v1/messages endpoint.
      if Lower_Id = "minimax-m2.5"
        or else Lower_Id = "minimax-m2.7"
      then
         return Anthropic_Messages_Wire;
      end if;
      return OpenAI_Completions_Wire;
   end Wire_Format_For;

   ------------------------------------------------------------
   --  OpenRouter cross-reference helpers
   ------------------------------------------------------------

   function Base_Name (Model_Id : String) return String is
      Pos : Natural := 0;
   begin
      for I in reverse Model_Id'Range loop
         if Model_Id (I) = '/' then
            Pos := I;
            exit;
         end if;
      end loop;
      if Pos > 0 and then Pos < Model_Id'Last then
         return Ada.Characters.Handling.To_Lower
           (Model_Id (Pos + 1 .. Model_Id'Last));
      end if;
      return Ada.Characters.Handling.To_Lower (Model_Id);
   end Base_Name;

   function Find_OpenRouter_Meta
     (Go_Model_Id : String;
      OR_Models   : LLM.Providers.OpenRouter.Catalogue.Catalogue_Vectors.Vector)
     return LLM.Providers.OpenRouter.Catalogue.Model_Info
   is
      Lower_Id : constant String :=
        Ada.Characters.Handling.To_Lower (Go_Model_Id);
   begin
      for OR_Model of OR_Models loop
         if Base_Name (To_String (OR_Model.Model_Id)) = Lower_Id then
            return OR_Model;
         end if;
      end loop;
      --  Return a default with conservative values.
      return
        (Model_Id        => To_Unbounded_String (Go_Model_Id),
         Name            => To_Unbounded_String (Go_Model_Id),
         Context_Window  => 128_000,
         Max_Tokens      => 16_384,
         Supports_Tools  => True,
         Supports_Images => False,
         Reasoning       => False,
         Cost_Input      => 0.0,
         Cost_Output     => 0.0,
         Cost_Cache_Read => 0.0,
         Cost_Cache_Write => 0.0);
   end Find_OpenRouter_Meta;

   ------------------------------------------------------------
   --  Cache-path and HTTP utilities
   ------------------------------------------------------------

   function Cache_Path return String is
      Base : constant String := LLM.Settings.Agent_Dir;
   begin
      if Base'Length = 0 then
         return "";
      end if;
      return Base & "/opencode_go_models_cache.json";
   end Cache_Path;

   function Base_Url return String is
   begin
      if Ada.Environment_Variables.Exists ("COYOTE_OPENCODE_GO_BASE_URL") then
         declare
            Value : constant String :=
              Ada.Environment_Variables.Value
                ("COYOTE_OPENCODE_GO_BASE_URL");
         begin
            if Value'Length > 0 then
               return Value;
            end if;
         end;
      end if;
      return "https://opencode.ai/zen/go";
   end Base_Url;

   function Endpoint_Url return String is
      Root : constant String := Base_Url;
   begin
      if Root'Length = 0 then
         return "/v1/models";
      elsif Root (Root'Last) = '/' then
         return Root & "v1/models";
      else
         return Root & "/v1/models";
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
      Renamed  : Boolean := False;
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
            "[!] Failed to replace OpenCode Go catalogue cache");
      end if;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         Delete_If_Exists (Tmp_Name);
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "[!] Failed to write OpenCode Go catalogue cache");
   end Write_Atomically;

   function Current_Unix_S return Long_Long_Integer is
      use Ada.Calendar;
      Epoch : constant Time :=
        Time_Of (Year    => 1970,
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

   ------------------------------------------------------------
   --  Model parsing with OpenRouter cross-reference
   ------------------------------------------------------------

   function Parse_Model
     (Value    : GNATCOLL.JSON.JSON_Value;
      OR_Meta  : LLM.Providers.OpenRouter.Catalogue.Model_Info)
     return Model_Info
   is
      Id : constant String := Get_String_Field (Value, "id");
   begin
      return
        (Model_Id        => To_Unbounded_String (Id),
         Name            => To_Unbounded_String (Id),
         Context_Window  => OR_Meta.Context_Window,
         Max_Tokens      => OR_Meta.Max_Tokens,
         Reasoning       => OR_Meta.Reasoning,
         Supports_Tools  => OR_Meta.Supports_Tools,
         Supports_Images => OR_Meta.Supports_Images,
         Wire            => Wire_Format_For (Id),
         Cost_Input      => OR_Meta.Cost_Input,
         Cost_Output     => OR_Meta.Cost_Output,
         Cost_Cache_Read => OR_Meta.Cost_Cache_Read,
         Cost_Cache_Write => OR_Meta.Cost_Cache_Write);
   end Parse_Model;

   procedure Parse_Models
     (Items     :     GNATCOLL.JSON.JSON_Array;
      Models    : out Catalogue_Vectors.Vector;
      OR_Models :     LLM.Providers.OpenRouter.Catalogue.Catalogue_Vectors.Vector)
   is
      Go_Id   : String (1 .. 256);
      Go_Len  : Natural;
      OR_Meta : LLM.Providers.OpenRouter.Catalogue.Model_Info;
   begin
      Models.Clear;
      for I in 1 .. GNATCOLL.JSON.Length (Items) loop
         declare
            Raw_Id : constant String := Get_String_Field
              (GNATCOLL.JSON.Get (Items, I), "id");
         begin
            Go_Len := Raw_Id'Length;
            Go_Id (1 .. Go_Len) := Raw_Id;
         end;
         OR_Meta := Find_OpenRouter_Meta (Go_Id (1 .. Go_Len), OR_Models);
         Models.Append
           (Parse_Model
             (GNATCOLL.JSON.Get (Items, I), OR_Meta));
      end loop;
   end Parse_Models;

   ------------------------------------------------------------
   --  Caching layer
   ------------------------------------------------------------

   type Cache_Load_Result is record
      Found  : Boolean := False;
      Fresh  : Boolean := False;
      Models : Catalogue_Vectors.Vector;
   end record;

   function Load_Cache
     (Max_Age_Hours : Natural;
      OR_Models     : LLM.Providers.OpenRouter.Catalogue.Catalogue_Vectors.Vector)
     return Cache_Load_Result
   is
      Path       : constant String := Cache_Path;
      Content    : constant String := Read_File (Path);
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
        or else not Root.Has_Field ("data")
        or else Root.Get ("data").Kind /= GNATCOLL.JSON.JSON_Array_Type
      then
         return Result;
      end if;
      Fetched_At := Get_Long_Long_Field (Root, "fetched_at");
      Result.Found := True;
      Result.Fresh := Is_Fresh (Fetched_At, Max_Age_Hours);
      Parse_Models (Root.Get ("data").Get, Result.Models, OR_Models);
      return Result;
   exception
      when others =>
         return Result;
   end Load_Cache;

   procedure Save_Cache (Data : GNATCOLL.JSON.JSON_Value) is
      Path : constant String := Cache_Path;
      Root : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
   begin
      if Path'Length = 0
        or else Data.Kind /= GNATCOLL.JSON.JSON_Array_Type
      then
         return;
      end if;
      Root.Set_Field ("fetched_at", Long_Integer (Current_Unix_S));
      declare
         Data_Array : constant GNATCOLL.JSON.JSON_Array := Data.Get;
      begin
         Root.Set_Field ("data", Data_Array);
      end;
      Write_Atomically (Path, GNATCOLL.JSON.Write (Root));
   end Save_Cache;

   function Fetch_Live
     (Models    : out Catalogue_Vectors.Vector;
      Data      : out GNATCOLL.JSON.JSON_Value;
      OR_Models :     LLM.Providers.OpenRouter.Catalogue.Catalogue_Vectors.Vector)
     return Boolean
   is
      Headers       : LLM.HTTP.Header_List;
      Status        : Natural := 0;
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
      LLM.HTTP.Get
        (URL      => Endpoint_Url,
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
      Parse_Models (Root.Get ("data").Get, Models, OR_Models);
      return True;
   exception
      when others =>
         Models.Clear;
         Data := GNATCOLL.JSON.JSON_Null;
         return False;
   end Fetch_Live;

   ------------------------------------------------------------
   --  Public entry point
   ------------------------------------------------------------

   procedure Load_Catalogue
     (Models        :    out Catalogue_Vectors.Vector;
      Max_Age_Hours :        Natural := 24)
   is
      --  Load the OpenRouter catalogue first so its metadata is
      --  available for cross-referencing during cache and live paths.
      OR_Models    : LLM.Providers.OpenRouter.Catalogue.Catalogue_Vectors.Vector;
      Cache_Result : Cache_Load_Result;
      Live_Models  : Catalogue_Vectors.Vector;
      Live_Data    : GNATCOLL.JSON.JSON_Value;
   begin
      LLM.Providers.OpenRouter.Catalogue.Load_Catalogue
        (OR_Models, Max_Age_Hours);

      Cache_Result := Load_Cache (Max_Age_Hours, OR_Models);

      if Cache_Result.Found and then Cache_Result.Fresh then
         Models := Cache_Result.Models;
         return;
      end if;

      if Fetch_Live (Models => Live_Models, Data => Live_Data,
                     OR_Models => OR_Models)
      then
         Models := Live_Models;
         Save_Cache (Live_Data);
         return;
      end if;

      if Cache_Result.Found then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "[!] OpenCode Go model catalogue fetch failed; using stale cache");
         Models := Cache_Result.Models;
      else
         Models.Clear;
      end if;
   end Load_Catalogue;

end LLM.Providers.OpenCode_Go.Catalogue;
