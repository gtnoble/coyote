--  Coyote_Cmark — thin Ada binding to libcmark (CommonMark parser).
--
--  Exposes the subset of the libcmark C API used by the GUI Markdown
--  renderer.  All enum / macro constants are resolved at package
--  elaboration time by calling C shim functions (coyote_cmark_c.c),
--  so the values always agree with the installed <cmark.h> regardless
--  of library version.
--
--  Opaque C pointer types use System.Address.  The cmark_shim_get_literal
--  wrapper guarantees Node_Get_Literal never returns a null chars_ptr.
--
--  Thread safety: libcmark parse and iteration are not thread-safe.
--  All calls must originate from the same task (the GTK idle callback in the GUI path).
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Interfaces.C;
with Interfaces.C.Strings;
with System;

package Coyote_Cmark is
   pragma Elaborate_Body;

   --  ── Opaque C pointer types ─────────────────────────────────────────

   subtype Node_Ptr is System.Address;
   subtype Iter_Ptr is System.Address;

   --  ── Discriminant integer subtypes ──────────────────────────────────

   subtype Node_Type_Int  is Interfaces.C.int;
   subtype List_Type_Int  is Interfaces.C.int;
   subtype Event_Type_Int is Interfaces.C.int;

   --  ── Enum constants ─────────────────────────────────────────────────
   --
   --  All values are initialised in the package body by calling the
   --  cmark_shim_* C getters (see coyote_cmark_c.c).  Client code must
   --  compare against these names — never raw integer literals.

   --  Node types
   NODE_NONE           : Node_Type_Int;
   NODE_DOCUMENT       : Node_Type_Int;
   NODE_BLOCK_QUOTE    : Node_Type_Int;
   NODE_LIST           : Node_Type_Int;
   NODE_ITEM           : Node_Type_Int;
   NODE_CODE_BLOCK     : Node_Type_Int;
   NODE_HTML_BLOCK     : Node_Type_Int;
   NODE_PARAGRAPH      : Node_Type_Int;
   NODE_HEADING        : Node_Type_Int;
   NODE_THEMATIC_BREAK : Node_Type_Int;
   NODE_TEXT           : Node_Type_Int;
   NODE_SOFTBREAK      : Node_Type_Int;
   NODE_LINEBREAK      : Node_Type_Int;
   NODE_CODE           : Node_Type_Int;
   NODE_HTML_INLINE    : Node_Type_Int;
   NODE_EMPH           : Node_Type_Int;
   NODE_STRONG         : Node_Type_Int;
   NODE_LINK           : Node_Type_Int;
   NODE_IMAGE          : Node_Type_Int;

   --  List types
   LIST_NO_LIST  : List_Type_Int;
   LIST_BULLET   : List_Type_Int;
   LIST_ORDERED  : List_Type_Int;

   --  Iterator event types
   EVENT_NONE  : Event_Type_Int;
   EVENT_DONE  : Event_Type_Int;
   EVENT_ENTER : Event_Type_Int;
   EVENT_EXIT  : Event_Type_Int;

   --  Parse option flag
   OPT_DEFAULT : Interfaces.C.int;

   --  ── libcmark API ───────────────────────────────────────────────────

   --  Parse a GFM document from a byte buffer (table, strikethrough, and
   --  autolink extensions are enabled automatically).
   --  Options should be OPT_DEFAULT (0) for standard parsing.
   --  Caller must free the returned node with Node_Free.
   function Parse_Document
     (Buffer  : Interfaces.C.char_array;
      Len     : Interfaces.C.size_t;
      Options : Interfaces.C.int) return Node_Ptr
   with Import, Convention => C, External_Name => "cmark_shim_parse_document_gfm";

   --  Free a document node tree returned by Parse_Document.
   procedure Node_Free (Node : Node_Ptr)
   with Import, Convention => C, External_Name => "cmark_node_free";

   --  Return the node type constant for Node.
   function Node_Get_Type (Node : Node_Ptr) return Node_Type_Int
   with Import, Convention => C, External_Name => "cmark_node_get_type";

   --  Return the inclusive source line range occupied by Node.
   function Node_Get_Start_Line (Node : Node_Ptr) return Interfaces.C.int
   with Import, Convention => C,
        External_Name => "cmark_node_get_start_line";

   function Node_Get_End_Line (Node : Node_Ptr) return Interfaces.C.int
   with Import, Convention => C,
        External_Name => "cmark_node_get_end_line";

   --  Return the heading level (1..6) for NODE_HEADING nodes.
   function Node_Get_Heading_Level
     (Node : Node_Ptr) return Interfaces.C.int
   with Import, Convention => C,
        External_Name => "cmark_node_get_heading_level";

   --  Return the list type for NODE_LIST nodes.
   function Node_Get_List_Type (Node : Node_Ptr) return List_Type_Int
   with Import, Convention => C, External_Name => "cmark_node_get_list_type";

   --  Return the starting ordinal for NODE_LIST ordered lists.
   function Node_Get_List_Start (Node : Node_Ptr) return Interfaces.C.int
   with Import, Convention => C, External_Name => "cmark_node_get_list_start";

   --  Return the node's literal text, or "" if the node carries none.
   --  Uses cmark_shim_get_literal which converts NULL → "".
   function Node_Get_Literal
     (Node : Node_Ptr) return Interfaces.C.Strings.chars_ptr
   with Import, Convention => C, External_Name => "cmark_shim_get_literal";

   --  Create an iterator over the subtree rooted at Root.
   --  Caller must free with Iter_Free.
   function Iter_New (Root : Node_Ptr) return Iter_Ptr
   with Import, Convention => C, External_Name => "cmark_iter_new";

   --  Advance the iterator; returns the event type for the current node.
   function Iter_Next (Iter : Iter_Ptr) return Event_Type_Int
   with Import, Convention => C, External_Name => "cmark_iter_next";

   --  Return the node associated with the most recent Iter_Next call.
   function Iter_Get_Node (Iter : Iter_Ptr) return Node_Ptr
   with Import, Convention => C, External_Name => "cmark_iter_get_node";

   --  Free an iterator created by Iter_New.
   procedure Iter_Free (Iter : Iter_Ptr)
   with Import, Convention => C, External_Name => "cmark_iter_free";

   --  Return the type-name string for Node (e.g. "paragraph", "table",
   --  "table_row", "table_cell", "strikethrough").  Extension nodes carry
   --  dynamic integer type-ids; this string is the only portable identifier.
   --  Never returns Null_Ptr.
   function Node_Get_Type_String
     (Node : Node_Ptr) return Interfaces.C.Strings.chars_ptr
   with Import, Convention => C,
        External_Name => "cmark_shim_node_get_type_string";

   --  Return the number of columns in a GFM table node.
   function Table_Column_Count
     (Node : Node_Ptr) return Interfaces.C.int
   with Import, Convention => C,
        External_Name => "cmark_shim_table_column_count";

   --  Return the alignment byte for a zero-based table column.  The result
   --  is zero for unspecified alignment or an invalid column.
   function Table_Column_Alignment
     (Node   : Node_Ptr;
      Column : Interfaces.C.int) return Interfaces.C.int
   with Import, Convention => C,
        External_Name => "cmark_shim_table_column_alignment";

   --  Return 1 if Node is a table_row that is the header row, else 0.
   function Table_Row_Is_Header
     (Node : Node_Ptr) return Interfaces.C.int
   with Import, Convention => C,
        External_Name => "cmark_shim_table_row_is_header";

   --  Return the first child of Node, or System.Null_Address if none.
   function Node_First_Child (Node : Node_Ptr) return Node_Ptr
   with Import, Convention => C,
        External_Name => "cmark_node_first_child";

   --  Return the next sibling of Node, or System.Null_Address if none.
   function Node_Next (Node : Node_Ptr) return Node_Ptr
   with Import, Convention => C,
        External_Name => "cmark_node_next";

end Coyote_Cmark;
