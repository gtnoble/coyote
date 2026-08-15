--  Coyote_GUI.Conversation.Testing — test accessors for internal state.
--
--  A public child of Coyote_GUI.Conversation that exposes private fields
--  for unit testing.  Lives in test/src/ so it is not part of the
--  production build.
--
--  Project: coyote

with Glib;

package Coyote_GUI.Conversation.Testing is

   function Line_Count (C : Instance) return Natural;
   --  Number of logical lines in the conversation.

   function Vis_Count_At (C : Instance; Index : Positive) return Natural;
   --  Cached visual-line count for logical line Index.
   --  Raises Constraint_Error if Index > Line_Count.

   function Total_Vis_Lines (C : Instance) return Natural;
   --  Sum of Vis_Count across all logical lines.

   function Total_Height_Px (C : Instance) return Natural;
   --  Sum of Pixel_Height across all logical lines.

   function Pixel_Height_At (C : Instance; Index : Positive) return Natural;
   --  Cached pixel height of logical line Index.

   function Line_Height_Px (C : Instance) return Glib.Gint;
   --  Body-text metric used as the empty-block fallback.

   function Is_In_Text_Block (C : Instance) return Boolean;
   --  True while streaming assistant text (between first Append_Text
   --  and End_Text_Block).

   function Stream_Buffer (C : Instance) return String;
   --  Accumulated raw text in the streaming buffer.

   function Is_In_Thinking (C : Instance) return Boolean;
   --  True inside a Begin_Thinking .. End_Thinking region.

   function Cache_Width_Px (C : Instance) return Glib.Gint;
   --  Width at which the Vis_Count cache was last computed.
   --  Zero means the cache is invalid.

   function Cached_Line_Count (C : Instance) return Natural;
   --  Line count at which the Vis_Count cache was last computed.

   function Has_Markup_Flag (C : Instance; Index : Positive) return Boolean;
   --  True when logical line Index has Has_Markup = True.

   function Get_Line_Style
     (C : Instance; Index : Positive) return Line_Style;
   --  Style assigned to logical line Index.

   function Get_Line_Tool_Status
     (C : Instance; Index : Positive) return Tool_End_Status;
   --  Tool status assigned to logical line Index.

   function Is_Line_Tool_Running
     (C : Instance; Index : Positive) return Boolean;
   --  True while logical line Index belongs to a running tool card.

   function Get_Line_Text (C : Instance; Index : Positive) return String;
   --  Raw text of logical line Index (Pango markup stripped if present).

   function Selection_Visible (C : Instance) return Boolean;
   --  True when a selection range is active.

   procedure Set_Selection
     (C           : in out Instance;
      Start_Line  :        Natural;
      Start_Byte  :        Natural;
      End_Line    :        Natural;
      End_Byte    :        Natural);
   --  Programmatically set the selection range (bypasses mouse events).

   function Extract_Text
     (C          : in out Instance;
      Start_Line :        Natural;
      Start_Byte :        Natural;
      End_Line   :        Natural;
      End_Byte   :        Natural) return String;
   --  Return the text spanned by a selection range, using the same
   --  extraction logic as Copy_Selection_To_Clipboard (LF between lines,
   --  Pango markup stripped).

   procedure Get_Ordered_Selection
     (C          : Instance;
      Start_Line : out Natural;
      Start_Byte : out Natural;
      End_Line   : out Natural;
      End_Byte   : out Natural);
   --  Return the stored selection endpoints in document order.

end Coyote_GUI.Conversation.Testing;
