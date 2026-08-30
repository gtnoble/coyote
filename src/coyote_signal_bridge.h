/*  coyote_process_control.h — async-signal-safe shutdown bridge. */
#ifndef COYOTE_PROCESS_CONTROL_H
#define COYOTE_PROCESS_CONTROL_H

int coyote_signal_install(void);
int coyote_signal_read(void);
int coyote_signal_group_tree(int root_pid, int signal_number);

#endif
