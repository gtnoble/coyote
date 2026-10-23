#define _GNU_SOURCE
#include "../../src/coyote_signal_bridge.h"
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

static int checks;
static int failures;
static const char *fault;
static int injected;
static int fail_at;
static int captured[2] = {-1, -1};

#define CHECK(expr, text) do { ++checks; if (!(expr)) { \
    fprintf(stderr, "FAIL: %s (errno=%d)\n", text, errno); ++failures; } \
} while (0)

static int armed(const char *name)
{
    return fault != NULL && strcmp(fault, name) == 0;
}

int __wrap_pipe(int descriptors[2])
{
    int result;
    if (armed("pipe")) { errno = EMFILE; return -1; }
    result = (int)syscall(SYS_pipe2, descriptors, 0);
    if (result == 0) { captured[0] = descriptors[0]; captured[1] = descriptors[1]; }
    return result;
}

int __wrap_fcntl(int fd, int command, ...)
{
    va_list args;
    int argument = 0;
    if (command != F_GETFD && command != F_GETFL) {
        va_start(args, command);
        argument = va_arg(args, int);
        va_end(args);
    }
    if (armed("fcntl") && injected++ == fail_at) {
        errno = EMFILE;
        return -1;
    }
    return (int)syscall(SYS_fcntl, fd, command, argument);
}

int __wrap_sigaction(int signum, const struct sigaction *action,
                     struct sigaction *old_action)
{
    if (armed("sigaction")) { errno = EINVAL; return -1; }
    extern int __real_sigaction(int, const struct sigaction *, struct sigaction *);
    return __real_sigaction(signum, action, old_action);
}

ssize_t __wrap_read(int fd, void *buffer, size_t length)
{
    if (armed("read") && !injected++) { errno = EINTR; return -1; }
    return (ssize_t)syscall(SYS_read, fd, buffer, length);
}

static int open_fd_count(void)
{
    int count = 0;
    for (int fd = 0; fd < 512; ++fd)
        if (syscall(SYS_fcntl, fd, F_GETFD, 0) >= 0)
            ++count;
    return count;
}

static int check_handler_path(void)
{
    if (coyote_signal_install() != 0) return 1;
    errno = EDOM;
    if (raise(SIGTERM) != 0 || errno != EDOM || !coyote_signal_requested()) return 2;
    if (coyote_signal_read() != 1 || coyote_signal_read() != 0) return 3;
    if (raise(SIGTERM) != 0 || coyote_signal_read() != 2 || coyote_signal_read() != 0)
        return 4;
    return 0;
}

static int check_install_fault(const char *name)
{
    const int before = open_fd_count();
    fault = name;
    injected = 0;
    errno = 0;
    if (coyote_signal_install() != -1) return 1;
    if (errno != (strcmp(name, "sigaction") == 0 ? EINVAL :
                  strcmp(name, "pipe") == 0 ? EMFILE : EMFILE)) return 2;
    if (open_fd_count() != before) return 3;
    if (strcmp(name, "fcntl") == 0 && injected != fail_at + 1) return 5;
    fault = NULL;
    if (coyote_signal_install() != 0) return 4;
    return 0;
}

static int worker(const char *mode)
{
    if (strcmp(mode, "handler") == 0) return check_handler_path();
    if (strcmp(mode, "fault-pipe") == 0) return check_install_fault("pipe");
    if (strncmp(mode, "fault-fcntl-", 12) == 0) {
        fail_at = atoi(mode + 12);
        return check_install_fault("fcntl");
    }
    if (strcmp(mode, "fault-sigaction") == 0) return check_install_fault("sigaction");
    if (strcmp(mode, "saturation") == 0) {
        if (coyote_signal_install() != 0) return 10;
        for (int i = 0; i < 100000; ++i)
            if (raise(SIGTERM) != 0) return 11;
        {
            int observed = coyote_signal_read();
            int pending;
            if (observed != 2) return 12;
            do {
                pending = coyote_signal_read();
                if (pending != 2 && pending != 0) return 13;
            } while (pending != 0);
        }
        return 0;
    }
    if (strcmp(mode, "repeat") == 0) {
        int before;
        if (coyote_signal_install() != 0) return 20;
        before = open_fd_count();
        for (int i = 0; i < 100; ++i)
            if (coyote_signal_install() != 0) return 21;
        return open_fd_count() == before ? 0 : 22;
    }
    if (strcmp(mode, "eintr") == 0) {
        if (coyote_signal_install() != 0 || raise(SIGTERM) != 0) return 30;
        fault = "read"; injected = 0;
        return coyote_signal_read() == 1 ? 0 : 31;
    }
    if (strcmp(mode, "fdflags") == 0) {
        if (coyote_signal_install() != 0) return 40;
        for (int i = 0; i < 2; ++i) {
            int fd = captured[i];
            if (fd < 0 || !(fcntl(fd, F_GETFD) & FD_CLOEXEC) ||
                !(fcntl(fd, F_GETFL) & O_NONBLOCK)) return 41;
        }
        return 0;
    }
    if (strcmp(mode, "badfd") == 0) {
        struct sigaction action;
        memset(&action, 0, sizeof action);
        action.sa_handler = SIG_IGN;
        sigemptyset(&action.sa_mask);
        if (sigaction(SIGTERM, &action, NULL) != 0 || coyote_signal_install() != 0)
            return 50;
        close(captured[1]);
        if (kill(getpid(), SIGTERM) != 0) return 51;
        return 52;
    }
    return 99;
}

static void isolated(const char *mode, int expected_exit)
{
    pid_t child = fork();
    int status = 0;
    CHECK(child >= 0, "fork isolated case");
    if (child == 0) _exit(worker(mode));
    if (child < 0) return;
    CHECK(waitpid(child, &status, 0) == child, "wait isolated case");
    if (!(WIFEXITED(status) && WEXITSTATUS(status) == expected_exit))
        fprintf(stderr, "case %s status=%d exit=%d signal=%d\n", mode,
                status, WIFEXITED(status) ? WEXITSTATUS(status) : -1,
                WIFSIGNALED(status) ? WTERMSIG(status) : 0);
    CHECK(WIFEXITED(status) && WEXITSTATUS(status) == expected_exit, mode);
}

int main(void)
{
    isolated("handler", 0);
    isolated("saturation", 0);
    isolated("repeat", 0);
    isolated("eintr", 0);
    isolated("fdflags", 0);
    isolated("badfd", 128 + SIGTERM);
    isolated("fault-pipe", 0);
    for (int i = 0; i < 8; ++i) {
        char mode[32];
        snprintf(mode, sizeof mode, "fault-fcntl-%d", i);
        isolated(mode, 0);
    }
    isolated("fault-sigaction", 0);
    if (failures != 0) return 1;
    printf("%d native signal-bridge checks passed\n", checks);
    return 0;
}
