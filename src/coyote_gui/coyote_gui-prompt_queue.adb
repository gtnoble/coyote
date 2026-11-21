--  Coyote_GUI.Prompt_Queue body.
--
--  Project: coyote

with LLM.User_Images;

package body Coyote_GUI.Prompt_Queue is

   protected body Queue is

      procedure Enqueue (I : Item; Accepted : out Boolean) is
         Tail : Natural;
         Bytes : constant Natural := (if I.Kind = Canvas_Prompt then
           LLM.User_Images.Byte_Count (I.Images) else 0);
      begin
         Accepted := False;
         if not Stopped and then Count < Max_Depth and then
           Bytes <= LLM.User_Images.Max_Turn - Image_Bytes
         then
            Image_Bytes := Image_Bytes + Bytes;
            Tail         := (Head - 1 + Count) mod Max_Depth + 1;
            Items (Tail) := I;
            Count        := Count + 1;
            Accepted     := True;
         end if;
      end Enqueue;

      procedure Enqueue (I : Item) is
         Accepted : Boolean;
      begin
         Enqueue (I, Accepted);
      end Enqueue;

      entry Dequeue (I : out Item) when Count > 0 or else Stopped is
      begin
         if Count > 0 then
            I := Items (Head);
            if I.Kind = Canvas_Prompt then
               Image_Bytes := Image_Bytes - LLM.User_Images.Byte_Count (I.Images);
            end if;
            Items (Head) := (Kind => Shutdown_Item, others => <>);
            Head  := Head mod Max_Depth + 1;
            Count := Count - 1;
         else
            I :=
              (Kind            => Shutdown_Item,
               Target_Agent_Id => Ada.Strings.Unbounded.Null_Unbounded_String);
         end if;
      end Dequeue;

      procedure Shutdown is
      begin
         Stopped := True;
      end Shutdown;

   end Queue;

end Coyote_GUI.Prompt_Queue;
