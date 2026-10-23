/*  coyote_signal_bridge.h — async-signal-safe shutdown bridge. */
#ifndef COYOTE_SIGNAL_BRIDGE_H
#define COYOTE_SIGNAL_BRIDGE_H

/* Installs a process-wide SIGTERM handler and nonblocking close-on-exec pipe.
 * Returns 0 on success, or -1 with errno preserved on setup failure; a failed
 * attempt leaves the bridge uninstalled and may be retried. Repeated successful
 * calls are idempotent. Installation is serialized at application startup,
 * before frontend/agent tasks begin; concurrent installation is unsupported. */
int coyote_signal_install(void);

/* Drains one batch of pipe data: 0 means no pending bytes, 1 means one SIGTERM
 * has been recorded, 2 means at least two. The second-signal state persists
 * after the pipe is drained. POSIX standard-signal coalescing means concurrent
 * deliveries are not guaranteed to be counted individually. */
int coyote_signal_read(void);

/* Returns 1 once any SIGTERM has been recorded, otherwise 0. */
int coyote_signal_requested(void);

int coyote_process_kill(int pid, int signal_number);
int coyote_process_getpgid(int pid);

#endif
