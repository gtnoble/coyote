/*  coyote_detach_spawn.c — detached double-fork spawn for fire-and-forget
 *  child processes (New Window, Fork Session).
 *
 *  Spawns a completely independent child that is reparented to init(1)
 *  before the caller even sees the return.  The parent never needs to
 *  call waitpid(); there is no zombie and no blocking.
 *
 *  Implementation: classic double-fork daemonization:
 *    1. fork() → intermediate child
 *    2. Intermediate child: fork() → grandchild, then _exit(0)
 *    3. Grandchild: setsid(), close+redirect fds→/dev/null, execvp()
 *    4. Parent: waitpid() intermediate child (returns immediately)
 *
 *  The intermediate child's exit is near-instantaneous (it does nothing
 *  but fork), so the parent's waitpid() never blocks for practical
 *  purposes.
 *
 *  Project: coyote
 */

#define _GNU_SOURCE
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdlib.h>

int coyote_detach_spawn(char *const argv[], const char *cwd)
{
    pid_t pid, pid2;
    int   status;
    int   devnull;

    pid = fork();
    if (pid < 0)
        return -1;

    if (pid == 0) {
        /*  Intermediate child: fork again, then exit immediately so the
         *  grandchild is reparented to init.                            */
        pid2 = fork();
        if (pid2 < 0)
            _exit(127);

        if (pid2 > 0)
            _exit(0);           /*  intermediate child exits at once     */

        /*  ── Grandchild (the real coyote process) ──────────────────── */
        setsid();               /*  detach from controlling terminal      */

        if (cwd && cwd[0])
            chdir(cwd);         /*  change to target directory            */

        /*  Redirect stdin / stdout / stderr to /dev/null so the child
         *  does not hold inherited fds from the parent.                 */
        devnull = open("/dev/null", O_RDWR);
        if (devnull >= 0) {
            dup2(devnull, 0);
            dup2(devnull, 1);
            dup2(devnull, 2);
            if (devnull > 2)
                close(devnull);
        }

        execvp(argv[0], argv);
        _exit(127);             /*  execvp failed                        */
    }

    /*  Parent: reap the intermediate child (returns quickly).            */
    waitpid(pid, &status, 0);
    return 0;
}
