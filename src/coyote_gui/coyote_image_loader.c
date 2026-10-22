#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
#include <glib.h>
#include <gdk-pixbuf/gdk-pixbuf.h>

typedef void (*Coyote_Image_Done)(GdkPixbuf *, const char *, void *);

typedef struct {
   char *root;
   char *destination;
   int max_width;
   Coyote_Image_Done done;
   void *data;
   GdkPixbuf *pixbuf;
   char *error;
} Image_Job;

static GMutex queue_lock;
static GThreadPool *worker_pool;
static guint outstanding_jobs;

static char *try_strdup(const char *text)
{
   size_t length = strlen(text) + 1;
   char *copy = g_try_malloc(length);
   if (copy != NULL)
      memcpy(copy, text, length);
   return copy;
}

static void set_error(Image_Job *job, const char *message)
{
   if (job->error == NULL)
      job->error = g_strdup(message);
}

static gboolean has_control(const char *text)
{
   const guchar *p = (const guchar *) text;
   for (; *p != '\0'; ++p)
      if (*p < 0x20 || *p == 0x7f)
         return TRUE;
   return FALSE;
}

static gboolean starts_with_scheme(const char *path)
{
   const char *colon = strchr(path, ':');
   const char *slash = strchr(path, '/');
   const char *p;
   if (colon == NULL || (slash != NULL && slash < colon))
      return FALSE;
   if (colon == path || !g_ascii_isalpha(path[0]))
      return FALSE;
   for (p = path + 1; p < colon; ++p)
      if (!g_ascii_isalnum(*p) && *p != '+' && *p != '.' && *p != '-')
         return FALSE;
   return TRUE;
}

static char *local_path(const char *root, const char *destination)
{
   char *path = NULL;
   if (destination == NULL || destination[0] == '\0' || has_control(destination))
      return NULL;
   if (g_str_has_prefix(destination, "file:")) {
      char *host = NULL;
      path = g_filename_from_uri(destination, &host, NULL);
      if (path == NULL || (host != NULL && host[0] != '\0')) {
         g_free(path);
         path = NULL;
      }
      g_free(host);
   } else if (starts_with_scheme(destination)) {
      return NULL;
   } else {
      path = g_uri_unescape_string(destination, NULL);
   }
   if (path == NULL)
      return NULL;
   if (has_control(path)) {
      g_free(path);
      return NULL;
   }
   if (g_str_has_prefix(destination, "file:")) {
      const char *escape;
      for (escape = destination; escape[0] != '\0'; ++escape)
         if (escape[0] == '%' && escape[1] != '\0' && escape[2] != '\0' &&
             g_ascii_isxdigit(escape[1]) && g_ascii_isxdigit(escape[2]) &&
             (g_ascii_xdigit_value(escape[1]) * 16 +
              g_ascii_xdigit_value(escape[2])) < 0x20) {
            g_free(path);
            return NULL;
         }
   }
   if (path != NULL && has_control(path)) {
      g_free(path);
      return NULL;
   }
   if (path != NULL && !g_path_is_absolute(path)) {
      char *joined = g_build_filename(root, path, NULL);
      g_free(path);
      path = joined;
   }
   return path;
}

/* Resource limits deliberately bound worker memory and decoder dimensions. */
#define COYOTE_IMAGE_MAX_BYTES (8U * 1024U * 1024U)
#define COYOTE_IMAGE_MAX_SIDE 8192
#define COYOTE_IMAGE_MAX_PIXELS (16U * 1024U * 1024U)
#define COYOTE_IMAGE_MAX_JOBS 32

static int open_beneath(const char *root, const char *destination, char **error)
{
   char proc_path[64];
   char root_link[PATH_MAX + 1];
   ssize_t root_length;
   char *canonical_root = NULL;
   char *path = NULL;
   char *canonical_path = NULL;
   const char *relative;
   char *cursor;
   int directory_fd = -1;
   int fd = -1;
   struct stat st;

   /* Open once: all later opens are relative to this exact directory object. */
   directory_fd = open(root, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
   if (directory_fd < 0) {
      *error = g_strdup("Image root is not accessible");
      return -1;
   }
   g_snprintf(proc_path, sizeof proc_path, "/proc/self/fd/%d", directory_fd);
   root_length = readlink(proc_path, root_link, sizeof root_link - 1);
   if (root_length < 0 || (gsize) root_length >= sizeof root_link - 1) {
      *error = g_strdup("Image root path cannot be resolved");
      goto done;
   }
   root_link[root_length] = '\0';
   if ((root_length >= 10 && strcmp(root_link + root_length - 10, " (deleted)") == 0)) {
      *error = g_strdup("Image root has been deleted");
      goto done;
   }
   canonical_root = realpath(root_link, NULL);
   if (canonical_root == NULL) {
      *error = g_strdup("Image root is not accessible");
      goto done;
   }
   path = local_path(canonical_root, destination);
   if (path == NULL) {
      *error = g_strdup("Image path is invalid or non-local");
      goto done;
   }
   canonical_path = g_canonicalize_filename(path, NULL);
   if (strcmp(canonical_root, G_DIR_SEPARATOR_S) != 0 &&
       (!g_str_has_prefix(canonical_path, canonical_root) ||
        (canonical_path[strlen(canonical_root)] != '\0' &&
         canonical_path[strlen(canonical_root)] != G_DIR_SEPARATOR))) {
      *error = g_strdup("Image path escapes its root");
      goto done;
   }
   relative = canonical_path + strlen(canonical_root);
   if (strcmp(canonical_root, G_DIR_SEPARATOR_S) == 0)
      relative = canonical_path + 1;
   if (*relative == G_DIR_SEPARATOR)
      ++relative;
   if (*relative == '\0') {
      *error = g_strdup("Image path is not a file");
      goto done;
   }
   cursor = g_strdup(relative);
   {
      char *component = cursor;
      for (;;) {
         char *separator = strchr(component, G_DIR_SEPARATOR);
         if (separator != NULL)
            *separator = '\0';
         if (component[0] == '\0' || strcmp(component, ".") == 0 ||
             strcmp(component, "..") == 0) {
            *error = g_strdup("Image path contains an invalid component");
            break;
         }
         if (separator != NULL) {
            int next_fd = openat(directory_fd, component,
                                 O_RDONLY | O_DIRECTORY | O_NOFOLLOW |
                                 O_CLOEXEC | O_NONBLOCK);
            if (next_fd < 0) {
               *error = g_strdup("Image path is inaccessible or contains a symlink");
               break;
            }
            close(directory_fd);
            directory_fd = next_fd;
            component = separator + 1;
         } else {
            fd = openat(directory_fd, component,
                        O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK);
            if (fd < 0) {
               *error = g_strdup("Image file is inaccessible or contains a symlink");
            } else if (fstat(fd, &st) != 0 || !S_ISREG(st.st_mode)) {
               close(fd);
               fd = -1;
               *error = g_strdup("Image path is not a regular file");
            } else if (st.st_size < 0 || st.st_size > COYOTE_IMAGE_MAX_BYTES) {
               close(fd);
               fd = -1;
               *error = g_strdup("Image exceeds the 8 MiB size limit");
            }
            break;
         }
      }
   }
   g_free(cursor);
done:
   if (directory_fd >= 0)
      close(directory_fd);
   free(canonical_root);
   g_free(path);
   g_free(canonical_path);
   return fd;
}

static gboolean dimensions_ok(gint width, gint height)
{
   return width > 0 && height > 0 &&
          width <= COYOTE_IMAGE_MAX_SIDE && height <= COYOTE_IMAGE_MAX_SIDE &&
          (guint64) width * (guint64) height <= COYOTE_IMAGE_MAX_PIXELS;
}

typedef struct {
   gboolean invalid;
   gint max_width;
} Decode_State;

static void size_prepared(GdkPixbufLoader *loader, gint width, gint height,
                          gpointer user_data)
{
   Decode_State *state = user_data;
   gint output_width;
   gint output_height;
   double scale;
   if (!dimensions_ok(width, height)) {
      state->invalid = TRUE;
      gdk_pixbuf_loader_set_size(loader, 1, 1);
      return;
   }
   scale = MIN(1.0, MIN((double) state->max_width / width,
                        600.0 / height));
   output_width = MAX(1, (gint) (width * scale));
   output_height = MAX(1, (gint) (height * scale));
   gdk_pixbuf_loader_set_size(loader, output_width, output_height);
}

static gboolean allowed_format(GdkPixbufFormat *format)
{
   gchar *name;
   gboolean result;
   if (format == NULL)
      return FALSE;
   name = gdk_pixbuf_format_get_name(format);
   result = name != NULL && (strcmp(name, "png") == 0 ||
            strcmp(name, "jpeg") == 0);
   g_free(name);
   return result;
}

static gboolean known_signature(const guchar *bytes, gsize length)
{
   static const guchar png[] = { 0x89, 'P', 'N', 'G', 0x0d, 0x0a, 0x1a, 0x0a };
   if (length >= sizeof png && memcmp(bytes, png, sizeof png) == 0)
      return TRUE;
   if (length >= 3 && bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff)
      return TRUE;
   return FALSE;
}

static gboolean looks_like_svg(const guchar *bytes, gsize length)
{
   gsize i = 0;
   while (i < length && g_ascii_isspace(bytes[i]))
      ++i;
   if (i < length && bytes[i] == '<') {
      gsize remaining = length - i;
      return g_ascii_strncasecmp((const char *) bytes + i, "<svg", MIN(remaining, 4)) == 0 ||
             g_ascii_strncasecmp((const char *) bytes + i, "<?xml", MIN(remaining, 5)) == 0;
   }
   return FALSE;
}

static void decode_job(Image_Job *job)
{
   char *open_error = NULL;
   GError *decode_error = NULL;
   int fd = open_beneath(job->root, job->destination, &open_error);
   GdkPixbufLoader *loader = NULL;
   Decode_State state = { FALSE, 0 };
   guchar buffer[16384];
   gsize total = 0;
   gboolean first = TRUE;

   if (fd < 0) {
      set_error(job, open_error != NULL ? open_error : "Image could not be opened");
      g_free(open_error);
      return;
   }
   state.max_width = CLAMP(job->max_width, 64, 1024);
   loader = gdk_pixbuf_loader_new();
   if (loader == NULL) {
      set_error(job, "Image decoder could not be created");
      close(fd);
      return;
   }
   g_signal_connect(loader, "size-prepared", G_CALLBACK(size_prepared), &state);
   for (;;) {
      ssize_t count = read(fd, buffer, sizeof buffer);
      if (count < 0 && errno == EINTR)
         continue;
      if (count < 0) {
         set_error(job, "Image read failed");
         break;
      }
      if (count == 0)
         break;
      total += (gsize) count;
      if (total > 8U * 1024U * 1024U) {
         set_error(job, "Image exceeds the 8 MiB size limit");
         break;
      }
      if (first) {
         first = FALSE;
         if (looks_like_svg(buffer, (gsize) count) ||
             !known_signature(buffer, (gsize) count)) {
            set_error(job, looks_like_svg(buffer, (gsize) count) ?
                      "SVG images are not supported" :
                      "Image signature is not a supported raster format");
            break;
         }
      }
      if (!gdk_pixbuf_loader_write(loader, buffer, (gsize) count, &decode_error)) {
         set_error(job, decode_error != NULL ? decode_error->message :
                   "Image decoding failed");
         g_clear_error(&decode_error);
         break;
      }
      if (state.invalid) {
         set_error(job, "Image dimensions exceed the allowed limit");
         break;
      }
   }
   close(fd);
   if (!gdk_pixbuf_loader_close(loader, &decode_error)) {
      if (job->error == NULL)
         set_error(job, decode_error != NULL ? decode_error->message :
                   "Image decoding failed");
   }
   g_clear_error(&decode_error);
   if (state.invalid)
      set_error(job, "Image dimensions exceed the allowed limit");
   if (job->error == NULL && !allowed_format(gdk_pixbuf_loader_get_format(loader)))
      set_error(job, "Only PNG and JPEG images are supported");
   if (job->error == NULL) {
      GdkPixbuf *pixbuf = gdk_pixbuf_loader_get_pixbuf(loader);
      if (pixbuf == NULL)
         set_error(job, "Image decoder produced no image");
      else
         job->pixbuf = g_object_ref(pixbuf);
   }
   g_object_unref(loader);
}

static gboolean complete_job(gpointer user_data)
{
   Image_Job *job = user_data;
   job->done(job->pixbuf, job->error, job->data);
   if (job->pixbuf != NULL)
      g_object_unref(job->pixbuf);
   g_free(job->error);
   g_free(job->root);
   g_free(job->destination);
   g_free(job);
   g_mutex_lock(&queue_lock);
   --outstanding_jobs;
   g_mutex_unlock(&queue_lock);
   return G_SOURCE_REMOVE;
}

static void worker(gpointer user_data, gpointer unused)
{
   Image_Job *job = user_data;
   GSource *source;
   (void) unused;
   decode_job(job);
   source = g_idle_source_new();
   g_source_set_callback(source, complete_job, job, NULL);
   g_source_attach(source, g_main_context_default());
   g_source_unref(source);
}

void coyote_image_load(const char *root, const char *destination, int max_width,
                       void (*done)(GdkPixbuf *, const char *, void *), void *data)
{
   Image_Job *job;
   GError *error = NULL;
   gboolean accepted = FALSE;
   gboolean saturated = FALSE;
   if (done == NULL)
      return;
   if (root == NULL || destination == NULL || has_control(root) || has_control(destination)) {
      done(NULL, "Image path is invalid", data);
      return;
   }
   job = g_try_new0(Image_Job, 1);
   if (job == NULL) {
      done(NULL, "Image loader is out of memory", data);
      return;
   }
   job->root = try_strdup(root);
   job->destination = try_strdup(destination);
   job->max_width = max_width;
   job->done = done;
   job->data = data;
   if (job->root == NULL || job->destination == NULL) {
      g_free(job->root);
      g_free(job->destination);
      g_free(job);
      done(NULL, "Image loader is out of memory", data);
      return;
   }
   g_mutex_lock(&queue_lock);
   saturated = outstanding_jobs >= COYOTE_IMAGE_MAX_JOBS;
   if (!saturated) {
      if (worker_pool == NULL)
         worker_pool = g_thread_pool_new(worker, NULL, 2, FALSE, &error);
      if (worker_pool != NULL) {
         ++outstanding_jobs;
         accepted = g_thread_pool_push(worker_pool, job, &error);
         if (!accepted)
            --outstanding_jobs;
      }
   }
   g_mutex_unlock(&queue_lock);
   if (!accepted) {
      done(NULL, error != NULL ? error->message :
           (saturated ? "Image loader queue is full" :
                        "Image worker pool is unavailable"), data);
      g_clear_error(&error);
      g_free(job->root);
      g_free(job->destination);
      g_free(job);
      return;
   }
   g_clear_error(&error);
}
