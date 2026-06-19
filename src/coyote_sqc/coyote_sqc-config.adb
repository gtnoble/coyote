--  Coyote_SQC.Config body.
--
--  Project: coyote

with Ada.Calendar;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with GNAT.OS_Lib;
with Coyote_Utils;
with GNATCOLL.JSON;
with LLM.HTTP;

package body Coyote_SQC.Config is

   use type GNATCOLL.JSON.JSON_Value_Type;

   function Config_Dir return String is
      Home : constant String := GNAT.OS_Lib.Getenv ("HOME").all;
      Dir  : constant String := Home & "/.config/coyote_sqc";
   begin
      if not Ada.Directories.Exists (Dir) then
         Ada.Directories.Create_Path (Dir);
      end if;
      return Dir;
   end Config_Dir;

   function Recent_File return String is (Config_Dir & "/recent_workspaces.json");

   --  ── JSON helpers ──────────────────────────────────────────────────────

   function Get_String (V : GNATCOLL.JSON.JSON_Value; F : String) return String is
   begin
      if V.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then V.Has_Field (F)
        and then V.Get (F).Kind = GNATCOLL.JSON.JSON_String_Type
      then
         return V.Get (F).Get;
      end if;
      return "";
   end Get_String;

   function Get_Int (V : GNATCOLL.JSON.JSON_Value; F : String) return Long_Long_Integer is
   begin
      if V.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then V.Has_Field (F)
        and then V.Get (F).Kind = GNATCOLL.JSON.JSON_Int_Type
      then
         return Long_Long_Integer (Long_Integer'(V.Get (F).Get));
      end if;
      return 0;
   end Get_Int;

   --  ── Load ──────────────────────────────────────────────────────────────
   function Load_Recent return Recent_List is
      Result  : Recent_List;
      Path    : constant String := Recent_File;
      Content : constant String := Coyote_Utils.Read_Whole_File (Path);
      Root    : GNATCOLL.JSON.JSON_Value;
   begin
      if Content'Length = 0 then
         return Result;
      end if;
      Root := GNATCOLL.JSON.Read (Content);
      if Root.Kind /= GNATCOLL.JSON.JSON_Object_Type then
         return Result;
      end if;
      if not Root.Has_Field ("recent") then
         return Result;
      end if;

      declare
         Arr : constant GNATCOLL.JSON.JSON_Array := Root.Get ("recent");
         N   : constant Natural := GNATCOLL.JSON.Length (Arr);
      begin
         for I in 1 .. Natural'Min (N, Max_Recent) loop
            declare
               E : constant GNATCOLL.JSON.JSON_Value :=
                 GNATCOLL.JSON.Get (Arr, I);
            begin
               Result.Count := Result.Count + 1;
               Result.Entries (I) :=
                 (Name        => To_Unbounded_String (Get_String (E, "name")),
                  Path        => To_Unbounded_String (Get_String (E, "path")),
                  Last_Opened => Get_Int (E, "lastOpened"));
            end;
         end loop;
      end;
      return Result;
   exception
      when E : others =>
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "coyote_sqc: failed to load recent workspaces: "
            & Ada.Exceptions.Exception_Information (E));
         return Result;
   end Load_Recent;



   procedure Record_Open (Name : String; Path : String) is
      use Ada.Calendar;
      Epoch   : constant Ada.Calendar.Time :=
        Ada.Calendar.Time_Of (1970, 1, 1, 0.0);
      Now_Ms  : constant Long_Long_Integer :=
        Long_Long_Integer ((Ada.Calendar.Clock - Epoch) * 1000.0);

      Old     : Recent_List := Load_Recent;
      New_L   : Recent_List;

      --  Build the new entry.
      New_E   : constant Recent_Entry :=
        (Name        => To_Unbounded_String (Name),
         Path        => To_Unbounded_String (Path),
         Last_Opened => Now_Ms);

      --  Write as JSON.
      procedure Write is
         use GNATCOLL.JSON;
         Root    : JSON_Value := Create_Object;
         Arr     : JSON_Array := Empty_Array;
         Tmp     : constant String := Recent_File & ".tmp";
         Dest    : constant String := Recent_File;
         File    : Ada.Text_IO.File_Type;
      begin
         Root.Set_Field ("version", Integer (1));
         for I in 1 .. Integer (New_L.Count) loop
            declare
               Obj : JSON_Value := Create_Object;
               E   : Recent_Entry := New_L.Entries (I);
            begin
               Obj.Set_Field ("name",        To_String (E.Name));
               Obj.Set_Field ("path",        To_String (E.Path));
               Obj.Set_Field ("lastOpened",  Long_Integer (E.Last_Opened));
               Append (Arr, Obj);
            end;
         end loop;
         Root.Set_Field ("recent", Arr);
         Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Tmp);
         Ada.Text_IO.Put_Line (File, Write (Root));
         Ada.Text_IO.Close (File);
         if Ada.Directories.Exists (Dest) then
            Ada.Directories.Delete_File (Dest);
         end if;
         Ada.Directories.Rename (Tmp, Dest);
      end Write;

   begin
      --  Put the new entry first.
      New_L.Count := 1;
      New_L.Entries (1) := New_E;

      --  Append old entries, skipping any that match the same path.
      for I in 1 .. Integer (Old.Count) loop
         exit when Integer (New_L.Count) = Max_Recent;
         if To_String (Old.Entries (I).Path) /= Path then
            New_L.Count := New_L.Count + 1;
            New_L.Entries (Integer (New_L.Count)) := Old.Entries (I);
         end if;
      end loop;

      Write;
   exception
      when E : others =>
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "coyote_sqc: failed to update recent workspaces list: "
            & Ada.Exceptions.Exception_Information (E));
   end Record_Open;

   --  ── Pricing ────────────────────────────────────────────────────────

   --  ── OpenRouter helpers ─────────────────────────────────────────────

   function OpenRouter_Base_Url return String is
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
   end OpenRouter_Base_Url;

   function OpenRouter_Api_Url return String is
      Root : constant String := OpenRouter_Base_Url;
   begin
      if Root (Root'Last) = '/' then
         return Root & "models";
      else
         return Root & "/models";
      end if;
   end OpenRouter_Api_Url;

   function OpenRouter_Cache_Path return String is
     (Config_Dir & "/openrouter_models_cache.json");

   function Current_Unix_S return Long_Long_Integer is
      use Ada.Calendar;
      Epoch : constant Time :=
        Time_Of (1970, 1, 1, 0.0);
   begin
      return Long_Long_Integer (Clock - Epoch);
   end Current_Unix_S;

   function Cache_Is_Fresh (Fetched_At : Long_Long_Integer) return Boolean is
      Age_Limit : constant Long_Long_Integer := 24 * 3600;
      Now_S     : constant Long_Long_Integer := Current_Unix_S;
   begin
      if Fetched_At <= 0 then
         return False;
      end if;
      if Fetched_At >= Now_S then
         return True;
      end if;
      return Now_S - Fetched_At <= Age_Limit;
   end Cache_Is_Fresh;

   --  Parse a string price value (OpenRouter returns all prices as strings).
   function Parse_Price_String (S : String) return Long_Float is
   begin
      return Long_Float'Value (S);
   exception
      when others =>
         return 0.0;
   end Parse_Price_String;

   --  Parse one model entry from the OpenRouter API response.
   --  Extracts id and pricing sub-object, returns prices.
   function Parse_OpenRouter_Model
     (Obj : GNATCOLL.JSON.JSON_Value)
      return Coyote_SQC.Metrics.Per_Token_Prices
   is
      use GNATCOLL.JSON;
   begin
      if Obj.Kind /= JSON_Object_Type
        or else not Obj.Has_Field ("pricing")
      then
         return (others => 0.0);
      end if;

      declare
         Pricing : constant JSON_Value := Obj.Get ("pricing");
         function Get_PF (F : String) return Long_Float is
            V : constant JSON_Value := Pricing.Get (F);
         begin
            if V.Kind = JSON_String_Type then
               return Parse_Price_String (V.Get);
            elsif V.Kind = JSON_Int_Type then
               return Long_Float (Long_Integer'(V.Get));
            elsif V.Kind = JSON_Float_Type then
               return Get_Long_Float (Pricing, F);
            end if;
            return 0.0;
         end Get_PF;
      begin
         return
           (Input_Price       => Get_PF ("prompt"),
            Output_Price      => Get_PF ("completion"),
            Cache_Read_Price  => Get_PF ("input_cache_read"),
            Cache_Write_Price => Get_PF ("input_cache_write"));
      end;
   end Parse_OpenRouter_Model;

   --  Fetch pricing from the live OpenRouter API.
   --  Returns True and populates Models_Json with the "data" array on success.
   procedure Fetch_OpenRouter_Pricing
     (Models_Json : out GNATCOLL.JSON.JSON_Value;
      Success     : out Boolean)
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

      use GNATCOLL.JSON;
   begin
      Models_Json := JSON_Null;
      Success     := False;

      LLM.HTTP.Get
        (URL      => OpenRouter_Api_Url,
         Headers  => Headers,
         On_Chunk => On_Chunk'Access,
         Status   => Status);

      if Status /= 200 then
         return;
      end if;

      Parsed := Read (To_String (Response_Body));
      if not Parsed.Success then
         return;
      end if;

      Root := Parsed.Value;
      if Root.Kind /= JSON_Object_Type
        or else not Root.Has_Field ("data")
      then
         return;
      end if;

      Models_Json := Root.Get ("data");
      Success     := True;
   exception
      when others =>
         Models_Json := JSON_Null;
         Success     := False;
   end Fetch_OpenRouter_Pricing;

   --  Save the OpenRouter cache file atomically.
   procedure Save_OpenRouter_Cache (Models_Array : GNATCOLL.JSON.JSON_Array) is
      Path     : constant String := OpenRouter_Cache_Path;
      Tmp_Path : constant String := Path & ".tmp";
      File     : Ada.Text_IO.File_Type;
      Renamed  : Boolean := False;
      Root     : GNATCOLL.JSON.JSON_Value := GNATCOLL.JSON.Create_Object;
   begin
      Root.Set_Field ("fetched_at", Long_Integer (Current_Unix_S));
      Root.Set_Field ("models", Models_Array);
      Ada.Directories.Create_Path (Config_Dir);

      if Ada.Directories.Exists (Tmp_Path) then
         Ada.Directories.Delete_File (Tmp_Path);
      end if;

      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Tmp_Path);
      Ada.Text_IO.Put (File, GNATCOLL.JSON.Write (Root));
      Ada.Text_IO.Close (File);

      GNAT.OS_Lib.Rename_File (Tmp_Path, Path, Renamed);
      if not Renamed then
         if Ada.Directories.Exists (Tmp_Path) then
            Ada.Directories.Delete_File (Tmp_Path);
         end if;
      end if;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         if Ada.Directories.Exists (Tmp_Path) then
            Ada.Directories.Delete_File (Tmp_Path);
         end if;
   end Save_OpenRouter_Cache;

   --  Load models from the OpenRouter cache and add them to the pricing table.
   --  Only adds models not already present in Table (local pricing wins).
   procedure Load_OpenRouter_Cache
     (Table : in out Coyote_SQC.Metrics.Pricing_Table)
   is
      Path    : constant String := OpenRouter_Cache_Path;
      Content : constant String := Coyote_Utils.Read_Whole_File (Path);
      Parsed  : GNATCOLL.JSON.Read_Result;
      Root    : GNATCOLL.JSON.JSON_Value;
      Arr     : GNATCOLL.JSON.JSON_Array;

      use GNATCOLL.JSON;
   begin
      if Content'Length = 0 then
         return;
      end if;

      Parsed := Read (Content);
      if not Parsed.Success then
         return;
      end if;

      Root := Parsed.Value;
      if Root.Kind /= JSON_Object_Type
        or else not Root.Has_Field ("models")
      then
         return;
      end if;

      Arr := Root.Get ("models").Get;
      for I in 1 .. Length (Arr) loop
         declare
            Model_Obj : constant JSON_Value := Get (Arr, I);
            Model_Id  : constant String :=
              (if Model_Obj.Kind = JSON_Object_Type
                 and then Model_Obj.Has_Field ("id")
                 and then Model_Obj.Get ("id").Kind = JSON_String_Type
               then Model_Obj.Get ("id").Get
               else "");
         begin
            if Model_Id'Length > 0
              and then not Table.Contains (To_Unbounded_String (Model_Id))
            then
               Table.Include
                 (To_Unbounded_String (Model_Id),
                  Parse_OpenRouter_Model (Model_Obj));
            end if;
         end;
      end loop;
   exception
      when others =>
         null;  --  Cache corrupted; silently skip
   end Load_OpenRouter_Cache;

   --  ── Load_Pricing ──────────────────────────────────────────────────

   function Load_Pricing return Coyote_SQC.Metrics.Pricing_Table is
      Result   : Coyote_SQC.Metrics.Pricing_Table;
      Dir      : constant String := Config_Dir;
      Cfg_Path : constant String := Dir & "/pricing.json";

      function Parse_Prices (Obj : GNATCOLL.JSON.JSON_Value)
        return Coyote_SQC.Metrics.Per_Token_Prices
      is
         function Get_LF (F : String) return Long_Float is
            V : constant GNATCOLL.JSON.JSON_Value := Obj.Get (F);
         begin
            if V.Kind = GNATCOLL.JSON.JSON_Int_Type then
               return Long_Float (Long_Integer'(V.Get));
            elsif V.Kind = GNATCOLL.JSON.JSON_Float_Type then
               return GNATCOLL.JSON.Get_Long_Float (Obj, F);
            end if;
            return 0.0;
         end Get_LF;
      begin
         return
           (Input_Price       => Get_LF ("input_price"),
            Output_Price      => Get_LF ("output_price"),
            Cache_Read_Price  => Get_LF ("cache_read_price"),
            Cache_Write_Price => Get_LF ("cache_write_price"));
      end Parse_Prices;

      --  Callback for Map_JSON_Object: accumulate model name → prices.
      procedure Add_Model
        (Name  : String;
         Value : GNATCOLL.JSON.JSON_Value)
      is
      begin
         Result.Include
           (To_Unbounded_String (Name), Parse_Prices (Value));
      end Add_Model;

   begin
      --  1. Load local pricing.json (highest priority).
      begin
         declare
            Content : constant String :=
              Coyote_Utils.Read_Whole_File (Cfg_Path);
            Root    : GNATCOLL.JSON.JSON_Value;
         begin
            if Content'Length > 0 then
               Root := GNATCOLL.JSON.Read (Content);
               if Root.Has_Field ("models") then
                  Root.Get ("models").Map_JSON_Object
                    (Add_Model'Access);
               end if;
            end if;
         end;
      exception
         when others =>
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "coyote_sqc: failed to load pricing from " & Cfg_Path);
      end;

      --  2. OpenRouter fallback: try to refresh the cache, then load
      --     any models not already found in the local pricing file.
      declare
         Cache_Path : constant String := OpenRouter_Cache_Path;
         Reuse_Cache : Boolean := False;
         Stale       : Boolean := True;
      begin
         --  Check if cache is fresh enough to reuse.
         if Ada.Directories.Exists (Cache_Path) then
            declare
               Content : constant String :=
                 Coyote_Utils.Read_Whole_File (Cache_Path);
               Parsed  : constant GNATCOLL.JSON.Read_Result :=
                 GNATCOLL.JSON.Read (Content);
               Fetched : Long_Long_Integer := 0;
            begin
               if Parsed.Success then
                  Fetched := Get_Int (Parsed.Value, "fetched_at");
               end if;
               if Cache_Is_Fresh (Fetched) then
                  Reuse_Cache := True;
                  Stale := False;
               end if;
            exception
               when others => null;
            end;
         end if;

         --  If cache is stale or missing, try to fetch from the live API.
         if not Reuse_Cache then
            declare
               Live_Data : GNATCOLL.JSON.JSON_Value;
               Fetched   : Boolean := False;
            begin
               Fetch_OpenRouter_Pricing (Live_Data, Fetched);
               if Fetched
                 and then Live_Data.Kind = GNATCOLL.JSON.JSON_Array_Type
               then
                  Save_OpenRouter_Cache (Live_Data.Get);
                  Stale := False;
               end if;
            exception
               when others =>
                  null;  --  Network/parse failure; skip silently
            end;
         end if;

         --  Load the cache into the pricing table (skip models already
         --  present from the local pricing file).
         if not Stale then
            Load_OpenRouter_Cache (Result);
         end if;

      --  3. Build fallback entries keyed by model name only (no provider
      --     prefix).  Sessions recorded with proxy-provider prefixes
      --     (e.g. github-copilot/claude-sonnet-4.6) can then match
      --     OpenRouter pricing entries (e.g. anthropic/claude-sonnet-4.6)
      --     by looking up the model-name portion alone.
      declare
         use Coyote_SQC.Metrics;
         Curs : Pricing_Maps.Cursor := Result.First;
         use Ada.Strings.Fixed;
      begin
         while Pricing_Maps.Has_Element (Curs) loop
            declare
               Key : constant String := To_String (Pricing_Maps.Key (Curs));
               Slash : constant Natural := Index (Key, "/");
            begin
               if Slash > 0 and then Slash < Key'Last then
                  declare
                     Model_Only : constant Unbounded_String :=
                       To_Unbounded_String (Key (Slash + 1 .. Key'Last));
                  begin
                     if not Result.Contains (Model_Only) then
                        Result.Include
                          (Model_Only, Pricing_Maps.Element (Curs));
                     end if;
                  end;
               end if;
            end;
            Pricing_Maps.Next (Curs);
         end loop;
      end;
      end;

      return Result;
   end Load_Pricing;

end Coyote_SQC.Config;
