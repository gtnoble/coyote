#include <cairo.h>
#include <png.h>

#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

void coyote_canvas_compose_rgba(unsigned char *out,
                                const unsigned char *background,
                                int src_stride, int channels,
                                int left, int top, int width, int height,
                                cairo_surface_t *mask, int ink)
{
   const unsigned char *mask_data = NULL;
   int mask_stride = 0;
   int x, y;
   unsigned int ink_r = ((unsigned int)ink >> 16) & 255U;
   unsigned int ink_g = ((unsigned int)ink >> 8) & 255U;
   unsigned int ink_b = (unsigned int)ink & 255U;

   if (mask != NULL) {
      cairo_surface_flush(mask);
      mask_data = cairo_image_surface_get_data(mask);
      mask_stride = cairo_image_surface_get_stride(mask);
   }

   for (y = 0; y < height; ++y) {
      unsigned char *dst = out + (size_t)y * (size_t)width * 4U;
      const unsigned char *src = background == NULL ? NULL :
         background + (size_t)(top + y) * (size_t)src_stride +
         (size_t)left * (size_t)channels;
      const unsigned char *coverage = mask_data == NULL ? NULL :
         mask_data + (size_t)(top + y) * (size_t)mask_stride + (size_t)left;

      for (x = 0; x < width; ++x) {
         unsigned char *pixel = dst + (size_t)x * 4U;
         unsigned int m = coverage == NULL ? 0U : coverage[x];
         unsigned int dr, dg, db, da;

         if (src == NULL) {
            dr = dg = db = 255U;
            da = 255U;
         } else {
            dr = src[(size_t)x * (size_t)channels];
            dg = src[(size_t)x * (size_t)channels + 1U];
            db = src[(size_t)x * (size_t)channels + 2U];
            da = channels == 4 ? src[(size_t)x * 4U + 3U] : 255U;
         }

         /* Preserve straight color even when destination alpha is zero. */
         if (m == 0U) {
            pixel[0] = (unsigned char)dr;
            pixel[1] = (unsigned char)dg;
            pixel[2] = (unsigned char)db;
            pixel[3] = (unsigned char)da;
         } else {
            unsigned int inverse = 255U - m;
            unsigned int a = m * 255U + da * inverse;
            unsigned int ink_weight = m * 255U;
            unsigned int dst_weight = da * inverse;
            /* Use the unrounded combined alpha for straight RGB. */
            pixel[0] = (unsigned char)((ink_r * ink_weight +
                                        dr * dst_weight + a / 2U) / a);
            pixel[1] = (unsigned char)((ink_g * ink_weight +
                                        dg * dst_weight + a / 2U) / a);
            pixel[2] = (unsigned char)((ink_b * ink_weight +
                                        db * dst_weight + a / 2U) / a);
            pixel[3] = (unsigned char)((a + 127U) / 255U);
         }
      }
   }
}

cairo_surface_t *coyote_canvas_rgba_surface(const unsigned char *pixels,
                                            int width, int height)
{
   cairo_surface_t *surface;
   unsigned char *data;
   int stride, x, y;

   surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, width, height);
   if (cairo_surface_status(surface) != CAIRO_STATUS_SUCCESS) return surface;

   data = cairo_image_surface_get_data(surface);
   stride = cairo_image_surface_get_stride(surface);
   for (y = 0; y < height; ++y) {
      const unsigned char *src = pixels + (size_t)y * (size_t)width * 4U;
      uint32_t *dst = (uint32_t *)(void *)(data + (size_t)y * (size_t)stride);
      for (x = 0; x < width; ++x) {
         unsigned int r = src[(size_t)x * 4U];
         unsigned int g = src[(size_t)x * 4U + 1U];
         unsigned int b = src[(size_t)x * 4U + 2U];
         unsigned int a = src[(size_t)x * 4U + 3U];
         unsigned int pr = (r * a + 127U) / 255U;
         unsigned int pg = (g * a + 127U) / 255U;
         unsigned int pb = (b * a + 127U) / 255U;
         dst[x] = ((uint32_t)a << 24) | ((uint32_t)pr << 16) |
                  ((uint32_t)pg << 8) | (uint32_t)pb;
      }
   }
   cairo_surface_mark_dirty(surface);
   return surface;
}

struct png_output {
   unsigned char *data;
   size_t size;
   size_t capacity;
   size_t limit;
   int result;
};

static void png_silent_error(png_structp png, png_const_charp message)
{
   (void)message;
   png_longjmp(png, 1);
}

static void png_silent_warning(png_structp png, png_const_charp message)
{
   (void)png;
   (void)message;
}

static void png_append(png_structp png, png_bytep bytes, png_size_t count)
{
   struct png_output *output = (struct png_output *)png_get_io_ptr(png);
   size_t amount = (size_t)count;
   size_t needed, capacity;
   unsigned char *grown;

   if (amount == 0U) return;
   if (amount > output->limit - output->size) {
      output->result = 1;
      png_error(png, "PNG output limit exceeded");
   }
   needed = output->size + amount;
   if (needed > output->capacity) {
      capacity = output->capacity == 0U ?
         (output->limit < 4096U ? output->limit : 4096U) : output->capacity;
      while (capacity < needed) {
         if (capacity > output->limit / 2U) {
            capacity = output->limit;
            break;
         }
         capacity *= 2U;
      }
      if (capacity < needed) {
         output->result = 1;
         png_error(png, "PNG output limit exceeded");
      }
      grown = (unsigned char *)realloc(output->data, capacity);
      if (grown == NULL) {
         output->result = 2;
         png_error(png, "PNG output allocation failed");
      }
      output->data = grown;
      output->capacity = capacity;
   }
   memcpy(output->data + output->size, bytes, amount);
   output->size = needed;
}

static int write_png(struct png_output *output, const unsigned char *pixels,
                     int width, int height)
{
   png_structp png = NULL;
   png_infop info = NULL;
   int y;

   png = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL,
                                 png_silent_error, png_silent_warning);
   if (png == NULL) return 2;
   info = png_create_info_struct(png);
   if (info == NULL) {
      png_destroy_write_struct(&png, NULL);
      return 2;
   }
   if (setjmp(png_jmpbuf(png)) != 0) {
      int result = output->result == 0 ? 2 : output->result;
      png_destroy_write_struct(&png, &info);
      return result;
   }

   png_set_write_fn(png, output, png_append, NULL);
   png_set_IHDR(png, info, (png_uint_32)width, (png_uint_32)height, 8,
                PNG_COLOR_TYPE_RGBA, PNG_INTERLACE_NONE,
                PNG_COMPRESSION_TYPE_DEFAULT, PNG_FILTER_TYPE_DEFAULT);
   png_write_info(png, info);
   for (y = 0; y < height; ++y)
      png_write_row(png, (png_const_bytep)(pixels + (size_t)y *
                                           (size_t)width * 4U));
   png_write_end(png, info);
   png_destroy_write_struct(&png, &info);
   return 0;
}

int coyote_canvas_encode_png(const unsigned char *pixels, int width, int height,
                             size_t limit, unsigned char **data, size_t *size)
{
   struct png_output output;
   int result;

   *data = NULL;
   *size = 0U;
   output.data = NULL;
   output.size = 0U;
   output.capacity = 0U;
   output.limit = limit;
   output.result = 0;

   result = write_png(&output, pixels, width, height);
   if (result != 0) {
      free(output.data);
      return result;
   }
   *data = output.data;
   *size = output.size;
   return 0;
}

/* Called only with native 8-bit RGB(A) Pixbuf rows and checked dimensions. */
void coyote_canvas_pack_rgba(const unsigned char *src, size_t stride,
                            int channels, size_t width, size_t height,
                            unsigned char *dst)
{
   for (size_t y = 0; y < height; ++y)
   {
      const unsigned char *row = src + y * stride;
      unsigned char *out = dst + y * width * 4;
      if (channels == 4)
         memcpy(out, row, width * 4);
      else
         for (size_t x = 0; x < width; ++x)
         {
            memcpy(out + x * 4, row + x * 3, 3);
            out[x * 4 + 3] = 255;
         }
   }
}
