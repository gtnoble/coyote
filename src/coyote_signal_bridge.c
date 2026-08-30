/*  coyote_process_control.c — async-signal-safe shutdown bridge. */
#define _GNU_SOURCE
#include "coyote_signal_bridge.h"

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>

#define MAX_PROCESSES 8192

typedef struct {
    pid_t pid;
    pid_t parent;
} process_record;

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

static int read_process_record(const char *name, process_record *record)
{
    char path[64];
    char line[4096];
    char *close_name;
    char state;
    long parent;
    FILE *file;

    if (name == NULL || record == NULL)
        return 0;
    record->pid = (pid_t)strtol(name, NULL, 10);
    if (record->pid <= 0)
        return 0;

    (void)snprintf(path, sizeof path, "/proc/%ld/stat", (long)record->pid);
    file = fopen(path, "r");
    if (file == NULL)
        return 0;
    if (fgets(line, sizeof line, file) == NULL) {
        fclose(file);
        return 0;
    }
    fclose(file);

    close_name = strrchr(line, ')');
    if (close_name == NULL
        || sscanf(close_name + 2, "%c %ld", &state, &parent) != 2)
        return 0;

    record->parent = (pid_t)parent;
    return 1;
}

static size_t collect_processes(process_record *records)
{
    DIR *directory;
    struct dirent *entry;
    size_t count = 0;
    process_record record;

    directory = opendir("/proc");
    if (directory == NULL)
        return 0;

    while ((entry = readdir(directory)) != NULL && count < MAX_PROCESSES) {
        if (read_process_record(entry->d_name, &record))
            records[count++] = record;
    }
    closedir(directory);
    return count;
}

static int is_descendant(pid_t pid, pid_t root,
                         const process_record *records, size_t count)
{
    size_t i;
    size_t depth;
    pid_t current = pid;

    for (depth = 0; depth < MAX_PROCESSES && current > 1; depth++) {
        if (current == root)
            return 1;
        for (i = 0; i < count; i++) {
            if (records[i].pid == current) {
                current = records[i].parent;
                break;
            }
        }
        if (i == count)
            break;
    }
    return current == root;
}

int coyote_signal_group_tree(int root_pid, int signal_number)
{
    process_record *records;
    size_t count;
    size_t i;

    if (root_pid <= 0)
        return -1;

    records = calloc(MAX_PROCESSES, sizeof *records);
    if (records == NULL)
        return -1;
    count = collect_processes(records);

    /* The root is a setsid-created process-group leader. */
    (void)kill((pid_t)-root_pid, signal_number);

    /* Nested coyote processes may have created their own setsid groups. */
    for (i = 0; i < count; i++) {
        if (records[i].pid == (pid_t)root_pid
            || !is_descendant(records[i].pid, (pid_t)root_pid,
                              records, count))
            continue;
        (void)kill(records[i].pid, signal_number);
        if (getpgid(records[i].pid) == records[i].pid)
            (void)kill((pid_t)-records[i].pid, signal_number);
    }

    free(records);
    return 0;
}
