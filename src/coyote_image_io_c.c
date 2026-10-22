#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <sys/stat.h>
#include <unistd.h>
#include <glib-object.h>
#include <gdk-pixbuf/gdk-pixbuf.h>

int coyote_image_io_open_root(const char *path)
{
   return open(path, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
}

int coyote_image_io_duplicate(int fd)
{
   return fcntl(fd, F_DUPFD_CLOEXEC, 0);
}

int coyote_image_io_open_directory(int parent, const char *name)
{
   return openat(parent, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW |
                 O_CLOEXEC | O_NONBLOCK);
}

int coyote_image_io_open_file(int parent, const char *name)
{
   return openat(parent, name, O_RDONLY | O_NOFOLLOW | O_CLOEXEC |
                 O_NONBLOCK);
}

int coyote_image_io_attributes(int fd, int *is_regular, long long *size)
{
   struct stat attributes;
   if (fstat(fd, &attributes) != 0)
      return -1;
   *is_regular = S_ISREG(attributes.st_mode) ? 1 : 0;
   *size = (long long) attributes.st_size;
   return 0;
}

long coyote_image_io_read(int fd, void *buffer, size_t length)
{
   ssize_t count;
   do {
      count = read(fd, buffer, length);
   } while (count < 0 && errno == EINTR);
   return (long) count;
}

long coyote_image_io_readlink_root(int fd, char *buffer, size_t length)
{
   char proc_path[64];
   (void) snprintf(proc_path, sizeof proc_path, "/proc/self/fd/%d", fd);
   return (long) readlink(proc_path, buffer, length);
}

int coyote_image_io_close(int fd)
{
   return close(fd);
}

void coyote_image_io_connect_size_prepared
  (GdkPixbufLoader *loader,
   void (*callback)(GdkPixbufLoader *, gint, gint, gpointer), void *state)
{
   (void) g_signal_connect_data
     (loader, "size-prepared", G_CALLBACK (callback), state, NULL, 0);
}

const char *coyote_image_decoder_error_message(const GError *error)
{
   return error == NULL ? NULL : error->message;
}
