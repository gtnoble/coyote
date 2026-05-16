--  LLM.Tools.Temp_File body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Streams.Stream_IO;
with Ada.Strings;
with Ada.Strings.Fixed;

package body LLM.Tools.Temp_File is

   --  POSIX getpid() for stable, per-process temp-file naming.
   function C_Getpid return Integer;
   pragma Import (C, C_Getpid, "getpid");

   --  Monotonically increasing counter; guards concurrent tool calls.
   protected Sequence is
      procedure Next (Value : out Natural);
   private
      Count : Natural := 0;
   end Sequence;

   protected body Sequence is
      procedure Next (Value : out Natural) is
      begin
         Count := Count + 1;
         Value := Count;
      end Next;
   end Sequence;

   function Trimmed_Image (Value : Integer) return String is
   begin
      return Ada.Strings.Fixed.Trim
        (Integer'Image (Value), Ada.Strings.Both);
   end Trimmed_Image;

   function Next_Temp_Path (Tool_Name : String) return String is
      Suffix : Natural;
   begin
      Sequence.Next (Suffix);
      return
        "/tmp/coyote_"
        & Tool_Name
        & "_"
        & Trimmed_Image (C_Getpid)
        & "_"
        & Trimmed_Image (Integer (Suffix))
        & ".txt";
   end Next_Temp_Path;

   function Result_Threshold (Context_Window : Natural) return Positive is
      Raw : Natural;
   begin
      if Context_Window = 0 then
         return MAX_RESULT_THRESHOLD;
      end if;

      Raw := Context_Window * BYTES_PER_TOKEN / CONTEXT_SHARE;

      if Raw < MIN_RESULT_THRESHOLD then
         return MIN_RESULT_THRESHOLD;
      elsif Raw > MAX_RESULT_THRESHOLD then
         return MAX_RESULT_THRESHOLD;
      else
         return Raw;
      end if;
   end Result_Threshold;

   function Truncated
     (Text      : String;
      Threshold : Positive;
      Tool_Name : String := "tool") return String
   is
   begin
      if Text'Length <= Threshold then
         return Text;
      end if;

      declare
         Path    : constant String := Next_Temp_Path (Tool_Name);
         Excerpt : constant String :=
           Text (Text'First .. Text'First + Threshold - 1);
         File    : Ada.Streams.Stream_IO.File_Type;
      begin
         Ada.Streams.Stream_IO.Create
           (File, Ada.Streams.Stream_IO.Out_File, Path);
         String'Write (Ada.Streams.Stream_IO.Stream (File), Text);
         Ada.Streams.Stream_IO.Close (File);

         return
           Excerpt
           & ASCII.LF
           & "[output truncated at "
           & Trimmed_Image (Threshold)
           & " bytes; full output saved to "
           & Path
           & "; total bytes "
           & Trimmed_Image (Text'Length)
           & "]";

      exception
         when others =>
            if Ada.Streams.Stream_IO.Is_Open (File) then
               Ada.Streams.Stream_IO.Close (File);
            end if;
            return
              Excerpt
              & ASCII.LF
              & "[output truncated at "
              & Trimmed_Image (Threshold)
              & " bytes; could not write temp file; total bytes "
              & Trimmed_Image (Text'Length)
              & "]";
      end;
   end Truncated;

end LLM.Tools.Temp_File;
