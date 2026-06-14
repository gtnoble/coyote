--  Coyote_SQC.Statistics.JSD body.
--
--  Project: coyote

with Ada.Characters.Handling;
with Ada.Containers.Hashed_Maps;
with Ada.Numerics.Long_Elementary_Functions;
with Ada.Strings.Unbounded;
with Ada.Strings.Unbounded.Hash;
with GNATCOLL.JSON;

package body Coyote_SQC.Statistics.JSD is

   use Ada.Characters.Handling;
   use Ada.Numerics.Long_Elementary_Functions;
   use Ada.Strings.Unbounded;

   --  Ln(2) constant for bit ↔ nat conversion.
   Ln2 : constant Long_Float := Log (2.0);

   --  Token frequency map: token string → occurrence count.
   package Token_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type        => Unbounded_String,
      Element_Type    => Natural,
      Hash            => Ada.Strings.Unbounded.Hash,
      Equivalent_Keys => "=");

   --  ── JSON string extraction ────────────────────────────────────────────

   --  Return a space-separated concatenation of all quoted string values
   --  found in JSON (simple scan; handles \" escape; extracts both keys and
   --  values).  Used by Build_Map / Token_Count for the whole-blob path.
   function Extract_JSON_Strings (JSON : String) return Unbounded_String is
      Result   : Unbounded_String;
      In_Str   : Boolean := False;
      Escape   : Boolean := False;
      Had_Text : Boolean := False;
   begin
      for I in JSON'Range loop
         declare
            C : constant Character := JSON (I);
         begin
            if Escape then
               if In_Str then
                  Append (Result, C);
               end if;
               Escape := False;
            elsif C = '\' then
               if In_Str then
                  Escape := True;
               end if;
            elsif C = '"' then
               if In_Str then
                  --  End of a quoted string — add separator.
                  if Had_Text then
                     Append (Result, ' ');
                  end if;
                  In_Str   := False;
                  Had_Text := True;
               else
                  In_Str := True;
               end if;
            elsif In_Str then
               Append (Result, C);
            end if;
         end;
      end loop;
      return Result;
   end Extract_JSON_Strings;

   --  ── Token map construction ────────────────────────────────────────────

   --  Add whitespace-delimited, lowercased tokens from Text to Map.
   procedure Add_Tokens
     (Text  :        String;
      Map   : in out Token_Maps.Map;
      Total : in out Natural)
   is
      Token : Unbounded_String;

      procedure Flush is
      begin
         if Length (Token) = 0 then
            return;
         end if;
         declare
            K    : constant Unbounded_String :=
              To_Unbounded_String (To_Lower (To_String (Token)));
            Curs : constant Token_Maps.Cursor := Map.Find (K);
         begin
            if Token_Maps.Has_Element (Curs) then
               Map.Replace_Element
                 (Curs, Token_Maps.Element (Curs) + 1);
            else
               Map.Insert (K, 1);
            end if;
            Total := Total + 1;
         end;
         Token := Null_Unbounded_String;
      end Flush;

   begin
      for C of Text loop
         if C = ' ' or else C = ASCII.HT
           or else C = ASCII.LF or else C = ASCII.CR
         then
            Flush;
         else
            Append (Token, C);
         end if;
      end loop;
      Flush;
   end Add_Tokens;

   --  Build a token frequency map from Tool_Name + whole Arguments blob.
   --  Used only by Token_Count.
   procedure Build_Map
     (Tool_Name : String;
      Arguments : String;
      Map       : out Token_Maps.Map;
      N         : out Natural)
   is
      JSON_Text : constant Unbounded_String :=
        Extract_JSON_Strings (Arguments);
      Full_Text : Unbounded_String;
   begin
      Map := Token_Maps.Empty_Map;
      N   := 0;
      Append (Full_Text, To_Lower (Tool_Name));
      if Length (JSON_Text) > 0 then
         Append (Full_Text, ' ');
         Append (Full_Text, JSON_Text);
      end if;
      Add_Tokens (To_String (Full_Text), Map, N);
   end Build_Map;

   --  Build a token frequency map from a plain text string.
   procedure Build_Map_From_Text
     (Text : String;
      Map  : out Token_Maps.Map;
      N    : out Natural)
   is
   begin
      Map := Token_Maps.Empty_Map;
      N   := 0;
      Add_Tokens (Text, Map, N);
   end Build_Map_From_Text;

   --  ── JSON value → token text ───────────────────────────────────────────

   --  Return a space-separated concatenation of all string-valued leaf
   --  content in V (recursively for nested objects and arrays).
   function Extract_From_Value
     (V : GNATCOLL.JSON.JSON_Value) return Unbounded_String
   is
      Result : Unbounded_String;

      --  Forward declaration to allow mutual recursion.
      procedure Append_Value (V2 : GNATCOLL.JSON.JSON_Value);

      procedure Visit_Field
        (Name  : GNATCOLL.JSON.UTF8_String;
         Value : GNATCOLL.JSON.JSON_Value)
      is
         pragma Unreferenced (Name);
      begin
         Append_Value (Value);
      end Visit_Field;

      procedure Append_Value (V2 : GNATCOLL.JSON.JSON_Value) is
         Arr : GNATCOLL.JSON.JSON_Array;
      begin
         case GNATCOLL.JSON.Kind (V2) is
            when GNATCOLL.JSON.JSON_String_Type =>
               if Length (Result) > 0 then
                  Append (Result, ' ');
               end if;
               declare
                  Val_Str : constant String := GNATCOLL.JSON.Get (V2);
               begin
                  Append (Result, Val_Str);
               end;
            when GNATCOLL.JSON.JSON_Object_Type =>
               GNATCOLL.JSON.Map_JSON_Object (V2, Visit_Field'Access);
            when GNATCOLL.JSON.JSON_Array_Type =>
               Arr := GNATCOLL.JSON.Get (V2);
               for I in 1 .. GNATCOLL.JSON.Length (Arr) loop
                  Append_Value (GNATCOLL.JSON.Get (Arr, I));
               end loop;
            when others =>
               null;
         end case;
      end Append_Value;

   begin
      Append_Value (V);
      return Result;
   end Extract_From_Value;

   --  ── JSD computation ──────────────────────────────────────────────────

   --  Compute JSD in bits (base-2) between two token maps.
   function Compute_D
     (Map1 : Token_Maps.Map; N1 : Positive;
      Map2 : Token_Maps.Map; N2 : Positive) return Long_Float
   is
      N   : constant Long_Float := Long_Float (N1 + N2);
      Sum : Long_Float := 0.0;

      function Token_Term (C1, C2 : Natural) return Long_Float is
         Mix : constant Natural := C1 + C2;
         T   : Long_Float := 0.0;
      begin
         T := Long_Float (Mix) * Log (N / Long_Float (Mix));
         if C1 > 0 then
            T := T - Long_Float (C1) * Log (Long_Float (N1) / Long_Float (C1));
         end if;
         if C2 > 0 then
            T := T - Long_Float (C2) * Log (Long_Float (N2) / Long_Float (C2));
         end if;
         return T;
      end Token_Term;

   begin
      for Pos in Map1.Iterate loop
         declare
            K  : constant Unbounded_String := Token_Maps.Key (Pos);
            C1 : constant Natural          := Token_Maps.Element (Pos);
            C2 : constant Natural          :=
              (if Map2.Contains (K) then Map2.Element (K) else 0);
         begin
            Sum := Sum + Token_Term (C1, C2);
         end;
      end loop;
      for Pos in Map2.Iterate loop
         declare
            K : constant Unbounded_String := Token_Maps.Key (Pos);
         begin
            if not Map1.Contains (K) then
               Sum := Sum + Token_Term (0, Token_Maps.Element (Pos));
            end if;
         end;
      end loop;
      declare
         D : constant Long_Float := Sum / (N * Ln2);
      begin
         return Long_Float'Max (0.0, Long_Float'Min (1.0, D));
      end;
   end Compute_D;

   --  Compute the bias-corrected JSD similarity S for two token maps.
   --  Returns 0.0 when one side has zero tokens (absent / empty argument).
   function Compute_One_S
     (Map1 : Token_Maps.Map; N1 : Natural;
      Map2 : Token_Maps.Map; N2 : Natural) return Long_Float
   is
   begin
      if N1 = 0 or else N2 = 0 then
         return 0.0;
      end if;
      declare
         N     : constant Long_Float := Long_Float (N1 + N2);
         D     : constant Long_Float :=
           Compute_D (Map1, N1, Map2, N2);
         K_Eff : Natural := Natural (Map1.Length);
         Bias  : Long_Float;
      begin
         for Pos in Map2.Iterate loop
            if not Map1.Contains (Token_Maps.Key (Pos)) then
               K_Eff := K_Eff + 1;
            end if;
         end loop;
         Bias := Long_Float (K_Eff - 1) / (2.0 * Ln2);
         return N * (1.0 - D) + Bias;
      end;
   end Compute_One_S;

   --  ── Public operations ─────────────────────────────────────────────────

   function Compute_S_Values
     (Tool_Name_1 : String;
      Arguments_1 : String;
      Tool_Name_2 : String;
      Arguments_2 : String) return Long_Float
   is
      use type GNATCOLL.JSON.JSON_Value_Type;
      Parse_1 : constant GNATCOLL.JSON.Read_Result :=
        GNATCOLL.JSON.Read (Arguments_1);
      Parse_2 : constant GNATCOLL.JSON.Read_Result :=
        GNATCOLL.JSON.Read (Arguments_2);

      JSON_1 : constant GNATCOLL.JSON.JSON_Value :=
        (if Parse_1.Success and then
            GNATCOLL.JSON.Kind (Parse_1.Value) = GNATCOLL.JSON.JSON_Object_Type
         then Parse_1.Value
         else GNATCOLL.JSON.JSON_Null);

      JSON_2 : constant GNATCOLL.JSON.JSON_Value :=
        (if Parse_2.Success and then
            GNATCOLL.JSON.Kind (Parse_2.Value) = GNATCOLL.JSON.JSON_Object_Type
         then Parse_2.Value
         else GNATCOLL.JSON.JSON_Null);

      Is_Obj_1 : constant Boolean :=
        GNATCOLL.JSON.Kind (JSON_1) = GNATCOLL.JSON.JSON_Object_Type;
      Is_Obj_2 : constant Boolean :=
        GNATCOLL.JSON.Kind (JSON_2) = GNATCOLL.JSON.JSON_Object_Type;
      Sum     : Long_Float := 0.0;

      --  Track keys already processed from JSON_1 to avoid double-counting.
      --  We reuse Token_Maps as a string set (element values are unused).
      Seen : Token_Maps.Map;

      --  Build maps from two text strings and append one S_k if N_k > 0.
      procedure Append_S_For_Texts (Text1, Text2 : String) is
         Map1, Map2 : Token_Maps.Map;
         N1, N2     : Natural;
      begin
         Build_Map_From_Text (Text1, Map1, N1);
         Build_Map_From_Text (Text2, Map2, N2);
         if N1 > 0 or else N2 > 0 then
            Sum := Sum + Compute_One_S (Map1, N1, Map2, N2);
         end if;
      end Append_S_For_Texts;

      --  Callback: process one key from JSON_1; record it in Seen.
      procedure Process_Key_1
        (Name : GNATCOLL.JSON.UTF8_String;
         Val1 : GNATCOLL.JSON.JSON_Value)
      is
         Text1 : constant String :=
           To_String (Extract_From_Value (Val1));
         Text2 : constant String :=
           (if Is_Obj_2 and then JSON_2.Has_Field (Name)
            then To_String (Extract_From_Value (JSON_2.Get (Name)))
            else "");
      begin
         Append_S_For_Texts (Text1, Text2);
         Seen.Include (To_Unbounded_String (Name), 0);
      end Process_Key_1;

      --  Callback: process one key from JSON_2 not already in JSON_1.
      procedure Process_Key_2
        (Name : GNATCOLL.JSON.UTF8_String;
         Val2 : GNATCOLL.JSON.JSON_Value)
      is
      begin
         if not Seen.Contains (To_Unbounded_String (Name)) then
            Append_S_For_Texts
              ("", To_String (Extract_From_Value (Val2)));
         end if;
      end Process_Key_2;

   begin
      --  Step 1: tool-name comparison (always first).
      Append_S_For_Texts
        (To_Lower (Tool_Name_1), To_Lower (Tool_Name_2));

      --  Step 2: per-argument comparisons.
      if Is_Obj_1 then
         GNATCOLL.JSON.Map_JSON_Object (JSON_1, Process_Key_1'Access);
      end if;
      if Is_Obj_2 then
         GNATCOLL.JSON.Map_JSON_Object (JSON_2, Process_Key_2'Access);
      end if;

      --  Step 3: fallback for non-object argument blobs.  If neither parsed
      --  as an object, compare the whole character-scanned content.
      if not Is_Obj_1 and then not Is_Obj_2 then
         declare
            Text1 : constant String :=
              To_String (Extract_JSON_Strings (Arguments_1));
            Text2 : constant String :=
              To_String (Extract_JSON_Strings (Arguments_2));
         begin
            Append_S_For_Texts (Text1, Text2);
         end;
      end if;
      return Sum;
   end Compute_S_Values;

   function Token_Count
     (Tool_Name : String;
      Arguments : String) return Natural
   is
      Map : Token_Maps.Map;
      N   : Natural;
   begin
      Build_Map (Tool_Name, Arguments, Map, N);
      return N;
   end Token_Count;

end Coyote_SQC.Statistics.JSD;
