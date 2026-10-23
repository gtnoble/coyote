--  Locate installed native-math data without depending on the tool cwd.
package Coyote_Math_Resources is
   function Font_Directory return String;
   --  Resolve the application share directory; missing data is reported by
   --  the font loader and leaves the original formula visible.
end Coyote_Math_Resources;
