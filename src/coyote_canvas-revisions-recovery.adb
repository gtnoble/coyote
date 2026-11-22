with Ada.Containers;
with Ada.Text_IO;
with Coyote_Canvas.Rasters;
with Coyote_Canvas.Store;
with GNATCOLL.JSON;

package body Coyote_Canvas.Revisions.Recovery is
   use GNATCOLL.JSON;
   use type Document.Rectangle;

   PAINT_VERSION : constant := 2;
   ERASE_VERSION : constant := 3;
   COLOR_VERSION : constant := 4;
   MAX_JSON_DEPTH : constant := 6;
   MAX_SEPARATORS : constant :=
     6 * MAX_POINTS + MAX_REVISIONS * MAX_STROKES + MAX_REVISIONS
     + MAX_STROKES;
   package Real_IO is new Ada.Text_IO.Float_IO (Long_Float);

   procedure Require (Valid : Boolean; Reason : String);
   function Is_Digest (Value : String) return Boolean;

   function Number (Value : Natural) return JSON_Value is
     (Create (Integer (Value)));

   function Number (Value : Long_Float) return JSON_Value is
      Text : String (1 .. 32);
   begin
      Real_IO.Put (Text, Value, Aft => 17, Exp => 4);
      return Create (Text);
   end Number;

   function State_Value (S : Drawing_State) return JSON_Value is
      Fields : JSON_Array;
      Ink    : JSON_Array;
   begin
      Append (Fields, Number (S.Extent.Left));
      Append (Fields, Number (S.Extent.Top));
      Append (Fields, Number (S.Extent.Right));
      Append (Fields, Number (S.Extent.Bottom));
      Append (Fields, Number (S.Image));
      for Id of S.Ink loop
         Append (Ink, Number (Id));
      end loop;
      Append (Fields, Create (Ink));
      return Create (Fields);
   end State_Value;

   function Encode
     (W : Workspace; Assets : Asset_References; With_Assets : Boolean)
      return String
   is
      Root : constant JSON_Value := Create_Object;
      Ink, Nodes, Refs : JSON_Array;
      Version : Natural := PAINT_VERSION;
   begin
      for Stroke of W.Strokes loop
         if Stroke.Operation = Paint
           and then Stroke.Color /= DEFAULT_INK_COLOR
         then
            Version := COLOR_VERSION;
         elsif Stroke.Operation = Erase and then Version /= COLOR_VERSION then
            Version := ERASE_VERSION;
         end if;
         declare
            Entries : JSON_Array;
         begin
            if Stroke.Operation = Erase then
               Append (Entries, Number (Natural'(0)));
            elsif Stroke.Color /= DEFAULT_INK_COLOR then
               Append
                 (Entries,
                  Number (Natural (Stroke.Color) + 1));
            end if;
            for Point of Stroke.Points loop
               declare
                  Triple : JSON_Array;
               begin
                  Append (Triple, Number (Point.X));
                  Append (Triple, Number (Point.Y));
                  Append (Triple, Number (Point.Width));
                  Append (Entries, Create (Triple));
               end;
            end loop;
            Append (Ink, Create (Entries));
         end;
      end loop;
      for Index in 1 .. Count (W) loop
         declare
            Node : constant Revision := W.Revisions (Index);
            Fields : JSON_Array;
         begin
            Append (Fields, Number (Node.Parent));
            Append (Fields, Create (Node.Key));
            Append (Fields, State_Value (Node.Content));
            if Original_Label (W, Index) /= "" then
               Append (Fields, Create (Original_Label (W, Index)));
            end if;
            Append (Nodes, Create (Fields));
            Append (Refs, Create (Assets (Index)));
         end;
      end loop;
      Set_Field (Root, "version", Integer (Version));
      Set_Field (Root, "strokes", Ink);
      Set_Field (Root, "revisions", Nodes);
      Set_Field (Root, "base", Integer (W.Base_Id));
      Set_Field (Root, "draft", State_Value (W.Draft));
      if With_Assets then
         Set_Field (Root, "assets", Refs);
      end if;
      return Write (Root);
   end Encode;

   function Encode (W : Workspace) return String is
      Empty_Assets : constant Asset_References := (others => NO_ASSET);
   begin
      return Encode (W, Empty_Assets, False);
   end Encode;

   function Encode
     (W : Workspace; Assets : Asset_References) return String is
   begin
      for Index in 1 .. Count (W) loop
         if Background (W, Index) = Index then
            Require
              (Assets (Index) /= NO_ASSET
               and then Is_Digest (Assets (Index)),
               "Invalid Canvas asset digest");
         else
            Require (Assets (Index) = NO_ASSET,
                     "Asset digest is set for a non-Original revision");
         end if;
      end loop;
      for Index in Count (W) + 1 .. MAX_REVISIONS loop
         Require (Assets (Index) = NO_ASSET,
                  "Asset digest is set beyond the revision list");
      end loop;
      return Encode (W, Assets, True);
   end Encode;

   procedure Require (Valid : Boolean; Reason : String) is
   begin
      if not Valid then
         raise Invalid_Snapshot with Reason;
      end if;
   end Require;

   function Is_Digest (Value : String) return Boolean is
   begin
      if Value'Length /= 64 then
         return False;
      end if;
      for Ch of Value loop
         if Ch not in '0' .. '9' and then Ch not in 'a' .. 'f' then
            return False;
         end if;
      end loop;
      return True;
   end Is_Digest;

   function Text (V : JSON_Value) return String is
   begin
      Require (V.Kind = JSON_String_Type, "Expected Canvas string");
      return Get (V);
   end Text;

   function Is_UUID (Value : String) return Boolean is
   begin
      if Value'Length /= 36 then
         return False;
      end if;
      for Index in Value'Range loop
         if Index - Value'First in 8 | 13 | 18 | 23 then
            if Value (Index) /= '-' then
               return False;
            end if;
         elsif Value (Index) not in '0' .. '9'
           and then Value (Index) not in 'a' .. 'f'
         then
            return False;
         end if;
      end loop;
      return Value (Value'First + 14) = '4'
        and then Value (Value'First + 19) in '8' | '9' | 'a' | 'b';
   end Is_UUID;

   procedure Check_Envelope
     (Data : String; With_Assets : Boolean)
   is
      Depth, Separators, Fields, Token_Length : Natural := 0;
      Root_Seen, Quoted : Boolean := False;
   begin
      Require (Data'Length in 1 .. Store.MAX_MANIFEST_BYTES,
               "Canvas snapshot size is invalid");
      for Ch of Data loop
         if Quoted then
            if Ch = '"' then
               Quoted := False;
            else
               Require (Ch in ' ' .. '~' and then Ch /= '\',
                        "Invalid Canvas string encoding");
               Token_Length := Token_Length + 1;
               Require (Token_Length <= 64, "Canvas string too long");
            end if;
         else
            Require (Depth > 0 or else Ch in ' ' | ASCII.HT | ASCII.LF |
                     ASCII.CR or else (Ch = '{' and then not Root_Seen),
                     "Expected one Canvas JSON object");
            case Ch is
               when '"' =>
                  Quoted := True;
                  Token_Length := 0;
               when '{' =>
                  Require (Depth = 0, "Unexpected Canvas JSON object");
                  Root_Seen := True;
                  Depth := 1;
               when '[' =>
                  Depth := Depth + 1;
                  Separators := Separators + 1;
                  Require (Depth <= MAX_JSON_DEPTH, "Canvas JSON too deep");
               when '}' | ']' =>
                  Depth := Depth - 1;
               when ':' =>
                  Fields := Fields + 1;
                  Require
                    (Depth = 1 and then
                       Fields <= (if With_Assets then 6 else 5),
                     "Unexpected Canvas field");
               when ',' => Separators := Separators + 1;
               when '0' .. '9' | ' ' | ASCII.HT | ASCII.LF | ASCII.CR => null;
               when others =>
                  raise Invalid_Snapshot with "Unexpected Canvas JSON token";
            end case;
            Require (Separators <= MAX_SEPARATORS,
                     "Canvas JSON too large");
         end if;
      end loop;
      Require
        (Depth = 0 and then not Quoted
         and then Fields = (if With_Assets then 6 else 5),
         "Incomplete or invalid Canvas JSON");
   end Check_Envelope;

   function Nat (V : JSON_Value; Max : Natural) return Natural is
      N : Long_Long_Integer;
   begin
      Require (V.Kind = JSON_Int_Type, "Expected Canvas integer");
      N := Get (V);
      Require (N in 0 .. Long_Long_Integer (Max),
               "Canvas integer out of range");
      return Natural (N);
   end Nat;

   function Real (V : JSON_Value) return Long_Float is
   begin
      Require (V.Kind = JSON_String_Type, "Expected Canvas sample string");
      declare
         Text : constant String := Get (V);
      begin
         Require (Text'Length = 32, "Invalid Canvas sample string length");
         return Long_Float'Value (Text);
      end;
   end Real;

   function Array_Of
     (V : JSON_Value; Max : Natural; Min : Natural := 0) return JSON_Array
   is
   begin
      Require (V.Kind = JSON_Array_Type, "Expected Canvas array");
      declare
         A : constant JSON_Array := Get (V);
      begin
         Require (Length (A) in Min .. Max, "Invalid Canvas array length");
         return A;
      end;
   end Array_Of;

   procedure Decode_Internal
     (Data : String; W : in out Workspace; Assets : out Asset_References;
      With_Assets : Boolean)
   is
      Candidate : Workspace;
      Candidate_Assets : Asset_References := (others => NO_ASSET);
      Roots : array (1 .. MAX_REVISIONS) of Revision_Id := (others => 0);
      Owners : array (1 .. MAX_STROKES) of Revision_Id := (others => 0);
      Max_X, Max_Y : array (1 .. MAX_STROKES) of Long_Float :=
        (others => 0.0);
      Seen_Keys : array (1 .. MAX_REVISIONS) of Stable_Id :=
        (others => (others => ' '));

      function Load_State (V : JSON_Value) return Drawing_State is
         A : constant JSON_Array := Array_Of (V, 6, 6);
         L : constant JSON_Array := Array_Of (Get (A, 6), MAX_STROKES);
         S : Drawing_State;
         Prior : Natural := 0;
      begin
         S.Extent :=
           (Nat (Get (A, 1), Rasters.MAX_SIDE),
            Nat (Get (A, 2), Rasters.MAX_SIDE),
            Nat (Get (A, 3), Rasters.MAX_SIDE),
            Nat (Get (A, 4), Rasters.MAX_SIDE));
         S.Image := Nat (Get (A, 5), Count (Candidate) + 1);
         for I in 1 .. Length (L) loop
            declare
               Id : constant Natural :=
                 Nat (Get (L, I), Natural (Candidate.Strokes.Length));
            begin
               Require (Id > Prior, "Canvas stroke order is invalid");
               S.Ink.Append (Id);
               Prior := Id;
            end;
         end loop;
         return S;
      end Load_State;

      procedure Check_State (S : Drawing_State; Root : Revision_Id) is
      begin
         Require (S.Image = Background (Candidate, Root)
                  and then Document.Is_Within
                    (S.Extent, Extent (Candidate, Root)),
                  "Canvas state does not match its Original");
         for Id of S.Ink loop
            Require ((Owners (Id) = 0 or else Owners (Id) = Root)
                     and then Max_X (Id) <=
                       Long_Float (Extent (Candidate, Root).Right)
                     and then Max_Y (Id) <=
                       Long_Float (Extent (Candidate, Root).Bottom),
                     "Canvas stroke does not match its Original");
            Owners (Id) := Root;
         end loop;
      end Check_State;

      procedure Validate_Assets (V : JSON_Value) is
         Refs : constant JSON_Array := Array_Of (V, MAX_REVISIONS);
      begin
         Require (Length (Refs) = Count (Candidate),
                  "Canvas asset lookup count is invalid");
         for I in 1 .. Length (Refs) loop
            declare
               Value : constant String := Text (Get (Refs, I));
            begin
               if Background (Candidate, I) = I then
                  Require (Is_Digest (Value),
                           "Invalid Canvas asset digest");
                  Candidate_Assets (I) := Value;
               else
                  Require (Value = NO_ASSET,
                           "Asset digest is set for a non-Original revision");
               end if;
            end;
         end loop;
      end Validate_Assets;

   begin
      Check_Envelope (Data, With_Assets);
      declare
         Parsed : constant Read_Result := Read (Data);
      begin
         Require (Parsed.Success, "Malformed Canvas JSON");
         declare
            Obj : constant JSON_Value := Parsed.Value;
         begin
            Require (Obj.Kind = JSON_Object_Type, "Expected Canvas manifest");
            declare
               Version : constant Natural :=
                 Nat (Get (Obj, "version"), COLOR_VERSION);
               Ink : constant JSON_Array :=
                 Array_Of (Get (Obj, "strokes"), MAX_STROKES);
               Nodes : constant JSON_Array :=
                 Array_Of (Get (Obj, "revisions"), MAX_REVISIONS);
            begin
               Require
                 (Version in PAINT_VERSION | ERASE_VERSION | COLOR_VERSION,
                  "Unsupported Canvas snapshot version");
               for I in 1 .. Length (Ink) loop
                  declare
                     Entries : constant JSON_Array := Array_Of
                       (Get (Ink, I), MAX_POINTS - Candidate.Points + 1, 1);
                     Marker : constant Boolean :=
                       Get (Entries, 1).Kind = JSON_Int_Type;
                     Marker_Value : Natural := 0;
                     Start : Positive := 1;
                     N : Natural;
                     Op : Stroke;
                  begin
                     if Marker then
                        Marker_Value := Nat
                          (Get (Entries, 1),
                           (if Version = COLOR_VERSION
                            then Natural (Ink_Color'Last) + 1 else 0));
                        Require
                          (Version = COLOR_VERSION
                           or else
                             (Version = ERASE_VERSION
                              and then Marker_Value = 0),
                           "Invalid Canvas ink operation");
                        Start := 2;
                        if Marker_Value = 0 then
                           Op.Operation := Erase;
                           Op.Color := DEFAULT_INK_COLOR;
                        else
                           Op.Color := Ink_Color (Marker_Value - 1);
                        end if;
                     end if;
                     N := Length (Entries) - Start + 1;
                     Require (N in 1 .. MAX_POINTS - Candidate.Points,
                              "Invalid Canvas sample count");
                     Op.Points.Reserve_Capacity (Ada.Containers.Count_Type (N));
                     for J in Start .. Length (Entries) loop
                        declare
                           Triple : constant JSON_Array :=
                             Array_Of (Get (Entries, J), 3, 3);
                           Point : constant Sample :=
                             (Real (Get (Triple, 1)), Real (Get (Triple, 2)),
                              Real (Get (Triple, 3)));
                        begin
                           Require
                             (Point.X in 0.0 .. Long_Float (Rasters.MAX_SIDE)
                              and then Point.Y in
                                0.0 .. Long_Float (Rasters.MAX_SIDE)
                              and then Point.Width > 0.0
                              and then Point.Width <= 64.0,
                              "Canvas ink point is out of bounds");
                           Max_X (I) := Long_Float'Max (Max_X (I), Point.X);
                           Max_Y (I) := Long_Float'Max (Max_Y (I), Point.Y);
                           Op.Points.Append (Point);
                        end;
                     end loop;
                     Candidate.Points := Candidate.Points + N;
                     Candidate.Strokes.Append (Op);
                  end;
               end loop;
               for I in 1 .. Length (Nodes) loop
                  declare
                     Fields : constant JSON_Array :=
                       Array_Of (Get (Nodes, I), 4, 3);
                     P : constant Revision_Id :=
                       Nat (Get (Fields, 1), I - 1);
                     Key_Text : constant String := Text (Get (Fields, 2));
                     Key : Stable_Id := (others => ' ');
                     S : constant Drawing_State :=
                       Load_State (Get (Fields, 3));
                  begin
                     Require (Is_UUID (Key_Text),
                              "Invalid Canvas revision UUID");
                     Key := Key_Text;
                     for J in 1 .. I - 1 loop
                        Require (Seen_Keys (J) /= Key,
                                 "Duplicate Canvas revision UUID");
                     end loop;
                     Seen_Keys (I) := Key;
                     if P = NO_REVISION then
                        Require (S.Extent.Left = 0 and then S.Extent.Top = 0
                                 and then Document.Is_Nonempty (S.Extent)
                                 and then S.Extent.Bottom <=
                                   Rasters.MAX_PIXELS / S.Extent.Right
                                 and then (S.Image = 0 or else S.Image = I)
                                 and then S.Ink.Is_Empty,
                                 "Invalid Canvas Original");
                        Roots (I) := I;
                     else
                        Roots (I) := Roots (P);
                        Check_State (S, Roots (I));
                     end if;
                     Candidate.Revisions.Append
                       (Revision'(P, Key, S, others => <>));
                     if Length (Fields) = 4 then
                        Set_Original_Label (Candidate, I, Text (Get (Fields, 4)));
                     end if;
                  end;
               end loop;
            end;
            Candidate.Base_Id := Nat (Get (Obj, "base"), Count (Candidate));
            Candidate.Draft := Load_State (Get (Obj, "draft"));
            if Candidate.Base_Id = NO_REVISION then
               Require (Candidate.Draft.Extent = Document.EMPTY_RECTANGLE
                        and then Candidate.Draft.Image = 0
                        and then Candidate.Draft.Ink.Is_Empty,
                        "Canvas draft has no base");
            else
               Check_State (Candidate.Draft, Roots (Candidate.Base_Id));
            end if;
            if With_Assets then
               Validate_Assets (Get (Obj, "assets"));
            end if;
         end;
      end;
      Move (W, Candidate);
      Assets := Candidate_Assets;
   exception
      when Constraint_Error | Ada.Text_IO.Layout_Error =>
         raise Invalid_Snapshot with "Malformed Canvas snapshot field";
   end Decode_Internal;

   procedure Move (Target, Source : in out Workspace) is
   begin
      Revision_Lists.Move (Target.Revisions, Source.Revisions);
      Stroke_Lists.Move (Target.Strokes, Source.Strokes);
      Stroke_Ids.Move (Target.Draft.Ink, Source.Draft.Ink);
      Target.Draft.Extent := Source.Draft.Extent;
      Target.Draft.Image := Source.Draft.Image;
      Target.Base_Id := Source.Base_Id;
      Target.Points := Source.Points;
      Target.Past.Clear;
      Target.Future.Clear;
      Source.Draft := (others => <>);
      Source.Base_Id := NO_REVISION;
      Source.Points := 0;
      Source.Past.Clear;
      Source.Future.Clear;
   end Move;

   procedure Select_Revisions
     (Source : Workspace; Requested : References; Target : in out Workspace;
      Source_Ids : out Revision_Mapping)
   is
      type Revision_Flags is array (Positive range 1 .. MAX_REVISIONS)
        of Boolean;
      type Ink_Flags is array (Positive range 1 .. MAX_STROKES) of Boolean;
      type Ink_Mapping is array (Positive range 1 .. MAX_STROKES) of Natural;
      Keep : Revision_Flags := (others => False);
      Keep_Ink : Ink_Flags := (others => False);
      New_Id : Revision_Mapping := (others => NO_REVISION);
      New_Ink : Ink_Mapping := (others => 0);
      Candidate : Workspace;
   begin
      Source_Ids := (others => NO_REVISION);
      for Ref of Requested loop
         declare
            Id : Revision_Id := NO_REVISION;
         begin
            Find_Revision : for I in 1 .. Count (Source) loop
               if Revision_Key (Source, I) = Ref.Revision then
                  Id := I;
                  exit Find_Revision;
               end if;
            end loop Find_Revision;
            Require (Id /= NO_REVISION and then
                       Drawing_Key (Source, Id) = Ref.Drawing,
                     "Canvas fork references an unknown revision or drawing");
            Ancestors : while Id /= NO_REVISION and then not Keep (Id) loop
               Keep (Id) := True;
               for Stroke of Source.Revisions (Id).Content.Ink loop
                  Keep_Ink (Stroke) := True;
               end loop;
               Id := Parent (Source, Id);
            end loop Ancestors;
         end;
      end loop;
      --  Preserve ascending stroke IDs independent of traversal order.
      for Id in 1 .. Natural (Source.Strokes.Length) loop
         if Keep_Ink (Id) then
            Candidate.Strokes.Append (Source.Strokes (Id));
            Candidate.Points := Candidate.Points +
              Natural (Source.Strokes (Id).Points.Length);
            New_Ink (Id) := Candidate.Strokes.Last_Index;
         end if;
      end loop;
      for Id in 1 .. Count (Source) loop
         if Keep (Id) then
            declare
               Node : Revision := Source.Revisions (Id);
               Next : constant Revision_Id := Count (Candidate) + 1;
            begin
               New_Id (Id) := Next;
               Source_Ids (Next) := Id;
               if Node.Parent /= NO_REVISION then
                  Node.Parent := New_Id (Node.Parent);
               end if;
               if Node.Content.Image /= NO_REVISION then
                  Node.Content.Image := New_Id (Node.Content.Image);
               end if;
               for Stroke of Node.Content.Ink loop
                  Stroke := New_Ink (Stroke);
               end loop;
               Candidate.Revisions.Append (Node);
            end;
         end if;
      end loop;
      Candidate.Base_Id := Count (Candidate);
      if Candidate.Base_Id /= NO_REVISION then
         Candidate.Draft := Candidate.Revisions (Candidate.Base_Id).Content;
      end if;
      Move (Target, Candidate);
   end Select_Revisions;

   procedure Adopt_Added_Originals (Target, Source : in out Workspace) is
   begin
      --  Source is a copy extended only with new roots. Keep live undo.
      Revision_Lists.Move (Target.Revisions, Source.Revisions);
   end Adopt_Added_Originals;

   procedure Copy (Target : in out Workspace; Source : Workspace) is
      Candidate : Workspace;
   begin
      Candidate.Revisions := Source.Revisions;
      Candidate.Strokes := Source.Strokes;
      Candidate.Draft := Source.Draft;
      Candidate.Points := Source.Points;
      Candidate.Base_Id := Source.Base_Id;
      Move (Target, Candidate);
   end Copy;

   procedure Decode (Data : String; W : in out Workspace) is
      Ignored : Asset_References;
   begin
      Decode_Internal (Data, W, Ignored, False);
   end Decode;

   procedure Decode
     (Data : String; W : in out Workspace; Assets : out Asset_References)
   is
   begin
      Decode_Internal (Data, W, Assets, True);
   end Decode;
end Coyote_Canvas.Revisions.Recovery;
