#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <glib-object.h>
#include <gdk-pixbuf/gdk-pixbuf.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

int coyote_image_io_open_root(const char *path);
int coyote_image_io_duplicate(int fd);
int coyote_image_io_open_directory(int parent, const char *name);
int coyote_image_io_open_file(int parent, const char *name);
int coyote_image_io_attributes(int fd, int *is_regular, long long *size);
long coyote_image_io_read(int fd, void *buffer, size_t length);
long coyote_image_io_readlink_root(int fd, char *buffer, size_t length);
int coyote_image_io_close(int fd);
void coyote_image_io_connect_size_prepared
  (GdkPixbufLoader *loader,
   void (*callback)(GdkPixbufLoader *, gint, gint, gpointer), void *state);
const char *coyote_image_decoder_error_message(const GError *error);

static char root_path[] = "/tmp/coyote-image-io-XXXXXX";
static char dir_path[PATH_MAX];
static char file_path[PATH_MAX];
static char file_link_path[PATH_MAX];
static char dir_link_path[PATH_MAX];
static char fifo_path[PATH_MAX];
static int checks;
static int failures;

static void cleanup(void)
{
   (void) unlink(file_link_path);
   (void) unlink(dir_link_path);
   (void) unlink(fifo_path);
   (void) unlink(file_path);
   (void) rmdir(dir_path);
   (void) rmdir(root_path);
}

static void check(int condition, const char *name)
{
   ++checks;
   printf("%s: %s\n", name, condition ? "PASS" : "FAIL");
   failures += !condition;
}

static void size_prepared(GdkPixbufLoader *loader, gint width, gint height,
                          gpointer state)
{
   int *called = state;
   (void) loader;
   if (width == 2 && height == 3)
      *called = 1;
}

int main(void)
{
   static const unsigned char payload[] = { 'a', 'b', 'c' };
   char canonical[PATH_MAX];
   char link_target[PATH_MAX];
   char buffer[16];
   int root_fd = -1;
   int duplicate_fd = -1;
   int directory_fd = -1;
   int file_fd = -1;
   int fifo_fd = -1;
   int regular = 0;
   long long size = -1;
   long count;
   long link_length;
   GError *error = NULL;
   GdkPixbuf *pixbuf = NULL;
   GdkPixbufLoader *loader = NULL;
   guchar *png_data = NULL;
   gsize png_length = 0;
   int callback_called = 0;
   gboolean png_saved;

   if (mkdtemp(root_path) == NULL) {
      perror("mkdtemp");
      return 2;
   }
   if (atexit(cleanup) != 0) {
      (void) rmdir(root_path);
      return 2;
   }
   (void) snprintf(dir_path, sizeof dir_path, "%s/subdir", root_path);
   (void) snprintf(file_path, sizeof file_path, "%s/subdir/data.bin", root_path);
   (void) snprintf(file_link_path, sizeof file_link_path, "%s/file-link", root_path);
   (void) snprintf(dir_link_path, sizeof dir_link_path, "%s/dir-link", root_path);
   (void) snprintf(fifo_path, sizeof fifo_path, "%s/pipe", root_path);

   if (mkdir(dir_path, 0700) != 0) {
      perror("mkdir fixture directory");
      return 2;
   }
   {
      int fd = open(file_path, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0600);
      if (fd < 0 || write(fd, payload, sizeof payload) != (ssize_t) sizeof payload) {
         perror("write fixture");
         if (fd >= 0)
            (void) close(fd);
         return 2;
      }
      if (close(fd) != 0) {
         perror("close fixture");
         return 2;
      }
   }
   if (symlink("subdir/data.bin", file_link_path) != 0 ||
       symlink("subdir", dir_link_path) != 0 ||
       mkfifo(fifo_path, 0600) != 0) {
      perror("create symlink/FIFO fixture");
      return 2;
   }

   root_fd = coyote_image_io_open_root(root_path);
   check(root_fd >= 0, "open root descriptor");
   if (root_fd < 0)
      goto finish;
   duplicate_fd = coyote_image_io_duplicate(root_fd);
   check(duplicate_fd >= 0 &&
         (fcntl(duplicate_fd, F_GETFD) & FD_CLOEXEC) != 0,
         "duplicate descriptor CLOEXEC");
   if (duplicate_fd < 0)
      goto finish;
   link_length = coyote_image_io_readlink_root(root_fd, link_target,
                                               sizeof link_target - 1);
   if (link_length >= 0)
      link_target[link_length] = '\0';
   check(realpath(root_path, canonical) != NULL && link_length > 0 &&
         (size_t) link_length == strlen(canonical) &&
         strcmp(canonical, link_target) == 0,
         "readlink root returns canonical path");

   directory_fd = coyote_image_io_open_directory(root_fd, "subdir");
   check(directory_fd >= 0, "openat directory without following links");
   check(coyote_image_io_open_directory(root_fd, "dir-link") < 0,
         "directory symlink rejected");
   check(coyote_image_io_open_file(root_fd, "file-link") < 0,
         "file symlink rejected");

   if (directory_fd >= 0)
      file_fd = coyote_image_io_open_file(directory_fd, "data.bin");
   check(file_fd >= 0, "openat regular file without following links");
   check(file_fd >= 0 && coyote_image_io_attributes(file_fd, &regular, &size) == 0 &&
         regular == 1 && size == (long long) sizeof payload,
         "fstat reports regular file and size");
   count = file_fd >= 0 ? coyote_image_io_read(file_fd, buffer, sizeof buffer) : -1;
   check(count == (long) sizeof payload &&
         memcmp(buffer, payload, sizeof payload) == 0,
         "read returns file bytes");
   count = file_fd >= 0 ? coyote_image_io_read(file_fd, buffer, sizeof buffer) : -1;
   check(count == 0, "read reports EOF");

   fifo_fd = coyote_image_io_open_file(root_fd, "pipe");
   check(fifo_fd >= 0 && coyote_image_io_attributes(fifo_fd, &regular, &size) == 0 &&
         regular == 0,
         "nonblocking FIFO open and nonregular attributes");
   check(coyote_image_io_attributes(-1, &regular, &size) == -1 &&
         coyote_image_io_read(-1, buffer, sizeof buffer) == -1 &&
         coyote_image_io_close(-1) == -1,
         "invalid descriptors report errors");

   error = g_error_new_literal(g_quark_from_static_string("image-io-test"), 1,
                               "expected decoder message");
   check(coyote_image_decoder_error_message(NULL) == NULL &&
         strcmp(coyote_image_decoder_error_message(error),
                "expected decoder message") == 0,
         "decoder error accessor handles null and message");
   g_error_free(error);
   error = NULL;

   pixbuf = gdk_pixbuf_new(GDK_COLORSPACE_RGB, TRUE, 8, 2, 3);
   png_saved = pixbuf != NULL &&
      gdk_pixbuf_save_to_buffer(pixbuf, (gchar **) &png_data, &png_length,
                                "png", &error, NULL);
   loader = gdk_pixbuf_loader_new();
   if (loader != NULL)
      coyote_image_io_connect_size_prepared(loader, size_prepared, &callback_called);
   if (png_saved && loader != NULL) {
      (void) gdk_pixbuf_loader_write(loader, png_data, png_length, &error);
      (void) gdk_pixbuf_loader_close(loader, &error);
   }
   check(png_saved && loader != NULL && error == NULL && callback_called == 1,
         "size-prepared callback ABI invoked by PNG loader");
   if (error != NULL)
      g_error_free(error);
   g_free(png_data);
   if (loader != NULL)
      g_object_unref(loader);
   if (pixbuf != NULL)
      g_object_unref(pixbuf);

finish:
   if (fifo_fd >= 0)
      (void) coyote_image_io_close(fifo_fd);
   if (file_fd >= 0)
      (void) coyote_image_io_close(file_fd);
   if (directory_fd >= 0)
      (void) coyote_image_io_close(directory_fd);
   if (duplicate_fd >= 0) {
      check(coyote_image_io_close(duplicate_fd) == 0,
            "close valid descriptor");
      duplicate_fd = -1;
   }
   if (root_fd >= 0)
      (void) coyote_image_io_close(root_fd);
   printf("checks=%d failures=%d\n", checks, failures);
   return failures == 0 ? 0 : 1;
}
