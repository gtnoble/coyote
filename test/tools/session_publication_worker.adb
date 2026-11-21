with Ada.Command_Line; use Ada.Command_Line;
with Ada.Exceptions;
with Ada.Text_IO; use Ada.Text_IO;
with Coyote_Process_Control;
with Coyote_Session_Transactions;
with LLM.Session_Store;
with LLM.Types;
with LLM.User_Images;
with GNATCOLL.JSON;
with Session_Lister;

procedure Session_Publication_Worker is
   package Tx renames Coyote_Session_Transactions;
   use type Tx.Result;

   procedure Publish_Stage (Replace : Boolean) is
      Stage  : constant String := Argument (2);
      Target : constant String := Argument (3);
      Lock   : Tx.Guard;
      Status : Tx.Result;
      Result : Tx.Publication_Result;
   begin
      Tx.Wait_For_Lock (Target, Lock, Status);
      if Status /= Tx.Acquired then
         raise Program_Error with "fixture could not get target guard";
      end if;
      if Replace then
         Tx.Replace_Log (Stage, Target, Result);
      else
         Tx.Publish (Stage, Target, Result);
      end if;
      Put_Line (Result'Image);
   end Publish_Stage;
begin
   if Argument (1) in "create" | "frozen-create" then
      if Argument (1) = "frozen-create" then
         Coyote_Process_Control.Freeze_Persistence;
      end if;
      Put_Line (LLM.Session_Store.Create_Session (Argument (2)));
   elsif Argument (1) = "fork" then
      declare
         Id : constant String := Session_Lister.Fork_Session
           (Argument (2), After_Turn => 1, Target_Cwd => Argument (3));
      begin
         if Id = "" then
            Set_Exit_Status (Failure);
         else
            Put_Line (Id);
         end if;
      end;
   elsif Argument (1) = "migrate" then
      declare
         Image : constant LLM.Types.User_Image := LLM.User_Images.From_JSON
           (GNATCOLL.JSON.Read (Argument (3)));
         Msg : LLM.Types.Message := (Role => LLM.Types.User, others => <>);
      begin
         Msg.Content.Append
           (LLM.Types.Content_Block'(Kind => LLM.Types.User_Image_Block,
                                     Image => Image));
         LLM.Session_Store.Append_Message (Argument (2), Msg);
      end;
   elsif Argument (1) in "publish" | "replace" then
      Publish_Stage (Replace => Argument (1) = "replace");
   else
      raise Program_Error with "unrecognized publication fixture mode";
   end if;
exception
   when Ex : LLM.Session_Store.Session_Error =>
      Put_Line (Standard_Error, Ada.Exceptions.Exception_Message (Ex));
      Set_Exit_Status (Failure);
   when Ex : Session_Lister.Fork_Publication_Uncertain =>
      Put_Line (Standard_Error, Ada.Exceptions.Exception_Message (Ex));
      Set_Exit_Status (Exit_Status (2));
end Session_Publication_Worker;
