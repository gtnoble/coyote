#define _GNU_SOURCE
#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/random.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <time.h>
#include <unistd.h>

/* Wire v1: CCA1, op, count, 16 opaque ID bytes, 64 hex token bytes.
 * Add receives a one-byte admission acknowledgement before any file data.
 * File: network uint32 length, uint8 label length, label, data. Add ends
 * with 0xa5 then half-close; query ends with half-close only. Results are
 * uint8 status, network uint32 length, and ASCII text. */
enum { FILES = 8, LABEL = 64, FILE_MAX = 8 * 1024 * 1024,
       BATCH_MAX = 32 * 1024 * 1024, TEXT_MAX = 2048, CACHE = 32,
       IO_MS = 10000, RESULT_MS = 60000, CACHE_MS = 120000 };
enum { ADD = 1, QUERY = 2, OK = 0, ERROR = 1, UNKNOWN = 2, PENDING = 3 };
struct file { char label[LABEL + 1]; uint32_t size; char *data; };
struct batch { unsigned count; struct file files[FILES]; };
struct receipt {
   unsigned char id[16];
   int status;
   int64_t expiry;
   char text[TEXT_MAX + 1];
};
struct service {
   int listener;
   char dir[108], path[108], cap[65];
   atomic_int stopped;
   pthread_t worker;
   pthread_mutex_t mutex;
   struct batch *batch;
   int active; /* one mailbox and one in-flight commit per binding */
   struct receipt cache[CACHE];
};

static int64_t now(void)
{
   struct timespec t;
   clock_gettime(CLOCK_MONOTONIC, &t);
   return (int64_t)t.tv_sec * 1000 + t.tv_nsec / 1000000;
}

static int random_bytes(void *data, size_t n)
{
   unsigned char *p = data;
   while (n) {
      ssize_t k = getrandom(p, n, 0);
      if (k < 0 && errno == EINTR) continue;
      if (k <= 0) return -1;
      p += k;
      n -= (size_t)k;
   }
   return 0;
}

static int wait_fd(int fd, short event, int64_t deadline,
                   const struct service *s)
{
   struct pollfd p = {fd, event, 0};
   while (!s || !atomic_load(&s->stopped)) {
      int64_t left = deadline - now();
      if (left <= 0) return -1;
      int r = poll(&p, 1, (int)(left > 100 ? 100 : left));
      if (r > 0) return 0;
      if (r < 0 && errno != EINTR) return -1;
   }
   return -1;
}

/* Returns 0 on exact transfer, 1 on EOF, -1 on failure. */
static int transfer(int fd, void *buf, size_t n, int writing, int64_t until,
                    const struct service *s)
{
   char *p = buf;
   while (n) {
      if (wait_fd(fd, writing ? POLLOUT : POLLIN, until, s)) return -1;
      ssize_t k = writing ? send(fd, p, n, MSG_NOSIGNAL) : recv(fd, p, n, 0);
      if (k < 0 && (errno == EAGAIN || errno == EINTR)) continue;
      if (k <= 0) return k == 0 ? 1 : -1;
      p += k;
      n -= (size_t)k;
   }
   return 0;
}

static int same_user(int fd)
{
   struct ucred c;
   socklen_t len = sizeof c;
   return getsockopt(fd, SOL_SOCKET, SO_PEERCRED, &c, &len) == 0 &&
          len == sizeof c && c.uid == geteuid();
}

static int label_char(unsigned char c)
{
   return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
          (c >= '0' && c <= '9') || c == ' ' || c == '_' || c == '-' || c == '.';
}

void coyote_canvas_import_free(struct batch *b)
{
   if (!b) return;
   for (unsigned i = 0; i < b->count; ++i) free(b->files[i].data);
   free(b);
}

unsigned coyote_canvas_import_count(const struct batch *b) { return b->count; }
const char *coyote_canvas_import_file(const struct batch *b, unsigned i,
                                     unsigned *size, const char **label)
{
   if (i >= b->count) return NULL;
   *size = b->files[i].size;
   *label = b->files[i].label;
   return b->files[i].data;
}

static void reply(int fd, int status, char *text, const struct service *s)
{
   unsigned char h[5];
   size_t n = strlen(text);
   uint32_t wire = htonl((uint32_t)n);
   int64_t until = now() + IO_MS;
   h[0] = (unsigned char)status;
   memcpy(h + 1, &wire, 4);
   if (!transfer(fd, h, 5, 1, until, s))
      (void)transfer(fd, text, n, 1, until, s);
}

static struct batch *read_batch(int fd, unsigned count, const struct service *s)
{
   struct batch *b = calloc(1, sizeof *b);
   size_t total = 0;
   int64_t until = now() + IO_MS;
   unsigned char byte;
   if (!b) return NULL;
   b->count = count;
   for (unsigned i = 0; i < count; ++i) {
      struct file *f = &b->files[i];
      uint32_t n;
      if (transfer(fd, &n, 4, 0, until, s) ||
          transfer(fd, &byte, 1, 0, until, s)) goto fail;
      f->size = ntohl(n);
      if (!f->size || f->size > FILE_MAX || f->size > BATCH_MAX - total ||
          !byte || byte > LABEL) goto fail;
      if (transfer(fd, f->label, byte, 0, until, s)) goto fail;
      for (unsigned j = 0; j < byte; ++j)
         if (!label_char((unsigned char)f->label[j])) goto fail;
      total += f->size;
      f->data = malloc(f->size);
      if (!f->data || transfer(fd, f->data, f->size, 0, until, s)) goto fail;
   }
   if (!transfer(fd, &byte, 1, 0, until, s) && byte == 0xa5 &&
       transfer(fd, &byte, 1, 0, until, s) == 1) return b;
fail:
   coyote_canvas_import_free(b);
   return NULL;
}

static void handle(struct service *s, int fd)
{
   unsigned char h[86], admission = 0;
   int slot = -1, match = -1;
   unsigned diff = 0;
   struct receipt result;
   if (!same_user(fd) || transfer(fd, h, sizeof h, 0, now() + IO_MS, s)) return;
   for (unsigned i = 0; i < 64; ++i) diff |= h[22+i] ^ (unsigned char)s->cap[i];
   if (diff || memcmp(h, "CCA1", 4)) return;
   pthread_mutex_lock(&s->mutex);
   for (int i = 0; i < CACHE; ++i) {
      if (i != s->active && s->cache[i].expiry <= now()) {
         if (slot < 0) slot = i;
      } else if (!memcmp(s->cache[i].id, h + 6, 16)) match = i;
   }
   if (h[4] == QUERY && h[5] == 0) {
      if (match >= 0) result = s->cache[match];
      pthread_mutex_unlock(&s->mutex);
      unsigned char extra;
      if (transfer(fd, &extra, 1, 0, now() + IO_MS, s) != 1) return;
      if (match < 0) reply(fd, UNKNOWN, "Canvas import outcome unknown", s);
      else reply(fd, result.status, result.text, s);
      return;
   }
   if (h[4] != ADD || h[5] == 0 || h[5] > FILES || slot < 0 ||
       match >= 0 || s->active >= 0) {
      pthread_mutex_unlock(&s->mutex);
      admission = 1;
      (void)transfer(fd, &admission, 1, 1, now() + IO_MS, s);
      return;
   }
   pthread_mutex_unlock(&s->mutex);
   if (transfer(fd, &admission, 1, 1, now() + IO_MS, s)) return;
   struct batch *b = read_batch(fd, h[5], s);
   if (!b) {
      pthread_mutex_lock(&s->mutex);
      s->cache[slot] = (struct receipt){.status = ERROR, .expiry = now() + CACHE_MS,
                                      .text = "Invalid or incomplete Canvas batch"};
      memcpy(s->cache[slot].id, h + 6, 16);
      pthread_mutex_unlock(&s->mutex);
      reply(fd, ERROR, "Invalid or incomplete Canvas batch", s);
      return;
   }
   pthread_mutex_lock(&s->mutex);
   s->cache[slot] = (struct receipt){.status = PENDING,
                                    .text = "Canvas import is still pending"};
   memcpy(s->cache[slot].id, h + 6, 16);
   s->active = slot;
   s->batch = b;
   pthread_mutex_unlock(&s->mutex);

   /* Wait for GTK without blocking the GTK task. A client that disconnects
    * can query the same receipt; the accepted operation is not replayed. */
   int64_t until = now() + RESULT_MS;
   while (!atomic_load(&s->stopped) && now() < until) {
      struct timespec interval = {0, 20000000};
      pthread_mutex_lock(&s->mutex);
      result = s->cache[slot];
      pthread_mutex_unlock(&s->mutex);
      if (result.status != PENDING) {
         reply(fd, result.status, result.text, s);
         return;
      }
      struct pollfd peer = {fd, 0, 0};
      if (poll(&peer, 1, 0) > 0 && (peer.revents & (POLLHUP | POLLERR)))
         return;
      nanosleep(&interval, NULL);
   }
   reply(fd, UNKNOWN, "Canvas import outcome unknown", s);
}

static void *serve(void *arg)
{
   struct service *s = arg;
   while (!atomic_load(&s->stopped)) {
      if (wait_fd(s->listener, POLLIN, now() + 100, s)) continue;
      int fd = accept4(s->listener, NULL, NULL, SOCK_NONBLOCK | SOCK_CLOEXEC);
      if (fd >= 0) {
         handle(s, fd);
         close(fd);
      }
   }
   return NULL;
}

static int address(struct sockaddr_un *a, const char *path)
{
   size_t n = strlen(path);
   if (path[0] != '/' || n >= sizeof a->sun_path) return -1;
   memset(a, 0, sizeof *a);
   a->sun_family = AF_UNIX;
   memcpy(a->sun_path, path, n + 1);
   return 0;
}

struct service *coyote_canvas_import_start(const char *runtime, char *path, char *cap)
{
   struct stat st;
   struct sockaddr_un a;
   unsigned char secret[32];
   struct service *s;
   static const char hex[] = "0123456789abcdef";
   if (runtime[0] != '/' || lstat(runtime, &st) || !S_ISDIR(st.st_mode) ||
       st.st_uid != geteuid() || (st.st_mode & 0777) != 0700 ||
       strlen(runtime) > sizeof a.sun_path - sizeof "/coyote-canvas-XXXXXX/add" ||
       random_bytes(secret, sizeof secret)) return NULL;
   s = calloc(1, sizeof *s);
   if (!s) return NULL;
   atomic_init(&s->stopped, 0);
   s->listener = -1;
   s->active = -1;
   (void)snprintf(s->dir, sizeof s->dir, "%s/coyote-canvas-XXXXXX", runtime);
   if (!mkdtemp(s->dir)) goto fail;
   size_t len = strlen(s->dir);
   memcpy(s->path, s->dir, len);
   memcpy(s->path + len, "/add", 5);
   for (unsigned i = 0; i < sizeof secret; ++i) {
      s->cap[i*2] = hex[secret[i] >> 4];
      s->cap[i*2+1] = hex[secret[i] & 15];
   }
   s->listener = socket(AF_UNIX, SOCK_STREAM | SOCK_NONBLOCK | SOCK_CLOEXEC, 0);
   if (s->listener < 0 || address(&a, s->path) ||
       bind(s->listener, (struct sockaddr *)&a, sizeof a) ||
       chmod(s->path, 0600) || listen(s->listener, 2) ||
       pthread_mutex_init(&s->mutex, NULL)) goto fail_dir;
   if (pthread_create(&s->worker, NULL, serve, s)) {
      pthread_mutex_destroy(&s->mutex);
      goto fail_dir;
   }
   strcpy(path, s->path);
   strcpy(cap, s->cap);
   return s;
fail_dir:
   if (s->listener >= 0) close(s->listener);
   (void)unlink(s->path);
   (void)rmdir(s->dir);
fail:
   free(s);
   return NULL;
}

void coyote_canvas_import_stop(struct service *s)
{
   if (!s) return;
   atomic_store(&s->stopped, 1);
   pthread_join(s->worker, NULL);
   close(s->listener);
   (void)unlink(s->path);
   (void)rmdir(s->dir);
   coyote_canvas_import_free(s->batch);
   pthread_mutex_destroy(&s->mutex);
   free(s);
}

int coyote_canvas_import_pending(struct service *s)
{
   pthread_mutex_lock(&s->mutex);
   int pending = s->batch != NULL;
   pthread_mutex_unlock(&s->mutex);
   return pending;
}

struct batch *coyote_canvas_import_take(struct service *s)
{
   struct batch *b;
   pthread_mutex_lock(&s->mutex);
   b = s->batch;
   s->batch = NULL;
   pthread_mutex_unlock(&s->mutex);
   return b;
}

void coyote_canvas_import_finish(struct service *s, int status, const char *text)
{
   pthread_mutex_lock(&s->mutex);
   if (s->active >= 0 && s->batch == NULL) {
      struct receipt *r = &s->cache[s->active];
      r->status = status;
      r->expiry = now() + CACHE_MS;
      (void)snprintf(r->text, sizeof r->text, "%s", text);
      s->active = -1;
   }
   pthread_mutex_unlock(&s->mutex);
}

static int connect_service(const char *path)
{
   struct sockaddr_un a;
   int fd;
   if (address(&a, path)) return -1;
   fd = socket(AF_UNIX, SOCK_STREAM | SOCK_NONBLOCK | SOCK_CLOEXEC, 0);
   if (fd < 0) return -1;
   if (connect(fd, (struct sockaddr *)&a, sizeof a) == 0 && same_user(fd)) return fd;
   close(fd);
   return -1;
}

static int receive_reply(int fd, char text[TEXT_MAX + 1], int64_t deadline)
{
   unsigned char h[5];
   uint32_t n;
   if (transfer(fd, h, 5, 0, deadline, NULL) || h[0] > PENDING) return UNKNOWN;
   memcpy(&n, h + 1, 4);
   n = ntohl(n);
   if (!n || n > TEXT_MAX || transfer(fd, text, n, 0, deadline, NULL)) return UNKNOWN;
   for (uint32_t i = 0; i < n; ++i)
      if (text[i] != '\t' && text[i] != '\n' && (text[i] < ' ' || text[i] > '~'))
         return UNKNOWN;
   text[n] = '\0';
   return h[0];
}

static int upload(int sock, const char *path, size_t *total, int64_t until)
{
   struct stat st;
   char buffer[65536], label[LABEL];
   const char *leaf = strrchr(path, '/');
   unsigned char len;
   int result = -1;
   int fd = open(path, O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC);
   if (fd < 0) return -1;
   if (fstat(fd, &st) || !S_ISREG(st.st_mode) || st.st_size <= 0 ||
       st.st_size > FILE_MAX || (uint64_t)st.st_size > BATCH_MAX - *total) goto done;
   leaf = leaf ? leaf + 1 : path;
   len = (unsigned char)strnlen(leaf, LABEL);
   if (!len) goto done;
   for (unsigned i = 0; i < len; ++i)
      label[i] = label_char((unsigned char)leaf[i]) ? leaf[i] : '_';
   uint32_t n = htonl((uint32_t)st.st_size);
   if (transfer(sock, &n, 4, 1, until, NULL) ||
       transfer(sock, &len, 1, 1, until, NULL) ||
       transfer(sock, label, len, 1, until, NULL)) goto done;
   size_t left = (size_t)st.st_size;
   while (left) {
      ssize_t k = read(fd, buffer, left < sizeof buffer ? left : sizeof buffer);
      if (k < 0 && errno == EINTR) continue;
      if (k <= 0 || transfer(sock, buffer, (size_t)k, 1, until, NULL)) goto done;
      left -= (size_t)k;
   }
   ssize_t extra;
   do { extra = read(fd, buffer, 1); } while (extra < 0 && errno == EINTR);
   if (extra != 0) goto done;
   *total += (size_t)st.st_size;
   result = 0;
done:
   close(fd);
   return result;
}

int coyote_canvas_import_client(const char *path, const char *cap, unsigned count,
                                const char *const *files, char *text)
{
   unsigned char h[86] = {'C','C','A','1',ADD,0}, admission;
   size_t total = 0;
   int fd, result;
   int64_t until;
   strcpy(text, "Canvas import unavailable: no authorized Canvas service");
   if (!count || count > FILES || strlen(cap) != 64 ||
       strspn(cap, "0123456789abcdef") != 64 || random_bytes(h + 6, 16)) return ERROR;
   fd = connect_service(path);
   if (fd < 0) return ERROR;
   h[5] = (unsigned char)count;
   memcpy(h + 22, cap, 64);
   until = now() + IO_MS;
   if (transfer(fd, h, sizeof h, 1, until, NULL) ||
       transfer(fd, &admission, 1, 0, until, NULL)) {
      close(fd);
      return ERROR;
   }
   if (admission) {
      strcpy(text, "Canvas import unavailable: service busy");
      close(fd);
      return ERROR;
   }
   until = now() + IO_MS;
   for (unsigned i = 0; i < count; ++i) {
      if (upload(fd, files[i], &total, until)) {
         close(fd);
         (void)snprintf(text, TEXT_MAX, "Image %u: cannot upload a bounded regular file", i+1);
         return ERROR;
      }
   }
   unsigned char end = 0xa5;
   (void)transfer(fd, &end, 1, 1, until, NULL);
   (void)shutdown(fd, SHUT_WR);
   result = receive_reply(fd, text, now() + RESULT_MS + IO_MS);
   close(fd);
   if (result != UNKNOWN && result != PENDING) return result;
   h[4] = QUERY;
   h[5] = 0;
   fd = connect_service(path);
   if (fd >= 0) {
      until = now() + IO_MS;
      if (!transfer(fd, h, sizeof h, 1, until, NULL)) {
         (void)shutdown(fd, SHUT_WR);
         result = receive_reply(fd, text, until);
      }
      close(fd);
   }
   if (result != OK && result != ERROR) {
      strcpy(text, "Canvas import outcome unknown; inspect Drawings before resubmitting");
      return UNKNOWN;
   }
   return result;
}
