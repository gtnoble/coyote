with Ada.Characters.Handling;
with Ada.Containers.Vectors;
with Ada.Unchecked_Deallocation;
with Ada.Exceptions;
with Ada.Text_IO;
with Ada.Strings.Unbounded;
with Math_Source;
with GNATCOLL.JSON;
with Math_Layout;
with Math_Engine;
with Math_Model;
with Math_Macros;
with Math_Syntax;
with Math_Paths;
with Math_Semantics;
with Math_Tokens;

procedure Math_Export is
   use GNATCOLL.JSON;
   use type Math_Layout.Command_Kind;
   use type Math_Engine.Status_Kind;
   use type Math_Model.Node_Id;
   use type Math_Paths.Command_Kind;

   Schema_Name : constant String := "coyote.math-export.v1";
   Strict_Name : constant String := "warn";

   type Context_Access is access Math_Macros.Context;
   type Sequence_State is record
      Name : Ada.Strings.Unbounded.Unbounded_String;
      Context : Context_Access;
   end record;
   package Sequence_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Sequence_State);
   procedure Free_Context is new Ada.Unchecked_Deallocation
     (Math_Macros.Context, Context_Access);
   Sequences : Sequence_Vectors.Vector;

   function Token_Array
     (Definition : Math_Macros.Definition; Is_Default : Boolean)
      return JSON_Array is
      Result : JSON_Array := Empty_Array;
      Count : constant Natural :=
        (if Is_Default then Math_Macros.Default_Token_Count (Definition)
         else Math_Macros.Token_Count (Definition));
   begin
      for Index in 1 .. Count loop
         declare
            Token : constant Math_Tokens.Token :=
              (if Is_Default then
                 Math_Macros.Default_Token_At (Definition, Index)
               else Math_Macros.Token_At (Definition, Index));
            Value : constant JSON_Value := Create_Object;
         begin
            Set_Field (Value, "text",
              Ada.Strings.Unbounded.To_String (Token.Lexeme));
            Set_Field (Value, "startByte", Integer (Token.First_Byte));
            Set_Field (Value, "endByte", Integer (Token.After_Byte));
            Append (Result, Value);
         end;
      end loop;
      return Result;
   end Token_Array;

   function Macro_State (Item : Math_Macros.Context) return JSON_Value is
      Result : constant JSON_Value := Create_Object;
   begin
      for Index in 1 .. Math_Macros.Definition_Count (Item) loop
         declare
            Definition : constant Math_Macros.Definition :=
              Math_Macros.Definition_At (Item, Positive (Index));
            Value : constant JSON_Value := Create_Object;
         begin
            Set_Field (Value, "tokens", Create
              (Token_Array (Definition, False)));
            Set_Field (Value, "numArgs", Integer
              (Math_Macros.Num_Params (Definition)));
            Set_Field (Value, "hasOptionalDefault",
              Math_Macros.Has_Optional_Default (Definition));
            if Math_Macros.Has_Optional_Default (Definition) then
               Set_Field (Value, "default", Create
                 (Token_Array (Definition, True)));
            end if;
            Set_Field (Result, Math_Macros.Name_Of (Definition), Value);
         end;
      end loop;
      return Result;
   end Macro_State;
   function Shared_Context (Name : String) return not null access
     Math_Macros.Context is
   begin
      if not Sequences.Is_Empty then
         for Index in Sequences.First_Index .. Sequences.Last_Index loop
            if Ada.Strings.Unbounded.To_String (Sequences (Index).Name) = Name then
               return Sequences (Index).Context;
            end if;
         end loop;
      end if;
      declare
         State : Sequence_State;
      begin
         State.Name := Ada.Strings.Unbounded.To_Unbounded_String (Name);
         State.Context := new Math_Macros.Context;
         Sequences.Append (State);
         return State.Context;
      end;
   end Shared_Context;

   function Lower (Text : String) return String is
      Result : String (Text'Range);
   begin
      for Index in Text'Range loop
         Result (Index) := Ada.Characters.Handling.To_Lower (Text (Index));
      end loop;
      return Result;
   end Lower;

   function Field_String
     (Item : JSON_Value;
      Name : String) return String is
   begin
      return GNATCOLL.JSON.Get (Item, Name);
   end Field_String;

   function Finite (Value : Long_Float) return Boolean is
   begin
      return Value = Value and then abs Value <= Long_Float'Last;
   end Finite;

   function Is_Finite (Box : Math_Layout.Box) return Boolean is
   begin
      if not Finite (Box.Width) or else not Finite (Box.Ascent) or else
        not Finite (Box.Descent)
      then
         return False;
      end if;
      if not Box.Commands.Is_Empty then
         for Index in Box.Commands.First_Index .. Box.Commands.Last_Index loop
            declare
               Command : constant Math_Layout.Draw_Command :=
                 Box.Commands (Index);
            begin
               if not Finite (Command.X) or else not Finite (Command.Y) or else
                 not Finite (Command.Scale) or else
                 not Finite (Command.Width) or else
                 not Finite (Command.Height)
               then
                  return False;
               end if;
            end;
         end loop;
      end if;
      return True;
   end Is_Finite;

   function Error_Value
     (Message : String;
      Position : Natural) return JSON_Value is
      Result : constant JSON_Value := Create_Object;
   begin
      Set_Field (Result, "message", Message);
      Set_Field (Result, "position", Integer (Position));
      return Result;
   end Error_Value;

   function New_Record
     (Id : JSON_Value;
      Source : JSON_Value;
      Display_Mode : Boolean;
      Status : String;
      Error : JSON_Value := JSON_Null;
      Box : JSON_Value := JSON_Null;
      Commands : JSON_Value := JSON_Null;
      Nodes : JSON_Value := JSON_Null;
      Root : Integer := 0;
      Semantic : JSON_Value := JSON_Null;
      Macro_State_Value : JSON_Value := JSON_Null;
      Policy : Boolean := False;
      Policy_Message : String := "") return JSON_Value is
      Result : constant JSON_Value := Create_Object;
      Capabilities : constant JSON_Value := Create_Object;
   begin
      Set_Field (Result, "schema", Schema_Name);
      Set_Field (Result, "engine", "native");
      Set_Field (Result, "id", Id);
      Set_Field (Result, "source", Source);
      Set_Field (Result, "displayMode", Display_Mode);
      Set_Field (Result, "status", Status);
      Set_Field (Result, "error", Error);
      Set_Field (Result, "box", Box);
      Set_Field (Result, "commands", Commands);
      Set_Field (Result, "nodes", Nodes);
      Set_Field (Result, "parsedRoot", Root);
      Set_Field (Result, "semanticTree", Semantic);
      if Macro_State_Value.Kind = JSON_Object_Type then
         Set_Field (Result, "macroState", Macro_State_Value);
         Set_Field (Result, "macroStateComplete", True);
      end if;
      if Policy then
         declare
            Policy_Value : constant JSON_Value := Create_Object;
         begin
            Set_Field (Policy_Value, "refusal", True);
            Set_Field (Policy_Value, "literalFallback", True);
            Set_Field
              (Policy_Value, "diagnostic",
               Policy_Message);
            Set_Field (Result, "policy", Policy_Value);
         end;
      end if;
      declare
         Options : constant JSON_Value := Create_Object;
      begin
         Set_Field (Options, "displayMode", Display_Mode);
         Set_Field (Options, "maxExpand", Integer (1_000));
         Set_Field (Options, "maxSize", Integer (100));
         Set_Field (Options, "strict", Strict_Name);
         Set_Field (Options, "throwOnError", True);
         Set_Field (Options, "trust", False);
         Set_Field (Result, "options", Options);
      end;
      Set_Field (Capabilities, "syntax", True);
      Set_Field (Capabilities, "commands", True);
      Set_Field (Capabilities, "semantic", Semantic.Kind = JSON_Object_Type);
      Set_Field (Capabilities, "paths", True);
      Set_Field (Capabilities, "colors", True);
      Set_Field (Capabilities, "sharedMacros", True);
      Set_Field (Capabilities, "macroStateSnapshot", True);
      Set_Field (Capabilities, "optionsMeasured", False);
      Set_Field (Capabilities, "optionsApplied", True);
      Set_Field (Result, "capabilities", Capabilities);
      return Result;
   end New_Record;

   function Command_Array (Item : Math_Layout.Box) return JSON_Value is
      Result : constant JSON_Value := Create (Empty_Array);
   begin
      if not Item.Commands.Is_Empty then
         for Index in Item.Commands.First_Index .. Item.Commands.Last_Index loop
            declare
               Command : constant Math_Layout.Draw_Command :=
                 Item.Commands (Index);
            begin
               if Command.Kind /= Math_Layout.Glyph_Command or else
                 Command.Code_Point > 0
               then
                  declare
                     Value : constant JSON_Value := Create_Object;
                  begin
               Set_Field
                 (Value, "kind",
                  (case Command.Kind is
                     when Math_Layout.Glyph_Command => "glyph",
                     when Math_Layout.Rule_Command => "rule",
                     when Math_Layout.Path_Command => "path"));
               Set_Field (Value, "font", Lower (Math_Model.Font_Kind'Image
                 (Command.Font)));
               Set_Field (Value, "codePoint", Integer (Command.Code_Point));
               Set_Field_Long_Float (Value, "x", Command.X);
               Set_Field_Long_Float (Value, "y", Command.Y);
               Set_Field_Long_Float (Value, "scale", Command.Scale);
               Set_Field_Long_Float (Value, "width", Command.Width);
               Set_Field_Long_Float (Value, "height", Command.Height);
               Set_Field (Value, "hasClip", Command.Has_Clip);
               Set_Field_Long_Float (Value, "clipX", Command.Clip_X);
               Set_Field_Long_Float (Value, "clipY", Command.Clip_Y);
               Set_Field_Long_Float (Value, "clipW", Command.Clip_W);
               Set_Field_Long_Float (Value, "clipH", Command.Clip_H);
               Set_Field (Value, "hasColor", Command.Has_Color);
               if Command.Has_Color then
                  Set_Field_Long_Float (Value, "red", Command.Red);
                  Set_Field_Long_Float (Value, "green", Command.Green);
                  Set_Field_Long_Float (Value, "blue", Command.Blue);
                  Set_Field_Long_Float (Value, "alpha", Command.Alpha);
               end if;
               if Command.Kind = Math_Layout.Path_Command then
                  declare
                     Segments : constant JSON_Value := Create (Empty_Array);
                  begin
                     if Command.Path_Data.Is_Empty then
                        raise Constraint_Error with "path command has no segments";
                     end if;
                     for Part in Command.Path_Data.First_Index ..
                       Command.Path_Data.Last_Index
                     loop
                        declare
                           Segment : constant Math_Paths.Segment :=
                             Command.Path_Data (Part);
                           Segment_Value : constant JSON_Value := Create_Object;
                        begin
                           Set_Field
                             (Segment_Value, "kind",
                              (case Segment.Kind is
                                 when Math_Paths.Move_To => "move",
                                 when Math_Paths.Line_To => "line",
                                 when Math_Paths.Cubic_To => "cubic",
                                 when Math_Paths.Close_Path => "close"));
                           Set_Field_Long_Float
                             (Segment_Value, "x1", Segment.First.X);
                           Set_Field_Long_Float
                             (Segment_Value, "y1", Segment.First.Y);
                           Set_Field_Long_Float
                             (Segment_Value, "x2", Segment.Second.X);
                           Set_Field_Long_Float
                             (Segment_Value, "y2", Segment.Second.Y);
                           Set_Field_Long_Float
                             (Segment_Value, "x3", Segment.Third.X);
                           Set_Field_Long_Float
                             (Segment_Value, "y3", Segment.Third.Y);
                           Append (Segments, Segment_Value);
                        end;
                     end loop;
                     Set_Field (Value, "segments", Segments);
                  end;
               end if;
               Append (Result, Value);
                  end;
               end if;
            end;
         end loop;
      end if;
      return Result;
   end Command_Array;

   function Semantic_Value
     (Projection : Math_Semantics.Document) return JSON_Value is
      Result : constant JSON_Value := Create_Object;
      Nodes : constant JSON_Value := Create (Empty_Array);
   begin
      if not Math_Semantics.Is_Valid (Projection) or else
        Math_Semantics.Count (Projection) = 0 or else
        Math_Semantics.Root (Projection) = 0
      then
         return JSON_Null;
      end if;
      for Index in 1 .. Math_Semantics.Count (Projection) loop
         declare
            Node : constant Math_Semantics.Semantic_Node :=
              Math_Semantics.Element (Projection, Positive (Index));
            Value : constant JSON_Value := Create_Object;
         begin
            Set_Field (Value, "id", Integer (Index));
            Set_Field (Value, "kind", Lower (Math_Model.Node_Kind'Image
              (Node.Kind)));
            Set_Field (Value, "role", Lower (Math_Semantics.Child_Role'Image
              (Node.Role)));
            Set_Field (Value, "astId", Integer (Node.AST_Id));
            Set_Field (Value, "parent", Integer (Node.Parent));
            Set_Field (Value, "firstChild", Integer (Node.First_Child));
            Set_Field (Value, "nextSibling", Integer (Node.Next_Sibling));
            Set_Field (Value, "childCount", Integer (Node.Child_Count));
            Set_Field (Value, "position", Integer (Node.Position));
            Set_Field (Value, "class", Lower (Math_Model.Atom_Class'Image
              (Node.Class)));
            Set_Field (Value, "font", Lower (Math_Model.Font_Kind'Image
              (Node.Font)));
            Set_Field (Value, "codePoint", Integer (Node.Code_Point));
            Set_Field (Value, "stretchyName",
              Ada.Strings.Unbounded.To_String (Node.Stretchy_Name));
            Set_Field (Value, "stretchyMode",
              (if Node.Code_Point = 0 then "accent"
               elsif Node.Code_Point = 1 then "labelled-arrow"
               else "special"));
            Set_Field_Long_Float (Value, "amount", Node.Amount);
            Set_Field_Long_Float (Value, "raiseAmount", Node.Amount);
            Set_Field_Long_Float (Value, "width", Node.Width);
            Set_Field_Long_Float (Value, "height", Node.Height);
            Set_Field_Long_Float (Value, "ruleWidth", Node.Width);
            Set_Field_Long_Float (Value, "ruleHeight", Node.Height);
            Set_Field_Long_Float (Value, "depth", Node.Depth);
            Set_Field_Long_Float (Value, "sizingScale", Node.Scale);
            Set_Field (Value, "enclosure",
              Lower (Math_Model.Enclosure_Kind'Image (Node.Enclosure)));
            Set_Field (Value, "fractionStyle", Lower
              (Math_Model.Fraction_Style'Image (Node.Fraction_Type)));
            Set_Field (Value, "scriptType", Lower
              (Math_Model.Script_Layout'Image (Node.Script_Type)));
            Set_Field (Value, "arrayType", Lower
              (Math_Model.Array_Kind'Image (Node.Array_Type)));
            Append (Nodes, Value);
         end;
      end loop;
      Set_Field (Result, "root", Integer (Math_Semantics.Root (Projection)));
      Set_Field (Result, "nodes", Nodes);
      return Result;
   end Semantic_Value;

   function Node_Array (Item : Math_Syntax.Document) return JSON_Value is
      Result : constant JSON_Value := Create (Empty_Array);
   begin
      for Index in 1 .. Math_Syntax.Count (Item) loop
         declare
            Node : constant Math_Syntax.Node := Math_Syntax.Element
              (Item, Positive (Index));
            Value : constant JSON_Value := Create_Object;
         begin
            Set_Field (Value, "id", Integer (Index));
            Set_Field (Value, "kind", Lower (Math_Model.Node_Kind'Image
              (Node.Kind)));
            Set_Field (Value, "class", Lower (Math_Model.Atom_Class'Image
              (Node.Class)));
            Set_Field (Value, "font", Lower (Math_Model.Font_Kind'Image
              (Node.Font)));
            Set_Field (Value, "codePoint", Integer (Node.Code_Point));
            Set_Field (Value, "stretchyName",
              Ada.Strings.Unbounded.To_String (Node.Stretchy_Name));
            Set_Field (Value, "stretchyMode",
              (if Node.Code_Point = 0 then "accent"
               elsif Node.Code_Point = 1 then "labelled-arrow"
               else "special"));
            Set_Field (Value, "first", Integer (Node.First));
            Set_Field (Value, "second", Integer (Node.Second));
            Set_Field (Value, "third", Integer (Node.Third));
            Set_Field (Value, "next", Integer (Node.Next));
            Set_Field (Value, "position", Integer (Node.Position));
            Set_Field_Long_Float (Value, "amount", Node.Amount);
            Set_Field_Long_Float (Value, "raiseAmount", Node.Amount);
            Set_Field_Long_Float (Value, "width", Node.Width);
            Set_Field_Long_Float (Value, "height", Node.Height);
            Set_Field_Long_Float (Value, "ruleWidth", Node.Width);
            Set_Field_Long_Float (Value, "ruleHeight", Node.Height);
            Set_Field_Long_Float (Value, "depth", Node.Depth);
            Set_Field_Long_Float (Value, "sizingScale", Node.Scale);
            Set_Field (Value, "enclosure",
              Lower (Math_Model.Enclosure_Kind'Image (Node.Enclosure)));
            Set_Field (Value, "fractionStyle",
              Lower (Math_Model.Fraction_Style'Image (Node.Fraction_Type)));
            Set_Field (Value, "scriptType",
              Lower (Math_Model.Script_Layout'Image (Node.Script_Type)));
            Set_Field (Value, "arrayType",
              Lower (Math_Model.Array_Kind'Image (Node.Array_Type)));
            Append (Result, Value);
         end;
      end loop;
      return Result;
   end Node_Array;

   function Handle (Line : String) return JSON_Value is
      Parsed : constant Read_Result := Read (Line);
      Request : JSON_Value;
      Id : JSON_Value := JSON_Null;
      Source_Value : JSON_Value := JSON_Null;
      Source_Text : Ada.Strings.Unbounded.Unbounded_String;
      Display_Mode : Boolean := False;
      Document : Math_Syntax.Document;
      Layout : Math_Layout.Box;
      Box_Value : JSON_Value;
      Position : Natural := 0;
      Validated_Source : Math_Source.Source;
      Source_Diagnostic : Math_Source.Diagnostic_Kind;
      Source_Error_Byte : Natural := 0;
      Sequence : Ada.Strings.Unbounded.Unbounded_String;
      Has_Sequence : Boolean := False;
      Fresh_Context : aliased Math_Macros.Context;
      Context : access Math_Macros.Context;
      Semantic : JSON_Value := JSON_Null;
      Macro_Snapshot : JSON_Value := JSON_Null;
      Policy_Refusal : Boolean := False;
      Policy_Diagnostic : Ada.Strings.Unbounded.Unbounded_String;
      Engine_Request : Math_Engine.Request := (others => <>);
      Engine_Result : Math_Engine.Result;
      Strict_Name : constant String := "warn";
   begin
      if not Parsed.Success then
         return New_Record
           (Id, Source_Value, False, "parse-error",
            Error_Value (Format_Parsing_Error (Parsed.Error), 0));
      end if;
      Request := Parsed.Value;
      if Request.Kind /= JSON_Object_Type or else
        not Has_Field (Request, "id") or else
        not Has_Field (Request, "source")
      then
         return New_Record
           (Id, Source_Value, False, "parse-error",
            Error_Value ("request requires id and source", 0));
      end if;
      Id := Get (Request, "id");
      Source_Value := Get (Request, "source");
      if Id.Kind /= JSON_String_Type or else
        Source_Value.Kind /= JSON_String_Type
      then
         return New_Record
           (Id, Source_Value, False, "parse-error",
            Error_Value ("id and source must be strings", 0));
      end if;
      Source_Text := Ada.Strings.Unbounded.To_Unbounded_String
        (Field_String (Request, "source"));
      if Has_Field (Request, "displayMode") then
         if Get (Request, "displayMode").Kind /= JSON_Boolean_Type then
            return New_Record
              (Id, Source_Value, False, "parse-error",
               Error_Value ("displayMode must be boolean", 0));
         end if;
         Display_Mode := Get (Request, "displayMode");
      end if;

      if Has_Field (Request, "sequence") and then
        Get (Request, "sequence").Kind = JSON_String_Type
      then
         Sequence := Ada.Strings.Unbounded.To_Unbounded_String
           (Field_String (Request, "sequence"));
         Has_Sequence := Ada.Strings.Unbounded.Length (Sequence) > 0;
      end if;
      if Has_Sequence then
         Context := Shared_Context
           (Ada.Strings.Unbounded.To_String (Sequence));
      else
         Context := Fresh_Context'Access;
      end if;

      Engine_Request.Style :=
        (if Display_Mode then Math_Layout.Display_Style
         else Math_Layout.Text_Style);
      Engine_Request.Strict := Math_Syntax.Strict_Warn;
      Engine_Request.Global_Group := False;
      Engine_Request.Settings.Max_Expand := 1_000;
      Engine_Request.Settings.Max_Size := 100;
      Engine_Request.Settings.Throw_On_Error := True;
      Math_Engine.Parse
        (Ada.Strings.Unbounded.To_String (Source_Text), Context,
         Engine_Request, Engine_Result);
      Document := Engine_Result.Parsed;
      if Has_Sequence then
         Macro_Snapshot := Macro_State (Context.all);
      end if;
      Policy_Refusal :=
        Engine_Result.Status = Math_Engine.Policy_Visible_Command;
      for Diagnostic_Index in 1 .. Math_Syntax.Diagnostic_Count (Document) loop
         declare
            Diagnostic : constant Math_Syntax.Diagnostic :=
              Math_Syntax.Diagnostic_At
                (Document, Positive (Diagnostic_Index));
            Message : constant String :=
              Ada.Strings.Unbounded.To_String (Diagnostic.Message);
         begin
            if Policy_Refusal and then Message'Length >= 27 and then
              Message (1 .. 27) = "refused untrusted command: "
            then
               Policy_Diagnostic :=
                 Ada.Strings.Unbounded.To_Unbounded_String (Message);
               exit;
            end if;
         end;
      end loop;
      Math_Source.Create
        (Ada.Strings.Unbounded.To_String (Source_Text), Validated_Source,
         Source_Diagnostic, Source_Error_Byte);
      if not Math_Syntax.Is_Valid (Document) then
         Position := Math_Syntax.Error_Position (Document);
         if Math_Source.Is_Valid (Validated_Source) and then Position > 0 then
            Position := Math_Source.UTF16_Offset
              (Validated_Source,
               Math_Source.Scalar_Boundary (Validated_Source, Position - 1)) + 1;
         end if;
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "math_export: " & Math_Syntax.Error (Document));
         return New_Record
           (Id, Source_Value, Display_Mode, "parse-error",
            Error_Value (Math_Syntax.Error (Document), Position),
            Nodes => Node_Array (Document),
            Root => Integer (Math_Syntax.Root (Document)),
            Macro_State_Value => Macro_Snapshot, Policy => Policy_Refusal,
            Policy_Message => Ada.Strings.Unbounded.To_String
              (Policy_Diagnostic));
      end if;
      Layout := Engine_Result.Geometry;
      if not Layout.Valid or else not Is_Finite (Layout) then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "math_export: " &
            Ada.Strings.Unbounded.To_String (Layout.Message));
         return New_Record
           (Id, Source_Value, Display_Mode, "layout-error",
            Error_Value (Ada.Strings.Unbounded.To_String (Layout.Message), 0),
            Nodes => Node_Array (Document),
            Root => Integer (Math_Syntax.Root (Document)),
            Macro_State_Value => Macro_Snapshot, Policy => Policy_Refusal,
            Policy_Message => Ada.Strings.Unbounded.To_String
              (Policy_Diagnostic));
      end if;
      Semantic := Semantic_Value (Engine_Result.Meaning);
      Box_Value := Create_Object;
      Set_Field_Long_Float (Box_Value, "width", Layout.Width);
      Set_Field_Long_Float (Box_Value, "ascent", Layout.Ascent);
      Set_Field_Long_Float (Box_Value, "descent", Layout.Descent);
      return New_Record
        (Id, Source_Value, Display_Mode,
         (if Engine_Result.Status = Math_Engine.Policy_Visible_Command
          then "policy-visible-command" else "ok"),
         Box => Box_Value,
         Commands => Command_Array (Layout), Nodes => Node_Array (Document),
         Root => Integer (Math_Syntax.Root (Document)),
         Semantic => Semantic, Macro_State_Value => Macro_Snapshot,
         Policy => Policy_Refusal,
         Policy_Message => Ada.Strings.Unbounded.To_String
           (Policy_Diagnostic));
   exception
      when Error : others =>
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "math_export: " & Ada.Exceptions.Exception_Message (Error));
         return New_Record
           (Id, Source_Value, Display_Mode, "parse-error",
            Error_Value (Ada.Exceptions.Exception_Message (Error), 0));
   end Handle;

   Line_Number : Natural := 0;
begin
   while not Ada.Text_IO.End_Of_File loop
      declare
         Line : constant String := Ada.Text_IO.Get_Line;
      begin
         Line_Number := Line_Number + 1;
         Ada.Text_IO.Put_Line (Write (Handle (Line), Compact => True));
      exception
         when Error : others =>
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "math_export: line" & Natural'Image (Line_Number) & ": " &
               Ada.Exceptions.Exception_Message (Error));
            Ada.Text_IO.Put_Line
              (Write
                 (New_Record
                    (JSON_Null, JSON_Null, False, "parse-error",
                     Error_Value
                       (Ada.Exceptions.Exception_Message (Error), 0)),
               Compact => True));
      end;
   end loop;
   if not Sequences.Is_Empty then
      for Index in Sequences.First_Index .. Sequences.Last_Index loop
         Free_Context (Sequences (Index).Context);
      end loop;
   end if;
end Math_Export;
