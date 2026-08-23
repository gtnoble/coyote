--  Coyote_Help_Tests body.
--
--  Project: coyote

with AUnit.Assertions;
with Coyote_Help;

package body Coyote_Help_Tests is

   use AUnit.Assertions;

   procedure Test_Root_URI (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert
        (Coyote_Help.Help_URI = "help:coyote",
         "the help root URI should use the coyote application ID");
   end Test_Root_URI;

   procedure Test_Topic_URI (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert
        (Coyote_Help.Help_URI ("send-prompt") = "help:coyote/send-prompt",
         "topic URIs should append the Mallard topic ID");
   end Test_Topic_URI;

   procedure Test_Yelp_Is_Available (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert
        (Coyote_Help.Yelp_Available,
         "Yelp is a required runtime dependency for Help");
   end Test_Yelp_Is_Available;

end Coyote_Help_Tests;
