with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Containers;

package body Math_Macros is
   use type Ada.Containers.Count_Type;
   use type Math_Tokens.Token_Kind;
   Max_Scopes : constant := 256;

   function Find (Item : Context; Name : String) return Natural is
   begin
      for I in 1 .. Natural (Item.Definitions.Length) loop
         if To_String (Item.Definitions (Positive (I)).Name) = Name then
            return I;
         end if;
      end loop;
      return 0;
   end Find;

   procedure Reset (Item : in out Context) is
   begin
      Item.Definitions.Clear;
      Item.Scopes.Clear;
      Item.Status := No_Error;
   end Reset;

   procedure Begin_Group (Item : in out Context) is
   begin
      if Item.Scopes.Length >= Max_Scopes then
         Item.Status := Scope_Limit;
      else
         Item.Scopes.Append (Undo_Vectors.Empty_Vector);
      end if;
   end Begin_Group;

   procedure End_Group (Item : in out Context) is
      Changes : Undo_Vectors.Vector;
   begin
      if Item.Scopes.Is_Empty then
         Item.Status := Unbalanced_Group;
         return;
      end if;
      Changes := Item.Scopes.Last_Element;
      Item.Scopes.Delete_Last;
      for I in reverse 1 .. Natural (Changes.Length) loop
         declare
            U : constant Undo := Changes (Positive (I));
            Pos : constant Natural := Find (Item, To_String (U.Name));
         begin
            if Pos > 0 then
               Item.Definitions.Delete (Positive (Pos));
            end if;
            if U.Had_Value then
               Item.Definitions.Append (U.Previous);
            end if;
         end;
      end loop;
   end End_Group;

   procedure Restore_To_Depth (Item : in out Context; Depth : Natural) is
   begin
      if Depth > Natural (Item.Scopes.Length) then
         Item.Status := Unbalanced_Group;
         return;
      end if;
      while Natural (Item.Scopes.Length) > Depth loop
         End_Group (Item);
      end loop;
   end Restore_To_Depth;

   function Scope_Depth (Item : Context) return Natural is
     (Natural (Item.Scopes.Length));

   procedure End_All (Item : in out Context) is
   begin
      Restore_To_Depth (Item, 0);
   end End_All;

   procedure Define_Tokens
     (Item : in out Context; Name : String; Num_Params : Natural;
      Replacement : Token_Sequence; Is_Global : Boolean;
      Diagnostic : out Diagnostic_Kind) is
      Pos : constant Natural := Find (Item, Name);
      New_Def : Definition :=
        (Name => To_Unbounded_String (Name), Num_Params => Num_Params,
         Optional_Default => Token_Vectors.Empty_Vector,
         Has_Default => False,
         Tokens => Token_Vectors.Empty_Vector);
      procedure Save (Frame : Positive) is
         Changes : Undo_Vectors.Vector := Item.Scopes (Frame);
      begin
         for J in 1 .. Natural (Changes.Length) loop
            if To_String (Changes (Positive (J)).Name) = Name then
               return;
            end if;
         end loop;
         declare
            Undo_Item : constant Undo :=
              (Name => To_Unbounded_String (Name), Had_Value => Pos > 0,
               Previous => (if Pos > 0 then Item.Definitions (Positive (Pos))
                            else (Name => Null_Unbounded_String,
                              Num_Params => 0,
                              Optional_Default => Token_Vectors.Empty_Vector,
                              Has_Default => False,
                              Tokens => Token_Vectors.Empty_Vector)));
         begin
            Changes.Append (New_Item => Undo_Item);
         end;
         Item.Scopes.Replace_Element (Frame, Changes);
      end Save;
   begin
      Diagnostic := No_Error;
      if Name'Length < 2 or else Name (Name'First) /= '\' or else
        Num_Params > 9
      then
         Diagnostic := Definition_Limit;
         return;
      end if;
      if Pos = 0 and then Item.Definitions.Length >= Max_Definitions then
         Diagnostic := Definition_Limit;
         return;
      end if;
      for T of Replacement loop
         New_Def.Tokens.Append (New_Item => T);
      end loop;
      for I in 1 .. Natural (New_Def.Tokens.Length) loop
         if New_Def.Tokens (Positive (I)).Kind = Math_Tokens.Parameter then
            if I = Natural (New_Def.Tokens.Length) or else
              New_Def.Tokens (Positive (I + 1)).Kind /=
                Math_Tokens.Character_Token or else
              New_Def.Tokens (Positive (I + 1)).Code_Point not in 49 .. 57 or else
              New_Def.Tokens (Positive (I + 1)).Code_Point - 48 > Num_Params
            then
               Diagnostic := Definition_Limit;
               return;
            end if;
         end if;
      end loop;
      if not Is_Global and then not Item.Scopes.Is_Empty then
         Save (Positive (Item.Scopes.Length));
      elsif Is_Global then
         for F in 1 .. Natural (Item.Scopes.Length) loop
            declare
               Changes : Undo_Vectors.Vector := Item.Scopes (Positive (F));
            begin
               for J in reverse 1 .. Natural (Changes.Length) loop
                  if To_String (Changes (Positive (J)).Name) = Name then
                     Changes.Delete (Positive (J));
                  end if;
               end loop;
               Item.Scopes.Replace_Element (Positive (F), Changes);
            end;
         end loop;
      end if;
      if Pos > 0 then
         Item.Definitions.Replace_Element (Positive (Pos), New_Def);
      else
         Item.Definitions.Append (New_Def);
      end if;
   end Define_Tokens;

   procedure Set_Optional_Default
     (Item : in out Context; Name : String;
      Replacement : Token_Sequence; Diagnostic : out Diagnostic_Kind) is
      Pos : constant Natural := Find (Item, Name);
      Updated : Definition;
   begin
      Diagnostic := No_Error;
      if Pos = 0 then
         Diagnostic := Definition_Limit;
         return;
      end if;
      Updated := Item.Definitions (Positive (Pos));
      Updated.Optional_Default.Clear;
      for T of Replacement loop
         Updated.Optional_Default.Append (T);
      end loop;
      Updated.Has_Default := True;
      Item.Definitions.Replace_Element (Positive (Pos), Updated);
   end Set_Optional_Default;

   procedure Copy_Definition
     (Item : in out Context; Target, Source : String; Is_Global : Boolean;
      Diagnostic : out Diagnostic_Kind) is
   begin
      if not Is_Defined (Item, Source) then
         Diagnostic := Definition_Limit;
         return;
      end if;
      declare
         Def : constant Definition := Lookup (Item, Source);
         Seq : Token_Sequence (1 .. Token_Count (Def));
      begin
         for I in Seq'Range loop
            Seq (I) := Token_At (Def, I);
         end loop;
         Define_Tokens
           (Item, Target, Num_Params (Def), Seq, Is_Global, Diagnostic);
      end;
   end Copy_Definition;

   procedure Define
     (Item : in out Context; Name : String; Num_Params : Natural;
      Replacement : Math_Tokens.Stream; First : Positive; Last : Natural;
      Is_Global : Boolean; Diagnostic : out Diagnostic_Kind) is
   begin
      if Last < First or else Last > Math_Tokens.Count (Replacement) then
         Diagnostic := Definition_Limit;
         return;
      end if;
      declare
         Seq : Token_Sequence (1 .. Last - First + 1);
      begin
         for I in Seq'Range loop
            Seq (I) := Math_Tokens.Element (Replacement, First + I - 1);
         end loop;
         Define_Tokens (Item, Name, Num_Params, Seq, Is_Global, Diagnostic);
      end;
   end Define;

   function Is_Defined (Item : Context; Name : String) return Boolean is
     (Find (Item, Name) > 0);

   function Lookup (Item : Context; Name : String) return Definition is
   begin
      return Item.Definitions (Positive (Find (Item, Name)));
   end Lookup;

   function Name_Of (Item : Definition) return String is
     (To_String (Item.Name));
   function Num_Params (Item : Definition) return Natural is (Item.Num_Params);
   function Has_Optional_Default (Item : Definition) return Boolean is
     (Item.Has_Default);
   function Default_Token_Count (Item : Definition) return Natural is
     (Natural (Item.Optional_Default.Length));
   function Default_Token_At
     (Item : Definition; Index : Positive) return Math_Tokens.Token is
     (Item.Optional_Default (Index));
   function Token_Count (Item : Definition) return Natural is
     (Natural (Item.Tokens.Length));
   function Token_At (Item : Definition; Index : Positive)
      return Math_Tokens.Token is (Item.Tokens (Index));
   function Definition_Count (Item : Context) return Natural is
     (Natural (Item.Definitions.Length));

   function Definition_At
     (Item : Context; Index : Positive) return Definition is
   begin
      if Index > Definition_Count (Item) then
         raise Constraint_Error with "macro definition index out of range";
      end if;
      return Item.Definitions (Index);
   end Definition_At;
   function Diagnostic (Item : Context) return Diagnostic_Kind is
     (Item.Status);
end Math_Macros;
