--  LLM.Providers.OpenRouter.Catalogue body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Calendar;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNAT.OS_Lib;
with GNATCOLL.JSON;
with LLM.Settings;
with LLM.HTTP;

package body LLM.Providers.OpenRouter.Catalogue is

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

      return Base & "/openrouter_models_cache.json";
   end Cache_Path;

   function Base_Url return String is
   begin
      if Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL") then
         declare
            Value : constant String :=
               Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL");
         begin
            if Value'Length > 0 then
               return Value;
            end if;
         end;
      end if;

      return "https://openrouter.ai/api/v1";
   end Base_Url;

   function Endpoint_Url return String is
      Root : constant String := Base_Url;
   begin
      if Root'Length = 0 then
         return "/models";
      elsif Root (Root'Last) = '/' then
         return Root & "models";
      else
         return Root & "/models";
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
      File    : Ada.Text_IO.File_Type;
      Content : Unbounded_String;
   begin
      if Path'Length = 0 or else not Ada.Directories.Exists (Path) then
         return "";
      end if;

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);

      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line : constant String := Ada.Text_IO.Get_Line (File);
         begin
            Append (Content, Line);
            Append (Content, ASCII.LF);
         end;
      end loop;

      Ada.Text_IO.Close (File);
      return To_String (Content);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;

         return "";
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
         "[!] Failed to replace OpenRouter catalogue cache");
      end if;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;

         Delete_If_Exists (Tmp_Name);
         Ada.Text_IO.Put_Line
            (Ada.Text_IO.Standard_Error,
         "[!] Failed to write OpenRouter catalogue cache");
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

   function Parse_Price
      (Value   : GNATCOLL.JSON.JSON_Value;
     Field   : String;
     Default : Long_Float := 0.0) return Long_Float
   is
      Raw : constant String := Get_String_Field (Value, Field);
   begin
      if Raw'Length = 0 then
         return Default;
      end if;

      return Long_Float'Value (Raw) * 1_000_000.0;
   exception
      when others =>
         return Default;
   end Parse_Price;

   function Parse_Model (Value : GNATCOLL.JSON.JSON_Value) return Model_Info is
      Result         : Model_Info;
      Top_Provider   : constant GNATCOLL.JSON.JSON_Value :=
         Get_Object_Field (Value, "top_provider");
      Architecture   : constant GNATCOLL.JSON.JSON_Value :=
         Get_Object_Field (Value, "architecture");
      Pricing        : constant GNATCOLL.JSON.JSON_Value :=
         Get_Object_Field (Value, "pricing");
      Parameters     : constant GNATCOLL.JSON.JSON_Array :=
         Get_Array_Field (Value, "supported_parameters");
      Input_Modes    : constant GNATCOLL.JSON.JSON_Array :=
         Get_Array_Field (Architecture, "input_modalities");
      Top_Context    : constant Natural :=
         Get_Natural_Field (Top_Provider, "context_length", 0);
      Top_Max_Tokens : constant Natural :=
         Get_Natural_Field (Top_Provider, "max_completion_tokens", 0);
   begin
      Result.Model_Id := To_Unbounded_String (Get_String_Field (Value, "id"));
      Result.Name := To_Unbounded_String (Get_String_Field (Value, "name"));

      if Top_Context > 0 then
         Result.Context_Window := Top_Context;
      else
         Result.Context_Window :=
            Get_Natural_Field (Value, "context_length", Result.Context_Window);
      end if;

      if Top_Max_Tokens > 0 then
         Result.Max_Tokens := Top_Max_Tokens;
      else
         Result.Max_Tokens := 4_096;
      end if;

      Result.Supports_Tools := Array_Contains (Parameters, "tools");
      Result.Reasoning := Array_Contains (Parameters, "reasoning");
      Result.Supports_Images := Array_Contains (Input_Modes, "image");
      Result.Cost_Input       := Parse_Price (Pricing, "prompt");
      Result.Cost_Output      := Parse_Price (Pricing, "completion");
      Result.Cost_Cache_Read  := Parse_Price (Pricing, "input_cache_read");
      Result.Cost_Cache_Write := Parse_Price (Pricing, "input_cache_write");
      return Result;
   end Parse_Model;

   procedure Parse_Models
      (Items  :     GNATCOLL.JSON.JSON_Array;
     Models : out Catalogue_Vectors.Vector)
   is
   begin
      Models.Clear;

      for I in 1 .. GNATCOLL.JSON.Length (Items) loop
         Models.Append (Parse_Model (GNATCOLL.JSON.Get (Items, I)));
      end loop;
   end Parse_Models;

   function Fetch_Live
      (Models : out Catalogue_Vectors.Vector;
     Data   : out GNATCOLL.JSON.JSON_Value) return Boolean
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
      Parse_Models (Root.Get ("data").Get, Models);
      return True;
   exception
      when others =>
         Models.Clear;
         Data := GNATCOLL.JSON.JSON_Null;
         return False;
   end Fetch_Live;

   procedure Save_Cache (Data : GNATCOLL.JSON.JSON_Value) is
      Path : constant String := Cache_Path;
      Root : constant GNATCOLL.JSON.JSON_Value := GNATCOLL.JSON.Create_Object;
   begin
      if Path'Length = 0 or else Data.Kind /= GNATCOLL.JSON.JSON_Array_Type then
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

   function Load_Cache
      (Max_Age_Hours : Natural) return Cache_Load_Result
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
      Parse_Models (Root.Get ("data").Get, Result.Models);
      return Result;
   exception
      when others =>
         return Result;
   end Load_Cache;

   procedure Load_Catalogue
      (Models        :    out Catalogue_Vectors.Vector;
     Max_Age_Hours :        Natural := 24)
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

      if Cache_Result.Found then
         Ada.Text_IO.Put_Line
            (Ada.Text_IO.Standard_Error,
         "[!] OpenRouter model catalogue fetch failed; using stale cache");
         Models := Cache_Result.Models;
      else
         Models.Clear;
      end if;
   end Load_Catalogue;

end LLM.Providers.OpenRouter.Catalogue;
