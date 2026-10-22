/*  coyote_signal_bridge.h — async-signal-safe shutdown bridge. */
#ifndef COYOTE_SIGNAL_BRIDGE_H
#define COYOTE_SIGNAL_BRIDGE_H

int coyote_signal_install(void);
int coyote_signal_read(void);
int coyote_signal_requested(void);
int coyote_process_kill(int pid, int signal_number);
int coyote_process_getpgid(int pid);

#endif
