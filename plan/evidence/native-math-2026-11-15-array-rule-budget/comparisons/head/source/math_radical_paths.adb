with Ada.Strings.Fixed;
with Math_Paths;

package body Math_Radical_Paths is
   function Image (Value : Long_Float) return String is
      Text : constant String := Long_Float'Image (Value);
   begin
      return Ada.Strings.Fixed.Trim (Text, Ada.Strings.Both);
   end Image;

   function Build
     (Size : Natural; Extra_Vinculum, Width : Long_Float)
      return Math_Paths.Path
   is
      Extra : Long_Float;
      Edge : Long_Float;
   begin
      if Size > 4 or else not Extra_Vinculum'Valid or else
        not Width'Valid or else Extra_Vinculum < 0.0 or else
        Width <= 0.0 or else Extra_Vinculum > 16.0 or else Width > 16.0
      then
         return Math_Paths.Parse ("");
      end if;
      Extra := Extra_Vinculum * 1_000.0;
      --  Preserve KaTeX's unscaled horizontal paths; callers clip.
      Edge := 400_000.0;
      case Size is
         when 0 =>
            return Math_Paths.Parse
              ("M95," & Image (622.0 + Extra + 80.0) &
               "c-2.7,0,-7.17,-2.7,-13.5,-8c-5.8,-5.3,-9.5,-10,-9.5,-14" &
               "c0,-2,0.3,-3.3,1,-4c1.3,-2.7,23.83,-20.7,67.5,-54" &
               "c44.2,-33.3,65.8,-50.3,66.5,-51c1.3,-1.3,3,-2,5,-2c4.7,0,8.7,3.3,12,10" &
               "s173,378,173,378c0.7,0,35.3,-71,104,-213c68.7,-142,137.5,-285,206.5,-429" &
               "c69,-144,104.5,-217.7,106.5,-221l" & Image (Extra / 2.075) & " -" & Image (Extra) &
               "c5.3,-9.3,12,-14,20,-14H" & Image (Edge) & "v" & Image (40.0 + Extra) &
               "H845.2724s-225.272,467,-225.272,467s-235,486,-235,486c-2.7,4.7,-9,7,-19,7" &
               "c-6,0,-10,-1,-12,-3s-194,-422,-194,-422s-65,47,-65,47zM" &
               "834 80h400000v" & Image (40.0 + Extra) &
               "h-400000z");
         when 1 =>
            return Math_Paths.Parse
              ("M263," & Image (601.0 + Extra + 80.0) &
               "c0.7,0,18,39.7,52,119c34,79.3,68.167,158.7,102.5,238c34.3,79.3,51.8,119.3,52.5,120" &
               "c340,-704.7,510.7,-1060.3,512,-1067l" & Image (Extra / 2.084) & " -" & Image (Extra) &
               "c4.7,-7.3,11,-11,19,-11H" & Image (Edge) & "v" & Image (40.0 + Extra) &
               "H1012.3s-271.3,567,-271.3,567c-38.7,80.7,-84,175,-136,283c-52,108,-89.167,185.3,-111.5,232" &
               "c-22.3,46.7,-33.8,70.3,-34.5,71c-4.7,4.7,-12.3,7,-23,7s-12,-1,-12,-1" &
               "s-109,-253,-109,-253c-72.7,-168,-109.3,-252,-110,-252c-10.7,8,-22,16.7,-34,26" &
               "c-22,17.3,-33.3,26,-34,26s-26,-26,-26,-26s76,-59,76,-59s76,-60,76,-60zM" &
               Image (1001.0 + Extra) & " 80h" & Image (Edge) & "v" & Image (40.0 + Extra) &
               "h-" & Image (Edge) & "z");
         when 2 =>
            return Math_Paths.Parse
              ("M983 " & Image (10.0 + Extra + 80.0) & "l" & Image (Extra / 3.13) & " -" & Image (Extra) &
               "c4,-6.7,10,-10,18,-10H" & Image (Edge) & "v" & Image (40.0 + Extra) &
               "H1013.1s-83.4,268,-264.1,840c-180.7,572,-277,876.3,-289,913c-4.7,4.7,-12.7,7,-24,7" &
               "s-12,0,-12,0c-1.3,-3.3,-3.7,-11.7,-7,-25c-35.3,-125.3,-106.7,-373.3,-214,-744" &
               "c-10,12,-21,25,-33,39s-32,39,-32,39c-6,-5.3,-15,-14,-27,-26s25,-30,25,-30" &
               "c26.7,-32.7,52,-63,76,-91s52,-60,52,-60s208,722,208,722" &
               "c56,-175.3,126.3,-397.3,211,-666c84.7,-268.7,153.8,-488.2,207.5,-658.5" &
               "c53.7,-170.3,84.5,-266.8,92.5,-289.5zM" & Image (1001.0 + Extra) &
               " 80h" & Image (Edge) & "v" & Image (40.0 + Extra) & "h-" & Image (Edge) & "z");
         when 3 =>
            return Math_Paths.Parse
              ("M424," & Image (2398.0 + Extra + 80.0) &
               "c-1.3,-0.7,-38.5,-172,-111.5,-514c-73,-342,-109.8,-513.3,-110.5,-514" &
               "c0,-2,-10.7,14.3,-32,49c-4.7,7.3,-9.8,15.7,-15.5,25c-5.7,9.3,-9.8,16,-12.5,20" &
               "s-5,7,-5,7c-4,-3.3,-8.3,-7.7,-13,-13s-13,-13,-13,-13s76,-122,76,-122s77,-121,77,-121" &
               "s209,968,209,968c0,-2,84.7,-361.7,254,-1079c169.3,-717.3,254.7,-1077.7,256,-1081" &
               "l" & Image (Extra / 4.223) & " -" & Image (Extra) & "c4,-6.7,10,-10,18,-10H" & Image (Edge) &
               "v" & Image (40.0 + Extra) & "H1014.6s-87.3,378.7,-272.6,1166c-185.3,787.3,-279.3,1182.3,-282,1185" &
               "c-2,6,-10,9,-24,9c-8,0,-12,-0.7,-12,-2zM" & Image (1001.0 + Extra) &
               " 80h" & Image (Edge) & "v" & Image (40.0 + Extra) & "h-" & Image (Edge) & "z");
         when 4 =>
            return Math_Paths.Parse
              ("M473," & Image (2713.0 + Extra + 80.0) &
               "c339.3,-1799.3,509.3,-2700,510,-2702l" & Image (Extra / 5.298) & " -" & Image (Extra) &
               "c3.3,-7.3,9.3,-11,18,-11H" & Image (Edge) & "v" & Image (40.0 + Extra) & "H1017.7" &
               "s-90.5,478,-276.2,1466c-185.7,988,-279.5,1483,-281.5,1485c-2,6,-10,9,-24,9" &
               "c-8,0,-12,-0.7,-12,-2c0,-1.3,-5.3,-32,-16,-92c-50.7,-293.3,-119.7,-693.3,-207,-1200" &
               "c0,-1.3,-5.3,8.7,-16,30c-10.7,21.3,-21.3,42.7,-32,64s-16,33,-16,33s-26,-26,-26,-26" &
               "s76,-153,76,-153s77,-151,77,-151c0.7,0.7,35.7,202,105,604c67.3,400.7,102,602.7,104,606zM" &
               Image (1001.0 + Extra) & " 80h" & Image (Edge) & "v" & Image (40.0 + Extra) &
               "H1017.7z");
         when others =>
            return Math_Paths.Parse ("");
      end case;
   end Build;
end Math_Radical_Paths;
