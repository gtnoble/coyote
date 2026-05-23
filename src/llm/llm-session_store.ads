--  LLM.Session_Store — JSONL session persistence.
--
--  Creates, appends, and reloads coyote session files using the
--  native JSONL format.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with LLM.Types;

package LLM.Session_Store is

   --  Generate a random RFC 4122 version-4 UUID as a lowercase
   --  hyphenated string.
   function New_UUID return String;

   --  Create a new session file under Session_Lister.Sessions_Dir (Cwd).
   --
   --  The target directory is created when it does not already exist.
   --  The new file contains only the JSONL header line.
   --
   --  Returns the new session UUID.
   --
   --  Raises Session_Error on directory-creation or file-write failure.
   function Create_Session (Cwd : String) return String;

   --  Append one message line to the session file for Session_Id.
   --
   --  Each call opens the file in append mode, writes one JSON object line
   --  followed by LF, and then closes the file again.
   --
   --  Raises Session_Error when the session file cannot be found or when
   --  Msg cannot be serialised.
   procedure Append_Message
     (Session_Id : String;
      Msg        : LLM.Types.Message);

   --  Append one compaction entry line to the session file.
   --
   --  Summary is the LLM-generated markdown summary. First_Kept_Index is
   --  the 0-based index of the first pre-compaction message retained after
   --  compaction. Tokens_Before records the estimated token count before
   --  compaction.
   --
   --  Raises Session_Error when the session file cannot be found or
   --  written.
   procedure Append_Compaction
     (Session_Id       : String;
      Summary          : String;
      First_Kept_Index : Natural;
      Tokens_Before    : Natural);

   --  Append a model-change record to the session JSONL.
   --
   --  Writes a {"type":"model_change","provider":Provider,"modelId":Model_Id}
   --  line.  Should be called once per Run_Prompt invocation, before the
   --  first assistant message, so that Coyote_SQC.Session_Parser can
   --  identify the model used for the session.
   --
   --  Raises Session_Error when the session file cannot be found or
   --  written.
   procedure Append_Model_Change
     (Session_Id : String;
      Provider   : String;
      Model_Id   : String);

   --  Return the working directory recorded in the header of the session
   --  file for Session_Id.
   --
   --  Returns "" when the file does not exist, the header cannot be
   --  parsed, or the header contains no "workDir" field.
   function Session_Work_Dir (Session_Id : String) return String;

   --  Load all messages from the session file for Session_Id.
   --
   --  Returns an empty vector when the file does not exist.
   --  Skips the header line and any non-message records.
   function Load_Messages
     (Session_Id : String) return LLM.Types.Message_Vectors.Vector;

   --  Return the full path of the session JSONL file for Session_Id.
   --
   --  Delegates to Session_Lister.Find_Session_File.
   function Session_File_Path (Session_Id : String) return String;

   --  Delete the session JSONL file for Session_Id.
   --
   --  This is a no-op when the file does not exist.
   --  Raises Session_Error on any deletion failure.
   procedure Delete_Session (Session_Id : String);

   Session_Error : exception;

end LLM.Session_Store;
