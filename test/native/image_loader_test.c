#define _GNU_SOURCE
#include <glib.h>
#include <gdk-pixbuf/gdk-pixbuf.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <pthread.h>
#include <errno.h>

void coyote_image_load(const char *, const char *, int,
                       void (*)(GdkPixbuf *, const char *, void *), void *);

typedef struct {
   GMainLoop *loop;
   pthread_t caller;
   gboolean expected;
   gboolean pass;
   gboolean callback_seen;
   const char *name;
} Case;

static int failures;
static void done(GdkPixbuf *pixbuf, const char *error, void *data)
{
   Case *c = data;
   c->callback_seen = TRUE;
   c->pass = pthread_equal(pthread_self(), c->caller) &&
      (c->expected ? pixbuf != NULL && error == NULL : pixbuf == NULL && error != NULL);
   if (!c->pass)
      fprintf(stderr, "%s: unexpected result/thread pixbuf=%p error=%s\n", c->name,
              (void *) pixbuf, error != NULL ? error : "(null)");
   if (c->loop != NULL)
      g_main_loop_quit(c->loop);
}
static gboolean run_case(const char *root, const char *path, gboolean expected, const char *name)
{
   Case c = { g_main_loop_new(NULL, FALSE), pthread_self(), expected, FALSE, FALSE, name };
   coyote_image_load(root, path, 512, done, &c);
   if (!c.callback_seen)
      g_main_loop_run(c.loop);
   g_main_loop_unref(c.loop);
   printf("%s: %s\n", name, c.pass ? "PASS" : "FAIL");
   failures += !c.pass;
   return c.pass;
}
static void write_bytes(const char *p, const void *data, size_t n)
{
   int fd = open(p, O_WRONLY | O_CREAT | O_TRUNC, 0600);
   if (fd < 0 || write(fd, data, n) != (ssize_t) n) g_error("write %s: %s", p, strerror(errno));
   close(fd);
}
static void fixture(const char *root, const char *name, const char *format, int w, int h)
{
   char path[1024];
   GdkPixbuf *image = gdk_pixbuf_new(GDK_COLORSPACE_RGB, TRUE, 8, w, h);
   g_snprintf(path, sizeof path, "%s/%s", root, name);
   gdk_pixbuf_fill(image, 0xff00ffff);
   if (!gdk_pixbuf_save(image, path, format, NULL, NULL)) g_error("save %s", path);
   g_object_unref(image);
}
typedef struct {
   int count;
   pthread_t caller;
   int wrong_thread;
} Queue_State;
static void queue_done(GdkPixbuf *p, const char *e, void *data)
{
   Queue_State *state = data;
   (void) p; (void) e;
   if (!pthread_equal(pthread_self(), state->caller))
      g_atomic_int_set(&state->wrong_thread, 1);
   g_atomic_int_inc(&state->count);
}
static void run_queue(const char *root, const char *path)
{
   Queue_State state = { 0, pthread_self(), 0 };
   for (int i = 0; i < 32; ++i)
      coyote_image_load(root, path, 512, queue_done, &state);
   gboolean at_cap = g_atomic_int_get(&state.count) == 0;
   coyote_image_load(root, path, 512, queue_done, &state);
   gboolean rejected = g_atomic_int_get(&state.count) == 1;
   while (g_atomic_int_get(&state.count) < 33)
      g_main_context_iteration(NULL, TRUE);
   printf("queue accepts 32/rejects 33rd synchronously: %s\n", at_cap && rejected && !g_atomic_int_get(&state.wrong_thread) ? "PASS" : "FAIL");
   failures += !(at_cap && rejected && !g_atomic_int_get(&state.wrong_thread));
}
int main(void)
{
   char temp[] = "/tmp/coyote-image-test-XXXXXX";
   char *root = g_mkdtemp(temp), path[1024], nested[1024];
   if (root == NULL) g_error("mkdtemp");
   fixture(root, "plot ü.png", "png", 4, 4);
   fixture(root, "photo.jpg", "jpeg", 4, 4);
   fixture(root, "wide.png", "png", 8193, 1);
   g_snprintf(path, sizeof path, "%s/corrupt.png", root); write_bytes(path, "not an image", 12);
   g_snprintf(path, sizeof path, "%s/vector.svg", root); write_bytes(path, "<svg></svg>", 11);
   g_snprintf(path, sizeof path, "%s/anim.gif", root); write_bytes(path, "GIF89a", 6);
   g_snprintf(path, sizeof path, "%s/anim.webp", root); write_bytes(path, "RIFFxxxxWEBPVP8X", 16);
   g_snprintf(path, sizeof path, "%s/huge", root);
   { int fd = open(path, O_CREAT | O_WRONLY, 0600); char block[8192] = { 0 };
     for (int i = 0; i < 1025; ++i) if (write(fd, block, sizeof block) != sizeof block) g_error("write huge");
     close(fd); }
   g_snprintf(path, sizeof path, "%s/outside", root); if (symlink("/etc/passwd", path) != 0) g_error("symlink");
   g_snprintf(path, sizeof path, "%s/pipe", root); if (mkfifo(path, 0600) != 0) g_error("mkfifo");
   g_snprintf(nested, sizeof nested, "%s/sub", root); if (mkdir(nested, 0700) != 0) g_error("mkdir");
#define TEST(p,e,n) run_case(root, p, e, n)
   TEST("plot%20%C3%BC.png", TRUE, "percent-encoded UTF-8 path");
   TEST("photo.jpg", TRUE, "JPEG succeeds");
   TEST("file://localhost", FALSE, "nonlocal file URI");
   TEST("file:///etc/passwd", FALSE, "outside file URI rejected");
   g_snprintf(path, sizeof path, "file://%s/photo.jpg", root);
   TEST(path, TRUE, "file URI succeeds");
   TEST("https://example.invalid/image.png", FALSE, "remote URI rejected");
   TEST("missing.png", FALSE, "missing path rejected");
   TEST("corrupt.png", FALSE, "invalid image rejected");
   TEST("vector.svg", FALSE, "SVG rejected");
   TEST("anim.gif", FALSE, "GIF rejected");
   TEST("anim.webp", FALSE, "WebP rejected");
   TEST("/etc/passwd", FALSE, "outside absolute path rejected");
   TEST("../etc/passwd", FALSE, "outside relative path rejected");
   TEST("outside", FALSE, "symlink rejected");
   TEST("pipe", FALSE, "FIFO rejected without blocking");
   TEST("wide.png", FALSE, "dimension limit enforced");
   TEST("huge", FALSE, "byte cap enforced");
   TEST("plot%00.png", FALSE, "encoded NUL rejected");
   g_snprintf(path, sizeof path, "%s/plot ü.png", root);
   run_case("/", path, TRUE, "root slash succeeds");
   run_queue(root, "photo.jpg");
   printf("failures=%d\n", failures);
   {
      const char *names[] = { "plot ü.png", "photo.jpg", "wide.png",
         "corrupt.png", "vector.svg", "anim.gif", "anim.webp",
         "huge", "outside", "pipe" };
      for (guint i = 0; i < G_N_ELEMENTS(names); ++i) {
         g_snprintf(path, sizeof path, "%s/%s", root, names[i]);
         if (unlink(path) != 0) g_error("cleanup %s", path);
      }
      if (rmdir(nested) != 0 || rmdir(root) != 0) g_error("cleanup root");
   }
   return failures == 0 ? 0 : 1;
}
#undef TEST
