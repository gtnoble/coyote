with Ada.Strings.Unbounded;
with Coyote_SQC.Statistics.JSD;
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
      M.Total_Uncached_Input_Tokens := Session.Total_Uncached_Input_Tokens;
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

      --  Compute consecutive JSD tool-call similarity pairs.
      --  Iterate all tool calls in session order (across turn boundaries),
      --  appending per-argument S_k values for each adjacent pair via
      --  Compute_S_Values.
      declare
         use Ada.Strings.Unbounded;
         Prev_Name : Unbounded_String;
         Prev_Args : Unbounded_String;
         Has_Prev  : Boolean := False;
      begin
         for Turn of Session.Turns loop
            for TC of Turn.Tool_Calls loop
               if Has_Prev then
                  Coyote_SQC.Statistics.JSD.Compute_S_Values
                    (Tool_Name_1 => To_String (Prev_Name),
                     Arguments_1 => To_String (Prev_Args),
                     Tool_Name_2 => To_String (TC.Tool_Name),
                     Arguments_2 => To_String (TC.Arguments),
                     Result      => M.Per_Consecutive_Tool_S);
                  M.N_Consecutive_Tool_Pairs :=
                    M.N_Consecutive_Tool_Pairs + 1;
               end if;
               Prev_Name := TC.Tool_Name;
               Prev_Args := TC.Arguments;
               Has_Prev  := True;
            end loop;
         end loop;
      end;

      --  Sum Per_Consecutive_Tool_S into the session-level scalar.
      for V of M.Per_Consecutive_Tool_S loop
         M.Total_Tool_Call_JSD_S := M.Total_Tool_Call_JSD_S + V;
      end loop;

      return M;
   end Compute;

end Coyote_SQC.Metrics;
