#define _GNU_SOURCE
#define _FILE_OFFSET_BITS 64
#include "coyote_canvas_tiles.h"

#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

/* Fixed v1 header: magic/version, then big-endian width and height.
 * The payload packs tiles across each band without padding, including edges.
 * Bound band RAM independently of the caller's disk allowance. */
#define HEADER_BYTES 16U
#define MAX_SIDE COYOTE_CANVAS_TILE_MAX_SIDE
#define TILE_SIDE COYOTE_CANVAS_TILE_SIDE
#define PIXEL_BYTES 4U

static const unsigned char magic[8] = {'C', 'Y', 'T', 'I', 'L', 'E', 0, 1};

struct coyote_canvas_tile_writer {
   int fd;
   uint64_t max_bytes;
   coyote_canvas_tile_cancel cancel;
   void *user;
   struct coyote_canvas_tile_info size;
   unsigned char *band;
   uint32_t top, rows;
   int dirty;
};

static uint32_t smaller(uint32_t x, uint32_t y)
{
   return x < y ? x : y;
}

static uint64_t file_size(uint32_t width, uint32_t height)
{
   return HEADER_BYTES + (uint64_t)width * height * PIXEL_BYTES;
}

static int valid_size(uint32_t width, uint32_t height)
{
   return width && height && width <= MAX_SIDE && height <= MAX_SIDE;
}

static void put_u32(unsigned char *p, uint32_t n)
{
   for (unsigned i = 0; i < 4; ++i)
      p[i] = (unsigned char)(n >> (24U - i * 8U));
}

static uint32_t get_u32(const unsigned char *p)
{
   uint32_t n = 0;
   for (unsigned i = 0; i < 4; ++i)
      n = (n << 8U) | p[i];
   return n;
}

static int read_at(int fd, unsigned char *data, size_t bytes, off_t offset)
{
   while (bytes) {
      ssize_t n = pread(fd, data, bytes, offset);
      if (n < 0 && errno == EINTR)
         continue;
      if (n <= 0)
         return n == 0 ? COYOTE_TILE_INVALID : COYOTE_TILE_IO;
      data += n;
      bytes -= (size_t)n;
      offset += n;
   }
   return COYOTE_TILE_OK;
}

static int write_at(int fd, const unsigned char *data, size_t bytes,
                    off_t offset)
{
   while (bytes) {
      ssize_t n = pwrite(fd, data, bytes, offset);
      if (n < 0 && errno == EINTR)
         continue;
      if (n <= 0)
         return COYOTE_TILE_IO;
      data += n;
      bytes -= (size_t)n;
      offset += n;
   }
   return COYOTE_TILE_OK;
}

static off_t band_offset(uint32_t width, uint32_t top)
{
   return (off_t)file_size(width, top);
}

int coyote_canvas_tiles_cancelled(const struct coyote_canvas_tile_writer *w)
{
   return w->cancel && w->cancel(w->user);
}

static int flush_band(struct coyote_canvas_tile_writer *w)
{
   if (!w->dirty)
      return COYOTE_TILE_OK;
   if (coyote_canvas_tiles_cancelled(w))
      return COYOTE_TILE_CANCELLED;
   int result = write_at(w->fd, w->band,
                         (size_t)w->size.width * w->rows * PIXEL_BYTES,
                         band_offset(w->size.width, w->top));
   if (result == COYOTE_TILE_OK)
      w->dirty = 0;
   return result;
}

int coyote_canvas_tiles_begin(struct coyote_canvas_tile_writer *w,
                              uint32_t width, uint32_t height)
{
   if (w->band)
      return COYOTE_TILE_INVALID;
   if (!valid_size(width, height) || file_size(width, height) > w->max_bytes)
      return COYOTE_TILE_LIMIT;
   if (coyote_canvas_tiles_cancelled(w))
      return COYOTE_TILE_CANCELLED;
   w->band = malloc((size_t)width * smaller(height, TILE_SIDE) * PIXEL_BYTES);
   if (!w->band)
      return COYOTE_TILE_MEMORY;
   w->size = (struct coyote_canvas_tile_info){width, height};
   return COYOTE_TILE_OK;
}

int coyote_canvas_tiles_row(struct coyote_canvas_tile_writer *w, uint32_t y,
                            unsigned char *rgba, int write_row)
{
   if (!w->band || !rgba || y >= w->size.height)
      return COYOTE_TILE_INVALID;
   uint32_t top = y - y % TILE_SIDE;
   uint32_t width = w->size.width;
   if (!w->rows || top != w->top) {
      int result = flush_band(w);
      if (result != COYOTE_TILE_OK)
         return result;
      w->top = top;
      w->rows = smaller(w->size.height - top, TILE_SIDE);
      if (!write_row) {
         result = read_at(w->fd, w->band, (size_t)width * w->rows * PIXEL_BYTES,
                          band_offset(width, top));
         if (result != COYOTE_TILE_OK)
            return result;
      }
   }
   for (uint32_t x = 0; x < width; x += TILE_SIDE) {
      uint32_t span = smaller(width - x, TILE_SIDE);
      unsigned char *tile_row = w->band +
         ((size_t)x * w->rows + (size_t)(y - top) * span) * PIXEL_BYTES;
      unsigned char *segment = rgba + (size_t)x * PIXEL_BYTES;
      if (write_row)
         memcpy(tile_row, segment, (size_t)span * PIXEL_BYTES);
      else
         memcpy(segment, tile_row, (size_t)span * PIXEL_BYTES);
   }
   if (write_row)
      w->dirty = 1;
   return COYOTE_TILE_OK;
}

int coyote_canvas_tiles_import(int source_fd, int staging_fd,
                              uint64_t max_bytes,
                              coyote_canvas_tile_cancel cancel, void *user,
                              struct coyote_canvas_tile_info *info)
{
   struct stat source, staging;
   struct coyote_canvas_tile_writer w = {
      .fd = staging_fd, .max_bytes = max_bytes, .cancel = cancel, .user = user
   };
   unsigned char header[HEADER_BYTES];
   if (!info)
      return COYOTE_TILE_INVALID;
   *info = (struct coyote_canvas_tile_info){0, 0};
   if (fstat(source_fd, &source) < 0 || fstat(staging_fd, &staging) < 0)
      return COYOTE_TILE_IO;
   if (!S_ISREG(source.st_mode) || !S_ISREG(staging.st_mode) ||
       staging.st_size != 0 ||
       (source.st_dev == staging.st_dev && source.st_ino == staging.st_ino))
      return COYOTE_TILE_INVALID;
   int flags = fcntl(staging_fd, F_GETFL);
   if (flags < 0)
      return COYOTE_TILE_IO;
   if ((flags & O_ACCMODE) != O_RDWR || (flags & O_APPEND))
      return COYOTE_TILE_INVALID;
   int result = coyote_canvas_tiles_decode(source_fd, &w);
   if (result == COYOTE_TILE_OK)
      result = flush_band(&w);
   if (result == COYOTE_TILE_OK && coyote_canvas_tiles_cancelled(&w))
      result = COYOTE_TILE_CANCELLED;
   if (result == COYOTE_TILE_OK) {
      memcpy(header, magic, sizeof magic);
      put_u32(header + 8, w.size.width);
      put_u32(header + 12, w.size.height);
      result = write_at(w.fd, header, sizeof header, 0);
   }
   free(w.band);
   if (result == COYOTE_TILE_OK)
      *info = w.size;
   else if (ftruncate(staging_fd, 0) < 0)
      result = COYOTE_TILE_IO;
   return result;
}

int coyote_canvas_tiles_inspect(int fd, struct coyote_canvas_tile_info *info)
{
   struct stat st;
   unsigned char header[HEADER_BYTES];
   if (!info)
      return COYOTE_TILE_INVALID;
   *info = (struct coyote_canvas_tile_info){0, 0};
   if (fstat(fd, &st) < 0)
      return COYOTE_TILE_IO;
   if (!S_ISREG(st.st_mode) || st.st_size < (off_t)sizeof header)
      return COYOTE_TILE_INVALID;
   int result = read_at(fd, header, sizeof header, 0);
   if (result != COYOTE_TILE_OK)
      return result;
   uint32_t width = get_u32(header + 8);
   uint32_t height = get_u32(header + 12);
   if (memcmp(magic, header, sizeof magic) != 0 || !valid_size(width, height) ||
       (uint64_t)st.st_size != file_size(width, height))
      return COYOTE_TILE_INVALID;
   *info = (struct coyote_canvas_tile_info){width, height};
   return COYOTE_TILE_OK;
}

int coyote_canvas_tiles_read(int fd, uint32_t tile_x, uint32_t tile_y,
                            unsigned char *rgba, size_t capacity,
                            struct coyote_canvas_tile_info *extent)
{
   struct coyote_canvas_tile_info size;
   if (!extent)
      return COYOTE_TILE_INVALID;
   *extent = (struct coyote_canvas_tile_info){0, 0};
   int result = coyote_canvas_tiles_inspect(fd, &size);
   if (result != COYOTE_TILE_OK)
      return result;
   if (!rgba || tile_x > (size.width - 1) / TILE_SIDE ||
       tile_y > (size.height - 1) / TILE_SIDE)
      return COYOTE_TILE_INVALID;
   uint32_t x = tile_x * TILE_SIDE, y = tile_y * TILE_SIDE;
   uint32_t width = smaller(size.width - x, TILE_SIDE);
   uint32_t height = smaller(size.height - y, TILE_SIDE);
   size_t bytes = (size_t)width * height * PIXEL_BYTES;
   if (capacity < bytes)
      return COYOTE_TILE_INVALID;
   result = read_at(fd, rgba, bytes, band_offset(size.width, y) +
                    (off_t)x * height * PIXEL_BYTES);
   if (result == COYOTE_TILE_OK)
      *extent = (struct coyote_canvas_tile_info){width, height};
   return result;
}

int coyote_canvas_tiles_reduce(int source_fd, int staging_fd,
                              coyote_canvas_tile_cancel cancel, void *user)
{
   struct stat source, staging;
   struct coyote_canvas_tile_info in_size;
   unsigned char header[HEADER_BYTES];
   const size_t capacity = (size_t)TILE_SIDE * TILE_SIDE * PIXEL_BYTES;
   unsigned char *tiles[4] = {NULL, NULL, NULL, NULL};
   unsigned char *output = NULL;
   int result = COYOTE_TILE_INVALID;

   if (fstat(source_fd, &source) < 0 || fstat(staging_fd, &staging) < 0)
      return COYOTE_TILE_IO;
   if (!S_ISREG(source.st_mode) || !S_ISREG(staging.st_mode) || staging.st_size != 0 ||
       (source.st_dev == staging.st_dev && source.st_ino == staging.st_ino))
      return COYOTE_TILE_INVALID;
   int flags = fcntl(staging_fd, F_GETFL);
   if (flags < 0)
      return COYOTE_TILE_IO;
   if ((flags & O_ACCMODE) != O_RDWR || (flags & O_APPEND))
      return COYOTE_TILE_INVALID;
   result = coyote_canvas_tiles_inspect(source_fd, &in_size);
   if (result != COYOTE_TILE_OK)
      goto done;
   uint32_t width = (in_size.width + 1U) / 2U;
   uint32_t height = (in_size.height + 1U) / 2U;
   uint32_t nx = (width + TILE_SIDE - 1U) / TILE_SIDE;
   uint32_t ny = (height + TILE_SIDE - 1U) / TILE_SIDE;
   if (cancel && cancel(user)) {
      result = COYOTE_TILE_CANCELLED;
      goto done;
   }
   for (unsigned i = 0; i < 4; ++i) {
      tiles[i] = malloc(capacity);
      if (!tiles[i]) { result = COYOTE_TILE_MEMORY; goto done; }
   }
   output = malloc(capacity);
   if (!output) { result = COYOTE_TILE_MEMORY; goto done; }
   result = COYOTE_TILE_OK;
   for (uint32_t oy = 0; oy < ny && result == COYOTE_TILE_OK; ++oy) {
      uint32_t out_y = oy * TILE_SIDE;
      uint32_t out_h = smaller(height - out_y, TILE_SIDE);
      uint32_t sy = out_y * 2U;
      uint32_t sy_end = smaller(in_size.height, sy + out_h * 2U);
      uint32_t ytile[2] = {sy / TILE_SIDE, (sy_end - 1U) / TILE_SIDE};
      unsigned yn = ytile[0] == ytile[1] ? 1U : 2U;
      for (uint32_t ox = 0; ox < nx && result == COYOTE_TILE_OK; ++ox) {
         if (cancel && cancel(user)) { result = COYOTE_TILE_CANCELLED; break; }
         uint32_t out_x = ox * TILE_SIDE;
         uint32_t out_w = smaller(width - out_x, TILE_SIDE);
         uint32_t sx = out_x * 2U;
         uint32_t sx_end = smaller(in_size.width, sx + out_w * 2U);
         uint32_t xtile[2] = {sx / TILE_SIDE, (sx_end - 1U) / TILE_SIDE};
         unsigned xn = xtile[0] == xtile[1] ? 1U : 2U;
         uint32_t tw[2] = {0, 0};
         for (unsigned iy = 0; iy < yn && result == COYOTE_TILE_OK; ++iy)
            for (unsigned ix = 0; ix < xn; ++ix) {
               unsigned index = iy * xn + ix;
               struct coyote_canvas_tile_info extent;
               result = coyote_canvas_tiles_read(source_fd, xtile[ix], ytile[iy],
                                                 tiles[index], capacity, &extent);
               if (result != COYOTE_TILE_OK) break;
               tw[ix] = extent.width;
            }
         if (result != COYOTE_TILE_OK) break;
         for (uint32_t y = 0; y < out_h; ++y)
            for (uint32_t x = 0; x < out_w; ++x) {
               unsigned alpha = 0, count = 0, sums[3] = {0, 0, 0};
               for (uint32_t dy = 0; dy < 2; ++dy)
                  for (uint32_t dx = 0; dx < 2; ++dx) {
                     uint32_t px = sx + 2U * x + dx, py = sy + 2U * y + dy;
                     if (px >= in_size.width || py >= in_size.height) continue;
                     unsigned ix = px / TILE_SIDE == xtile[0] ? 0U : 1U;
                     unsigned iy = py / TILE_SIDE == ytile[0] ? 0U : 1U;
                     const unsigned char *p = tiles[iy * xn + ix] +
                        ((size_t)(py % TILE_SIDE) * tw[ix] + px % TILE_SIDE) * PIXEL_BYTES;
                     ++count;
                     alpha += p[3];
                     for (unsigned c = 0; c < 3; ++c) sums[c] += (unsigned)p[c] * p[3];
                  }
               unsigned char *d = output + ((size_t)y * out_w + x) * PIXEL_BYTES;
               d[3] = (unsigned char)((alpha + count / 2U) / count);
               for (unsigned c = 0; c < 3; ++c)
                  d[c] = alpha ? (unsigned char)((sums[c] + alpha / 2U) / alpha) : 0;
            }
         if (cancel && cancel(user)) { result = COYOTE_TILE_CANCELLED; break; }
         off_t offset = band_offset(width, out_y) + (off_t)out_x * out_h * PIXEL_BYTES;
         result = write_at(staging_fd, output, (size_t)out_w * out_h * PIXEL_BYTES, offset);
      }
   }
   if (result == COYOTE_TILE_OK && cancel && cancel(user))
      result = COYOTE_TILE_CANCELLED;
   if (result == COYOTE_TILE_OK) {
      memcpy(header, magic, sizeof magic);
      put_u32(header + 8, width);
      put_u32(header + 12, height);
      result = write_at(staging_fd, header, sizeof header, 0);
   }
done:
   for (unsigned i = 0; i < 4; ++i) free(tiles[i]);
   free(output);
   if (result != COYOTE_TILE_OK && ftruncate(staging_fd, 0) < 0)
      result = COYOTE_TILE_IO;
   return result;
}

/* An unlinked private file, never reachable through the session sidecar. */
int coyote_canvas_tiles_stage(void)
{
   char path[] = "/tmp/coyote-tile-XXXXXX";
   int fd = mkostemp(path, O_CLOEXEC);
   if (fd >= 0 && unlink(path) < 0) {
      close(fd);
      return -1;
   }
   return fd;
}
