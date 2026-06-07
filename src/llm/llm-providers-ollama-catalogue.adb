--  LLM.Providers.Ollama.Catalogue body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Calendar;
with Ada.Directories;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNAT.OS_Lib;
with GNATCOLL.JSON;
with LLM.HTTP;
with LLM.Settings;

package body LLM.Providers.Ollama.Catalogue is

   use type GNATCOLL.JSON.JSON_Value_Type;

   function Cache_Path return String is
      Base : constant String := LLM.Settings.Agent_Dir;
   begin
      if Base'Length = 0 then
         return "";
      end if;
      return Base & "/ollama_models_cache.json";
   end Cache_Path;

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
            "[!] Failed to replace Ollama catalogue cache");
      end if;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         Delete_If_Exists (Tmp_Name);
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "[!] Failed to write Ollama catalogue cache");
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

   function Parse_Model
     (Value : GNATCOLL.JSON.JSON_Value) return Model_Info
   is
      Id : constant String := Get_String_Field (Value, "name");
   begin
      return
        (Model_Id        => To_Unbounded_String (Id),
         Name            => To_Unbounded_String (Id),
         Context_Window  => 128_000,
         Max_Tokens      => 16_384,
         Reasoning       => False,
         Supports_Tools  => True,
         Supports_Images => False);
   end Parse_Model;

   procedure Parse_Models
     (Items  :     GNATCOLL.JSON.JSON_Array;
      Models : out Catalogue_Vectors.Vector)
   is
   begin
      Models.Clear;
      for I in 1 .. GNATCOLL.JSON.Length (Items) loop
         Models.Append
           (Parse_Model (GNATCOLL.JSON.Get (Items, I)));
      end loop;
   end Parse_Models;

   type Cache_Load_Result is record
      Found  : Boolean := False;
      Fresh  : Boolean := False;
      Models : Catalogue_Vectors.Vector;
   end record;

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
        or else not Root.Has_Field ("models")
        or else Root.Get ("models").Kind /= GNATCOLL.JSON.JSON_Array_Type
      then
         return Result;
      end if;
      Fetched_At := Get_Long_Long_Field (Root, "fetched_at");
      Result.Found := True;
      Result.Fresh := Is_Fresh (Fetched_At, Max_Age_Hours);
      Parse_Models (Root.Get ("models").Get, Result.Models);
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
         Root.Set_Field ("models", Data_Array);
      end;
      Write_Atomically (Path, GNATCOLL.JSON.Write (Root));
   end Save_Cache;

   function Fetch_Live
     (Base_Url  : String;
      Api_Key   : String;
      Models    : out Catalogue_Vectors.Vector;
      Root_Data : out GNATCOLL.JSON.JSON_Value) return Boolean
   is
      Headers       : LLM.HTTP.Header_List;
      Status        : Natural := 0;
      Response_Body : Unbounded_String;
      Parsed        : GNATCOLL.JSON.Read_Result;
      Root          : GNATCOLL.JSON.JSON_Value;
      Endpoint      : constant String :=
        (if Base_Url'Length = 0 then "http://localhost:11434/api/tags"
         elsif Base_Url (Base_Url'Last) = '/' then Base_Url & "api/tags"
         else Base_Url & "/api/tags");

      procedure On_Chunk (Chunk : String) is
      begin
         Append (Response_Body, Chunk);
      end On_Chunk;
   begin
      Models.Clear;
      Root_Data := GNATCOLL.JSON.JSON_Null;
      
      if Api_Key'Length > 0 then
         LLM.HTTP.Add_Header (Headers, "Authorization", "Bearer " & Api_Key);
      end if;
      
      LLM.HTTP.Get
        (URL      => Endpoint,
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
      
      Root_Data := Root.Get ("models");
      Parse_Models (Root.Get ("models").Get, Models);
      return True;
   exception
      when others =>
         Models.Clear;
         Root_Data := GNATCOLL.JSON.JSON_Null;
         return False;
   end Fetch_Live;

   procedure Load_Catalogue
     (Models        :    out Catalogue_Vectors.Vector;
      Base_Url      :        String := "";
      Api_Key       :        String := "";
      Max_Age_Hours :        Natural := 24)
   is
      Cache_Result : constant Cache_Load_Result :=
        Load_Cache (Max_Age_Hours);
      Live_Models : Catalogue_Vectors.Vector;
      Live_Data   : GNATCOLL.JSON.JSON_Value;
   begin
      if Cache_Result.Found and then Cache_Result.Fresh then
         Models := Cache_Result.Models;
         return;
      end if;
      
      if Fetch_Live (Base_Url => Base_Url, Api_Key => Api_Key, Models => Live_Models, Root_Data => Live_Data) then
         Models := Live_Models;
         Save_Cache (Live_Data);
         return;
      end if;
      
      if Cache_Result.Found then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "[!] Ollama model catalogue fetch failed; using stale cache");
         Models := Cache_Result.Models;
      else
         Models.Clear;
      end if;
   end Load_Catalogue;

end LLM.Providers.Ollama.Catalogue;
