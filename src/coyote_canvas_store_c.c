#define _GNU_SOURCE
#define _FILE_OFFSET_BITS 64
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <glib.h>
#include "coyote_canvas_tiles.h"
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

static int lock_entry(int dir, const char *name, int *lock_fd, int create)
{
   const int flags = O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK | O_RDWR;
   struct stat st;
   int fd;
   if (create)
   {
      fd = openat(dir, name, flags | O_CREAT | O_EXCL, 0600);
      if (fd >= 0)
      {
         if (fchmod(fd, 0600) < 0)
         {
            close(fd);
            return STORE_IO;
         }
      }
      else if (errno == EEXIST)
         fd = openat(dir, name, flags);
   }
   else
      fd = openat(dir, name, flags);
   if (fd < 0)
      return !create && errno == ENOENT ? STORE_OK : classify_parent_errno(errno);
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

static int acquire_lock(int dir, const char *name, int *lock_fd)
{
   return lock_entry(dir, name, lock_fd, 1);
}

static int open_checked(int dir_fd, const char *name, int manifest,
                        struct stat *st)
{
   int fd = openat(dir_fd, name,
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
   if (!valid_private_stat(st, 0, manifest))
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

static int read_entry(int dir_fd, const char *name, int manifest,
                      size_t max, char **data, size_t *len)
{
   struct stat st;
   int fd = open_checked(dir_fd, name, manifest, &st);
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

static int read_sidecar(const char *parent, const char *uuid,
                        const char *name, int manifest, size_t max,
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
         result = read_entry(side_fd, name, manifest, max, data, len);
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

/* Existing content-addressed files are never rewritten, even if corrupt. */
static int verify_asset(int dir, const char *name, const char *data, size_t len)
{
   struct stat st;
   int fd = open_checked(dir, name, 0, &st);
   int result = STORE_INVALID;
   size_t done = 0;
   char buffer[8192];
   if (fd < 0)
      return classify_errno(errno);
   if (st.st_size < 0 || (uintmax_t)st.st_size != (uintmax_t)len)
      goto done;
   while (done < len)
   {
      size_t want = len - done < sizeof buffer ? len - done : sizeof buffer;
      ssize_t n = read(fd, buffer, want);
      if (n < 0 && errno == EINTR)
         continue;
      if (n < 0)
      {
         result = STORE_IO;
         goto done;
      }
      if (n == 0 || memcmp(buffer, data + done, (size_t)n) != 0)
         goto done;
      done += (size_t)n;
   }
   result = fsync(fd) == 0 && fsync(dir) == 0 ? STORE_OK : STORE_IO;
done:
   close(fd);
   return result;
}

static int write_sidecar(const char *parent, const char *uuid,
                         const char *name, int manifest,
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
   result = acquire_lock(side_fd, ".writer", &lock_fd);
   if (result != STORE_OK)
      goto done;
   result = STORE_IO;
   if (fstatat(side_fd, name, &st, AT_SYMLINK_NOFOLLOW) == 0)
   {
      if (!valid_private_stat(&st, 0, 0))
      {
         result = STORE_INVALID;
         goto done;
      }
      if (!manifest)
      {
         result = verify_asset(side_fd, name, data, len);
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
   if ((manifest ? renameat(side_fd, temp_name, side_fd, name) :
        renameat2(side_fd, temp_name, side_fd, name, RENAME_NOREPLACE)) < 0)
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

#define TILE_MAX_BYTES (UINT64_C(16) + UINT64_C(4) * 32768 * 32768)
#define TILE_COPY_BLOCK 65536

static int valid_digest(const char *digest)
{
   return digest != NULL && strlen(digest) == 64 &&
      strspn(digest, "0123456789abcdef") == 64;
}

static int tile_name(const char *digest, char name[70])
{
   if (!valid_digest(digest))
      return 0;
   memcpy(name, digest, 64);
   memcpy(name + 64, ".tile", 6);
   return 1;
}

/* Hash exact bytes without changing the descriptor position. */
static int tile_hash_fd(int fd, char digest[65])
{
   struct coyote_canvas_tile_info info;
   struct stat st;
   unsigned char block[TILE_COPY_BLOCK];
   GChecksum *sum;
   uint64_t offset = 0;
   if (coyote_canvas_tiles_inspect(fd, &info) != COYOTE_TILE_OK ||
       fstat(fd, &st) < 0 || st.st_size <= 0 ||
       (uintmax_t)st.st_size > TILE_MAX_BYTES)
      return STORE_INVALID;
   sum = g_checksum_new(G_CHECKSUM_SHA256);
   if (sum == NULL)
      return STORE_IO;
   while (offset < (uint64_t)st.st_size)
   {
      size_t want = (uint64_t)sizeof block < (uint64_t)st.st_size - offset ?
         sizeof block : (size_t)((uint64_t)st.st_size - offset);
      ssize_t n;
      do
         n = pread(fd, block, want, (off_t)offset);
      while (n < 0 && errno == EINTR);
      if (n <= 0)
      {
         g_checksum_free(sum);
         return n == 0 ? STORE_INVALID : STORE_IO;
      }
      g_checksum_update(sum, block, (gsize)n);
      offset += (uint64_t)n;
   }
   memcpy(digest, g_checksum_get_string(sum), 65);
   g_checksum_free(sum);
   return STORE_OK;
}

int coyote_canvas_store_write_tile(const char *parent, const char *uuid,
                                   int source_fd, char digest[65])
{
   char sidecar[64], name[70], actual[65];
   int parent_fd = -1, side_fd = -1, lock_fd = -1, temp_fd = -1;
   int result = STORE_IO, owns_temp = 0;
   struct coyote_canvas_tile_info info;
   struct stat source_st, existing_st;
   unsigned char block[TILE_COPY_BLOCK];
   uint64_t offset = 0;
   GChecksum *sum = NULL;
   static const char temp_name[] = ".canvas.tmp";
   if (!valid_uuid(uuid) || source_fd < 0 || digest == NULL ||
       coyote_canvas_tiles_inspect(source_fd, &info) != COYOTE_TILE_OK ||
       fstat(source_fd, &source_st) < 0 || source_st.st_size <= 0 ||
       (uintmax_t)source_st.st_size > TILE_MAX_BYTES)
      return STORE_INVALID;
   (void)snprintf(sidecar, sizeof sidecar, "%s.canvas", uuid);
   parent_fd = open_parent(parent);
   if (parent_fd < 0)
      return classify_parent_errno(errno);
   result = open_or_create_sidecar(parent_fd, sidecar, &side_fd);
   if (result != STORE_OK)
      goto done;
   result = acquire_lock(side_fd, ".writer", &lock_fd);
   if (result != STORE_OK)
      goto done;
   result = STORE_IO;
   if (unlinkat(side_fd, temp_name, 0) < 0 && errno != ENOENT)
      goto done;
   temp_fd = openat(side_fd, temp_name,
                    O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0600);
   if (temp_fd < 0)
      goto done;
   owns_temp = 1;
   if (fchmod(temp_fd, 0600) < 0)
      goto done;
   sum = g_checksum_new(G_CHECKSUM_SHA256);
   if (sum == NULL)
      goto done;
   while (offset < (uint64_t)source_st.st_size)
   {
      size_t want = (uint64_t)sizeof block < (uint64_t)source_st.st_size - offset ?
         sizeof block : (size_t)((uint64_t)source_st.st_size - offset);
      ssize_t n;
      do
         n = pread(source_fd, block, want, (off_t)offset);
      while (n < 0 && errno == EINTR);
      if (n <= 0)
      {
         result = n == 0 ? STORE_INVALID : STORE_IO;
         goto done;
      }
      if (write_all(temp_fd, (const char *)block, (size_t)n) < 0)
         goto done;
      g_checksum_update(sum, block, (gsize)n);
      offset += (uint64_t)n;
   }
   memcpy(actual, g_checksum_get_string(sum), sizeof actual);
   if (coyote_canvas_tiles_inspect(temp_fd, &info) != COYOTE_TILE_OK ||
       fsync(temp_fd) < 0)
      goto done;
   if (close(temp_fd) < 0)
   {
      temp_fd = -1;
      goto done;
   }
   temp_fd = -1;
   if (!tile_name(actual, name))
   {
      result = STORE_IO;
      goto done;
   }
   if (fstatat(side_fd, name, &existing_st, AT_SYMLINK_NOFOLLOW) == 0)
   {
      char existing_digest[65];
      int existing = open_checked(side_fd, name, 0, &existing_st);
      result = STORE_INVALID;
      if (existing >= 0)
      {
         result = tile_hash_fd(existing, existing_digest);
         if (result == STORE_OK && strcmp(existing_digest, actual) != 0)
            result = STORE_INVALID;
         if (result == STORE_OK && (fsync(existing) < 0 || fsync(side_fd) < 0))
            result = STORE_IO;
         close(existing);
      }
      if (result == STORE_OK)
         memcpy(digest, actual, sizeof actual);
      goto done;
   }
   if (errno != ENOENT)
      goto done;
   if (renameat2(side_fd, temp_name, side_fd, name, RENAME_NOREPLACE) < 0)
   {
      if (errno == EEXIST)
      {
         struct stat race_st;
         int existing = open_checked(side_fd, name, 0, &race_st);
         char existing_digest[65];
         result = existing < 0 ? classify_errno(errno) :
            tile_hash_fd(existing, existing_digest);
         if (existing >= 0)
         {
            if (result == STORE_OK && strcmp(existing_digest, actual) != 0)
               result = STORE_INVALID;
            if (result == STORE_OK && (fsync(existing) < 0 || fsync(side_fd) < 0))
               result = STORE_IO;
            close(existing);
         }
         if (result == STORE_OK)
            memcpy(digest, actual, sizeof actual);
      }
      goto done;
   }
   owns_temp = 0;
   result = fsync(side_fd) < 0 ? STORE_UNCERTAIN : STORE_OK;
   if (result == STORE_OK)
      memcpy(digest, actual, sizeof actual);

done:
   if (sum != NULL)
      g_checksum_free(sum);
   if (temp_fd >= 0)
      close(temp_fd);
   if (owns_temp && side_fd >= 0)
      (void)unlinkat(side_fd, temp_name, 0);
   if (lock_fd >= 0)
      close(lock_fd);
   if (side_fd >= 0)
      close(side_fd);
   if (parent_fd >= 0)
      close(parent_fd);
   return result == STORE_MISSING ? STORE_IO : result;
}

static int open_tile(const char *parent, const char *uuid,
                                  const char *digest, int verify, int *fd)
{
   char sidecar[64], name[70], actual[65];
   struct stat st;
   int parent_fd, side_fd = -1, tile_fd = -1, result;
   if (fd == NULL)
      return STORE_INVALID;
   *fd = -1;
   if (!valid_uuid(uuid) || !tile_name(digest, name))
      return STORE_INVALID;
   (void)snprintf(sidecar, sizeof sidecar, "%s.canvas", uuid);
   parent_fd = open_parent(parent);
   if (parent_fd < 0)
      return classify_parent_errno(errno);
   side_fd = openat(parent_fd, sidecar,
                    O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
   if (side_fd < 0)
   {
      result = classify_errno(errno);
      goto done;
   }
   if (fstat(side_fd, &st) < 0)
   {
      result = STORE_IO;
      goto done;
   }
   if (!valid_private_stat(&st, 1, 0))
   {
      result = STORE_INVALID;
      goto done;
   }
   tile_fd = open_checked(side_fd, name, 0, &st);
   if (tile_fd < 0)
   {
      result = classify_errno(errno);
      goto done;
   }
   if (verify) {
      result = tile_hash_fd(tile_fd, actual);
      if (result == STORE_OK && strcmp(actual, digest) != 0)
         result = STORE_INVALID;
   } else {
      struct coyote_canvas_tile_info info;
      result = coyote_canvas_tiles_inspect(tile_fd, &info) == COYOTE_TILE_OK ?
         STORE_OK : STORE_INVALID;
   }
   if (result == STORE_OK && lseek(tile_fd, 0, SEEK_SET) < 0)
      result = STORE_IO;
   if (result == STORE_OK)
   {
      *fd = tile_fd;
      tile_fd = -1;
   }
done:
   if (tile_fd >= 0)
      close(tile_fd);
   if (side_fd >= 0)
      close(side_fd);
   close(parent_fd);
   return result;
}

int coyote_canvas_store_open_tile(const char *parent, const char *uuid,
                                  const char *digest, int *fd)
{
   return open_tile(parent, uuid, digest, 1, fd);
}

int coyote_canvas_store_open_validated_tile(const char *parent,
                                            const char *uuid,
                                            const char *digest, int *fd)
{
   return open_tile(parent, uuid, digest, 0, fd);
}

static int asset_name(const char *digest, char name[70])
{
   if (strlen(digest) != 64 ||
       strspn(digest, "0123456789abcdef") != 64)
      return 0;
   memcpy(name, digest, 64);
   memcpy(name + 64, ".rgba", 6);
   return 1;
}

int coyote_canvas_store_read(const char *parent, const char *uuid, size_t max,
                             char **data, size_t *len)
{
   return read_sidecar(parent, uuid, "canvas.json", 1, max, data, len);
}

int coyote_canvas_store_write(const char *parent, const char *uuid,
                              const char *data, size_t len)
{
   return write_sidecar(parent, uuid, "canvas.json", 1, data, len);
}

int coyote_canvas_store_read_asset(const char *parent, const char *uuid,
                                   const char *digest, size_t max,
                                   char **data, size_t *len)
{
   char name[70];
   *data = NULL;
   *len = 0;
   if (!asset_name(digest, name))
      return STORE_INVALID;
   return read_sidecar(parent, uuid, name, 0, max, data, len);
}

int coyote_canvas_store_write_asset(const char *parent, const char *uuid,
                                    const char *digest,
                                    const char *data, size_t len)
{
   char name[70];
   if (!asset_name(digest, name))
      return STORE_INVALID;
   return write_sidecar(parent, uuid, name, 0, data, len);
}

/* Long-lived lease for GTK Canvas owners. The short publication lock
 * remains independent. This lease does not authorize JSONL writes. */
int coyote_canvas_store_claim(const char *parent, const char *uuid, int *lease)
{
   char sidecar[64];
   int dir, side = -1, result;
   *lease = -1;
   if (!valid_uuid(uuid))
      return STORE_INVALID;
   (void)snprintf(sidecar, sizeof sidecar, "%s.canvas", uuid);
   dir = open_parent(parent);
   if (dir < 0)
      return classify_parent_errno(errno);
   result = open_or_create_sidecar(dir, sidecar, &side);
   if (result == STORE_OK)
      result = acquire_lock(side, ".gtk-writer", lease);
   if (side >= 0)
      close(side);
   close(dir);
   return result;
}

/* Shared with JSONL writers. Keep this inode outside the removable Canvas
 * sidecar, and never unlink it when releasing a lock. */
int coyote_session_transaction_lock(const char *parent, const char *id,
                                    int *guard)
{
   char name[96];
   int dir, result;
   *guard = -1;
   if (!valid_uuid(id) &&
       !(strlen(id) == 64 && strspn(id, "0123456789abcdef") == 64))
      return 2;
   (void)snprintf(name, sizeof name, ".%s.session-writer", id);
   dir = open_parent(parent);
   if (dir < 0)
      return 2;
   result = acquire_lock(dir, name, guard);
   close(dir);
   return result == STORE_OK ? 0 : (result == STORE_BUSY ? 1 : 2);
}

/* Existing storage aliases are supported. mkdirat never replaces an
 * entry: if the name is a dangling link, open still fails after EEXIST. */
static int open_session_child(int dir, const char *name)
{
   int flags = O_RDONLY | O_DIRECTORY | O_CLOEXEC;
   int child = openat(dir, name, flags);
   if (child >= 0 || errno != ENOENT)
      return child;
   if (mkdirat(dir, name, 0700) < 0 && errno != EEXIST)
      return -1;
   return openat(dir, name, flags);
}

/* Prepare exactly HOME/.coyote/sessions/<project>. Sync the three parents
 * bottom-up even when they already existed: a prior attempt or concurrent
 * creator may have made a directory visible without syncing its parent.
 * The project directory itself is synced after publishing the log. */
int coyote_session_prepare_directory(const char *home, const char *project)
{
   const char *names[] = { ".coyote", "sessions", project };
   int fds[] = { -1, -1, -1, -1 };
   int result = -1;
   if (!project[0] || strchr(project, '/') || strcmp(project, ".") == 0 ||
       strcmp(project, "..") == 0)
      return -1;
   fds[0] = open_parent(home);
   if (fds[0] < 0)
      return -1;
   for (size_t i = 0; i < 3; ++i)
   {
      fds[i + 1] = open_session_child(fds[i], names[i]);
      if (fds[i + 1] < 0)
         goto done;
   }
   for (int i = 2; i >= 0; --i)
      if (fsync(fds[i]) < 0)
         goto done;
   result = 0;

done:
   for (int i = 3; i >= 0; --i)
      if (fds[i] >= 0)
         close(fds[i]);
   return result;
}

int coyote_session_stage(char *path)
{
   return mkostemp(path, O_CLOEXEC);
}

enum { LOG_DURABLE = 0, LOG_NOT_PUBLISHED = 1, LOG_UNCERTAIN = 2 };

/* Caller holds the target's guard. Both names must be siblings in the
 * resolved directory. Open it before rename; a failure to open or sync the
 * stage leaves the destination untouched. A failed sync AFTER rename does
 * not undo publication, and the caller must keep any referenced Canvas. */
static int publish_log(const char *stage, const char *target, int replace)
{
   const char *from = strrchr(stage, '/');
   const char *to = strrchr(target, '/');
   struct stat st;
   int dir, fd, synced, result = LOG_NOT_PUBLISHED;
   if (stage[0] != '/' || !from || !to || !from[1] || !to[1] ||
       from - stage != to - target || memcmp(stage, target, (size_t)(to - target)) ||
       strcmp(from + 1, to + 1) == 0)
      return result;
   if (to == target)
      dir = open_parent("/");
   else
   {
      char *parent = strndup(target, (size_t)(to - target));
      if (!parent)
         return result;
      dir = open_parent(parent);
      free(parent);
   }
   if (dir < 0)
      return result;
   if (replace && (fstatat(dir, to + 1, &st, AT_SYMLINK_NOFOLLOW) < 0 ||
       !S_ISREG(st.st_mode) || st.st_nlink != 1 || st.st_uid != geteuid()))
      goto done;
   fd = open_checked(dir, from + 1, 0, &st);
   if (fd < 0)
      goto done;
   synced = fsync(fd);
   if (close(fd) < 0 || synced < 0)
      goto done;
   if (renameat2(dir, from + 1, dir, to + 1,
                 replace ? 0 : RENAME_NOREPLACE) == 0)
      result = fsync(dir) == 0 ? LOG_DURABLE : LOG_UNCERTAIN;

done:
   close(dir);
   return result;
}

int coyote_session_publish(const char *stage, const char *target)
{
   return publish_log(stage, target, 0);
}

int coyote_session_replace(const char *stage, const char *target)
{
   return publish_log(stage, target, 1);
}

/* Caller holds the existing session guard. */
int coyote_session_sync(const char *target)
{
   int fd = open(target, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK);
   if (fd < 0)
      return 2;
   struct stat st;
   int result = fstat(fd, &st) == 0 && S_ISREG(st.st_mode) && fsync(fd) == 0;
   return close(fd) == 0 && result ? 0 : 2;
}

/* Callers hold the session transaction guard. A new fork must not adopt or
 * overwrite an existing sidecar, even if its JSONL does not exist. */
int coyote_canvas_reserve_fork(const char *parent, const char *uuid)
{
   char sidecar[64], log[64];
   struct stat st;
   int dir, result;
   if (!valid_uuid(uuid))
      return STORE_INVALID;
   (void)snprintf(sidecar, sizeof sidecar, "%s.canvas", uuid);
   (void)snprintf(log, sizeof log, "%s.jsonl", uuid);
   dir = open_parent(parent);
   if (dir < 0)
      return classify_parent_errno(errno);
   if (fstatat(dir, log, &st, AT_SYMLINK_NOFOLLOW) == 0)
      result = STORE_INVALID;
   else if (errno != ENOENT)
      result = STORE_IO;
   else if (mkdirat(dir, sidecar, 0700) < 0)
      result = errno == EEXIST ? STORE_INVALID : classify_errno(errno);
   else
      /* The first workspace write syncs this directory entry. */
      result = STORE_OK;
   close(dir);
   return result;
}

static int raster_entry(const char *name)
{
   return strlen(name) == 69 && strcmp(name + 64, ".rgba") == 0 &&
      strspn(name, "0123456789abcdef") == 64;
}

static int tile_entry(const char *name)
{
   return strlen(name) == 69 && strcmp(name + 64, ".tile") == 0 &&
      strspn(name, "0123456789abcdef") == 64;
}

static int asset_entry(const char *name)
{
   return raster_entry(name) || tile_entry(name);
}

static int known_canvas_entry(const char *name)
{
   if (strcmp(name, "canvas.json") == 0 || strcmp(name, ".canvas.tmp") == 0 ||
       strcmp(name, ".gtk-writer") == 0 || strcmp(name, ".writer") == 0)
      return 1;
   return asset_entry(name);
}

/* No recursion and no symlink traversal. Inspect every entry before the
 * visible deletion, so an unfamiliar layout does not cause data loss. */
static int scan_canvas(DIR *stream, int remove)
{
   int fd = dirfd(stream);
   for (;;)
   {
      struct dirent *entry;
      struct stat st;
      errno = 0;
      entry = readdir(stream);
      if (entry == NULL)
         return errno == 0 ? STORE_OK : STORE_IO;
      if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
         continue;
      if (!known_canvas_entry(entry->d_name))
         return STORE_INVALID;
      if (fstatat(fd, entry->d_name, &st, AT_SYMLINK_NOFOLLOW) < 0)
         return STORE_IO;
      if (!valid_private_stat(&st, 0, 0))
         return STORE_INVALID;
      if (remove && unlinkat(fd, entry->d_name, 0) < 0)
         return STORE_IO;
   }
}

/* A null sidecar key (empty string) denotes a non-Canvas legacy log.
 * An empty log denotes rollback of a freshly reserved, unpublished fork. */
int coyote_canvas_remove_session(const char *parent, const char *uuid,
                                 const char *log)
{
   char sidecar[64];
   struct stat st;
   DIR *stream = NULL;
   int dir, side = -1, editor = -1, writer = -1;
   int result = STORE_INVALID;
   int has_log = log[0] != '\0';
   if ((uuid[0] != '\0' && !valid_uuid(uuid)) ||
       (has_log && (strchr(log, '/') || strlen(log) < 7 ||
        strcmp(log + strlen(log) - 6, ".jsonl") != 0)) ||
       (!has_log && !valid_uuid(uuid)))
      return STORE_INVALID;
   dir = open_parent(parent);
   if (dir < 0)
      return classify_parent_errno(errno);
   if (has_log)
   {
      if (fstatat(dir, log, &st, AT_SYMLINK_NOFOLLOW) < 0)
      {
         result = classify_errno(errno);
         goto done;
      }
      if (!S_ISREG(st.st_mode) || st.st_uid != geteuid() || st.st_nlink != 1)
         goto done;
   }
   if (uuid[0] != '\0')
   {
      (void)snprintf(sidecar, sizeof sidecar, "%s.canvas", uuid);
      side = openat(dir, sidecar, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
      if (side < 0 && errno != ENOENT)
      {
         result = classify_errno(errno);
         goto done;
      }
      if (side >= 0)
      {
         if (fstat(side, &st) < 0)
         {
            result = STORE_IO;
            goto done;
         }
         if (!valid_private_stat(&st, 1, 0))
            goto done;
         result = acquire_lock(side, ".gtk-writer", &editor);
         if (result != STORE_OK)
            goto done;
         result = acquire_lock(side, ".writer", &writer);
         if (result != STORE_OK)
            goto done;
         stream = fdopendir(side);
         if (stream == NULL)
         {
            result = STORE_IO;
            goto done;
         }
         side = -1; /* stream owns the descriptor */
         result = scan_canvas(stream, 0);
         if (result != STORE_OK)
            goto done;
      }
   }
   /* Remove and sync the log first. After a crash a hidden-by-absence
    * sidecar may remain, but a surviving log never loses its Canvas. */
   if (has_log && unlinkat(dir, log, 0) < 0)
   {
      result = STORE_IO;
      goto done;
   }
   if (has_log && fsync(dir) < 0)
   {
      result = STORE_UNCERTAIN;
      goto done;
   }
   result = STORE_OK;
   if (stream != NULL)
   {
      rewinddir(stream);
      if (scan_canvas(stream, 1) != STORE_OK ||
          unlinkat(dir, sidecar, AT_REMOVEDIR) < 0 || fsync(dir) < 0)
         result = has_log ? STORE_UNCERTAIN : STORE_IO;
   }
done:
   if (stream != NULL)
      closedir(stream);
   if (writer >= 0)
      close(writer);
   if (editor >= 0)
      close(editor);
   if (side >= 0)
      close(side);
   close(dir);
   return result;
}

/* Cooperating callers hold the session guard throughout inspection and
 * reclamation. Match exact names and UUID suffixes accepted by Identity.
 * Also block substring matches: legacy session lookup could select one. */
int coyote_canvas_reclaim_header(const char *parent, const char *uuid,
                                 int orphan, size_t max, char **header,
                                 size_t *len)
{
   DIR *stream;
   int dir, fd = -1, result = STORE_MISSING;
   char *buffer = NULL;
   struct stat st;
   *header = NULL;
   *len = 0;
   if (!valid_uuid(uuid) || max == 0)
      return STORE_INVALID;
   dir = open_parent(parent);
   if (dir < 0)
      return classify_parent_errno(errno);
   stream = fdopendir(dir);
   if (stream == NULL)
   {
      close(dir);
      return STORE_IO;
   }
   for (;;)
   {
      errno = 0;
      struct dirent *entry = readdir(stream);
      if (entry == NULL)
      {
         if (errno != 0)
            result = STORE_IO;
         break;
      }
      const char *name = entry->d_name;
      size_t n = strlen(name);
      if (n < 42 || strcmp(name + n - 6, ".jsonl") != 0 ||
          strstr(name, uuid) == NULL)
         continue;
      if (orphan || fd >= 0 || memcmp(name + n - 42, uuid, 36) != 0 ||
          (n != 42 && name[n - 43] != '_'))
      {
         result = STORE_INVALID;
         goto done;
      }
      fd = openat(dir, name, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK);
      if (fd < 0 || fstat(fd, &st) < 0 || !S_ISREG(st.st_mode) ||
          st.st_uid != geteuid() || st.st_nlink != 1)
      {
         result = STORE_INVALID;
         goto done;
      }
   }
   if (result == STORE_IO)
      goto done;
   if (fd < 0)
   {
      result = orphan ? STORE_OK : STORE_MISSING;
      goto done;
   }
   buffer = malloc(max);
   result = STORE_IO;
   if (buffer == NULL)
      goto done;
   size_t used = 0;
   while (used < max)
   {
      ssize_t n = read(fd, buffer + used, max - used);
      if (n < 0 && errno == EINTR)
         continue;
      if (n < 0)
         goto done;
      if (n == 0)
         break;
      char *end = memchr(buffer + used, '\n', (size_t)n);
      if (end != NULL)
      {
         size_t size = (size_t)(end - buffer);
         if (size == 0)
            break;
         *header = buffer;
         *len = size;
         buffer = NULL;
         result = STORE_OK;
         goto done;
      }
      used += (size_t)n;
   }
   result = STORE_INVALID;

done:
   free(buffer);
   if (fd >= 0)
      close(fd);
   closedir(stream);
   return result;
}

#define MAX_RECLAIM_ENTRIES 16384

struct reclaim_entry
{
   char name[70];
   dev_t device;
   ino_t inode;
};

static int kept_asset(const char *name, const char *keep, size_t count)
{
   for (size_t i = 0; i < count; ++i)
      if (memcmp(name, keep + 69 * i, 69) == 0)
         return 1;
   return 0;
}

/* The Ada layer validates the entire live graph and every referenced raster
 * or tile. Keep entries are exact 69-byte filenames; the manifest is rechecked
 * under the publication lock before applying that keep set. */
int coyote_canvas_reclaim(const char *parent, const char *uuid,
                          const char *manifest, size_t manifest_size,
                          const char *keep, size_t keep_count,
                          int orphan, int apply, size_t *files, uint64_t *bytes)
{
   char sidecar[64];
   struct stat st, side_st;
   int dir, side = -1, editor = -1, writer = -1, manifest_fd = -1;
   int result, changed = 0;
   DIR *stream = NULL;
   struct reclaim_entry *entries = NULL;
   size_t seen = 0;
   *files = 0;
   *bytes = 0;
   if (!valid_uuid(uuid) || (!orphan && manifest_size == 0) || keep_count > 256 ||
       (keep_count != 0 && keep == NULL))
      return STORE_INVALID;
   (void)snprintf(sidecar, sizeof sidecar, "%s.canvas", uuid);
   dir = open_parent(parent);
   if (dir < 0)
      return classify_parent_errno(errno);
   side = openat(dir, sidecar, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW);
   if (side < 0)
   {
      result = classify_errno(errno);
      goto done;
   }
   result = STORE_IO;
   if (fstat(side, &side_st) < 0)
      goto done;
   result = STORE_INVALID;
   if (!valid_private_stat(&side_st, 1, 0))
      goto done;
   /* Do not create lease files for inspection or for an abandoned fork. */
   result = lock_entry(side, ".gtk-writer", &editor, 0);
   if (result != STORE_OK)
      goto done;
   result = lock_entry(side, ".writer", &writer, 0);
   if (result != STORE_OK)
      goto done;
   if (!orphan)
   {
      char *current = NULL;
      size_t length = 0;
      manifest_fd = open_checked(side, "canvas.json", 0, &st);
      if (manifest_fd < 0)
      {
         result = classify_errno(errno);
         goto done;
      }
      result = read_fd(manifest_fd, manifest_size, &st, &current, &length);
      if (result == STORE_OK &&
          (length != manifest_size || memcmp(current, manifest, length) != 0))
         result = STORE_INVALID;
      free(current);
      if (result != STORE_OK)
         goto done;
   }
   stream = fdopendir(side);
   if (stream == NULL)
   {
      result = STORE_IO;
      goto done;
   }
   /* fdopendir now owns side; use the descriptor until closedir. */
   if (apply)
   {
      entries = malloc(MAX_RECLAIM_ENTRIES * sizeof *entries);
      if (entries == NULL)
      {
         result = STORE_IO;
         goto done;
      }
   }
   for (;;)
   {
      errno = 0;
      struct dirent *entry = readdir(stream);
      if (entry == NULL)
      {
         if (errno != 0)
         {
            result = STORE_IO;
            goto done;
         }
         break;
      }
      const char *name = entry->d_name;
      if (strcmp(name, ".") == 0 || strcmp(name, "..") == 0)
         continue;
      result = STORE_INVALID;
      if (++seen > MAX_RECLAIM_ENTRIES || !known_canvas_entry(name))
         goto done;
      result = STORE_IO;
      if (fstatat(side, name, &st, AT_SYMLINK_NOFOLLOW) < 0)
         goto done;
      result = STORE_INVALID;
      if (!valid_private_stat(&st, 0, 0) || st.st_size < 0)
         goto done;
      if (!orphan && strcmp(name, ".canvas.tmp") != 0 &&
          (!asset_entry(name) || kept_asset(name, keep, keep_count)))
         continue;
      if ((uintmax_t)st.st_size > UINT64_MAX - *bytes)
         goto done;
      *bytes += (uint64_t)st.st_size;
      if (entries != NULL)
      {
         strcpy(entries[*files].name, name);
         entries[*files].device = st.st_dev;
         entries[*files].inode = st.st_ino;
      }
      ++*files;
   }
   result = STORE_OK;
   if (!apply || (!orphan && *files == 0))
      goto done;
   /* Persist the current live manifest (including a previously uncertain
    * rename), or persist the log's absence, before removing any files. */
   result = STORE_IO;
   if ((orphan && fsync(dir) < 0) ||
       (!orphan && (fsync(manifest_fd) < 0 || fsync(side) < 0)))
      goto done;
   for (size_t i = 0; i < *files; ++i)
   {
      if (fstatat(side, entries[i].name, &st, AT_SYMLINK_NOFOLLOW) < 0 ||
          !valid_private_stat(&st, 0, 0) || st.st_dev != entries[i].device ||
          st.st_ino != entries[i].inode || unlinkat(side, entries[i].name, 0) < 0)
         goto done;
      changed = 1;
   }
   if (fsync(side) < 0)
      goto done;
   if (orphan)
   {
      if (fstatat(dir, sidecar, &st, AT_SYMLINK_NOFOLLOW) < 0 ||
          st.st_dev != side_st.st_dev || st.st_ino != side_st.st_ino ||
          unlinkat(dir, sidecar, AT_REMOVEDIR) < 0)
         goto done;
      changed = 1;
      if (fsync(dir) < 0)
         goto done;
   }
   result = STORE_OK;

done:
   if (result != STORE_OK)
   {
      *files = 0;
      *bytes = 0;
      if (changed)
         result = STORE_UNCERTAIN;
   }
   free(entries);
   if (manifest_fd >= 0)
      close(manifest_fd);
   if (writer >= 0)
      close(writer);
   if (editor >= 0)
      close(editor);
   if (stream != NULL)
      closedir(stream);
   else if (side >= 0)
      close(side);
   close(dir);
   return result;
}
