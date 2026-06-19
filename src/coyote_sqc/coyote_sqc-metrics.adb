--  Coyote_SQC.Metrics body.
--
--  Project: coyote

with Ada.Strings.Unbounded;
with Coyote_SQC.Statistics.JSD;
with Coyote_SQC.Statistics.MI;

package body Coyote_SQC.Metrics is

   use Coyote_SQC.Data_Model;

   function Compute
     (Session : Session_Record;
      Pricing : Pricing_Table) return Session_Metrics_Record
   is
      M : Session_Metrics_Record;
      --  Cost helpers.
      TC  : Long_Float := 0.0;
      IC  : Long_Float := 0.0;
      OC  : Long_Float := 0.0;
      CRC : Long_Float := 0.0;
      CWC : Long_Float := 0.0;
      UIC : Long_Float := 0.0;
      P   : Per_Token_Prices;
      Has_P : Boolean := False;
      use Ada.Strings.Unbounded;
   begin
      --  Look up pricing for this session's model.
      if not Pricing.Is_Empty then
         declare
            Pos : constant Pricing_Maps.Cursor :=
              Pricing.Find (Session.Model);
         begin
            if Pricing_Maps.Has_Element (Pos) then
               P := Pricing_Maps.Element (Pos);
               Has_P := True;
            end if;
         end;
      end if;

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

         --  Tool calls.
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
      declare
         Prev_Name : Unbounded_String;
         Prev_Args : Unbounded_String;
         Has_Prev  : Boolean := False;
      begin
         for Turn of Session.Turns loop
            for TC of Turn.Tool_Calls loop
               if Has_Prev then
                  M.Per_Consecutive_Tool_S.Append
                    (Coyote_SQC.Statistics.JSD.Compute_S_Values
                       (Tool_Name_1 => To_String (Prev_Name),
                        Arguments_1 => To_String (Prev_Args),
                        Tool_Name_2 => To_String (TC.Tool_Name),
                        Arguments_2 => To_String (TC.Arguments)));
                  M.N_Consecutive_Tool_Pairs :=
                    M.N_Consecutive_Tool_Pairs + 1;
               end if;
               Prev_Name := TC.Tool_Name;
               Prev_Args := TC.Arguments;
               Has_Prev  := True;
            end loop;
         end loop;
      end;

      --  Sum Per_Consecutive_Tool_S.
      for V of M.Per_Consecutive_Tool_S loop
         M.Total_Tool_Call_JSD_S := M.Total_Tool_Call_JSD_S + V;
      end loop;

      --  Compute consecutive MI tool-call similarity pairs.
      declare
         Prev_Name : Unbounded_String;
         Prev_Args : Unbounded_String;
         Has_Prev  : Boolean := False;
      begin
         for Turn of Session.Turns loop
            for TC of Turn.Tool_Calls loop
               if Has_Prev then
                  Coyote_SQC.Statistics.MI.Compute_MI_Values
                    (Tool_Name_1 => To_String (Prev_Name),
                     Arguments_1 => To_String (Prev_Args),
                     Tool_Name_2 => To_String (TC.Tool_Name),
                     Arguments_2 => To_String (TC.Arguments),
                     Result      => M.Per_Consecutive_Tool_MI);
                  M.N_Consecutive_Tool_MI_Pairs :=
                    M.N_Consecutive_Tool_MI_Pairs + 1;
               end if;
               Prev_Name := TC.Tool_Name;
               Prev_Args := TC.Arguments;
               Has_Prev  := True;
            end loop;
         end loop;
      end;

      --  Sum Per_Consecutive_Tool_MI.
      for V of M.Per_Consecutive_Tool_MI loop
         M.Total_Tool_Call_MI := M.Total_Tool_Call_MI + V;
      end loop;

      --  Compute token costs if pricing is available for this model.
      if Has_P then
         declare
            N_Turns : constant Natural :=
              (if Session.Turns.Is_Empty then 1
               else Natural (Session.Turns.Length));
            PTC  : Long_Float;
            PTIC : Long_Float;
            PTOC : Long_Float;
            PTCRC : Long_Float;
            PTCWC : Long_Float;
            PTUIC : Long_Float;
         begin
            for Turn of Session.Turns loop
               PTIC := Long_Float (Turn.Input_Tokens) * P.Input_Price;
               PTOC := Long_Float (Turn.Output_Tokens) * P.Output_Price;
               PTC  := PTIC + PTOC;

               M.Per_Turn_Cost.Append (PTC);
               M.Per_Turn_Input_Cost.Append (PTIC);
               M.Per_Turn_Output_Cost.Append (PTOC);

               TC  := TC + PTC;
               IC  := IC + PTIC;
               OC  := OC + PTOC;
            end loop;

            --  Session-level cache and uncached costs.
            CRC := Long_Float (Session.Total_Cache_Read_Tokens)
                     * P.Cache_Read_Price;
            CWC := Long_Float (Session.Total_Cache_Write_Tokens)
                     * P.Cache_Write_Price;
            UIC := Long_Float (Session.Total_Uncached_Input_Tokens)
                     * P.Input_Price;

            M.Total_Cache_Read_Cost  := CRC;
            M.Total_Cache_Write_Cost := CWC;
            M.Total_Uncached_Input_Cost := UIC;

            --  Total input cost = uncached + cache read + cache write.
            M.Total_Input_Cost := IC + CRC + CWC;
            M.Total_Output_Cost := OC;
            M.Total_Cost := M.Total_Input_Cost + M.Total_Output_Cost;

            --  Per-turn cache costs: average across turns.
            if N_Turns > 0 then
               PTCRC := CRC / Long_Float (N_Turns);
               PTCWC := CWC / Long_Float (N_Turns);
               PTUIC := UIC / Long_Float (N_Turns);
               for I in 1 .. N_Turns loop
                  M.Per_Turn_Cache_Read_Cost.Append (PTCRC);
                  M.Per_Turn_Cache_Write_Cost.Append (PTCWC);
                  M.Per_Turn_Uncached_Input_Cost.Append (PTUIC);
               end loop;
            end if;
         end;
      end if;

      return M;
   end Compute;

end Coyote_SQC.Metrics;
