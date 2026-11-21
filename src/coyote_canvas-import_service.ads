with Ada.Strings.Unbounded;
with System;

package Coyote_Canvas.Import_Service is
   use Ada.Strings.Unbounded;
   MAX_FILES : constant := 8;
   SOCKET_ENV : constant String := "COYOTE_CANVAS_SOCKET";
   TOKEN_ENV : constant String := "COYOTE_CANVAS_CAPABILITY";

   type Endpoint is record
      Path, Capability : Unbounded_String;
   end record;
   type Text_List is array (Positive range <>) of Unbounded_String;
   type Result is (Ok, Rejected, Unknown);

   --  Only this publication record crosses between GTK and the agent task.
   protected type Binding is
      procedure Set (UUID : String; Value : Endpoint);
      procedure Clear;
      function Get (UUID : String) return Endpoint;
      entry Await (UUID : String; Value : out Endpoint);
   private
      Id : Unbounded_String;
      Current : Endpoint;
      Ready : Boolean := False;
   end Binding;

   type Binding_Access is access all Binding;
   type Listener is limited private;
   procedure Start (Service : in out Listener; Target : out Endpoint);
   procedure Stop (Service : in out Listener);
   function Running (Service : Listener) return Boolean;

   --  At most one accepted request is pending. Take transfers a full batch;
   --  Finish records the terminal disposition before it is sent to the CLI.
   function Pending (Service : Listener) return Boolean;
   procedure Take (Service : Listener; Data, Labels : out Text_List;
                   Count : out Natural);
   procedure Finish (Service : Listener; Status : Result; Text : String);

   --  The CLI inherits authority, never infers a target. No file is opened
   --  until the service has admitted this request.
   procedure Add (Files : Text_List; Status : out Result;
                  Text : out Unbounded_String);
   procedure Clear_Inherited;
private
   type Listener is limited record
      Handle : System.Address := System.Null_Address;
   end record;
end Coyote_Canvas.Import_Service;
