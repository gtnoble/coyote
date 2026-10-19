with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with LLM.Auth;
with LLM.Auth.Codex;
with LLM.Credential_Locks;

procedure Auth_Test_Worker is
   use Ada.Command_Line;

   procedure Touch (Path : String) is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Close (File);
   end Touch;

   procedure Wait_For (Path : String) is
   begin
      for Attempt in 1 .. 1_000 loop
         exit when Ada.Directories.Exists (Path);
         delay 0.01;
      end loop;
      if not Ada.Directories.Exists (Path) then
         raise Program_Error with "barrier timeout: " & Path;
      end if;
   end Wait_For;

   Home : constant String := Ada.Environment_Variables.Value ("HOME", "");
   Mode : constant String := Argument (1);
begin
   if Home'Length = 0 or else Argument_Count < 2 then
      raise Program_Error with "usage: auth_test_worker MODE MARKER [ARG]";
   end if;

   if Mode = "hold-lock" then
      declare
         Guard : LLM.Credential_Locks.Lock;
         Ready : constant String := Argument (2);
      begin
         LLM.Credential_Locks.Acquire
           (Guard, Home & "/.coyote/codex-refresh.lock");
         Touch (Ready);
         Wait_For (Argument (3));
      end;
   elsif Mode = "idle" then
      Touch (Argument (2));
      Wait_For (Argument (3));
   else
      if Mode = "ensure" then
         Touch (Argument (2));
         Wait_For (Argument (3));
         declare
            Creds : LLM.Auth.Provider_Credentials :=
              LLM.Auth.Load_Credentials ("codex");
         begin
            LLM.Auth.Codex.Ensure_Valid (Creds);
            if Length (Creds.Access_Token) = 0 then
               raise Program_Error with "ensure returned empty token";
            end if;
         end;
      elsif Mode = "recover" then
         declare
            --  Capture before the gate so concurrent workers share the
            --  same rejected token if one refreshes first.
            Creds : LLM.Auth.Provider_Credentials :=
              LLM.Auth.Load_Credentials ("codex");
            Rejected : constant String := To_String (Creds.Access_Token);
         begin
            Touch (Argument (2));
            Wait_For (Argument (3));
            LLM.Auth.Codex.Recover_Rejected_Token (Creds, Rejected);
            if Length (Creds.Access_Token) = 0 then
               raise Program_Error with "recover returned empty token";
            end if;
         end;
      elsif Mode = "save-openai" or else Mode = "save-anthropic"
        or else Mode = "save-codex" or else Mode = "logout-codex"
      then
         Touch (Argument (2));
         Wait_For (Argument (3));
         declare
            Creds : constant LLM.Auth.Provider_Credentials :=
              (if Mode = "logout-codex" then (others => <>)
               else (Credential_Type => To_Unbounded_String ("test"),
                     Refresh_Token => Null_Unbounded_String,
                     Access_Token => To_Unbounded_String (Mode),
                     Expires_Ms => 0,
                     Account_Id => Null_Unbounded_String));
            Provider : constant String :=
              (if Mode = "save-openai" then "openai"
               elsif Mode = "save-anthropic" then "anthropic"
               else "codex");
         begin
            LLM.Auth.Save_Credentials (Provider, Creds);
         end;
      else
         raise Program_Error with "unknown mode: " & Mode;
      end if;
      Touch (Argument (2) & ".done");
   end if;
exception
   when others =>
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "auth worker failed");
      Set_Exit_Status (Failure);
end Auth_Test_Worker;
