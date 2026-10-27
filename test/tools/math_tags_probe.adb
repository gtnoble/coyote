with Ada.Text_IO;
with Ada.Strings.Unbounded;
with Math_Layout;
with Math_Model;
with Math_Syntax;

procedure Math_Tags_Probe is
   use Math_Model;

   procedure Check_Valid (Source : String; Has_Tag : Boolean) is
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse (Source);
      Root : Math_Syntax.Node;
      Content : Math_Syntax.Node;
      Geometry : Math_Layout.Box;
   begin
      if not Math_Syntax.Is_Valid (Parsed) then
         raise Program_Error with Source & ": " & Math_Syntax.Error (Parsed);
      end if;
      Root := Math_Syntax.Element (Parsed, Positive (Math_Syntax.Root (Parsed)));
      Root := Math_Syntax.Element (Parsed, Positive (Root.First));
      if Root.Kind /= Tagged_Node then
         raise Program_Error with "equation did not produce Tagged_Node";
      end if;
      if Has_Tag /= (Root.Second /= No_Node) then
         raise Program_Error with "tag presence mismatch";
      end if;
      Content := Math_Syntax.Element (Parsed, Positive (Root.First));
      if Content.Kind /= Array_Node then
         raise Program_Error with "equation content is not an array";
      end if;
      Geometry := Math_Layout.Build (Parsed);
      if not Geometry.Valid then
         raise Program_Error with "tagged geometry failed: " &
           Ada.Strings.Unbounded.To_String (Geometry.Message);
      end if;
      Ada.Text_IO.Put_Line ("PASS " & Source);
   end Check_Valid;

   procedure Check_Invalid (Source : String) is
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse (Source);
   begin
      if Math_Syntax.Is_Valid (Parsed) then
         raise Program_Error with "invalid tag syntax accepted: " & Source;
      end if;
      Ada.Text_IO.Put_Line ("PASS reject " & Source);
   end Check_Invalid;
begin
   Check_Valid ("\begin{equation}x\tag{4}\end{equation}", True);
   Check_Valid ("\begin{equation*}x\end{equation*}", False);
   Check_Invalid ("x\tag{4}");
   Check_Invalid ("\begin{equation}x\tag{4}\tag{5}\end{equation}");
   Check_Invalid ("\begin{equation}x\\y\end{equation}");
end Math_Tags_Probe;
