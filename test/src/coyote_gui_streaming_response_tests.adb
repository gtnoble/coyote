--  Coyote_GUI_Streaming_Response_Tests body.
--
--  Project: coyote

with Ada.Containers.Vectors;
with Ada.Environment_Variables;
with Ada.Real_Time;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with AUnit.Assertions;
with AUnit.Test_Caller;
with Coyote_GUI.Streaming_Response.Testing;
with Glib;
with Gtk.Box;
with Gtk.Enums;
with Gtk.Grid;
with Gtk.Main;
with Gtk.Style_Context;
with Gtk.Text_View;
with Gtk.Text_Buffer;
with Pango.Font;
with Coyote_GUI.Math_Element;

package body Coyote_GUI_Streaming_Response_Tests is

   use AUnit.Assertions;
   use type Glib.Gint;
   use type Gtk.Box.Gtk_Box;
   use type Ada.Real_Time.Time;
   use type Ada.Real_Time.Time_Span;
   use type Gtk.Grid.Gtk_Grid;
   use type Gtk.Text_Buffer.Gtk_Text_Buffer;
   use type Gtk.Text_View.Gtk_Text_View;
   use type Coyote_GUI.Math_Element.Instance_Access;
   use type Coyote_GUI.Streaming_Response.Handle;
   package R renames Coyote_GUI.Streaming_Response;
   package RT renames Coyote_GUI.Streaming_Response.Testing;

   function Make_Source (Count : Positive) return String is
      Result : Unbounded_String;
   begin
      for Position in 1 .. Count loop
         Append (Result, "<p>token " & Natural'Image (Position)
                 & " <strong>value</strong></p>");
         if Position mod 7 = 0 then
            Append (Result, "<table><row><cell>x</cell></row></table>");
         end if;
      end loop;
      return To_String (Result);
   end Make_Source;

   function Next_Random (State : in out Natural) return Natural is
   begin
      State := (State * 1_103 + 37) mod 32_771;
      return State;
   end Next_Random;

   procedure Append_Chunks
     (Response : in out R.Handle; Source : String; Mode : Natural) is
      Position : Natural := Source'First;
      State : Natural := 19;
      Width : Natural;
   begin
      while Position <= Source'Last loop
         if Mode = 1 then
            Width := 1;
         elsif Mode = 2 then
            Width := 9;
         else
            Width := 1 + Next_Random (State) mod 17;
         end if;
         Width := Natural'Min (Width, Source'Last - Position + 1);
         R.Append (Response, Source (Position .. Position + Width - 1));
         Position := Position + Width;
      end loop;
   end Append_Chunks;

   function Elapsed
     (Start, Stop : Ada.Real_Time.Time) return Long_Float is
   begin
      return Long_Float (Ada.Real_Time.To_Duration (Stop - Start));
   end Elapsed;

   function Timed_Response
     (T : in out Test; Source : String; Repetitions : Positive)
      return Long_Float is
      Total : Long_Float := 0.0;
   begin
      for Repeat in 1 .. Repetitions loop
         declare
            Start : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
            Stop : Ada.Real_Time.Time;
         begin
            R.Begin_Response (T.Response, T.Host.all'Access);
            R.Append (T.Response, Source);
            R.Finish (T.Response);
            Stop := Ada.Real_Time.Clock;
            Total := Total + Elapsed (Start, Stop);
         end;
      end loop;
      return Total / Long_Float (Repetitions);
   end Timed_Response;

   function Display_Available return Boolean is
   begin
      return Ada.Environment_Variables.Exists ("DISPLAY")
        or else Ada.Environment_Variables.Exists ("WAYLAND_DISPLAY");
   exception
      when others =>
         return False;
   end Display_Available;

   overriding procedure Set_Up (T : in out Test) is
   begin
      if Display_Available then
         Gtk.Main.Init;
         T.Display_Available := True;
         Gtk.Window.Gtk_New (T.Parent, Gtk.Enums.Window_Toplevel);
         Gtk.Box.Gtk_New_Vbox (T.Host, Homogeneous => False, Spacing => 0);
         T.Parent.Add (T.Host);
         T.Response := R.New_Handle;
      end if;
   end Set_Up;

   overriding procedure Tear_Down (T : in out Test) is
   begin
      if T.Display_Available then
         T.Response.Reset;
         T.Parent.Destroy;
         T.Parent := null;
      end if;
   end Tear_Down;

   procedure Test_Empty_Lifecycle_Operations_Are_No_Ops (T : in out Test) is
      Empty  : R.Handle;
      Empty2 : R.Handle;
   begin
      if not T.Display_Available then
         return;
      end if;
      R.Begin_Response (Empty, T.Host.all'Access);
      R.Append (Empty, "ignored");
      R.Finish (Empty);
      R.Discard (Empty);
      declare
         Empty_Font : Pango.Font.Pango_Font_Description :=
           Pango.Font.From_String ("sans 12");
      begin
         R.Set_Font (Empty, Empty_Font, Math_Scale => 2.0);
         Pango.Font.Free (Empty_Font);
      end;
      Empty.Reset;
      Assert (Empty.Is_Empty, "empty lifecycle operations remain no-ops");
      Assert (Empty = Empty2, "empty handles compare equal");
      Assert (R.Section (Empty) = null, "empty section accessor is null");
      Assert (R.Active_Buffer (Empty) = null,
              "empty buffer accessor is null");
      Assert (R.Active_View (Empty) = null, "empty view accessor is null");
      Assert (R.Response_Box (Empty) = null,
              "empty response accessor is null");
   end Test_Empty_Lifecycle_Operations_Are_No_Ops;

   procedure Test_Begin_Append_Finish_Is_Idempotent (T : in out Test) is
   begin
      if not T.Display_Available then
         return;
      end if;
      R.Begin_Response (T.Response, T.Host.all'Access);
      R.Append (T.Response, "<p>owner response</p>");
      Assert (RT.Is_Open (T.Response), "owner is open while streaming");
      Assert (Ada.Strings.Fixed.Index (RT.Presented_Text (T.Response),
                                       "owner response") > 0,
              "owner exposes live content");
      R.Finish (T.Response);
      Assert (RT.Is_Finished (T.Response), "owner is finished");
      Assert (R.Response_Box (T.Response) /= null,
              "owner retains completed response root");
      R.Finish (T.Response);
      Assert (RT.Text_View_Count (T.Response) > 0,
              "duplicate finish does not remove completed content");
   end Test_Begin_Append_Finish_Is_Idempotent;

   procedure Test_Empty_Finish_Closes_Owner (T : in out Test) is
   begin
      if not T.Display_Available then
         return;
      end if;
      R.Begin_Response (T.Response, T.Host.all'Access);
      R.Finish (T.Response);
      Assert (not RT.Is_Open (T.Response),
              "empty finish closes the owner");
      Assert (RT.Is_Finished (T.Response),
              "empty finish records completion");
      R.Finish (T.Response);
   end Test_Empty_Finish_Closes_Owner;

   procedure Test_Begin_After_Finish_Reuses_Owner (T : in out Test) is
   begin
      if not T.Display_Available then
         return;
      end if;
      R.Begin_Response (T.Response, T.Host.all'Access);
      R.Append (T.Response, "first response");
      R.Finish (T.Response);
      R.Begin_Response (T.Response, T.Host.all'Access);
      Assert (RT.Is_Open (T.Response),
              "begin after finish reopens the owner");
      Assert (not RT.Is_Finished (T.Response),
              "begin after finish clears completion");
      R.Append (T.Response, "second response");
      R.Finish (T.Response);
      Assert (Ada.Strings.Fixed.Index (RT.Source (T.Response),
                                       "second response") > 0,
              "reused owner contains the new source");
      Assert (Ada.Strings.Fixed.Index (RT.Source (T.Response),
                                       "first response") = 0,
              "reused owner removes the previous source");
      Assert (Ada.Strings.Fixed.Index (RT.Presented_Text (T.Response),
                                       "first response") = 0,
              "reused owner removes the previous presented text");
   end Test_Begin_After_Finish_Reuses_Owner;

   procedure Test_Discard_Releases_Transaction (T : in out Test) is
   begin
      if not T.Display_Available then
         return;
      end if;
      R.Begin_Response (T.Response, T.Host.all'Access);
      R.Append (T.Response, "<p>discarded</p>");
      R.Discard (T.Response);
      Assert (not RT.Is_Open (T.Response), "discard closes owner");
      Assert (not RT.Is_Finished (T.Response), "discard resets completion");
      Assert (R.Section (T.Response) = null,
              "discard removes response section");
      R.Discard (T.Response);
   end Test_Discard_Releases_Transaction;

   procedure Test_Clear_While_Focused_Is_Safe (T : in out Test) is
      View : Gtk.Text_View.Gtk_Text_View;
   begin
      if not T.Display_Available then
         return;
      end if;
      R.Begin_Response (T.Response, T.Host.all'Access);
      View := R.Active_View (T.Response);
      View.Grab_Focus;
      R.Append (T.Response, "focused response");
      R.Discard (T.Response);
      Assert (R.Section (T.Response) = null,
              "discard removes the focused response section");
      T.Response.Reset;
      Assert (T.Response.Is_Empty,
              "release clears the owner handle after focused cleanup");
      T.Response := R.New_Handle;
   end Test_Clear_While_Focused_Is_Safe;

   procedure Test_Font_Applies_Before_During_And_After (T : in out Test) is
      Before : Pango.Font.Pango_Font_Description :=
        Pango.Font.From_String ("sans 17");
      During : Pango.Font.Pango_Font_Description :=
        Pango.Font.From_String ("sans 21");
      View : Gtk.Text_View.Gtk_Text_View;
   begin
      if not T.Display_Available then
         Pango.Font.Free (Before);
         Pango.Font.Free (During);
         return;
      end if;
      R.Set_Font (T.Response, Before);
      R.Begin_Response (T.Response, T.Host.all'Access);
      View := R.Active_View (T.Response);
      Assert
        (Pango.Font.Get_Size
           (Gtk.Style_Context.Get_Style_Context (View).Get_Font
              (Gtk.Enums.Gtk_State_Flag_Normal)) = Pango.Font.Get_Size (Before),
         "font set before begin reaches live view");
      R.Set_Font (T.Response, During);
      Assert
        (Pango.Font.Get_Size
           (Gtk.Style_Context.Get_Style_Context (View).Get_Font
              (Gtk.Enums.Gtk_State_Flag_Normal)) = Pango.Font.Get_Size (During),
         "font set during streaming updates the live view");
      R.Append (T.Response, "<p>font</p>");
      R.Finish (T.Response);
      Assert
        (Pango.Font.Get_Size
           (Gtk.Style_Context.Get_Style_Context
              (R.Active_View (T.Response)).Get_Font
                (Gtk.Enums.Gtk_State_Flag_Normal)) = Pango.Font.Get_Size (During),
         "font remains applied after Finish");
      Pango.Font.Free (Before);
      Pango.Font.Free (During);
   end Test_Font_Applies_Before_During_And_After;

   procedure Test_Malformed_Source_Remains_Visible (T : in out Test) is
      Source : constant String := "<p>malformed <strong>source</p>";
   begin
      if not T.Display_Available then
         return;
      end if;
      R.Begin_Response (T.Response, T.Host.all'Access);
      R.Append (T.Response, Source);
      R.Finish (T.Response);
      Assert (Ada.Strings.Fixed.Index (RT.Source (T.Response), "malformed") > 0,
              "owner retains malformed source");
      Assert (RT.Text_View_Count (T.Response) > 0,
              "owner renders malformed source visibly");
   end Test_Malformed_Source_Remains_Visible;

   procedure Test_Split_Table_Promotes_Only_At_Close (T : in out Test) is
   begin
      if not T.Display_Available then
         return;
      end if;
      R.Begin_Response (T.Response, T.Host.all'Access);
      R.Append (T.Response, "<table><row><cell>x</cell>");
      Assert (RT.Table_Count (T.Response) = 0,
              "table cell close cannot promote an incomplete table");
      R.Append (T.Response, "</row>");
      Assert (RT.Table_Count (T.Response) = 0,
              "table row close cannot promote an incomplete table");
      R.Append (T.Response, "</table>");
      Assert (RT.Table_Count (T.Response) = 1,
              "table promotes exactly at its root close");
      R.Finish (T.Response);
      Assert (RT.Table_Count (T.Response) = 1,
              "Finish does not replace the committed table");
   end Test_Split_Table_Promotes_Only_At_Close;

   procedure Test_Split_Math_Promotes_Only_At_Close (T : in out Test) is
      Prefix : constant String :=
        "<math xmlns=""http://www.w3.org/1998/Math/MathML"">";
   begin
      if not T.Display_Available then
         return;
      end if;
      R.Begin_Response (T.Response, T.Host.all'Access);
      R.Append (T.Response, Prefix & "<mi>");
      Assert (RT.Math_Element_Count (T.Response) = 0,
              "partial MathML remains provisional");
      R.Append (T.Response, "x</mi></math>");
      Assert (RT.Math_Element_Count (T.Response) = 1,
              "MathML promotes exactly at its root close");
      R.Finish (T.Response);
      Assert (RT.Math_Element_Count (T.Response) = 1,
              "Finish does not replace committed MathML");
   end Test_Split_Math_Promotes_Only_At_Close;

   procedure Test_Native_Payload_Identity_Survives_Later_Mutation
     (T : in out Test)
   is
      Table_Source : constant String :=
        "<table><row><cell>x</cell></row></table>";
      Math_Source : constant String :=
        "<math xmlns=""http://www.w3.org/1998/Math/MathML"">"
        & "<mi>y</mi></math>";
      Table_Before : Gtk.Grid.Gtk_Grid;
      Math_Before : Coyote_GUI.Math_Element.Instance_Access;
      Text_Before : Gtk.Text_View.Gtk_Text_View;
      Response_Before : Gtk.Box.Gtk_Box;
   begin
      if not T.Display_Available then
         return;
      end if;
      R.Begin_Response (T.Response, T.Host.all'Access);
      R.Append
        (T.Response, Table_Source & Math_Source & "<p>later</p>");
      Table_Before := RT.Table_Grid_At (T.Response, 1);
      Math_Before := RT.Math_Element_At (T.Response, 1);
      Text_Before := RT.Text_View_At (T.Response, 1);
      Response_Before := R.Response_Box (T.Response);
      R.Append (T.Response, "<p>changed later</p>");
      Assert (RT.Table_Grid_At (T.Response, 1) = Table_Before,
              "later text mutation preserves table grid identity");
      Assert (RT.Math_Element_At (T.Response, 1) = Math_Before,
              "later text mutation preserves MathML identity");
      Assert (RT.Text_View_At (T.Response, 1) = Text_Before,
              "later text mutation preserves existing text view identity");
      Assert (R.Response_Box (T.Response) = Response_Before,
              "append does not replace the response outer");
      R.Finish (T.Response);
      Assert (RT.Table_Grid_At (T.Response, 1) = Table_Before,
              "Finish preserves committed table identity");
      Assert (RT.Math_Element_At (T.Response, 1) = Math_Before,
              "Finish preserves committed MathML identity");
      Assert (R.Response_Box (T.Response) = Response_Before,
              "Finish does not whole-response replace");
   end Test_Native_Payload_Identity_Survives_Later_Mutation;

   procedure Test_Handle_Copy_And_Assignment (T : in out Test) is
      First  : R.Handle;
      Second : R.Handle;
      Third  : R.Handle;
      Before : constant Natural := RT.Live_Owner_Count;
   begin
      if not T.Display_Available then
         return;
      end if;
      First := R.New_Handle;
      Assert (RT.Live_Owner_Count = Before + 1,
              "new handle creates one live owner");
      Second := R.New_Handle;
      Assert (RT.Live_Owner_Count = Before + 2,
              "second handle creates a distinct owner");
      First := Second;
      Assert (RT.Live_Owner_Count = Before + 1,
              "assignment over a nonempty handle releases the old owner");
      Third := Second;
      Assert (RT.Live_Owner_Count = Before + 1,
              "controlled copies share one live owner");
      First := First;
      Assert (RT.Live_Owner_Count = Before + 1,
              "self-assignment preserves the owner");
      Second.Reset;
      Assert (RT.Live_Owner_Count = Before + 1,
              "resetting one copy retains shared owner");
      First.Reset;
      Assert (RT.Live_Owner_Count = Before + 1,
              "assignment copy remains the owner");
      Third.Reset;
      Assert (RT.Live_Owner_Count = Before,
              "last handle reset reclaims the owner");
   end Test_Handle_Copy_And_Assignment;

   procedure Test_Handle_Vector_Delete_And_Clear (T : in out Test) is
      package Handles is new Ada.Containers.Vectors
        (Index_Type => Positive, Element_Type => R.Handle);
      Values : Handles.Vector;
      First  : R.Handle;
      Second : R.Handle;
      Before : Natural;
      procedure Reset_Handle (Value : in out R.Handle) is
      begin
         Value.Reset;
      end Reset_Handle;
   begin
      if not T.Display_Available then
         return;
      end if;
      Before := RT.Live_Owner_Count;

      First := R.New_Handle;
      Values.Append (First);
      First.Reset;
      Assert (RT.Live_Owner_Count = Before + 1,
              "vector append retains its stored owner");
      Values.Update_Element (Values.First_Index, Reset_Handle'Access);
      Values.Clear;
      Assert (RT.Live_Owner_Count = Before,
              "Clear releases its reset stored owner");

      First := R.New_Handle;
      Second := R.New_Handle;
      Values.Append (First);
      First.Reset;
      Values.Replace_Element (Values.First_Index, Second);
      Second.Reset;
      Assert (RT.Live_Owner_Count = Before + 1,
              "Replace_Element releases the displaced owner");
      Values.Update_Element (Values.First_Index, Reset_Handle'Access);
      Values.Clear;
      Assert (RT.Live_Owner_Count = Before,
              "replacement owner can be reset and cleared");

      First := R.New_Handle;
      Values.Append (First);
      First.Reset;
      Values.Update_Element (Values.First_Index, Reset_Handle'Access);
      Values.Delete (Values.First_Index);
      Assert (RT.Live_Owner_Count = Before,
              "Delete releases an explicitly reset stored owner");

      First := R.New_Handle;
      Values.Append (First);
      First.Reset;
      Values.Update_Element (Values.Last_Index, Reset_Handle'Access);
      Values.Delete_Last;
      Assert (RT.Live_Owner_Count = Before,
              "Delete_Last releases an explicitly reset stored owner");

      First := R.New_Handle;
      Values.Append (First);
      First.Reset;
      Values.Update_Element (Values.First_Index, Reset_Handle'Access);
      Values.Clear;
      Assert (RT.Live_Owner_Count = Before,
              "Clear releases an explicitly reset stored owner");
   end Test_Handle_Vector_Delete_And_Clear;

   procedure Test_Handle_Reset_Is_Idempotent (T : in out Test) is
      Value  : R.Handle;
      Before : constant Natural := RT.Live_Owner_Count;
   begin
      if not T.Display_Available then
         return;
      end if;
      Value := R.New_Handle;
      Value.Reset;
      Value.Reset;
      Assert (Value.Is_Empty, "repeated reset leaves an empty handle");
      Assert (RT.Live_Owner_Count = Before,
              "repeated reset does not double-finalize");
   end Test_Handle_Reset_Is_Idempotent;

   procedure Test_Handle_Finalizes_During_Exception_Unwinding
     (T : in out Test)
   is
      Before : constant Natural := RT.Live_Owner_Count;
      Raised : Boolean := False;
   begin
      if not T.Display_Available then
         return;
      end if;
      begin
         declare
            Value : R.Handle := R.New_Handle;
         begin
            Assert (not Value.Is_Empty, "exception fixture owns a handle");
            raise Constraint_Error;
         end;
      exception
         when Constraint_Error =>
            Raised := True;
      end;
      Assert (Raised, "exception fixture raised");
      Assert (RT.Live_Owner_Count = Before,
              "exception unwinding finalizes the handle");
   end Test_Handle_Finalizes_During_Exception_Unwinding;

   procedure Test_Chunking_Preserves_Root_And_Widget_Identity
     (T : in out Test) is
      Source : constant String :=
        "<p>one</p><table><row><cell>x</cell></row></table>"
        & "<math xmlns=""http://www.w3.org/1998/Math/MathML"">"
        & "<mi>y</mi></math><p>three</p>";
      Expected_Text : Unbounded_String;
      Expected_Tables : Natural := 0;
      Expected_Math : Natural := 0;
   begin
      if not T.Display_Available then
         return;
      end if;
      for Mode in 1 .. 3 loop
         R.Begin_Response (T.Response, T.Host.all'Access);
         Append_Chunks (T.Response, Source, Mode);
         declare
            Response_Box : constant Gtk.Box.Gtk_Box :=
              R.Response_Box (T.Response);
            Text_View : constant Gtk.Text_View.Gtk_Text_View :=
              RT.Text_View_At (T.Response, 1);
            Table : constant Gtk.Grid.Gtk_Grid :=
              RT.Table_Grid_At (T.Response, 1);
            Math : constant Coyote_GUI.Math_Element.Instance_Access :=
              RT.Math_Element_At (T.Response, 1);
         begin
            if Mode = 1 then
               Expected_Text := To_Unbounded_String
                 (RT.Presented_Text (T.Response));
               Expected_Tables := RT.Table_Count (T.Response);
               Expected_Math := RT.Math_Element_Count (T.Response);
            else
               Assert (RT.Presented_Text (T.Response) = To_String (Expected_Text),
                       "chunking changes live semantic text");
               Assert (RT.Table_Count (T.Response) = Expected_Tables,
                       "chunking changes native table count");
               Assert (RT.Math_Element_Count (T.Response) = Expected_Math,
                       "chunking changes native math count");
               Assert (R.Response_Box (T.Response) = Response_Box,
                       "chunking replaces response root");
               Assert (RT.Text_View_At (T.Response, 1) = Text_View,
                       "chunking replaces text widget");
               if Expected_Tables > 0 then
                  Assert (RT.Table_Grid_At (T.Response, 1) = Table,
                          "chunking replaces native table widget");
               end if;
               if Expected_Math > 0 then
                  Assert (RT.Math_Element_At (T.Response, 1) = Math,
                          "chunking replaces native math widget");
               end if;
            end if;
            R.Finish (T.Response);
            Assert (R.Response_Box (T.Response) = Response_Box,
                    "Finish replaces response root");
            Assert (RT.Text_View_At (T.Response, 1) = Text_View,
                    "Finish replaces text widget");
            if Expected_Tables > 0 then
               Assert (RT.Table_Grid_At (T.Response, 1) = Table,
                       "Finish replaces native table widget");
            end if;
            if Expected_Math > 0 then
               Assert (RT.Math_Element_At (T.Response, 1) = Math,
                       "Finish replaces native math widget");
            end if;
         end;
         R.Discard (T.Response);
      end loop;
   end Test_Chunking_Preserves_Root_And_Widget_Identity;

   procedure Test_Long_Stream_Widget_Scaling
     (T : in out Test) is
      Small : constant String := Make_Source (80);
      Large : constant String := Make_Source (160);
      Small_Time : Long_Float;
      Large_Time : Long_Float;
      Before : constant Natural := RT.Live_Owner_Count;
   begin
      if not T.Display_Available then
         return;
      end if;
      Small_Time := Timed_Response (T, Small, 3);
      Large_Time := Timed_Response (T, Large, 3);
      Ada.Text_IO.Put_Line
        ("CSM-2 Stage 6 response scaling bytes="
         & Natural'Image (Small'Length) & ","
         & Natural'Image (Large'Length) & " seconds="
         & Long_Float'Image (Small_Time) & ","
         & Long_Float'Image (Large_Time));
      Assert (Large_Time <= Small_Time * 16.0 + 0.01,
              "Streaming_Response scaling is grossly superlinear");
      R.Discard (T.Response);
      Assert (RT.Live_Owner_Count = Before,
              "response scaling leaves no live owner");
   end Test_Long_Stream_Widget_Scaling;

   procedure Test_Repeated_Response_Reset_Has_No_Stale_Roots
     (T : in out Test) is
      Before : Natural;
   begin
      if not T.Display_Available then
         return;
      end if;
      Before := RT.Live_Owner_Count;
      for Repeat in 1 .. 40 loop
         R.Begin_Response (T.Response, T.Host.all'Access);
         R.Append
           (T.Response, "<p>ok</p><table><row><cell>x</cell></row>"
                   & "</table><math xmlns=""http://www.w3.org/1998/Math/MathML"""
                   & ">"
                   & "<mi>z</mi></math><p><strong>bad</p>"
                   );
         R.Finish (T.Response);
         Assert (R.Response_Box (T.Response) /= null,
                 "stress response root is present");
         Assert (RT.Source (T.Response)'Length > 0,
                 "stress response source is retained before clear");
         R.Discard (T.Response);
         Assert (R.Section (T.Response) = null,
                 "discard leaves no stale response section");
         Assert (RT.Live_Owner_Count = Before,
                 "discard does not leak response owners");
      end loop;
   end Test_Repeated_Response_Reset_Has_No_Stale_Roots;

   package Caller is new AUnit.Test_Caller (Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test
        (Caller.Create
           ("streaming response empty lifecycle operations",
            Test_Empty_Lifecycle_Operations_Are_No_Ops'Access));
      Result.Add_Test
        (Caller.Create
           ("streaming response begin append finish",
            Test_Begin_Append_Finish_Is_Idempotent'Access));
      Result.Add_Test
        (Caller.Create
           ("streaming response empty finish",
            Test_Empty_Finish_Closes_Owner'Access));
      Result.Add_Test
        (Caller.Create
           ("streaming response begin after finish",
            Test_Begin_After_Finish_Reuses_Owner'Access));
      Result.Add_Test
        (Caller.Create
           ("streaming response discard",
            Test_Discard_Releases_Transaction'Access));
      Result.Add_Test
        (Caller.Create
           ("streaming response focused cleanup",
            Test_Clear_While_Focused_Is_Safe'Access));
      Result.Add_Test
        (Caller.Create
           ("streaming response font lifecycle",
            Test_Font_Applies_Before_During_And_After'Access));
      Result.Add_Test
        (Caller.Create
           ("streaming response malformed source",
            Test_Malformed_Source_Remains_Visible'Access));
      Result.Add_Test
        (Caller.Create
           ("streaming response split table atomic promotion",
            Test_Split_Table_Promotes_Only_At_Close'Access));
      Result.Add_Test
        (Caller.Create
           ("streaming response split MathML atomic promotion",
            Test_Split_Math_Promotes_Only_At_Close'Access));
      Result.Add_Test
        (Caller.Create
           ("streaming response native payload identity",
            Test_Native_Payload_Identity_Survives_Later_Mutation'Access));
      Result.Add_Test
        (Caller.Create
           ("streaming response handle copy assignment",
            Test_Handle_Copy_And_Assignment'Access));
      Result.Add_Test
        (Caller.Create
           ("streaming response handle vector lifecycle",
            Test_Handle_Vector_Delete_And_Clear'Access));
      Result.Add_Test
        (Caller.Create
           ("streaming response handle repeated reset",
            Test_Handle_Reset_Is_Idempotent'Access));
      Result.Add_Test
        (Caller.Create
           ("streaming response handle exception unwinding",
            Test_Handle_Finalizes_During_Exception_Unwinding'Access));
      Result.Add_Test
        (Caller.Create
           ("streaming response Stage 6 chunking identity",
            Test_Chunking_Preserves_Root_And_Widget_Identity'Access));
      Result.Add_Test
        (Caller.Create
           ("streaming response Stage 6 scaling",
            Test_Long_Stream_Widget_Scaling'Access));
      Result.Add_Test
        (Caller.Create
           ("streaming response Stage 6 reset lifecycle stress",
            Test_Repeated_Response_Reset_Has_No_Stale_Roots'Access));
      return Result;
   end Suite;

end Coyote_GUI_Streaming_Response_Tests;
