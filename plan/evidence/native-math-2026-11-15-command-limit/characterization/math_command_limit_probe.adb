with Ada.Containers;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Math_Engine;
with Math_Macros;
with Math_Syntax;

procedure Math_Command_Limit_Probe is
   use type Ada.Containers.Count_Type;
   use type Math_Engine.Status_Kind;
   Shared : aliased Math_Macros.Context;
   Output : Math_Engine.Result;
   Base : constant String := "\begin{array}{c}";
   Tail : constant String := "\kern{100em}\end{array}";
   procedure Run (Rules, Extra : Natural) is
      Source : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.To_Unbounded_String (Base);
   begin
      for I in 1 .. Rules loop
         Ada.Strings.Unbounded.Append (Source, "\hdashline ");
      end loop;
      Ada.Strings.Unbounded.Append (Source, Tail);
      if Extra > 0 then
         Ada.Strings.Unbounded.Append (Source, (1 .. Extra => 'x'));
      end if;
      Math_Engine.Parse
        (Ada.Strings.Unbounded.To_String (Source), Shared'Access,
         (others => <>), Output);
      Ada.Text_IO.Put_Line
        ("rules=" & Natural'Image (Rules) &
         " extra=" & Natural'Image (Extra) &
         " bytes=" & Natural'Image
           (Ada.Strings.Unbounded.Length (Source)) &
         " valid=" & Boolean'Image (Math_Syntax.Is_Valid (Output.Parsed)) &
         " nodes=" & Natural'Image (Math_Syntax.Count (Output.Parsed)) &
         " status=" & Math_Engine.Status_Kind'Image (Output.Status) &
         " commands=" & Ada.Containers.Count_Type'Image
           (Output.Geometry.Commands.Length) &
         " error=" & Math_Engine.Error (Output));
   end Run;
begin
   Run (312, 0);
   Run (314, 0);
   Run (315, 0);
   Run (314, 134);
   Run (314, 135);
end Math_Command_Limit_Probe;
