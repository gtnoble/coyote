#include <cairo.h>
#include <png.h>

#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static void compose_pixel(unsigned char *pixel, const unsigned char *src,
                          int channels, const unsigned char *ink)
{
   unsigned int dr, dg, db, da;
   uint32_t packed;
   unsigned int ia, ir, ig, ib;

   if (src == NULL) {
      dr = dg = db = 255U;
      da = 255U;
   } else {
      dr = src[0];
      dg = src[1];
      db = src[2];
      da = channels == 4 ? src[3] : 255U;
   }
   if (ink == NULL) {
      ia = ir = ig = ib = 0U;
   } else {
      memcpy(&packed, ink, sizeof packed);
      ia = packed >> 24;
      ir = (packed >> 16) & 255U;
      ig = (packed >> 8) & 255U;
      ib = packed & 255U;
   }
   if (ia == 0U) {
      pixel[0] = (unsigned char)dr;
      pixel[1] = (unsigned char)dg;
      pixel[2] = (unsigned char)db;
      pixel[3] = (unsigned char)da;
   } else {
      unsigned int inverse = 255U - ia;
      unsigned int alpha = ia * 255U + da * inverse;
      /* Ink is already premultiplied; unassociate only the final RGB. */
      pixel[0] = (unsigned char)((ir * 65025U +
                                  dr * da * inverse + alpha / 2U) / alpha);
      pixel[1] = (unsigned char)((ig * 65025U +
                                  dg * da * inverse + alpha / 2U) / alpha);
      pixel[2] = (unsigned char)((ib * 65025U +
                                  db * da * inverse + alpha / 2U) / alpha);
      pixel[3] = (unsigned char)((alpha + 127U) / 255U);
   }
}

static void premultiplied_pixel(unsigned char *dst,
                                const unsigned char *rgba)
{
   unsigned int r = rgba[0], g = rgba[1], b = rgba[2], a = rgba[3];
   uint32_t packed = ((uint32_t)a << 24) |
      ((uint32_t)((r * a + 127U) / 255U) << 16) |
      ((uint32_t)((g * a + 127U) / 255U) << 8) |
      (uint32_t)((b * a + 127U) / 255U);
   memcpy(dst, &packed, sizeof packed);
}

void coyote_canvas_compose_rgba(unsigned char *out,
                                const unsigned char *background,
                                int src_stride, int channels,
                                int left, int top, int width, int height,
                                cairo_surface_t *ink_surface)
{
   const unsigned char *ink_data = NULL;
   int ink_stride = 0;
   int x, y;

   if (ink_surface != NULL) {
      cairo_surface_flush(ink_surface);
      ink_data = cairo_image_surface_get_data(ink_surface);
      ink_stride = cairo_image_surface_get_stride(ink_surface);
   }
   for (y = 0; y < height; ++y) {
      unsigned char *dst = out + (size_t)y * (size_t)width * 4U;
      const unsigned char *src = background == NULL ? NULL :
         background + (size_t)(top + y) * (size_t)src_stride +
         (size_t)left * (size_t)channels;
      const unsigned char *ink = ink_data == NULL ? NULL :
         ink_data + (size_t)(top + y) * (size_t)ink_stride +
         (size_t)left * 4U;
      for (x = 0; x < width; ++x)
         compose_pixel(dst + (size_t)x * 4U,
                       src == NULL ? NULL : src + (size_t)x *
                       (size_t)channels, channels,
                       ink == NULL ? NULL : ink + (size_t)x * 4U);
   }
}

void coyote_canvas_preview_region(unsigned char *display,
                                  const unsigned char *source,
                                  const unsigned char *ink_surface,
                                  int display_stride, int source_stride,
                                  int channels, int ink_stride,
                                  int source_left, int source_top,
                                  int display_left, int display_top,
                                  int width, int height)
{
   int x, y;

   for (y = 0; y < height; ++y) {
      unsigned char *dst = display + (size_t)(display_top + y) *
         (size_t)display_stride + (size_t)display_left * 4U;
      const unsigned char *src = source == NULL ? NULL : source +
         (size_t)(source_top + y) * (size_t)source_stride +
         (size_t)source_left * (size_t)channels;
      const unsigned char *ink = ink_surface +
         (size_t)(source_top + y) * (size_t)ink_stride +
         (size_t)source_left * 4U;
      for (x = 0; x < width; ++x) {
         unsigned char rgba[4];
         compose_pixel(rgba, src == NULL ? NULL : src + (size_t)x *
                       (size_t)channels, channels, ink + (size_t)x * 4U);
         premultiplied_pixel(dst + (size_t)x * 4U, rgba);
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
      unsigned char *dst = data + (size_t)y * (size_t)stride;
      for (x = 0; x < width; ++x)
         premultiplied_pixel(dst + (size_t)x * 4U, src + (size_t)x * 4U);
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
