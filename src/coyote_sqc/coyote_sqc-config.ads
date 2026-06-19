--  Coyote_SQC.Config — per-user configuration file management.
--
--  Configuration lives under ~/.config/coyote_sqc/.
--
--  Project: coyote

with Ada.Strings.Unbounded;

with Coyote_SQC.Metrics;

package Coyote_SQC.Config is

   --  A recent workspace entry.
   type Recent_Entry is record
      Name        : Ada.Strings.Unbounded.Unbounded_String;
      Path        : Ada.Strings.Unbounded.Unbounded_String;
      Last_Opened : Long_Long_Integer := 0;  --  Unix milliseconds
   end record;

   Max_Recent : constant := 5;
   type Recent_Array is array (1 .. Max_Recent) of Recent_Entry;
   type Recent_Count is range 0 .. Max_Recent;

   type Recent_List is record
      Entries : Recent_Array;
      Count   : Recent_Count := 0;
   end record;

   --  Return the path to the config directory, creating it if needed.
   function Config_Dir return String;

   --  Load the recent-workspaces list.  Returns an empty list on error.
   function Load_Recent return Recent_List;

   --  Record a workspace open/save.  Upserts the entry (keyed by Path) at
   --  the top of the list and trims to Max_Recent entries.  Writes the file
   --  atomically (write to .tmp, then rename).
   procedure Record_Open (Name : String; Path : String);

   --  ── Pricing ────────────────────────────────────────────────────────

   --  Load the token pricing table: first from ~/.config/coyote_sqc/pricing.json
   --  (if it exists), then attempt the OpenRouter API fallback for any model
   --  not found locally.  Returns an empty table on error or when no pricing
   --  source is available.
   function Load_Pricing return Coyote_SQC.Metrics.Pricing_Table;

end Coyote_SQC.Config;
