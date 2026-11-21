with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with LLM.User_Images;

package body Coyote_App.Frontend is
   procedure Begin_Image_Request
     (F : in out Instance; Text : String; Images : LLM.Types.User_Images.Vector) is
      Display : Unbounded_String := To_Unbounded_String (Text);
   begin
      for I in Images.First_Index .. Images.Last_Index loop
         if Length (Display) /= 0 then
            Append (Display, ASCII.LF);
         end if;
         Append (Display, LLM.User_Images.Marker (Images (I), I));
      end loop;
      Begin_Request (Instance'Class (F), To_String (Display));
   end Begin_Image_Request;

end Coyote_App.Frontend;
