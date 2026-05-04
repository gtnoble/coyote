--  Tool_URI_Tests body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with AUnit.Assertions;
with Coyote_App.Utils;  use Coyote_App.Utils;

package body Tool_URI_Tests is

   use AUnit.Assertions;

   --  ── Helpers ──────────────────────────────────────────────────────────

   --  True iff every character of S is a lowercase hex digit (0-9, a-f).
   function Is_Lowercase_Hex (S : String) return Boolean is
   begin
      for C of S loop
         if C not in '0' .. '9' | 'a' .. 'f' then
            return False;
         end if;
      end loop;
      return True;
   end Is_Lowercase_Hex;

   --  Build the canonical token string for a given session UUID and tool hash.
   function Make_Token (Session_UUID : String; Hash : String) return String is
   begin
      return "llm-chat+" & Session_UUID & "/tool/" & Hash;
   end Make_Token;

   --  Sample UUID used throughout the Scan tests.
   Sample_UUID : constant String :=
     "aabbccdd-1122-3344-5566-aabbccddeeff";

   pragma Unreferenced (Make_Token, Sample_UUID);

   --  ── Hash_Tool_Id tests ────────────────────────────────────────────────

   --  SHA-256("") =
   --    e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
   --  First 16 hex chars = "e3b0c44298fc1c14"
   procedure Test_Hash_Empty (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (Hash_Tool_Id ("") = "e3b0c44298fc1c14",
              "SHA-256 of empty string should match Python reference");
   end Test_Hash_Empty;

   --  Known values cross-checked against:
   --    python3 -c "import hashlib;
   --                print(hashlib.sha256(b'tc-ok-001').hexdigest()[:16])"
   procedure Test_Hash_Known_Values (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert
        (Hash_Tool_Id ("tc-ok-001") = "e74ffc63142d6dcb",
         "Hash of 'tc-ok-001' should match Python reference");
      Assert
        (Hash_Tool_Id ("toolfoo") = "bb4537d4f05a6a84",
         "Hash of 'toolfoo' should match Python reference");
      Assert
        (Hash_Tool_Id ("abc123def456") = "e861b2eab679927c",
         "Hash of 'abc123def456' should match Python reference");
   end Test_Hash_Known_Values;

   --  Hash_Tool_Id must always return exactly 16 characters.
   procedure Test_Hash_Length (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (Hash_Tool_Id ("")'Length = 16,
              "Hash of empty string should be 16 chars");
      Assert (Hash_Tool_Id ("x")'Length = 16,
              "Hash of single char should be 16 chars");
      Assert (Hash_Tool_Id ("some-tool-call-id-12345")'Length = 16,
              "Hash of longer string should be 16 chars");
   end Test_Hash_Length;

   --  A small sample of distinct inputs should produce distinct hashes.
   procedure Test_Hash_Distinct (T : in out Test) is
      pragma Unreferenced (T);
      H1 : constant String := Hash_Tool_Id ("alpha");
      H2 : constant String := Hash_Tool_Id ("beta");
      H3 : constant String := Hash_Tool_Id ("gamma");
      H4 : constant String := Hash_Tool_Id ("alpha2");
   begin
      Assert (H1 /= H2, "Different inputs should yield different hashes (1)");
      Assert (H1 /= H3, "Different inputs should yield different hashes (2)");
      Assert (H2 /= H3, "Different inputs should yield different hashes (3)");
      Assert (H1 /= H4, "Different inputs should yield different hashes (4)");
   end Test_Hash_Distinct;

   --  All characters in the result must be lowercase hex digits.
   procedure Test_Hash_Lowercase_Hex (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (Is_Lowercase_Hex (Hash_Tool_Id ("")),
              "Hash of empty string should be lowercase hex");
      Assert (Is_Lowercase_Hex (Hash_Tool_Id ("hello")),
              "Hash of 'hello' should be lowercase hex");
      Assert (Is_Lowercase_Hex (Hash_Tool_Id ("UPPER")),
              "Hash of upper-case input should still be lowercase hex");
   end Test_Hash_Lowercase_Hex;

end Tool_URI_Tests;
