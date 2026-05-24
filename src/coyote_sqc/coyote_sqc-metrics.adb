--  Coyote_SQC.Metrics body.
--
--  Project: coyote

package body Coyote_SQC.Metrics is

   use Coyote_SQC.Data_Model;

   function Compute
     (Session : Session_Record) return Session_Metrics_Record
   is
      M : Session_Metrics_Record;
   begin
      M.Session_Id := Session.Session_Id;
      M.Total_Input_Tokens  := Session.Total_Input_Tokens;
      M.Total_Output_Tokens := Session.Total_Output_Tokens;
      M.Total_Cache_Read_Tokens  := Session.Total_Cache_Read_Tokens;
      M.Total_Cache_Write_Tokens := Session.Total_Cache_Write_Tokens;
      M.N_Turns    := (if Session.Turns.Is_Empty then 1
                       else Positive (Session.Turns.Length));

      for Turn of Session.Turns loop
         --  Per-turn output and input token vectors.
         M.Per_Turn_Output_Tokens.Append (Turn.Output_Tokens);
         M.Per_Turn_Input_Tokens.Append  (Turn.Input_Tokens);
         M.Total_Thinking_Tokens :=
           M.Total_Thinking_Tokens + Turn.Thinking_Tokens;

         --  Tool calls: sum estimated per-TC token costs, count calls and
         --  failures, and accumulate for tool-call turns only.
         declare
            Tool_Sum : Natural := 0;
         begin
            for TC of Turn.Tool_Calls loop
               Tool_Sum :=
                 Tool_Sum + TC.Input_Tokens + TC.Output_Tokens;
               M.Total_Tool_Call_Input_Tokens  :=
                 M.Total_Tool_Call_Input_Tokens + TC.Input_Tokens;
               M.Total_Tool_Call_Result_Tokens :=
                 M.Total_Tool_Call_Result_Tokens + TC.Output_Tokens;
               M.N_Tool_Calls := M.N_Tool_Calls + 1;
               if TC.Failed then
                  M.N_Failed_Tool_Calls := M.N_Failed_Tool_Calls + 1;
               end if;
            end loop;

            if not Turn.Tool_Calls.Is_Empty then
               M.N_Tool_Call_Turns           := M.N_Tool_Call_Turns + 1;
               M.N_Tool_Call_Turns_For_Chart :=
                 M.N_Tool_Call_Turns_For_Chart + 1;
               M.Per_Turn_Tool_Tokens.Append (Tool_Sum);
            end if;
         end;

         --  Thinking.
         if Turn.Thinking_Enabled then
            M.Any_Thinking                 := True;
            M.N_Thinking_Turns_For_Chart   := M.N_Thinking_Turns_For_Chart + 1;
            M.Per_Turn_Thinking_Tokens.Append (Turn.Thinking_Tokens);
         end if;

         if Turn.Thinking_Tokens > 0 then
            M.N_Thinking_Turns := M.N_Thinking_Turns + 1;
         end if;
      end loop;

      return M;
   end Compute;

end Coyote_SQC.Metrics;
