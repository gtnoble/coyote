--  Coyote_SQC.Config body.
--
--  Project: coyote

with Ada.Calendar;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNAT.OS_Lib;
with Coyote_Utils;
with GNATCOLL.JSON;

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
      return Result;
   end Load_Pricing;

end Coyote_SQC.Config;
