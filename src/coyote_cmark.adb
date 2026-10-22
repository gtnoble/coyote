--  Coyote_Cmark body — package elaboration initialises all enum constants
--  by calling the C shim getters declared locally here.
--
--  Project: coyote
--  For revision history, see the project version-control log.

package body Coyote_Cmark is

   use type Interfaces.C.Strings.chars_ptr;
   use type System.Address;

   Empty_String : aliased Interfaces.C.char_array :=
     Interfaces.C.To_C ("");
   Empty_String_Ptr : constant Interfaces.C.Strings.chars_ptr :=
     Interfaces.C.Strings.To_Chars_Ptr (Empty_String'Access);

   function Raw_Literal
     (Node : Node_Ptr) return Interfaces.C.Strings.chars_ptr with
     Import, Convention => C, External_Name => "cmark_node_get_literal";

   function Raw_Url
     (Node : Node_Ptr) return Interfaces.C.Strings.chars_ptr with
     Import, Convention => C, External_Name => "cmark_node_get_url";

   function Raw_Title
     (Node : Node_Ptr) return Interfaces.C.Strings.chars_ptr with
     Import, Convention => C, External_Name => "cmark_node_get_title";

   function Raw_Type_String
     (Node : Node_Ptr) return Interfaces.C.Strings.chars_ptr with
     Import, Convention => C, External_Name => "cmark_node_get_type_string";

   function Node_Get_Literal
     (Node : Node_Ptr) return Interfaces.C.Strings.chars_ptr is
      Result : constant Interfaces.C.Strings.chars_ptr := Raw_Literal (Node);
   begin
      return (if Result = Interfaces.C.Strings.Null_Ptr
              then Empty_String_Ptr else Result);
   end Node_Get_Literal;

   function Node_Get_Url
     (Node : Node_Ptr) return Interfaces.C.Strings.chars_ptr is
      Result : constant Interfaces.C.Strings.chars_ptr := Raw_Url (Node);
   begin
      return (if Result = Interfaces.C.Strings.Null_Ptr
              then Empty_String_Ptr else Result);
   end Node_Get_Url;

   function Node_Get_Title
     (Node : Node_Ptr) return Interfaces.C.Strings.chars_ptr is
      Result : constant Interfaces.C.Strings.chars_ptr := Raw_Title (Node);
   begin
      return (if Result = Interfaces.C.Strings.Null_Ptr
              then Empty_String_Ptr else Result);
   end Node_Get_Title;

   function Node_Get_Type_String
     (Node : Node_Ptr) return Interfaces.C.Strings.chars_ptr is
      Result : constant Interfaces.C.Strings.chars_ptr :=
        Raw_Type_String (Node);
   begin
      return (if Result = Interfaces.C.Strings.Null_Ptr
              then Empty_String_Ptr else Result);
   end Node_Get_Type_String;

   function Copy_String
     (Value : Interfaces.C.Strings.chars_ptr) return String is
   begin
      if Value = Interfaces.C.Strings.Null_Ptr then
         return "";
      end if;
      return Interfaces.C.Strings.Value (Value);
   end Copy_String;

   function Literal (Node : Node_Ptr) return String is
   begin
      return Copy_String (Raw_Literal (Node));
   end Literal;

   function Url (Node : Node_Ptr) return String is
   begin
      return Copy_String (Raw_Url (Node));
   end Url;

   function Title (Node : Node_Ptr) return String is
   begin
      return Copy_String (Raw_Title (Node));
   end Title;

   function Type_String (Node : Node_Ptr) return String is
   begin
      return Copy_String (Raw_Type_String (Node));
   end Type_String;

   overriding function "=" (Left, Right : Node_Ptr) return Boolean is
   begin
      return System.Address (Left) = System.Address (Right);
   end "=";

   overriding function "=" (Left, Right : Iter_Ptr) return Boolean is
   begin
      return System.Address (Left) = System.Address (Right);
   end "=";

   function Is_Null (Node : Node_Ptr) return Boolean is
   begin
      return Node = Null_Node;
   end Is_Null;

   function Is_Null (Iter : Iter_Ptr) return Boolean is
   begin
      return Iter = Null_Iter;
   end Is_Null;

   procedure Parse
     (Owner   : in out Document;
      Buffer  : Interfaces.C.char_array;
      Len     : Interfaces.C.size_t;
      Options : Interfaces.C.int) is
   begin
      Finalize (Owner);
      Owner.Value := Parse_Document (Buffer, Len, Options);
   end Parse;

   function Root (Owner : Document) return Node_Ptr is
   begin
      return Owner.Value;
   end Root;

   procedure Start
     (Owner : in out Iterator;
      Root  : Node_Ptr) is
   begin
      Finalize (Owner);
      if not Is_Null (Root) then
         Owner.Value := Iter_New (Root);
      end if;
   end Start;

   function Handle (Owner : Iterator) return Iter_Ptr is
   begin
      return Owner.Value;
   end Handle;

   overriding procedure Finalize (Owner : in out Iterator) is
      Value : constant Iter_Ptr := Owner.Value;
   begin
      Owner.Value := Null_Iter;
      if not Is_Null (Value) then
         Iter_Free (Value);
      end if;
   end Finalize;

   overriding procedure Finalize (Owner : in out Document) is
      Value : constant Node_Ptr := Owner.Value;
   begin
      Owner.Value := Null_Node;
      if not Is_Null (Value) then
         Node_Free (Value);
      end if;
   end Finalize;

   --  ── C shim getter imports ──────────────────────────────────────────
   --
   --  These are implementation details; only the initialised variables
   --  are visible to clients via the package spec.

   function Shim_Node_None return Interfaces.C.int with
     Import, Convention => C, External_Name => "cmark_shim_node_none";

   function Shim_Node_Document return Interfaces.C.int with
     Import, Convention => C, External_Name => "cmark_shim_node_document";

   function Shim_Node_Block_Quote return Interfaces.C.int with
     Import, Convention => C, External_Name => "cmark_shim_node_block_quote";

   function Shim_Node_List return Interfaces.C.int with
     Import, Convention => C, External_Name => "cmark_shim_node_list";

   function Shim_Node_Item return Interfaces.C.int with
     Import, Convention => C, External_Name => "cmark_shim_node_item";

   function Shim_Node_Code_Block return Interfaces.C.int with
     Import, Convention => C, External_Name => "cmark_shim_node_code_block";

   function Shim_Node_Html_Block return Interfaces.C.int with
     Import, Convention => C, External_Name => "cmark_shim_node_html_block";

   function Shim_Node_Paragraph return Interfaces.C.int with
     Import, Convention => C, External_Name => "cmark_shim_node_paragraph";

   function Shim_Node_Heading return Interfaces.C.int with
     Import, Convention => C, External_Name => "cmark_shim_node_heading";

   function Shim_Node_Thematic_Break return Interfaces.C.int with
     Import,
     Convention    => C,
     External_Name => "cmark_shim_node_thematic_break";

   function Shim_Node_Text return Interfaces.C.int with
     Import, Convention => C, External_Name => "cmark_shim_node_text";

   function Shim_Node_Softbreak return Interfaces.C.int with
     Import, Convention => C, External_Name => "cmark_shim_node_softbreak";

   function Shim_Node_Linebreak return Interfaces.C.int with
     Import, Convention => C, External_Name => "cmark_shim_node_linebreak";

   function Shim_Node_Code return Interfaces.C.int with
     Import, Convention => C, External_Name => "cmark_shim_node_code";

   function Shim_Node_Html_Inline return Interfaces.C.int with
     Import, Convention => C, External_Name => "cmark_shim_node_html_inline";

   function Shim_Node_Emph return Interfaces.C.int with
     Import, Convention => C, External_Name => "cmark_shim_node_emph";

   function Shim_Node_Strong return Interfaces.C.int with
     Import, Convention => C, External_Name => "cmark_shim_node_strong";

   function Shim_Node_Link return Interfaces.C.int with
     Import, Convention => C, External_Name => "cmark_shim_node_link";

   function Shim_Node_Image return Interfaces.C.int with
     Import, Convention => C, External_Name => "cmark_shim_node_image";

   function Shim_List_No_List return Interfaces.C.int with
     Import, Convention => C, External_Name => "cmark_shim_list_no_list";

   function Shim_List_Bullet return Interfaces.C.int with
     Import, Convention => C, External_Name => "cmark_shim_list_bullet";

   function Shim_List_Ordered return Interfaces.C.int with
     Import, Convention => C, External_Name => "cmark_shim_list_ordered";

   function Shim_Event_None return Interfaces.C.int with
     Import, Convention => C, External_Name => "cmark_shim_event_none";

   function Shim_Event_Done return Interfaces.C.int with
     Import, Convention => C, External_Name => "cmark_shim_event_done";

   function Shim_Event_Enter return Interfaces.C.int with
     Import, Convention => C, External_Name => "cmark_shim_event_enter";

   function Shim_Event_Exit return Interfaces.C.int with
     Import, Convention => C, External_Name => "cmark_shim_event_exit";

   function Shim_Opt_Default return Interfaces.C.int with
     Import, Convention => C, External_Name => "cmark_shim_opt_default";

begin
   --  Node types
   NODE_NONE           := Shim_Node_None;
   NODE_DOCUMENT       := Shim_Node_Document;
   NODE_BLOCK_QUOTE    := Shim_Node_Block_Quote;
   NODE_LIST           := Shim_Node_List;
   NODE_ITEM           := Shim_Node_Item;
   NODE_CODE_BLOCK     := Shim_Node_Code_Block;
   NODE_HTML_BLOCK     := Shim_Node_Html_Block;
   NODE_PARAGRAPH      := Shim_Node_Paragraph;
   NODE_HEADING        := Shim_Node_Heading;
   NODE_THEMATIC_BREAK := Shim_Node_Thematic_Break;
   NODE_TEXT           := Shim_Node_Text;
   NODE_SOFTBREAK      := Shim_Node_Softbreak;
   NODE_LINEBREAK      := Shim_Node_Linebreak;
   NODE_CODE           := Shim_Node_Code;
   NODE_HTML_INLINE    := Shim_Node_Html_Inline;
   NODE_EMPH           := Shim_Node_Emph;
   NODE_STRONG         := Shim_Node_Strong;
   NODE_LINK           := Shim_Node_Link;
   NODE_IMAGE          := Shim_Node_Image;

   --  List types
   LIST_NO_LIST := Shim_List_No_List;
   LIST_BULLET  := Shim_List_Bullet;
   LIST_ORDERED := Shim_List_Ordered;

   --  Event types
   EVENT_NONE  := Shim_Event_None;
   EVENT_DONE  := Shim_Event_Done;
   EVENT_ENTER := Shim_Event_Enter;
   EVENT_EXIT  := Shim_Event_Exit;

   --  Parse options
   OPT_DEFAULT := Shim_Opt_Default;

end Coyote_Cmark;
