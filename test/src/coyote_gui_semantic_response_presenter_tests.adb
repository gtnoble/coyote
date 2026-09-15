--  Coyote_GUI_Semantic_Response_Presenter_Tests body.
--
--  Project: coyote

with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with AUnit.Assertions;
with AUnit.Test_Caller;
with Coyote_GUI.Response_Renderer;
with Coyote_GUI.Semantic_Response_Presenter;
with Coyote_Renderer.Incremental;
with Coyote_Renderer.Semantics;
with Glib;
with Gtk.Enums;
with Gtk.Main;
with Gtk.Text_Buffer;
with Gtk.Text_Attributes;
with Gtk.Text_Iter;
with Gtk.Text_Tag;
with Gtk.Text_View;
with Pango.Enums;
with Pango.Font;

package body Coyote_GUI_Semantic_Response_Presenter_Tests is

   use AUnit.Assertions;
   package P renames Coyote_GUI.Semantic_Response_Presenter;
   package I renames Coyote_Renderer.Incremental;
   package S renames Coyote_Renderer.Semantics;

   use type Gtk.Box.Gtk_Box;
   use type Gtk.Text_View.Gtk_Text_View;
   use type S.Block_Kind;
   use type Gtk.Text_Tag.Text_Tag_List.GSlist;
   use type Pango.Enums.Weight;
   use type Pango.Enums.Style;
   use type Glib.Guint;

   function Display_Available return Boolean is
   begin
      return Ada.Environment_Variables.Exists ("DISPLAY")
        or else Ada.Environment_Variables.Exists ("WAYLAND_DISPLAY");
   exception
      when others => return False;
   end Display_Available;

   function Has_Tag_At
     (Buffer : Gtk.Text_Buffer.Gtk_Text_Buffer;
      Offset : Glib.Gint) return Boolean is
      Iter : Gtk.Text_Iter.Gtk_Text_Iter;
      Tags : Gtk.Text_Tag.Text_Tag_List.GSlist;
   begin
      Buffer.Get_Iter_At_Offset (Iter, Offset);
      Tags := Gtk.Text_Iter.Get_Tags (Iter);
      declare
         Result : constant Boolean := Tags /= Gtk.Text_Tag.Text_Tag_List.Null_List;
      begin
         Gtk.Text_Tag.Text_Tag_List.Free (Tags);
         return Result;
      end;
   end Has_Tag_At;

   function Effective_Attributes_At
     (View : Gtk.Text_View.Gtk_Text_View;
      Offset : Glib.Gint) return Gtk.Text_Attributes.Gtk_Text_Attributes is
      Iter       : Gtk.Text_Iter.Gtk_Text_Iter;
      Attributes : aliased Gtk.Text_Attributes.Gtk_Text_Attributes :=
        View.Get_Default_Attributes;
   begin
      View.Get_Buffer.Get_Iter_At_Offset (Iter, Offset);
      Assert (Gtk.Text_Iter.Get_Attributes (Iter, Attributes'Access),
              "rendered offset has effective GTK text attributes");
      return Attributes;
   end Effective_Attributes_At;

   procedure Assert_Presented_Styles
     (Presenter : P.Instance) is
      Strong_View : constant Gtk.Text_View.Gtk_Text_View :=
        P.Text_View_At (Presenter, 1);
      Quote_View : constant Gtk.Text_View.Gtk_Text_View :=
        P.Text_View_At (Presenter, 2);
      List_View : constant Gtk.Text_View.Gtk_Text_View :=
        P.Text_View_At (Presenter, 3);
      Code_View : constant Gtk.Text_View.Gtk_Text_View :=
        P.Text_View_At (Presenter, 4);
      Strong_Attributes : Gtk.Text_Attributes.Gtk_Text_Attributes;
      Em_Attributes : Gtk.Text_Attributes.Gtk_Text_Attributes;
      Del_Attributes : Gtk.Text_Attributes.Gtk_Text_Attributes;
      Link_Attributes : Gtk.Text_Attributes.Gtk_Text_Attributes;
      Code_Inline_Attributes : Gtk.Text_Attributes.Gtk_Text_Attributes;
      Quote_Attributes : Gtk.Text_Attributes.Gtk_Text_Attributes;
      Code_Attributes : Gtk.Text_Attributes.Gtk_Text_Attributes;
   begin
      Strong_Attributes := Effective_Attributes_At (Strong_View, 4);
      Assert
        (Pango.Font.Get_Weight (Strong_Attributes.Font) =
           Pango.Enums.Pango_Weight_Bold,
         "strong text is effectively bold at its representative offset");
      Em_Attributes := Effective_Attributes_At (Strong_View, 9);
      Assert
        (Pango.Font.Get_Style (Em_Attributes.Font) =
           Pango.Enums.Pango_Style_Italic,
         "emphasis text is effectively italic at its representative offset");
      Del_Attributes := Effective_Attributes_At (Strong_View, 16);
      Assert
        (Del_Attributes.Appearance.Strikethrough /= 0,
         "deleted text is effectively struck through at its offset");
      Link_Attributes := Effective_Attributes_At (Strong_View, 22);
      Assert
        (Link_Attributes.Appearance.Underline /= 0,
         "link text is effectively underlined at its representative offset");
      Code_Inline_Attributes := Effective_Attributes_At (Strong_View, 29);
      Assert
        (Pango.Font.Get_Family (Code_Inline_Attributes.Font) = "Monospace",
         "inline code is effectively monospace at its representative offset");
      Quote_Attributes := Effective_Attributes_At (Quote_View, 2);
      Assert
        (Pango.Font.Get_Style (Quote_Attributes.Font) =
           Pango.Enums.Pango_Style_Italic,
         "blockquote text is effectively italic");
      Assert (Has_Tag_At (List_View.Get_Buffer, 0),
              "list text has a GTK tag at its representative offset");
      Code_Attributes := Effective_Attributes_At (Code_View, 0);
      Assert (Code_Attributes.Appearance.Draw_Bg /= 0,
              "code-block text has an effective GTK background");
      Assert (Has_Tag_At (Code_View.Get_Buffer, 0),
              "code-block text has a GTK tag at its representative offset");
   end Assert_Presented_Styles;

   overriding procedure Set_Up (T : in out Test) is
   begin
      if Display_Available then
         Gtk.Main.Init;
         T.Display_Available := True;
         Gtk.Window.Gtk_New (T.Parent, Gtk.Enums.Window_Toplevel);
         Gtk.Box.Gtk_New_Vbox (T.Host, Homogeneous => False, Spacing => 0);
         T.Parent.Add (T.Host);
      end if;
   end Set_Up;

   overriding procedure Tear_Down (T : in out Test) is
   begin
      if T.Display_Available then
         T.Parent.Destroy;
         T.Parent := null;
      end if;
   end Tear_Down;

   procedure Test_Text_Identity_Persists (T : in out Test) is
      Presenter : P.Instance;
      Parser    : I.Instance;
      Document  : S.Document;
      First     : Gtk.Text_View.Gtk_Text_View;
   begin
      if not T.Display_Available then
         return;
      end if;
      P.Create (Presenter, T.Host.all'Access);
      I.Feed (Parser, "<p>one ", I.Semantic_Handler'(null));
      I.Snapshot (Parser, Document);
      P.Reconcile (Presenter, Document);
      First := P.Text_View_At (Presenter, 1);
      I.Feed (Parser, "two</p>", I.Semantic_Handler'(null));
      I.Snapshot (Parser, Document);
      P.Reconcile (Presenter, Document);
      Assert (P.Text_View_At (Presenter, 1) = First,
              "text view identity persists across append reconciliation");
      I.Flush (Parser, I.Semantic_Handler'(null));
      I.Snapshot (Parser, Document);
      P.Reconcile (Presenter, Document);
      Assert (P.Text_View_At (Presenter, 1) = First,
              "text view identity persists through finish reconciliation");
      P.Clear (Presenter);
   end Test_Text_Identity_Persists;

   procedure Test_Native_Commit_Preserves_Neighbors (T : in out Test) is
      Presenter : P.Instance;
      Parser    : I.Instance;
      Document  : S.Document;
      Before       : Gtk.Box.Gtk_Box;
      Following    : Gtk.Box.Gtk_Box;
      Following_Id : Natural := 0;
   begin
      if not T.Display_Available then
         return;
      end if;
      P.Create (Presenter, T.Host.all'Access);
      I.Feed (Parser, "<p>before</p><p>after", I.Semantic_Handler'(null));
      I.Snapshot (Parser, Document);
      P.Reconcile (Presenter, Document);
      Before := P.Root_Outer (Presenter, 1);
      Following_Id := S.Block_Semantic_Root_Id
        (Document, S.Block_At (Document, 2));
      Following := P.Root_Outer (Presenter, Following_Id);
      I.Feed (Parser, " later</p>", I.Semantic_Handler'(null));
      I.Snapshot (Parser, Document);
      P.Reconcile (Presenter, Document);
      Assert (Before = P.Root_Outer (Presenter, 1),
              "preceding root outer identity survives later root mutation");
      Assert (Following = P.Root_Outer (Presenter, Following_Id),
              "following root outer identity survives its own mutation");
      P.Clear (Presenter);
   end Test_Native_Commit_Preserves_Neighbors;

   procedure Test_Semantic_Styles_And_Order (T : in out Test) is
      Presenter : P.Instance;
      Parser    : I.Instance;
      Document  : S.Document;
      Markup    : Unbounded_String;
   begin
      if not T.Display_Available then
         return;
      end if;
      P.Create (Presenter, T.Host.all'Access);
      I.Feed
        (Parser,
         "<p>one <strong>bold</strong> <em>italic</em> "
         & "<del>gone</del> <link url=""u"">link</link>"
         & "<code-inline>literal</code-inline></p>"
         & "<blockquote><p>quote</p></blockquote>"
         & "<list kind=""ordered"" start=""3""><item>first</item>"
         & "<item>second</item></list>"
         & "<code lang=""ada"">x &lt; y</code>",
         I.Semantic_Handler'(null));
      I.Snapshot (Parser, Document);
      for Position in 1 .. S.Block_Count (Document) loop
         Append (Markup,
           Coyote_GUI.Response_Renderer.Block_Markup
             (Document, S.Block_At (Document, Position)));
      end loop;
      P.Reconcile (Presenter, Document);
      Assert (P.Text_View_Count (Presenter) >= 3,
              "representative semantic styles render into GTK text buffers");
      Assert_Presented_Styles (Presenter);
      Assert (P.Has_Style (Document, P.Strong_Style),
              "semantic presenter recognizes strong style");
      Assert (P.Has_Style (Document, P.Em_Style),
              "semantic presenter recognizes emphasis style");
      Assert (P.Has_Style (Document, P.Del_Style),
              "semantic presenter recognizes deletion style");
      Assert (P.Has_Style (Document, P.Link_Style),
              "semantic presenter recognizes link style");
      Assert (P.Has_Style (Document, P.Inline_Code_Style),
              "semantic presenter recognizes inline code style");
      Assert (P.Has_Style (Document, P.Blockquote_Style),
              "semantic presenter recognizes blockquote style");
      Assert (P.Has_Style (Document, P.List_Style),
              "semantic presenter recognizes list style");
      Assert (P.Has_Style (Document, P.Code_Block_Style),
              "semantic presenter recognizes code block style");
      Assert (Ada.Strings.Fixed.Index (To_String (Markup), "one") <
                Ada.Strings.Fixed.Index (To_String (Markup), "quote"),
              "semantic presentation retains source order");
      Assert (Ada.Strings.Fixed.Index (To_String (Markup), "quote") <
                Ada.Strings.Fixed.Index (To_String (Markup), "first"),
              "blockquote precedes the following list");
      Assert (S.Block_Kind_Of (Document, S.Block_At (Document, 1)) = S.Paragraph
                and then S.Block_Kind_Of (Document, S.Block_At (Document, 2)) =
                  S.Blockquote
                and then S.Block_Kind_Of (Document, S.Block_At (Document, 3)) =
                  S.List
                and then S.Block_Kind_Of (Document, S.Block_At (Document, 4)) =
                  S.Code_Block,
              "semantic presentation retains block source order");
      P.Clear (Presenter);
   end Test_Semantic_Styles_And_Order;

   procedure Test_Localized_Invalid_Preserves_Roots (T : in out Test) is
      Presenter : P.Instance;
      Parser    : I.Instance;
      Document  : S.Document;
      Before    : Gtk.Box.Gtk_Box;
      After     : Gtk.Box.Gtk_Box;
   begin
      if not T.Display_Available then
         return;
      end if;
      P.Create (Presenter, T.Host.all'Access);
      I.Feed (Parser, "<p>before</p><p>bad <unknown>x</unknown></p>"
              & "<p>after</p>", I.Semantic_Handler'(null));
      I.Snapshot (Parser, Document);
      P.Reconcile (Presenter, Document);
      Before := P.Root_Outer (Presenter, 1);
      After := P.Root_Outer (Presenter, 3);
      I.Flush (Parser, I.Semantic_Handler'(null));
      I.Snapshot (Parser, Document);
      P.Reconcile (Presenter, Document);
      Assert (Before = P.Root_Outer (Presenter, 1),
              "preceding root survives localized malformed replacement");
      Assert (After = P.Root_Outer (Presenter, 3),
              "following root survives localized malformed replacement");
      declare
         View       : constant Gtk.Text_View.Gtk_Text_View :=
           P.Text_View_At (Presenter, 2);
         Buffer     : constant Gtk.Text_Buffer.Gtk_Text_Buffer :=
           View.Get_Buffer;
         Start_Iter : Gtk.Text_Iter.Gtk_Text_Iter;
         End_Iter   : Gtk.Text_Iter.Gtk_Text_Iter;
      begin
         Buffer.Get_Start_Iter (Start_Iter);
         Buffer.Get_End_Iter (End_Iter);
         Assert (Ada.Strings.Fixed.Index
                   (Buffer.Get_Text (Start_Iter, End_Iter), "<unknown>") > 0,
                 "localized invalid source remains selectable");
      end;
      P.Clear (Presenter);
   end Test_Localized_Invalid_Preserves_Roots;

   package Caller is new AUnit.Test_Caller (Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (Caller.Create
        ("semantic presenter text identity", Test_Text_Identity_Persists'Access));
      Result.Add_Test (Caller.Create
        ("semantic presenter native neighbors",
         Test_Native_Commit_Preserves_Neighbors'Access));
      Result.Add_Test (Caller.Create
        ("semantic presenter localized invalid",
         Test_Localized_Invalid_Preserves_Roots'Access));
      Result.Add_Test (Caller.Create
        ("semantic presenter semantic styles and order",
         Test_Semantic_Styles_And_Order'Access));
      return Result;
   end Suite;

end Coyote_GUI_Semantic_Response_Presenter_Tests;
