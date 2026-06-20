--  LLM.Providers.Ollama.Catalogue body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Calendar;
with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNAT.OS_Lib;
with GNATCOLL.JSON;
with LLM.HTTP;
with Coyote_Utils;
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

   function Get_Natural_Field
     (Value   : GNATCOLL.JSON.JSON_Value;
      Field   : String;
      Default : Natural := 0) return Natural
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

   function Get_Object_Field
     (Value : GNATCOLL.JSON.JSON_Value;
      Field : String) return GNATCOLL.JSON.JSON_Value
   is
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind
          = GNATCOLL.JSON.JSON_Object_Type
      then
         return Value.Get (Field);
      end if;
      return GNATCOLL.JSON.JSON_Null;
   end Get_Object_Field;

   --  Parse_Model — now reads fields written by Fetch_Live from
   --  /api/show enrichment (context, reasoning, vision booleans).
   function Parse_Model
     (Value : GNATCOLL.JSON.JSON_Value) return Model_Info
   is
      Id         : constant String := Get_String_Field (Value, "name");
      Ctx        : constant Natural :=
        Get_Natural_Field (Value, "context", 128_000);
      Has_Reason : constant Boolean :=
        (if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
           and then Value.Has_Field ("reasoning")
         then Value.Get ("reasoning").Get
         else False);
      Has_Vis    : constant Boolean :=
        (if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
           and then Value.Has_Field ("vision")
         then Value.Get ("vision").Get
         else False);
   begin
      return
        (Model_Id        => To_Unbounded_String (Id),
         Name            => To_Unbounded_String (Id),
         Context_Window  => Ctx,
         Max_Tokens      => 16_384,
         Reasoning       => Has_Reason,
         Supports_Tools  => True,
         Supports_Images => Has_Vis);
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

   --  Fetch_Live — two-phase fetch: /api/tags for model list, then
   --  /api/show per model to extract capabilities, context length,
   --  reasoning, and vision flags.
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
      Tags_Endpoint : constant String :=
        (if Base_Url'Length = 0 then "https://ollama.com/api/tags"
         elsif Base_Url (Base_Url'Last) = '/' then Base_Url & "api/tags"
         else Base_Url & "/api/tags");
      Show_Base     : constant String :=
        (if Base_Url'Length = 0 then "https://ollama.com/"
         elsif Base_Url (Base_Url'Last) = '/' then Base_Url
         else Base_Url & "/");

      procedure On_Chunk (Chunk : String) is
      begin
         Append (Response_Body, Chunk);
      end On_Chunk;

      procedure Fetch_Show_Detail
        (Model_Name :     String;
         Ctx        : out Natural;
         Has_Reason : out Boolean;
         Has_Vis    : out Boolean)
      is
         Body_Text : Unbounded_String;
         Hdrs      : LLM.HTTP.Header_List;
         St        : Natural := 0;

         procedure On_Chunk_Show (Chunk : String) is
         begin
            Append (Body_Text, Chunk);
         end On_Chunk_Show;

         Req_Obj : GNATCOLL.JSON.JSON_Value :=
           GNATCOLL.JSON.Create_Object;
      begin
         Ctx        := 128_000;
         Has_Reason := False;
         Has_Vis    := False;

         Req_Obj.Set_Field ("name", Model_Name);

         if Api_Key'Length > 0 then
            LLM.HTTP.Add_Header
              (Hdrs, "Authorization", "Bearer " & Api_Key);
         end if;
         LLM.HTTP.Add_Header
           (Hdrs, "Content-Type", "application/json");

         LLM.HTTP.Post
           (URL      => Show_Base & "api/show",
            Headers  => Hdrs,
            Payload  => GNATCOLL.JSON.Write (Req_Obj),
            On_Chunk => On_Chunk_Show'Access,
            Status   => St);

         if St /= 200 then
            return;
         end if;

         declare
            Result : constant GNATCOLL.JSON.Read_Result :=
              GNATCOLL.JSON.Read (To_String (Body_Text));
         begin
            if not Result.Success then
               return;
            end if;

            declare
               Show_Root  : constant GNATCOLL.JSON.JSON_Value :=
                 Result.Value;
               Caps_Array : GNATCOLL.JSON.JSON_Array;
               MI_Obj     : GNATCOLL.JSON.JSON_Value;
            begin
               if Show_Root.Has_Field ("capabilities")
                 and then Show_Root.Get ("capabilities").Kind
                   = GNATCOLL.JSON.JSON_Array_Type
               then
                  Caps_Array := Show_Root.Get ("capabilities").Get;
                  for I in 1 .. GNATCOLL.JSON.Length (Caps_Array) loop
                     declare
                        Cap : constant String :=
                          Ada.Characters.Handling.To_Lower
                            (GNATCOLL.JSON.Get (Caps_Array, I).Get);
                     begin
                        if Cap = "thinking" then
                           Has_Reason := True;
                        elsif Cap = "vision" then
                           Has_Vis := True;
                        end if;
                     end;
                  end loop;
               end if;

               if Show_Root.Has_Field ("model_info")
                 and then Show_Root.Get ("model_info").Kind
                   = GNATCOLL.JSON.JSON_Object_Type
               then
                  MI_Obj := Show_Root.Get ("model_info");
                  if MI_Obj.Has_Field ("general.architecture")
                    and then MI_Obj.Get ("general.architecture").Kind
                      = GNATCOLL.JSON.JSON_String_Type
                  then
                     declare
                        Arch    : constant String :=
                          MI_Obj.Get ("general.architecture").Get;
                        Ctx_Key : constant String :=
                          Arch & ".context_length";
                     begin
                        if MI_Obj.Has_Field (Ctx_Key)
                          and then MI_Obj.Get (Ctx_Key).Kind
                            = GNATCOLL.JSON.JSON_Int_Type
                        then
                           declare
                              Raw : constant Long_Integer :=
                                MI_Obj.Get (Ctx_Key).Get;
                           begin
                              if Raw > 0 then
                                 Ctx := Natural (Raw);
                              end if;
                           end;
                        end if;
                     end;
                  end if;
               end if;
            end;
         end;
      exception
         when others =>
            Ctx        := 128_000;
            Has_Reason := False;
            Has_Vis    := False;
      end Fetch_Show_Detail;
   begin
      Models.Clear;
      Root_Data := GNATCOLL.JSON.JSON_Null;

      if Api_Key'Length > 0 then
         LLM.HTTP.Add_Header
           (Headers, "Authorization", "Bearer " & Api_Key);
      end if;

      --  Step 1: get model list from /api/tags.
      LLM.HTTP.Get
        (URL      => Tags_Endpoint,
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

      --  Step 2: enrich each model with /api/show data.
      declare
         Tag_Items        : constant GNATCOLL.JSON.JSON_Array :=
           Root.Get ("models").Get;
         Ctx              : Natural;
         Has_Reason       : Boolean;
         Has_Vis          : Boolean;
         Enriched_Entries : GNATCOLL.JSON.JSON_Array :=
           GNATCOLL.JSON.Empty_Array;
      begin
         for I in 1 .. GNATCOLL.JSON.Length (Tag_Items) loop
            declare
               Item     : constant GNATCOLL.JSON.JSON_Value :=
                 GNATCOLL.JSON.Get (Tag_Items, I);
               Name_Str : constant String :=
                 Get_String_Field (Item, "name");
            begin
               if Name_Str'Length > 0 then
                  Fetch_Show_Detail (Name_Str, Ctx, Has_Reason, Has_Vis);
                  declare
                     Entry_Obj : constant GNATCOLL.JSON.JSON_Value :=
                       GNATCOLL.JSON.Create_Object;
                  begin
                     Entry_Obj.Set_Field ("name", Name_Str);
                     Entry_Obj.Set_Field
                       ("context", Long_Integer (Ctx));
                     Entry_Obj.Set_Field ("reasoning", Has_Reason);
                     Entry_Obj.Set_Field ("vision", Has_Vis);
                     GNATCOLL.JSON.Append (Enriched_Entries, Entry_Obj);
                  end;
               end if;
            end;
         end loop;

         Root_Data := GNATCOLL.JSON.Create (Enriched_Entries);
         Parse_Models (Enriched_Entries, Models);
      end;

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

      if Fetch_Live (Base_Url => Base_Url, Api_Key => Api_Key,
                     Models => Live_Models, Root_Data => Live_Data)
      then
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
