--  Coyote_Help — Yelp-based application help integration.
--
--  Project: coyote

package Coyote_Help is

   --  Return the Yelp URI for the application help root or a topic.
   function Help_URI (Topic : String := "") return String;

   --  Return the stable Mallard topic ID for a named main-window area.
   function Topic_For_Area (Area : String) return String;

   --  Return the installation-relative data directory containing the Help
   --  documentation, or "" when the executable is not under a bin/ layout.
   --  Executable defaults to the running coyote binary.
   function Help_Data_Directory
     (Executable : String := "") return String;

   --  Return True when the required Yelp executable is available on PATH.
   function Yelp_Available return Boolean;

   --  Open the application help root or a topic in Yelp.  Return False when
   --  Yelp cannot be found or the detached launch cannot be started.
   function Open (Topic : String := "") return Boolean;

   --  In-process Product Information body: name, version, and license.
   --  Independent of Yelp so the Help menu entry still works when the
   --  viewer or Mallard files are missing.
   function Product_Information_Text return String;

end Coyote_Help;
