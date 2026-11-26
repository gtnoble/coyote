#define _GNU_SOURCE
#include "coyote_canvas_tiles.h"

#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <jpeglib.h>
#include <png.h>
#include <setjmp.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <sys/stat.h>
#include <unistd.h>

#define W 259U
#define H 261U
static char temp_dir[512];
static int checks, failures;

struct cancel_after_payload {
   int fd;
   int observed_payload;
};

static int cancel_after_payload_write(void *user)
{
   struct cancel_after_payload *state = user;
   struct stat st;
   if (fstat(state->fd, &st) == 0 && st.st_size > 0) {
      state->observed_payload = 1;
      return 1;
   }
   return 0;
}

static void check(int ok, const char *name)
{
   ++checks;
   printf("%s: %s\n", name, ok ? "PASS" : "FAIL");
   failures += !ok;
}

static int make_file(const char *name)
{
   char path[512];
   if (snprintf(path, sizeof path, "%s/%s", temp_dir, name) >= (int)sizeof path)
      return -1;
   return open(path, O_RDWR | O_CREAT | O_TRUNC | O_CLOEXEC, 0600);
}

static int open_file(const char *name)
{
   char path[512];
   if (snprintf(path, sizeof path, "%s/%s", temp_dir, name) >= (int)sizeof path)
      return -1;
   return open(path, O_RDWR | O_CLOEXEC);
}

static int copy_and_truncate(const char *source_name, const char *target_name)
{
   int source = open_file(source_name);
   int target = make_file(target_name);
   struct stat st;
   unsigned char buffer[8192];
   ssize_t count;
   int result = -1;
   if (source < 0 || target < 0 || fstat(source, &st) < 0 || st.st_size <= 12)
      goto out;
   while ((count = read(source, buffer, sizeof buffer)) > 0)
      if (write(target, buffer, (size_t)count) != count) goto out;
   if (count < 0 || ftruncate(target, st.st_size - 12) < 0) goto out;
   result = 0;
out:
   if (source >= 0) close(source);
   if (target >= 0) close(target);
   return result;
}

static int pixel(unsigned x, unsigned y, unsigned char *p)
{
   p[0] = (unsigned char)(x * 17U + y * 3U);
   p[1] = (unsigned char)(x * 5U + y * 29U);
   p[2] = (unsigned char)(x * 11U + y * 7U);
   p[3] = ((x + y) % 9U == 0U) ? 0 : (unsigned char)(80U + (x + y) % 176U);
   if (p[3] == 0) { p[0] ^= 0xa5; p[1] ^= 0x5a; p[2] ^= 0x3c; }
   return 0;
}

static void expected_reduced_pixel(unsigned x, unsigned y, unsigned width,
                                   unsigned height, unsigned char *out)
{
   unsigned alpha = 0, samples = 0, sums[3] = {0, 0, 0};
   for (unsigned dy = 0; dy < 2; ++dy)
      for (unsigned dx = 0; dx < 2; ++dx) {
         unsigned px = x * 2U + dx, py = y * 2U + dy;
         unsigned char p[4];
         if (px >= width || py >= height) continue;
         pixel(px, py, p);
         ++samples;
         alpha += p[3];
         for (unsigned c = 0; c < 3; ++c) sums[c] += (unsigned)p[c] * p[3];
      }
   out[3] = (unsigned char)((alpha + samples / 2U) / samples);
   for (unsigned c = 0; c < 3; ++c)
      out[c] = alpha ? (unsigned char)((sums[c] + alpha / 2U) / alpha) : 0;
}

static int cancel_always(void *user)
{
   (void)user;
   return 1;
}

static int cancel_after_nonempty(void *user)
{
   int fd = *(int *)user;
   struct stat st;
   return fstat(fd, &st) == 0 && st.st_size > 0;
}

static int write_png(int fd, unsigned width, unsigned height, int interlace)
{
   FILE *f = fdopen(dup(fd), "wb");
   if (!f) return -1;
   png_structp png = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
   png_infop info = png ? png_create_info_struct(png) : NULL;
   unsigned char *row = malloc((size_t)width * 4U);
   int ok = 0;
   if (!png || !info || !row) goto out;
   if (setjmp(png_jmpbuf(png))) goto out;
   png_init_io(png, f);
   png_set_IHDR(png, info, width, height, 8, PNG_COLOR_TYPE_RGBA,
                interlace ? PNG_INTERLACE_ADAM7 : PNG_INTERLACE_NONE,
                PNG_COMPRESSION_TYPE_DEFAULT, PNG_FILTER_TYPE_DEFAULT);
   png_write_info(png, info);
   int passes = interlace ? png_set_interlace_handling(png) : 1;
   for (int pass = 0; pass < passes; ++pass)
      for (unsigned y = 0; y < height; ++y) {
         for (unsigned x = 0; x < width; ++x) pixel(x, y, row + (size_t)x * 4U);
         png_write_row(png, row);
      }
   png_write_end(png, info);
   ok = 1;
out:
   free(row);
   if (png) png_destroy_write_struct(&png, info ? &info : NULL);
   if (fclose(f) != 0) ok = 0;
   return ok ? 0 : -1;
}

static int write_jpeg(int fd, int progressive)
{
   FILE *f = fdopen(dup(fd), "wb");
   if (!f) return -1;
   struct jpeg_compress_struct c;
   struct jpeg_error_mgr e;
   unsigned char *row = malloc(W * 3U);
   int ok = 0;
   c.err = jpeg_std_error(&e);
   jpeg_create_compress(&c);
   jpeg_stdio_dest(&c, f);
   c.image_width = W; c.image_height = H; c.input_components = 3;
   c.in_color_space = JCS_RGB;
   jpeg_set_defaults(&c);
   jpeg_set_quality(&c, 90, TRUE);
   if (progressive) jpeg_simple_progression(&c);
   jpeg_start_compress(&c, TRUE);
   if (!row) goto out;
   while (c.next_scanline < c.image_height) {
      unsigned y = c.next_scanline;
      for (unsigned x = 0; x < W; ++x) {
         unsigned char p[4]; pixel(x, y, p);
         memcpy(row + (size_t)x * 3U, p, 3);
      }
      JSAMPROW rows[1] = {row};
      if (jpeg_write_scanlines(&c, rows, 1) != 1) goto out;
   }
   jpeg_finish_compress(&c);
   ok = 1;
out:
   free(row);
   jpeg_destroy_compress(&c);
   if (fclose(f) != 0) ok = 0;
   return ok ? 0 : -1;
}


static int import_named(const char *name, int dst, uint64_t cap,
                        coyote_canvas_tile_cancel cancel,
                        struct coyote_canvas_tile_info *info)
{
   int src = open_file(name);
   if (src < 0) return COYOTE_TILE_IO;
   int r = coyote_canvas_tiles_import(src, dst, cap, cancel, NULL, info);
   close(src);
   return r;
}

static int write_large(void)
{
   const unsigned side = 20000;
   int src = make_file("large.png"), dst = make_file("large.tiles");
   int ok = 0;
   if (src < 0 || dst < 0) goto out;
   /* Input consists of deterministic generated rows; no full image allocation. */
   FILE *f = fdopen(dup(src), "wb");
   png_structp png = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
   png_infop info = png ? png_create_info_struct(png) : NULL;
   unsigned char *row = malloc((size_t)side * 4U);
   if (!f || !png || !info || !row) goto out;
   if (setjmp(png_jmpbuf(png))) goto out;
   png_init_io(png, f);
   png_set_IHDR(png, info, side, side, 8, PNG_COLOR_TYPE_RGBA,
      PNG_INTERLACE_NONE, PNG_COMPRESSION_TYPE_DEFAULT, PNG_FILTER_TYPE_DEFAULT);
   png_write_info(png, info);
   for (unsigned y = 0; y < side; ++y) {
      for (unsigned x = 0; x < side; ++x) {
         unsigned char *p = row + (size_t)x * 4U;
         p[0] = (unsigned char)x; p[1] = (unsigned char)y;
         p[2] = (unsigned char)(x ^ y); p[3] = 255;
      }
      png_write_row(png, row);
   }
   png_write_end(png, info);
   ok = fclose(f) == 0;
   free(row); png_destroy_write_struct(&png, &info);
   if (!ok) goto out;
   struct coyote_canvas_tile_info extent;
   if (lseek(dst, 0, SEEK_SET) != 0 || import_named("large.png", dst,
       UINT64_C(1800000000), NULL, &extent) != COYOTE_TILE_OK ||
       extent.width != side || extent.height != side) { ok = 0; goto out; }
   unsigned char *tile = malloc((size_t)256 * 256 * 4);
   if (!tile) { ok = 0; goto out; }
   int r = coyote_canvas_tiles_read(dst, 78, 78, tile, (size_t)256 * 256 * 4, &extent);
   ok = r == COYOTE_TILE_OK && extent.width == 32 && extent.height == 32 &&
      tile[0] == (unsigned char)(78U * 256U) &&
      tile[1] == (unsigned char)(78U * 256U) && tile[3] == 255;
   free(tile);
out:
   if (src >= 0) close(src);
   if (dst >= 0) close(dst);
   return ok;
}

static int generated_tests(void)
{
   const uint32_t width = 259, height = 261;
   const int stride = (int)(width * 4U + 12U);
   unsigned char *band = calloc(256U, (size_t)stride);
   int fd = make_file("generated.tiles");
   if (!band || fd < 0) { free(band); if (fd >= 0) close(fd); return 0; }
   (void)lseek(fd, 13, SEEK_SET);
   void *writer = NULL;
   int ok = coyote_canvas_tiles_generated_begin(fd, width, height,
      UINT64_C(16) + (uint64_t)width * height * 4U, &writer) == COYOTE_TILE_OK && writer;
   for (uint32_t top = 0; ok && top < height; ) {
      uint32_t rows = height - top < 256U ? height - top : 256U;
      memset(band, 0xee, (size_t)rows * (size_t)stride);
      for (uint32_t y = 0; y < rows; ++y)
         for (uint32_t x = 0; x < width; ++x) {
            uint32_t value = UINT32_C(0xff000000) |
               ((x & 255U) << 16U) | (((top + y) & 255U) << 8U) |
               ((x + top + y) & 255U);
            memcpy(band + (size_t)y * (size_t)stride + (size_t)x * 4U,
                   &value, sizeof value);
         }
      ok = coyote_canvas_tiles_generated_band(writer, band, stride, rows) == COYOTE_TILE_OK;
      top += rows;
   }
   if (ok)
      ok = coyote_canvas_tiles_generated_end(writer) == COYOTE_TILE_OK;
   else
      coyote_canvas_tiles_generated_abort(writer);
   struct coyote_canvas_tile_info size, extent;
   unsigned char edge[3U * 5U * 4U];
   ok = ok && lseek(fd, 0, SEEK_CUR) == 13 &&
      coyote_canvas_tiles_inspect(fd, &size) == COYOTE_TILE_OK &&
      size.width == width && size.height == height &&
      coyote_canvas_tiles_read(fd, 1, 1, edge, sizeof edge, &extent) == COYOTE_TILE_OK &&
      extent.width == 3 && extent.height == 5;
   for (uint32_t y = 0; ok && y < 5; ++y)
      for (uint32_t x = 0; x < 3; ++x) {
         unsigned char expected[4] = {(unsigned char)((x + 256U) & 255U),
            (unsigned char)((y + 256U) & 255U),
            (unsigned char)((x + y + 512U) & 255U), 255};
         if (memcmp(edge + ((size_t)y * 3U + x) * 4U, expected, 4) != 0)
            ok = 0;
      }
   close(fd);
   fd = make_file("generated-incomplete.tiles");
   writer = NULL;
   ok = ok && fd >= 0 && coyote_canvas_tiles_generated_begin(fd, 1, 257,
      UINT64_C(16) + 1U * 257U * 4U, &writer) == COYOTE_TILE_OK;
   unsigned char *single_column = calloc(257U, 4U);
   if (!single_column) ok = 0;
   struct stat st;
   if (ok) {
      ok = coyote_canvas_tiles_generated_band(writer, single_column, 4, 256) == COYOTE_TILE_OK &&
         coyote_canvas_tiles_generated_end(writer) == COYOTE_TILE_INVALID;
      writer = NULL;
   }
   ok = ok && fstat(fd, &st) == 0 && st.st_size == 0;
   close(fd);
   fd = make_file("generated-abort.tiles");
   writer = NULL;
   if (fd < 0) ok = 0;
   if (ok) {
      ok = coyote_canvas_tiles_generated_begin(fd, 1, 257, 16U + 257U * 4U, &writer) == COYOTE_TILE_OK &&
         coyote_canvas_tiles_generated_band(writer, single_column, 4, 256) == COYOTE_TILE_OK &&
         coyote_canvas_tiles_generated_band(writer, single_column + 256U * 4U, 4, 1) == COYOTE_TILE_OK;
      if (writer) coyote_canvas_tiles_generated_abort(writer);
      ok = ok && fstat(fd, &st) == 0 && st.st_size == 0;
   }
   close(fd);
   fd = make_file("generated-cancel.tiles");
   writer = NULL;
   if (fd < 0) ok = 0;
   if (ok) {
      ok = coyote_canvas_tiles_generated_begin(fd, 1, 257, 16U + 257U * 4U, &writer) == COYOTE_TILE_OK &&
         coyote_canvas_tiles_generated_band(writer, single_column, 4, 256) == COYOTE_TILE_OK &&
         coyote_canvas_tiles_generated_band(writer, single_column + 256U * 4U, 4, 1) == COYOTE_TILE_OK;
      if (writer) coyote_canvas_tiles_generated_abort(writer);
      ok = ok && fstat(fd, &st) == 0 && st.st_size == 0;
   }
   free(single_column);
   close(fd);
   unsigned char pixel_data[4] = {0};
   fd = make_file("generated-stride.tiles");
   writer = NULL;
   if (fd < 0) ok = 0;
   if (ok) {
      ok = coyote_canvas_tiles_generated_begin(fd, 1, 1, 20, &writer) == COYOTE_TILE_OK &&
         coyote_canvas_tiles_generated_band(writer, pixel_data, 3, 1) == COYOTE_TILE_INVALID &&
         coyote_canvas_tiles_generated_end(writer) == COYOTE_TILE_INVALID &&
         fstat(fd, &st) == 0 && st.st_size == 0;
      writer = NULL;
   }
   close(fd);
   fd = make_file("generated-budget.tiles");
   writer = NULL;
   if (fd < 0) ok = 0;
   if (ok)
      ok = coyote_canvas_tiles_generated_begin(fd, 1, 1, 19, &writer) == COYOTE_TILE_LIMIT &&
         writer == NULL && fstat(fd, &st) == 0 && st.st_size == 0;
   close(fd);
   free(band);
   return ok;
}

int main(int argc, char **argv)
{
   int large = argc == 2 && strcmp(argv[1], "--large") == 0;
   if (argc > 1 && !large) { fprintf(stderr, "usage: %s [--large]\n", argv[0]); return 2; }
   const char *tmp = getenv("TMPDIR");
   if (!tmp || !*tmp) tmp = "/tmp";
   int n = snprintf(temp_dir, sizeof temp_dir, "%s/coyote-canvas-tiles-XXXXXX", tmp);
   if (n < 0 || (size_t)n >= sizeof temp_dir || !mkdtemp(temp_dir)) {
      perror("mkdtemp"); return 2;
   }
   check(generated_tests(), "generated Cairo RGB24 writer, edge tiles, budgets, rollback, and offsets");
   int png = make_file("pattern.png"), adam = make_file("adam.png");
   int jpg = make_file("baseline.jpg"), prog = make_file("progressive.jpg");
   int bad = make_file("bad.bin"), dst = make_file("asset.tiles");
   if (png < 0 || adam < 0 || jpg < 0 || prog < 0 || bad < 0 || dst < 0 ||
       write_png(png, W, H, 0) || write_png(adam, W, H, 1) ||
       write_jpeg(jpg, 0) || write_jpeg(prog, 1)) {
      perror("fixture creation"); return 2;
   }
   close(png); close(adam); close(jpg); close(prog);
   unsigned char nonsense[8] = {1,2,3,4,5,6,7,8};
   if (write(bad, nonsense, sizeof nonsense) != (ssize_t)sizeof nonsense) return 2;
   struct coyote_canvas_tile_info info = {0, 0}, extent;
   unsigned char *tile = malloc((size_t)256 * 256 * 4U);
   if (!tile) return 2;
   int src = open_file("pattern.png");
   (void)lseek(src, 17, SEEK_SET);
   off_t initial = lseek(src, 0, SEEK_CUR);
   int r = coyote_canvas_tiles_import(src, dst, UINT64_C(10000000), NULL, NULL, &info);
   check(r == COYOTE_TILE_OK && info.width == W && info.height == H, "PNG import and dimensions");
   check(lseek(src, 0, SEEK_CUR) == initial, "source offset unchanged");
   close(src);
   close(dst);
   dst = open_file("asset.tiles");
   check(dst >= 0 && coyote_canvas_tiles_inspect(dst, &info) == COYOTE_TILE_OK &&
         info.width == W && info.height == H, "inspect reopened tile asset");
   check(coyote_canvas_tiles_read(dst, 1, 1, tile, (size_t)256 * 256 * 4U, &extent) == COYOTE_TILE_OK &&
         extent.width == 3 && extent.height == 5, "partial bottom-right edge extent");
   unsigned char p[4]; pixel(256, 256, p);
   check(memcmp(tile, p, 4) == 0, "edge pixel is packed RGBA");
   pixel(257, 260, p);
   check(memcmp(tile + ((size_t)4 * 3U + 1U) * 4U, p, 4) == 0, "edge tile row has no padding");
   int reduced = make_file("reduced.tiles");
   (void)lseek(dst, 7, SEEK_SET);
   (void)lseek(reduced, 11, SEEK_SET);
   int reduce_result = coyote_canvas_tiles_reduce(dst, reduced, NULL, NULL);
   struct coyote_canvas_tile_info reduced_size;
   int reduced_ok = reduce_result == COYOTE_TILE_OK &&
      coyote_canvas_tiles_inspect(reduced, &reduced_size) == COYOTE_TILE_OK &&
      reduced_size.width == (W + 1U) / 2U && reduced_size.height == (H + 1U) / 2U &&
      lseek(dst, 0, SEEK_CUR) == 7 && lseek(reduced, 0, SEEK_CUR) == 11;
   if (reduced_ok) {
      unsigned char *out_tile = malloc((size_t)256 * 256 * 4U);
      reduced_ok = out_tile && coyote_canvas_tiles_read(reduced, 0, 0, out_tile,
         (size_t)256 * 256 * 4U, &extent) == COYOTE_TILE_OK &&
         extent.width == 130 && extent.height == 131;
      if (reduced_ok) {
         for (unsigned y = 0; y < extent.height; ++y)
            for (unsigned x = 0; x < extent.width; ++x) {
               unsigned char expected[4];
               expected_reduced_pixel(x, y, W, H, expected);
               if (memcmp(out_tile + ((size_t)y * extent.width + x) * 4U,
                          expected, 4) != 0) reduced_ok = 0;
            }
      }
      free(out_tile);
   }
   check(reduced_ok, "2x alpha-weighted reduction handles odd extent and offsets");
   struct stat cancelled_stat;
   int nonempty_reduce = make_file("reduced-nonempty.tiles");
   unsigned char marker = 0x5a;
   (void)write(nonempty_reduce, &marker, 1);
   check(coyote_canvas_tiles_reduce(dst, nonempty_reduce, NULL, NULL) == COYOTE_TILE_INVALID &&
         fstat(nonempty_reduce, &cancelled_stat) == 0 && cancelled_stat.st_size == 1,
         "reduction rejects nonempty staging without modification");
   check(coyote_canvas_tiles_reduce(dst, dst, NULL, NULL) == COYOTE_TILE_INVALID,
         "reduction rejects source/staging alias");
   close(nonempty_reduce);
   int cancelled_stage = make_file("reduced-cancel.tiles");
   check(coyote_canvas_tiles_reduce(dst, cancelled_stage, cancel_always, NULL) ==
         COYOTE_TILE_CANCELLED && fstat(cancelled_stage, &cancelled_stat) == 0 &&
         cancelled_stat.st_size == 0,
         "reduction cancellation rolls staging back");
   close(cancelled_stage);
   int late_stage = make_file("reduced-late-cancel.tiles");
   check(coyote_canvas_tiles_reduce(dst, late_stage, cancel_after_nonempty, &late_stage) ==
         COYOTE_TILE_CANCELLED && fstat(late_stage, &cancelled_stat) == 0 &&
         cancelled_stat.st_size == 0,
         "late reduction cancellation rolls staging back");
   close(late_stage);
   close(reduced);
   check(coyote_canvas_tiles_read(dst, 2, 0, tile, (size_t)256 * 256 * 4U, &extent) != COYOTE_TILE_OK,
         "out-of-range tile rejected");
   check(coyote_canvas_tiles_read(dst, 0, 0, tile, 4, &extent) != COYOTE_TILE_OK,
         "undersized capacity rejected");
   src = open_file("pattern.png");
   struct stat st;
   check(fstat(dst, &st) == 0, "stat staging before nonempty check");
   off_t existing_size = st.st_size;
   check(coyote_canvas_tiles_import(src, dst, UINT64_C(10000000), NULL, NULL, &info) != COYOTE_TILE_OK,
         "nonempty staging rejected");
   check(fstat(dst, &st) == 0 && st.st_size == existing_size &&
         coyote_canvas_tiles_inspect(dst, &info) == COYOTE_TILE_OK,
         "nonempty staging remains unmodified");
   close(src);

   int adam_dst = make_file("adam.tiles");
   check(import_named("adam.png", adam_dst, UINT64_C(10000000), NULL, &info) == COYOTE_TILE_OK &&
         coyote_canvas_tiles_read(adam_dst, 0, 0, tile, (size_t)256 * 256 * 4U, &extent) == COYOTE_TILE_OK,
         "Adam7 import and read");
   int adam_matches = 1;
   for (unsigned y = 0; y < 256; ++y)
      for (unsigned x = 0; x < 256; ++x) {
         pixel(x, y, p);
         if (memcmp(tile + ((size_t)y * 256U + x) * 4U, p, 4) != 0)
            adam_matches = 0;
      }
   check(adam_matches, "Adam7 full top-left tile matches patterned RGBA");
   close(adam_dst);

   int jpeg_dst = make_file("jpeg.tiles");
   int jr = import_named("baseline.jpg", jpeg_dst, UINT64_C(10000000), NULL, &info);
   check(jr == COYOTE_TILE_OK && info.width == W && info.height == H &&
         coyote_canvas_tiles_read(jpeg_dst, 0, 0, tile, (size_t)256 * 256 * 4U, &extent) == COYOTE_TILE_OK && tile[3] == 255,
         "baseline JPEG import is opaque RGBA"); close(jpeg_dst);
   int progressive_dst = make_file("progressive.tiles");
   check(import_named("progressive.jpg", progressive_dst, UINT64_C(10000000), NULL, &info) == COYOTE_TILE_UNSUPPORTED,
         "progressive JPEG rejected"); close(progressive_dst);

   int bad_dst = make_file("bad.tiles");
   check(import_named("bad.bin", bad_dst, UINT64_C(1000000), NULL, &info) != COYOTE_TILE_OK,
         "malformed asset rejected");
   check(fstat(bad_dst, &st) == 0 && st.st_size == 0,
         "malformed asset failure rolls staging back");
   int trunc = make_file("truncated.png");
   int original = open_file("pattern.png");
   unsigned char copy_buffer[8192];
   ssize_t copied;
   while ((copied = read(original, copy_buffer, sizeof copy_buffer)) > 0)
      if (write(trunc, copy_buffer, (size_t)copied) != copied) return 2;
   if (copied < 0 || fstat(trunc, &st) != 0 || st.st_size <= 12 ||
       ftruncate(trunc, st.st_size - 12) != 0) return 2;
   close(original); close(trunc);
   int trunc_dst = make_file("trunc.tiles");
   check(import_named("truncated.png", trunc_dst, UINT64_C(10000000), NULL, &info) != COYOTE_TILE_OK,
         "truncated PNG rejected");
   check(fstat(trunc_dst, &st) == 0 && st.st_size == 0,
         "truncated PNG failure rolls staging back");
   close(trunc_dst);
   check(copy_and_truncate("baseline.jpg", "truncated.jpg") == 0,
         "create truncated JPEG fixture");
   int trunc_jpeg_dst = make_file("trunc-jpeg.tiles");
   check(import_named("truncated.jpg", trunc_jpeg_dst, UINT64_C(10000000), NULL, &info) != COYOTE_TILE_OK,
         "truncated JPEG rejected");
   check(fstat(trunc_jpeg_dst, &st) == 0 && st.st_size == 0,
         "truncated JPEG failure rolls staging back");
   close(trunc_jpeg_dst);
   check(import_named("pattern.png", bad_dst, 32, NULL, &info) == COYOTE_TILE_LIMIT &&
         fstat(bad_dst, &st) == 0 && st.st_size == 0, "disk cap failure rolls staging back");
   int cancel_dst = make_file("cancel.tiles");
   src = open_file("pattern.png");
   struct cancel_after_payload cancel_state = {cancel_dst, 0};
   int cancel_result = coyote_canvas_tiles_import(src, cancel_dst, UINT64_C(10000000),
      cancel_after_payload_write, &cancel_state, &info);
   check(cancel_result == COYOTE_TILE_CANCELLED && cancel_state.observed_payload,
         "late cancellation observed nonempty staging payload");
   check(fstat(cancel_dst, &st) == 0 && st.st_size == 0,
         "late cancellation rolls staging back");
   close(src); close(cancel_dst);
   src = open_file("pattern.png");
   check(coyote_canvas_tiles_import(src, src, UINT64_C(10000000), NULL, NULL, &info) != COYOTE_TILE_OK,
         "valid source/staging alias rejected");
   close(src);
   check(fstat(bad_dst, &st) == 0 && st.st_size == 0, "failed imports leave empty staging");
   close(bad_dst); close(bad); close(dst);
   free(tile);
   if (large) {
      struct rlimit limit = {UINT64_C(128) * 1024 * 1024, UINT64_C(128) * 1024 * 1024};
      if (setrlimit(RLIMIT_AS, &limit) != 0) { perror("setrlimit"); return 2; }
      check(write_large(), "20k PNG streams and tiles under 128 MiB address-space cap");
   }
   printf("checks=%d failures=%d\n", checks, failures);
   static const char *files[] = {
      "pattern.png", "truncated.png", "truncated.jpg", "adam.png", "baseline.jpg", "progressive.jpg", "bad.bin",
      "asset.tiles", "adam.tiles", "jpeg.tiles", "progressive.tiles",
      "bad.tiles", "trunc.tiles", "trunc-jpeg.tiles", "cancel.tiles", "large.png", "large.tiles"
   };
   char path[1024];
   for (size_t i = 0; i < sizeof files / sizeof files[0]; ++i) {
      (void)snprintf(path, sizeof path, "%s/%s", temp_dir, files[i]);
      (void)unlink(path);
   }
   (void)rmdir(temp_dir);
   return failures ? 1 : 0;
}
