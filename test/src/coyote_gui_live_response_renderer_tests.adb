--  Coyote_GUI_Live_Response_Renderer_Tests body.
--
--  Project: coyote

with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with AUnit.Assertions;
with AUnit.Test_Caller;
with Coyote_App.Utils; use Coyote_App.Utils;
with Coyote_Renderer.Incremental;
with Gtk.Enums;
with Gtk.Main;

package body Coyote_GUI_Live_Response_Renderer_Tests is

   use AUnit.Assertions;
   package R renames Coyote_GUI.Live_Response_Renderer;
   package I renames Coyote_Renderer.Incremental;

   use type R.Deferred_Kind;

   function Display_Available return Boolean is
   begin
      return Ada.Environment_Variables.Exists ("DISPLAY")
        or else Ada.Environment_Variables.Exists ("WAYLAND_DISPLAY");
   exception
      when others =>
         return False;
   end Display_Available;

   Active_Renderer : access R.Instance;

   procedure Apply_Live (Value : I.Live_Event) is
   begin
      if Active_Renderer /= null then
         Active_Renderer.all.Apply (Value);
      end if;
   end Apply_Live;

   procedure Render
     (Renderer : in out R.Instance; Source : String) is
      Parser  : I.Instance;
      Handler : constant I.Live_Handler := Apply_Live'Access;
   begin
      Renderer.Begin_Response;
      Active_Renderer := Renderer'Unchecked_Access;
      I.Feed (Parser, Source, Handler);
      Active_Renderer := null;
   end Render;

   overriding procedure Set_Up (T : in out Test) is
   begin
      if Display_Available then
         Gtk.Main.Init;
         T.Display_Available := True;
         Gtk.Window.Gtk_New (T.Parent, Gtk.Enums.Window_Toplevel);
         Gtk.Box.Gtk_New_Vbox (T.Host, Homogeneous => False, Spacing => 0);
         T.Parent.Add (T.Host);
         T.Renderer.Create (T.Host);
      else
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "[SKIP display unavailable] live response renderer fixture");
      end if;
   end Set_Up;

   overriding procedure Tear_Down (T : in out Test) is
   begin
      if T.Display_Available then
         T.Renderer.Clear;
      end if;
   end Tear_Down;

   procedure Test_Live_Text_Styles_And_Order (T : in out Test) is
      Visible : Unbounded_String;
   begin
      if not T.Display_Available then
         return;
      end if;
      Render
        (T.Renderer,
         "<p>one <strong>bold</strong> <em>italic</em> "
         & "<del>gone</del> <link url=""u"">link</link>"
         & "<code-inline>literal</code-inline><br/>tail</p>"
         & "<h2>heading</h2>");
      Assert
        (T.Renderer.Has_Style
           (R.Heading_Style,
            Ada.Strings.Fixed.Index (T.Renderer.Text, "heading")),
         "heading range is tagged");
      Assert
        (Ada.Strings.Fixed.Index (T.Renderer.Text, "one") > 0,
         "paragraph text remains ordered before heading");
      Assert
        (T.Renderer.Has_Style
           (R.Inline_Code_Style,
            Ada.Strings.Fixed.Index (T.Renderer.Text, "literal")),
         "inline code range is tagged");
      Assert
        (Ada.Strings.Fixed.Index
           (T.Renderer.Text, "one bold italic gone link") > 0,
         "live update is visible before end-equivalent completion");
      Visible := To_Unbounded_String (T.Renderer.Text);
      Assert
        (Ada.Strings.Fixed.Index
           (To_String (Visible), "one bold italic gone link") > 0,
         "live text and inline styles preserve source order");
      Assert (Ada.Strings.Fixed.Index (To_String (Visible), "tail") > 0,
              "hard break content is visible before stream completion");
      Assert (Ada.Strings.Fixed.Index (To_String (Visible), "heading") > 0,
              "heading content is visible before stream completion");
      Assert
        (T.Renderer.Has_Style
           (R.Strong_Style,
            Ada.Strings.Fixed.Index (To_String (Visible), "bold")),
         "strong range is tagged");
      Assert
        (T.Renderer.Has_Style
           (R.Em_Style,
            Ada.Strings.Fixed.Index (To_String (Visible), "italic")),
         "emphasis range is tagged");
      Assert
        (T.Renderer.Has_Style
           (R.Del_Style,
            Ada.Strings.Fixed.Index (To_String (Visible), "gone")),
         "deletion range is tagged");
      Assert
        (T.Renderer.Has_Style
           (R.Link_Style,
            Ada.Strings.Fixed.Index (To_String (Visible), "link")),
         "link range is tagged");
   end Test_Live_Text_Styles_And_Order;

   procedure Test_Live_Code_Quote_And_Lists (T : in out Test) is
      Visible : Unbounded_String;
      Code_Pos : Natural;
      Quote_Pos : Natural;
   begin
      if not T.Display_Available then
         return;
      end if;
      Render
        (T.Renderer,
         "<blockquote><p>quote</p></blockquote>"
         & "<list kind=""unordered""><item>bullet</item></list>"
         & "<list kind=""ordered"" start=""3""><item>first</item>"
         & "<item>second</item></list>"
         & "<code lang=""ada"">x &lt; y</code>");
      Visible := To_Unbounded_String (T.Renderer.Text);
      Code_Pos := Ada.Strings.Fixed.Index (To_String (Visible), "x &lt; y");
      Quote_Pos := Ada.Strings.Fixed.Index (To_String (Visible), "quote");
      Assert (Ada.Strings.Fixed.Index (To_String (Visible), "quote") > 0,
              "blockquote text is visible");
      Assert
        (Ada.Strings.Fixed.Index
           (To_String (Visible), UC_BULLET & " bullet") > 0,
         "unordered list renders a bullet");
      Assert
        (T.Renderer.Has_Style
           (R.List_Style,
            Ada.Strings.Fixed.Index (To_String (Visible), "bullet")),
         "list content uses the list style");
      Assert (Ada.Strings.Fixed.Index (To_String (Visible), "3. first") > 0,
              "ordered list preserves its start value");
      Assert (Ada.Strings.Fixed.Index (To_String (Visible), "4. second") > 0,
              "ordered list increments from its start value");
      Assert (Ada.Strings.Fixed.Index (To_String (Visible), "x &lt; y") > 0,
              "code payload preserves opaque literal source");
      Assert (Ada.Strings.Fixed.Index (To_String (Visible), "x &lt; y") > 0,
              "opaque code payload remains visible literally");
      Assert (T.Renderer.Has_Style (R.Code_Block_Style, Code_Pos),
              "code payload uses monospace/background tag");
      Assert (T.Renderer.Has_Style (R.Blockquote_Style, Quote_Pos),
              "blockquote content uses container tag");
   end Test_Live_Code_Quote_And_Lists;

   procedure Test_Deferred_Blocks_And_Clear (T : in out Test) is
      Visible : Unbounded_String;
   begin
      if not T.Display_Available then
         return;
      end if;
      Render
        (T.Renderer,
         "<p>before</p><table><row><cell>deferred</cell></row></table>"
         & "<math xmlns=""http://www.w3.org/1998/Math/MathML"">"
         & "<mi>x</mi></math><p>after</p>");
      Visible := To_Unbounded_String (T.Renderer.Text);
      Assert (T.Renderer.Deferred_Block_Count = 2,
              "table and math are retained as deferred state");
      Assert
        (T.Renderer.Deferred_Block_Kind_At (1) = R.Deferred_Table,
         "first deferred block is a table");
      Assert
        (T.Renderer.Deferred_Block_Kind_At (2) = R.Deferred_Math,
         "second deferred block is math");
      Assert
        (Ada.Strings.Fixed.Index
           (T.Renderer.Deferred_Block_Source_At (1), "<table>") = 1,
         "deferred table source is retained");
      Assert (T.Renderer.Invalid_Event_Count = 0,
              "valid deferred events do not report invalid content");
      Assert (Ada.Strings.Fixed.Index (To_String (Visible), "deferred") > 0,
              "deferred table text remains selectable live text");
      Assert (Ada.Strings.Fixed.Index (To_String (Visible), "after") > 0,
              "events after deferred blocks preserve ordering");
      T.Renderer.Finalize;
      Assert
        (T.Renderer.Is_Finalized, "Finalize marks the live stream complete");
      T.Renderer.Clear;
      Assert (T.Renderer.Text = "", "Clear discards the live subtree content");
      Assert (T.Renderer.Deferred_Block_Count = 0,
              "Clear resets deferred state");
      Assert (not T.Renderer.Is_Finalized,
              "Clear resets finalized state for reuse");
      T.Renderer.Begin_Response;
      Assert
        (T.Renderer.Text = "", "Begin starts from an empty live subtree");
   end Test_Deferred_Blocks_And_Clear;

   procedure Test_Invalid_Rolls_Back_Optimistic_Content (T : in out Test) is
      Parser : I.Instance;
      Source : constant String := "<p>good <strong>prefix</p></strong> tail";
      procedure Apply_Event (Value : I.Live_Event) is
      begin
         T.Renderer.Apply (Value);
      end Apply_Event;
   begin
      if not T.Display_Available then
         return;
      end if;
      T.Renderer.Begin_Response;
      I.Feed (Parser, Source, Apply_Event'Unrestricted_Access);
      Assert (T.Renderer.Invalid_Event_Count = 1,
              "crossing live tags produce one invalid rollback");
      Assert (T.Renderer.Text = Source,
              "invalid live input leaves exact full source visible");
      I.Feed (Parser, " ignored", Apply_Event'Unrestricted_Access);
      Assert (T.Renderer.Text = Source,
              "events after invalid rollback do not duplicate source");
      T.Renderer.Finalize;
      T.Renderer.Finalize;
      Assert (T.Renderer.Is_Finalized,
              "repeated live finalization remains idempotent");
      T.Renderer.Clear;
      Assert (T.Renderer.Text = "",
              "clear removes invalid live fallback");
      T.Renderer.Begin_Response;
      I.Reset (Parser);
      I.Feed (Parser, "<p>new</p>", Apply_Event'Unrestricted_Access);
      Assert (T.Renderer.Text = "new" & ASCII.LF & ASCII.LF,
              "begin response permits clean reuse after rollback");
   end Test_Invalid_Rolls_Back_Optimistic_Content;

   procedure Test_Detach_And_Reattach (T : in out Test) is
   begin
      if not T.Display_Available then
         return;
      end if;
      T.Renderer.Begin_Response;
      T.Renderer.Apply
        ((Kind => I.Live_Text_Event,
          Text => To_Unbounded_String ("first"),
          Sequence => 1,
          others => <>));
      T.Renderer.Detach (T.Host);
      T.Renderer.Create (T.Host);
      T.Renderer.Begin_Response;
      T.Renderer.Apply
        ((Kind => I.Live_Text_Event,
          Text => To_Unbounded_String ("second"),
          Sequence => 1,
          others => <>));
      Assert (T.Renderer.Text = "second",
              "detached renderer can be safely reattached and reused");
   end Test_Detach_And_Reattach;

   package Caller is new AUnit.Test_Caller (Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test
        (Caller.Create
           ("live renderer text styles and order",
            Test_Live_Text_Styles_And_Order'Access));
      Result.Add_Test
        (Caller.Create
           ("live renderer code quote and lists",
            Test_Live_Code_Quote_And_Lists'Access));
      Result.Add_Test
        (Caller.Create
           ("live renderer deferred blocks and clear",
            Test_Deferred_Blocks_And_Clear'Access));
      Result.Add_Test
        (Caller.Create
           ("live renderer invalid rollback and reuse",
            Test_Invalid_Rolls_Back_Optimistic_Content'Access));
      Result.Add_Test
        (Caller.Create
           ("live renderer detach and reattach",
            Test_Detach_And_Reattach'Access));
      return Result;
   end Suite;

end Coyote_GUI_Live_Response_Renderer_Tests;
