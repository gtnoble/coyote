--  Coyote_Notify body.
--
--  Project: coyote

with Interfaces.C;
with Interfaces.C.Strings;
with System;

package body Coyote_Notify is

   use type Interfaces.C.int;
   use type System.Address;

   type Notification_Handle is new System.Address;
   type Error_Handle is new System.Address;

   type Urgency is (Low, Normal, Critical);
   pragma Unreferenced (Low, Critical);
   for Urgency use (0, 1, 2);
   pragma Convention (C, Urgency);

   Initialized    : Boolean := False;
   Init_Attempted : Boolean := False;

   function Notify_Init
     (App_Name : Interfaces.C.Strings.chars_ptr)
      return Interfaces.C.int
     with Import, Convention => C, External_Name => "notify_init";

   procedure Notify_Uninit
     with Import, Convention => C, External_Name => "notify_uninit";

   function Notification_New
     (Summary   : Interfaces.C.Strings.chars_ptr;
      Body_Text : Interfaces.C.Strings.chars_ptr;
      Icon      : Interfaces.C.Strings.chars_ptr)
      return Notification_Handle
     with Import, Convention => C,
       External_Name => "notify_notification_new";

   procedure Notification_Set_Timeout
     (Notification : Notification_Handle;
      Timeout      : Interfaces.C.int)
     with Import, Convention => C,
       External_Name => "notify_notification_set_timeout";

   procedure Notification_Set_Urgency
     (Notification : Notification_Handle;
      Value        : Urgency)
     with Import, Convention => C,
       External_Name => "notify_notification_set_urgency";

   procedure Notification_Set_App_Name
     (Notification : Notification_Handle;
      App_Name     : Interfaces.C.Strings.chars_ptr)
     with Import, Convention => C,
       External_Name => "notify_notification_set_app_name";

   function Notification_Show
     (Notification : Notification_Handle;
      Error        : access Error_Handle)
      return Interfaces.C.int
     with Import, Convention => C,
       External_Name => "notify_notification_show";

   procedure Object_Unref (Object : Notification_Handle)
     with Import, Convention => C, External_Name => "g_object_unref";

   procedure Error_Free (Error : Error_Handle)
     with Import, Convention => C, External_Name => "g_error_free";

   function Show_Completion return Boolean is
      --  Native calls copy these strings; unchecked access stays local to
      --  each synchronous call and never escapes this procedure.
      App_Name : aliased Interfaces.C.char_array :=
        Interfaces.C.To_C ("coyote");
      Summary : aliased Interfaces.C.char_array :=
        Interfaces.C.To_C ("Coyote");
      Body_Text : aliased Interfaces.C.char_array :=
        Interfaces.C.To_C ("Agent turn complete.");
      Notification : Notification_Handle := Notification_Handle
        (System.Null_Address);
      Error : aliased Error_Handle := Error_Handle (System.Null_Address);
      Shown : Interfaces.C.int := 0;
      Result : Boolean := False;

      procedure Release_Resources is
         Saved : Error_Handle;
      begin
         if Error /= Error_Handle (System.Null_Address) then
            Saved := Error;
            Error := Error_Handle (System.Null_Address);
            Error_Free (Saved);
         end if;
         if Notification /= Notification_Handle (System.Null_Address) then
            declare
               Saved_Notification : constant Notification_Handle :=
                 Notification;
            begin
               Notification := Notification_Handle (System.Null_Address);
               Object_Unref (Saved_Notification);
            end;
         end if;
      end Release_Resources;
   begin
      if not Init_Attempted then
         Init_Attempted := True;
         Initialized :=
           Notify_Init
             (Interfaces.C.Strings.To_Chars_Ptr
                (App_Name'Unchecked_Access)) /= 0;
      end if;

      if Initialized then
         Notification :=
           Notification_New
             (Interfaces.C.Strings.To_Chars_Ptr (Summary'Unchecked_Access),
              Interfaces.C.Strings.To_Chars_Ptr (Body_Text'Unchecked_Access),
              Interfaces.C.Strings.Null_Ptr);
         if Notification /= Notification_Handle (System.Null_Address) then
            Notification_Set_Timeout (Notification, 5_000);
            Notification_Set_Urgency (Notification, Normal);
            Notification_Set_App_Name
              (Notification,
               Interfaces.C.Strings.To_Chars_Ptr
                 (App_Name'Unchecked_Access));
            Shown := Notification_Show (Notification, Error'Access);
            Result := Shown /= 0;
         end if;
      end if;

      Release_Resources;
      return Result;
   exception
      when others =>
         begin
            Release_Resources;
         exception
            when others =>
               null;
         end;
         return False;
   end Show_Completion;

   procedure Finalize is
      Was_Initialized : constant Boolean := Initialized;
   begin
      Initialized := False;
      Init_Attempted := False;
      if Was_Initialized then
         Notify_Uninit;
      end if;
   exception
      when others =>
         Initialized := False;
         Init_Attempted := False;
   end Finalize;

end Coyote_Notify;
