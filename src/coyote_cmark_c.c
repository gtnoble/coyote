/*  coyote_cmark_c.c — C shim for libcmark enum constants and helpers.
 *
 *  All enum-getter functions are trivial one-liners that return a single
 *  cmark enum value.  The Ada package Coyote_Cmark imports these at
 *  elaboration time to initialise package-body constants, ensuring the
 *  values always agree with the installed <cmark.h> regardless of the
 *  library version.
 *
 *  cmark_shim_get_literal wraps cmark_node_get_literal so the Ada side
 *  receives a valid (possibly empty) C string rather than a null pointer.
 *
 *  Project: coyote
 *  For revision history, see the project version-control log.
 */

#include <cmark.h>
#include <stddef.h>

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
