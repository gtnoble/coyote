/*  coyote_lasem_c.c — small C shim for Lasem iTeX rendering.
 *
 *  The shim keeps Lasem's GObject and GError APIs out of the Ada binding.
 *  Each operation owns and releases its document and view before returning.
 *
 *  Project: coyote
 */

#include <lsm.h>
#include <lsmdomdocument.h>
#include <lsmdomview.h>
#include <lsmmathmldocument.h>
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

char *coyote_lasem_measure_itex
  (const char       *itex,
   gssize            itex_len,
   unsigned int     *width,
   unsigned int     *height,
   unsigned int     *baseline)
{
    GError            *error = NULL;
    LsmMathmlDocument *document;
    LsmDomView        *view;

    if (itex == NULL || width == NULL || height == NULL || baseline == NULL)
        return strdup ("NULL argument");

    document = lsm_mathml_document_new_from_itex (itex, itex_len, &error);
    if (document == NULL)
        return error_message (error, "Lasem could not parse iTeX");

    view = lsm_dom_document_create_view (LSM_DOM_DOCUMENT (document));
    if (view == NULL) {
        g_object_unref (document);
        return strdup ("Lasem could not create a document view");
    }

    lsm_dom_view_get_size_pixels (view, width, height, baseline);

    g_object_unref (view);
    g_object_unref (document);
    return NULL;
}

char *coyote_lasem_render_itex
  (const char       *itex,
   gssize            itex_len,
   cairo_t          *cairo,
   double            x,
   double            y)
{
    GError            *error = NULL;
    LsmMathmlDocument *document;
    LsmDomView        *view;

    if (itex == NULL || cairo == NULL)
        return strdup ("NULL argument");

    document = lsm_mathml_document_new_from_itex (itex, itex_len, &error);
    if (document == NULL)
        return error_message (error, "Lasem could not parse iTeX");

    view = lsm_dom_document_create_view (LSM_DOM_DOCUMENT (document));
    if (view == NULL) {
        g_object_unref (document);
        return strdup ("Lasem could not create a document view");
    }

    lsm_dom_view_render (view, cairo, x, y);

    g_object_unref (view);
    g_object_unref (document);
    return NULL;
}

void coyote_lasem_free_error (char *message)
{
    free (message);
}
