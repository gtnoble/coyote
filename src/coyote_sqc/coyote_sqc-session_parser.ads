--  Coyote_SQC.Session_Parser — sole package that reads Coyote JSONL files.
--
--  Scans the session directory for a given source working directory and
--  parses all .jsonl files found there into Session_Record values.
--
--  Both legacy (version 1) and current (version 3) wire formats are handled.
--  No other package in Coyote_SQC may reference raw session file field names.
--
--  Project: coyote

with Coyote_SQC.Data_Model;

package Coyote_SQC.Session_Parser is

   --  Produce the session directory slug for a source working directory.
   --  E.g. "/home/user/Projects/foo" → "--home-user-Projects-foo--".
   function Encode_Cwd (Cwd : String) return String;

   --  Load all sessions whose Source_Directory matches any entry in
   --  Source_Directories (or all sessions when Source_Directories is empty).
   --
   --  Sessions are appended to the supplied vector and sorted by Start_Time
   --  ascending before returning.
   procedure Load_Sessions
     (Source_Directories : Coyote_SQC.Data_Model.String_Vectors.Vector;
      Model_Filter       : Coyote_SQC.Data_Model.String_Vectors.Vector;
      Sessions           : in out Coyote_SQC.Data_Model.Session_Vectors.Vector);

   --  Parse a single .jsonl session file.
   --  Raises Session_Parse_Error on unrecoverable format errors.
   procedure Parse_File
     (Path    :     String;
      Session : out Coyote_SQC.Data_Model.Session_Record;
      Ok      : out Boolean);

   Session_Parse_Error : exception;

end Coyote_SQC.Session_Parser;
