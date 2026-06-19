--  Coyote_SQC.Metrics — derive Session_Metrics_Record from Session_Record.
--
--  Computed once at load time and cached alongside the session.
--
--  Project: coyote

with Ada.Containers.Hashed_Maps;
with Ada.Strings.Unbounded;
with Ada.Strings.Unbounded.Hash;

with Coyote_SQC.Data_Model;

package Coyote_SQC.Metrics is

   --  ── Token Pricing ──────────────────────────────────────────────────

   type Per_Token_Prices is record
      Input_Price       : Long_Float := 0.0;
      Output_Price      : Long_Float := 0.0;
      Cache_Read_Price  : Long_Float := 0.0;
      Cache_Write_Price : Long_Float := 0.0;
   end record;
   --  All prices in USD per token.

   function USB_Hash (S : Ada.Strings.Unbounded.Unbounded_String) return Ada.Containers.Hash_Type is
     (Ada.Strings.Unbounded.Hash (S));

   package Pricing_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type        => Ada.Strings.Unbounded.Unbounded_String,
      Element_Type    => Per_Token_Prices,
      Hash            => USB_Hash,
      Equivalent_Keys => Ada.Strings.Unbounded."=");

   subtype Pricing_Table is Pricing_Maps.Map;
   --  Maps model identifier strings to per-token prices.
   --  An empty table means no pricing data is available; all cost
   --  fields in Session_Metrics_Record will be left at 0.0.

   --  ── Compute ────────────────────────────────────────────────────────

   --  Compute and return the metrics record for Session.
   --  When Pricing is non-empty and contains an entry for Session.Model,
   --  cost fields (Total_Cost, Per_Turn_Cost, etc.) are populated;
   --  otherwise they remain at 0.0.
   function Compute
     (Session : Coyote_SQC.Data_Model.Session_Record;
      Pricing : Pricing_Table) return Coyote_SQC.Data_Model.Session_Metrics_Record;

end Coyote_SQC.Metrics;
