--  Static sqrtMain and sqrtSize1..4 paths from KaTeX 0.16.22.
--  Source: src/svgGeometry.js, SHA-256 e7bb196633f23cab95da9d010ffbbdad37d2c942c2f96a33f8094f260ecfd892.
--  Archive SHA-256: e9e0d167db3175481cbadaff38e8d90b130f6a3ddb451a47e43c577fd511f365.
--  Copyright (c) 2013-2020 Khan Academy and other contributors (MIT License).
with Math_Paths;

package Math_Radical_Paths is
   --  Size selects sqrtMain (0) or sqrtSize1..sqrtSize4 (1..4).
   --  Extra_Vinculum and Width are in ems; output uses SVG units.
   --  Width is validated but does not alter KaTeX's raw paths. Callers
   --  must clip drawing to their available horizontal extent.
   function Build
     (Size : Natural; Extra_Vinculum, Width : Long_Float)
      return Math_Paths.Path;
end Math_Radical_Paths;
