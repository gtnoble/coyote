--  LLM.Tools — built-in tool descriptors and dispatcher.
--
--  Defines the standard built-in tools exposed to the native harness and
--  provides the central name-based dispatcher used to execute them.
--
--  Project: pi_acme
--  For revision history, see the project version-control log.

with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

package LLM.Tools is

   --  Description of one tool available to the LLM.
   type Tool_Descriptor is record
      Name        : Ada.Strings.Unbounded.Unbounded_String;
      Description : Ada.Strings.Unbounded.Unbounded_String;
      --  Full JSON Schema object string for the tool's parameters.
      Schema_Json : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   package Tool_Descriptor_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Tool_Descriptor);

   --  Return the standard set of built-in tools.
   --
   --  The result contains the descriptors for bash, read, write, edit,
   --  find, and glob in that order.
   function Built_In_Tools return Tool_Descriptor_Vectors.Vector;

   --  Execute the named built-in tool with Args_Json.
   --
   --  Result receives the tool output on success or a diagnostic message on
   --  failure.  Is_Error is True when the tool itself fails because of bad
   --  arguments, missing files, non-zero command exit status, and similar
   --  execution errors.
   --
   --  Raises Unknown_Tool when Name does not match one of the built-in
   --  tools returned by Built_In_Tools.
   procedure Execute
     (Name      :     String;
      Args_Json :     String;
      Result    : out Ada.Strings.Unbounded.Unbounded_String;
      Is_Error  : out Boolean);

   --  Raised when Execute is asked to dispatch an unknown tool name.
   Unknown_Tool : exception;

end LLM.Tools;
