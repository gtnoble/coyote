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
    const unsigned char byte = 1;
    const int saved_errno = errno;
    ssize_t result;

    (void)signo;
    if (signal_count < 2)
        signal_count++;
    if (signal_pipe[1] < 0)
        _exit(128 + SIGTERM);
    result = write(signal_pipe[1], &byte, sizeof byte);
    if (result < 0 && errno == EBADF)
        _exit(128 + SIGTERM);
    /* EAGAIN means the nonblocking pipe is full; signal_count retains state. */
    errno = saved_errno;
}

static int set_close_on_exec(int descriptor)
{
    int flags = fcntl(descriptor, F_GETFD, 0);

    if (flags < 0)
        return -1;
    return fcntl(descriptor, F_SETFD, flags | FD_CLOEXEC);
}

static int set_nonblocking(int descriptor)
{
    int flags = fcntl(descriptor, F_GETFL, 0);

    if (flags < 0)
        return -1;
    return fcntl(descriptor, F_SETFL, flags | O_NONBLOCK);
}

static void close_pair(int descriptors[2], int saved_errno)
{
    if (descriptors[0] >= 0)
        (void)close(descriptors[0]);
    if (descriptors[1] >= 0)
        (void)close(descriptors[1]);
    descriptors[0] = -1;
    descriptors[1] = -1;
    errno = saved_errno;
}

int coyote_signal_install(void)
{
    struct sigaction action;
    int descriptors[2] = {-1, -1};
    int saved_errno;

    if (signal_pipe[0] >= 0)
        return 0;
    if (pipe(descriptors) != 0)
        return -1;
    if (set_close_on_exec(descriptors[0]) != 0
        || set_close_on_exec(descriptors[1]) != 0
        || set_nonblocking(descriptors[0]) != 0
        || set_nonblocking(descriptors[1]) != 0) {
        saved_errno = errno;
        close_pair(descriptors, saved_errno);
        return -1;
    }

    memset(&action, 0, sizeof action);
    action.sa_handler = on_sigterm;
    sigemptyset(&action.sa_mask);
    action.sa_flags = SA_RESTART;

    /* Publish only fully configured descriptors before exposing the handler. */
    signal_pipe[0] = descriptors[0];
    signal_pipe[1] = descriptors[1];
    if (sigaction(SIGTERM, &action, NULL) != 0) {
        saved_errno = errno;
        signal_pipe[0] = -1;
        signal_pipe[1] = -1;
        close_pair(descriptors, saved_errno);
        return -1;
    }
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
