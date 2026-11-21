/* bounded, conservative SVG decoding for Coyote canvas imports */
#include <limits.h>
#include <math.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include <libxml/parser.h>
#include <libxml/tree.h>
#include <librsvg/rsvg.h>
#include <cairo.h>
#include <gdk-pixbuf/gdk-pixbuf.h>
#include <glib.h>

#define SVG_MAX_NODES 50000U
#define SVG_MAX_DEPTH 64U

static const char *const elements[] = {
   "svg", "g", "defs", "symbol", "use", "path", "rect", "circle",
   "ellipse", "line", "polyline", "polygon", "text", "tspan",
   "textPath", "title", "desc", "linearGradient", "radialGradient",
   "stop", "clipPath", "mask", "pattern", "marker"
};

static const char *const attributes[] = {
   "id", "class", "x", "y", "x1", "y1", "x2", "y2", "cx", "cy",
   "r", "rx", "ry", "width", "height", "viewBox", "preserveAspectRatio",
   "d", "points", "transform", "fill", "fill-opacity", "fill-rule",
   "stroke", "stroke-width", "stroke-opacity", "stroke-linecap",
   "stroke-linejoin", "stroke-miterlimit", "stroke-dasharray",
   "stroke-dashoffset", "opacity", "display", "visibility", "color",
   "color-interpolation", "clip-path", "clip-rule", "mask",
   "stop-color", "stop-opacity", "offset", "gradientUnits",
   "gradientTransform", "spreadMethod", "fx", "fy", "fr", "patternUnits",
   "patternContentUnits", "patternTransform", "marker", "marker-start",
   "marker-mid", "marker-end", "markerWidth", "markerHeight", "refX", "refY",
   "orient", "font-family", "font-size", "font-style", "font-weight",
   "font-variant", "text-anchor", "dominant-baseline", "alignment-baseline",
   "letter-spacing", "word-spacing", "text-decoration", "direction",
   "unicode-bidi", "startOffset", "method", "spacing", "clipPathUnits",
   "maskUnits", "maskContentUnits", "href", "version"
};

static int listed(const char *value, const char *const *list, size_t count)
{
   size_t i;
   for (i = 0; i < count; ++i)
      if (strcmp(value, list[i]) == 0) return 1;
   return 0;
}

/* Allow CSS paint/reference values, but never CSS escapes or comments.
 * A functional paint reference must be a quoted or bare local ASCII ID.
 * The rest of the allowlist has no resource-bearing presentation values. */
static int id_char(char c)
{
   return g_ascii_isalnum(c) || c == '_' || c == '-' || c == '.' || c == ':';
}

static int local_fragment(const char *value)
{
   const char *p = value;
   if (*p++ != '#' || !id_char(*p)) return 0;
   while (id_char(*p)) ++p;
   return *p == '\0';
}

static int valid_paint_value(const char *value)
{
   const char *p = value;
   char quote = '\0';
   if (strpbrk(value, "\\/*;{}@") != NULL) return 0;
   while (g_ascii_isspace(*p)) ++p;
   if (g_ascii_strncasecmp(p, "url(", 4U) != 0) {
      for (; *p != '\0'; ++p)
         if (g_ascii_strncasecmp(p, "url", 3U) == 0) return 0;
      return 1;
   }
   p += 4;
   while (g_ascii_isspace(*p)) ++p;
   if (*p == '\'' || *p == '"') quote = *p++;
   if (*p++ != '#' || !id_char(*p)) return 0;
   while (id_char(*p)) ++p;
   if (quote != '\0' && *p++ != quote) return 0;
   while (g_ascii_isspace(*p)) ++p;
   if (*p++ != ')') return 0;
   while (g_ascii_isspace(*p)) ++p;
   return *p == '\0';
}

static int valid_node(xmlNode *node, unsigned int depth,
                      unsigned int *nodes)
{
   xmlNode *child;
   xmlAttr *attr;
   if (depth > SVG_MAX_DEPTH || ++*nodes > SVG_MAX_NODES) return 0;
   if (node->type == XML_TEXT_NODE || node->type == XML_CDATA_SECTION_NODE ||
       node->type == XML_COMMENT_NODE)
      return 1;
   if (node->type != XML_ELEMENT_NODE || node->ns == NULL ||
       node->ns->href == NULL ||
       strcmp((const char *)node->ns->href,
              "http://www.w3.org/2000/svg") != 0 ||
       !listed((const char *)node->name, elements,
               sizeof elements / sizeof elements[0])) return 0;
   for (attr = node->properties; attr != NULL; attr = attr->next) {
      static const char *const paint_attrs[] = {
         "fill", "stroke", "clip-path", "mask", "marker",
         "marker-start", "marker-mid", "marker-end"
      };
      const char *name = (const char *)attr->name;
      xmlChar *content;
      int good = 1;
      if (attr->ns != NULL) {
         if (attr->ns->href == NULL) return 0;
         if (xmlStrEqual(attr->ns->href, BAD_CAST "http://www.w3.org/XML/1998/namespace") &&
             strcmp(name, "space") == 0) continue;
         if (!xmlStrEqual(attr->ns->href, BAD_CAST "http://www.w3.org/1999/xlink") ||
             strcmp(name, "href") != 0) return 0;
      } else if (!listed(name, attributes,
                         sizeof attributes / sizeof attributes[0])) return 0;
      content = xmlNodeListGetString(node->doc, attr->children, 1);
      if (strcmp(name, "href") == 0)
         good = content != NULL && local_fragment((const char *)content);
      else if (content != NULL && listed(name, paint_attrs,
                sizeof paint_attrs / sizeof paint_attrs[0]))
         good = valid_paint_value((const char *)content);
      if (content != NULL) xmlFree(content);
      if (!good) return 0;
   }
   for (child = node->children; child != NULL; child = child->next)
      if (!valid_node(child, depth + 1U, nodes)) return 0;
   return 1;
}

static int valid_document(xmlDoc *doc)
{
   xmlNode *root, *node;
   unsigned int nodes = 0U;
   if (doc == NULL || doc->intSubset != NULL || doc->extSubset != NULL)
      return 0;
   for (node = doc->children; node != NULL; node = node->next)
      if (node->type == XML_PI_NODE || node->type == XML_DTD_NODE) return 0;
   root = xmlDocGetRootElement(doc);
   return root != NULL && strcmp((const char *)root->name, "svg") == 0 &&
          valid_node(root, 1U, &nodes);
}

static void copy_surface_to_pixbuf(cairo_surface_t *surface, GdkPixbuf *pixbuf,
                                   int width, int height)
{
   const unsigned char *source;
   unsigned char *destination;
   int source_stride, destination_stride, y, x;
   cairo_surface_flush(surface);
   source = cairo_image_surface_get_data(surface);
   source_stride = cairo_image_surface_get_stride(surface);
   destination = gdk_pixbuf_get_pixels(pixbuf);
   destination_stride = gdk_pixbuf_get_rowstride(pixbuf);
   for (y = 0; y < height; ++y) {
      const uint32_t *src = (const uint32_t *)(source + y * source_stride);
      unsigned char *dst = destination + y * destination_stride;
      for (x = 0; x < width; ++x) {
         uint32_t pixel = src[x];
         unsigned int a = pixel >> 24;
         unsigned int r = (pixel >> 16) & 255U;
         unsigned int g = (pixel >> 8) & 255U;
         unsigned int b = pixel & 255U;
         if (a != 0U && a != 255U) {
            r = (r * 255U + a / 2U) / a;
            g = (g * 255U + a / 2U) / a;
            b = (b * 255U + a / 2U) / a;
         }
         dst[4 * x] = (unsigned char)(r > 255U ? 255U : r);
         dst[4 * x + 1] = (unsigned char)(g > 255U ? 255U : g);
         dst[4 * x + 2] = (unsigned char)(b > 255U ? 255U : b);
         dst[4 * x + 3] = (unsigned char)a;
      }
   }
}

GdkPixbuf *coyote_canvas_svg_decode(const char *data, size_t length,
                                   size_t max_bytes, int max_side,
                                   size_t max_pixels, const char **error_out)
{
   xmlParserCtxt *context = NULL;
   xmlDoc *doc = NULL;
   xmlChar *validated_xml = NULL;
   int validated_size = 0;
   RsvgHandle *handle = NULL;
   GdkPixbuf *pixbuf = NULL;
   cairo_surface_t *surface = NULL;
   cairo_t *cr = NULL;
   GError *gerror = NULL;
   double width = 0.0, height = 0.0;
   const char *message = "Invalid or unsafe SVG";
   if (error_out != NULL) *error_out = NULL;
   if (data == NULL || length == 0U || length > max_bytes ||
       length > (size_t)INT_MAX || max_side <= 0) {
      message = "SVG input exceeds supported limits";
      goto done;
   }
   if ((length >= 2U && (unsigned char)data[0] == 0x1fU &&
        (unsigned char)data[1] == 0x8bU) ||
       (length >= 4U && memcmp(data, "PK\003\004", 4U) == 0)) {
      message = "Compressed SVG is not accepted";
      goto done;
   }
   if (memchr(data, '\0', length) != NULL ||
       !g_utf8_validate(data, (gssize)length, NULL)) {
      message = "SVG must be valid UTF-8 XML";
      goto done;
   }
   /* Do not even parse a DTD. The parser also disables external loading
    * and the tree validator rejects subsets and processing instructions. */
   if (g_strstr_len(data, (gssize)length, "<!DOCTYPE") != NULL) {
      message = "SVG document types are not accepted";
      goto done;
   }
   context = xmlNewParserCtxt();
   if (context == NULL) goto done;
   doc = xmlCtxtReadMemory(context, data, (int)length, NULL, "UTF-8",
                           XML_PARSE_NONET | XML_PARSE_COMPACT |
                           XML_PARSE_NOERROR | XML_PARSE_NOWARNING);
   if (!valid_document(doc)) {
      message = "SVG contains unsupported or unsafe XML";
      goto done;
   }
   /* Feed the validated tree, not the original XML byte stream, to the
    * renderer. This fixes UTF-8 and prevents parser interpretation drift. */
   xmlDocDumpMemoryEnc(doc, &validated_xml, &validated_size, "UTF-8");
   if (validated_xml == NULL || validated_size <= 0 ||
       (size_t)validated_size > max_bytes) {
      message = "Validated SVG exceeds the size limit";
      goto done;
   }
   handle = rsvg_handle_new_from_data(validated_xml, (size_t)validated_size,
                                      &gerror);
   if (handle == NULL) {
      message = "librsvg rejected the SVG document";
      goto done;
   }
   rsvg_handle_set_dpi(handle, 96.0);
   if (!rsvg_handle_get_intrinsic_size_in_pixels(handle, &width, &height)) {
      RsvgRectangle box = {0.0, 0.0, 0.0, 0.0};
      gboolean has_box = FALSE;
      rsvg_handle_get_intrinsic_dimensions(handle, NULL, NULL, NULL, NULL,
                                            &has_box, &box);
      if (!has_box || !isfinite(box.x) || !isfinite(box.y) ||
          !isfinite(box.width) || !isfinite(box.height) ||
          box.width <= 0.0 || box.height <= 0.0) {
         message = "SVG requires pixel dimensions or a positive viewBox";
         goto done;
      }
      width = box.width;
      height = box.height;
   }
   if (!isfinite(width) || !isfinite(height) || width <= 0.0 || height <= 0.0 ||
       ceil(width) > (double)max_side || ceil(height) > (double)max_side ||
       ceil(width) * ceil(height) > (double)max_pixels) {
      message = "SVG pixel dimensions exceed the allowed limit";
      goto done;
   }
   width = ceil(width);
   height = ceil(height);
   surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, (int)width,
                                        (int)height);
   if (cairo_surface_status(surface) != CAIRO_STATUS_SUCCESS) {
      message = "Unable to allocate SVG render surface";
      goto done;
   }
   cr = cairo_create(surface);
   if (cairo_status(cr) != CAIRO_STATUS_SUCCESS) {
      message = "Unable to create SVG render context";
      goto done;
   }
   cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE);
   cairo_set_source_rgba(cr, 0.0, 0.0, 0.0, 0.0);
   cairo_paint(cr);
   cairo_set_operator(cr, CAIRO_OPERATOR_OVER);
   pixbuf = gdk_pixbuf_new(GDK_COLORSPACE_RGB, TRUE, 8, (int)width, (int)height);
   if (pixbuf == NULL) {
      message = "Unable to allocate SVG pixel buffer";
      goto done;
   }
   if (!rsvg_handle_render_document(handle, cr,
          &(RsvgRectangle){0.0, 0.0, width, height}, &gerror) ||
       cairo_status(cr) != CAIRO_STATUS_SUCCESS) {
      message = "Unable to render SVG document";
      g_object_unref(pixbuf);
      pixbuf = NULL;
      goto done;
   }
   copy_surface_to_pixbuf(surface, pixbuf, (int)width, (int)height);
done:
   if (cr != NULL) cairo_destroy(cr);
   if (surface != NULL) cairo_surface_destroy(surface);
   if (handle != NULL) g_object_unref(handle);
   if (validated_xml != NULL) xmlFree(validated_xml);
   if (doc != NULL) xmlFreeDoc(doc);
   if (context != NULL) xmlFreeParserCtxt(context);
   if (gerror != NULL) g_error_free(gerror);
   if (pixbuf == NULL && error_out != NULL) *error_out = message;
   return pixbuf;
}
