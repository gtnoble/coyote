--  LLM.Auth reads and updates provider credentials in auth.json.
--
--  Public saves serialize provider-specific updates with a store lock.
--  Codex refresh code that already owns its provider lock may call the
--  private unlocked save operation; it still acquires the store lock.
--  Invalid existing JSON is never overwritten. File operations are atomic.

with Ada.Strings.Unbounded;

package LLM.Auth is

   type Provider_Credentials is record
      Credential_Type : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;
      Refresh_Token   : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;
      Access_Token    : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;
      Expires_Ms      : Long_Long_Integer := 0;
      Account_Id      : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;
   end record;

   --  Read the lowercase provider entry. Missing/malformed JSON or an absent
   --  provider returns empty credentials. Atomic replacement allows readers
   --  to observe a complete old or new snapshot without acquiring a lock.
   function Load_Credentials (Provider : String) return Provider_Credentials;

   --  Merge a lowercase provider entry under the auth-store file lock.
   --  Codex additionally takes its refresh lock first (login/logout order).
   --  Refuses malformed existing JSON; writes mode-0600 unique staging files
   --  followed by atomic rename. Lock waits are bounded to 60 seconds.
   procedure Save_Credentials
     (Provider : String; Creds : Provider_Credentials);

private

   --  Caller owns the Codex refresh lock when writing Codex credentials.
   --  Acquires only the short store lock. Deliberately not cancellable:
   --  successful refresh-token rotation must be persisted before aborting.
   procedure Save_Credentials_Unlocked
     (Provider : String; Creds : Provider_Credentials);

end LLM.Auth;
