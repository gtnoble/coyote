--  Coyote_SQC.Workspace body.
--
--  Project: coyote

with Ada.Calendar;
with Ada.Numerics.Discrete_Random;
with Ada.Strings.Unbounded;             use Ada.Strings.Unbounded;
with Ada.Text_IO;
with Ada.Directories;
with GNATCOLL.JSON;

package body Coyote_SQC.Workspace is
   use type GNATCOLL.JSON.JSON_Value_Type;

   use Coyote_SQC.Data_Model;

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

   --  ── Load ──────────────────────────────────────────────────────────────

   procedure Load
     (Path      :     String;
      Workspace     : out Workspace_Record;
      Version_Found : out Natural)
   is
      File    : Ada.Text_IO.File_Type;
      Content : Unbounded_String;
      Line    : String (1 .. 65536);
      Last    : Natural;
      Root    : GNATCOLL.JSON.JSON_Value;
      Version : Long_Integer;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         Ada.Text_IO.Get_Line (File, Line, Last);
         Append (Content, Line (1 .. Last) & ASCII.LF);
      end loop;
      Ada.Text_IO.Close (File);

      Root := GNATCOLL.JSON.Read (To_String (Content));

      Version := Get_Int_Field (Root, "version", -1);
      if Version > 6 then
         raise Workspace_Error with
           "This workspace was created by a newer version of coyote_sqc "
           & "and cannot be opened.";
      end if;
      Version_Found := (if Version > 0 then Natural (Version) else 0);

      Workspace.Workspace_Id :=
        To_Unbounded_String (Get_String_Field (Root, "workspaceId"));
      Workspace.Name :=
        To_Unbounded_String (Get_String_Field (Root, "name"));

      --  Source directories.
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
                     --  Include does nothing if already present (dedup).
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
               end;
            end loop;
         end;
      end if;
      --  iChartBoxCox (optional; absent = disabled).
      if Root.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Root.Has_Field ("iChartBoxCox")
      then
         declare
            BC  : constant GNATCOLL.JSON.JSON_Value :=
              Root.Get ("iChartBoxCox");
            Src : constant String :=
              Get_String_Field (BC, "lambdaSource");
         begin
            if BC.Kind = GNATCOLL.JSON.JSON_Object_Type then
               if BC.Has_Field ("enabled")
                 and then BC.Get ("enabled").Kind =
                   GNATCOLL.JSON.JSON_Boolean_Type
               then
                  Workspace.I_Chart_Box_Cox.Enabled :=
                    Boolean'(BC.Get ("enabled").Get);
               end if;
               Workspace.I_Chart_Box_Cox.Lambda_Source :=
                 (if Src = "fixed"
                  then Coyote_SQC.Data_Model.Fixed
                  elsif Src = "robust_auto"
                  then Coyote_SQC.Data_Model.Robust_Auto
                  else Coyote_SQC.Data_Model.Auto);
               if BC.Has_Field ("fixedLambda")
                 and then BC.Get ("fixedLambda").Kind =
                   GNATCOLL.JSON.JSON_Float_Type
               then
                  Workspace.I_Chart_Box_Cox.Fixed_Lambda :=
                    GNATCOLL.JSON.Get_Long_Float (BC, "fixedLambda");
               end if;
            end if;
         end;
      end if;
      --  xbarSBoxCox (optional; absent = disabled).
      if Root.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Root.Has_Field ("xbarSBoxCox")
      then
         declare
            BC  : constant GNATCOLL.JSON.JSON_Value :=
              Root.Get ("xbarSBoxCox");
            Src : constant String :=
              Get_String_Field (BC, "lambdaSource");
         begin
            if BC.Kind = GNATCOLL.JSON.JSON_Object_Type then
               if BC.Has_Field ("enabled")
                 and then BC.Get ("enabled").Kind =
                   GNATCOLL.JSON.JSON_Boolean_Type
               then
                  Workspace.Xbar_S_Box_Cox.Enabled :=
                    Boolean'(BC.Get ("enabled").Get);
               end if;
               Workspace.Xbar_S_Box_Cox.Lambda_Source :=
                 (if Src = "fixed"
                  then Coyote_SQC.Data_Model.Fixed
                  elsif Src = "robust_auto"
                  then Coyote_SQC.Data_Model.Robust_Auto
                  else Coyote_SQC.Data_Model.Auto);
               if BC.Has_Field ("fixedLambda")
                 and then BC.Get ("fixedLambda").Kind =
                   GNATCOLL.JSON.JSON_Float_Type
               then
                  Workspace.Xbar_S_Box_Cox.Fixed_Lambda :=
                    GNATCOLL.JSON.Get_Long_Float (BC, "fixedLambda");
               end if;
            end if;
         end;
      end if;
      --  EWMA parameters (optional; absent = defaults 0.2 / 3.0).
      if Root.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Root.Has_Field ("ewmaWeight")
        and then Root.Get ("ewmaWeight").Kind =
          GNATCOLL.JSON.JSON_Float_Type
      then
         Workspace.EWMA_Weight :=
           GNATCOLL.JSON.Get_Long_Float (Root, "ewmaWeight");
      end if;
      if Root.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Root.Has_Field ("ewmaL")
        and then Root.Get ("ewmaL").Kind =
          GNATCOLL.JSON.JSON_Float_Type
      then
         Workspace.EWMA_L :=
           GNATCOLL.JSON.Get_Long_Float (Root, "ewmaL");
      end if;
      --  turnCountBoxCox (optional; absent = disabled; version 5).
      if Root.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Root.Has_Field ("turnCountBoxCox")
      then
         declare
            BC  : constant GNATCOLL.JSON.JSON_Value :=
              Root.Get ("turnCountBoxCox");
            Src : constant String :=
              Get_String_Field (BC, "lambdaSource");
         begin
            if BC.Kind = GNATCOLL.JSON.JSON_Object_Type then
               if BC.Has_Field ("enabled")
                 and then BC.Get ("enabled").Kind =
                   GNATCOLL.JSON.JSON_Boolean_Type
               then
                  Workspace.Turn_Count_Box_Cox.Enabled :=
                    Boolean'(BC.Get ("enabled").Get);
               end if;
               Workspace.Turn_Count_Box_Cox.Lambda_Source :=
                 (if Src = "fixed"
                  then Coyote_SQC.Data_Model.Fixed
                  elsif Src = "robust_auto"
                  then Coyote_SQC.Data_Model.Robust_Auto
                  else Coyote_SQC.Data_Model.Auto);
               if BC.Has_Field ("fixedLambda")
                 and then BC.Get ("fixedLambda").Kind =
                   GNATCOLL.JSON.JSON_Float_Type
               then
                  Workspace.Turn_Count_Box_Cox.Fixed_Lambda :=
                    GNATCOLL.JSON.Get_Long_Float (BC, "fixedLambda");
               end if;
            end if;
         end;
      end if;
      --  estimationMethod (optional; absent = Classical; version 6).
      declare
         Est_Str : constant String :=
           Get_String_Field (Root, "estimationMethod");
      begin
         if Est_Str = "robust_median" then
            Workspace.Estimation_Method :=
              Coyote_SQC.Data_Model.Robust_Median;
         else
            Workspace.Estimation_Method :=
              Coyote_SQC.Data_Model.Classical;
         end if;
      end;
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

      File : Ada.Text_IO.File_Type;
   begin
      Root.Set_Field ("version", Integer (6));
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

      --  Sort comments by ascending timestamp before serialising (§9.2).
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
            C.Set_Field ("timestamp", Long_Integer (Time_To_Ms (Cmt.Timestamp)));
            C.Set_Field ("text", To_String (Cmt.Text));
            Append (Cmt_Arr, C);
         end;
      end loop;
      end;
      Root.Set_Field ("comments", Cmt_Arr);
      --  iChartBoxCox.
      declare
         BC_Obj : GNATCOLL.JSON.JSON_Value := GNATCOLL.JSON.Create_Object;
      begin
         BC_Obj.Set_Field ("enabled",
           Workspace.I_Chart_Box_Cox.Enabled);
         BC_Obj.Set_Field ("lambdaSource",
           (if Workspace.I_Chart_Box_Cox.Lambda_Source =
                 Coyote_SQC.Data_Model.Fixed
            then "fixed"
            elsif Workspace.I_Chart_Box_Cox.Lambda_Source =
                  Coyote_SQC.Data_Model.Robust_Auto
            then "robust_auto"
            else "auto"));
         BC_Obj.Set_Field ("fixedLambda",
           GNATCOLL.JSON.Create
             (Workspace.I_Chart_Box_Cox.Fixed_Lambda));
         Root.Set_Field ("iChartBoxCox", BC_Obj);
      end;
      --  xbarSBoxCox.
      declare
         XS_Obj : GNATCOLL.JSON.JSON_Value := GNATCOLL.JSON.Create_Object;
      begin
         XS_Obj.Set_Field ("enabled",
           Workspace.Xbar_S_Box_Cox.Enabled);
         XS_Obj.Set_Field ("lambdaSource",
           (if Workspace.Xbar_S_Box_Cox.Lambda_Source =
                 Coyote_SQC.Data_Model.Fixed
            then "fixed"
            elsif Workspace.Xbar_S_Box_Cox.Lambda_Source =
                  Coyote_SQC.Data_Model.Robust_Auto
            then "robust_auto"
            else "auto"));
         XS_Obj.Set_Field ("fixedLambda",
           GNATCOLL.JSON.Create
             (Workspace.Xbar_S_Box_Cox.Fixed_Lambda));
         Root.Set_Field ("xbarSBoxCox", XS_Obj);
      --  EWMA parameters.
      Root.Set_Field ("ewmaWeight",
        GNATCOLL.JSON.Create (Workspace.EWMA_Weight));
      Root.Set_Field ("ewmaL",
        GNATCOLL.JSON.Create (Workspace.EWMA_L));
      end;
      --  turnCountBoxCox.
      declare
         TC_Obj : GNATCOLL.JSON.JSON_Value := GNATCOLL.JSON.Create_Object;
      begin
         TC_Obj.Set_Field ("enabled",
           Workspace.Turn_Count_Box_Cox.Enabled);
         TC_Obj.Set_Field ("lambdaSource",
           (if Workspace.Turn_Count_Box_Cox.Lambda_Source =
                 Coyote_SQC.Data_Model.Fixed
            then "fixed"
            elsif Workspace.Turn_Count_Box_Cox.Lambda_Source =
                  Coyote_SQC.Data_Model.Robust_Auto
            then "robust_auto"
            else "auto"));
         TC_Obj.Set_Field ("fixedLambda",
           GNATCOLL.JSON.Create
             (Workspace.Turn_Count_Box_Cox.Fixed_Lambda));
         Root.Set_Field ("turnCountBoxCox", TC_Obj);
      --  estimationMethod.
      Root.Set_Field ("estimationMethod",
        (if Workspace.Estimation_Method =
              Coyote_SQC.Data_Model.Robust_Median
         then "robust_median"
         else "classical"));
      end;
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
