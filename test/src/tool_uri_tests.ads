--  Tool_URI_Tests — unit tests for Hash_Tool_Id and Scan_Tool_Token.
--
--  Both functions are pure (no I/O, no acme required), so every test
--  here runs unconditionally and does not need a live acme instance.
--
--  Hash_Tool_Id expected values were verified against the Python reference:
--    hashlib.sha256(tool_id.encode()).hexdigest()[:16]
--
--  Project: coyote
--  For revision history, see the project version-control log.

with AUnit;
with AUnit.Test_Fixtures;

package Tool_URI_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  ── Hash_Tool_Id ──────────────────────────────────────────────────────

   --  Empty string produces the SHA-256 of b"".
   procedure Test_Hash_Empty               (T : in out Test);

   --  Known non-empty inputs match Python reference values.
   procedure Test_Hash_Known_Values        (T : in out Test);

   --  Result is always exactly 16 characters.
   procedure Test_Hash_Length              (T : in out Test);

   --  Different inputs always produce different hashes (no collision
   --  for a small representative sample).
   procedure Test_Hash_Distinct            (T : in out Test);

   --  Result contains only lowercase hex characters.
   procedure Test_Hash_Lowercase_Hex       (T : in out Test);

end Tool_URI_Tests;
