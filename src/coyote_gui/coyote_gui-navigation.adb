--  Coyote_GUI.Navigation body.
--
--  Project: coyote

package body Coyote_GUI.Navigation is

   use type Glib.Gdouble;

   function Target_Value
     (Current   : Glib.Gdouble;
      Lower     : Glib.Gdouble;
      Upper     : Glib.Gdouble;
      Page_Size : Glib.Gdouble;
      Line_Size : Glib.Gdouble;
      Move      : Movement) return Glib.Gdouble
   is
      Maximum : constant Glib.Gdouble :=
        Glib.Gdouble'Max (Lower, Upper - Glib.Gdouble'Max (Page_Size, 0.0));
      Step : constant Glib.Gdouble := Glib.Gdouble'Max (Line_Size, 1.0);
      Value : Glib.Gdouble := Current;
   begin
      case Move is
         when Line_Up =>
            Value := Current - Step;
         when Line_Down =>
            Value := Current + Step;
         when Page_Up =>
            Value := Current - Glib.Gdouble'Max (Page_Size, Step);
         when Page_Down =>
            Value := Current + Glib.Gdouble'Max (Page_Size, Step);
         when To_Top =>
            Value := Lower;
         when To_Bottom =>
            Value := Maximum;
      end case;

      return Glib.Gdouble'Min (Maximum, Glib.Gdouble'Max (Lower, Value));
   end Target_Value;

end Coyote_GUI.Navigation;
