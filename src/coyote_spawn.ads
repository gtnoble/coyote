--  Coyote_Spawn — fire-and-forget process spawn using double-fork.
--
--  GNATCOLL.OS.Process.Start always requires a subsequent Wait to avoid
--  zombie processes.  The Process_Reaper idiom used previously (fire
--  Start, then allocate a background task to Wait) has a critical flaw:
--  because Process_Reaper_Access lives at package-body library level, all
--  reaper tasks are master-dependent on the environment task, so the
--  program cannot exit until every spawned child process terminates.
--  This makes parent windows hang when children are still running.
--
--  Spawn_Detached uses POSIX double-fork + setsid to create a fully
--  independent child that is reparented to init(1) before the call
--  returns.  There is no zombie, no Wait needed, and no dependency
--  between parent and child lifetimes.
--
--  Project: coyote

with GNATCOLL.OS.Process;

package Coyote_Spawn is

   --  Return True when the detached intermediate process was created.
   function Spawn_Detached
     (Args : GNATCOLL.OS.Process.Argument_List;
      Cwd  : String := "") return Boolean;

end Coyote_Spawn;
