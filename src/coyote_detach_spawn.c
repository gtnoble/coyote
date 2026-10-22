/*  Detached double-fork spawn with synchronous setup reporting.
 *
 *  The caller waits for the intermediate child, never the detached
 *  application.  The grandchild reports setup errno through a pipe whose
 *  write end is close-on-exec.  An errno payload reports a setup/exec
 *  failure; clean EOF is the normal close-on-exec indication that execvp
 *  succeeded, but cannot distinguish an unexpected grandchild death before
 *  execvp from that successful close.  All post-fork operations are C/POSIX
 *  only.
 *
 *  execvp is used for PATH search.  POSIX does not require execvp itself to
 *  be async-signal-safe in a multithreaded process; this implementation
 *  targets Linux/glibc behavior after fork.  The child performs no Ada
 *  runtime calls.  Fault-injection wrappers invoke raw fork syscalls and
 *  are intended for this native single-threaded test harness only.
 */
#define _GNU_SOURCE
#include "coyote_detach_spawn.h"

#include <errno.h>
#include <fcntl.h>
#include <stddef.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

static int move_above_stdio(int fd)
{
    int replacement;

    if (fd > STDERR_FILENO)
        return fd;
#ifdef F_DUPFD_CLOEXEC
    replacement = fcntl(fd, F_DUPFD_CLOEXEC, STDERR_FILENO + 1);
#else
    replacement = fcntl(fd, F_DUPFD, STDERR_FILENO + 1);
    if (replacement >= 0 && fcntl(replacement, F_SETFD, FD_CLOEXEC) < 0) {
        int saved = errno;
        close(replacement);
        errno = saved;
        return -1;
    }
#endif
    if (replacement < 0) {
        int saved = errno;
        close(fd);
        errno = saved;
        return -1;
    }
    close(fd);
    return replacement;
}

static void report_error(int fd, int error)
{
    const unsigned char *data = (const unsigned char *)&error;
    size_t left = sizeof(error);

    while (left > 0) {
        ssize_t count = write(fd, data, left);
        if (count > 0) {
            data += count;
            left -= (size_t)count;
        } else if (count < 0 && errno == EINTR) {
            continue;
        } else {
            break;
        }
    }
}

static void fail_child(int fd, int error)
{
    report_error(fd, error);
    _exit(127);
}

int coyote_detach_spawn(char *const argv[], const char *cwd)
{
    int pipefd[2];
    int error = 0;
    size_t received = 0;
    pid_t pid;
    int status;

    if (argv == NULL || argv[0] == NULL || argv[0][0] == '\0') {
        errno = EINVAL;
        return -1;
    }
#if defined(__linux__) && defined(O_CLOEXEC)
    if (pipe2(pipefd, O_CLOEXEC) < 0)
        return -1;
#else
    errno = ENOTSUP;
    return -1;
#endif
    pipefd[0] = move_above_stdio(pipefd[0]);
    if (pipefd[0] < 0) {
        int saved = errno;
        close(pipefd[1]);
        errno = saved;
        return -1;
    }
    pipefd[1] = move_above_stdio(pipefd[1]);
    if (pipefd[1] < 0) {
        int saved = errno;
        close(pipefd[0]);
        errno = saved;
        return -1;
    }

    pid = fork();
    if (pid < 0) {
        int saved = errno;
        close(pipefd[0]);
        close(pipefd[1]);
        errno = saved;
        return -1;
    }
    if (pid == 0) {
        pid_t grandchild;
        close(pipefd[0]);
        grandchild = fork();
        if (grandchild < 0)
            fail_child(pipefd[1], errno);
        if (grandchild > 0)
            _exit(0);

        if (setsid() < 0)
            fail_child(pipefd[1], errno);
        if (cwd != NULL && cwd[0] != '\0' && chdir(cwd) < 0)
            fail_child(pipefd[1], errno);

        {
            int nullfd = open("/dev/null", O_RDWR);
            if (nullfd < 0)
                fail_child(pipefd[1], errno);
            for (int target = STDIN_FILENO; target <= STDERR_FILENO; ++target) {
                if (dup2(nullfd, target) < 0)
                    fail_child(pipefd[1], errno);
            }
            if (nullfd > STDERR_FILENO)
                close(nullfd);
        }
        execvp(argv[0], argv);
        fail_child(pipefd[1], errno);
    }

    close(pipefd[1]);
    while (received < sizeof(error)) {
        ssize_t count = read(pipefd[0], (unsigned char *)&error + received,
                             sizeof(error) - received);
        if (count > 0) {
            received += (size_t)count;
        } else if (count == 0) {
            break;
        } else if (errno != EINTR) {
            error = errno;
            received = sizeof(error);
            break;
        }
    }
    close(pipefd[0]);

    while (waitpid(pid, &status, 0) < 0) {
        if (errno == EINTR)
            continue;
        return -1;
    }
    if (received != 0) {
        errno = received == sizeof(error) ? error : EIO;
        return -1;
    }
    if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) {
        errno = ECHILD;
        return -1;
    }
    return 0;
}
