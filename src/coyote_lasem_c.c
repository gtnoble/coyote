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

/*
 * Lasem's iTeX lexer accepts the relation commands \\lt and \\gt but does
 * not accept the literal relation characters that are valid in LaTeX and
 * MathJax.  Normalize a temporary copy for Lasem; callers retain the
 * original source for display and selection.
 */
static char *normalize_relations
  (const char *itex,
   gssize      itex_len,
   gssize     *normalized_len)
{
    size_t source_len;
    size_t output_len;
    size_t i;
    size_t output_index = 0;
    size_t relation_count = 0;
    unsigned int text_brace_depth = 0;
    int in_math = 0;
    int in_text = 0;
    char *normalized;

    if (itex == NULL || normalized_len == NULL)
        return NULL;

    source_len = itex_len < 0 ? strlen (itex) : (size_t) itex_len;

    /* Count only relations that Lasem will lex as math tokens. */
    for (i = 0; i < source_len; ++i) {
        if (in_text != 0) {
            if (itex[i] == '{')
                ++text_brace_depth;
            else if (itex[i] == '}' && text_brace_depth > 0
                     && --text_brace_depth == 0)
                in_text = 0;
        } else if (in_math != 0 && itex[i] == '\\'
                   && i + 5 < source_len
                   && strncmp (itex + i, "\\text{", 6) == 0) {
            in_text = 1;
            text_brace_depth = 1;
            i += 5;
        } else if (itex[i] == '\\' && i + 1 < source_len
          && (itex[i + 1] == '[' || itex[i + 1] == '(')) {
            in_math = 1;
            ++i;
        } else if (itex[i] == '\\' && i + 1 < source_len
          && (itex[i + 1] == ']' || itex[i + 1] == ')')) {
            in_math = 0;
            ++i;
        } else if (itex[i] == '$' && in_math == 0) {
            in_math = 1;
            if (i + 1 < source_len && itex[i + 1] == '$')
                ++i;
        } else if (itex[i] == '$' && in_math != 0) {
            in_math = 0;
            if (i + 1 < source_len && itex[i + 1] == '$')
                ++i;
        } else if (in_math != 0 && (itex[i] == '<' || itex[i] == '>')) {
            ++relation_count;
        }
    }

    output_len = source_len + relation_count * 2;
    normalized = malloc (output_len + 1);
    if (normalized == NULL)
        return NULL;

    in_math = 0;
    in_text = 0;
    text_brace_depth = 0;
    for (i = 0; i < source_len; ++i) {
        if (in_text != 0) {
            normalized[output_index++] = itex[i];
            if (itex[i] == '{')
                ++text_brace_depth;
            else if (itex[i] == '}' && text_brace_depth > 0
                     && --text_brace_depth == 0)
                in_text = 0;
        } else if (in_math != 0 && itex[i] == '\\'
          && i + 5 < source_len
          && strncmp (itex + i, "\\text{", 6) == 0) {
            in_text = 1;
            text_brace_depth = 1;
            memcpy (normalized + output_index, itex + i, 6);
            output_index += 6;
            i += 5;
        } else if (itex[i] == '\\' && i + 1 < source_len
          && (itex[i + 1] == '[' || itex[i + 1] == '(')) {
            in_math = 1;
            normalized[output_index++] = itex[i];
            normalized[output_index++] = itex[++i];
        } else if (itex[i] == '\\' && i + 1 < source_len
          && (itex[i + 1] == ']' || itex[i + 1] == ')')) {
            in_math = 0;
            normalized[output_index++] = itex[i];
            normalized[output_index++] = itex[++i];
        } else if (itex[i] == '$' && in_math == 0) {
            in_math = 1;
            normalized[output_index++] = itex[i];
            if (i + 1 < source_len && itex[i + 1] == '$')
                normalized[output_index++] = itex[++i];
        } else if (itex[i] == '$' && in_math != 0) {
            in_math = 0;
            normalized[output_index++] = itex[i];
            if (i + 1 < source_len && itex[i + 1] == '$')
                normalized[output_index++] = itex[++i];
        } else if (in_math != 0 && itex[i] == '<') {
            normalized[output_index++] = '\\';
            normalized[output_index++] = 'l';
            normalized[output_index++] = 't';
        } else if (in_math != 0 && itex[i] == '>') {
            normalized[output_index++] = '\\';
            normalized[output_index++] = 'g';
            normalized[output_index++] = 't';
        } else {
            normalized[output_index++] = itex[i];
        }
    }

    normalized[output_index] = '\0';
    *normalized_len = (gssize) output_index;
    return normalized;
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
    char              *normalized;
    gssize             normalized_len;

    if (itex == NULL || width == NULL || height == NULL || baseline == NULL)
        return strdup ("NULL argument");

    normalized = normalize_relations (itex, itex_len, &normalized_len);
    if (normalized == NULL)
        return strdup ("Could not allocate normalized iTeX");

    document = lsm_mathml_document_new_from_itex
      (normalized, normalized_len, &error);
    free (normalized);
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
    char              *normalized;
    gssize             normalized_len;

    if (itex == NULL || cairo == NULL)
        return strdup ("NULL argument");

    normalized = normalize_relations (itex, itex_len, &normalized_len);
    if (normalized == NULL)
        return strdup ("Could not allocate normalized iTeX");

    document = lsm_mathml_document_new_from_itex
      (normalized, normalized_len, &error);
    free (normalized);
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
