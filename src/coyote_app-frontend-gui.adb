--  Coyote_App.Frontend.GUI body.
--
--  Project: coyote

with Gdk.Event;
with Gdk.Types;
with Gdk.Types.Keysyms;
with Glib;                       use Glib;
with Glib.Main;
with Glib.Properties;            use Glib.Properties;
with Gtk.Box;
with Gtk.Button;
with Gtk.Enums;
with Gtk.Frame;
with Gtk.Label;
with Gtk.Main;
with Gtk.Menu;
with Gtk.Menu_Item;
with Gtk.Menu_Shell;
with Gtk.Scrolled_Window;
with Gtk.Separator_Menu_Item;
with Gtk.Text_Buffer;
with Gtk.Text_Iter;
with Gtk.Text_View;
with Gtk.Widget;
with Gtk.Window;
with Pango.Font;
with Ada.Directories;
with Glib.Values;
with Gtk.Cell_Renderer_Text;
with Gtk.Dialog;
with Gtk.List_Store;
with Gtk.Tree_Model;
with Gtk.Tree_Selection;
with Gtk.Tree_View;
with Gtk.Tree_View_Column;
with Session_Lister;
with LLM.Providers;
with Coyote_App.Utils;
with LLM.Model_Registry;

package body Coyote_App.Frontend.GUI is
   use Coyote_GUI.Prompt_Queue;

   --  ── Package-body state ────────────────────────────────────────────────

   --  Global access for signal callbacks (single window per process).
   Current_Frontend : access Instance := null;

   --  Prefix character used by menu-item handlers to pass commands through

   --  ── Show-detail secondary window ──────────────────────────────────────

   procedure Show_Text_Window (Title : String; Content : String) is
      use Gtk.Window;
      use Gtk.Scrolled_Window;
      use Gtk.Text_View;
      use Gtk.Text_Buffer;
      use Gtk.Text_Iter;

      Win    : Gtk_Window;
      Scroll : Gtk_Scrolled_Window;
      View   : Gtk_Text_View;
      Buf    : Gtk_Text_Buffer;
      Iter   : Gtk_Text_Iter;
   begin
      Gtk.Window.Gtk_New (Win, Gtk.Enums.Window_Toplevel);
      Win.Set_Title (Title);
      Win.Set_Default_Size (700, 500);

      Gtk.Scrolled_Window.Gtk_New (Scroll);
      Scroll.Set_Policy (Gtk.Enums.Policy_Automatic,
                         Gtk.Enums.Policy_Automatic);

      Gtk.Text_View.Gtk_New (View);
      View.Set_Editable (False);
      View.Set_Wrap_Mode (Gtk.Enums.Wrap_Word_Char);

      declare
         Font_Desc : Pango.Font.Pango_Font_Description :=
           Pango.Font.From_String ("monospace 10");
      begin
         View.Modify_Font (Font_Desc);
         Pango.Font.Free (Font_Desc);
      end;

      Buf := View.Get_Buffer;
      Buf.Get_End_Iter (Iter);
      Buf.Insert (Iter, Content);

      Scroll.Add (View);
      Win.Add (Scroll);
      Win.Show_All;
   end Show_Text_Window;

   --  ── Apply_Update — called on the GTK main thread by Drain_Idle ────────

   procedure Apply_Update (F : in out Instance; U : Coyote_GUI.Update) is
      use Coyote_GUI;
   begin
      case U.Kind is

         when Append_Text =>
            F.Buf.Append_Text (To_String (U.Text));
            F.Buf.Scroll_To_End;

         when End_Text_Block =>
            F.Buf.End_Text_Block;
            F.Buf.Scroll_To_End;

         when Begin_Thinking =>
            F.Buf.Begin_Thinking;

         when Append_Thinking =>
            F.Buf.Append_Thinking (To_String (U.Text));
            F.Buf.Scroll_To_End;

         when End_Thinking =>
            F.Buf.End_Thinking;

         when Begin_Tool =>
            F.Buf.Begin_Tool
              (Name       => To_String (U.Text),
               Args       => To_String (U.Text2),
               Session_Id => To_String (U.Text3),
               Tool_Id    => To_String (U.Text4));
            F.Buf.Scroll_To_End;

         when End_Tool =>
            F.Buf.End_Tool
              (Tool_Id => To_String (U.Text),
               Status  => Coyote_GUI.Tool_End_Status'Val
                            (Coyote_App.Frontend.Tool_End_Status'Pos
                               (Coyote_App.Frontend.Tool_End_Status'Val
                                  (Coyote_GUI.Tool_End_Status'Pos
                                     (U.T_Status)))),
               Result  => To_String (U.Text2));

         when Append_Notice =>
            F.Buf.Append_Notice
              (Kind => Coyote_GUI.Notice_Kind'Val
                         (Coyote_App.Frontend.Notice_Kind'Pos
                            (Coyote_App.Frontend.Notice_Kind'Val
                               (Coyote_GUI.Notice_Kind'Pos (U.N_Kind)))),
               Text => To_String (U.Text));
            F.Buf.Scroll_To_End;

         when Append_Turn_Footer =>
            F.Buf.Append_Turn_Footer (To_String (U.Text));
            F.Buf.Scroll_To_End;

         when Set_Status =>
            F.Status_Bar.Set_Text (To_String (U.Text));

         when Set_Mode =>
            declare
               Base  : constant String := To_String (F.Win_Name);
               Title : constant String :=
                 (case U.Mode is
                    when Coyote_GUI.Idle    => Base,
                    when Coyote_GUI.Running => Base & " -- running",
                    when Coyote_GUI.Armed   => Base & " -- armed",
                    when Coyote_GUI.Paused  => Base & " -- paused");
            begin
               F.Win.Set_Title (Title);
            end;

         when Show_Detail =>
            Show_Text_Window (To_String (U.Text), To_String (U.Text2));

         when Shutdown =>
            F.PQ.Shutdown;
            Gtk.Main.Main_Quit;

      end case;
   end Apply_Update;

   --  ── GLib idle drain callback ──────────────────────────────────────────

   function Drain_Idle return Boolean is
      U   : Coyote_GUI.Update;
      Got : Boolean;
   begin
      if Current_Frontend = null then
         return False;
      end if;
      loop
         Current_Frontend.Updates.Dequeue (U, Got);
         exit when not Got;
         Apply_Update (Current_Frontend.all, U);
      end loop;
      return True;
   end Drain_Idle;

   --  ── Signal handlers ───────────────────────────────────────────────────

   function On_Window_Delete
     (Self  : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event) return Boolean
   is
      pragma Unreferenced (Self, Event);
   begin
      if Current_Frontend /= null then
         Current_Frontend.PQ.Shutdown;
      end if;
      Gtk.Main.Main_Quit;
      return True;  --  suppress default handler (window destruction)
   end On_Window_Delete;

   procedure On_Send_Clicked
     (Self : access Gtk.Button.Gtk_Button_Record'Class)
   is
      pragma Unreferenced (Self);
      use Gtk.Text_Iter;
      SI, EI : Gtk_Text_Iter;
   begin
      if Current_Frontend = null then
         return;
      end if;
      Current_Frontend.Prompt_Buf.Get_Start_Iter (SI);
      Current_Frontend.Prompt_Buf.Get_End_Iter   (EI);
      declare
         Text : constant String :=
           Current_Frontend.Prompt_Buf.Get_Text (SI, EI);
      begin
         if Text'Length > 0 then
            Current_Frontend.PQ.Enqueue
              ((User_Prompt,
                Text => To_Unbounded_String (Text)));
            Current_Frontend.Prompt_Buf.Set_Text ("");
         end if;
      end;
   end On_Send_Clicked;

   function On_Prompt_Key_Press
     (Self  : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event_Key) return Boolean
   is
      pragma Unreferenced (Self);
      use type Gdk.Types.Gdk_Key_Type;
      use type Gdk.Types.Gdk_Modifier_Type;
   begin
      if (Event.Keyval = Gdk.Types.Keysyms.GDK_Return
            or else Event.Keyval = Gdk.Types.Keysyms.GDK_KP_Enter)
        and then (Event.State and Gdk.Types.Shift_Mask) = 0
      then
         On_Send_Clicked (null);
         return True;
      end if;
      return False;
   end On_Prompt_Key_Press;

   --  ── Menu item handlers ────────────────────────────────────────────────

   procedure On_New_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend /= null then
         Current_Frontend.PQ.Enqueue ((Kind => New_Window));
      end if;
   end On_New_Activate;

   procedure On_Quit_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend /= null then
         Current_Frontend.PQ.Shutdown;
      end if;
      Gtk.Main.Main_Quit;
   end On_Quit_Activate;

   procedure On_Stop_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend /= null then
         Current_Frontend.PQ.Enqueue ((Kind => Stop));
      end if;
   end On_Stop_Activate;

   procedure On_Pause_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend /= null then
         Current_Frontend.PQ.Enqueue ((Kind => Pause));
      end if;
   end On_Pause_Activate;

   procedure On_Resume_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend /= null then
         Current_Frontend.PQ.Enqueue ((Kind => Resume));
      end if;
   end On_Resume_Activate;

   procedure On_Compact_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend /= null then
         Current_Frontend.PQ.Enqueue ((Kind => Compact));
      end if;
   end On_Compact_Activate;

   procedure On_Stats_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend /= null then
         Show_Text_Window ("Session Stats",
                           To_String (Current_Frontend.Stats_Text));
      end if;
   end On_Stats_Activate;

   --  ── Open Session dialog ───────────────────────────────────────────────

   procedure On_Open_Session_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Self);
      use Gtk.Dialog;
      use Gtk.List_Store;
      use Gtk.Tree_Model;
      use Gtk.Tree_View;

      Sessions : Session_Lister.Session_Vectors.Vector;
      Store    : Gtk_List_Store;
      View     : Gtk_Tree_View;
      Scroll   : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Content  : Gtk.Box.Gtk_Box;
      Dialog   : Gtk_Dialog;
      Resp     : Gtk_Response_Type;
      Sel      : Gtk.Tree_Selection.Gtk_Tree_Selection;
      Model    : Gtk_Tree_Model;
      Iter     : Gtk_Tree_Iter;
      Val      : Glib.Values.GValue;
      Dummy    : Glib.Gint;
      pragma Unreferenced (Dummy);
      Btn     : Gtk.Widget.Gtk_Widget;
      pragma Unreferenced (Btn);

      --  ── Column helpers ──────────────────────────────────────────────
      procedure Add_Text_Column (Title : String; Col_Num : Glib.Gint) is
         Col      : Gtk.Tree_View_Column.Gtk_Tree_View_Column;
         Renderer : Gtk.Cell_Renderer_Text.Gtk_Cell_Renderer_Text;
      begin
         Gtk.Cell_Renderer_Text.Gtk_New (Renderer);
         Gtk.Tree_View_Column.Gtk_New (Col);
         Col.Set_Title (Title);
         Col.Pack_Start (Renderer, Expand => True);
         Col.Add_Attribute (Renderer, "text", Col_Num);
         Dummy := View.Append_Column (Col);
      end Add_Text_Column;

   begin
      if Current_Frontend = null then
         return;
      end if;

      Sessions := Session_Lister.List_Sessions
        (Ada.Directories.Current_Directory);

      --  Build the list store (col 0 = Name, 1 = Date, 2 = UUID hidden).
      Gtk.List_Store.Gtk_New
        (Store,
         (0 => Glib.GType_String,
          1 => Glib.GType_String,
          2 => Glib.GType_String));

      for S of Sessions loop
         declare
            Row : Gtk_Tree_Iter;
         begin
            Store.Append (Row);
            Store.Set (Row, 0,
                       Ada.Strings.Unbounded.To_String (S.Name));
            Store.Set (Row, 1,
                       Ada.Strings.Unbounded.To_String (S.Date));
            Store.Set (Row, 2,
                       Ada.Strings.Unbounded.To_String (S.UUID));
         end;
      end loop;

      Gtk.Tree_View.Gtk_New (View, +Store);
      Add_Text_Column ("Name", 0);
      Add_Text_Column ("Date", 1);

      Gtk.Scrolled_Window.Gtk_New (Scroll);
      Scroll.Set_Policy (Gtk.Enums.Policy_Automatic,
                         Gtk.Enums.Policy_Automatic);
      Scroll.Add (View);

      Gtk.Dialog.Gtk_New (Dialog);
      Dialog.Set_Title ("Open Session");
      Dialog.Set_Default_Size (620, 400);
      Dialog.Set_Transient_For (Current_Frontend.Win);
      Btn := Dialog.Add_Button ("_Cancel", Gtk_Response_Cancel);
      Btn := Dialog.Add_Button ("_Open",   Gtk_Response_OK);
      Dialog.Set_Default_Response (Gtk_Response_OK);

      Content := Dialog.Get_Content_Area;
      Content.Pack_Start (Scroll, Expand => True, Fill => True, Padding => 4);
      Dialog.Show_All;

      Resp := Dialog.Run;
      if Resp = Gtk_Response_OK then
         Sel := View.Get_Selection;
         Sel.Get_Selected (Model, Iter);
         if Iter /= Null_Iter then
            Gtk.Tree_Model.Get_Value (Model, Iter, 2, Val);
            declare
               UUID : constant String := Glib.Values.Get_String (Val);
            begin
               Glib.Values.Unset (Val);
               if UUID'Length > 0 then
                  Current_Frontend.PQ.Enqueue
                    ((Switch_Session,
                      Session_UUID => To_Unbounded_String (UUID)));
               end if;
            end;
         end if;
      end if;
      Dialog.Destroy;
   end On_Open_Session_Activate;

   --  ── Change Model dialog ───────────────────────────────────────────────

   procedure On_Change_Model_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Self);
      use Gtk.Dialog;
      use Gtk.List_Store;
      use Gtk.Tree_Model;
      use Gtk.Tree_View;

      Models  : constant LLM.Model_Registry.Model_Info_Vectors.Vector :=
                  LLM.Model_Registry.Available_Models;
      Store   : Gtk_List_Store;
      View    : Gtk_Tree_View;
      Scroll  : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Content : Gtk.Box.Gtk_Box;
      Dialog  : Gtk_Dialog;
      Resp    : Gtk_Response_Type;
      Sel     : Gtk.Tree_Selection.Gtk_Tree_Selection;
      Tmodel  : Gtk_Tree_Model;
      Iter    : Gtk_Tree_Iter;
      Val     : Glib.Values.GValue;
      Dummy   : Glib.Gint;
      pragma Unreferenced (Dummy);
      Btn     : Gtk.Widget.Gtk_Widget;
      pragma Unreferenced (Btn);

      --  Append one text column to View backed by Col_Num of Store.
      --  If Sort_Col >= 0 the column header becomes clickable for sorting.
      procedure Add_Text_Column
        (Title    : String;
         Col_Num  : Glib.Gint;
         Sort_Col : Glib.Gint := -1)
      is
         Col      : Gtk.Tree_View_Column.Gtk_Tree_View_Column;
         Renderer : Gtk.Cell_Renderer_Text.Gtk_Cell_Renderer_Text;
      begin
         Gtk.Cell_Renderer_Text.Gtk_New (Renderer);
         Gtk.Tree_View_Column.Gtk_New (Col);
         Col.Set_Title (Title);
         Col.Pack_Start (Renderer, Expand => True);
         Col.Add_Attribute (Renderer, "text", Col_Num);
         Col.Set_Resizable (True);
         if Sort_Col >= 0 then
            Col.Set_Sort_Column_Id (Sort_Col);
         end if;
         Dummy := View.Append_Column (Col);
      end Add_Text_Column;

      --  Convert a price (dollars per MTok) to a Gint sort key
      --  (micro-dollars per MTok).  Clamped to avoid Gint overflow.
      function Price_Sort (P : Long_Float) return Glib.Gint is
         Scale : constant Long_Float := 1.0e6;
         Max   : constant Long_Float := Long_Float (Glib.Gint'Last);
      begin
         if P <= 0.0 then
            return 0;
         elsif P * Scale >= Max then
            return Glib.Gint'Last;
         else
            return Glib.Gint (P * Scale);
         end if;
      end Price_Sort;

   begin
      if Current_Frontend = null then
         return;
      end if;

      --  Store columns: 0=Provider 1=Name 2=Context 3=In 4=Out 5=CR 6=CW
      --  (displayed strings); 7=Spec (hidden string);
      --  8=Ctx 9=In 10=Out 11=CR 12=CW (hidden Gint sort keys).
      Gtk.List_Store.Gtk_New
        (Store,
         (0  => Glib.GType_String,
          1  => Glib.GType_String,
          2  => Glib.GType_String,
          3  => Glib.GType_String,
          4  => Glib.GType_String,
          5  => Glib.GType_String,
          6  => Glib.GType_String,
          7  => Glib.GType_String,
          8  => Glib.GType_Int,
          9  => Glib.GType_Int,
          10 => Glib.GType_Int,
          11 => Glib.GType_Int,
          12 => Glib.GType_Int));

      for M of Models loop
         declare
            use Ada.Strings.Unbounded;
            Provider : constant String := To_String (M.Provider);
            Name     : constant String :=
              (if Length (M.Name) > 0
               then To_String (M.Name)
               else To_String (M.Model_Id));
            Ctx      : constant String :=
              Coyote_App.Utils.Format_SI_Count (M.Context_Window) & " ctx";
            In_P     : constant String :=
              Coyote_App.Utils.Format_SI_Price (M.Cost.Input);
            Out_P    : constant String :=
              Coyote_App.Utils.Format_SI_Price (M.Cost.Output);
            CR_P     : constant String :=
              Coyote_App.Utils.Format_SI_Price (M.Cost.Cache_Read);
            CW_P     : constant String :=
              Coyote_App.Utils.Format_SI_Price (M.Cost.Cache_Write);
            Spec     : constant String :=
              Provider & "/" & To_String (M.Model_Id);
            Row      : Gtk_Tree_Iter;
         begin
            Store.Append (Row);
            Store.Set (Row, 0,  Provider);
            Store.Set (Row, 1,  Name);
            Store.Set (Row, 2,  Ctx);
            Store.Set (Row, 3,  In_P);
            Store.Set (Row, 4,  Out_P);
            Store.Set (Row, 5,  CR_P);
            Store.Set (Row, 6,  CW_P);
            Store.Set (Row, 7,  Spec);
            Store.Set (Row, 8,  Glib.Gint (M.Context_Window));
            Store.Set (Row, 9,  Price_Sort (M.Cost.Input));
            Store.Set (Row, 10, Price_Sort (M.Cost.Output));
            Store.Set (Row, 11, Price_Sort (M.Cost.Cache_Read));
            Store.Set (Row, 12, Price_Sort (M.Cost.Cache_Write));
         end;
      end loop;

      --  Tree view: interactive typeahead search on the Name column.
      Gtk.Tree_View.Gtk_New (View, +Store);
      View.Set_Enable_Search (True);
      View.Set_Search_Column (1);
      Add_Text_Column ("Provider",   0, Sort_Col => 0);
      Add_Text_Column ("Name",       1, Sort_Col => 1);
      Add_Text_Column ("Context",    2, Sort_Col => 8);
      Add_Text_Column ("In $/MTok",  3, Sort_Col => 9);
      Add_Text_Column ("Out $/MTok", 4, Sort_Col => 10);
      Add_Text_Column ("CR $/MTok",  5, Sort_Col => 11);
      Add_Text_Column ("CW $/MTok",  6, Sort_Col => 12);

      Gtk.Scrolled_Window.Gtk_New (Scroll);
      Scroll.Set_Policy (Gtk.Enums.Policy_Automatic,
                         Gtk.Enums.Policy_Automatic);
      Scroll.Add (View);

      Gtk.Dialog.Gtk_New (Dialog);
      Dialog.Set_Title ("Select Model");
      Dialog.Set_Default_Size (1000, 520);
      Dialog.Set_Transient_For (Current_Frontend.Win);
      Btn := Dialog.Add_Button ("_Cancel", Gtk_Response_Cancel);
      Btn := Dialog.Add_Button ("_Select", Gtk_Response_OK);
      Dialog.Set_Default_Response (Gtk_Response_OK);

      Content := Dialog.Get_Content_Area;
      Content.Pack_Start (Scroll, Expand => True, Fill => True, Padding => 4);
      Dialog.Show_All;

      Resp := Dialog.Run;
      if Resp = Gtk_Response_OK then
         Sel := View.Get_Selection;
         Sel.Get_Selected (Tmodel, Iter);
         if Iter /= Null_Iter then
            Gtk.Tree_Model.Get_Value (Tmodel, Iter, 7, Val);
            declare
               use Ada.Strings.Unbounded;
               Spec : constant String := Glib.Values.Get_String (Val);
            begin
               Glib.Values.Unset (Val);
               if Spec'Length > 0 then
                  Current_Frontend.PQ.Enqueue
                    ((Set_Model,
                      Model_Spec => To_Unbounded_String (Spec)));
               end if;
            end;
         end if;
      end if;
      Dialog.Destroy;
   end On_Change_Model_Activate;

   --  ── Thinking level handlers ───────────────────────────────────────────

   procedure On_Thinking_Off_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend /= null then
         Current_Frontend.PQ.Enqueue
           ((Set_Thinking, Level => LLM.Providers.Off));
      end if;
   end On_Thinking_Off_Activate;

   procedure On_Thinking_Minimal_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend /= null then
         Current_Frontend.PQ.Enqueue
           ((Set_Thinking, Level => LLM.Providers.Minimal));
      end if;
   end On_Thinking_Minimal_Activate;

   procedure On_Thinking_Low_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend /= null then
         Current_Frontend.PQ.Enqueue
           ((Set_Thinking, Level => LLM.Providers.Low));
      end if;
   end On_Thinking_Low_Activate;

   procedure On_Thinking_Medium_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend /= null then
         Current_Frontend.PQ.Enqueue
           ((Set_Thinking, Level => LLM.Providers.Medium));
      end if;
   end On_Thinking_Medium_Activate;

   procedure On_Thinking_High_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend /= null then
         Current_Frontend.PQ.Enqueue
           ((Set_Thinking, Level => LLM.Providers.High));
      end if;
   end On_Thinking_High_Activate;

   procedure On_Thinking_X_High_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend /= null then
         Current_Frontend.PQ.Enqueue
           ((Set_Thinking, Level => LLM.Providers.X_High));
      end if;
   end On_Thinking_X_High_Activate;

   --  ── Menu construction helper ──────────────────────────────────────────

   function Make_Item
     (Label : String;
      Menu  : Gtk.Menu.Gtk_Menu)
      return Gtk.Menu_Item.Gtk_Menu_Item
   is
      Item : Gtk.Menu_Item.Gtk_Menu_Item;
   begin
      Gtk.Menu_Item.Gtk_New_With_Mnemonic (Item, Label);
      Gtk.Menu_Shell.Append (Gtk.Menu_Shell.Gtk_Menu_Shell (Menu), Item);
      return Item;
   end Make_Item;

   procedure Add_Sep (Menu : Gtk.Menu.Gtk_Menu) is
      Sep : Gtk.Separator_Menu_Item.Gtk_Separator_Menu_Item;
   begin
      Gtk.Separator_Menu_Item.Gtk_New (Sep);
      Gtk.Menu_Shell.Append
        (Gtk.Menu_Shell.Gtk_Menu_Shell (Menu), Sep);
   end Add_Sep;

   --  ── Create ────────────────────────────────────────────────────────────

   procedure Create (F : in out Instance; Win_Name : String) is
      use Gtk.Box;
      use Gtk.Button;
      use Gtk.Enums;
      use Gtk.Frame;
      use Gtk.Label;
      use Gtk.Menu;
      use Gtk.Menu_Bar;
      use Gtk.Menu_Item;
      use Gtk.Scrolled_Window;
      use Gtk.Text_Buffer;
      use Gtk.Text_View;
      use Gtk.Window;

      Prompt_Box : Gtk.Box.Gtk_Box;
      Bottom_Box : Gtk.Box.Gtk_Box;

      --  File menu
      File_Menu : Gtk_Menu;
      File_Item : Gtk_Menu_Item;
      Item      : Gtk_Menu_Item;

      --  Agent menu
      Agent_Menu : Gtk_Menu;
      Agent_Item : Gtk_Menu_Item;

      Idle_Id : Glib.Main.G_Source_Id;
      pragma Unreferenced (Idle_Id);
   begin
      F.Win_Name := To_Unbounded_String (Win_Name);
      Current_Frontend := F'Unchecked_Access;

      --  Top-level window
      Gtk.Window.Gtk_New (F.Win, Window_Toplevel);
      F.Win.Set_Title (Win_Name);
      F.Win.Set_Default_Size (900, 700);
      F.Win.On_Delete_Event (On_Window_Delete'Access);

      --  Outer vertical box
      Gtk.Box.Gtk_New_Vbox (F.Outer_Box, Homogeneous => False, Spacing => 0);
      F.Win.Add (F.Outer_Box);

      --  ── Menu bar ──────────────────────────────────────────────────────

      Gtk.Menu_Bar.Gtk_New (F.Menu_Bar);
      F.Outer_Box.Pack_Start (F.Menu_Bar, Expand => False, Fill => False,
                              Padding => 0);

      --  File menu
      Gtk.Menu.Gtk_New (File_Menu);
      Gtk.Menu_Item.Gtk_New_With_Mnemonic (File_Item, "_File");
      File_Item.Set_Submenu (File_Menu);
      Gtk.Menu_Shell.Append
        (Gtk.Menu_Shell.Gtk_Menu_Shell (F.Menu_Bar), File_Item);

      Item := Make_Item ("_New Window", File_Menu);
      Item.On_Activate (On_New_Activate'Access);
      Item := Make_Item ("Open _Session...", File_Menu);
      Item.On_Activate (On_Open_Session_Activate'Access);
      Add_Sep (File_Menu);
      Item := Make_Item ("_Quit", File_Menu);
      Item.On_Activate (On_Quit_Activate'Access);

      --  Agent menu
      Gtk.Menu.Gtk_New (Agent_Menu);
      Gtk.Menu_Item.Gtk_New_With_Mnemonic (Agent_Item, "_Agent");
      Agent_Item.Set_Submenu (Agent_Menu);
      Gtk.Menu_Shell.Append
        (Gtk.Menu_Shell.Gtk_Menu_Shell (F.Menu_Bar), Agent_Item);

      Item := Make_Item ("_Stop", Agent_Menu);
      Item.On_Activate (On_Stop_Activate'Access);
      Item := Make_Item ("_Pause", Agent_Menu);
      Item.On_Activate (On_Pause_Activate'Access);
      Item := Make_Item ("_Resume", Agent_Menu);
      Item.On_Activate (On_Resume_Activate'Access);
      Add_Sep (Agent_Menu);
      Item := Make_Item ("Change _Model...", Agent_Menu);
      Item.On_Activate (On_Change_Model_Activate'Access);
      declare
         Thinking_Menu : Gtk.Menu.Gtk_Menu;
         Thinking_Head : Gtk.Menu_Item.Gtk_Menu_Item;
      begin
         Gtk.Menu.Gtk_New (Thinking_Menu);
         Gtk.Menu_Item.Gtk_New_With_Mnemonic
           (Thinking_Head, "_Thinking Level");
         Thinking_Head.Set_Submenu (Thinking_Menu);
         Gtk.Menu_Shell.Append
           (Gtk.Menu_Shell.Gtk_Menu_Shell (Agent_Menu), Thinking_Head);
         Item := Make_Item ("_Off",     Thinking_Menu);
         Item.On_Activate (On_Thinking_Off_Activate'Access);
         Item := Make_Item ("M_inimal", Thinking_Menu);
         Item.On_Activate (On_Thinking_Minimal_Activate'Access);
         Item := Make_Item ("_Low",     Thinking_Menu);
         Item.On_Activate (On_Thinking_Low_Activate'Access);
         Item := Make_Item ("M_edium",  Thinking_Menu);
         Item.On_Activate (On_Thinking_Medium_Activate'Access);
         Item := Make_Item ("_High",    Thinking_Menu);
         Item.On_Activate (On_Thinking_High_Activate'Access);
         Item := Make_Item ("_X-High",  Thinking_Menu);
         Item.On_Activate (On_Thinking_X_High_Activate'Access);
      end;
      Add_Sep (Agent_Menu);
      Item := Make_Item ("_Compact Context", Agent_Menu);
      Item.On_Activate (On_Compact_Activate'Access);
      Add_Sep (Agent_Menu);
      Item := Make_Item ("Session _Stats", Agent_Menu);
      Item.On_Activate (On_Stats_Activate'Access);

      --  ── Conversation view ─────────────────────────────────────────────

      Gtk.Scrolled_Window.Gtk_New (F.Conv_Scroll);
      F.Conv_Scroll.Set_Policy (Policy_Automatic, Policy_Automatic);

      Gtk.Text_View.Gtk_New (F.Conv_View);
      F.Conv_View.Set_Editable (False);
      F.Conv_View.Set_Cursor_Visible (False);
      F.Conv_View.Set_Wrap_Mode (Wrap_Word_Char);
      F.Conv_View.Set_Left_Margin (8);
      F.Conv_View.Set_Right_Margin (8);
      F.Conv_View.Set_Top_Margin (6);
      F.Conv_View.Set_Bottom_Margin (6);

      F.Conv_Buf := F.Conv_View.Get_Buffer;
      F.Buf.Attach (F.Conv_View, F.Conv_Buf);

      F.Conv_Scroll.Add (F.Conv_View);
      F.Outer_Box.Pack_Start (F.Conv_Scroll, Expand => True, Fill => True,
                              Padding => 0);

      --  ── Prompt area ───────────────────────────────────────────────────

      Gtk.Box.Gtk_New_Vbox (Prompt_Box, Homogeneous => False, Spacing => 2);

      Gtk.Scrolled_Window.Gtk_New (F.Prompt_Scroll);
      F.Prompt_Scroll.Set_Policy (Policy_Never, Policy_Automatic);
      F.Prompt_Scroll.Set_Min_Content_Height (24);
      F.Prompt_Scroll.Set_Max_Content_Height (120);

      Gtk.Text_View.Gtk_New (F.Prompt_View);
      F.Prompt_View.Set_Wrap_Mode (Wrap_Word_Char);
      F.Prompt_View.Set_Left_Margin (4);
      F.Prompt_View.Set_Right_Margin (4);
      F.Prompt_View.On_Key_Press_Event (On_Prompt_Key_Press'Access);

      F.Prompt_Buf := F.Prompt_View.Get_Buffer;

      F.Prompt_Scroll.Add (F.Prompt_View);

      Gtk.Box.Gtk_New_Hbox (Bottom_Box, Homogeneous => False, Spacing => 4);
      Bottom_Box.Pack_Start (F.Prompt_Scroll, Expand => True, Fill => True,
                             Padding => 2);

      Gtk.Button.Gtk_New (F.Send_Btn, "Send");
      F.Send_Btn.On_Clicked (On_Send_Clicked'Access);
      Bottom_Box.Pack_Start (F.Send_Btn, Expand => False, Fill => False,
                             Padding => 2);

      Prompt_Box.Pack_Start (Bottom_Box, Expand => True, Fill => True,
                             Padding => 0);
      F.Outer_Box.Pack_Start (Prompt_Box, Expand => False, Fill => False,
                              Padding => 2);

      --  ── Status bar ────────────────────────────────────────────────────

      Gtk.Label.Gtk_New (F.Status_Bar, "");
      F.Status_Bar.Set_Xalign (0.0);

      declare
         Font_Desc : Pango.Font.Pango_Font_Description :=
           Pango.Font.From_String ("9");
      begin
         F.Status_Bar.Modify_Font (Font_Desc);
         Pango.Font.Free (Font_Desc);
      end;

      F.Outer_Box.Pack_Start (F.Status_Bar, Expand => False, Fill => False,
                              Padding => 2);

      --  ── Show and register idle drain ──────────────────────────────────

      F.Win.Show_All;

      Idle_Id := Glib.Main.Idle_Add (Drain_Idle'Access);
   end Create;

   --  ── Frontend.Instance overrides ───────────────────────────────────────

   overriding
   procedure Set_Status (F : in out Instance; Text : in String) is
      U : Coyote_GUI.Update;
   begin
      U.Kind := Coyote_GUI.Set_Status;
      U.Text := To_Unbounded_String (Text);
      F.Updates.Enqueue (U);
   end Set_Status;

   overriding
   procedure Set_Mode (F : in out Instance; Mode : in Run_Mode) is
      U : Coyote_GUI.Update;
   begin
      U.Kind := Coyote_GUI.Set_Mode;
      U.Mode := Coyote_GUI.Run_Mode'Val (Run_Mode'Pos (Mode));
      F.Updates.Enqueue (U);
   end Set_Mode;

   overriding
   procedure Append_Text (F : in out Instance; Text : in String) is
      U : Coyote_GUI.Update;
   begin
      U.Kind := Coyote_GUI.Append_Text;
      U.Text := To_Unbounded_String (Text);
      F.Updates.Enqueue (U);
   end Append_Text;

   overriding
   procedure End_Text_Block (F : in out Instance) is
      U : Coyote_GUI.Update;
   begin
      U.Kind := Coyote_GUI.End_Text_Block;
      F.Updates.Enqueue (U);
   end End_Text_Block;

   overriding
   procedure Begin_Thinking (F : in out Instance) is
      U : Coyote_GUI.Update;
   begin
      U.Kind := Coyote_GUI.Begin_Thinking;
      F.Updates.Enqueue (U);
   end Begin_Thinking;

   overriding
   procedure Append_Thinking (F : in out Instance; Text : in String) is
      U : Coyote_GUI.Update;
   begin
      U.Kind := Coyote_GUI.Append_Thinking;
      U.Text := To_Unbounded_String (Text);
      F.Updates.Enqueue (U);
   end Append_Thinking;

   overriding
   procedure End_Thinking (F : in out Instance) is
      U : Coyote_GUI.Update;
   begin
      U.Kind := Coyote_GUI.End_Thinking;
      F.Updates.Enqueue (U);
   end End_Thinking;

   overriding
   procedure Begin_Tool
     (F          : in out Instance;
      Name       : in     String;
      Args_Json  : in     String;
      Session_Id : in     String;
      Tool_Id    : in     String)
   is
      U : Coyote_GUI.Update;
   begin
      U.Kind  := Coyote_GUI.Begin_Tool;
      U.Text  := To_Unbounded_String (Name);
      U.Text2 := To_Unbounded_String (Args_Json);
      U.Text3 := To_Unbounded_String (Session_Id);
      U.Text4 := To_Unbounded_String (Tool_Id);
      F.Updates.Enqueue (U);
   end Begin_Tool;

   overriding
   procedure End_Tool
     (F           : in out Instance;
      Tool_Id     : in     String;
      Status      : in     Tool_End_Status;
      Result_Text : in     String := "")
   is
      U : Coyote_GUI.Update;
   begin
      U.Kind     := Coyote_GUI.End_Tool;
      U.Text     := To_Unbounded_String (Tool_Id);
      U.Text2    := To_Unbounded_String (Result_Text);
      U.T_Status :=
        Coyote_GUI.Tool_End_Status'Val (Tool_End_Status'Pos (Status));
      F.Updates.Enqueue (U);
   end End_Tool;

   overriding
   procedure Append_Turn_Footer (F : in out Instance; Text : in String) is
      U : Coyote_GUI.Update;
   begin
      U.Kind := Coyote_GUI.Append_Turn_Footer;
      U.Text := To_Unbounded_String (Text);
      F.Updates.Enqueue (U);
   end Append_Turn_Footer;

   overriding
   procedure Append_Notice
     (F    : in out Instance;
      Kind : in     Notice_Kind;
      Text : in     String)
   is
      U : Coyote_GUI.Update;
   begin
      U.Kind   := Coyote_GUI.Append_Notice;
      U.Text   := To_Unbounded_String (Text);
      U.N_Kind :=
        Coyote_GUI.Notice_Kind'Val (Notice_Kind'Pos (Kind));
      F.Updates.Enqueue (U);
   end Append_Notice;

   overriding
   procedure Show_Detail
     (F       : in out Instance;
      Title   : in     String;
      Content : in     String)
   is
      U : Coyote_GUI.Update;
   begin
      U.Kind  := Coyote_GUI.Show_Detail;
      U.Text  := To_Unbounded_String (Title);
      U.Text2 := To_Unbounded_String (Content);
      F.Updates.Enqueue (U);
   end Show_Detail;

   function Read_Item (F : in out Instance)
     return Coyote_GUI.Prompt_Queue.Item
   is
      Result : Coyote_GUI.Prompt_Queue.Item;
   begin
      F.PQ.Dequeue (Result);
      return Result;
   end Read_Item;

   overriding
   function Read_Prompt (F : in out Instance) return String is
      It : constant Coyote_GUI.Prompt_Queue.Item := Read_Item (F);
   begin
      case It.Kind is
         when User_Prompt  =>
            return Ada.Strings.Unbounded.To_String (It.Text);
         when Shutdown_Item =>
            return "";
         when others =>
            --  Commands are not representable as plain strings;
            --  callers in the GUI path should use Read_Item instead.
            return "";
      end case;
   end Read_Prompt;

   overriding
   procedure Shutdown (F : in out Instance) is
      U : Coyote_GUI.Update;
   begin
      U.Kind := Coyote_GUI.Shutdown;
      F.Updates.Enqueue (U);
   end Shutdown;

   --  ── GUI-specific ──────────────────────────────────────────────────────

   procedure Set_Stats_Summary (F : in out Instance; Text : String) is
   begin
      F.Stats_Text := To_Unbounded_String (Text);
   end Set_Stats_Summary;

   function Stats_Summary_Text (F : Instance) return String is
   begin
      return To_String (F.Stats_Text);
   end Stats_Summary_Text;

end Coyote_App.Frontend.GUI;
