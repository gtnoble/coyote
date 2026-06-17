--  Coyote_SQC.Statistics.MI body.
--
--  Project: coyote

with Ada.Characters.Handling;
with Ada.Containers.Hashed_Sets;
with Ada.Strings.Unbounded;
with Ada.Strings.Unbounded.Hash;
with GNATCOLL.JSON;
with Coyote_SQC.Zlib;
with Interfaces.C;
with Ada.Unchecked_Deallocation;

package body Coyote_SQC.Statistics.MI is

   use Ada.Characters.Handling;
   use Ada.Strings.Unbounded;
   use Interfaces.C;
   use type GNATCOLL.JSON.JSON_Value_Type;

   --  Simple set of Unbounded_Strings for tracking processed keys.
   package Key_Sets is new Ada.Containers.Hashed_Sets
     (Element_Type        => Unbounded_String,
      Hash                => Ada.Strings.Unbounded.Hash,
      Equivalent_Elements => "=");

   --  Compress a String and return the compressed size in bytes.
   --  Uses zlib compress2 at level 9.
   --  Returns 0 on failure (empty input or compression error).
   function Compressed_Size (S : String) return Natural is
      use type Interfaces.C.size_t;
      type Char_Array_Access is access Interfaces.C.char_array;
      procedure Free is new Ada.Unchecked_Deallocation
        (Interfaces.C.char_array, Char_Array_Access);
      S_Len   : constant Natural := S'Length;
   begin
      if S_Len = 0 then
         return 0;
      end if;
      declare
         Src_Len : constant Coyote_SQC.Zlib.uLong :=
           Coyote_SQC.Zlib.uLong (S_Len);
         Bound   : constant Coyote_SQC.Zlib.uLong :=
           Coyote_SQC.Zlib.Compress_Bound (Src_Len);
         B_Int   : constant Interfaces.C.size_t :=
           Interfaces.C.size_t (Bound);
         Dest : Char_Array_Access :=
           new Interfaces.C.char_array (0 .. B_Int - 1);
         Dest_Len : aliased Coyote_SQC.Zlib.uLongf := Bound;
         Src  : Char_Array_Access :=
           new Interfaces.C.char_array (0 .. Interfaces.C.size_t (S_Len) - 1);
         Ret     : Interfaces.C.int;
      begin
         for I in S'Range loop
            Src.all (Interfaces.C.size_t (I - S'First)) :=
              Interfaces.C.char'Val (Character'Pos (S (I)));
         end loop;
         Ret := Coyote_SQC.Zlib.Compress2
           (Dest       => Dest.all,
            Dest_Len   => Dest_Len,
            Source     => Src.all,
            Source_Len => Src_Len,
            Level      => 9);
         Free (Dest);
         Free (Src);
         if Ret /= Coyote_SQC.Zlib.Z_OK then
            return 0;
         end if;
         return Natural (Dest_Len);
      end;
   end Compressed_Size;

   --  Extract all string-valued leaf content from a JSON value, returning a
   --  space-separated single string (same extraction logic as the JSD
   --  package).
   function Extract_From_Value
     (V : GNATCOLL.JSON.JSON_Value) return Unbounded_String
   is
      Result : Unbounded_String;

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

   --  Extract all quoted string values from a raw JSON string (simple
   --  character-scan fallback for non-object JSON).
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

   --  ── Public operations ─────────────────────────────────────────────────

   procedure Compute_MI_Values
     (Tool_Name_1 : String;
      Arguments_1 : String;
      Tool_Name_2 : String;
      Arguments_2 : String;
      Result      : in out Coyote_SQC.Data_Model.Long_Float_Vectors.Vector)
   is
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

      Seen_Keys : Key_Sets.Set;

      --  Compute one MI_k value and append to Result.
      procedure Append_MI_For_Strings (S1, S2 : String) is
         C1 : constant Natural := Compressed_Size (S1);
         C2 : constant Natural := Compressed_Size (S2);
      begin
         if S1'Length = 0 and then S2'Length = 0 then
            return;  --  both empty: skip
         end if;
         if S1'Length = 0 or else S2'Length = 0 then
            --  One side absent: MI_k ≈ 0.
            Result.Append (0.0);
            return;
         end if;
         declare
            Concat : constant String := S1 & S2;
            C_AB   : constant Natural := Compressed_Size (Concat);
            Raw    : constant Long_Float := Long_Float (C1 + C2 - C_AB);
         begin
            Result.Append (Long_Float'Max (0.0, Raw));
         end;
      end Append_MI_For_Strings;

      --  Process one key from JSON_1 and its counterpart from JSON_2.
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
         Append_MI_For_Strings (Text1, Text2);
         Seen_Keys.Include (To_Unbounded_String (Name));
      end Process_Key_1;

      --  Process a key only present in JSON_2.
      procedure Process_Key_2
        (Name : GNATCOLL.JSON.UTF8_String;
         Val2 : GNATCOLL.JSON.JSON_Value)
      is
      begin
         if not Seen_Keys.Contains (To_Unbounded_String (Name)) then
            Append_MI_For_Strings
              ("", To_String (Extract_From_Value (Val2)));
         end if;
      end Process_Key_2;

   begin
      --  Step 1: tool-name comparison (always first).
      Append_MI_For_Strings
        (To_Lower (Tool_Name_1), To_Lower (Tool_Name_2));

      --  Step 2: per-argument comparisons.
      if Is_Obj_1 then
         GNATCOLL.JSON.Map_JSON_Object (JSON_1, Process_Key_1'Access);
      end if;
      if Is_Obj_2 then
         GNATCOLL.JSON.Map_JSON_Object (JSON_2, Process_Key_2'Access);
      end if;

      --  Step 3: fallback for non-object argument blobs.
      if not Is_Obj_1 and then not Is_Obj_2 then
         declare
            Text1 : constant String :=
              To_String (Extract_JSON_Strings (Arguments_1));
            Text2 : constant String :=
              To_String (Extract_JSON_Strings (Arguments_2));
         begin
            Append_MI_For_Strings (Text1, Text2);
         end;
      end if;
   end Compute_MI_Values;

end Coyote_SQC.Statistics.MI;
