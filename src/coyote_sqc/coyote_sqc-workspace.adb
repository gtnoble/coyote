--  Coyote_SQC.Workspace body.
--
--  Project: coyote

with Ada.Calendar;
with Ada.Numerics.Discrete_Random;
with Ada.Strings.Unbounded;             use Ada.Strings.Unbounded;
with Ada.Text_IO;
with Ada.Directories;
with Coyote_Utils;
with GNATCOLL.JSON;

package body Coyote_SQC.Workspace is
   use type GNATCOLL.JSON.JSON_Value_Type;

   use Coyote_SQC.Data_Model;
   use Coyote_SQC.Charts;

   --  ── UUID generation (same approach as LLM.Session_Store) ─────────────

   type Byte is mod 256;

   function Byte_Image (B : Byte) return String is
      Hex  : constant String := "0123456789abcdef";
      High : constant Character := Hex (Natural (B / 16) + 1);
      Low  : constant Character := Hex (Natural (B mod 16) + 1);
   begin
      return (1 => High, 2 => Low);
   end Byte_Image;

   package Byte_Random is new Ada.Numerics.Discrete_Random (Byte);

   function New_UUID return String is
      Generator : Byte_Random.Generator;
      Bytes     : array (Positive range 1 .. 16) of Byte;
   begin
      Byte_Random.Reset (Generator);
      for I in Bytes'Range loop
         Bytes (I) := Byte_Random.Random (Generator);
      end loop;
      --  RFC 4122 UUIDv4 version / variant bits.
      Bytes (7) := (Bytes (7) and 16#0F#) or 16#40#;
      Bytes (9) := (Bytes (9) and 16#3F#) or 16#80#;
      return Byte_Image (Bytes (1)) & Byte_Image (Bytes (2))
        & Byte_Image (Bytes (3)) & Byte_Image (Bytes (4))
        & "-"
        & Byte_Image (Bytes (5)) & Byte_Image (Bytes (6))
        & "-"
        & Byte_Image (Bytes (7)) & Byte_Image (Bytes (8))
        & "-"
        & Byte_Image (Bytes (9)) & Byte_Image (Bytes (10))
        & "-"
        & Byte_Image (Bytes (11)) & Byte_Image (Bytes (12))
        & Byte_Image (Bytes (13)) & Byte_Image (Bytes (14))
        & Byte_Image (Bytes (15)) & Byte_Image (Bytes (16));
   end New_UUID;

   --  ── Chart_Settings helper ─────────────────────────────────────────────

   function Chart_Settings
     (W    : Coyote_SQC.Data_Model.Workspace_Record;
      Kind : Coyote_SQC.Charts.Chart_Kind)
      return Coyote_SQC.Data_Model.Chart_Settings_Record
   is
   begin
      if W.Chart_Settings.Contains (Kind) then
         return W.Chart_Settings (Kind);
      else
         return (others => <>);
      end if;
   end Chart_Settings;

   --  ── JSON helpers ──────────────────────────────────────────────────────

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

   function Get_Int_Field
     (Value   : GNATCOLL.JSON.JSON_Value;
      Field   : String;
      Default : Long_Integer := 0) return Long_Integer
   is
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind = GNATCOLL.JSON.JSON_Int_Type
      then
         return Value.Get (Field).Get;
      end if;
      return Default;
   end Get_Int_Field;

   function Get_Float_Field
     (Value   : GNATCOLL.JSON.JSON_Value;
      Field   : String;
      Default : Long_Float := 0.0) return Long_Float
   is
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Value.Has_Field (Field)
      then
         declare
            F : constant GNATCOLL.JSON.JSON_Value := Value.Get (Field);
         begin
            if F.Kind = GNATCOLL.JSON.JSON_Float_Type then
               return GNATCOLL.JSON.Get_Long_Float (Value, Field);
            elsif F.Kind = GNATCOLL.JSON.JSON_Int_Type then
               return Long_Float (Long_Integer'(F.Get));
            end if;
         end;
      end if;
      return Default;
   end Get_Float_Field;

   function Get_Bool_Field
     (Value   : GNATCOLL.JSON.JSON_Value;
      Field   : String;
      Default : Boolean := False) return Boolean
   is
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind = GNATCOLL.JSON.JSON_Boolean_Type
      then
         return Boolean'(Value.Get (Field).Get);
      end if;
      return Default;
   end Get_Bool_Field;

   --  Convert Unix milliseconds to Ada.Calendar.Time.
   function Ms_To_Time (Ms : Long_Integer) return Ada.Calendar.Time is
      use Ada.Calendar;
      Epoch : constant Time :=
        Time_Of (Year => 1970, Month => 1, Day => 1, Seconds => 0.0);
   begin
      return Epoch + Duration (Long_Float (Ms) / 1000.0);
   end Ms_To_Time;

   --  Convert Ada.Calendar.Time to Unix milliseconds.
   function Time_To_Ms (T : Ada.Calendar.Time) return Long_Integer is
      use Ada.Calendar;
      Epoch : constant Time :=
        Time_Of (Year => 1970, Month => 1, Day => 1, Seconds => 0.0);
   begin
      return Long_Integer ((T - Epoch) * 1000.0);
   end Time_To_Ms;

   --  ── Variance-stabilization transform JSON helpers ──────────────────────

   --  Parse the new "transform" JSON object format.
   --  {"kind": "box_cox", "lambdaSource": "auto", "fixedLambda": 0.5}
   --  {"kind": "sqrt_vs"}  {"kind": "anscombe"}  {"kind": "arcsinh_vs"}
   --  {"kind": "freeman_tukey"}
   function Parse_Transform (T : GNATCOLL.JSON.JSON_Value)
     return Transform_Config
   is
      Cfg  : Transform_Config;
      Kind : constant String := Get_String_Field (T, "kind");
      Src  : constant String := Get_String_Field (T, "lambdaSource");
   begin
      if T.Kind /= GNATCOLL.JSON.JSON_Object_Type then
         return Cfg;
      end if;
      Cfg.Kind :=
        (if Kind = "box_cox"        then Box_Cox
         elsif Kind = "sqrt_vs"     then Sqrt_VS
         elsif Kind = "anscombe"    then Anscombe
         elsif Kind = "arcsinh_vs"  then Arcsinh_VS
         elsif Kind = "freeman_tukey" then Freeman_Tukey
         else None);
      Cfg.Lambda_Source :=
        (if Src = "fixed"         then Fixed
         elsif Src = "robust_auto" then Robust_Auto
         else Auto);
      Cfg.Fixed_Lambda := Get_Float_Field (T, "fixedLambda", 0.0);
      return Cfg;
   end Parse_Transform;

   --  Parse the legacy "boxCox" JSON object format (v7 and earlier).
   --  Returns a Transform_Config with Kind = Box_Cox if enabled, else None.
   function Parse_Box_Cox_Legacy (BC : GNATCOLL.JSON.JSON_Value)
     return Transform_Config
   is
      Cfg : Transform_Config;
      Src : constant String := Get_String_Field (BC, "lambdaSource");
   begin
      if BC.Kind /= GNATCOLL.JSON.JSON_Object_Type then
         return Cfg;
      end if;
      Cfg.Kind :=
        (if Get_Bool_Field (BC, "enabled", False) then Box_Cox else None);
      Cfg.Lambda_Source :=
        (if Src = "fixed"         then Fixed
         elsif Src = "robust_auto" then Robust_Auto
         else Auto);
      Cfg.Fixed_Lambda := Get_Float_Field (BC, "fixedLambda", 0.0);
      return Cfg;
   end Parse_Box_Cox_Legacy;

   function Transform_To_JSON (Cfg : Transform_Config)
     return GNATCOLL.JSON.JSON_Value
   is
      Obj : GNATCOLL.JSON.JSON_Value := GNATCOLL.JSON.Create_Object;
   begin
      Obj.Set_Field ("kind",
        (case Cfg.Kind is
           when None          => "none",
           when Box_Cox       => "box_cox",
           when Sqrt_VS       => "sqrt_vs",
           when Anscombe      => "anscombe",
           when Arcsinh_VS    => "arcsinh_vs",
           when Freeman_Tukey => "freeman_tukey"));
      if Cfg.Kind = Box_Cox then
         Obj.Set_Field ("lambdaSource",
           (if Cfg.Lambda_Source = Fixed        then "fixed"
            elsif Cfg.Lambda_Source = Robust_Auto then "robust_auto"
            else "auto"));
         Obj.Set_Field ("fixedLambda",
           GNATCOLL.JSON.Create (Cfg.Fixed_Lambda));
      end if;
      return Obj;
   end Transform_To_JSON;

   --  ── Chart_Settings_Record JSON helpers ────────────────────────────────

   function Parse_Chart_Settings (Obj : GNATCOLL.JSON.JSON_Value)
     return Chart_Settings_Record
   is
      Rec : Chart_Settings_Record;
      Est : constant String := Get_String_Field (Obj, "estimationMethod");
   begin
      if Obj.Kind /= GNATCOLL.JSON.JSON_Object_Type then
         return Rec;
      end if;

      --  Transform (new "transform" key; legacy "boxCox" fallback for v7).
      if Obj.Has_Field ("transform") then
         Rec.Transform := Parse_Transform (Obj.Get ("transform"));
      elsif Obj.Has_Field ("boxCox") then
         Rec.Transform := Parse_Box_Cox_Legacy (Obj.Get ("boxCox"));
      end if;
      --  Estimation method.
      if Est = "robust_median" then
         Rec.Estimation_Method := Robust_Median;
      else
         Rec.Estimation_Method := Classical;
      end if;

      --  EWMA parameters.
      Rec.EWMA_Weight := Get_Float_Field (Obj, "ewmaWeight", 0.2);
      Rec.EWMA_L      := Get_Float_Field (Obj, "ewmaL",      3.0);

      --  Plot method (optional; default = classical).
      declare
         PM : constant String := Get_String_Field (Obj, "plotMethod");
      begin
         if PM = "robust_median" then
            Rec.Plot_Method := Robust_Median;
         end if;
      end;

      return Rec;
   end Parse_Chart_Settings;

   --  Return True if the settings record is entirely at default values.
   function Is_Default (Rec : Chart_Settings_Record) return Boolean is
   begin
      return Rec.Transform.Kind = None
        and then Rec.Estimation_Method = Classical
        and then Rec.Plot_Method = Classical
        and then Rec.EWMA_Weight = 0.2
        and then Rec.EWMA_L = 3.0;
   end Is_Default;

   function Chart_Settings_To_JSON (Rec : Chart_Settings_Record)
     return GNATCOLL.JSON.JSON_Value
   is
      Obj : GNATCOLL.JSON.JSON_Value := GNATCOLL.JSON.Create_Object;
   begin
      --  Write transform config if not default (None).
      if Rec.Transform.Kind /= None then
         Obj.Set_Field ("transform", Transform_To_JSON (Rec.Transform));
      end if;
      --  Estimation method — omit when classical (default).
      if Rec.Estimation_Method = Robust_Median then
         Obj.Set_Field ("estimationMethod", "robust_median");
      end if;

      --  Plot method — omit when classical (default).
      if Rec.Plot_Method = Robust_Median then
         Obj.Set_Field ("plotMethod", "robust_median");
      end if;

      --  EWMA params — omit when default.
      if Rec.EWMA_Weight /= 0.2 then
         Obj.Set_Field ("ewmaWeight",
           GNATCOLL.JSON.Create (Rec.EWMA_Weight));
      end if;
      if Rec.EWMA_L /= 3.0 then
         Obj.Set_Field ("ewmaL",
           GNATCOLL.JSON.Create (Rec.EWMA_L));
      end if;

      return Obj;
   end Chart_Settings_To_JSON;

   --  ── Migration helpers (v1–6 → v7) ─────────────────────────────────────

   --  All Session-Token I/MR/EWMA chart kinds (receive iChartBoxCox migration).
   --  Only applies Box-Cox (not EWMA_Weight/L, which come from ewmaWeight/ewmaL).
   procedure Apply_I_Chart_Box_Cox_Migration
     (W   : in out Workspace_Record;
      Cfg : Transform_Config)
   is
      I_Chart_Kinds : constant array (Positive range <>) of Chart_Kind :=
        (Session_Input_Tokens_I,
         Session_Input_Tokens_MR,
         Session_Input_Tokens_EWMA,
         Session_Output_Tokens_I,
         Session_Output_Tokens_MR,
         Session_Output_Tokens_EWMA,
         Session_Cache_Read_Tokens_I,
         Session_Cache_Read_Tokens_MR,
         Session_Cache_Read_Tokens_EWMA,
         Session_Cache_Write_Tokens_I,
         Session_Cache_Write_Tokens_MR,
         Session_Cache_Write_Tokens_EWMA,
         Session_Thinking_Tokens_I,
         Session_Thinking_Tokens_MR,
         Session_Thinking_Tokens_EWMA,
         Session_Tool_Call_Tokens_I,
         Session_Tool_Call_Tokens_MR,
         Session_Tool_Call_Tokens_EWMA,
         Session_Tool_Call_Result_Tokens_I,
         Session_Tool_Call_Result_Tokens_MR,
         Session_Tool_Call_Result_Tokens_EWMA,
         Session_Uncached_Input_Tokens_I,
         Session_Uncached_Input_Tokens_MR,
         Session_Uncached_Input_Tokens_EWMA);
   begin
      for K of I_Chart_Kinds loop
         declare
            Rec : Chart_Settings_Record := Chart_Settings (W, K);
         begin
            Rec.Transform := Cfg;
            if not Is_Default (Rec) then
               W.Chart_Settings.Include (K, Rec);
            end if;
         end;
      end loop;
   end Apply_I_Chart_Box_Cox_Migration;

   procedure Apply_Xbar_S_Box_Cox_Migration
     (W   : in out Workspace_Record;
      Cfg : Transform_Config)
   is
      Xbar_S_Kinds : constant array (Positive range <>) of Chart_Kind :=
        (Turn_Tokens_Xbar,
         Turn_Tokens_S,
         Tool_Call_Tokens_Xbar,
         Tool_Call_Tokens_S,
         Thinking_Tokens_Xbar,
         Thinking_Tokens_S);
   begin
      for K of Xbar_S_Kinds loop
         declare
            Rec : Chart_Settings_Record := Chart_Settings (W, K);
         begin
            Rec.Transform := Cfg;
            if not Is_Default (Rec) then
               W.Chart_Settings.Include (K, Rec);
            end if;
         end;
      end loop;
   end Apply_Xbar_S_Box_Cox_Migration;

   procedure Apply_Turn_Count_Box_Cox_Migration
     (W   : in out Workspace_Record;
      Cfg : Transform_Config)
   is
      TC_Kinds : constant array (Positive range <>) of Chart_Kind :=
        (Session_Turn_Count_I,
         Session_Turn_Count_MR,
         Session_Turn_Count_EWMA);
   begin
      for K of TC_Kinds loop
         declare
            Rec : Chart_Settings_Record := Chart_Settings (W, K);
         begin
            Rec.Transform := Cfg;
            if not Is_Default (Rec) then
               W.Chart_Settings.Include (K, Rec);
            end if;
         end;
      end loop;
   end Apply_Turn_Count_Box_Cox_Migration;

   procedure Apply_Estimation_Method_Migration
     (W      : in out Workspace_Record;
      Method : Estimation_Method_Kind)
   is
   begin
      if Method = Classical then
         return;  --  Classical is default; no entries needed.
      end if;
      for K in Chart_Kind loop
         declare
            Rec : Chart_Settings_Record := Chart_Settings (W, K);
         begin
            Rec.Estimation_Method := Method;
            if not Is_Default (Rec) then
               W.Chart_Settings.Include (K, Rec);
            end if;
         end;
      end loop;
   end Apply_Estimation_Method_Migration;

   procedure Apply_EWMA_Params_Migration
     (W      : in out Workspace_Record;
      Weight : Long_Float;
      L      : Long_Float)
   is
      EWMA_Kinds : constant array (Positive range <>) of Chart_Kind :=
        (Session_Input_Tokens_EWMA,
         Session_Output_Tokens_EWMA,
         Session_Cache_Read_Tokens_EWMA,
         Session_Cache_Write_Tokens_EWMA,
         Session_Thinking_Tokens_EWMA,
         Session_Tool_Call_Tokens_EWMA,
         Session_Tool_Call_Result_Tokens_EWMA,
         Session_Turn_Count_EWMA,
         Session_Uncached_Input_Tokens_EWMA,
         Fraction_Thinking_Tokens_EWMA,
         Fraction_Tool_Call_Tokens_EWMA,
         Fraction_Thinking_Per_Tool_Call_EWMA,
         Fraction_Uncached_Input_EWMA,
         Session_Tool_Call_JSD_Sum_EWMA);
   begin
      if Weight = 0.2 and then L = 3.0 then
         return;  --  Both are default; no entries needed.
      end if;
      for K of EWMA_Kinds loop
         declare
            Rec : Chart_Settings_Record := Chart_Settings (W, K);
         begin
            Rec.EWMA_Weight := Weight;
            Rec.EWMA_L      := L;
            if not Is_Default (Rec) then
               W.Chart_Settings.Include (K, Rec);
            end if;
         end;
      end loop;
   end Apply_EWMA_Params_Migration;

   --  ── Load ──────────────────────────────────────────────────────────────

   procedure Load
     (Path          :     String;
      Workspace     : out Workspace_Record;
      Version_Found : out Natural;
      Migrated      : out Boolean)
   is
      Content : Unbounded_String;
      Root    : GNATCOLL.JSON.JSON_Value;
      Version : Long_Integer;
   begin
      Migrated := False;

      Content := To_Unbounded_String (Coyote_Utils.Read_Whole_File (Path));

      Root := GNATCOLL.JSON.Read (To_String (Content));

      Version := Get_Int_Field (Root, "version", -1);
      if Version > 10 then
         raise Workspace_Error with
           "This workspace was created by a newer version of coyote_sqc "
           & "and cannot be opened.";
      end if;
      Version_Found := (if Version > 0 then Natural (Version) else 0);

      Workspace.Workspace_Id :=
        To_Unbounded_String (Get_String_Field (Root, "workspaceId"));
      Workspace.Name :=
        To_Unbounded_String (Get_String_Field (Root, "name"));
      Workspace.Log_Y_Mode :=
        Get_Bool_Field (Root, "logYMode", False);
      Workspace.Analyze_All_Directories :=
        Get_Bool_Field (Root, "analyzeAllDirectories", False);
      Workspace.Interpolate_Quantile_Limits :=
        Get_Bool_Field (Root, "interpolateQuantileLimits", False);
      Workspace.Quantile_Bonferroni :=
        Get_Bool_Field (Root, "quantileBonferroni", True);
      if Root.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Root.Has_Field ("sourceDirectories")
      then
         declare
            Arr : constant GNATCOLL.JSON.JSON_Array :=
              Root.Get ("sourceDirectories");
         begin
            for I in 1 .. GNATCOLL.JSON.Length (Arr) loop
               declare
                  V : constant GNATCOLL.JSON.JSON_Value :=
                    GNATCOLL.JSON.Get (Arr, I);
               begin
                  if V.Kind = GNATCOLL.JSON.JSON_String_Type then
                     Workspace.Source_Directories.Append
                       (Unbounded_String'(V.Get));
                  end if;
               end;
            end loop;
         end;
      end if;

      --  Model filter.
      if Root.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Root.Has_Field ("modelFilter")
      then
         declare
            Arr : constant GNATCOLL.JSON.JSON_Array :=
              Root.Get ("modelFilter");
         begin
            for I in 1 .. GNATCOLL.JSON.Length (Arr) loop
               declare
                  V : constant GNATCOLL.JSON.JSON_Value :=
                    GNATCOLL.JSON.Get (Arr, I);
               begin
                  if V.Kind = GNATCOLL.JSON.JSON_String_Type then
                     Workspace.Model_Filter.Append
                       (Unbounded_String'(V.Get));
                  end if;
               end;
            end loop;
         end;
      end if;

      --  Setup session IDs.
      if Root.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Root.Has_Field ("setupSessionIds")
      then
         declare
            Arr : constant GNATCOLL.JSON.JSON_Array :=
              Root.Get ("setupSessionIds");
         begin
            for I in 1 .. GNATCOLL.JSON.Length (Arr) loop
               declare
                  V : constant GNATCOLL.JSON.JSON_Value :=
                    GNATCOLL.JSON.Get (Arr, I);
               begin
                  if V.Kind = GNATCOLL.JSON.JSON_String_Type then
                     Workspace.Setup_Session_Ids.Include
                       (Unbounded_String'(V.Get));
                  end if;
               end;
            end loop;
         end;
      end if;

      --  Comments.
      if Root.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Root.Has_Field ("comments")
      then
         declare
            Arr : constant GNATCOLL.JSON.JSON_Array :=
              Root.Get ("comments");
         begin
            for I in 1 .. GNATCOLL.JSON.Length (Arr) loop
               declare
                  C   : constant GNATCOLL.JSON.JSON_Value :=
                    GNATCOLL.JSON.Get (Arr, I);
                  Rec : Comment_Record;
               begin
                  Rec.Comment_Id :=
                    To_Unbounded_String (Get_String_Field (C, "commentId"));
                  Rec.Session_Id :=
                    To_Unbounded_String (Get_String_Field (C, "sessionId"));
                  Rec.Timestamp  :=
                    Ms_To_Time (Get_Int_Field (C, "timestamp"));
                  Rec.Text       :=
                    To_Unbounded_String (Get_String_Field (C, "text"));
                  Workspace.Comments.Append (Rec);
                  Workspace.Commented_Session_Ids.Include (Rec.Session_Id);
               end;
            end loop;
         end;
      end if;

      --  ── Version-7 chartSettings ─────────────────────────────────────────
      if Version >= 7
        and then Root.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Root.Has_Field ("chartSettings")
      then
         declare
            CS_Obj : constant GNATCOLL.JSON.JSON_Value :=
              Root.Get ("chartSettings");
         begin
            if CS_Obj.Kind = GNATCOLL.JSON.JSON_Object_Type then
               --  Iterate over each key in the chartSettings object.
               declare
                  procedure Parse_Chart_Entry
                    (Key   : String;
                     Value : GNATCOLL.JSON.JSON_Value)
                  is
                  begin
                     declare
                        K : constant Chart_Kind :=
                          Chart_Kind'Value (Key);
                        Rec : constant Chart_Settings_Record :=
                          Parse_Chart_Settings (Value);
                     begin
                        if not Is_Default (Rec) then
                           Workspace.Chart_Settings.Include (K, Rec);
                        end if;
                     end;
                  exception
                     when Constraint_Error => null;  --  Unknown key; skip.
                  end Parse_Chart_Entry;
               begin
                  CS_Obj.Map_JSON_Object (Parse_Chart_Entry'Access);
               end;
            end if;
         end;

      --  ── Migration from version ≤ 6 ──────────────────────────────────────
      elsif Version <= 6 then
         Migrated := True;

         --  iChartBoxCox (optional; default = disabled).
         if Root.Has_Field ("iChartBoxCox") then
            declare
               Cfg : constant Transform_Config :=
                 Parse_Box_Cox_Legacy (Root.Get ("iChartBoxCox"));
            begin
               Apply_I_Chart_Box_Cox_Migration (Workspace, Cfg);
            end;
         end if;

         --  xbarSBoxCox (optional; default = disabled).
         if Root.Has_Field ("xbarSBoxCox") then
            declare
               Cfg : constant Transform_Config :=
                 Parse_Box_Cox_Legacy (Root.Get ("xbarSBoxCox"));
            begin
               Apply_Xbar_S_Box_Cox_Migration (Workspace, Cfg);
            end;
         end if;

         --  turnCountBoxCox (optional; version 5; default = disabled).
         if Root.Has_Field ("turnCountBoxCox") then
            declare
               Cfg : constant Transform_Config :=
                 Parse_Box_Cox_Legacy (Root.Get ("turnCountBoxCox"));
            begin
               Apply_Turn_Count_Box_Cox_Migration (Workspace, Cfg);
            end;
         end if;

         --  estimationMethod (optional; version 6; default = classical).
         declare
            Est_Str : constant String :=
              Get_String_Field (Root, "estimationMethod");
            Method  : constant Estimation_Method_Kind :=
              (if Est_Str = "robust_median" then Robust_Median
               else Classical);
         begin
            Apply_Estimation_Method_Migration (Workspace, Method);
         end;

         --  ewmaWeight / ewmaL (optional; version 4; defaults 0.2 / 3.0).
         declare
            Weight : constant Long_Float :=
              Get_Float_Field (Root, "ewmaWeight", 0.2);
            L      : constant Long_Float :=
              Get_Float_Field (Root, "ewmaL", 3.0);
         begin
            Apply_EWMA_Params_Migration (Workspace, Weight, L);
         end;

      end if;
   end Load;

   --  ── Save ──────────────────────────────────────────────────────────────

   procedure Save
     (Path      : String;
      Workspace : Workspace_Record)
   is
      use GNATCOLL.JSON;

      Root      : JSON_Value := Create_Object;
      Src_Arr   : JSON_Array := Empty_Array;
      Flt_Arr   : JSON_Array := Empty_Array;
      Setup_Arr : JSON_Array := Empty_Array;
      Cmt_Arr   : JSON_Array := Empty_Array;
      CS_Obj    : JSON_Value := Create_Object;

      File : Ada.Text_IO.File_Type;
   begin
      Root.Set_Field ("version", Integer (10));
      Root.Set_Field ("workspaceId", To_String (Workspace.Workspace_Id));
      Root.Set_Field ("name", To_String (Workspace.Name));

      for Dir of Workspace.Source_Directories loop
         Append (Src_Arr, Create (To_String (Dir)));
      end loop;
      Root.Set_Field ("sourceDirectories", Src_Arr);

      for Model of Workspace.Model_Filter loop
         Append (Flt_Arr, Create (To_String (Model)));
      end loop;
      Root.Set_Field ("modelFilter", Flt_Arr);

      for Id of Workspace.Setup_Session_Ids loop
         Append (Setup_Arr, Create (To_String (Id)));
      end loop;
      Root.Set_Field ("setupSessionIds", Setup_Arr);

      --  chartSettings — sparse: only non-default entries are written.
      for K in Chart_Kind loop
         declare
            Rec : constant Chart_Settings_Record :=
              Chart_Settings (Workspace, K);
         begin
            if not Is_Default (Rec) then
               CS_Obj.Set_Field
                 (Chart_Kind'Image (K),
                  Chart_Settings_To_JSON (Rec));
            end if;
         end;
      end loop;
      Root.Set_Field ("chartSettings", CS_Obj);
      Root.Set_Field ("logYMode", Workspace.Log_Y_Mode);
      Root.Set_Field ("analyzeAllDirectories",
                      Workspace.Analyze_All_Directories);
      Root.Set_Field ("interpolateQuantileLimits",
                      Workspace.Interpolate_Quantile_Limits);
      Root.Set_Field ("quantileBonferroni",
                      Workspace.Quantile_Bonferroni);
      declare
         Sorted_Cmts : Comment_Vectors.Vector := Workspace.Comments;
         function Cmt_Lt (A, B : Comment_Record) return Boolean is
           (Ada.Calendar."<" (A.Timestamp, B.Timestamp));
         package Cmt_Sort is new Comment_Vectors.Generic_Sorting
           ("<" => Cmt_Lt);
      begin
         Cmt_Sort.Sort (Sorted_Cmts);
         for Cmt of Sorted_Cmts loop
            declare
               C : JSON_Value := Create_Object;
            begin
               C.Set_Field ("commentId", To_String (Cmt.Comment_Id));
               C.Set_Field ("sessionId", To_String (Cmt.Session_Id));
               C.Set_Field ("timestamp",
                 Long_Integer (Time_To_Ms (Cmt.Timestamp)));
               C.Set_Field ("text", To_String (Cmt.Text));
               Append (Cmt_Arr, C);
            end;
         end loop;
      end;
      Root.Set_Field ("comments", Cmt_Arr);

      declare
         Tmp : constant String := Path & ".tmp";
      begin
         Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Tmp);
         Ada.Text_IO.Put_Line (File, Write (Root));
         Ada.Text_IO.Close (File);
         if Ada.Directories.Exists (Path) then
            Ada.Directories.Delete_File (Path);
         end if;
         Ada.Directories.Rename (Tmp, Path);
      end;
   end Save;

end Coyote_SQC.Workspace;
