--  Coyote_SQC.Workspace.Integrity body.
--
--  Project: coyote

with Ada.Strings.Unbounded;

package body Coyote_SQC.Workspace.Integrity is

   use Ada.Strings.Unbounded;
   use Coyote_SQC.Data_Model;

   --  Build the set of session IDs present in Sessions.
   function Present_Ids
     (Sessions : Session_Vectors.Vector) return UUID_Set
   is
      S : UUID_Set;
   begin
      for Sess of Sessions loop
         S.Include (Sess.Session_Id);
      end loop;
      return S;
   end Present_Ids;

   function Check
     (Workspace : Workspace_Record;
      Sessions  : Session_Vectors.Vector) return Check_Result
   is
      Present : constant UUID_Set := Present_Ids (Sessions);
      Result  : Check_Result;
   begin
      for Id of Workspace.Setup_Session_Ids loop
         if not Present.Contains (Id) then
            Result.Missing_Count := Result.Missing_Count + 1;
         end if;
      end loop;
      return Result;
   end Check;

   procedure Remove_Missing
     (Workspace : in out Workspace_Record;
      Sessions  :        Session_Vectors.Vector)
   is
      Present  : constant UUID_Set := Present_Ids (Sessions);
      To_Keep  : UUID_Set;
   begin
      for Id of Workspace.Setup_Session_Ids loop
         if Present.Contains (Id) then
            To_Keep.Include (Id);
         end if;
      end loop;
      Workspace.Setup_Session_Ids := To_Keep;
   end Remove_Missing;

end Coyote_SQC.Workspace.Integrity;
