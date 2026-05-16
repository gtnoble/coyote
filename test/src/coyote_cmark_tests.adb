--  Coyote_Cmark_Tests body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with AUnit.Assertions;
with Coyote_Cmark;
with Ada.Characters.Latin_1;
with Ada.Strings.Fixed;
with Interfaces.C;
with Interfaces.C.Strings;
with System;

package body Coyote_Cmark_Tests is

   use AUnit.Assertions;
   use type System.Address;
   use Interfaces.C;
   use Interfaces.C.Strings;

   --  Convenience: parse a CommonMark string and return the root node.
   function Parse (S : String) return Coyote_Cmark.Node_Ptr is
      C_Text : constant char_array := To_C (S, Append_Nul => True);
   begin
      return Coyote_Cmark.Parse_Document
               (C_Text, size_t (S'Length), Coyote_Cmark.OPT_DEFAULT);
   end Parse;

   ---------------------------------------------------------------------------

   procedure Test_Constants_Are_Non_Negative (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (Coyote_Cmark.NODE_NONE          >= 0, "NODE_NONE >= 0");
      Assert (Coyote_Cmark.NODE_DOCUMENT      >= 0, "NODE_DOCUMENT >= 0");
      Assert (Coyote_Cmark.NODE_PARAGRAPH     >= 0, "NODE_PARAGRAPH >= 0");
      Assert (Coyote_Cmark.NODE_TEXT          >= 0, "NODE_TEXT >= 0");
      Assert (Coyote_Cmark.NODE_HEADING       >= 0, "NODE_HEADING >= 0");
      Assert (Coyote_Cmark.NODE_STRONG        >= 0, "NODE_STRONG >= 0");
      Assert (Coyote_Cmark.NODE_EMPH          >= 0, "NODE_EMPH >= 0");
      Assert (Coyote_Cmark.NODE_CODE          >= 0, "NODE_CODE >= 0");
      Assert
        (Coyote_Cmark.NODE_THEMATIC_BREAK >= 0, "NODE_THEMATIC_BREAK >= 0");
      Assert (Coyote_Cmark.LIST_BULLET        >= 0, "LIST_BULLET >= 0");
      Assert (Coyote_Cmark.LIST_ORDERED       >= 0, "LIST_ORDERED >= 0");
      Assert (Coyote_Cmark.EVENT_DONE         >= 0, "EVENT_DONE >= 0");
      Assert (Coyote_Cmark.EVENT_ENTER        >= 0, "EVENT_ENTER >= 0");
      Assert (Coyote_Cmark.EVENT_EXIT         >= 0, "EVENT_EXIT >= 0");
      Assert (Coyote_Cmark.OPT_DEFAULT        >= 0, "OPT_DEFAULT >= 0");
   end Test_Constants_Are_Non_Negative;

   ---------------------------------------------------------------------------

   procedure Test_Parse_Returns_Non_Null (T : in out Test) is
      pragma Unreferenced (T);
      Doc : constant Coyote_Cmark.Node_Ptr := Parse ("hello");
   begin
      Assert (Doc /= System.Null_Address, "Parse_Document returned null");
      Coyote_Cmark.Node_Free (Doc);
   end Test_Parse_Returns_Non_Null;

   ---------------------------------------------------------------------------

   procedure Test_Root_Type_Is_Document (T : in out Test) is
      pragma Unreferenced (T);
      Doc    : constant Coyote_Cmark.Node_Ptr := Parse ("hello");
      NType  : Coyote_Cmark.Node_Type_Int;
   begin
      Assert (Doc /= System.Null_Address, "Parse_Document returned null");
      NType := Coyote_Cmark.Node_Get_Type (Doc);
      Assert (NType = Coyote_Cmark.NODE_DOCUMENT,
              "root node type should be NODE_DOCUMENT");
      Coyote_Cmark.Node_Free (Doc);
   end Test_Root_Type_Is_Document;

   ---------------------------------------------------------------------------

   procedure Test_Iterator_Yields_Text_Event (T : in out Test) is
      pragma Unreferenced (T);
      Doc        : constant Coyote_Cmark.Node_Ptr := Parse ("hello");
      Iter       : Coyote_Cmark.Iter_Ptr;
      Ev         : Coyote_Cmark.Event_Type_Int;
      Node       : Coyote_Cmark.Node_Ptr;
      Found_Text : Boolean := False;
   begin
      Assert (Doc /= System.Null_Address, "Parse_Document returned null");
      Iter := Coyote_Cmark.Iter_New (Doc);

      loop
         Ev := Coyote_Cmark.Iter_Next (Iter);
         exit when Ev = Coyote_Cmark.EVENT_DONE;

         if Ev = Coyote_Cmark.EVENT_ENTER then
            Node := Coyote_Cmark.Iter_Get_Node (Iter);
            if Coyote_Cmark.Node_Get_Type (Node) = Coyote_Cmark.NODE_TEXT then
               Found_Text := True;
            end if;
         end if;
      end loop;

      Coyote_Cmark.Iter_Free (Iter);
      Coyote_Cmark.Node_Free (Doc);

      Assert (Found_Text, "iterator should yield at least one TEXT event");
   end Test_Iterator_Yields_Text_Event;

   ---------------------------------------------------------------------------

   procedure Test_Literal_Matches_Input (T : in out Test) is
      pragma Unreferenced (T);
      Input      : constant String := "coyote";
      Doc        : constant Coyote_Cmark.Node_Ptr := Parse (Input);
      Iter       : Coyote_Cmark.Iter_Ptr;
      Ev         : Coyote_Cmark.Event_Type_Int;
      Node       : Coyote_Cmark.Node_Ptr;
      Found      : Boolean := False;
   begin
      Assert (Doc /= System.Null_Address, "Parse_Document returned null");
      Iter := Coyote_Cmark.Iter_New (Doc);

      loop
         Ev := Coyote_Cmark.Iter_Next (Iter);
         exit when Ev = Coyote_Cmark.EVENT_DONE;

         if Ev = Coyote_Cmark.EVENT_ENTER then
            Node := Coyote_Cmark.Iter_Get_Node (Iter);
            if Coyote_Cmark.Node_Get_Type (Node) = Coyote_Cmark.NODE_TEXT then
               declare
                  Ptr : constant chars_ptr :=
                    Coyote_Cmark.Node_Get_Literal (Node);
                  Lit : constant String :=
                    (if Ptr /= Null_Ptr then Value (Ptr) else "");
               begin
                  if Lit = Input then
                     Found := True;
                  end if;
               end;
            end if;
         end if;
      end loop;

      Coyote_Cmark.Iter_Free (Iter);
      Coyote_Cmark.Node_Free (Doc);

      Assert (Found, "TEXT node literal should equal the input word");
   end Test_Literal_Matches_Input;

   ---------------------------------------------------------------------------

   procedure Test_Free_Does_Not_Raise (T : in out Test) is
      pragma Unreferenced (T);
      Doc  : constant Coyote_Cmark.Node_Ptr := Parse ("**bold**");
      Iter : Coyote_Cmark.Iter_Ptr;
      Ev   : Coyote_Cmark.Event_Type_Int;
   begin
      Assert (Doc /= System.Null_Address, "Parse_Document returned null");
      Iter := Coyote_Cmark.Iter_New (Doc);

      --  Drain the iterator fully before freeing.
      loop
         Ev := Coyote_Cmark.Iter_Next (Iter);
         exit when Ev = Coyote_Cmark.EVENT_DONE;
      end loop;

      Coyote_Cmark.Iter_Free (Iter);
      Coyote_Cmark.Node_Free (Doc);

      Assert (True, "Free and Iter_Free should not raise");
   end Test_Free_Does_Not_Raise;


   ---------------------------------------------------------------------------
   --  Shared helper: return first node whose type = Target_Type, or
   --  Null_Address when not found.  Caller must already hold Doc alive.
   function Find_Node
     (Doc         : Coyote_Cmark.Node_Ptr;
      Target_Type : Coyote_Cmark.Node_Type_Int)
      return Coyote_Cmark.Node_Ptr
   is
      use type System.Address;
      Iter   : constant Coyote_Cmark.Iter_Ptr :=
        Coyote_Cmark.Iter_New (Doc);
      Ev     : Coyote_Cmark.Event_Type_Int;
      Node   : Coyote_Cmark.Node_Ptr;
      Result : Coyote_Cmark.Node_Ptr := System.Null_Address;
   begin
      loop
         Ev := Coyote_Cmark.Iter_Next (Iter);
         exit when Ev = Coyote_Cmark.EVENT_DONE;
         if Ev = Coyote_Cmark.EVENT_ENTER then
            Node := Coyote_Cmark.Iter_Get_Node (Iter);
            if Coyote_Cmark.Node_Get_Type (Node) = Target_Type then
               Result := Node;
               exit;
            end if;
         end if;
      end loop;
      Coyote_Cmark.Iter_Free (Iter);
      return Result;
   end Find_Node;

   ---------------------------------------------------------------------------

   procedure Test_Heading_Level (T : in out Test) is
      pragma Unreferenced (T);
      use type System.Address;
      Doc1 : constant Coyote_Cmark.Node_Ptr := Parse ("# Heading");
      Doc3 : constant Coyote_Cmark.Node_Ptr := Parse ("### Deep");
      H1   : Coyote_Cmark.Node_Ptr;
      H3   : Coyote_Cmark.Node_Ptr;
   begin
      Assert (Doc1 /= System.Null_Address, "Parse h1 returned null");
      Assert (Doc3 /= System.Null_Address, "Parse h3 returned null");

      H1 := Find_Node (Doc1, Coyote_Cmark.NODE_HEADING);
      Assert (H1 /= System.Null_Address,
              "NODE_HEADING not found in '# Heading'");
      Assert (Integer (Coyote_Cmark.Node_Get_Heading_Level (H1)) = 1,
              "heading level should be 1 for '# Heading'");

      H3 := Find_Node (Doc3, Coyote_Cmark.NODE_HEADING);
      Assert (H3 /= System.Null_Address,
              "NODE_HEADING not found in '### Deep'");
      Assert (Integer (Coyote_Cmark.Node_Get_Heading_Level (H3)) = 3,
              "heading level should be 3 for '### Deep'");

      Coyote_Cmark.Node_Free (Doc1);
      Coyote_Cmark.Node_Free (Doc3);
   end Test_Heading_Level;

   ---------------------------------------------------------------------------

   procedure Test_List_Type_Is_Bullet (T : in out Test) is
      pragma Unreferenced (T);
      use type System.Address;
      Doc  : constant Coyote_Cmark.Node_Ptr := Parse ("- item");
      List : Coyote_Cmark.Node_Ptr;
   begin
      Assert (Doc /= System.Null_Address, "Parse returned null");
      List := Find_Node (Doc, Coyote_Cmark.NODE_LIST);
      Assert (List /= System.Null_Address,
              "NODE_LIST not found in '- item'");
      Assert (Coyote_Cmark.Node_Get_List_Type (List)
              = Coyote_Cmark.LIST_BULLET,
              "list type should be LIST_BULLET for '- item'");
      Coyote_Cmark.Node_Free (Doc);
   end Test_List_Type_Is_Bullet;

   ---------------------------------------------------------------------------

   procedure Test_List_Type_Is_Ordered (T : in out Test) is
      pragma Unreferenced (T);
      use type System.Address;
      Doc  : constant Coyote_Cmark.Node_Ptr := Parse ("1. item");
      List : Coyote_Cmark.Node_Ptr;
   begin
      Assert (Doc /= System.Null_Address, "Parse returned null");
      List := Find_Node (Doc, Coyote_Cmark.NODE_LIST);
      Assert (List /= System.Null_Address,
              "NODE_LIST not found in '1. item'");
      Assert (Coyote_Cmark.Node_Get_List_Type (List)
              = Coyote_Cmark.LIST_ORDERED,
              "list type should be LIST_ORDERED for '1. item'");
      Coyote_Cmark.Node_Free (Doc);
   end Test_List_Type_Is_Ordered;

   ---------------------------------------------------------------------------

   procedure Test_List_Start_Ordinal (T : in out Test) is
      pragma Unreferenced (T);
      use type System.Address;
      Doc  : constant Coyote_Cmark.Node_Ptr := Parse ("3. item");
      List : Coyote_Cmark.Node_Ptr;
   begin
      Assert (Doc /= System.Null_Address, "Parse returned null");
      List := Find_Node (Doc, Coyote_Cmark.NODE_LIST);
      Assert (List /= System.Null_Address,
              "NODE_LIST not found in '3. item'");
      Assert (Integer (Coyote_Cmark.Node_Get_List_Start (List)) = 3,
              "list start ordinal should be 3 for '3. item'");
      Coyote_Cmark.Node_Free (Doc);
   end Test_List_Start_Ordinal;

   ---------------------------------------------------------------------------

   procedure Test_Code_Block_Literal (T : in out Test) is
      pragma Unreferenced (T);
      use type System.Address;
      --  Fenced code block in CommonMark: ``` on its own line.
      Md   : constant String :=
        "```" & Ada.Characters.Latin_1.LF & "hello code" & Ada.Characters.Latin_1.LF & "```" & Ada.Characters.Latin_1.LF;
      Doc  : constant Coyote_Cmark.Node_Ptr := Parse (Md);
      CB   : Coyote_Cmark.Node_Ptr;
      Ptr  : Interfaces.C.Strings.chars_ptr;
   begin
      Assert (Doc /= System.Null_Address, "Parse returned null");
      CB := Find_Node (Doc, Coyote_Cmark.NODE_CODE_BLOCK);
      Assert (CB /= System.Null_Address,
              "NODE_CODE_BLOCK not found in fenced code input");
      Ptr := Coyote_Cmark.Node_Get_Literal (CB);
      Assert (Ptr /= Interfaces.C.Strings.Null_Ptr,
              "Node_Get_Literal on CODE_BLOCK should not be null");
      declare
         use Ada.Strings.Fixed;
         S : constant String := Interfaces.C.Strings.Value (Ptr);
      begin
         Assert (Index (S, "hello code") > 0,
                 "code block literal should contain 'hello code'");
      end;
      Coyote_Cmark.Node_Free (Doc);
   end Test_Code_Block_Literal;

   ---------------------------------------------------------------------------

   procedure Test_Get_Literal_Null_Safety (T : in out Test) is
      pragma Unreferenced (T);
      use type System.Address;
      --  NODE_PARAGRAPH has no literal; cmark_node_get_literal returns NULL.
      --  The shim (cmark_shim_get_literal) must convert that to "".
      Doc  : constant Coyote_Cmark.Node_Ptr := Parse ("hello");
      Para : Coyote_Cmark.Node_Ptr;
      Ptr  : Interfaces.C.Strings.chars_ptr;
   begin
      Assert (Doc /= System.Null_Address, "Parse returned null");
      Para := Find_Node (Doc, Coyote_Cmark.NODE_PARAGRAPH);
      Assert (Para /= System.Null_Address,
              "NODE_PARAGRAPH not found in 'hello'");
      Ptr := Coyote_Cmark.Node_Get_Literal (Para);
      Assert (Ptr /= Interfaces.C.Strings.Null_Ptr,
              "shim should return non-null for NODE_PARAGRAPH (null-safety)");
      declare
         Lit_Str : constant String := Interfaces.C.Strings.Value (Ptr);
      begin
         Assert (Lit_Str = "",
                 "shim should return empty string for NODE_PARAGRAPH");
      end;
      Coyote_Cmark.Node_Free (Doc);
   end Test_Get_Literal_Null_Safety;

   ---------------------------------------------------------------------------

   procedure Test_Event_Constants_Are_Distinct (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (Coyote_Cmark.EVENT_ENTER /= Coyote_Cmark.EVENT_EXIT,
              "EVENT_ENTER and EVENT_EXIT must be distinct");
      Assert (Coyote_Cmark.EVENT_ENTER /= Coyote_Cmark.EVENT_DONE,
              "EVENT_ENTER and EVENT_DONE must be distinct");
      Assert (Coyote_Cmark.EVENT_EXIT  /= Coyote_Cmark.EVENT_DONE,
              "EVENT_EXIT and EVENT_DONE must be distinct");
   end Test_Event_Constants_Are_Distinct;

   ---------------------------------------------------------------------------

   procedure Test_Node_Constants_Are_Distinct (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (Coyote_Cmark.NODE_TEXT     /= Coyote_Cmark.NODE_STRONG,
              "NODE_TEXT and NODE_STRONG must be distinct");
      Assert (Coyote_Cmark.NODE_TEXT     /= Coyote_Cmark.NODE_EMPH,
              "NODE_TEXT and NODE_EMPH must be distinct");
      Assert (Coyote_Cmark.NODE_TEXT     /= Coyote_Cmark.NODE_CODE,
              "NODE_TEXT and NODE_CODE must be distinct");
      Assert (Coyote_Cmark.NODE_TEXT     /= Coyote_Cmark.NODE_PARAGRAPH,
              "NODE_TEXT and NODE_PARAGRAPH must be distinct");
      Assert (Coyote_Cmark.NODE_HEADING  /= Coyote_Cmark.NODE_PARAGRAPH,
              "NODE_HEADING and NODE_PARAGRAPH must be distinct");
      Assert (Coyote_Cmark.NODE_LIST     /= Coyote_Cmark.NODE_ITEM,
              "NODE_LIST and NODE_ITEM must be distinct");
      Assert (Coyote_Cmark.NODE_CODE     /= Coyote_Cmark.NODE_CODE_BLOCK,
              "NODE_CODE and NODE_CODE_BLOCK must be distinct");
      Assert
        (Coyote_Cmark.NODE_DOCUMENT /= Coyote_Cmark.NODE_NONE,
         "NODE_DOCUMENT and NODE_NONE must be distinct");
   end Test_Node_Constants_Are_Distinct;

end Coyote_Cmark_Tests;
