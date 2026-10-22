--  Coyote_Cmark — Ada binding to libcmark-gfm.
--
--  Production callers should use Document and Iterator owners.  Borrowed node
--  handles and iterator handles are valid only while their owning document is
--  alive; callers must finalize iterators before their documents.  Do not
--  replace a document with Parse while an iterator still borrows its root.
--  This lifetime relation is documented, not statically enforced between
--  objects.
--  Low-level Parse_Document, Node_Free, Iter_New, and Iter_Free remain for
--  binding qualification tests only; production code must not use them.

with Ada.Finalization;
with Interfaces.C;
with Interfaces.C.Strings;
with System;

package Coyote_Cmark is
   pragma Elaborate_Body;

   type Node_Ptr is private;
   type Iter_Ptr is private;

   overriding function "=" (Left, Right : Node_Ptr) return Boolean;
   overriding function "=" (Left, Right : Iter_Ptr) return Boolean;

   Null_Node : constant Node_Ptr;
   Null_Iter : constant Iter_Ptr;

   function Is_Null (Node : Node_Ptr) return Boolean;
   function Is_Null (Iter : Iter_Ptr) return Boolean;

   type Document is limited private;
   type Iterator is limited private;

   --  Replaces and finalizes the prior document before parsing.  This
   --  invalidates its borrowed root and all nodes from that tree.  The
   --  returned root is borrowed; do not pass it to Node_Free or otherwise
   --  free it with the low-level API.  A null parse result is reported by
   --  Root returning Null_Node.  Finalization frees the tree.
   procedure Parse
     (Owner   : in out Document;
      Buffer  : Interfaces.C.char_array;
      Len     : Interfaces.C.size_t;
      Options : Interfaces.C.int);
   --  Returns a borrowed root, valid only until Owner is finalized or
   --  replaced by Parse.  Do not free it with Node_Free.
   function Root (Owner : Document) return Node_Ptr;

   --  Replaces and finalizes the prior iterator before starting.  Root must
   --  remain valid for the iterator's lifetime.  Finalize iterators before
   --  their document; finalization releases the iterator before the tree.
   procedure Start
     (Owner : in out Iterator;
      Root  : Node_Ptr);
   --  Returns a borrowed handle; do not pass it to Iter_Free.
   function Handle (Owner : Iterator) return Iter_Ptr;

   --  These four functions return independent Ada String copies; no C-owned
   --  string storage escapes through these functions.  Legacy borrowed
   --  chars_ptr accessors remain public below.
   function Literal (Node : Node_Ptr) return String;
   function Url (Node : Node_Ptr) return String;
   function Title (Node : Node_Ptr) return String;
   function Type_String (Node : Node_Ptr) return String;

   subtype Node_Type_Int is Interfaces.C.int;
   subtype List_Type_Int is Interfaces.C.int;
   subtype Event_Type_Int is Interfaces.C.int;

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

   LIST_NO_LIST : List_Type_Int;
   LIST_BULLET  : List_Type_Int;
   LIST_ORDERED : List_Type_Int;

   EVENT_NONE  : Event_Type_Int;
   EVENT_DONE  : Event_Type_Int;
   EVENT_ENTER : Event_Type_Int;
   EVENT_EXIT  : Event_Type_Int;

   OPT_DEFAULT : Interfaces.C.int;

   --  Legacy raw entry points are retained for binding tests only.
   function Parse_Document
     (Buffer  : Interfaces.C.char_array;
      Len     : Interfaces.C.size_t;
      Options : Interfaces.C.int) return Node_Ptr
     with Import, Convention => C,
       External_Name => "cmark_shim_parse_document_gfm";
   procedure Node_Free (Node : Node_Ptr)
     with Import, Convention => C, External_Name => "cmark_node_free";

   function Node_Get_Type (Node : Node_Ptr) return Node_Type_Int
     with Import, Convention => C, External_Name => "cmark_node_get_type";
   function Node_Get_Start_Line (Node : Node_Ptr) return Interfaces.C.int
     with Import, Convention => C,
       External_Name => "cmark_node_get_start_line";
   function Node_Get_End_Line (Node : Node_Ptr) return Interfaces.C.int
     with Import, Convention => C, External_Name => "cmark_node_get_end_line";
   function Node_Get_Heading_Level (Node : Node_Ptr) return Interfaces.C.int
     with Import, Convention => C,
       External_Name => "cmark_node_get_heading_level";
   function Node_Get_List_Type (Node : Node_Ptr) return List_Type_Int
     with Import, Convention => C,
       External_Name => "cmark_node_get_list_type";
   function Node_Get_List_Start (Node : Node_Ptr) return Interfaces.C.int
     with Import, Convention => C,
       External_Name => "cmark_node_get_list_start";

   --  Borrowed C-string accessors retained only for legacy binding tests.
   function Node_Get_Literal
     (Node : Node_Ptr) return Interfaces.C.Strings.chars_ptr;
   function Node_Get_Url
     (Node : Node_Ptr) return Interfaces.C.Strings.chars_ptr;
   function Node_Get_Title
     (Node : Node_Ptr) return Interfaces.C.Strings.chars_ptr;
   function Node_Get_Type_String
     (Node : Node_Ptr) return Interfaces.C.Strings.chars_ptr;

   function Iter_New (Root : Node_Ptr) return Iter_Ptr
     with Import, Convention => C, External_Name => "cmark_iter_new";
   function Iter_Next (Iter : Iter_Ptr) return Event_Type_Int
     with Import, Convention => C, External_Name => "cmark_iter_next";
   function Iter_Get_Node (Iter : Iter_Ptr) return Node_Ptr
     with Import, Convention => C, External_Name => "cmark_iter_get_node";
   procedure Iter_Free (Iter : Iter_Ptr)
     with Import, Convention => C, External_Name => "cmark_iter_free";

   function Table_Column_Count (Node : Node_Ptr) return Interfaces.C.int
     with Import, Convention => C,
       External_Name => "cmark_shim_table_column_count";
   function Table_Column_Alignment
     (Node : Node_Ptr; Column : Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C,
       External_Name => "cmark_shim_table_column_alignment";
   function Table_Row_Is_Header (Node : Node_Ptr) return Interfaces.C.int
     with Import, Convention => C,
       External_Name => "cmark_shim_table_row_is_header";
   function Node_First_Child (Node : Node_Ptr) return Node_Ptr
     with Import, Convention => C,
       External_Name => "cmark_node_first_child";
   function Node_Next (Node : Node_Ptr) return Node_Ptr
     with Import, Convention => C, External_Name => "cmark_node_next";

private
   type Node_Ptr is new System.Address;
   type Iter_Ptr is new System.Address;
   Null_Node : constant Node_Ptr := Node_Ptr (System.Null_Address);
   Null_Iter : constant Iter_Ptr := Iter_Ptr (System.Null_Address);

   type Document is new Ada.Finalization.Limited_Controlled with record
      Value : Node_Ptr := Null_Node;
   end record;
   overriding procedure Finalize (Owner : in out Document);

   type Iterator is new Ada.Finalization.Limited_Controlled with record
      Value : Iter_Ptr := Null_Iter;
   end record;
   overriding procedure Finalize (Owner : in out Iterator);
end Coyote_Cmark;
