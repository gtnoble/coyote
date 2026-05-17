/*  coyote_cmark_c.c — C shim for libcmark-gfm enum constants and helpers.
 *
 *  All enum-getter functions are trivial one-liners that return a single
 *  cmark enum value.  The Ada package Coyote_Cmark imports these at
 *  elaboration time to initialise package-body constants, ensuring the
 *  values always agree with the installed <cmark-gfm.h> regardless of the
 *  library version.
 *
 *  cmark_shim_get_literal wraps cmark_node_get_literal so the Ada side
 *  receives a valid (possibly empty) C string rather than a null pointer.
 *
 *  cmark_shim_parse_document_gfm creates a parser with the GFM "table",
 *  "strikethrough", and "autolink" extensions attached, parses the supplied
 *  buffer, and returns the document root node.  The caller must free the
 *  returned node with cmark_node_free.
 *
 *  Project: coyote
 *  For revision history, see the project version-control log.
 */

#include <cmark-gfm.h>
#include <cmark-gfm-core-extensions.h>
#include <cmark-gfm-extension_api.h>
#include <stddef.h>
#include <string.h>

/* ── Node types ──────────────────────────────────────────────────────────── */

int cmark_shim_node_none(void)          { return (int)CMARK_NODE_NONE;          }
int cmark_shim_node_document(void)      { return (int)CMARK_NODE_DOCUMENT;      }
int cmark_shim_node_block_quote(void)   { return (int)CMARK_NODE_BLOCK_QUOTE;   }
int cmark_shim_node_list(void)          { return (int)CMARK_NODE_LIST;          }
int cmark_shim_node_item(void)          { return (int)CMARK_NODE_ITEM;          }
int cmark_shim_node_code_block(void)    { return (int)CMARK_NODE_CODE_BLOCK;    }
int cmark_shim_node_html_block(void)    { return (int)CMARK_NODE_HTML_BLOCK;    }
int cmark_shim_node_paragraph(void)     { return (int)CMARK_NODE_PARAGRAPH;     }
int cmark_shim_node_heading(void)       { return (int)CMARK_NODE_HEADING;       }
int cmark_shim_node_thematic_break(void){ return (int)CMARK_NODE_THEMATIC_BREAK;}
int cmark_shim_node_text(void)          { return (int)CMARK_NODE_TEXT;          }
int cmark_shim_node_softbreak(void)     { return (int)CMARK_NODE_SOFTBREAK;     }
int cmark_shim_node_linebreak(void)     { return (int)CMARK_NODE_LINEBREAK;     }
int cmark_shim_node_code(void)          { return (int)CMARK_NODE_CODE;          }
int cmark_shim_node_html_inline(void)   { return (int)CMARK_NODE_HTML_INLINE;   }
int cmark_shim_node_emph(void)          { return (int)CMARK_NODE_EMPH;          }
int cmark_shim_node_strong(void)        { return (int)CMARK_NODE_STRONG;        }
int cmark_shim_node_link(void)          { return (int)CMARK_NODE_LINK;          }
int cmark_shim_node_image(void)         { return (int)CMARK_NODE_IMAGE;         }

/* ── List types ──────────────────────────────────────────────────────────── */

int cmark_shim_list_no_list(void)       { return (int)CMARK_NO_LIST;            }
int cmark_shim_list_bullet(void)        { return (int)CMARK_BULLET_LIST;        }
int cmark_shim_list_ordered(void)       { return (int)CMARK_ORDERED_LIST;       }

/* ── Event types ─────────────────────────────────────────────────────────── */

int cmark_shim_event_none(void)         { return (int)CMARK_EVENT_NONE;         }
int cmark_shim_event_done(void)         { return (int)CMARK_EVENT_DONE;         }
int cmark_shim_event_enter(void)        { return (int)CMARK_EVENT_ENTER;        }
int cmark_shim_event_exit(void)         { return (int)CMARK_EVENT_EXIT;         }

/* ── Default parse options ───────────────────────────────────────────────── */

int cmark_shim_opt_default(void)        { return (int)CMARK_OPT_DEFAULT;        }

/* ── Safe literal accessor ───────────────────────────────────────────────── */

/*  cmark_node_get_literal returns NULL for nodes that carry no text.
 *  This wrapper converts NULL to an empty string so the Ada side can
 *  always treat the return value as a valid C string without handling
 *  a null chars_ptr.                                                  */
const char *cmark_shim_get_literal(cmark_node *node)
{
    const char *s = cmark_node_get_literal(node);
    return (s != NULL) ? s : "";
}

/* ── GFM parse with table extension ─────────────────────────────────────── */

/*  Parse buffer with the GFM "table", "strikethrough", and "autolink"
 *  extensions enabled.  Returns the document root; caller must free with
 *  cmark_node_free.                                                     */
cmark_node *cmark_shim_parse_document_gfm(const char *buffer,
                                           size_t      len,
                                           int         options)
{
    static const char *const ext_names[] = {
        "table", "strikethrough", "autolink", NULL
    };
    const char *const *name;
    cmark_syntax_extension *ext;
    cmark_parser *parser;
    cmark_node   *doc;

    cmark_gfm_core_extensions_ensure_registered();

    parser = cmark_parser_new(options);
    for (name = ext_names; *name != NULL; ++name) {
        ext = cmark_find_syntax_extension(*name);
        if (ext != NULL)
            cmark_parser_attach_syntax_extension(parser, ext);
    }

    cmark_parser_feed(parser, buffer, len);
    doc = cmark_parser_finish(parser);
    cmark_parser_free(parser);
    return doc;
}

/* ── Node type string ────────────────────────────────────────────────────── */

/*  Returns the type-name string for a node (e.g. "table", "table_row",
 *  "table_cell", "paragraph", …).  Extension nodes carry dynamic integer
 *  type ids; the string is the only portable way to identify them.
 *  Never returns NULL.                                                   */
const char *cmark_shim_node_get_type_string(cmark_node *node)
{
    const char *s = cmark_node_get_type_string(node);
    return (s != NULL) ? s : "";
}

/* ── Table row header predicate ──────────────────────────────────────────── */

/*  Returns non-zero if node is a table_row that is the header row.     */
int cmark_shim_table_row_is_header(cmark_node *node)
{
    return cmark_gfm_extensions_get_table_row_is_header(node);
}
