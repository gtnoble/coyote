#define _GNU_SOURCE
#include "../../src/coyote_detach_spawn.h"
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/sysmacros.h>
#include <sys/types.h>
#include <sys/syscall.h>
#include <stdarg.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

static char root[] = "/tmp/coyote-detach-test.XXXXXX";
static int failures;
static int checks;
/* Linker --wrap hooks provide deterministic faults without production hooks. */
static const char *fault;
static int injected;
static int arm(const char *name)
{
    return fault != NULL && strcmp(fault, name) == 0;
}
int __wrap_pipe2(int p[2], int flags)
{
    if (arm("pipe2")) { errno = EMFILE; return -1; }
    return syscall(SYS_pipe2, p, flags);
}
int __wrap_fcntl(int fd, int cmd, ...)
{
    va_list ap;
    int arg;
    va_start(ap, cmd); arg = va_arg(ap, int); va_end(ap);    if (arm("fcntl") && !injected++) { errno = EMFILE; return -1; }
    return (int)syscall(SYS_fcntl, fd, cmd, arg);
}
pid_t __wrap_fork(void)
{
    if (arm("fork") && !injected++) { errno = EAGAIN; return -1; }
    if (arm("fork2") && injected++ == 1) { errno = EAGAIN; return -1; }
    return (pid_t)syscall(SYS_fork);
}
int __wrap_setsid(void)
{
    if (arm("setsid")) { errno = EPERM; return -1; }
    return (int)syscall(SYS_setsid);
}
int __wrap_chdir(const char *path)
{
    if (arm("chdir")) { errno = EACCES; return -1; }
    return (int)syscall(SYS_chdir, path);
}
int __wrap_open(const char *path, int flags, ...)
{
    mode_t mode = 0;
    if (flags & O_CREAT) { va_list ap; va_start(ap, flags); mode = va_arg(ap, int); va_end(ap); }
    if (arm("open") && strcmp(path, "/dev/null") == 0) { errno = EMFILE; return -1; }
    return (int)syscall(SYS_openat, AT_FDCWD, path, flags, mode);
}
int __wrap_dup2(int oldfd, int newfd)
{
    if (arm("dup2")) { errno = EBADF; return -1; }
    return (int)syscall(SYS_dup2, oldfd, newfd);
}
int __wrap_execvp(const char *file, char *const argv[])
{
    if (arm("execvp")) { errno = ENOENT; return -1; }
    extern int __real_execvp(const char *, char *const []);
    return __real_execvp(file, argv);
}
ssize_t __wrap_read(int fd, void *buf, size_t n)
{
    if (arm("read") && !injected++) { errno = EINTR; return -1; }
    return (ssize_t)syscall(SYS_read, fd, buf, n);
}
ssize_t __wrap_write(int fd, const void *buf, size_t n)
{
    if (arm("write") && !injected++) { errno = EINTR; return -1; }
    return (ssize_t)syscall(SYS_write, fd, buf, n);
}
pid_t __wrap_waitpid(pid_t pid, int *status, int options)
{
    if (arm("waitpid") && !injected++) { errno = EINTR; return -1; }
    return (pid_t)syscall(SYS_wait4, pid, status, options, NULL);
}

#define CHECK(expr, message) do { \
    ++checks; \
    if (!(expr)) { fprintf(stderr, "FAIL: %s (errno=%d)\n", message, errno); \
        ++failures; } \
} while (0)
static int spawn(char *const argv[], const char *cwd)
{
    return coyote_detach_spawn(argv, cwd);
}

static int wait_file(const char *path, int milliseconds)
{
    struct timespec pause = {0, 10000000};
    for (int i = 0; i < milliseconds / 10; ++i) {
        if (access(path, F_OK) == 0)
            return 1;
        nanosleep(&pause, NULL);
    }
    return access(path, F_OK) == 0;
}

static int fd_count(void)
{
    int count = 0;
    for (int i = 0; i < 256; ++i) {
        errno = 0;
        if (syscall(SYS_fcntl, i, F_GETFD, 0) >= 0 || errno != EBADF)
            ++count;
    }
    return count;
}

static int inspect_stdio(const char *result)
{
    char temporary[600];
    int fd;
    int okay = 1;
    if (snprintf(temporary, sizeof temporary, "%s.tmp", result) >=
        (int)sizeof temporary)
        return 0;
    fd = open(temporary, O_WRONLY | O_CREAT | O_EXCL, 0600);
    if (fd < 0) return 0;
    for (int i = 0; i <= STDERR_FILENO; ++i) {
        struct stat st;
        char link[128], target[256];
        ssize_t n;
        snprintf(link, sizeof link, "/proc/self/fd/%d", i);
        n = readlink(link, target, sizeof target - 1);
        if (fstat(i, &st) < 0 || !S_ISCHR(st.st_mode) ||
            st.st_rdev != makedev(1, 3) || n < 0)
            okay = 0;
        else {
            target[n] = '\0';
            if (strcmp(target, "/dev/null") != 0) okay = 0;
        }
    }
    if (write(fd, okay ? "OK\n" : "BAD\n", okay ? 3 : 4) < 0) okay = 0;
    if (fsync(fd) < 0) okay = 0;
    if (close(fd) < 0) okay = 0;
    if (rename(temporary, result) < 0) okay = 0;
    if (!okay) unlink(temporary);
    return okay;
}

static void script(const char *path, const char *body, mode_t mode)
{
    int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, mode);
    if (fd < 0 || write(fd, body, strlen(body)) != (ssize_t)strlen(body)) {
        perror("write script");
        ++failures;
    }
    if (fd >= 0) close(fd);
    if (chmod(path, mode) < 0) { perror("chmod"); ++failures; }
}

int main(int argc, char **argv)
{
    char mark[512], initial_mark[512], executable[512], nonexec[512], space_dir[512];
    char fds_mark[512], self[512];
    char *exit_nonzero[] = {"/bin/sh", "-c", "exit 37", NULL};
    char *wait_mark[5];
    char *bad_exec[] = {"/definitely/missing/coyote-executable", NULL};
    char *bad_cwd[] = {"/bin/true", NULL};
    char *run_file[2];
    char *check_fds[4];
    char *long_run[6];
    pid_t probe;
    int status;

    if (argc == 3 && strcmp(argv[1], "--inspect-stdio") == 0)
        return inspect_stdio(argv[2]) ? 0 : 1;
    if (argc == 3 && strcmp(argv[1], "--fault") == 0) {
        char *success[] = {"/bin/true", NULL};
        char *failure[] = {"/definitely/missing/coyote-fault-target", NULL};
        const char *name = argv[2];
        int expect_failure = strcmp(name, "pipe2") == 0 ||
            strcmp(name, "fcntl") == 0 || strcmp(name, "fork") == 0 ||
            strcmp(name, "fork2") == 0 || strcmp(name, "setsid") == 0 ||
            strcmp(name, "chdir") == 0 || strcmp(name, "open") == 0 ||
            strcmp(name, "dup2") == 0 || strcmp(name, "execvp") == 0 ||
            strcmp(name, "write") == 0;
        int expected_errno = strcmp(name, "pipe2") == 0 ||
            strcmp(name, "fcntl") == 0 || strcmp(name, "open") == 0
            ? EMFILE : strcmp(name, "fork") == 0 || strcmp(name, "fork2") == 0
            ? EAGAIN : strcmp(name, "setsid") == 0 ? EPERM
            : strcmp(name, "chdir") == 0 ? EACCES
            : strcmp(name, "dup2") == 0 ? EBADF
            : strcmp(name, "write") == 0 || strcmp(name, "execvp") == 0
            ? ENOENT : 0;
        char *const *args = strcmp(name, "write") == 0 ? failure : success;        const char *cwd = strcmp(name, "chdir") == 0 ? "/" : NULL;
        fault = name;
        int before = -1;
        if (strcmp(name, "fcntl") == 0) {
            close(0); close(1); close(2);
            before = fd_count();
            injected = 0;
        }
        errno = 0;
        int result = coyote_detach_spawn((char *const *)args, cwd);
        int okay = expect_failure
            ? result == -1 && errno == expected_errno
            : result == 0;
        if (strcmp(name, "fcntl") == 0 && fd_count() != before)
            okay = 0;
        return okay ? 0 : 1;
    }
    {
        ssize_t self_length = readlink("/proc/self/exe", self, sizeof self - 1);
        if (self_length < 0) {
            perror("readlink /proc/self/exe"); return 2;
        }
        self[self_length] = '\0';
    }
    if (mkdtemp(root) == NULL) { perror("mkdtemp"); return 2; }
    snprintf(mark, sizeof mark, "%s/marker", root);
    snprintf(initial_mark, sizeof initial_mark, "%s", mark);
    snprintf(executable, sizeof executable, "%s/worker", root);
    snprintf(nonexec, sizeof nonexec, "%s/not-executable", root);
    snprintf(space_dir, sizeof space_dir, "%s/dir with spaces", root);
    if (mkdir(space_dir, 0700) < 0) { perror("mkdir"); ++failures; }
    script(executable, "#!/bin/sh\nprintf '%s' \"$PWD\" > \"$1\"\nexit 37\n", 0700);
    script(nonexec, "#!/bin/sh\nexit 0\n", 0600);

    CHECK(spawn(exit_nonzero, NULL) == 0, "successful exec returning nonzero");
    errno = 0;
    CHECK(spawn(bad_exec, NULL) == -1 && errno == ENOENT,
          "missing executable reports ENOENT");
    {
        char *denied[] = {nonexec, NULL};
        errno = 0;
        CHECK(spawn(denied, NULL) == -1 && errno == EACCES,
              "non-executable file reports EACCES");
    }
    errno = 0;
    CHECK(spawn(bad_cwd, "/no/such/coyote-working-directory") == -1 &&
          errno == ENOENT, "invalid cwd reports ENOENT");
    run_file[0] = nonexec; run_file[1] = NULL;
    CHECK(spawn(run_file, NULL) == -1, "non-executable file is reported");

    wait_mark[0] = executable; wait_mark[1] = mark; wait_mark[2] = NULL;
    CHECK(spawn(wait_mark, space_dir) == 0, "cwd containing spaces execs");
    CHECK(wait_file(mark, 2000), "child wrote marker after exec");
    {
        char actual[512];
        int fd = open(mark, O_RDONLY);
        ssize_t n = fd < 0 ? -1 : read(fd, actual, sizeof actual - 1);
        if (fd >= 0) close(fd);
        if (n >= 0) actual[n] = '\0';
        CHECK(n >= 0 && strcmp(actual, space_dir) == 0,
              "cwd with spaces preserved exactly");
    }

    snprintf(fds_mark, sizeof fds_mark, "%s/fds", root);
    check_fds[0] = self; check_fds[1] = "--inspect-stdio";
    check_fds[2] = fds_mark; check_fds[3] = NULL;
    CHECK(spawn(check_fds, NULL) == 0, "stdio probe exec succeeds");
    CHECK(wait_file(fds_mark, 2000), "stdio probe publishes result");
    {
        char actual[16] = {0};
        int fd = open(fds_mark, O_RDONLY);
        ssize_t n = fd < 0 ? -1 : read(fd, actual, sizeof actual - 1);
        if (fd >= 0) close(fd);
        CHECK(n == 3 && strcmp(actual, "OK\n") == 0,
              "child fstat/readlink confirms stdin/out/err are /dev/null");
    }

    long_run[0] = "/bin/sh"; long_run[1] = "-c";
    snprintf(mark, sizeof mark, "%s/long-run-done", root);
    long_run[2] = "sleep 2; : > \"$1\"";
    long_run[3] = "coyote-long-run"; long_run[4] = mark;
    long_run[5] = NULL;
    {
        struct timespec start, end;
        clock_gettime(CLOCK_MONOTONIC, &start);
        CHECK(spawn(long_run, NULL) == 0, "long-lived child exec succeeds");
        clock_gettime(CLOCK_MONOTONIC, &end);
        CHECK((end.tv_sec - start.tv_sec) * 1000 +
              (end.tv_nsec - start.tv_nsec) / 1000000 < 1000,
              "spawn returns before application exits");
        CHECK(wait_file(mark, 4000), "long-lived child completes marker");
    }

    /* Closing stdio forces pipe allocation to use descriptors 0/1/2. */
    probe = fork();
    if (probe == 0) {
        close(0); close(1); close(2);
        _exit(spawn(exit_nonzero, NULL) == 0 ? 0 : 1);
    }
    CHECK(probe >= 0 && waitpid(probe, &status, 0) >= 0 &&
          WIFEXITED(status) && WEXITSTATUS(status) == 0,
          "closed standard descriptors do not overwrite protocol");
    {
        const char *faults[] = {"pipe2", "fcntl", "fork", "fork2", "setsid",
                                "chdir", "open", "dup2", "execvp", "read",
                                "write", "waitpid"};
        for (size_t i = 0; i < sizeof faults / sizeof faults[0]; ++i) {
            pid_t f = fork();
            if (f == 0) {
                execl(self, self, "--fault", faults[i], (char *)NULL);
                _exit(125);
            }
            CHECK(f >= 0 && waitpid(f, &status, 0) >= 0 &&
                  WIFEXITED(status) && WEXITSTATUS(status) == 0,
                  faults[i]);        }
    }

    /* Confirm this process has no waitable direct children left. */
    errno = 0;
    CHECK(waitpid(-1, &status, WNOHANG) == -1 && errno == ECHILD,
          "intermediate children are reaped");
    unlink(executable); unlink(nonexec); unlink(mark); unlink(initial_mark);
    unlink(fds_mark);
    rmdir(space_dir); rmdir(root);
    if (failures != 0) return 1;
    printf("%d native detached-spawn checks passed\n", checks);    return 0;
}
