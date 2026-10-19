with AUnit.Test_Caller;
--  Coyote_App.Frontend.GUI.Help_Tests body.
--
--  Project: coyote

with Ada.Characters.Handling;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Coyote_App.Frontend.GUI.Testing;
with Coyote_Config;
with Coyote_Help;
with Glib;
with Gtk.Bin;
with Gtk.Box;
with Gtk.Container;
with Gtk.Dialog;
with Gtk.Image;
with Gtk.Label;
with Gtk.Main;
with Gtk.Menu_Item;
with Gtk.Widget;
with Gtk.Window;

package body Coyote_App.Frontend.GUI.Help_Tests is

   use AUnit.Assertions;
   use Ada.Strings.Unbounded;
   use type Gtk.Dialog.Gtk_Dialog;
   use type Gtk.Image.Gtk_Image;
   use type Gtk.Menu_Item.Gtk_Menu_Item;
   use type Gtk.Widget.Gtk_Widget;
   use type Gtk.Window.Gtk_Window;

   overriding procedure Set_Up (T : in out Test) is
   begin
      if Ada.Environment_Variables.Exists ("DISPLAY")
        or else Ada.Environment_Variables.Exists ("WAYLAND_DISPLAY")
      then
         Gtk.Main.Init;
         T.Display_Available := True;
      end if;
   end Set_Up;

   overriding procedure Tear_Down (T : in out Test) is
      pragma Unreferenced (T);
   begin
      null;
   end Tear_Down;

   function Menu_Item_At
     (Menu  : Gtk.Widget.Gtk_Widget;
      Index : Natural) return Gtk.Menu_Item.Gtk_Menu_Item
   is
      Children : Gtk.Widget.Widget_List.Glist :=
        Gtk.Container.Get_Children
          (Gtk.Container.Gtk_Container (Menu));
      Child : constant Gtk.Widget.Gtk_Widget :=
        Gtk.Widget.Widget_List.Nth_Data
          (Children, Glib.Guint (Index));
   begin
      Gtk.Widget.Widget_List.Free (Children);
      return Gtk.Menu_Item.Gtk_Menu_Item (Child);
   end Menu_Item_At;

   function Menu_Length (Menu : Gtk.Widget.Gtk_Widget) return Natural is
      Children : Gtk.Widget.Widget_List.Glist :=
        Gtk.Container.Get_Children (Gtk.Container.Gtk_Container (Menu));
      Count : constant Natural :=
        Natural (Gtk.Widget.Widget_List.Length (Children));
   begin
      Gtk.Widget.Widget_List.Free (Children);
      return Count;
   end Menu_Length;

   procedure Assert_Menu_Item
     (Menu     : Gtk.Widget.Gtk_Widget;
      Index    : Natural;
      Label    : String;
      Mnemonic : Character)
   is
      Item  : constant Gtk.Menu_Item.Gtk_Menu_Item :=
        Menu_Item_At (Menu, Index);
      Child : constant Gtk.Widget.Gtk_Widget :=
        Gtk.Bin.Get_Child (Gtk.Bin.Gtk_Bin (Item));
   begin
      Assert (Item.Get_Label = Label, "Help item order/label: " & Label);
      Assert
        (Child /= null,
         "Help item has a real label widget: " & Label);
      Assert
        (Gtk.Label.Get_Mnemonic_Keyval (Gtk.Label.Gtk_Label (Child))
           = Glib.Guint
             (Character'Pos (Ada.Characters.Handling.To_Lower (Mnemonic))),
         "Help item mnemonic: " & Label);
   end Assert_Menu_Item;

   procedure Test_Help_Menu_And_Product_Information (T : in out Test) is
      Frontend      : Coyote_App.Frontend.GUI.Instance;
      Frontend_Made : Boolean := False;
      Main_Window   : Gtk.Window.Gtk_Window;
      Menu_Bar      : Gtk.Widget.Gtk_Widget;
      Help_Item     : Gtk.Menu_Item.Gtk_Menu_Item;
      Help_Menu     : Gtk.Widget.Gtk_Widget;
      Dialog        : Gtk.Dialog.Gtk_Dialog;
      Image         : Gtk.Image.Gtk_Image;
      Old_Path      : Unbounded_String;
      Had_Path      : Boolean := False;
      Path_Masked   : Boolean := False;

      procedure Restore_Path is
      begin
         if Path_Masked then
            if Had_Path then
               Ada.Environment_Variables.Set ("PATH", To_String (Old_Path));
            else
               Ada.Environment_Variables.Clear ("PATH");
            end if;
            Path_Masked := False;
         end if;
      end Restore_Path;

      procedure Cleanup is
      begin
         Restore_Path;
         if Dialog /= null then
            Dialog.Destroy;
            Dialog := null;
         end if;
         if Frontend_Made then
            Frontend.Request_Shutdown;
            if Main_Window /= null then
               Main_Window.Destroy;
               Main_Window := null;
            end if;
            Frontend_Made := False;
         end if;
      end Cleanup;
   begin
      if not T.Display_Available then
         return;
      end if;

      Had_Path := Ada.Environment_Variables.Exists ("PATH");
      if Had_Path then
         Old_Path := To_Unbounded_String
           (Ada.Environment_Variables.Value ("PATH"));
      end if;
      Ada.Environment_Variables.Set ("PATH", "/dev/null");
      Path_Masked := True;

      begin
         Assert (not Coyote_Help.Yelp_Available,
                 "controlled PATH hides Yelp from the application");
         Coyote_App.Frontend.GUI.Create
           (Frontend, "help menu test", Pop_Under => True);
         Frontend_Made := True;
         Main_Window := Coyote_App.Frontend.GUI.Testing.Main_Window (Frontend);

         Menu_Bar := Gtk.Box.Get_Child
           (Coyote_App.Frontend.GUI.Testing.Outer_Box (Frontend), 0);
         Assert (Menu_Bar.Get_Name = "coyote-help-menu",
                 "menu bar has its Help-area click mapping");
         Assert (Menu_Length (Menu_Bar) = 6,
                 "top-level menu order has six menus");
         Assert_Menu_Item (Menu_Bar, 0, "_File", 'F');
         Assert_Menu_Item (Menu_Bar, 1, "_Edit", 'E');
         Assert_Menu_Item (Menu_Bar, 2, "_View", 'V');
         Assert_Menu_Item (Menu_Bar, 3, "_Agent", 'A');
         Assert_Menu_Item (Menu_Bar, 4, "_Options", 'O');
         Assert_Menu_Item (Menu_Bar, 5, "_Help", 'H');

         Help_Item := Menu_Item_At (Menu_Bar, 5);
         Help_Menu := Gtk.Menu_Item.Get_Submenu (Help_Item);
         Assert (Help_Menu /= null, "Help top-level item has a submenu");
         Assert (Menu_Length (Help_Menu) = 8,
                 "Help submenu contains eight entries");
         Assert_Menu_Item
           (Help_Menu, 0, "_Click for Help", 'C');
         Assert_Menu_Item
           (Help_Menu, 1, "_Overview", 'O');
         Assert_Menu_Item
           (Help_Menu, 2, "_Send a Prompt", 'S');
         Assert_Menu_Item
           (Help_Menu, 3, "_Manage Sessions", 'M');
         Assert_Menu_Item
           (Help_Menu, 4, "_Agent Controls", 'A');
         Assert_Menu_Item
           (Help_Menu, 5, "_Index", 'I');
         Assert_Menu_Item
           (Help_Menu, 6, "_Keys & Shortcuts", 'K');
         Assert_Menu_Item
           (Help_Menu, 7, "_Product Information", 'P');

         Coyote_App.Frontend.GUI.Testing.Build_Product_Information
           (Frontend, Dialog, Image);
         Assert (Dialog /= null, "Product Information dialog is constructed");
         Assert
           (Dialog.Get_Title = "coyote : Product Information",
            "Product Information title is correct");
         Assert
           (Gtk.Window.Get_Transient_For (Gtk.Window.Gtk_Window (Dialog))
              = Main_Window,
            "Product Information is transient for the main window");
         Assert (Image /= null, "Product Information includes the icon");
         Assert
           (Gtk.Widget.Is_Visible (Gtk.Widget.Gtk_Widget (Image)),
            "Product Information icon is visible");
         declare
            Content : constant Gtk.Box.Gtk_Box :=
              Gtk.Dialog.Get_Content_Area (Dialog);
            Label_Widget : constant Gtk.Widget.Gtk_Widget :=
              Gtk.Box.Get_Child (Content, 1);
         begin
            Assert (Label_Widget /= null,
                    "Product Information contains its text label");
            declare
               Text : constant String :=
                 Gtk.Label.Get_Text (Gtk.Label.Gtk_Label (Label_Widget));
            begin
               Assert (Ada.Strings.Fixed.Index (Text, "coyote") > 0,
                       "Product Information label names the application");
               Assert
                 (Ada.Strings.Fixed.Index
                    (Text, Coyote_Config.Crate_Version) > 0,
                  "Product Information label includes the version");
               Assert
                 (Ada.Strings.Fixed.Index (Text, "License") > 0,
                  "Product Information label includes the license");
            end;
         end;
         Cleanup;
      exception
         when others =>
            Cleanup;
            raise;
      end;
   exception
      when others =>
         Cleanup;
         raise;
   end Test_Help_Menu_And_Product_Information;

   package Caller is new AUnit.Test_Caller (Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test
        (Caller.Create
           ("Coyote.GUI Help widgets without Yelp",
            Test_Help_Menu_And_Product_Information'Access));
      return Result;
   end Suite;

end Coyote_App.Frontend.GUI.Help_Tests;
