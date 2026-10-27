with Ada.Text_IO;
with Ada.Strings.Unbounded;
with Math_Layout;
with Math_Model;
with Math_Syntax;

procedure Math_Constructs_Probe is
   use Math_Model;
   procedure Check (Source : String; Expected : Node_Kind) is
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse (Source);
      Geometry : constant Math_Layout.Box := Math_Layout.Build (Parsed);
      Root : Math_Syntax.Node;
   begin
      if not Math_Syntax.Is_Valid (Parsed) then
         raise Program_Error with Source & ": " & Math_Syntax.Error (Parsed);
      end if;
      Root := Math_Syntax.Element (Parsed, Positive (Math_Syntax.Root (Parsed)));
      Root := Math_Syntax.Element (Parsed, Positive (Root.First));
      if Root.Kind /= Expected or else not Geometry.Valid then
         raise Program_Error with "construct failed: " & Source & " / kind=" & Root.Kind'Image;
      end if;
      Ada.Text_IO.Put_Line ("PASS " & Source);
   end Check;
begin
   Check ("\binom{n}{k}", Binomial_Node);
   Check ("\dbinom{n}{k}", Binomial_Node);
   Check ("\tbinom{n}{k}", Binomial_Node);
   Check ("\overset{a}{=}", Annotation_Node);
   Check ("\underset{i}{=}", Annotation_Node);
   Check ("\boxed{x}", Boxed_Node);
   Check ("\phantom{x}", Phantom_Node);
   Check ("\hphantom{x}", Phantom_Node);
   Check ("\vphantom{x}", Phantom_Node);
   Check ("\textcolor{red}{x}", Color_Node);
   Check ("\textcolor{#00aaff}{x}", Color_Node);
   Check ("\displaystyle\frac{a}{b}", Style_Node);
   Check ("\scriptstyle x", Style_Node);
end Math_Constructs_Probe;
