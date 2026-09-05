--  Coyote_App.Agent_Registry — runtime virtual-agent hierarchy.
--
--  Maintains coordinator-local identity, parentage, lifecycle, and selection
--  state without owning GTK widgets or child-process resources.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Containers;
with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

package Coyote_App.Agent_Registry is

   --  Runtime identity is intentionally separate from durable session UUIDs.
   type Agent_Id is private;

   function Create_Agent_Id (Value : String) return Agent_Id;
   function Is_Empty (Id : Agent_Id) return Boolean;
   function To_String (Id : Agent_Id) return String;
   function "=" (Left, Right : Agent_Id) return Boolean;

   type Lifecycle_Status is
     (Starting, Ready, Running, Paused, Completed, Aborted, Failed,
      Disconnected);

   type Endpoint_Kind is (Local_Endpoint, RPC_Endpoint);

   --  Presentation data retained for one virtual agent.  This record contains
   --  no GTK values; the GUI owns its visual projection separately.  Endpoint
   --  identifies how the coordinator sends input and controls to the agent.
   type Agent_Record is record
      Runtime_Id         : Agent_Id;
      Parent_Runtime_Id  : Agent_Id;
      Durable_Session_Id : Ada.Strings.Unbounded.Unbounded_String;
      Label              : Ada.Strings.Unbounded.Unbounded_String;
      Endpoint           : Endpoint_Kind := Local_Endpoint;
      Status             : Lifecycle_Status := Starting;
   end record;

   type Registry is tagged private;

   --  Register an agent node.  An empty parent identifies the single root;
   --  a non-empty parent must already be registered.
   function Register_Agent
     (R                  : in out Registry;
      Runtime_Id         : Agent_Id;
      Parent_Runtime_Id  : Agent_Id;
      Endpoint           : Endpoint_Kind;
      Durable_Session_Id : String := "";
      Label              : String := "agent";
      Status             : Lifecycle_Status := Starting) return Boolean;

   --  Register exactly one local root agent.  Returns False for an empty or
   --  duplicate identity, or when a root is already present.
   function Register_Root
     (R                  : in out Registry;
      Runtime_Id         : Agent_Id;
      Durable_Session_Id : String := "";
      Label              : String := "main";
      Status             : Lifecycle_Status := Starting) return Boolean;

   --  Register an RPC child below an existing parent.  Returns False for an
   --  empty or duplicate identity, or for an unknown parent.
   function Register_Child
     (R                  : in out Registry;
      Runtime_Id         : Agent_Id;
      Parent_Runtime_Id  : Agent_Id;
      Durable_Session_Id : String := "";
      Label              : String := "subagent";
      Status             : Lifecycle_Status := Starting) return Boolean;

   function Agent_Count (R : Registry) return Natural;
   function Child_Count
     (R         : Registry;
      Parent_Id : Agent_Id) return Natural;

   --  Return an empty record when the requested position or identity is not
   --  present.  Positions follow registration order for Agent_At and
   --  parent-child order for Child_At.
   function Agent_At
     (R        : Registry;
      Position : Positive) return Agent_Record;
   function Child_At
     (R         : Registry;
      Parent_Id : Agent_Id;
      Position  : Positive) return Agent_Id;
   function Get_Agent
     (R          : Registry;
      Runtime_Id : Agent_Id) return Agent_Record;

   function Has_Agent
     (R          : Registry;
      Runtime_Id : Agent_Id) return Boolean;

   function Set_Status
     (R          : in out Registry;
      Runtime_Id : Agent_Id;
      Status     : Lifecycle_Status) return Boolean;

   function Set_Durable_Session_Id
     (R          : in out Registry;
      Runtime_Id : Agent_Id;
      Session_Id : String) return Boolean;

   --  Selection includes terminal agents so their retained conversations can
   --  be reviewed.  Can_Control is false for terminal or disconnected agents.
   function Select_Agent
     (R          : in out Registry;
      Runtime_Id : Agent_Id) return Boolean;
   procedure Clear_Selection (R : in out Registry);
   function Selected_Agent (R : Registry) return Agent_Id;
   function Has_Selection (R : Registry) return Boolean;
   function Can_Control
     (R          : Registry;
      Runtime_Id : Agent_Id) return Boolean;

   procedure Clear (R : in out Registry);

private

   type Agent_Id is record
      Value : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   package Agent_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Agent_Record);

   type Registry is tagged record
      Agents   : Agent_Vectors.Vector;
      Selected : Agent_Id;
   end record;

end Coyote_App.Agent_Registry;
