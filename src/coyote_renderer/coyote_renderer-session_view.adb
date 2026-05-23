--  Coyote_Renderer.Session_View body.
--
--  Project: coyote

with Ada.Containers.Vectors;
with Ada.Containers.Hashed_Maps;
with Ada.Containers;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Ada.Text_IO;
with Coyote_App.Utils;       use Coyote_App.Utils;
with Coyote_Renderer.Markup;
with Coyote_SQC.Session_Parser;
with Glib;                   use Glib;
with Glib.Object;
with Glib.Properties;        use Glib.Properties;
with GNAT.OS_Lib;
with GNATCOLL.JSON;
with Gtk.Button;
with Gtk.Text_Child_Anchor;
with Gtk.Text_Iter;
with Gtk.Text_Tag;
with Pango.Enums;
with System;
with System.Storage_Elements;

package body Coyote_Renderer.Session_View is

   use type GNATCOLL.JSON.JSON_Value_Type;

   --  ── JSON helpers ──────────────────────────────────────────────────────

   function Get_Str (V : GNATCOLL.JSON.JSON_Value; F : String) return String is
   begin
      if V.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then V.Has_Field (F)
        and then V.Get (F).Kind = GNATCOLL.JSON.JSON_String_Type
      then
         return V.Get (F).Get;
      end if;
      return "";
   end Get_Str;

   function Get_Bool (V : GNATCOLL.JSON.JSON_Value; F : String) return Boolean is
   begin
      if V.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then V.Has_Field (F)
        and then V.Get (F).Kind = GNATCOLL.JSON.JSON_Boolean_Type
      then
         return V.Get (F).Get;
      end if;
      return False;
   end Get_Bool;

   --  ── Text-tag helpers ──────────────────────────────────────────────────

   procedure Append_Tagged
     (Buffer : not null access Gtk.Text_Buffer.Gtk_Text_Buffer_Record'Class;
      Text   : in String;
      Tag    : in Gtk.Text_Tag.Gtk_Text_Tag)
   is
      Iter : Gtk.Text_Iter.Gtk_Text_Iter;
   begin
      Buffer.Get_End_Iter (Iter);
      Buffer.Insert_With_Tags (Iter, Text, Tag);
   end Append_Tagged;

   procedure Append_Text
     (Buffer : not null access Gtk.Text_Buffer.Gtk_Text_Buffer_Record'Class;
      Text   : in String)
   is
      Iter : Gtk.Text_Iter.Gtk_Text_Iter;
   begin
      Buffer.Get_End_Iter (Iter);
      Buffer.Insert (Iter, Text);
   end Append_Text;

   procedure Append_Markup
     (Buffer : not null access Gtk.Text_Buffer.Gtk_Text_Buffer_Record'Class;
      Markup : in String)
   is
      Iter : Gtk.Text_Iter.Gtk_Text_Iter;
   begin
      Buffer.Get_End_Iter (Iter);
      Buffer.Insert_Markup (Iter, Markup, -1);
   end Append_Markup;

   --  ── Setup text tags ───────────────────────────────────────────────────

   type Tag_Set is record
      Thinking : Gtk.Text_Tag.Gtk_Text_Tag;
      Tool     : Gtk.Text_Tag.Gtk_Text_Tag;
      User     : Gtk.Text_Tag.Gtk_Text_Tag;
      Error    : Gtk.Text_Tag.Gtk_Text_Tag;
      Dim      : Gtk.Text_Tag.Gtk_Text_Tag;
   end record;

   function Make_Tags
     (Buffer : not null access Gtk.Text_Buffer.Gtk_Text_Buffer_Record'Class)
      return Tag_Set
   is
      use Gtk.Text_Tag;
      Tags : Tag_Set;
   begin
      Tags.Thinking := Buffer.Create_Tag ("sv_thinking");
      Set_Property (Tags.Thinking, Foreground_Property, "#7070a0");
      Set_Property (Tags.Thinking, Background_Property, "#f8f8ff");

      Tags.Tool := Buffer.Create_Tag ("sv_tool");
      Set_Property (Tags.Tool, Family_Property, "Monospace");
      Set_Property (Tags.Tool, Background_Property, "#f4f4f4");

      Tags.User := Buffer.Create_Tag ("sv_user");
      Set_Property (Tags.User, Foreground_Property, "#204080");

      Tags.Error := Buffer.Create_Tag ("sv_error");
      Set_Property (Tags.Error, Foreground_Property, "#cc3333");

      Tags.Dim := Buffer.Create_Tag ("sv_dim");
      Set_Property (Tags.Dim, Foreground_Property, "#909090");

      return Tags;
   end Make_Tags;

   --  ── Tool result collector ─────────────────────────────────────────────
   --
   --  Pass 1 scans the file to collect tool results so we can display
   --  them inline next to tool calls.

   type Tool_Result is record
      Id       : Unbounded_String;
      Text     : Unbounded_String;
      Is_Err   : Boolean := False;
      Is_Image : Boolean := False;
   end record;

   package TR_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Tool_Result);

   function Collect_Tool_Results (Path : in String) return TR_Vectors.Vector is
      Results : TR_Vectors.Vector;
      File    : Ada.Text_IO.File_Type;
      Line    : String (1 .. 65536);
      Last    : Natural;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         Ada.Text_IO.Get_Line (File, Line, Last);
         begin
            declare
               Root : constant GNATCOLL.JSON.JSON_Value :=
                 GNATCOLL.JSON.Read (Line (1 .. Last));
               Msg  : GNATCOLL.JSON.JSON_Value;
            begin
               if Root.Kind = GNATCOLL.JSON.JSON_Object_Type then
                  if Root.Has_Field ("type")
                    and then Root.Get ("type").Kind =
                      GNATCOLL.JSON.JSON_String_Type
                    and then String'(Root.Get ("type").Get) = "message"
                    and then Root.Has_Field ("message")
                  then
                     Msg := Root.Get ("message");
                  else
                     Msg := Root;
                  end if;
                  if Get_Str (Msg, "role") = "toolResult" then
                     declare
                        TC_Id  : constant String := Get_Str (Msg, "toolCallId");
                        Is_Err : constant Boolean := Get_Bool (Msg, "isError");
                        Text   : Unbounded_String;
                        Is_Img : Boolean := False;
                     begin
                        if Msg.Has_Field ("content")
                          and then Msg.Get ("content").Kind =
                            GNATCOLL.JSON.JSON_Array_Type
                        then
                           declare
                              Arr : constant GNATCOLL.JSON.JSON_Array :=
                                Msg.Get ("content");
                           begin
                              for I in 1 .. GNATCOLL.JSON.Length (Arr) loop
                                 declare
                                    B : constant GNATCOLL.JSON.JSON_Value :=
                                      GNATCOLL.JSON.Get (Arr, I);
                                    BT : constant String := Get_Str (B, "type");
                                 begin
                                    if BT = "text"
                                      and then B.Has_Field ("text")
                                    then
                                       Append (Text, Get_Str (B, "text"));
                                    elsif BT = "image"
                                      and then B.Has_Field ("source")
                                    then
                                       --  Anthropic-style image block.
                                       declare
                                          Src : constant GNATCOLL.JSON.JSON_Value
                                            := B.Get ("source");
                                       begin
                                          if Src.Has_Field ("data") then
                                             Text := To_Unbounded_String
                                               (Get_Str (Src, "data"));
                                             Is_Img := True;
                                          end if;
                                       end;
                                    end if;
                                 end;
                              end loop;
                           end;
                        end if;
                        Results.Append
                          ((Id       => To_Unbounded_String (TC_Id),
                            Text     => Text,
                            Is_Err   => Is_Err,
                            Is_Image => Is_Img));
                     end;
                  end if;
               end if;
            end;
         exception
            when others => null;
         end;
      end loop;
      Ada.Text_IO.Close (File);
      return Results;
   exception
      when others => return Results;
   end Collect_Tool_Results;

   function Find_Result
     (Results : in TR_Vectors.Vector;
      Id      : in String) return Tool_Result
   is
   begin
      for R of Results loop
         if To_String (R.Id) = Id then
            return R;
         end if;
      end loop;
      return (Id       => Null_Unbounded_String,
              Text     => Null_Unbounded_String,
              Is_Err   => False,
              Is_Image => False);
   end Find_Result;

   --  ── Tool call button closure map ──────────────────────────────────────
   --
   --  When On_Tool_Click is non-null, each tool call GtkButton stores its
   --  closure data here, keyed by the button's underlying GObject address.
   --  The map is cleared at the start of every Render_Session call so that
   --  stale entries from previous renders do not accumulate.

   type Tool_Closure is record
      Tool_Name    : Unbounded_String;
      Arguments    : Unbounded_String;
      Result_Text  : Unbounded_String;
      Is_Image     : Boolean         := False;
      Status       : Tool_End_Status := Success;
      Turn_Index   : Positive        := 1;
      Call_In_Turn : Positive        := 1;
      Session      : Coyote_SQC.Data_Model.Session_Record;
      Callback     : Tool_Click_Callback := null;
   end record;

   function Address_Hash
     (Key : in System.Address) return Ada.Containers.Hash_Type
   is
      use System.Storage_Elements;
   begin
      return Ada.Containers.Hash_Type'Mod (To_Integer (Key));
   end Address_Hash;

   package Closure_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type        => System.Address,
      Element_Type    => Tool_Closure,
      Hash            => Address_Hash,
      Equivalent_Keys => System."=");

   Button_Map : Closure_Maps.Map;

   --  Invoked when the user clicks any tool call button in the replay view.
   procedure On_Tool_Button_Clicked
     (Button : access Gtk.Button.Gtk_Button_Record'Class)
   is
      Key    : constant System.Address :=
        Glib.Object.Get_Object (Button);
      Cursor : constant Closure_Maps.Cursor :=
        Button_Map.Find (Key);
   begin
      if Closure_Maps.Has_Element (Cursor) then
         declare
            C : constant Tool_Closure := Closure_Maps.Element (Cursor);
         begin
            if C.Callback /= null then
               C.Callback
                 (Tool_Name    => To_String (C.Tool_Name),
                  Arguments    => To_String (C.Arguments),
                  Result_Text  => To_String (C.Result_Text),
                  Is_Image     => C.Is_Image,
                  Status       => C.Status,
                  Turn_Index   => C.Turn_Index,
                  Call_In_Turn => C.Call_In_Turn,
                  Session      => C.Session);
            end if;
         end;
      end if;
   end On_Tool_Button_Clicked;

   --  ── Rendering pass ────────────────────────────────────────────────────

   procedure Render_Pass
     (Path     : in     String;
      Buffer   : not null access Gtk.Text_Buffer.Gtk_Text_Buffer_Record'Class;
      View     : not null access Gtk.Text_View.Gtk_Text_View_Record'Class;
      Tags     : in     Tag_Set;
      Results  : in     TR_Vectors.Vector;
      Callback : in     Tool_Click_Callback;
      Session  : in     Coyote_SQC.Data_Model.Session_Record)
   is
      File : Ada.Text_IO.File_Type;
      Line : String (1 .. 65536);
      Last : Natural;

      Turn_No : Natural := 0;

      procedure Render_User_Msg (Msg : in GNATCOLL.JSON.JSON_Value) is
      begin
         if Msg.Has_Field ("content") then
            declare
               Content_V : constant GNATCOLL.JSON.JSON_Value :=
                 Msg.Get ("content");
            begin
               if Content_V.Kind = GNATCOLL.JSON.JSON_String_Type then
                  Append_Tagged (Buffer, UC_TRI_R & " ", Tags.User);
                  Append_Text (Buffer,
                    String'(Content_V.Get) & ASCII.LF & ASCII.LF);
               elsif Content_V.Kind = GNATCOLL.JSON.JSON_Array_Type then
                  declare
                     Arr : constant GNATCOLL.JSON.JSON_Array :=
                       GNATCOLL.JSON.JSON_Array'(Content_V.Get);
                  begin
                     for I in 1 .. GNATCOLL.JSON.Length (Arr) loop
                        declare
                           B : constant GNATCOLL.JSON.JSON_Value :=
                             GNATCOLL.JSON.Get (Arr, I);
                        begin
                           if Get_Str (B, "type") = "text"
                             and then B.Has_Field ("text")
                           then
                              Append_Tagged (Buffer, UC_TRI_R & " ", Tags.User);
                              Append_Text
                                (Buffer, Get_Str (B, "text")
                                 & ASCII.LF & ASCII.LF);
                           end if;
                        end;
                     end loop;
                  end;
               end if;
            end;
         end if;
      end Render_User_Msg;

      procedure Render_Assistant_Msg (Msg : in GNATCOLL.JSON.JSON_Value) is
         Call_In_Turn : Natural := 0;
      begin
         Turn_No := Turn_No + 1;
         Append_Tagged (Buffer, "Turn " & Turn_No'Image & ASCII.LF,
                        Tags.Dim);

         if not Msg.Has_Field ("content") then
            return;
         end if;
         if Msg.Get ("content").Kind /= GNATCOLL.JSON.JSON_Array_Type then
            return;
         end if;

         declare
            Arr : constant GNATCOLL.JSON.JSON_Array := Msg.Get ("content");
         begin
            for I in 1 .. GNATCOLL.JSON.Length (Arr) loop
               declare
                  B    : constant GNATCOLL.JSON.JSON_Value :=
                    GNATCOLL.JSON.Get (Arr, I);
                  Kind : constant String := Get_Str (B, "type");
               begin
                  if Kind = "thinking" and then B.Has_Field ("thinking") then
                     Append_Tagged
                       (Buffer,
                        "[ thinking ]" & ASCII.LF
                        & Get_Str (B, "thinking") & ASCII.LF & ASCII.LF,
                        Tags.Thinking);

                  elsif Kind = "text" and then B.Has_Field ("text") then
                     declare
                        MD   : constant String := Get_Str (B, "text");
                        Mark : constant String :=
                          Coyote_Renderer.Markup.To_Pango_Markup (MD);
                     begin
                        Append_Markup (Buffer, Mark & ASCII.LF);
                     end;

                  elsif Kind = "toolCall" then
                     declare
                        TC_Id   : constant String := Get_Str (B, "id");
                        TC_Name : constant String := Get_Str (B, "name");
                        TC_Args : constant String := Get_Str (B, "arguments");
                        Res     : constant Tool_Result :=
                          Find_Result (Results, TC_Id);
                        Status  : constant Tool_End_Status :=
                          (if Res.Is_Err then Error else Success);
                     begin
                        Call_In_Turn := Call_In_Turn + 1;

                        if Callback /= null then
                           --  Embed a clickable GtkButton widget.
                           declare
                              use Gtk.Button;
                              use Gtk.Text_Child_Anchor;
                              Anchor : Gtk.Text_Child_Anchor.Gtk_Text_Child_Anchor;
                              Btn    : Gtk.Button.Gtk_Button;
                              Iter   : Gtk.Text_Iter.Gtk_Text_Iter;
                           begin
                              Buffer.Get_End_Iter (Iter);
                              Anchor := Buffer.Create_Child_Anchor (Iter);
                              Gtk.Button.Gtk_New
                                (Btn, UC_GEAR & " " & TC_Name);
                              View.Add_Child_At_Anchor (Btn, Anchor);
                              Btn.Show;
                              --  Register closure keyed by GObject address.
                              Button_Map.Insert
                                (Glib.Object.Get_Object (Btn),
                                 (Tool_Name    => To_Unbounded_String
                                                    (TC_Name),
                                  Arguments    => To_Unbounded_String
                                                    (TC_Args),
                                  Result_Text  => Res.Text,
                                  Is_Image     => Res.Is_Image,
                                  Status       => Status,
                                  Turn_Index   => Turn_No,
                                  Call_In_Turn => Call_In_Turn,
                                  Session      => Session,
                                  Callback     => Callback));
                              Btn.On_Clicked
                                (On_Tool_Button_Clicked'Access);
                              Append_Text (Buffer, "" & ASCII.LF);
                           end;
                        else
                           --  Non-interactive plain-text fallback.
                           Append_Tagged
                             (Buffer,
                              UC_GEAR & " " & TC_Name & ASCII.LF
                              & (if TC_Args'Length > 0
                                 then TC_Args & ASCII.LF
                                 else ""),
                              Tags.Tool);
                           if To_String (Res.Id) /= "" then
                              if Res.Is_Err then
                                 Append_Tagged
                                   (Buffer,
                                    UC_CROSS & " "
                                    & To_String (Res.Text) & ASCII.LF,
                                    Tags.Error);
                              else
                                 Append_Tagged
                                   (Buffer,
                                    UC_CHECK & " done" & ASCII.LF,
                                    Tags.Dim);
                              end if;
                           end if;
                           Append_Text (Buffer, "" & ASCII.LF);
                        end if;
                     end;
                  end if;
               end;
            end loop;
         end;
         Append_Text (Buffer, "" & ASCII.LF);
      end Render_Assistant_Msg;

   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         Ada.Text_IO.Get_Line (File, Line, Last);
         begin
            declare
               Root : constant GNATCOLL.JSON.JSON_Value :=
                 GNATCOLL.JSON.Read (Line (1 .. Last));
               Msg  : GNATCOLL.JSON.JSON_Value;
            begin
               if Root.Kind = GNATCOLL.JSON.JSON_Object_Type then
                  if Root.Has_Field ("type")
                    and then Root.Get ("type").Kind =
                      GNATCOLL.JSON.JSON_String_Type
                  then
                     declare
                        T : constant String :=
                          String'(Root.Get ("type").Get);
                     begin
                        if T = "message" and then Root.Has_Field ("message") then
                           Msg := Root.Get ("message");
                        elsif T = "model_change" then
                           Append_Tagged
                             (Buffer,
                              "[Model: "
                              & Get_Str (Root, "provider") & "/"
                              & Get_Str (Root, "modelId") & "]"
                              & ASCII.LF,
                              Tags.Dim);
                           goto Next_Line;
                        else
                           goto Next_Line;
                        end if;
                     end;
                  else
                     --  Legacy: bare message object.
                     Msg := Root;
                  end if;

                  declare
                     Role : constant String := Get_Str (Msg, "role");
                  begin
                     if    Role = "user"      then Render_User_Msg (Msg);
                     elsif Role = "assistant" then Render_Assistant_Msg (Msg);
                     end if;
                  end;
               end if;
            end;
         exception
            when others => null;
         end;
         <<Next_Line>>
      end loop;
      Ada.Text_IO.Close (File);
   exception
      when others => null;
   end Render_Pass;

   --  ── Public interface ──────────────────────────────────────────────────

   function Find_Session_File
     (Session_Id       : in String;
      Source_Directory : in String) return String
   is
      use Ada.Directories;
      Home  : constant String := GNAT.OS_Lib.Getenv ("HOME").all;
      Slug  : constant String :=
        Coyote_SQC.Session_Parser.Encode_Cwd (Source_Directory);
      Dir   : constant String :=
        Home & "/.coyote/sessions/" & Slug & "/";
      Path  : constant String := Dir & Session_Id & ".jsonl";
   begin
      if Exists (Path) then
         return Path;
      end if;
      --  Search all session directories if source-dir slug doesn't match.
      declare
         Search : Search_Type;
         Dirent : Directory_Entry_Type;
         Base   : constant String := Home & "/.coyote/sessions/";
      begin
         if not Exists (Base) then
            return "";
         end if;
         Start_Search (Search, Base, "",
                       (Directory => True, others => False));
         while More_Entries (Search) loop
            Get_Next_Entry (Search, Dirent);
            declare
               Candidate : constant String :=
                 Full_Name (Dirent) & "/" & Session_Id & ".jsonl";
            begin
               if Exists (Candidate) then
                  End_Search (Search);
                  return Candidate;
               end if;
            end;
         end loop;
         End_Search (Search);
      end;
      return "";
   exception
      when others => return "";
   end Find_Session_File;

   procedure Render_Session
     (Session       : in     Coyote_SQC.Data_Model.Session_Record;
      Buffer        : not null access Gtk.Text_Buffer.Gtk_Text_Buffer_Record'Class;
      View          : not null access Gtk.Text_View.Gtk_Text_View_Record'Class;
      On_Tool_Click : in     Tool_Click_Callback := null)
   is
      use Ada.Strings.Unbounded;
      Path : constant String :=
        Find_Session_File
          (To_String (Session.Session_Id),
           To_String (Session.Source_Directory));
   begin
      --  Clear stale button closures from any previous render.
      Button_Map.Clear;

      Buffer.Set_Text ("");

      if Path = "" then
         Buffer.Set_Text ("[ Session file not found ]");
         return;
      end if;

      declare
         Tags    : constant Tag_Set    := Make_Tags (Buffer);
         Results : constant TR_Vectors.Vector :=
           Collect_Tool_Results (Path);
      begin
         Render_Pass (Path, Buffer, View, Tags, Results, On_Tool_Click,
                      Session);
      end;
   exception
      when E : others =>
         Buffer.Set_Text
           ("[ Error rendering session: "
            & Ada.Exceptions.Exception_Message (E) & " ]");
   end Render_Session;

end Coyote_Renderer.Session_View;
