/* Loaded only by the isolated session-publication worker. */
#define _GNU_SOURCE
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/syscall.h>

int fsync(int fd)
{
   static int saw_stage;
   const char *dir = getenv("COYOTE_PUBLICATION_TEST_DIR");
   const char *fault = getenv("COYOTE_PUBLICATION_TEST_FAULT");
   char fd_path[64], path[PATH_MAX];
   const char *step = NULL;
   ssize_t n;

   if (dir && fault)
   {
      (void)snprintf(fd_path, sizeof fd_path, "/proc/self/fd/%d", fd);
      n = readlink(fd_path, path, sizeof path - 1);
      if (n >= 0)
      {
         size_t len = strlen(dir);
         path[n] = '\0';
         if (strncmp(path, dir, len) == 0 &&
             strncmp(path + len, "/.coyote-session-", 17) == 0)
         {
            saw_stage = strcmp(fault, "stage") != 0;
            step = "stage";
         }
         else if (saw_stage && strcmp(path, dir) == 0)
            step = "directory";
      }
   }
   if (step)
   {
      int fail = strcmp(step, fault) == 0;
      (void)dprintf(STDERR_FILENO, "fsync %s %s\n", step, fail ? "fail" : "pass");
      if (fail)
      {
         errno = EIO;
         return -1;
      }
   }
   return (int)syscall(SYS_fsync, fd);
}
