#define _GNU_SOURCE
#define _FILE_OFFSET_BITS 64
#include "coyote_canvas_tiles.h"

#include <stddef.h>
#include <stdio.h>
#include <errno.h>
#include <jpeglib.h>
#include <jerror.h>
#include <png.h>
#include <setjmp.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

enum {
   TILE_MAX_PNG_CHUNK = 1048576,
   INPUT_BLOCK = 65536
};

struct png_input {
   int fd;
   off_t offset;
   off_t length;
   struct coyote_canvas_tile_writer *writer;
   int result;
};

static void png_error_silent(png_structp png, png_const_charp message)
{
   (void)message;
   png_longjmp(png, 1);
}

static void png_read_fd(png_structp png, png_bytep out, png_size_t length)
{
   struct png_input *in = png_get_io_ptr(png);
   if ((uintmax_t)length > (uintmax_t)(in->length - in->offset))
      png_error(png, "truncated PNG");
   size_t done = 0;
   while (done < length) {
      if (coyote_canvas_tiles_cancelled(in->writer)) {
         in->result = COYOTE_TILE_CANCELLED;
         png_error(png, "cancelled");
      }
      size_t wanted = length - done;
      if (wanted > INPUT_BLOCK) wanted = INPUT_BLOCK;
      ssize_t n = pread(in->fd, out + done, wanted, in->offset);
      if (n < 0 && errno == EINTR) continue;
      if (n < 0) {
         in->result = COYOTE_TILE_IO;
         png_error(png, "input read failed");
      }
      if (n == 0) {
         in->result = COYOTE_TILE_INVALID;
         png_error(png, "truncated PNG");
      }
      in->offset += n;
      done += (size_t)n;
   }
}

struct png_state {
   png_structp png;
   png_infop info;
   png_bytep row;
   struct png_input input;
   int result;
};

static int decode_png(int fd, struct coyote_canvas_tile_writer *writer,
                      off_t length)
{
   struct png_state *state = calloc(1, sizeof *state);
   if (!state) return COYOTE_TILE_MEMORY;
   state->input = (struct png_input){fd, 0, length, writer, COYOTE_TILE_INVALID};
   state->result = COYOTE_TILE_INVALID;
   state->png = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL,
                                       png_error_silent, png_error_silent);
   if (!state->png) {
      free(state);
      return COYOTE_TILE_MEMORY;
   }
   state->info = png_create_info_struct(state->png);
   if (!state->info) {
      png_destroy_read_struct(&state->png, NULL, NULL);
      free(state);
      return COYOTE_TILE_MEMORY;
   }
   if (setjmp(png_jmpbuf(state->png))) {
      int result = state->input.result != COYOTE_TILE_INVALID
         ? state->input.result : state->result;
      free(state->row);
      png_destroy_read_struct(&state->png, &state->info, NULL);
      free(state);
      return result == COYOTE_TILE_OK ? COYOTE_TILE_INVALID : result;
   }
   png_set_read_fn(state->png, &state->input, png_read_fd);
#ifdef PNG_HANDLE_AS_UNKNOWN_SUPPORTED
   /* Ignore non-pixel metadata; do not inflate text or ICC profiles. */
   png_set_keep_unknown_chunks(state->png, PNG_HANDLE_CHUNK_NEVER, NULL, -1);
#endif
#if PNG_LIBPNG_VER >= 10400
   png_set_chunk_malloc_max(state->png, TILE_MAX_PNG_CHUNK);
   png_set_chunk_cache_max(state->png, 128);
#endif
   png_read_info(state->png, state->info);
   png_uint_32 width, height;
   int bit_depth, color_type, interlace, compression, filter;
   if (!png_get_IHDR(state->png, state->info, &width, &height, &bit_depth,
                     &color_type, &interlace, &compression, &filter))
      png_error(state->png, "missing IHDR");
   if (!width || !height || width > COYOTE_CANVAS_TILE_MAX_SIDE ||
       height > COYOTE_CANVAS_TILE_MAX_SIDE) {
      state->result = COYOTE_TILE_LIMIT;
      png_error(state->png, "image dimensions exceed limit");
   }
   if (bit_depth == 16) png_set_strip_16(state->png);
   if (color_type == PNG_COLOR_TYPE_PALETTE) png_set_palette_to_rgb(state->png);
   if (color_type == PNG_COLOR_TYPE_GRAY && bit_depth < 8)
      png_set_expand_gray_1_2_4_to_8(state->png);
   if (png_get_valid(state->png, state->info, PNG_INFO_tRNS))
      png_set_tRNS_to_alpha(state->png);
   if (color_type == PNG_COLOR_TYPE_GRAY || color_type == PNG_COLOR_TYPE_GRAY_ALPHA)
      png_set_gray_to_rgb(state->png);
   if (!(color_type & PNG_COLOR_MASK_ALPHA) &&
       !png_get_valid(state->png, state->info, PNG_INFO_tRNS))
      png_set_filler(state->png, 0xff, PNG_FILLER_AFTER);
   int passes = png_set_interlace_handling(state->png);
   png_read_update_info(state->png, state->info);
   if (png_get_bit_depth(state->png, state->info) != 8 ||
       png_get_channels(state->png, state->info) != 4 ||
       png_get_rowbytes(state->png, state->info) != (png_size_t)width * 4U)
      png_error(state->png, "unsupported transformed PNG layout");
   state->result = coyote_canvas_tiles_begin(writer, width, height);
   if (state->result != COYOTE_TILE_OK)
      png_error(state->png, "writer rejected dimensions");
   state->row = malloc((size_t)width * 4U);
   if (!state->row) {
      state->result = COYOTE_TILE_MEMORY;
      png_error(state->png, "row allocation failed");
   }
   for (int pass = 0; pass < passes; ++pass) {
      for (png_uint_32 y = 0; y < height; ++y) {
         if (coyote_canvas_tiles_cancelled(writer)) {
            state->result = COYOTE_TILE_CANCELLED;
            png_error(state->png, "cancelled");
         }
         if (pass == 0) {
            memset(state->row, 0, (size_t)width * 4U);
         } else {
            state->result = coyote_canvas_tiles_row(writer, y, state->row, 0);
            if (state->result != COYOTE_TILE_OK)
               png_error(state->png, "cannot restore interlace row");
         }
         png_read_row(state->png, state->row, NULL);
         state->result = coyote_canvas_tiles_row(writer, y, state->row, 1);
         if (state->result != COYOTE_TILE_OK)
            png_error(state->png, "cannot store decoded row");
      }
   }
   png_read_end(state->png, state->info);
   free(state->row);
   png_destroy_read_struct(&state->png, &state->info, NULL);
   free(state);
   return COYOTE_TILE_OK;
}

struct jpeg_error {
   struct jpeg_error_mgr base;
   jmp_buf jump;
};

struct jpeg_input {
   struct jpeg_source_mgr base;
   int fd;
   off_t offset;
   off_t length;
   struct coyote_canvas_tile_writer *writer;
   int result;
   JOCTET buffer[INPUT_BLOCK];
};

struct jpeg_state {
   struct jpeg_decompress_struct cinfo;
   struct jpeg_error error;
   struct jpeg_input input;
   unsigned char *sample_row;
   unsigned char *rgba_row;
   int created;
   int result;
};

static void jpeg_fail(j_common_ptr common)
{
   struct jpeg_error *error = (struct jpeg_error *)common->err;
   longjmp(error->jump, 1);
}

static void jpeg_message(j_common_ptr common, int level)
{
   if (level < 0) jpeg_fail(common);
}

static void jpeg_init_source(j_decompress_ptr cinfo)
{
   struct jpeg_input *input = (struct jpeg_input *)cinfo->src;
   input->offset = 0;
   input->base.bytes_in_buffer = 0;
   input->base.next_input_byte = NULL;
}

static boolean jpeg_fill_input_buffer(j_decompress_ptr cinfo)
{
   struct jpeg_input *input = (struct jpeg_input *)cinfo->src;
   if (coyote_canvas_tiles_cancelled(input->writer)) {
      input->result = COYOTE_TILE_CANCELLED;
      ERREXIT(cinfo, JERR_FILE_READ);
   }
   while (input->offset < input->length) {
      off_t remaining = input->length - input->offset;
      size_t wanted = remaining > (off_t)sizeof input->buffer
         ? sizeof input->buffer : (size_t)remaining;
      ssize_t n = pread(input->fd, input->buffer, wanted, input->offset);
      if (n < 0 && errno == EINTR) continue;
      if (n < 0) {
         input->result = COYOTE_TILE_IO;
         ERREXIT(cinfo, JERR_FILE_READ);
      }
      if (n == 0) {
         input->result = COYOTE_TILE_INVALID;
         ERREXIT(cinfo, JERR_INPUT_EOF);
      }
      input->offset += n;
      input->base.next_input_byte = input->buffer;
      input->base.bytes_in_buffer = (size_t)n;
      return TRUE;
   }
   input->result = COYOTE_TILE_INVALID;
   ERREXIT(cinfo, JERR_INPUT_EOF);
   return FALSE;
}

static void jpeg_skip_input_data(j_decompress_ptr cinfo, long count)
{
   struct jpeg_input *input = (struct jpeg_input *)cinfo->src;
   if (count <= 0) return;
   size_t remaining = input->base.bytes_in_buffer;
   if ((uintmax_t)count <= remaining) {
      input->base.next_input_byte += count;
      input->base.bytes_in_buffer -= (size_t)count;
      return;
   }
   uintmax_t skip = (uintmax_t)count - remaining;
   off_t unread_offset = input->offset;
   off_t unread_length = input->length - unread_offset;
   if (unread_offset < 0 || unread_length < 0 || skip > (uintmax_t)unread_length) {
      input->result = COYOTE_TILE_INVALID;
      ERREXIT(cinfo, JERR_INPUT_EOF);
   }
   input->offset += (off_t)skip;
   input->base.next_input_byte += remaining;
   input->base.bytes_in_buffer = 0;
}

static void jpeg_term_source(j_decompress_ptr cinfo)
{
   (void)cinfo;
}

static void jpeg_set_source(struct jpeg_state *state, int fd, off_t length,
                            struct coyote_canvas_tile_writer *writer)
{
   state->input.fd = fd;
   state->input.offset = 0;
   state->input.length = length;
   state->input.writer = writer;
   state->input.result = COYOTE_TILE_INVALID;
   state->input.base.init_source = jpeg_init_source;
   state->input.base.fill_input_buffer = jpeg_fill_input_buffer;
   state->input.base.skip_input_data = jpeg_skip_input_data;
   state->input.base.resync_to_restart = jpeg_resync_to_restart;
   state->input.base.term_source = jpeg_term_source;
   state->input.base.bytes_in_buffer = 0;
   state->input.base.next_input_byte = NULL;
   state->cinfo.src = &state->input.base;
}

static int decode_jpeg(int fd, struct coyote_canvas_tile_writer *writer,
                       off_t length)
{
   struct jpeg_state *state = calloc(1, sizeof *state);
   if (!state) return COYOTE_TILE_MEMORY;
   state->result = COYOTE_TILE_INVALID;
   state->cinfo.err = jpeg_std_error(&state->error.base);
   state->error.base.error_exit = jpeg_fail;
   state->error.base.emit_message = jpeg_message;
   if (setjmp(state->error.jump)) {
      if (state->created) jpeg_destroy_decompress(&state->cinfo);
      free(state->sample_row);
      free(state->rgba_row);
      int result = state->input.result != COYOTE_TILE_INVALID
         ? state->input.result : state->result;
      free(state);
      return result == COYOTE_TILE_OK ? COYOTE_TILE_INVALID : result;
   }
   jpeg_create_decompress(&state->cinfo);
   state->created = 1;
   jpeg_set_source(state, fd, length, writer);
   if (jpeg_read_header(&state->cinfo, TRUE) != JPEG_HEADER_OK) {
      state->result = COYOTE_TILE_INVALID;
      longjmp(state->error.jump, 1);
   }
   if (state->cinfo.progressive_mode || state->cinfo.input_scan_number != 1 ||
       state->cinfo.comps_in_scan != state->cinfo.num_components ||
       jpeg_has_multiple_scans(&state->cinfo)) {
      state->result = COYOTE_TILE_UNSUPPORTED;
      longjmp(state->error.jump, 1);
   }
   if (state->cinfo.num_components == 1 &&
       state->cinfo.jpeg_color_space == JCS_GRAYSCALE) {
      state->cinfo.out_color_space = JCS_GRAYSCALE;
   } else if (state->cinfo.num_components == 3 &&
              (state->cinfo.jpeg_color_space == JCS_RGB ||
               state->cinfo.jpeg_color_space == JCS_YCbCr)) {
      state->cinfo.out_color_space = JCS_RGB;
   } else {
      state->result = COYOTE_TILE_UNSUPPORTED;
      longjmp(state->error.jump, 1);
   }
   jpeg_calc_output_dimensions(&state->cinfo);
   if (!state->cinfo.output_width || !state->cinfo.output_height ||
       state->cinfo.output_width > COYOTE_CANVAS_TILE_MAX_SIDE ||
       state->cinfo.output_height > COYOTE_CANVAS_TILE_MAX_SIDE) {
      state->result = COYOTE_TILE_LIMIT;
      longjmp(state->error.jump, 1);
   }
   state->result = coyote_canvas_tiles_begin(
      writer, state->cinfo.output_width, state->cinfo.output_height);
   if (state->result != COYOTE_TILE_OK) longjmp(state->error.jump, 1);
   size_t channels = state->cinfo.out_color_space == JCS_GRAYSCALE ? 1U : 3U;
   state->sample_row = malloc((size_t)state->cinfo.output_width * channels);
   state->rgba_row = malloc((size_t)state->cinfo.output_width * 4U);
   if (!state->sample_row || !state->rgba_row) {
      state->result = COYOTE_TILE_MEMORY;
      longjmp(state->error.jump, 1);
   }
   if (!jpeg_start_decompress(&state->cinfo)) {
      state->result = COYOTE_TILE_INVALID;
      longjmp(state->error.jump, 1);
   }
   while (state->cinfo.output_scanline < state->cinfo.output_height) {
      if (coyote_canvas_tiles_cancelled(writer)) {
         state->result = COYOTE_TILE_CANCELLED;
         longjmp(state->error.jump, 1);
      }
      JSAMPROW rows[1] = {state->sample_row};
      JDIMENSION y = state->cinfo.output_scanline;
      if (jpeg_read_scanlines(&state->cinfo, rows, 1) != 1) {
         state->result = state->input.result;
         longjmp(state->error.jump, 1);
      }
      for (JDIMENSION x = 0; x < state->cinfo.output_width; ++x) {
         unsigned char *rgba = state->rgba_row + (size_t)x * 4U;
         if (channels == 1) {
            rgba[0] = rgba[1] = rgba[2] = state->sample_row[x];
         } else {
            memcpy(rgba, state->sample_row + (size_t)x * 3U, 3);
         }
         rgba[3] = 255;
      }
      state->result = coyote_canvas_tiles_row(writer, y, state->rgba_row, 1);
      if (state->result != COYOTE_TILE_OK) longjmp(state->error.jump, 1);
   }
   if (!jpeg_finish_decompress(&state->cinfo)) {
      state->result = COYOTE_TILE_INVALID;
      longjmp(state->error.jump, 1);
   }
   jpeg_destroy_decompress(&state->cinfo);
   free(state->sample_row);
   free(state->rgba_row);
   free(state);
   return COYOTE_TILE_OK;
}

int coyote_canvas_tiles_decode(int source_fd,
                               struct coyote_canvas_tile_writer *writer)
{
   struct stat st;
   unsigned char signature[8];
   ssize_t n;
   if (source_fd < 0 || writer == NULL) return COYOTE_TILE_INVALID;
   if (coyote_canvas_tiles_cancelled(writer)) return COYOTE_TILE_CANCELLED;
   if (fstat(source_fd, &st) < 0) return COYOTE_TILE_IO;
   if (!S_ISREG(st.st_mode) || st.st_size <= 0) return COYOTE_TILE_INVALID;
   do { n = pread(source_fd, signature, sizeof signature, 0); }
   while (n < 0 && errno == EINTR);
   if (n < 0) return COYOTE_TILE_IO;
   if (n >= 8 && png_sig_cmp(signature, 0, 8) == 0)
      return decode_png(source_fd, writer, st.st_size);
   if (n >= 2 && signature[0] == 0xff && signature[1] == 0xd8)
      return decode_jpeg(source_fd, writer, st.st_size);
   return COYOTE_TILE_UNSUPPORTED;
}
