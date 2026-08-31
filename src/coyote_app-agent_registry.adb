--  Coyote_App.Agent_Registry — runtime virtual-agent hierarchy.
--
--  The registry uses registration-order vectors because the coordinator must
--  retain stable presentation order while child relationships are resolved by
--  runtime identity.  It deliberately has no GUI or process dependencies.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded;

package body Coyote_App.Agent_Registry is

   use Ada.Strings.Unbounded;

   Empty_Id : constant Agent_Id :=
     (Value => Null_Unbounded_String);

   Empty_Record : constant Agent_Record :=
     (Runtime_Id         => Empty_Id,
      Parent_Runtime_Id  => Empty_Id,
      Durable_Session_Id => Null_Unbounded_String,
      Label              => Null_Unbounded_String,
      Status             => Starting);

   function Create_Agent_Id (Value : String) return Agent_Id is
   begin
      return (Value => To_Unbounded_String (Value));
   end Create_Agent_Id;

   function Is_Empty (Id : Agent_Id) return Boolean is
   begin
      return Length (Id.Value) = 0;
   end Is_Empty;

   function To_String (Id : Agent_Id) return String is
   begin
      return To_String (Id.Value);
   end To_String;

   function "=" (Left, Right : Agent_Id) return Boolean is
   begin
      return Left.Value = Right.Value;
   end "=";

   function Find_Index
     (R          : Registry;
      Runtime_Id : Agent_Id) return Agent_Vectors.Extended_Index
   is
   begin
      for Position in R.Agents.First_Index .. R.Agents.Last_Index loop
         if R.Agents.Element (Position).Runtime_Id = Runtime_Id then
            return Position;
         end if;
      end loop;
      return Agent_Vectors.No_Index;
   end Find_Index;

   function Register_Root
     (R                  : in out Registry;
      Runtime_Id         : Agent_Id;
      Durable_Session_Id : String := "";
      Label              : String := "main";
      Status             : Lifecycle_Status := Starting) return Boolean
   is
   begin
      if Is_Empty (Runtime_Id)
        or else not R.Agents.Is_Empty
        or else Has_Agent (R, Runtime_Id)
      then
         return False;
      end if;

      R.Agents.Append
        ((Runtime_Id         => Runtime_Id,
          Parent_Runtime_Id  => Empty_Id,
          Durable_Session_Id => To_Unbounded_String (Durable_Session_Id),
          Label              => To_Unbounded_String (Label),
          Status             => Status));
      return True;
   end Register_Root;

   function Register_Child
     (R                  : in out Registry;
      Runtime_Id         : Agent_Id;
      Parent_Runtime_Id  : Agent_Id;
      Durable_Session_Id : String := "";
      Label              : String := "subagent";
      Status             : Lifecycle_Status := Starting) return Boolean
   is
   begin
      if Is_Empty (Runtime_Id)
        or else Is_Empty (Parent_Runtime_Id)
        or else Has_Agent (R, Runtime_Id)
        or else not Has_Agent (R, Parent_Runtime_Id)
      then
         return False;
      end if;

      R.Agents.Append
        ((Runtime_Id         => Runtime_Id,
          Parent_Runtime_Id  => Parent_Runtime_Id,
          Durable_Session_Id => To_Unbounded_String (Durable_Session_Id),
          Label              => To_Unbounded_String (Label),
          Status             => Status));
      return True;
   end Register_Child;

   function Agent_Count (R : Registry) return Natural is
   begin
      return Natural (R.Agents.Length);
   end Agent_Count;

   function Child_Count
     (R         : Registry;
      Parent_Id : Agent_Id) return Natural
   is
      Count : Natural := 0;
   begin
      if Is_Empty (Parent_Id) or else R.Agents.Is_Empty then
         return Count;
      end if;

      for Position in R.Agents.First_Index .. R.Agents.Last_Index loop
         if R.Agents.Element (Position).Parent_Runtime_Id = Parent_Id then
            Count := Count + 1;
         end if;
      end loop;
      return Count;
   end Child_Count;

   function Agent_At
     (R        : Registry;
      Position : Positive) return Agent_Record
   is
   begin
      if R.Agents.Is_Empty
        or else Position > Natural (R.Agents.Length)
      then
         return Empty_Record;
      end if;
      return R.Agents.Element (Position);
   end Agent_At;

   function Child_At
     (R         : Registry;
      Parent_Id : Agent_Id;
      Position  : Positive) return Agent_Id
   is
      Child_Position : Natural := 0;
   begin
      if Is_Empty (Parent_Id) or else R.Agents.Is_Empty then
         return Empty_Id;
      end if;

      for Index in R.Agents.First_Index .. R.Agents.Last_Index loop
         if R.Agents.Element (Index).Parent_Runtime_Id = Parent_Id then
            Child_Position := Child_Position + 1;
            if Child_Position = Position then
               return R.Agents.Element (Index).Runtime_Id;
            end if;
         end if;
      end loop;
      return Empty_Id;
   end Child_At;

   function Get_Agent
     (R          : Registry;
      Runtime_Id : Agent_Id) return Agent_Record
   is
      Position : constant Agent_Vectors.Extended_Index :=
        Find_Index (R, Runtime_Id);
   begin
      if Position = Agent_Vectors.No_Index then
         return Empty_Record;
      end if;
      return R.Agents.Element (Position);
   end Get_Agent;

   function Has_Agent
     (R          : Registry;
      Runtime_Id : Agent_Id) return Boolean
   is
   begin
      return not Is_Empty (Runtime_Id)
        and then Find_Index (R, Runtime_Id) /= Agent_Vectors.No_Index;
   end Has_Agent;

   function Set_Status
     (R          : in out Registry;
      Runtime_Id : Agent_Id;
      Status     : Lifecycle_Status) return Boolean
   is
      Position : constant Agent_Vectors.Extended_Index :=
        Find_Index (R, Runtime_Id);
   begin
      if Position = Agent_Vectors.No_Index then
         return False;
      end if;
      R.Agents.Replace_Element
        (Position,
         (Runtime_Id         => R.Agents.Element (Position).Runtime_Id,
          Parent_Runtime_Id  => R.Agents.Element (Position).Parent_Runtime_Id,
          Durable_Session_Id => R.Agents.Element (Position).Durable_Session_Id,
          Label              => R.Agents.Element (Position).Label,
          Status             => Status));
      return True;
   end Set_Status;

   function Set_Durable_Session_Id
     (R          : in out Registry;
      Runtime_Id : Agent_Id;
      Session_Id : String) return Boolean
   is
      Position : constant Agent_Vectors.Extended_Index :=
        Find_Index (R, Runtime_Id);
      Current : Agent_Record;
   begin
      if Position = Agent_Vectors.No_Index then
         return False;
      end if;
      Current := R.Agents.Element (Position);
      Current.Durable_Session_Id := To_Unbounded_String (Session_Id);
      R.Agents.Replace_Element (Position, Current);
      return True;
   end Set_Durable_Session_Id;

   function Select_Agent
     (R          : in out Registry;
      Runtime_Id : Agent_Id) return Boolean
   is
   begin
      if not Has_Agent (R, Runtime_Id) then
         return False;
      end if;
      R.Selected := Runtime_Id;
      return True;
   end Select_Agent;

   procedure Clear_Selection (R : in out Registry) is
   begin
      R.Selected := Empty_Id;
   end Clear_Selection;

   function Selected_Agent (R : Registry) return Agent_Id is
   begin
      return R.Selected;
   end Selected_Agent;

   function Has_Selection (R : Registry) return Boolean is
   begin
      return not Is_Empty (R.Selected);
   end Has_Selection;

   function Can_Control
     (R          : Registry;
      Runtime_Id : Agent_Id) return Boolean
   is
      Position : constant Agent_Vectors.Extended_Index :=
        Find_Index (R, Runtime_Id);
      Current  : Lifecycle_Status;
   begin
      if Position = Agent_Vectors.No_Index then
         return False;
      end if;

      Current := R.Agents.Element (Position).Status;
      return Current = Starting
        or else Current = Ready
        or else Current = Running
        or else Current = Paused;
   end Can_Control;

   procedure Clear (R : in out Registry) is
   begin
      R.Agents.Clear;
      R.Selected := Empty_Id;
   end Clear;

end Coyote_App.Agent_Registry;
