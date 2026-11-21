#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

/*
 * Internal persistence boundary: parent must be a trusted, fully-resolved,
 * absolute session directory. This module does not create or resolve parent.
 * Writers coordinate through the UUID-specific lock file; readers see the
 * old or new manifest through atomic rename. Processes modifying these
 * paths without that cooperative lock are unsupported.
 */

enum { STORE_OK = 0, STORE_MISSING = 1, STORE_BUSY = 2,
       STORE_INVALID = 3, STORE_IO = 4, STORE_UNCERTAIN = 5 };

static int valid_uuid(const char *uuid)
{
   size_t i;
   if (uuid == NULL || strlen(uuid) != 36)
      return 0;
   for (i = 0; i < 36; ++i)
   {
      if (i == 8 || i == 13 || i == 18 || i == 23)
      {
         if (uuid[i] != '-')
            return 0;
      }
      else if (!((uuid[i] >= '0' && uuid[i] <= '9') ||
                 (uuid[i] >= 'a' && uuid[i] <= 'f')))
         return 0;
   }
   return 1;
}

static int classify_errno(int error)
{
   if (error == ENOENT)
      return STORE_MISSING;
   if (error == ELOOP || error == ENOTDIR || error == EACCES ||
       error == EPERM || error == EINVAL || error == EFBIG ||
       error == EOVERFLOW)
      return STORE_INVALID;
   return STORE_IO;
}

static int valid_private_stat(const struct stat *st, int directory,
                              int allow_unlinked)
{
   mode_t forbidden = S_IRWXG | S_IRWXO | S_ISUID | S_ISGID | S_ISVTX;
   if (st->st_uid != geteuid() || (st->st_mode & forbidden) != 0)
      return 0;
   if (directory)
   {
      if (!S_ISDIR(st->st_mode) || (st->st_mode & S_IRWXU) != S_IRWXU)
         return 0;
   }
   else if (!S_ISREG(st->st_mode))
      return 0;
   if (!directory && ((st->st_mode & 0777) != 0600 ||
       (st->st_nlink != 1 && !(allow_unlinked && st->st_nlink == 0))))
      return 0;
   return 1;
}

static int open_parent(const char *parent)
{
   if (parent == NULL || parent[0] != '/')
   {
      errno = EINVAL;
      return -1;
   }
   return open(parent, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
}

static int classify_parent_errno(int error)
{
   if (error == ENOENT || error == ENOTDIR || error == ELOOP ||
       error == EACCES || error == EPERM || error == EINVAL)
      return STORE_INVALID;
   return STORE_IO;
}

static int acquire_lock(int dir, int *lock_fd)
{
   const int flags = O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK | O_RDWR;
   struct stat st;
   int fd = openat(dir, ".writer", flags | O_CREAT | O_EXCL, 0600);
   if (fd >= 0)
   {
      if (fchmod(fd, 0600) < 0)
      {
         close(fd);
         return STORE_IO;
      }
   }
   else if (errno == EEXIST)
      fd = openat(dir, ".writer", flags);
   if (fd < 0)
      return classify_parent_errno(errno);
   if (fstat(fd, &st) < 0)
   {
      close(fd);
      return STORE_IO;
   }
   if (!valid_private_stat(&st, 0, 0))
   {
      close(fd);
      return STORE_INVALID;
   }
   if (flock(fd, LOCK_EX | LOCK_NB) < 0)
   {
      int e = errno;
      close(fd);
      return e == EWOULDBLOCK || e == EAGAIN ? STORE_BUSY : STORE_IO;
   }
   *lock_fd = fd;
   return STORE_OK;
}

static int open_checked_manifest(int dir_fd, struct stat *st)
{
   int fd = openat(dir_fd, "canvas.json",
                   O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC);
   if (fd < 0)
      return -1;
   if (fstat(fd, st) < 0)
   {
      int e = errno;
      close(fd);
      errno = e;
      return -1;
   }
   /* Atomic replacement may have unlinked this already-open inode. */
   if (!valid_private_stat(st, 0, 1))
   {
      close(fd);
      errno = EINVAL;
      return -1;
   }
   return fd;
}

static int read_fd(int fd, size_t max, const struct stat *st,
                   char **data, size_t *len)
{
   char *buffer;
   size_t wanted;
   size_t done = 0;
   char extra;
   ssize_t n;
   if (st->st_size <= 0 || (uintmax_t) st->st_size > (uintmax_t) max)
      return STORE_INVALID;
   wanted = (size_t) st->st_size;
   buffer = malloc(wanted);
   if (buffer == NULL)
      return STORE_IO;
   while (done < wanted)
   {
      n = read(fd, buffer + done, wanted - done);
      if (n < 0 && errno == EINTR)
         continue;
      if (n <= 0)
      {
         free(buffer);
         return n == 0 ? STORE_INVALID : STORE_IO;
      }
      done += (size_t) n;
   }
   do
      n = read(fd, &extra, 1);
   while (n < 0 && errno == EINTR);
   if (n < 0)
   {
      free(buffer);
      return STORE_IO;
   }
   if (n != 0)
   {
      free(buffer);
      return STORE_INVALID;
   }
   *data = buffer;
   *len = wanted;
   return STORE_OK;
}

static int read_manifest(int dir_fd, size_t max, char **data, size_t *len)
{
   struct stat st;
   int fd = open_checked_manifest(dir_fd, &st);
   int result;
   if (fd < 0)
      return classify_errno(errno);
   result = read_fd(fd, max, &st, data, len);
   if (close(fd) < 0 && result == STORE_OK)
   {
      free(*data);
      *data = NULL;
      *len = 0;
      return STORE_IO;
   }
   return result;
}

int coyote_canvas_store_read(const char *parent, const char *uuid, size_t max,
                            char **data, size_t *len)
{
   char sidecar[64];
   int parent_fd, side_fd, result;
   struct stat st;
   *data = NULL;
   *len = 0;
   if (!valid_uuid(uuid))
      return STORE_INVALID;
   (void) snprintf(sidecar, sizeof sidecar, "%s.canvas", uuid);
   parent_fd = open_parent(parent);
   if (parent_fd < 0)
      return classify_parent_errno(errno);
   side_fd = openat(parent_fd, sidecar,
                    O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
   if (side_fd < 0)
      result = classify_errno(errno);
   else
   {
      if (fstat(side_fd, &st) < 0)
         result = STORE_IO;
      else if (!valid_private_stat(&st, 1, 0))
         result = STORE_INVALID;
      else
         result = read_manifest(side_fd, max, data, len);
      close(side_fd);
   }
   close(parent_fd);
   return result;
}

static int write_all(int fd, const char *data, size_t len)
{
   size_t done = 0;
   while (done < len)
   {
      ssize_t n = write(fd, data + done, len - done);
      if (n < 0 && errno == EINTR)
         continue;
      if (n <= 0)
         return -1;
      done += (size_t) n;
   }
   return 0;
}

static int open_or_create_sidecar(int parent_fd, const char *sidecar,
                                  int *side_fd)
{
   struct stat st;
   if (mkdirat(parent_fd, sidecar, 0700) < 0 && errno != EEXIST)
      return classify_errno(errno);
   if (fsync(parent_fd) < 0)
      return STORE_IO;
   *side_fd = openat(parent_fd, sidecar,
                     O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK);
   if (*side_fd < 0)
      return classify_errno(errno);
   if (fstat(*side_fd, &st) < 0)
   {
      int e = errno;
      close(*side_fd);
      *side_fd = -1;
      return classify_errno(e);
   }
   if (!valid_private_stat(&st, 1, 0))
   {
      close(*side_fd);
      *side_fd = -1;
      return STORE_INVALID;
   }
   return STORE_OK;
}

int coyote_canvas_store_write(const char *parent, const char *uuid,
                             const char *data, size_t len)
{
   char sidecar[64];
   int parent_fd, side_fd = -1, lock_fd = -1, temp_fd = -1;
   int result;
   int owns_temp = 0;
   struct stat st;
   static const char temp_name[] = ".canvas.tmp";

   if (!valid_uuid(uuid) || data == NULL || len == 0)
      return STORE_INVALID;
   (void) snprintf(sidecar, sizeof sidecar, "%s.canvas", uuid);
   parent_fd = open_parent(parent);
   if (parent_fd < 0)
      return classify_parent_errno(errno);
   result = open_or_create_sidecar(parent_fd, sidecar, &side_fd);
   if (result != STORE_OK)
      goto done;
   result = acquire_lock(side_fd, &lock_fd);
   if (result != STORE_OK)
      goto done;
   result = STORE_IO;
   if (fstatat(side_fd, "canvas.json", &st, AT_SYMLINK_NOFOLLOW) == 0)
   {
      if (!valid_private_stat(&st, 0, 0))
      {
         result = STORE_INVALID;
         goto done;
      }
   }
   else if (errno != ENOENT)
      goto done;
   /* Only a writer holding the lock may clean an interrupted temp file. */
   if (unlinkat(side_fd, temp_name, 0) < 0 && errno != ENOENT)
      goto done;
   temp_fd = openat(side_fd, temp_name,
                    O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0600);
   if (temp_fd < 0)
      goto done;
   owns_temp = 1;
   if (fchmod(temp_fd, 0600) < 0 || write_all(temp_fd, data, len) < 0 ||
       fsync(temp_fd) < 0)
      goto done;
   if (close(temp_fd) < 0)
   {
      temp_fd = -1;
      goto done;
   }
   temp_fd = -1;
   if (renameat(side_fd, temp_name, side_fd, "canvas.json") < 0)
      goto done;
   owns_temp = 0;
   result = fsync(side_fd) < 0 ? STORE_UNCERTAIN : STORE_OK;

done:
   if (temp_fd >= 0)
      close(temp_fd);
   if (owns_temp)
      (void) unlinkat(side_fd, temp_name, 0);
   if (lock_fd >= 0)
      close(lock_fd);
   if (side_fd >= 0)
      close(side_fd);
   close(parent_fd);
   return result == STORE_MISSING ? STORE_IO : result;
}
