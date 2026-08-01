package body Coyote_GUI.Conversation.Testing is

   function Line_Count (C : Instance) return Natural is
   begin
      return Natural (C.Lines.Length);
   end Line_Count;

   function Vis_Count_At (C : Instance; Index : Positive) return Natural is
   begin
      return C.Lines (Index).Vis_Count;
   end Vis_Count_At;

   function Total_Vis_Lines (C : Instance) return Natural is
   begin
      return C.Total_Vis_Lines;
   end Total_Vis_Lines;

   function Line_Height_Px (C : Instance) return Glib.Gint is
   begin
      return C.Line_Height_Px;
   end Line_Height_Px;

   function Is_In_Text_Block (C : Instance) return Boolean is
   begin
      return C.In_Text_Block;
   end Is_In_Text_Block;

   function Stream_Buffer (C : Instance) return String is
   begin
      return To_String (C.Stream_Buf);
   end Stream_Buffer;

   function Is_In_Thinking (C : Instance) return Boolean is
   begin
      return C.In_Thinking;
   end Is_In_Thinking;

   function Cache_Width_Px (C : Instance) return Glib.Gint is
   begin
      return C.Cache_Width_Px;
   end Cache_Width_Px;

   function Cached_Line_Count (C : Instance) return Natural is
   begin
      return C.Cached_Line_Count;
   end Cached_Line_Count;

end Coyote_GUI.Conversation.Testing;
