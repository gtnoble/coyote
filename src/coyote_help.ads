--  Coyote_Help — Yelp-based application help integration.
--
--  Project: coyote

package Coyote_Help is

   --  Return the Yelp URI for the application help root or a topic.
   function Help_URI (Topic : String := "") return String;

   --  Return the stable Mallard topic ID for a named main-window area.
   function Topic_For_Area (Area : String) return String;

   --  Return True when the required Yelp executable is available on PATH.
   function Yelp_Available return Boolean;

   --  Open the application help root or a topic in Yelp.  Return False when
   --  Yelp cannot be found or the detached launch cannot be started.
   function Open (Topic : String := "") return Boolean;

end Coyote_Help;
