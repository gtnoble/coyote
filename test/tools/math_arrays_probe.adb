with Ada.Text_IO;
with Ada.Strings.Unbounded;
with Math_Layout;
with Math_Model;
with Math_Syntax;

procedure Math_Arrays_Probe is
   use type Math_Layout.Command_Kind;
   use type Math_Model.Node_Kind;
   use type Math_Model.Array_Kind;
   use type Math_Model.Array_Rule_Kind;
   use type Math_Model.Atom_Class;

   procedure Show (Name, Source : String) is
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse (Source);
      Layout : constant Math_Layout.Box := Math_Layout.Build (Parsed);
      Rules : Natural := 0;
   begin
      if Layout.Valid then
         for Command of Layout.Commands loop
            if Command.Kind = Math_Layout.Rule_Command then
               Rules := Rules + 1;
            end if;
         end loop;
         Ada.Text_IO.Put_Line
           (Name & " OK " & Long_Float'Image (Layout.Width) & " " &
            Natural'Image (Rules));
      else
         Ada.Text_IO.Put_Line (Name & " ERROR " & Math_Syntax.Error (Parsed));
      end if;
   end Show;

   procedure Check_Array_Rules
     (Name, Source : String; Expected : Natural; Valid : Boolean := True)
   is
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse (Source);
      Layout : constant Math_Layout.Box := Math_Layout.Build (Parsed);
      Array_Id : Math_Model.Node_Id := Math_Syntax.Root (Parsed);
      Array_Value : Math_Syntax.Node;
      Rule_Count : Natural := 0;
      Dashed_Metadata : Natural := 0;
      Dashed_Commands : Natural := 0;
   begin
      if Array_Id > 0 and then Array_Id <= Math_Syntax.Count (Parsed) then
         Array_Value := Math_Syntax.Element (Parsed, Positive (Array_Id));
         if Array_Value.Kind = Math_Model.Row_Node then
            Array_Id := Array_Value.First;
            if Array_Id > 0 then
               Array_Value := Math_Syntax.Element
                 (Parsed, Positive (Array_Id));
            end if;
         end if;
      end if;
      if Math_Syntax.Is_Valid (Parsed) /= Valid or else
        Layout.Valid /= Valid
      then
         raise Program_Error with "array rule validity mismatch: " & Name;
      end if;
      if Valid then
         if Array_Value.Kind /= Math_Model.Array_Node then
            raise Program_Error with "array rule AST missing: " & Name;
         end if;
         if not Array_Value.Array_Rules.Is_Empty then
            for Rule of Array_Value.Array_Rules loop
               Rule_Count := Rule_Count + 1;
               if Rule.Kind = Math_Model.Dashed_Array_Rule then
                  Dashed_Metadata := Dashed_Metadata + 1;
               end if;
            end loop;
         end if;
         for Command of Layout.Commands loop
            if Command.Kind = Math_Layout.Rule_Command then
               if Command.X < 0.0 or else Command.Y /= Command.Y or else
                 Command.Width <= 0.0 or else Command.Height <= 0.0
               then
                  raise Program_Error with "invalid array rule geometry";
               end if;
               if Dashed_Metadata > 0 and then Command.Width < Layout.Width
               then
                  Dashed_Commands := Dashed_Commands + 1;
               end if;
            end if;
         end loop;
         if Rule_Count /= Expected or else
           (Dashed_Metadata > 0 and then Dashed_Commands = 0)
         then
            raise Program_Error with "array rule assertion failed: " & Name;
         end if;
      end if;
      Ada.Text_IO.Put_Line
        (Name & (if Valid then " OK " else " REJECTED ") &
         Natural'Image (Rule_Count));
   end Check_Array_Rules;

   procedure Check_Rule_Spacing is
      One_Top : constant Math_Layout.Box := Math_Layout.Build
        (Math_Syntax.Parse ("\begin{array}{c}\hline a\end{array}"));
      Two_Top : constant Math_Layout.Box := Math_Layout.Build
        (Math_Syntax.Parse ("\begin{array}{c}\hline\hline a\end{array}"));
      Plain : constant Math_Layout.Box := Math_Layout.Build
        (Math_Syntax.Parse ("\begin{array}{c}a\\b\end{array}"));
      Interior : constant Math_Layout.Box := Math_Layout.Build
        (Math_Syntax.Parse ("\begin{array}{c}a\\\hline b\end{array}"));
      Top_First_Y : Long_Float := 0.0;
      Top_Second_Y : Long_Float := 0.0;
      Top_Seen : Natural := 0;
   begin
      for Command of Two_Top.Commands loop
         if Command.Kind = Math_Layout.Rule_Command then
            Top_Seen := Top_Seen + 1;
            if Top_Seen = 1 then
               Top_First_Y := Command.Y;
            else
               Top_Second_Y := Command.Y;
            end if;
         end if;
      end loop;
      if not One_Top.Valid or else not Two_Top.Valid or else
        not Plain.Valid or else not Interior.Valid
      then
         raise Program_Error with "array rule geometry invalid";
      end if;
      if Top_Seen /= 2 or else
        abs ((Two_Top.Ascent + Two_Top.Descent) -
             (One_Top.Ascent + One_Top.Descent) - 0.25) > 0.000_001 or else
        abs ((Top_Second_Y - Top_First_Y) - 0.25) > 0.000_001 or else
        abs ((Interior.Ascent + Interior.Descent) -
             (Plain.Ascent + Plain.Descent)) > 0.000_001
      then
         raise Program_Error with "array rule spacing mismatch";
      end if;
      Ada.Text_IO.Put_Line ("array-rule-spacing OK");
   end Check_Rule_Spacing;

   procedure Check_CD_Column_Stride is
      Layout : constant Math_Layout.Box := Math_Layout.Build
        (Math_Syntax.Parse ("\begin{CD}A@.B\end{CD}"));
      A_X : Long_Float := -1.0;
      B_X : Long_Float := -1.0;
   begin
      for Command of Layout.Commands loop
         if Command.Kind = Math_Layout.Glyph_Command then
            if Command.Code_Point = Character'Pos ('A') then
               A_X := Command.X;
            elsif Command.Code_Point = Character'Pos ('B') then
               B_X := Command.X;
            end if;
         end if;
      end loop;
      if not Layout.Valid or else A_X < 0.0 or else B_X <= Layout.Width / 2.0 then
         raise Program_Error with "CD empty-column stride mismatch";
      end if;
      Ada.Text_IO.Put_Line ("cd-empty-column-stride OK");
   end Check_CD_Column_Stride;

   procedure Check_CD_Row_Domain (Visible_Rows : Positive) is
      Source : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.To_Unbounded_String ("\begin{CD}");
      Parsed : Math_Syntax.Document;
      Layout : Math_Layout.Box;
      Array_Id : Math_Model.Node_Id;
      Array_Value : Math_Syntax.Node;
      Row_Id : Math_Model.Node_Id;
      Row_Value : Math_Syntax.Node;
      Row_Count : Natural := 0;
      Is_Ok : Boolean := True;
   begin
      for Index in 1 .. Visible_Rows loop
         if Index > 1 then
            Ada.Strings.Unbounded.Append (Source, "\\");
         end if;
         Ada.Strings.Unbounded.Append (Source, "A@.B");
      end loop;
      Ada.Strings.Unbounded.Append (Source, "\end{CD}");
      Parsed := Math_Syntax.Parse
        (Ada.Strings.Unbounded.To_String (Source));
      Layout := Math_Layout.Build (Parsed);
      Is_Ok := Math_Syntax.Is_Valid (Parsed) = (Visible_Rows <= 64)
        and then Layout.Valid = (Visible_Rows <= 64);
      if Visible_Rows <= 64 and then Is_Ok then
         Array_Id := Math_Syntax.Root (Parsed);
         Array_Value := Math_Syntax.Element (Parsed, Positive (Array_Id));
         if Array_Value.Kind = Math_Model.Row_Node then
            Array_Id := Array_Value.First;
         end if;
         Array_Value := Math_Syntax.Element (Parsed, Positive (Array_Id));
         Is_Ok := Array_Value.Kind = Math_Model.Array_Node
           and then Array_Value.Array_Type = Math_Model.CD_Array;
         Row_Id := Array_Value.First;
         while Row_Id /= Math_Model.No_Node loop
            Row_Count := Row_Count + 1;
            Row_Value := Math_Syntax.Element (Parsed, Positive (Row_Id));
            if Row_Value.First = Math_Model.No_Node then
               Is_Ok := Is_Ok and then
                 Row_Value.Next = Math_Model.No_Node;
            end if;
            Row_Id := Row_Value.Next;
         end loop;
         Is_Ok := Is_Ok and then Row_Count = Visible_Rows + 1;
      elsif Visible_Rows = 65 then
         Is_Ok := Is_Ok and then
           Math_Syntax.Error (Parsed) = "CD row limit exceeded";
      end if;
      if not Is_Ok then
         raise Program_Error with "CD row-domain assertion failed: " &
           Positive'Image (Visible_Rows) & " rows=" &
           Natural'Image (Row_Count) & " parse=" &
           Math_Syntax.Error (Parsed) & " layout=" &
           Ada.Strings.Unbounded.To_String (Layout.Message);
      end if;
      Ada.Text_IO.Put_Line
        ("cd-visible-rows" & Positive'Image (Visible_Rows) & " OK");
   end Check_CD_Row_Domain;

   procedure Check_CD (Name, Source : String; Valid : Boolean) is
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse (Source);
      Is_Ok : Boolean := Math_Syntax.Is_Valid (Parsed) = Valid;
      Array_Id : Math_Model.Node_Id := Math_Syntax.Root (Parsed);
      Array_Value : Math_Syntax.Node;
      Row_Id : Math_Model.Node_Id;
      Row_Value : Math_Syntax.Node;
      Cell_Id : Math_Model.Node_Id;
      Cell_Value : Math_Syntax.Node;
      Arrow_Id : Math_Model.Node_Id;
      Arrow_Value : Math_Syntax.Node;
      Layout : Math_Layout.Box;
   begin
      if Valid and then Is_Ok and then Name not in "cd-cr" | "cd-empty"
        and then Array_Id > 0 and then
          Array_Id <= Math_Syntax.Count (Parsed)
      then
         Array_Value := Math_Syntax.Element (Parsed, Positive (Array_Id));
         Is_Ok := Array_Value.Kind = Math_Model.Row_Node;
         if Array_Value.First /= Math_Model.No_Node then
            Array_Id := Array_Value.First;
         end if;
         Array_Value := Math_Syntax.Element (Parsed, Positive (Array_Id));
         Is_Ok := Is_Ok and then Array_Value.Kind = Math_Model.Array_Node
           and then Array_Value.Array_Type = Math_Model.CD_Array;
         Row_Id := Array_Value.First;
         Row_Value := Math_Syntax.Element (Parsed, Positive (Row_Id));
         Cell_Id := Row_Value.First;
         Cell_Value := Math_Syntax.Element (Parsed, Positive (Cell_Id));
         Is_Ok := Is_Ok and then Cell_Value.Kind = Math_Model.Row_Node;
         Cell_Id := Cell_Value.Next;
         Is_Ok := Is_Ok and then Cell_Id /= Math_Model.No_Node;
         if Cell_Id /= Math_Model.No_Node then
            Cell_Value := Math_Syntax.Element (Parsed, Positive (Cell_Id));
            Is_Ok := Is_Ok and then Cell_Value.Kind = Math_Model.Row_Node;
            Arrow_Id := Cell_Value.First;
            if Arrow_Id /= Math_Model.No_Node then
               Arrow_Value := Math_Syntax.Element
                 (Parsed, Positive (Arrow_Id));
               if Name = "cd-horizontal" then
                  Is_Ok := Is_Ok and then Arrow_Value.Kind =
                    Math_Model.Stretchy_Node;
               elsif Name = "cd-vertical" then
                  Is_Ok := Is_Ok and then Arrow_Value.Kind =
                    Math_Model.CD_Arrow_Node;
               end if;
            end if;
         end if;
         if Cell_Value.Kind = Math_Model.Row_Node then
            Arrow_Id := Cell_Value.First;
            while Arrow_Id /= Math_Model.No_Node loop
               Arrow_Value := Math_Syntax.Element
                 (Parsed, Positive (Arrow_Id));
               if Arrow_Value.Kind in Math_Model.Stretchy_Node |
                 Math_Model.CD_Arrow_Node |
                 Math_Model.Delimited_Node |
                 Math_Model.Space_Node
               then
                  Is_Ok := Is_Ok and then Cell_Value.Class =
                    Math_Model.Ordinary;
               end if;
               Arrow_Id := Arrow_Value.Next;
            end loop;
         end if;
      end if;
      Is_Ok := Is_Ok and then
        (if Valid then Math_Syntax.Is_Valid (Parsed) else
           not Math_Syntax.Is_Valid (Parsed));
      Layout := Math_Layout.Build (Parsed);
      Is_Ok := Is_Ok and then Layout.Valid = Valid;
      if Layout.Valid then
         Is_Ok := Is_Ok and then Layout.Width = Layout.Width
           and then Layout.Ascent = Layout.Ascent
           and then Layout.Descent = Layout.Descent;
         if Name = "cd-empty" then
            Is_Ok := Is_Ok and then Layout.Width = 0.0
              and then Layout.Ascent = 0.0
              and then Layout.Descent = 0.0
              and then Layout.Commands.Is_Empty;
         end if;
      end if;
      Ada.Text_IO.Put_Line
        (Name & (if Is_Ok then " OK" else " FAIL") &
         (if Layout.Valid then
            " " & Long_Float'Image (Layout.Ascent) & " " &
              Long_Float'Image (Layout.Descent) & " " &
              Long_Float'Image (Layout.Width)
          elsif Math_Syntax.Is_Valid (Parsed) then
            " LAYOUT_ERROR " & Ada.Strings.Unbounded.To_String
              (Layout.Message)
          else " " & Math_Syntax.Error (Parsed)));
      if not Is_Ok then
         raise Program_Error with "CD probe assertion failed: " & Name;
      end if;
   end Check_CD;
begin
   Check_Rule_Spacing;
   Check_CD_Column_Stride;
   Check_CD_Row_Domain (63);
   Check_CD_Row_Domain (64);
   Check_CD_Row_Domain (65);
   Check_Array_Rules
     ("hline-top", "\begin{array}{c}\hline a\end{array}", 1);
   Check_Array_Rules
     ("hline-repeated",
      "\begin{array}{c}\hline\hline a\end{array}", 2);
   Check_Array_Rules
     ("hline-interior",
      "\begin{array}{c}a\\\hline b\end{array}", 1);
   Check_Array_Rules
     ("hline-repeated-interior",
      "\begin{array}{c}a\\\hline\hline b\end{array}", 2);
   Check_Array_Rules
     ("hdashline-interior",
      "\begin{array}{c}a\\\hdashline b\end{array}", 1);
   Check_Array_Rules
     ("hline-inside-cell", "\begin{array}{c}a\hline b\end{array}", 0,
      False);
   Show ("array-align", "\begin{array}{lcr}a&bb&c\\xxx&y&zz\end{array}");
   Show ("array-rule", "\begin{array}{|c|r|}a&bb\\ccc&d\end{array}");
   Show
     ("nested", "\begin{array}{c}\begin{matrix}a&b\\c&d\end{matrix}\end{array}");
   Show
     ("alignedat", "\begin{alignedat}{2}a&=b&c&=d\\x&=y&z&=w\end{alignedat}");
   Show ("bad-spec", "\begin{array}{lx}a&b\end{array}");
   Show ("missing-spec", "\begin{array}a&b\end{array}");
   Show ("wrong-columns", "\begin{array}{cc}a&b&c\end{array}");
   Show ("wrong-pairs", "\begin{alignedat}{2}a&=b\end{alignedat}");
   Check_CD
     ("cd-horizontal", "\begin{CD}A@>f>>B&C@=D\end{CD}", True);
   Check_CD
     ("cd-vertical", "\begin{CD}A@VfVV&B@|C@.D\end{CD}", True);
   Check_CD
     ("cd-cr", "\begin{CD}A\cr B\end{CD}", True);
   Check_CD
     ("cd-empty-label", "\begin{CD}A@>x>>B\end{CD}", True);
   Check_CD
     ("cd-bad-marker", "\begin{CD}A@?B\end{CD}", False);
   Check_CD
     ("cd-missing-label", "\begin{CD}A@>f>B\end{CD}", False);
   Show
     ("cd-cr-scope", "\begin{CD}A\cr B\end{CD}+C");
end Math_Arrays_Probe;
