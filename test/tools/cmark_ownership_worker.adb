with Coyote_Cmark;
with Ada.Command_Line;
with Ada.Text_IO;
with Interfaces.C;

procedure Cmark_Ownership_Worker is
   use type Interfaces.C.int;

   procedure Probe_Reset with Import, Convention => C,
     External_Name => "cmark_probe_reset";
   function Probe_Node_Frees return Interfaces.C.int with Import,
     Convention => C, External_Name => "cmark_probe_node_frees";
   function Probe_Iter_Frees return Interfaces.C.int with Import,
     Convention => C, External_Name => "cmark_probe_iter_frees";
   function Probe_Last_Free return Interfaces.C.int with Import,
     Convention => C, External_Name => "cmark_probe_last_free";
   function Probe_Free_Sequence return Interfaces.C.int with Import,
     Convention => C, External_Name => "cmark_probe_free_sequence";
   procedure Probe_Fail_Parser with Import, Convention => C,
     External_Name => "cmark_probe_fail_parser";
   procedure Probe_Fail_Iterator with Import, Convention => C,
     External_Name => "cmark_probe_fail_iterator";
   procedure Check (Condition : Boolean; Message : String);

   Failures : Natural := 0;
   Checks   : Natural := 0;

   procedure Check (Condition : Boolean; Message : String) is
   begin
      Checks := Checks + 1;
      if not Condition then
         Ada.Text_IO.Put_Line ("FAIL: " & Message);
         Failures := Failures + 1;
      end if;
   end Check;

   procedure Parse_Into (Owner : in out Coyote_Cmark.Document) is
      Text : constant Interfaces.C.char_array :=
        Interfaces.C.To_C ("owner text", Append_Nul => True);
   begin
      Coyote_Cmark.Parse
        (Owner, Text, 10, Coyote_Cmark.OPT_DEFAULT);
   end Parse_Into;

   procedure Normal_Scope is
      Doc : Coyote_Cmark.Document;
      It  : Coyote_Cmark.Iterator;
   begin
      Parse_Into (Doc);
      Coyote_Cmark.Start (It, Coyote_Cmark.Root (Doc));
      Check (not Coyote_Cmark.Is_Null (Coyote_Cmark.Handle (It)),
        "normal path creates iterator");
   end Normal_Scope;

   procedure Early_Return is
      Doc : Coyote_Cmark.Document;
   begin
      Parse_Into (Doc);
      return;
   end Early_Return;

   procedure Exception_Scope is
      Doc : Coyote_Cmark.Document;
      It  : Coyote_Cmark.Iterator;
   begin
      Parse_Into (Doc);
      Coyote_Cmark.Start (It, Coyote_Cmark.Root (Doc));
      raise Constraint_Error;
   end Exception_Scope;

   procedure Check_Last_Order (Expected : Interfaces.C.int) is
   begin
      Check (Probe_Last_Free = Expected, "free order");
   end Check_Last_Order;

begin
   Ada.Text_IO.Put_Line ("cmark lifecycle qualification");

   declare
      Doc : Coyote_Cmark.Document;
      Failure_Caught : Boolean;
   begin
      Probe_Reset;
      Normal_Scope;
      Check (Probe_Iter_Frees = 1, "normal scope iterator free count");
      Check (Probe_Node_Frees = 1, "normal scope document free count");
      Check_Last_Order (1);
      Check (Probe_Free_Sequence = 21,
        "normal frees iterator before document");

      Probe_Reset;
      Early_Return;
      Check (Probe_Iter_Frees = 0, "early return without iterator");
      Check (Probe_Node_Frees = 1, "early return document free count");
      Check_Last_Order (1);

      Probe_Reset;
      begin
         Exception_Scope;
      exception
         when Constraint_Error => null;
      end;
      Check (Probe_Iter_Frees = 1, "exception iterator free count");
      Check (Probe_Node_Frees = 1, "exception document free count");
      Check_Last_Order (1);
      Check (Probe_Free_Sequence = 21,
        "exception frees iterator before document");

      Probe_Reset;
      Parse_Into (Doc);
      declare
         It : Coyote_Cmark.Iterator;
      begin
         Coyote_Cmark.Start (It, Coyote_Cmark.Root (Doc));
         Coyote_Cmark.Start (It, Coyote_Cmark.Root (Doc));
         Check (Probe_Iter_Frees = 1,
           "iterator replacement frees prior iterator");
      end;
      Check (Probe_Iter_Frees = 2,
        "iterator scope exit releases replacement");
      Parse_Into (Doc);
      Check (Probe_Node_Frees = 1,
        "document replacement frees prior document");
      Check (Probe_Iter_Frees = 2,
        "replacement caller finalizes iterator first");
      Check_Last_Order (1);
      Check (Probe_Free_Sequence = 221,
        "two iterator frees precede replaced document free");
      declare
         It : Coyote_Cmark.Iterator;
      begin
         Coyote_Cmark.Start (It, Coyote_Cmark.Root (Doc));
         Check (not Coyote_Cmark.Is_Null (Coyote_Cmark.Handle (It)),
           "valid root creates iterator before null replacement");
         Coyote_Cmark.Start (It, Coyote_Cmark.Null_Node);
         Check (Coyote_Cmark.Is_Null (Coyote_Cmark.Handle (It)),
           "null root yields null iterator");
         Check (Probe_Iter_Frees = 3,
           "replacing live iterator by null frees prior iterator");
      end;

      Probe_Reset;
      Probe_Fail_Iterator;
      declare
         It : Coyote_Cmark.Iterator;
      begin
         Coyote_Cmark.Start (It, Coyote_Cmark.Root (Doc));
         Check (Coyote_Cmark.Is_Null (Coyote_Cmark.Handle (It)),
           "injected iterator allocation failure returns null");
         Check (Probe_Iter_Frees = 0,
           "failed iterator allocation has no free");
      end;

      Probe_Reset;
      Probe_Fail_Parser;
      Failure_Caught := False;
      begin
         Parse_Into (Doc);
      exception
         when others => Failure_Caught := True;
      end;
      Check (not Failure_Caught,
        "parser allocation failure is null, not exception");
      Check (Coyote_Cmark.Is_Null (Coyote_Cmark.Root (Doc)),
        "parser allocation failure leaves null document");
      Check (Probe_Node_Frees = 1,
        "parse replacement frees previous document");
      Check (Probe_Iter_Frees = 0,
        "parse failure does not free absent iterator");
   end;

   if Failures = 0 then
      Ada.Text_IO.Put_Line
        ("checks passed: " & Natural'Image (Checks) & " assertions");
   else
      Ada.Text_IO.Put_Line
        ("failures=" & Natural'Image (Failures)
         & " of " & Natural'Image (Checks) & " assertions");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Cmark_Ownership_Worker;
