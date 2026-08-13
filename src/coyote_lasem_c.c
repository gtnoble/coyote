/*  coyote_lasem_c.c — small C shim for Lasem MathML rendering.
 *
 *  The shim keeps Lasem's GObject and GError APIs out of the Ada binding.
 *  Each operation owns and releases its document and view before returning.
 *
 *  Project: coyote
 */

#include <lsm.h>
#include <lsmdomdocument.h>
#include <lsmdomparser.h>
#include <lsmdomview.h>
#include <cairo.h>
#include <glib.h>
#include <stdlib.h>
#include <string.h>

static char *error_message (GError *error, const char *fallback)
{
    char *message;

    if (error != NULL && error->message != NULL)
        message = strdup (error->message);
    else
        message = strdup (fallback);

    if (error != NULL)
        g_error_free (error);

    return message;
}

char *coyote_lasem_measure_mathml
  (const char       *mathml,
   gssize            mathml_len,
   unsigned int     *width,
   unsigned int     *height,
   unsigned int     *baseline,
   double            scale)
{
    GError         *error = NULL;
    LsmDomDocument *document;
    LsmDomView     *view;

    if (mathml == NULL || width == NULL || height == NULL || baseline == NULL)
        return strdup ("NULL argument");

    document = lsm_dom_document_new_from_memory
      (mathml, mathml_len, &error);
    if (document == NULL)
        return error_message (error, "Lasem could not parse MathML");

    view = lsm_dom_document_create_view (document);
    if (view == NULL) {
        g_object_unref (document);
        return strdup ("Lasem could not create a document view");
    }

    lsm_dom_view_set_resolution (view, 72.0 * (scale > 0.0 ? scale : 1.0));
    lsm_dom_view_get_size_pixels (view, width, height, baseline);

    g_object_unref (view);
    g_object_unref (document);
    return NULL;
}

char *coyote_lasem_render_mathml
  (const char       *mathml,
   gssize            mathml_len,
   cairo_t          *cairo,
   double            x,
   double            y,
   double            scale)
{
    GError         *error = NULL;
    LsmDomDocument *document;
    LsmDomView     *view;

    if (mathml == NULL || cairo == NULL)
        return strdup ("NULL argument");

    document = lsm_dom_document_new_from_memory
      (mathml, mathml_len, &error);
    if (document == NULL)
        return error_message (error, "Lasem could not parse MathML");

    view = lsm_dom_document_create_view (document);
    if (view == NULL) {
        g_object_unref (document);
        return strdup ("Lasem could not create a document view");
    }

    lsm_dom_view_set_resolution (view, 72.0 * (scale > 0.0 ? scale : 1.0));
    lsm_dom_view_render (view, cairo, x, y);

    g_object_unref (view);
    g_object_unref (document);
    return NULL;
}

void coyote_lasem_free_error (char *message)
{
    free (message);
}
