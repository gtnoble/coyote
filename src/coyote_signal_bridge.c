/*  coyote_signal_bridge.c — async-signal-safe shutdown bridge. */
#define _GNU_SOURCE
#include "coyote_signal_bridge.h"

#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>

static int signal_pipe[2] = {-1, -1};
static volatile sig_atomic_t signal_count = 0;

static void on_sigterm(int signo)
{
    unsigned char byte = 1;
    int saved_errno = errno;
    ssize_t ignored;

    (void)signo;
    if (signal_count < 2)
        signal_count++;
    if (signal_pipe[1] >= 0) {
        ignored = write(signal_pipe[1], &byte, sizeof byte);
        if (ignored < 0 && errno == EBADF)
            _exit(128 + SIGTERM);
    } else {
        _exit(128 + SIGTERM);
    }
    errno = saved_errno;
}

static int set_close_on_exec(int descriptor)
{
    int flags = fcntl(descriptor, F_GETFD, 0);

    if (flags < 0)
        return -1;
    return fcntl(descriptor, F_SETFD, flags | FD_CLOEXEC);
}

int coyote_signal_install(void)
{
    struct sigaction action;
    int flags;

    if (signal_pipe[0] >= 0)
        return 0;
    if (pipe(signal_pipe) != 0)
        return -1;
    if (set_close_on_exec(signal_pipe[0]) != 0
        || set_close_on_exec(signal_pipe[1]) != 0)
        return -1;

    flags = fcntl(signal_pipe[0], F_GETFL, 0);
    if (flags < 0 || fcntl(signal_pipe[0], F_SETFL, flags | O_NONBLOCK) != 0)
        return -1;
    flags = fcntl(signal_pipe[1], F_GETFL, 0);
    if (flags < 0 || fcntl(signal_pipe[1], F_SETFL, flags | O_NONBLOCK) != 0)
        return -1;

    memset(&action, 0, sizeof action);
    action.sa_handler = on_sigterm;
    sigemptyset(&action.sa_mask);
    action.sa_flags = SA_RESTART;
    if (sigaction(SIGTERM, &action, NULL) != 0)
        return -1;

    return 0;
}

int coyote_signal_read(void)
{
    unsigned char buffer[32];
    ssize_t result;

    if (signal_pipe[0] < 0)
        return 0;

    do {
        result = read(signal_pipe[0], buffer, sizeof buffer);
    } while (result < 0 && errno == EINTR);

    if (result > 0)
        return signal_count >= 2 ? 2 : 1;
    if (result < 0 && (errno == EAGAIN || errno == EWOULDBLOCK))
        return 0;
    return result < 0 ? -1 : 0;
}

int coyote_signal_requested(void)
{
    return signal_count > 0 ? 1 : 0;
}

int coyote_process_kill(int pid, int signal_number)
{
    return kill((pid_t)pid, signal_number);
}

int coyote_process_getpgid(int pid)
{
    return (int)getpgid((pid_t)pid);
}
