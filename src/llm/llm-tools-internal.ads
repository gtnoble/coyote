--  LLM.Tools.Internal — thin POSIX bindings shared by tool implementations.
--
--  This is a private child package; it is not part of the public API.
--
--  Project: coyote
--  For revision history, see the project version-control log.

private package LLM.Tools.Internal is

   --  Thin binding for POSIX kill(2).
   --
   --  Sends Signal to the process identified by Pid.  Returns 0 on
   --  success or -1 on error (errno is set but not mapped here).
   --  Signal 15 is SIGTERM.
   function C_Kill
     (Pid    : Integer;
      Signal : Integer) return Integer
     with Import, Convention => C, External_Name => "kill";

end LLM.Tools.Internal;
