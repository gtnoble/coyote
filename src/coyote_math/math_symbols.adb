--  GENERATED from the pinned KaTeX 0.16.22 dist inventory.
--  Inventory SHA-256: 445511f22cbf79b0300a505c4f096bc57066b40daaa095bd9d39fc614943604d
--  dist/katex.js SHA-256: 8f1f4fb1080439c012bb8fddf424fa253e9144ab4cdd7dc0eae0e92cd04a5e33

with Math_Model; use Math_Model;

package body Math_Symbols is
   function Find (Name : String; Text_Mode : Boolean) return Symbol_Record is
   begin
      if Text_Mode = False then
         if Name =
           "!" then
            return
              (True, 33,
               Closing, Main_Regular);
         end if;
         if Name =
           """" then
            return
              (True, 34,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "(" then
            return
              (True, 40,
               Opening, Main_Regular);
         end if;
         if Name =
           ")" then
            return
              (True, 41,
               Closing, Main_Regular);
         end if;
         if Name =
           "*" then
            return
              (True, 8727,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           "+" then
            return
              (True, 43,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           "," then
            return
              (True, 44,
               Punctuation, Main_Regular);
         end if;
         if Name =
           "-" then
            return
              (True, 8722,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           "." then
            return
              (True, 46,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "/" then
            return
              (True, 47,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "0" then
            return
              (True, 48,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "1" then
            return
              (True, 49,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "2" then
            return
              (True, 50,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "3" then
            return
              (True, 51,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "4" then
            return
              (True, 52,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "5" then
            return
              (True, 53,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "6" then
            return
              (True, 54,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "7" then
            return
              (True, 55,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "8" then
            return
              (True, 56,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "9" then
            return
              (True, 57,
               Ordinary, Main_Regular);
         end if;
         if Name =
           ":" then
            return
              (True, 58,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           ";" then
            return
              (True, 59,
               Punctuation, Main_Regular);
         end if;
         if Name =
           "<" then
            return
              (True, 60,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "=" then
            return
              (True, 61,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           ">" then
            return
              (True, 62,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "?" then
            return
              (True, 63,
               Closing, Main_Regular);
         end if;
         if Name =
           "@" then
            return
              (True, 64,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "A" then
            return
              (True, 65,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "B" then
            return
              (True, 66,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "C" then
            return
              (True, 67,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "D" then
            return
              (True, 68,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "E" then
            return
              (True, 69,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "F" then
            return
              (True, 70,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "G" then
            return
              (True, 71,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "H" then
            return
              (True, 72,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "I" then
            return
              (True, 73,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "J" then
            return
              (True, 74,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "K" then
            return
              (True, 75,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "L" then
            return
              (True, 76,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "M" then
            return
              (True, 77,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "N" then
            return
              (True, 78,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "O" then
            return
              (True, 79,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "P" then
            return
              (True, 80,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "Q" then
            return
              (True, 81,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "R" then
            return
              (True, 82,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "S" then
            return
              (True, 83,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "T" then
            return
              (True, 84,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "U" then
            return
              (True, 85,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "V" then
            return
              (True, 86,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "W" then
            return
              (True, 87,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "X" then
            return
              (True, 88,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "Y" then
            return
              (True, 89,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "Z" then
            return
              (True, 90,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "[" then
            return
              (True, 91,
               Opening, Main_Regular);
         end if;
         if Name =
           "\" & "#" then
            return
              (True, 35,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "$" then
            return
              (True, 36,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "%" then
            return
              (True, 37,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "&" then
            return
              (True, 38,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "@" & "c" & "d" & "o" & "t" & "s" then
            return
              (True, 8943,
               Inner, Main_Regular);
         end if;
         if Name =
           "\" & "@" & "g" & "v" & "e" & "r" & "t" & "n" & "e" & "q" & "q" then
            return
              (True, 57357,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "@" & "i" & "m" & "a" & "t" & "h" then
            return
              (True, 57649,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "\" & "@" & "j" & "m" & "a" & "t" & "h" then
            return
              (True, 57911,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "\" & "@" & "l" & "l" & "c" & "o" & "r" & "n" & "e" & "r" then
            return
              (True, 9492,
               Opening, AMS_Regular);
         end if;
         if Name =
           "\" & "@" & "l" & "r" & "c" & "o" & "r" & "n" & "e" & "r" then
            return
              (True, 9496,
               Closing, AMS_Regular);
         end if;
         if Name =
           "\" & "@" & "l" & "v" & "e" & "r" & "t" & "n" & "e" & "q" & "q" then
            return
              (True, 57356,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "@" & "n" & "g" & "e" & "q" & "q" then
            return
              (True, 57358,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "@" & "n" & "g" & "e" & "q" & "s" & "l" & "a" & "n" & "t" then
            return
              (True, 57359,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "@" & "n" & "l" & "e" & "q" & "q" then
            return
              (True, 57361,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "@" & "n" & "l" & "e" & "q" & "s" & "l" & "a" & "n" & "t" then
            return
              (True, 57360,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "@" & "n" & "o" & "t" then
            return
              (True, 57376,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "@" & "n" & "s" & "h" & "o" & "r" & "t" & "m" & "i" & "d" then
            return
              (True, 57350,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "@" & "n" & "s" & "h" & "o" & "r" & "t" & "p" & "a" & "r" & "a" & "l" & "l" & "e" & "l" then
            return
              (True, 57351,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "@" & "n" & "s" & "u" & "b" & "s" & "e" & "t" & "e" & "q" & "q" then
            return
              (True, 57366,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "@" & "n" & "s" & "u" & "p" & "s" & "e" & "t" & "e" & "q" & "q" then
            return
              (True, 57368,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "@" & "u" & "l" & "c" & "o" & "r" & "n" & "e" & "r" then
            return
              (True, 9484,
               Opening, AMS_Regular);
         end if;
         if Name =
           "\" & "@" & "u" & "r" & "c" & "o" & "r" & "n" & "e" & "r" then
            return
              (True, 9488,
               Closing, AMS_Regular);
         end if;
         if Name =
           "\" & "@" & "v" & "a" & "r" & "s" & "u" & "b" & "s" & "e" & "t" & "n" & "e" & "q" then
            return
              (True, 57370,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "@" & "v" & "a" & "r" & "s" & "u" & "b" & "s" & "e" & "t" & "n" & "e" & "q" & "q" then
            return
              (True, 57367,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "@" & "v" & "a" & "r" & "s" & "u" & "p" & "s" & "e" & "t" & "n" & "e" & "q" then
            return
              (True, 57371,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "@" & "v" & "a" & "r" & "s" & "u" & "p" & "s" & "e" & "t" & "n" & "e" & "q" & "q" then
            return
              (True, 57369,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "A" & "n" & "d" then
            return
              (True, 38,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "B" & "o" & "x" then
            return
              (True, 9633,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           "\" & "B" & "u" & "m" & "p" & "e" & "q" then
            return
              (True, 8782,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "C" & "a" & "p" then
            return
              (True, 8914,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "C" & "u" & "p" then
            return
              (True, 8915,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "D" & "e" & "l" & "t" & "a" then
            return
              (True, 916,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "D" & "i" & "a" & "m" & "o" & "n" & "d" then
            return
              (True, 9674,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           "\" & "D" & "o" & "t" & "e" & "q" then
            return
              (True, 8785,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "D" & "o" & "w" & "n" & "a" & "r" & "r" & "o" & "w" then
            return
              (True, 8659,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "F" & "i" & "n" & "v" then
            return
              (True, 8498,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           "\" & "G" & "a" & "m" & "e" then
            return
              (True, 8513,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           "\" & "G" & "a" & "m" & "m" & "a" then
            return
              (True, 915,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "I" & "m" then
            return
              (True, 8465,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "J" & "o" & "i" & "n" then
            return
              (True, 8904,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "L" & "a" & "m" & "b" & "d" & "a" then
            return
              (True, 923,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "L" & "e" & "f" & "t" & "a" & "r" & "r" & "o" & "w" then
            return
              (True, 8656,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "L" & "e" & "f" & "t" & "r" & "i" & "g" & "h" & "t" & "a" & "r" & "r" & "o" & "w" then
            return
              (True, 8660,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "L" & "l" & "e" & "f" & "t" & "a" & "r" & "r" & "o" & "w" then
            return
              (True, 8666,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "L" & "o" & "n" & "g" & "l" & "e" & "f" & "t" & "a" & "r" & "r" & "o" & "w" then
            return
              (True, 10232,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "L" & "o" & "n" & "g" & "l" & "e" & "f" & "t" & "r" & "i" & "g" & "h" & "t" & "a" & "r" & "r" & "o" & "w" then
            return
              (True, 10234,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "L" & "o" & "n" & "g" & "r" & "i" & "g" & "h" & "t" & "a" & "r" & "r" & "o" & "w" then
            return
              (True, 10233,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "L" & "s" & "h" then
            return
              (True, 8624,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "O" & "m" & "e" & "g" & "a" then
            return
              (True, 937,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "P" then
            return
              (True, 182,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "P" & "h" & "i" then
            return
              (True, 934,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "P" & "i" then
            return
              (True, 928,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "P" & "s" & "i" then
            return
              (True, 936,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "R" & "e" then
            return
              (True, 8476,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "R" & "i" & "g" & "h" & "t" & "a" & "r" & "r" & "o" & "w" then
            return
              (True, 8658,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "R" & "r" & "i" & "g" & "h" & "t" & "a" & "r" & "r" & "o" & "w" then
            return
              (True, 8667,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "R" & "s" & "h" then
            return
              (True, 8625,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "S" then
            return
              (True, 167,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "S" & "i" & "g" & "m" & "a" then
            return
              (True, 931,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "S" & "u" & "b" & "s" & "e" & "t" then
            return
              (True, 8912,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "S" & "u" & "p" & "s" & "e" & "t" then
            return
              (True, 8913,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "T" & "h" & "e" & "t" & "a" then
            return
              (True, 920,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "U" & "p" & "a" & "r" & "r" & "o" & "w" then
            return
              (True, 8657,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "U" & "p" & "d" & "o" & "w" & "n" & "a" & "r" & "r" & "o" & "w" then
            return
              (True, 8661,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "U" & "p" & "s" & "i" & "l" & "o" & "n" then
            return
              (True, 933,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "V" & "d" & "a" & "s" & "h" then
            return
              (True, 8873,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "V" & "e" & "r" & "t" then
            return
              (True, 8741,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "V" & "v" & "d" & "a" & "s" & "h" then
            return
              (True, 8874,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "X" & "i" then
            return
              (True, 926,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "_" then
            return
              (True, 95,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "a" & "l" & "e" & "p" & "h" then
            return
              (True, 8501,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "a" & "l" & "p" & "h" & "a" then
            return
              (True, 945,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "\" & "a" & "m" & "a" & "l" & "g" then
            return
              (True, 10815,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "a" & "n" & "g" & "l" & "e" then
            return
              (True, 8736,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "a" & "p" & "p" & "r" & "o" & "x" then
            return
              (True, 8776,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "a" & "p" & "p" & "r" & "o" & "x" & "e" & "q" then
            return
              (True, 8778,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "a" & "s" & "t" then
            return
              (True, 8727,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "a" & "s" & "y" & "m" & "p" then
            return
              (True, 8781,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "b" & "a" & "c" & "k" & "e" & "p" & "s" & "i" & "l" & "o" & "n" then
            return
              (True, 8717,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "b" & "a" & "c" & "k" & "p" & "r" & "i" & "m" & "e" then
            return
              (True, 8245,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           "\" & "b" & "a" & "c" & "k" & "s" & "i" & "m" then
            return
              (True, 8765,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "b" & "a" & "c" & "k" & "s" & "i" & "m" & "e" & "q" then
            return
              (True, 8909,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "b" & "a" & "c" & "k" & "s" & "l" & "a" & "s" & "h" then
            return
              (True, 92,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "b" & "a" & "r" & "w" & "e" & "d" & "g" & "e" then
            return
              (True, 8892,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "b" & "e" & "c" & "a" & "u" & "s" & "e" then
            return
              (True, 8757,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "b" & "e" & "t" & "a" then
            return
              (True, 946,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "\" & "b" & "e" & "t" & "h" then
            return
              (True, 8502,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           "\" & "b" & "e" & "t" & "w" & "e" & "e" & "n" then
            return
              (True, 8812,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "b" & "i" & "g" & "c" & "a" & "p" then
            return
              (True, 8898,
               Operator_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "b" & "i" & "g" & "c" & "i" & "r" & "c" then
            return
              (True, 9711,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "b" & "i" & "g" & "c" & "u" & "p" then
            return
              (True, 8899,
               Operator_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "b" & "i" & "g" & "o" & "d" & "o" & "t" then
            return
              (True, 10752,
               Operator_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "b" & "i" & "g" & "o" & "p" & "l" & "u" & "s" then
            return
              (True, 10753,
               Operator_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "b" & "i" & "g" & "o" & "t" & "i" & "m" & "e" & "s" then
            return
              (True, 10754,
               Operator_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "b" & "i" & "g" & "s" & "q" & "c" & "u" & "p" then
            return
              (True, 10758,
               Operator_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "b" & "i" & "g" & "s" & "t" & "a" & "r" then
            return
              (True, 9733,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           "\" & "b" & "i" & "g" & "t" & "r" & "i" & "a" & "n" & "g" & "l" & "e" & "d" & "o" & "w" & "n" then
            return
              (True, 9661,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "b" & "i" & "g" & "t" & "r" & "i" & "a" & "n" & "g" & "l" & "e" & "u" & "p" then
            return
              (True, 9651,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "b" & "i" & "g" & "u" & "p" & "l" & "u" & "s" then
            return
              (True, 10756,
               Operator_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "b" & "i" & "g" & "v" & "e" & "e" then
            return
              (True, 8897,
               Operator_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "b" & "i" & "g" & "w" & "e" & "d" & "g" & "e" then
            return
              (True, 8896,
               Operator_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "b" & "l" & "a" & "c" & "k" & "l" & "o" & "z" & "e" & "n" & "g" & "e" then
            return
              (True, 10731,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           "\" & "b" & "l" & "a" & "c" & "k" & "s" & "q" & "u" & "a" & "r" & "e" then
            return
              (True, 9632,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           "\" & "b" & "l" & "a" & "c" & "k" & "t" & "r" & "i" & "a" & "n" & "g" & "l" & "e" then
            return
              (True, 9650,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           "\" & "b" & "l" & "a" & "c" & "k" & "t" & "r" & "i" & "a" & "n" & "g" & "l" & "e" & "d" & "o" & "w" & "n" then
            return
              (True, 9660,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           "\" & "b" & "l" & "a" & "c" & "k" & "t" & "r" & "i" & "a" & "n" & "g" & "l" & "e" & "l" & "e" & "f" & "t" then
            return
              (True, 9664,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "b" & "l" & "a" & "c" & "k" & "t" & "r" & "i" & "a" & "n" & "g" & "l" & "e" & "r" & "i" & "g" & "h" & "t" then
            return
              (True, 9654,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "b" & "o" & "t" then
            return
              (True, 8869,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "b" & "o" & "w" & "t" & "i" & "e" then
            return
              (True, 8904,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "b" & "o" & "x" & "d" & "o" & "t" then
            return
              (True, 8865,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "b" & "o" & "x" & "m" & "i" & "n" & "u" & "s" then
            return
              (True, 8863,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "b" & "o" & "x" & "p" & "l" & "u" & "s" then
            return
              (True, 8862,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "b" & "o" & "x" & "t" & "i" & "m" & "e" & "s" then
            return
              (True, 8864,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "b" & "u" & "l" & "l" & "e" & "t" then
            return
              (True, 8729,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "b" & "u" & "m" & "p" & "e" & "q" then
            return
              (True, 8783,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "c" & "a" & "p" then
            return
              (True, 8745,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "c" & "d" & "o" & "t" then
            return
              (True, 8901,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "c" & "d" & "o" & "t" & "p" then
            return
              (True, 8901,
               Punctuation, Main_Regular);
         end if;
         if Name =
           "\" & "c" & "e" & "n" & "t" & "e" & "r" & "d" & "o" & "t" then
            return
              (True, 8901,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "c" & "h" & "e" & "c" & "k" & "m" & "a" & "r" & "k" then
            return
              (True, 10003,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           "\" & "c" & "h" & "i" then
            return
              (True, 967,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "\" & "c" & "i" & "r" & "c" then
            return
              (True, 8728,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "c" & "i" & "r" & "c" & "e" & "q" then
            return
              (True, 8791,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "c" & "i" & "r" & "c" & "l" & "e" & "a" & "r" & "r" & "o" & "w" & "l" & "e" & "f" & "t" then
            return
              (True, 8634,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "c" & "i" & "r" & "c" & "l" & "e" & "a" & "r" & "r" & "o" & "w" & "r" & "i" & "g" & "h" & "t" then
            return
              (True, 8635,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "c" & "i" & "r" & "c" & "l" & "e" & "d" & "R" then
            return
              (True, 174,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           "\" & "c" & "i" & "r" & "c" & "l" & "e" & "d" & "S" then
            return
              (True, 9416,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           "\" & "c" & "i" & "r" & "c" & "l" & "e" & "d" & "a" & "s" & "t" then
            return
              (True, 8859,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "c" & "i" & "r" & "c" & "l" & "e" & "d" & "c" & "i" & "r" & "c" then
            return
              (True, 8858,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "c" & "i" & "r" & "c" & "l" & "e" & "d" & "d" & "a" & "s" & "h" then
            return
              (True, 8861,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "c" & "l" & "u" & "b" & "s" & "u" & "i" & "t" then
            return
              (True, 9827,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "c" & "o" & "m" & "p" & "l" & "e" & "m" & "e" & "n" & "t" then
            return
              (True, 8705,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           "\" & "c" & "o" & "n" & "g" then
            return
              (True, 8773,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "c" & "o" & "p" & "r" & "o" & "d" then
            return
              (True, 8720,
               Operator_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "c" & "u" & "p" then
            return
              (True, 8746,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "c" & "u" & "r" & "l" & "y" & "e" & "q" & "p" & "r" & "e" & "c" then
            return
              (True, 8926,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "c" & "u" & "r" & "l" & "y" & "e" & "q" & "s" & "u" & "c" & "c" then
            return
              (True, 8927,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "c" & "u" & "r" & "l" & "y" & "v" & "e" & "e" then
            return
              (True, 8910,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "c" & "u" & "r" & "l" & "y" & "w" & "e" & "d" & "g" & "e" then
            return
              (True, 8911,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "c" & "u" & "r" & "v" & "e" & "a" & "r" & "r" & "o" & "w" & "l" & "e" & "f" & "t" then
            return
              (True, 8630,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "c" & "u" & "r" & "v" & "e" & "a" & "r" & "r" & "o" & "w" & "r" & "i" & "g" & "h" & "t" then
            return
              (True, 8631,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "d" & "a" & "g" then
            return
              (True, 8224,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "d" & "a" & "g" & "g" & "e" & "r" then
            return
              (True, 8224,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "d" & "a" & "l" & "e" & "t" & "h" then
            return
              (True, 8504,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           "\" & "d" & "a" & "s" & "h" & "l" & "e" & "f" & "t" & "a" & "r" & "r" & "o" & "w" then
            return
              (True, 8672,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "d" & "a" & "s" & "h" & "r" & "i" & "g" & "h" & "t" & "a" & "r" & "r" & "o" & "w" then
            return
              (True, 8674,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "d" & "a" & "s" & "h" & "v" then
            return
              (True, 8867,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "d" & "d" & "a" & "g" then
            return
              (True, 8225,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "d" & "d" & "a" & "g" & "g" & "e" & "r" then
            return
              (True, 8225,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "d" & "d" & "o" & "t" & "s" then
            return
              (True, 8945,
               Inner, Main_Regular);
         end if;
         if Name =
           "\" & "d" & "e" & "g" & "r" & "e" & "e" then
            return
              (True, 176,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "d" & "e" & "l" & "t" & "a" then
            return
              (True, 948,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "\" & "d" & "i" & "a" & "g" & "d" & "o" & "w" & "n" then
            return
              (True, 9586,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           "\" & "d" & "i" & "a" & "g" & "u" & "p" then
            return
              (True, 9585,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           "\" & "d" & "i" & "a" & "m" & "o" & "n" & "d" then
            return
              (True, 8900,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "d" & "i" & "a" & "m" & "o" & "n" & "d" & "s" & "u" & "i" & "t" then
            return
              (True, 9826,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "d" & "i" & "g" & "a" & "m" & "m" & "a" then
            return
              (True, 989,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           "\" & "d" & "i" & "v" then
            return
              (True, 247,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "d" & "i" & "v" & "i" & "d" & "e" & "o" & "n" & "t" & "i" & "m" & "e" & "s" then
            return
              (True, 8903,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "d" & "o" & "t" & "e" & "q" then
            return
              (True, 8784,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "d" & "o" & "t" & "e" & "q" & "d" & "o" & "t" then
            return
              (True, 8785,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "d" & "o" & "t" & "p" & "l" & "u" & "s" then
            return
              (True, 8724,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "d" & "o" & "u" & "b" & "l" & "e" & "b" & "a" & "r" & "w" & "e" & "d" & "g" & "e" then
            return
              (True, 10846,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "d" & "o" & "u" & "b" & "l" & "e" & "c" & "a" & "p" then
            return
              (True, 8914,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "d" & "o" & "u" & "b" & "l" & "e" & "c" & "u" & "p" then
            return
              (True, 8915,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "d" & "o" & "w" & "n" & "a" & "r" & "r" & "o" & "w" then
            return
              (True, 8595,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "d" & "o" & "w" & "n" & "d" & "o" & "w" & "n" & "a" & "r" & "r" & "o" & "w" & "s" then
            return
              (True, 8650,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "d" & "o" & "w" & "n" & "h" & "a" & "r" & "p" & "o" & "o" & "n" & "l" & "e" & "f" & "t" then
            return
              (True, 8643,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "d" & "o" & "w" & "n" & "h" & "a" & "r" & "p" & "o" & "o" & "n" & "r" & "i" & "g" & "h" & "t" then
            return
              (True, 8642,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "e" & "l" & "l" then
            return
              (True, 8467,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "e" & "m" & "p" & "t" & "y" & "s" & "e" & "t" then
            return
              (True, 8709,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "e" & "p" & "s" & "i" & "l" & "o" & "n" then
            return
              (True, 1013,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "\" & "e" & "q" & "c" & "i" & "r" & "c" then
            return
              (True, 8790,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "e" & "q" & "s" & "i" & "m" then
            return
              (True, 8770,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "e" & "q" & "s" & "l" & "a" & "n" & "t" & "g" & "t" & "r" then
            return
              (True, 10902,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "e" & "q" & "s" & "l" & "a" & "n" & "t" & "l" & "e" & "s" & "s" then
            return
              (True, 10901,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "e" & "q" & "u" & "i" & "v" then
            return
              (True, 8801,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "e" & "t" & "a" then
            return
              (True, 951,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "\" & "e" & "t" & "h" then
            return
              (True, 240,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           "\" & "e" & "x" & "i" & "s" & "t" & "s" then
            return
              (True, 8707,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "f" & "a" & "l" & "l" & "i" & "n" & "g" & "d" & "o" & "t" & "s" & "e" & "q" then
            return
              (True, 8786,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "f" & "l" & "a" & "t" then
            return
              (True, 9837,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "f" & "o" & "r" & "a" & "l" & "l" then
            return
              (True, 8704,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "f" & "r" & "o" & "w" & "n" then
            return
              (True, 8994,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "g" & "a" & "m" & "m" & "a" then
            return
              (True, 947,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "\" & "g" & "e" then
            return
              (True, 8805,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "g" & "e" & "q" then
            return
              (True, 8805,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "g" & "e" & "q" & "q" then
            return
              (True, 8807,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "g" & "e" & "q" & "s" & "l" & "a" & "n" & "t" then
            return
              (True, 10878,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "g" & "e" & "t" & "s" then
            return
              (True, 8592,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "g" & "g" then
            return
              (True, 8811,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "g" & "g" & "g" then
            return
              (True, 8921,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "g" & "g" & "g" & "t" & "r" then
            return
              (True, 8921,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "g" & "i" & "m" & "e" & "l" then
            return
              (True, 8503,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           "\" & "g" & "n" & "a" & "p" & "p" & "r" & "o" & "x" then
            return
              (True, 10890,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "g" & "n" & "e" & "q" then
            return
              (True, 10888,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "g" & "n" & "e" & "q" & "q" then
            return
              (True, 8809,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "g" & "n" & "s" & "i" & "m" then
            return
              (True, 8935,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "g" & "t" then
            return
              (True, 62,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "g" & "t" & "r" & "a" & "p" & "p" & "r" & "o" & "x" then
            return
              (True, 10886,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "g" & "t" & "r" & "d" & "o" & "t" then
            return
              (True, 8919,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "g" & "t" & "r" & "e" & "q" & "l" & "e" & "s" & "s" then
            return
              (True, 8923,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "g" & "t" & "r" & "e" & "q" & "q" & "l" & "e" & "s" & "s" then
            return
              (True, 10892,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "g" & "t" & "r" & "l" & "e" & "s" & "s" then
            return
              (True, 8823,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "g" & "t" & "r" & "s" & "i" & "m" then
            return
              (True, 8819,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "h" & "b" & "a" & "r" then
            return
              (True, 8463,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "h" & "e" & "a" & "r" & "t" & "s" & "u" & "i" & "t" then
            return
              (True, 9825,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "h" & "o" & "o" & "k" & "l" & "e" & "f" & "t" & "a" & "r" & "r" & "o" & "w" then
            return
              (True, 8617,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "h" & "o" & "o" & "k" & "r" & "i" & "g" & "h" & "t" & "a" & "r" & "r" & "o" & "w" then
            return
              (True, 8618,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "h" & "s" & "l" & "a" & "s" & "h" then
            return
              (True, 8463,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           "\" & "i" & "i" & "i" & "n" & "t" then
            return
              (True, 8749,
               Operator_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "i" & "i" & "n" & "t" then
            return
              (True, 8748,
               Operator_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "i" & "m" & "a" & "g" & "e" & "o" & "f" then
            return
              (True, 8887,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "i" & "n" then
            return
              (True, 8712,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "i" & "n" & "f" & "t" & "y" then
            return
              (True, 8734,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "i" & "n" & "t" then
            return
              (True, 8747,
               Operator_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "i" & "n" & "t" & "e" & "r" & "c" & "a" & "l" then
            return
              (True, 8890,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "i" & "n" & "t" & "o" & "p" then
            return
              (True, 8747,
               Operator_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "i" & "o" & "t" & "a" then
            return
              (True, 953,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "\" & "k" & "a" & "p" & "p" & "a" then
            return
              (True, 954,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "\" & "l" & "V" & "e" & "r" & "t" then
            return
              (True, 8741,
               Opening, Main_Regular);
         end if;
         if Name =
           "\" & "l" & "a" & "m" & "b" & "d" & "a" then
            return
              (True, 955,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "\" & "l" & "a" & "n" & "d" then
            return
              (True, 8743,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "l" & "a" & "n" & "g" & "l" & "e" then
            return
              (True, 10216,
               Opening, Main_Regular);
         end if;
         if Name =
           "\" & "l" & "b" & "r" & "a" & "c" & "e" then
            return
              (True, 123,
               Opening, Main_Regular);
         end if;
         if Name =
           "\" & "l" & "b" & "r" & "a" & "c" & "k" then
            return
              (True, 91,
               Opening, Main_Regular);
         end if;
         if Name =
           "\" & "l" & "c" & "e" & "i" & "l" then
            return
              (True, 8968,
               Opening, Main_Regular);
         end if;
         if Name =
           "\" & "l" & "d" & "o" & "t" & "p" then
            return
              (True, 46,
               Punctuation, Main_Regular);
         end if;
         if Name =
           "\" & "l" & "d" & "o" & "t" & "s" then
            return
              (True, 8230,
               Inner, Main_Regular);
         end if;
         if Name =
           "\" & "l" & "e" then
            return
              (True, 8804,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "l" & "e" & "a" & "d" & "s" & "t" & "o" then
            return
              (True, 8669,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "l" & "e" & "f" & "t" & "a" & "r" & "r" & "o" & "w" then
            return
              (True, 8592,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "l" & "e" & "f" & "t" & "a" & "r" & "r" & "o" & "w" & "t" & "a" & "i" & "l" then
            return
              (True, 8610,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "l" & "e" & "f" & "t" & "h" & "a" & "r" & "p" & "o" & "o" & "n" & "d" & "o" & "w" & "n" then
            return
              (True, 8637,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "l" & "e" & "f" & "t" & "h" & "a" & "r" & "p" & "o" & "o" & "n" & "u" & "p" then
            return
              (True, 8636,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "l" & "e" & "f" & "t" & "l" & "e" & "f" & "t" & "a" & "r" & "r" & "o" & "w" & "s" then
            return
              (True, 8647,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "l" & "e" & "f" & "t" & "r" & "i" & "g" & "h" & "t" & "a" & "r" & "r" & "o" & "w" then
            return
              (True, 8596,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "l" & "e" & "f" & "t" & "r" & "i" & "g" & "h" & "t" & "a" & "r" & "r" & "o" & "w" & "s" then
            return
              (True, 8646,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "l" & "e" & "f" & "t" & "r" & "i" & "g" & "h" & "t" & "h" & "a" & "r" & "p" & "o" & "o" & "n" & "s" then
            return
              (True, 8651,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "l" & "e" & "f" & "t" & "r" & "i" & "g" & "h" & "t" & "s" & "q" & "u" & "i" & "g" & "a" & "r" & "r" & "o" & "w" then
            return
              (True, 8621,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "l" & "e" & "f" & "t" & "t" & "h" & "r" & "e" & "e" & "t" & "i" & "m" & "e" & "s" then
            return
              (True, 8907,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "l" & "e" & "q" then
            return
              (True, 8804,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "l" & "e" & "q" & "q" then
            return
              (True, 8806,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "l" & "e" & "q" & "s" & "l" & "a" & "n" & "t" then
            return
              (True, 10877,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "l" & "e" & "s" & "s" & "a" & "p" & "p" & "r" & "o" & "x" then
            return
              (True, 10885,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "l" & "e" & "s" & "s" & "d" & "o" & "t" then
            return
              (True, 8918,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "l" & "e" & "s" & "s" & "e" & "q" & "g" & "t" & "r" then
            return
              (True, 8922,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "l" & "e" & "s" & "s" & "e" & "q" & "q" & "g" & "t" & "r" then
            return
              (True, 10891,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "l" & "e" & "s" & "s" & "g" & "t" & "r" then
            return
              (True, 8822,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "l" & "e" & "s" & "s" & "s" & "i" & "m" then
            return
              (True, 8818,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "l" & "f" & "l" & "o" & "o" & "r" then
            return
              (True, 8970,
               Opening, Main_Regular);
         end if;
         if Name =
           "\" & "l" & "g" & "r" & "o" & "u" & "p" then
            return
              (True, 10222,
               Opening, Main_Regular);
         end if;
         if Name =
           "\" & "l" & "h" & "d" then
            return
              (True, 8882,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "l" & "l" then
            return
              (True, 8810,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "l" & "l" & "l" then
            return
              (True, 8920,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "l" & "l" & "l" & "e" & "s" & "s" then
            return
              (True, 8920,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "l" & "m" & "o" & "u" & "s" & "t" & "a" & "c" & "h" & "e" then
            return
              (True, 9136,
               Opening, Main_Regular);
         end if;
         if Name =
           "\" & "l" & "n" & "a" & "p" & "p" & "r" & "o" & "x" then
            return
              (True, 10889,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "l" & "n" & "e" & "q" then
            return
              (True, 10887,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "l" & "n" & "e" & "q" & "q" then
            return
              (True, 8808,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "l" & "n" & "o" & "t" then
            return
              (True, 172,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "l" & "n" & "s" & "i" & "m" then
            return
              (True, 8934,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "l" & "o" & "n" & "g" & "l" & "e" & "f" & "t" & "a" & "r" & "r" & "o" & "w" then
            return
              (True, 10229,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "l" & "o" & "n" & "g" & "l" & "e" & "f" & "t" & "r" & "i" & "g" & "h" & "t" & "a" & "r" & "r" & "o" & "w" then
            return
              (True, 10231,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "l" & "o" & "n" & "g" & "m" & "a" & "p" & "s" & "t" & "o" then
            return
              (True, 10236,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "l" & "o" & "n" & "g" & "r" & "i" & "g" & "h" & "t" & "a" & "r" & "r" & "o" & "w" then
            return
              (True, 10230,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "l" & "o" & "o" & "p" & "a" & "r" & "r" & "o" & "w" & "l" & "e" & "f" & "t" then
            return
              (True, 8619,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "l" & "o" & "o" & "p" & "a" & "r" & "r" & "o" & "w" & "r" & "i" & "g" & "h" & "t" then
            return
              (True, 8620,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "l" & "o" & "r" then
            return
              (True, 8744,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "l" & "o" & "z" & "e" & "n" & "g" & "e" then
            return
              (True, 9674,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           "\" & "l" & "p" & "a" & "r" & "e" & "n" then
            return
              (True, 40,
               Opening, Main_Regular);
         end if;
         if Name =
           "\" & "l" & "t" then
            return
              (True, 60,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "l" & "t" & "i" & "m" & "e" & "s" then
            return
              (True, 8905,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "l" & "v" & "e" & "r" & "t" then
            return
              (True, 8739,
               Opening, Main_Regular);
         end if;
         if Name =
           "\" & "m" & "a" & "l" & "t" & "e" & "s" & "e" then
            return
              (True, 10016,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           "\" & "m" & "a" & "p" & "s" & "t" & "o" then
            return
              (True, 8614,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "m" & "a" & "t" & "h" & "e" & "l" & "l" & "i" & "p" & "s" & "i" & "s" then
            return
              (True, 8230,
               Inner, Main_Regular);
         end if;
         if Name =
           "\" & "m" & "a" & "t" & "h" & "s" & "t" & "e" & "r" & "l" & "i" & "n" & "g" then
            return
              (True, 163,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "m" & "e" & "a" & "s" & "u" & "r" & "e" & "d" & "a" & "n" & "g" & "l" & "e" then
            return
              (True, 8737,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           "\" & "m" & "h" & "o" then
            return
              (True, 8487,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           "\" & "m" & "i" & "d" then
            return
              (True, 8739,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "m" & "o" & "d" & "e" & "l" & "s" then
            return
              (True, 8872,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "m" & "p" then
            return
              (True, 8723,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "m" & "u" then
            return
              (True, 956,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "\" & "m" & "u" & "l" & "t" & "i" & "m" & "a" & "p" then
            return
              (True, 8888,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "n" & "L" & "e" & "f" & "t" & "a" & "r" & "r" & "o" & "w" then
            return
              (True, 8653,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "n" & "L" & "e" & "f" & "t" & "r" & "i" & "g" & "h" & "t" & "a" & "r" & "r" & "o" & "w" then
            return
              (True, 8654,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "n" & "R" & "i" & "g" & "h" & "t" & "a" & "r" & "r" & "o" & "w" then
            return
              (True, 8655,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "n" & "V" & "D" & "a" & "s" & "h" then
            return
              (True, 8879,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "n" & "V" & "d" & "a" & "s" & "h" then
            return
              (True, 8878,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "n" & "a" & "b" & "l" & "a" then
            return
              (True, 8711,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "n" & "a" & "t" & "u" & "r" & "a" & "l" then
            return
              (True, 9838,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "n" & "c" & "o" & "n" & "g" then
            return
              (True, 8774,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "n" & "e" & "a" & "r" & "r" & "o" & "w" then
            return
              (True, 8599,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "n" & "e" & "g" then
            return
              (True, 172,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "n" & "e" & "x" & "i" & "s" & "t" & "s" then
            return
              (True, 8708,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           "\" & "n" & "g" & "e" & "q" then
            return
              (True, 8817,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "n" & "g" & "t" & "r" then
            return
              (True, 8815,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "n" & "i" then
            return
              (True, 8715,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "n" & "l" & "e" & "f" & "t" & "a" & "r" & "r" & "o" & "w" then
            return
              (True, 8602,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "n" & "l" & "e" & "f" & "t" & "r" & "i" & "g" & "h" & "t" & "a" & "r" & "r" & "o" & "w" then
            return
              (True, 8622,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "n" & "l" & "e" & "q" then
            return
              (True, 8816,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "n" & "l" & "e" & "s" & "s" then
            return
              (True, 8814,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "n" & "m" & "i" & "d" then
            return
              (True, 8740,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "n" & "p" & "a" & "r" & "a" & "l" & "l" & "e" & "l" then
            return
              (True, 8742,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "n" & "p" & "r" & "e" & "c" then
            return
              (True, 8832,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "n" & "p" & "r" & "e" & "c" & "e" & "q" then
            return
              (True, 8928,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "n" & "r" & "i" & "g" & "h" & "t" & "a" & "r" & "r" & "o" & "w" then
            return
              (True, 8603,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "n" & "s" & "i" & "m" then
            return
              (True, 8769,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "n" & "s" & "u" & "b" & "s" & "e" & "t" & "e" & "q" then
            return
              (True, 8840,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "n" & "s" & "u" & "c" & "c" then
            return
              (True, 8833,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "n" & "s" & "u" & "c" & "c" & "e" & "q" then
            return
              (True, 8929,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "n" & "s" & "u" & "p" & "s" & "e" & "t" & "e" & "q" then
            return
              (True, 8841,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "n" & "t" & "r" & "i" & "a" & "n" & "g" & "l" & "e" & "l" & "e" & "f" & "t" then
            return
              (True, 8938,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "n" & "t" & "r" & "i" & "a" & "n" & "g" & "l" & "e" & "l" & "e" & "f" & "t" & "e" & "q" then
            return
              (True, 8940,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "n" & "t" & "r" & "i" & "a" & "n" & "g" & "l" & "e" & "r" & "i" & "g" & "h" & "t" then
            return
              (True, 8939,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "n" & "t" & "r" & "i" & "a" & "n" & "g" & "l" & "e" & "r" & "i" & "g" & "h" & "t" & "e" & "q" then
            return
              (True, 8941,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "n" & "u" then
            return
              (True, 957,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "\" & "n" & "v" & "D" & "a" & "s" & "h" then
            return
              (True, 8877,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "n" & "v" & "d" & "a" & "s" & "h" then
            return
              (True, 8876,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "n" & "w" & "a" & "r" & "r" & "o" & "w" then
            return
              (True, 8598,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "o" & "d" & "o" & "t" then
            return
              (True, 8857,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "o" & "i" & "i" & "i" & "n" & "t" then
            return
              (True, 8752,
               Operator_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "o" & "i" & "i" & "n" & "t" then
            return
              (True, 8751,
               Operator_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "o" & "i" & "n" & "t" then
            return
              (True, 8750,
               Operator_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "o" & "m" & "e" & "g" & "a" then
            return
              (True, 969,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "\" & "o" & "m" & "i" & "c" & "r" & "o" & "n" then
            return
              (True, 959,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "\" & "o" & "m" & "i" & "n" & "u" & "s" then
            return
              (True, 8854,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "o" & "p" & "l" & "u" & "s" then
            return
              (True, 8853,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "o" & "r" & "i" & "g" & "o" & "f" then
            return
              (True, 8886,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "o" & "s" & "l" & "a" & "s" & "h" then
            return
              (True, 8856,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "o" & "t" & "i" & "m" & "e" & "s" then
            return
              (True, 8855,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "o" & "w" & "n" & "s" then
            return
              (True, 8715,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "p" & "a" & "r" & "a" & "l" & "l" & "e" & "l" then
            return
              (True, 8741,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "p" & "a" & "r" & "t" & "i" & "a" & "l" then
            return
              (True, 8706,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "p" & "e" & "r" & "p" then
            return
              (True, 8869,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "p" & "h" & "i" then
            return
              (True, 981,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "\" & "p" & "i" then
            return
              (True, 960,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "\" & "p" & "i" & "t" & "c" & "h" & "f" & "o" & "r" & "k" then
            return
              (True, 8916,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "p" & "m" then
            return
              (True, 177,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "p" & "o" & "u" & "n" & "d" & "s" then
            return
              (True, 163,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "p" & "r" & "e" & "c" then
            return
              (True, 8826,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "p" & "r" & "e" & "c" & "a" & "p" & "p" & "r" & "o" & "x" then
            return
              (True, 10935,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "p" & "r" & "e" & "c" & "c" & "u" & "r" & "l" & "y" & "e" & "q" then
            return
              (True, 8828,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "p" & "r" & "e" & "c" & "e" & "q" then
            return
              (True, 10927,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "p" & "r" & "e" & "c" & "n" & "a" & "p" & "p" & "r" & "o" & "x" then
            return
              (True, 10937,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "p" & "r" & "e" & "c" & "n" & "e" & "q" & "q" then
            return
              (True, 10933,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "p" & "r" & "e" & "c" & "n" & "s" & "i" & "m" then
            return
              (True, 8936,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "p" & "r" & "e" & "c" & "s" & "i" & "m" then
            return
              (True, 8830,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "p" & "r" & "i" & "m" & "e" then
            return
              (True, 8242,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "p" & "r" & "o" & "d" then
            return
              (True, 8719,
               Operator_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "p" & "r" & "o" & "p" & "t" & "o" then
            return
              (True, 8733,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "p" & "s" & "i" then
            return
              (True, 968,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "\" & "r" & "V" & "e" & "r" & "t" then
            return
              (True, 8741,
               Closing, Main_Regular);
         end if;
         if Name =
           "\" & "r" & "a" & "n" & "g" & "l" & "e" then
            return
              (True, 10217,
               Closing, Main_Regular);
         end if;
         if Name =
           "\" & "r" & "b" & "r" & "a" & "c" & "e" then
            return
              (True, 125,
               Closing, Main_Regular);
         end if;
         if Name =
           "\" & "r" & "b" & "r" & "a" & "c" & "k" then
            return
              (True, 93,
               Closing, Main_Regular);
         end if;
         if Name =
           "\" & "r" & "c" & "e" & "i" & "l" then
            return
              (True, 8969,
               Closing, Main_Regular);
         end if;
         if Name =
           "\" & "r" & "e" & "s" & "t" & "r" & "i" & "c" & "t" & "i" & "o" & "n" then
            return
              (True, 8638,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "r" & "f" & "l" & "o" & "o" & "r" then
            return
              (True, 8971,
               Closing, Main_Regular);
         end if;
         if Name =
           "\" & "r" & "g" & "r" & "o" & "u" & "p" then
            return
              (True, 10223,
               Closing, Main_Regular);
         end if;
         if Name =
           "\" & "r" & "h" & "d" then
            return
              (True, 8883,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "r" & "h" & "o" then
            return
              (True, 961,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "\" & "r" & "i" & "g" & "h" & "t" & "a" & "r" & "r" & "o" & "w" then
            return
              (True, 8594,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "r" & "i" & "g" & "h" & "t" & "a" & "r" & "r" & "o" & "w" & "t" & "a" & "i" & "l" then
            return
              (True, 8611,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "r" & "i" & "g" & "h" & "t" & "h" & "a" & "r" & "p" & "o" & "o" & "n" & "d" & "o" & "w" & "n" then
            return
              (True, 8641,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "r" & "i" & "g" & "h" & "t" & "h" & "a" & "r" & "p" & "o" & "o" & "n" & "u" & "p" then
            return
              (True, 8640,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "r" & "i" & "g" & "h" & "t" & "l" & "e" & "f" & "t" & "a" & "r" & "r" & "o" & "w" & "s" then
            return
              (True, 8644,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "r" & "i" & "g" & "h" & "t" & "l" & "e" & "f" & "t" & "h" & "a" & "r" & "p" & "o" & "o" & "n" & "s" then
            return
              (True, 8652,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "r" & "i" & "g" & "h" & "t" & "r" & "i" & "g" & "h" & "t" & "a" & "r" & "r" & "o" & "w" & "s" then
            return
              (True, 8649,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "r" & "i" & "g" & "h" & "t" & "s" & "q" & "u" & "i" & "g" & "a" & "r" & "r" & "o" & "w" then
            return
              (True, 8669,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "r" & "i" & "g" & "h" & "t" & "t" & "h" & "r" & "e" & "e" & "t" & "i" & "m" & "e" & "s" then
            return
              (True, 8908,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "r" & "i" & "s" & "i" & "n" & "g" & "d" & "o" & "t" & "s" & "e" & "q" then
            return
              (True, 8787,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "r" & "m" & "o" & "u" & "s" & "t" & "a" & "c" & "h" & "e" then
            return
              (True, 9137,
               Closing, Main_Regular);
         end if;
         if Name =
           "\" & "r" & "p" & "a" & "r" & "e" & "n" then
            return
              (True, 41,
               Closing, Main_Regular);
         end if;
         if Name =
           "\" & "r" & "t" & "i" & "m" & "e" & "s" then
            return
              (True, 8906,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "r" & "v" & "e" & "r" & "t" then
            return
              (True, 8739,
               Closing, Main_Regular);
         end if;
         if Name =
           "\" & "s" & "e" & "a" & "r" & "r" & "o" & "w" then
            return
              (True, 8600,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "s" & "e" & "t" & "m" & "i" & "n" & "u" & "s" then
            return
              (True, 8726,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "s" & "h" & "a" & "r" & "p" then
            return
              (True, 9839,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "s" & "h" & "o" & "r" & "t" & "m" & "i" & "d" then
            return
              (True, 8739,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "s" & "h" & "o" & "r" & "t" & "p" & "a" & "r" & "a" & "l" & "l" & "e" & "l" then
            return
              (True, 8741,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "s" & "i" & "g" & "m" & "a" then
            return
              (True, 963,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "\" & "s" & "i" & "m" then
            return
              (True, 8764,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "s" & "i" & "m" & "e" & "q" then
            return
              (True, 8771,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "s" & "m" & "a" & "l" & "l" & "f" & "r" & "o" & "w" & "n" then
            return
              (True, 8994,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "s" & "m" & "a" & "l" & "l" & "i" & "n" & "t" then
            return
              (True, 8747,
               Operator_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "s" & "m" & "a" & "l" & "l" & "s" & "e" & "t" & "m" & "i" & "n" & "u" & "s" then
            return
              (True, 8726,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "s" & "m" & "a" & "l" & "l" & "s" & "m" & "i" & "l" & "e" then
            return
              (True, 8995,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "s" & "m" & "i" & "l" & "e" then
            return
              (True, 8995,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "s" & "p" & "a" & "d" & "e" & "s" & "u" & "i" & "t" then
            return
              (True, 9824,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "s" & "p" & "h" & "e" & "r" & "i" & "c" & "a" & "l" & "a" & "n" & "g" & "l" & "e" then
            return
              (True, 8738,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           "\" & "s" & "q" & "c" & "a" & "p" then
            return
              (True, 8851,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "s" & "q" & "c" & "u" & "p" then
            return
              (True, 8852,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "s" & "q" & "s" & "u" & "b" & "s" & "e" & "t" then
            return
              (True, 8847,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "s" & "q" & "s" & "u" & "b" & "s" & "e" & "t" & "e" & "q" then
            return
              (True, 8849,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "s" & "q" & "s" & "u" & "p" & "s" & "e" & "t" then
            return
              (True, 8848,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "s" & "q" & "s" & "u" & "p" & "s" & "e" & "t" & "e" & "q" then
            return
              (True, 8850,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "s" & "q" & "u" & "a" & "r" & "e" then
            return
              (True, 9633,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           "\" & "s" & "t" & "a" & "r" then
            return
              (True, 8902,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "s" & "u" & "b" & "s" & "e" & "t" then
            return
              (True, 8834,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "s" & "u" & "b" & "s" & "e" & "t" & "e" & "q" then
            return
              (True, 8838,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "s" & "u" & "b" & "s" & "e" & "t" & "e" & "q" & "q" then
            return
              (True, 10949,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "s" & "u" & "b" & "s" & "e" & "t" & "n" & "e" & "q" then
            return
              (True, 8842,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "s" & "u" & "b" & "s" & "e" & "t" & "n" & "e" & "q" & "q" then
            return
              (True, 10955,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "s" & "u" & "c" & "c" then
            return
              (True, 8827,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "s" & "u" & "c" & "c" & "a" & "p" & "p" & "r" & "o" & "x" then
            return
              (True, 10936,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "s" & "u" & "c" & "c" & "c" & "u" & "r" & "l" & "y" & "e" & "q" then
            return
              (True, 8829,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "s" & "u" & "c" & "c" & "e" & "q" then
            return
              (True, 10928,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "s" & "u" & "c" & "c" & "n" & "a" & "p" & "p" & "r" & "o" & "x" then
            return
              (True, 10938,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "s" & "u" & "c" & "c" & "n" & "e" & "q" & "q" then
            return
              (True, 10934,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "s" & "u" & "c" & "c" & "n" & "s" & "i" & "m" then
            return
              (True, 8937,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "s" & "u" & "c" & "c" & "s" & "i" & "m" then
            return
              (True, 8831,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "s" & "u" & "m" then
            return
              (True, 8721,
               Operator_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "s" & "u" & "p" & "s" & "e" & "t" then
            return
              (True, 8835,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "s" & "u" & "p" & "s" & "e" & "t" & "e" & "q" then
            return
              (True, 8839,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "s" & "u" & "p" & "s" & "e" & "t" & "e" & "q" & "q" then
            return
              (True, 10950,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "s" & "u" & "p" & "s" & "e" & "t" & "n" & "e" & "q" then
            return
              (True, 8843,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "s" & "u" & "p" & "s" & "e" & "t" & "n" & "e" & "q" & "q" then
            return
              (True, 10956,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "s" & "u" & "r" & "d" then
            return
              (True, 8730,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "s" & "w" & "a" & "r" & "r" & "o" & "w" then
            return
              (True, 8601,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "t" & "a" & "u" then
            return
              (True, 964,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "\" & "t" & "h" & "e" & "r" & "e" & "f" & "o" & "r" & "e" then
            return
              (True, 8756,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "t" & "h" & "e" & "t" & "a" then
            return
              (True, 952,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "\" & "t" & "h" & "i" & "c" & "k" & "a" & "p" & "p" & "r" & "o" & "x" then
            return
              (True, 8776,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "t" & "h" & "i" & "c" & "k" & "s" & "i" & "m" then
            return
              (True, 8764,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "t" & "i" & "m" & "e" & "s" then
            return
              (True, 215,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "t" & "o" then
            return
              (True, 8594,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "t" & "o" & "p" then
            return
              (True, 8868,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "t" & "r" & "i" & "a" & "n" & "g" & "l" & "e" then
            return
              (True, 9651,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "t" & "r" & "i" & "a" & "n" & "g" & "l" & "e" & "d" & "o" & "w" & "n" then
            return
              (True, 9661,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           "\" & "t" & "r" & "i" & "a" & "n" & "g" & "l" & "e" & "l" & "e" & "f" & "t" then
            return
              (True, 9667,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "t" & "r" & "i" & "a" & "n" & "g" & "l" & "e" & "l" & "e" & "f" & "t" & "e" & "q" then
            return
              (True, 8884,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "t" & "r" & "i" & "a" & "n" & "g" & "l" & "e" & "q" then
            return
              (True, 8796,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "t" & "r" & "i" & "a" & "n" & "g" & "l" & "e" & "r" & "i" & "g" & "h" & "t" then
            return
              (True, 9657,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "t" & "r" & "i" & "a" & "n" & "g" & "l" & "e" & "r" & "i" & "g" & "h" & "t" & "e" & "q" then
            return
              (True, 8885,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "t" & "w" & "o" & "h" & "e" & "a" & "d" & "l" & "e" & "f" & "t" & "a" & "r" & "r" & "o" & "w" then
            return
              (True, 8606,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "t" & "w" & "o" & "h" & "e" & "a" & "d" & "r" & "i" & "g" & "h" & "t" & "a" & "r" & "r" & "o" & "w" then
            return
              (True, 8608,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "u" & "n" & "l" & "h" & "d" then
            return
              (True, 8884,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "u" & "n" & "r" & "h" & "d" then
            return
              (True, 8885,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "u" & "p" & "a" & "r" & "r" & "o" & "w" then
            return
              (True, 8593,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "u" & "p" & "d" & "o" & "w" & "n" & "a" & "r" & "r" & "o" & "w" then
            return
              (True, 8597,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "u" & "p" & "h" & "a" & "r" & "p" & "o" & "o" & "n" & "l" & "e" & "f" & "t" then
            return
              (True, 8639,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "u" & "p" & "h" & "a" & "r" & "p" & "o" & "o" & "n" & "r" & "i" & "g" & "h" & "t" then
            return
              (True, 8638,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "u" & "p" & "l" & "u" & "s" then
            return
              (True, 8846,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "u" & "p" & "s" & "i" & "l" & "o" & "n" then
            return
              (True, 965,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "\" & "u" & "p" & "u" & "p" & "a" & "r" & "r" & "o" & "w" & "s" then
            return
              (True, 8648,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "v" & "D" & "a" & "s" & "h" then
            return
              (True, 8872,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "v" & "a" & "r" & "e" & "p" & "s" & "i" & "l" & "o" & "n" then
            return
              (True, 949,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "\" & "v" & "a" & "r" & "k" & "a" & "p" & "p" & "a" then
            return
              (True, 1008,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           "\" & "v" & "a" & "r" & "n" & "o" & "t" & "h" & "i" & "n" & "g" then
            return
              (True, 8709,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           "\" & "v" & "a" & "r" & "p" & "h" & "i" then
            return
              (True, 966,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "\" & "v" & "a" & "r" & "p" & "i" then
            return
              (True, 982,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "\" & "v" & "a" & "r" & "p" & "r" & "o" & "p" & "t" & "o" then
            return
              (True, 8733,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "v" & "a" & "r" & "r" & "h" & "o" then
            return
              (True, 1009,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "\" & "v" & "a" & "r" & "s" & "i" & "g" & "m" & "a" then
            return
              (True, 962,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "\" & "v" & "a" & "r" & "t" & "h" & "e" & "t" & "a" then
            return
              (True, 977,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "\" & "v" & "a" & "r" & "t" & "r" & "i" & "a" & "n" & "g" & "l" & "e" then
            return
              (True, 9651,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "v" & "a" & "r" & "t" & "r" & "i" & "a" & "n" & "g" & "l" & "e" & "l" & "e" & "f" & "t" then
            return
              (True, 8882,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "v" & "a" & "r" & "t" & "r" & "i" & "a" & "n" & "g" & "l" & "e" & "r" & "i" & "g" & "h" & "t" then
            return
              (True, 8883,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "v" & "a" & "r" & "v" & "d" & "o" & "t" & "s" then
            return
              (True, 8942,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "v" & "d" & "a" & "s" & "h" then
            return
              (True, 8866,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "v" & "e" & "e" then
            return
              (True, 8744,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "v" & "e" & "e" & "b" & "a" & "r" then
            return
              (True, 8891,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           "\" & "v" & "e" & "r" & "t" then
            return
              (True, 8739,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "w" & "e" & "d" & "g" & "e" then
            return
              (True, 8743,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "w" & "p" then
            return
              (True, 8472,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "w" & "r" then
            return
              (True, 8768,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           "\" & "x" & "i" then
            return
              (True, 958,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "\" & "y" & "e" & "n" then
            return
              (True, 165,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           "\" & "z" & "e" & "t" & "a" then
            return
              (True, 950,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "\" & "{" then
            return
              (True, 123,
               Opening, Main_Regular);
         end if;
         if Name =
           "\" & "|" then
            return
              (True, 8741,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "}" then
            return
              (True, 125,
               Closing, Main_Regular);
         end if;
         if Name =
           "]" then
            return
              (True, 93,
               Closing, Main_Regular);
         end if;
         if Name =
           "`" then
            return
              (True, 8216,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "a" then
            return
              (True, 97,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "b" then
            return
              (True, 98,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "c" then
            return
              (True, 99,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "d" then
            return
              (True, 100,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "e" then
            return
              (True, 101,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "f" then
            return
              (True, 102,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "g" then
            return
              (True, 103,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "h" then
            return
              (True, 104,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "i" then
            return
              (True, 105,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "j" then
            return
              (True, 106,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "k" then
            return
              (True, 107,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "l" then
            return
              (True, 108,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "m" then
            return
              (True, 109,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "n" then
            return
              (True, 110,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "o" then
            return
              (True, 111,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "p" then
            return
              (True, 112,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "q" then
            return
              (True, 113,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "r" then
            return
              (True, 114,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "s" then
            return
              (True, 115,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "t" then
            return
              (True, 116,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "u" then
            return
              (True, 117,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "v" then
            return
              (True, 118,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "w" then
            return
              (True, 119,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "x" then
            return
              (True, 120,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "y" then
            return
              (True, 121,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "z" then
            return
              (True, 122,
               Ordinary, Math_Italic);
         end if;
         if Name =
           "|" then
            return
              (True, 8739,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (194) & Character'Val (163) then
            return
              (True, 163,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (194) & Character'Val (165) then
            return
              (True, 165,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           Character'Val (194) & Character'Val (167) then
            return
              (True, 167,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (194) & Character'Val (172) then
            return
              (True, 172,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (194) & Character'Val (176) then
            return
              (True, 176,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (194) & Character'Val (177) then
            return
              (True, 177,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (194) & Character'Val (182) then
            return
              (True, 182,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (195) & Character'Val (144) then
            return
              (True, 208,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (195) & Character'Val (151) then
            return
              (True, 215,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (195) & Character'Val (158) then
            return
              (True, 222,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (195) & Character'Val (176) then
            return
              (True, 240,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           Character'Val (195) & Character'Val (183) then
            return
              (True, 247,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (195) & Character'Val (190) then
            return
              (True, 254,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (196) & Character'Val (177) then
            return
              (True, 305,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (200) & Character'Val (183) then
            return
              (True, 567,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (206) & Character'Val (145) then
            return
              (True, 65,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (206) & Character'Val (146) then
            return
              (True, 66,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (206) & Character'Val (147) then
            return
              (True, 915,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (206) & Character'Val (148) then
            return
              (True, 916,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (206) & Character'Val (149) then
            return
              (True, 69,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (206) & Character'Val (150) then
            return
              (True, 90,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (206) & Character'Val (151) then
            return
              (True, 72,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (206) & Character'Val (152) then
            return
              (True, 920,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (206) & Character'Val (153) then
            return
              (True, 73,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (206) & Character'Val (154) then
            return
              (True, 75,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (206) & Character'Val (155) then
            return
              (True, 923,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (206) & Character'Val (156) then
            return
              (True, 77,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (206) & Character'Val (157) then
            return
              (True, 78,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (206) & Character'Val (158) then
            return
              (True, 926,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (206) & Character'Val (159) then
            return
              (True, 79,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (206) & Character'Val (160) then
            return
              (True, 928,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (206) & Character'Val (161) then
            return
              (True, 80,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (206) & Character'Val (163) then
            return
              (True, 931,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (206) & Character'Val (164) then
            return
              (True, 84,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (206) & Character'Val (165) then
            return
              (True, 933,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (206) & Character'Val (166) then
            return
              (True, 934,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (206) & Character'Val (167) then
            return
              (True, 88,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (206) & Character'Val (168) then
            return
              (True, 936,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (206) & Character'Val (169) then
            return
              (True, 937,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (206) & Character'Val (177) then
            return
              (True, 945,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (206) & Character'Val (178) then
            return
              (True, 946,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (206) & Character'Val (179) then
            return
              (True, 947,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (206) & Character'Val (180) then
            return
              (True, 948,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (206) & Character'Val (181) then
            return
              (True, 949,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (206) & Character'Val (182) then
            return
              (True, 950,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (206) & Character'Val (183) then
            return
              (True, 951,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (206) & Character'Val (184) then
            return
              (True, 952,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (206) & Character'Val (185) then
            return
              (True, 953,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (206) & Character'Val (186) then
            return
              (True, 954,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (206) & Character'Val (187) then
            return
              (True, 955,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (206) & Character'Val (188) then
            return
              (True, 956,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (206) & Character'Val (189) then
            return
              (True, 957,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (206) & Character'Val (190) then
            return
              (True, 958,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (206) & Character'Val (191) then
            return
              (True, 959,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (207) & Character'Val (128) then
            return
              (True, 960,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (207) & Character'Val (129) then
            return
              (True, 961,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (207) & Character'Val (130) then
            return
              (True, 962,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (207) & Character'Val (131) then
            return
              (True, 963,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (207) & Character'Val (132) then
            return
              (True, 964,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (207) & Character'Val (133) then
            return
              (True, 965,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (207) & Character'Val (134) then
            return
              (True, 966,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (207) & Character'Val (135) then
            return
              (True, 967,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (207) & Character'Val (136) then
            return
              (True, 968,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (207) & Character'Val (137) then
            return
              (True, 969,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (207) & Character'Val (145) then
            return
              (True, 977,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (207) & Character'Val (149) then
            return
              (True, 981,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (207) & Character'Val (150) then
            return
              (True, 982,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (207) & Character'Val (157) then
            return
              (True, 989,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           Character'Val (207) & Character'Val (177) then
            return
              (True, 1009,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (207) & Character'Val (181) then
            return
              (True, 1013,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (226) & Character'Val (128) & Character'Val (166) then
            return
              (True, 8230,
               Inner, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (132) & Character'Val (130) then
            return
              (True, 67,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (132) & Character'Val (141) then
            return
              (True, 72,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (132) & Character'Val (142) then
            return
              (True, 104,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (226) & Character'Val (132) & Character'Val (143) then
            return
              (True, 8463,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (132) & Character'Val (145) then
            return
              (True, 8465,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (132) & Character'Val (147) then
            return
              (True, 8467,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (132) & Character'Val (149) then
            return
              (True, 78,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (132) & Character'Val (152) then
            return
              (True, 8472,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (132) & Character'Val (153) then
            return
              (True, 80,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (132) & Character'Val (154) then
            return
              (True, 81,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (132) & Character'Val (156) then
            return
              (True, 8476,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (132) & Character'Val (157) then
            return
              (True, 82,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (132) & Character'Val (164) then
            return
              (True, 90,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (132) & Character'Val (178) then
            return
              (True, 8498,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (132) & Character'Val (181) then
            return
              (True, 8501,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (132) & Character'Val (182) then
            return
              (True, 8502,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (132) & Character'Val (183) then
            return
              (True, 8503,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (132) & Character'Val (184) then
            return
              (True, 8504,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (133) & Character'Val (129) then
            return
              (True, 8513,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (134) & Character'Val (144) then
            return
              (True, 8592,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (134) & Character'Val (145) then
            return
              (True, 8593,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (134) & Character'Val (146) then
            return
              (True, 8594,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (134) & Character'Val (147) then
            return
              (True, 8595,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (134) & Character'Val (148) then
            return
              (True, 8596,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (134) & Character'Val (149) then
            return
              (True, 8597,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (134) & Character'Val (150) then
            return
              (True, 8598,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (134) & Character'Val (151) then
            return
              (True, 8599,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (134) & Character'Val (152) then
            return
              (True, 8600,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (134) & Character'Val (153) then
            return
              (True, 8601,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (134) & Character'Val (154) then
            return
              (True, 8602,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (134) & Character'Val (155) then
            return
              (True, 8603,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (134) & Character'Val (158) then
            return
              (True, 8606,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (134) & Character'Val (160) then
            return
              (True, 8608,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (134) & Character'Val (162) then
            return
              (True, 8610,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (134) & Character'Val (163) then
            return
              (True, 8611,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (134) & Character'Val (166) then
            return
              (True, 8614,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (134) & Character'Val (169) then
            return
              (True, 8617,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (134) & Character'Val (170) then
            return
              (True, 8618,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (134) & Character'Val (171) then
            return
              (True, 8619,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (134) & Character'Val (172) then
            return
              (True, 8620,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (134) & Character'Val (173) then
            return
              (True, 8621,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (134) & Character'Val (174) then
            return
              (True, 8622,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (134) & Character'Val (176) then
            return
              (True, 8624,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (134) & Character'Val (177) then
            return
              (True, 8625,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (134) & Character'Val (182) then
            return
              (True, 8630,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (134) & Character'Val (183) then
            return
              (True, 8631,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (134) & Character'Val (186) then
            return
              (True, 8634,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (134) & Character'Val (187) then
            return
              (True, 8635,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (134) & Character'Val (188) then
            return
              (True, 8636,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (134) & Character'Val (189) then
            return
              (True, 8637,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (134) & Character'Val (190) then
            return
              (True, 8638,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (134) & Character'Val (191) then
            return
              (True, 8639,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (135) & Character'Val (128) then
            return
              (True, 8640,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (135) & Character'Val (129) then
            return
              (True, 8641,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (135) & Character'Val (130) then
            return
              (True, 8642,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (135) & Character'Val (131) then
            return
              (True, 8643,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (135) & Character'Val (132) then
            return
              (True, 8644,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (135) & Character'Val (134) then
            return
              (True, 8646,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (135) & Character'Val (135) then
            return
              (True, 8647,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (135) & Character'Val (136) then
            return
              (True, 8648,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (135) & Character'Val (137) then
            return
              (True, 8649,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (135) & Character'Val (138) then
            return
              (True, 8650,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (135) & Character'Val (139) then
            return
              (True, 8651,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (135) & Character'Val (140) then
            return
              (True, 8652,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (135) & Character'Val (141) then
            return
              (True, 8653,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (135) & Character'Val (142) then
            return
              (True, 8654,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (135) & Character'Val (143) then
            return
              (True, 8655,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (135) & Character'Val (144) then
            return
              (True, 8656,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (135) & Character'Val (145) then
            return
              (True, 8657,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (135) & Character'Val (146) then
            return
              (True, 8658,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (135) & Character'Val (147) then
            return
              (True, 8659,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (135) & Character'Val (148) then
            return
              (True, 8660,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (135) & Character'Val (149) then
            return
              (True, 8661,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (135) & Character'Val (154) then
            return
              (True, 8666,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (135) & Character'Val (155) then
            return
              (True, 8667,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (135) & Character'Val (157) then
            return
              (True, 8669,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (135) & Character'Val (160) then
            return
              (True, 8672,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (135) & Character'Val (162) then
            return
              (True, 8674,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (136) & Character'Val (128) then
            return
              (True, 8704,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (136) & Character'Val (129) then
            return
              (True, 8705,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (136) & Character'Val (130) then
            return
              (True, 8706,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (136) & Character'Val (131) then
            return
              (True, 8707,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (136) & Character'Val (135) then
            return
              (True, 8711,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (136) & Character'Val (136) then
            return
              (True, 8712,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (136) & Character'Val (139) then
            return
              (True, 8715,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (136) & Character'Val (146) then
            return
              (True, 8722,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (136) & Character'Val (147) then
            return
              (True, 8723,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (136) & Character'Val (148) then
            return
              (True, 8724,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (136) & Character'Val (150) then
            return
              (True, 8726,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (136) & Character'Val (151) then
            return
              (True, 8727,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (136) & Character'Val (152) then
            return
              (True, 8728,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (136) & Character'Val (153) then
            return
              (True, 8729,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (136) & Character'Val (157) then
            return
              (True, 8733,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (136) & Character'Val (158) then
            return
              (True, 8734,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (136) & Character'Val (160) then
            return
              (True, 8736,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (136) & Character'Val (161) then
            return
              (True, 8737,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (136) & Character'Val (162) then
            return
              (True, 8738,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (136) & Character'Val (163) then
            return
              (True, 8739,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (136) & Character'Val (164) then
            return
              (True, 8740,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (136) & Character'Val (166) then
            return
              (True, 8742,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (136) & Character'Val (167) then
            return
              (True, 8743,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (136) & Character'Val (168) then
            return
              (True, 8744,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (136) & Character'Val (169) then
            return
              (True, 8745,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (136) & Character'Val (170) then
            return
              (True, 8746,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (136) & Character'Val (180) then
            return
              (True, 8756,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (136) & Character'Val (181) then
            return
              (True, 8757,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (136) & Character'Val (188) then
            return
              (True, 8764,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (136) & Character'Val (189) then
            return
              (True, 8765,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (128) then
            return
              (True, 8768,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (129) then
            return
              (True, 8769,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (130) then
            return
              (True, 8770,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (131) then
            return
              (True, 8771,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (133) then
            return
              (True, 8773,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (134) then
            return
              (True, 8774,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (136) then
            return
              (True, 8776,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (138) then
            return
              (True, 8778,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (141) then
            return
              (True, 8781,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (142) then
            return
              (True, 8782,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (143) then
            return
              (True, 8783,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (144) then
            return
              (True, 8784,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (145) then
            return
              (True, 8785,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (146) then
            return
              (True, 8786,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (147) then
            return
              (True, 8787,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (150) then
            return
              (True, 8790,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (151) then
            return
              (True, 8791,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (156) then
            return
              (True, 8796,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (161) then
            return
              (True, 8801,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (164) then
            return
              (True, 8804,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (165) then
            return
              (True, 8805,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (166) then
            return
              (True, 8806,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (167) then
            return
              (True, 8807,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (168) then
            return
              (True, 8808,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (169) then
            return
              (True, 8809,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (170) then
            return
              (True, 8810,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (171) then
            return
              (True, 8811,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (172) then
            return
              (True, 8812,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (174) then
            return
              (True, 8814,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (175) then
            return
              (True, 8815,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (176) then
            return
              (True, 8816,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (177) then
            return
              (True, 8817,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (178) then
            return
              (True, 8818,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (179) then
            return
              (True, 8819,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (182) then
            return
              (True, 8822,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (183) then
            return
              (True, 8823,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (186) then
            return
              (True, 8826,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (187) then
            return
              (True, 8827,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (188) then
            return
              (True, 8828,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (189) then
            return
              (True, 8829,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (190) then
            return
              (True, 8830,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (137) & Character'Val (191) then
            return
              (True, 8831,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (128) then
            return
              (True, 8832,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (129) then
            return
              (True, 8833,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (130) then
            return
              (True, 8834,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (131) then
            return
              (True, 8835,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (134) then
            return
              (True, 8838,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (135) then
            return
              (True, 8839,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (136) then
            return
              (True, 8840,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (137) then
            return
              (True, 8841,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (138) then
            return
              (True, 8842,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (139) then
            return
              (True, 8843,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (142) then
            return
              (True, 8846,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (143) then
            return
              (True, 8847,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (144) then
            return
              (True, 8848,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (145) then
            return
              (True, 8849,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (146) then
            return
              (True, 8850,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (147) then
            return
              (True, 8851,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (148) then
            return
              (True, 8852,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (149) then
            return
              (True, 8853,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (150) then
            return
              (True, 8854,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (151) then
            return
              (True, 8855,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (152) then
            return
              (True, 8856,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (153) then
            return
              (True, 8857,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (154) then
            return
              (True, 8858,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (155) then
            return
              (True, 8859,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (157) then
            return
              (True, 8861,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (158) then
            return
              (True, 8862,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (159) then
            return
              (True, 8863,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (160) then
            return
              (True, 8864,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (161) then
            return
              (True, 8865,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (162) then
            return
              (True, 8866,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (163) then
            return
              (True, 8867,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (168) then
            return
              (True, 8872,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (169) then
            return
              (True, 8873,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (170) then
            return
              (True, 8874,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (172) then
            return
              (True, 8876,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (173) then
            return
              (True, 8877,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (174) then
            return
              (True, 8878,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (175) then
            return
              (True, 8879,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (182) then
            return
              (True, 8886,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (183) then
            return
              (True, 8887,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (184) then
            return
              (True, 8888,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (186) then
            return
              (True, 8890,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (187) then
            return
              (True, 8891,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (138) & Character'Val (188) then
            return
              (True, 8892,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (139) & Character'Val (133) then
            return
              (True, 8901,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (139) & Character'Val (135) then
            return
              (True, 8903,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (139) & Character'Val (136) then
            return
              (True, 8904,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (139) & Character'Val (137) then
            return
              (True, 8905,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (139) & Character'Val (138) then
            return
              (True, 8906,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (139) & Character'Val (139) then
            return
              (True, 8907,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (139) & Character'Val (140) then
            return
              (True, 8908,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (139) & Character'Val (141) then
            return
              (True, 8909,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (139) & Character'Val (142) then
            return
              (True, 8910,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (139) & Character'Val (143) then
            return
              (True, 8911,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (139) & Character'Val (144) then
            return
              (True, 8912,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (139) & Character'Val (145) then
            return
              (True, 8913,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (139) & Character'Val (146) then
            return
              (True, 8914,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (139) & Character'Val (147) then
            return
              (True, 8915,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (139) & Character'Val (148) then
            return
              (True, 8916,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (139) & Character'Val (152) then
            return
              (True, 8920,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (139) & Character'Val (153) then
            return
              (True, 8921,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (139) & Character'Val (154) then
            return
              (True, 8922,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (139) & Character'Val (155) then
            return
              (True, 8923,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (139) & Character'Val (158) then
            return
              (True, 8926,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (139) & Character'Val (159) then
            return
              (True, 8927,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (139) & Character'Val (160) then
            return
              (True, 8928,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (139) & Character'Val (161) then
            return
              (True, 8929,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (139) & Character'Val (166) then
            return
              (True, 8934,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (139) & Character'Val (167) then
            return
              (True, 8935,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (139) & Character'Val (168) then
            return
              (True, 8936,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (139) & Character'Val (169) then
            return
              (True, 8937,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (139) & Character'Val (172) then
            return
              (True, 8940,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (139) & Character'Val (173) then
            return
              (True, 8941,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (139) & Character'Val (175) then
            return
              (True, 8943,
               Inner, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (139) & Character'Val (177) then
            return
              (True, 8945,
               Inner, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (140) & Character'Val (136) then
            return
              (True, 8968,
               Opening, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (140) & Character'Val (137) then
            return
              (True, 8969,
               Closing, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (140) & Character'Val (138) then
            return
              (True, 8970,
               Opening, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (140) & Character'Val (139) then
            return
              (True, 8971,
               Closing, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (140) & Character'Val (162) then
            return
              (True, 8994,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (140) & Character'Val (163) then
            return
              (True, 8995,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (142) & Character'Val (176) then
            return
              (True, 9136,
               Opening, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (142) & Character'Val (177) then
            return
              (True, 9137,
               Closing, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (148) & Character'Val (140) then
            return
              (True, 9484,
               Opening, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (148) & Character'Val (144) then
            return
              (True, 9488,
               Closing, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (148) & Character'Val (148) then
            return
              (True, 9492,
               Opening, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (148) & Character'Val (152) then
            return
              (True, 9496,
               Closing, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (151) & Character'Val (175) then
            return
              (True, 9711,
               Binary_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (153) & Character'Val (160) then
            return
              (True, 9824,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (153) & Character'Val (161) then
            return
              (True, 9825,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (153) & Character'Val (162) then
            return
              (True, 9826,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (153) & Character'Val (163) then
            return
              (True, 9827,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (153) & Character'Val (173) then
            return
              (True, 9837,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (153) & Character'Val (174) then
            return
              (True, 9838,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (153) & Character'Val (175) then
            return
              (True, 9839,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (156) & Character'Val (147) then
            return
              (True, 10003,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (159) & Character'Val (168) then
            return
              (True, 10216,
               Opening, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (159) & Character'Val (169) then
            return
              (True, 10217,
               Closing, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (159) & Character'Val (174) then
            return
              (True, 10222,
               Opening, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (159) & Character'Val (175) then
            return
              (True, 10223,
               Closing, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (159) & Character'Val (181) then
            return
              (True, 10229,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (159) & Character'Val (182) then
            return
              (True, 10230,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (159) & Character'Val (183) then
            return
              (True, 10231,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (159) & Character'Val (184) then
            return
              (True, 10232,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (159) & Character'Val (185) then
            return
              (True, 10233,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (159) & Character'Val (186) then
            return
              (True, 10234,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (159) & Character'Val (188) then
            return
              (True, 10236,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (169) & Character'Val (158) then
            return
              (True, 10846,
               Binary_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (169) & Character'Val (189) then
            return
              (True, 10877,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (169) & Character'Val (190) then
            return
              (True, 10878,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (170) & Character'Val (133) then
            return
              (True, 10885,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (170) & Character'Val (134) then
            return
              (True, 10886,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (170) & Character'Val (135) then
            return
              (True, 10887,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (170) & Character'Val (136) then
            return
              (True, 10888,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (170) & Character'Val (137) then
            return
              (True, 10889,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (170) & Character'Val (138) then
            return
              (True, 10890,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (170) & Character'Val (139) then
            return
              (True, 10891,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (170) & Character'Val (140) then
            return
              (True, 10892,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (170) & Character'Val (149) then
            return
              (True, 10901,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (170) & Character'Val (150) then
            return
              (True, 10902,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (170) & Character'Val (175) then
            return
              (True, 10927,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (170) & Character'Val (176) then
            return
              (True, 10928,
               Relation_Atom, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (170) & Character'Val (181) then
            return
              (True, 10933,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (170) & Character'Val (182) then
            return
              (True, 10934,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (170) & Character'Val (183) then
            return
              (True, 10935,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (170) & Character'Val (184) then
            return
              (True, 10936,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (170) & Character'Val (185) then
            return
              (True, 10937,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (170) & Character'Val (186) then
            return
              (True, 10938,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (171) & Character'Val (133) then
            return
              (True, 10949,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (171) & Character'Val (134) then
            return
              (True, 10950,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (171) & Character'Val (139) then
            return
              (True, 10955,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (171) & Character'Val (140) then
            return
              (True, 10956,
               Relation_Atom, AMS_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (128) then
            return
              (True, 65,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (129) then
            return
              (True, 66,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (130) then
            return
              (True, 67,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (131) then
            return
              (True, 68,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (132) then
            return
              (True, 69,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (133) then
            return
              (True, 70,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (134) then
            return
              (True, 71,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (135) then
            return
              (True, 72,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (136) then
            return
              (True, 73,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (137) then
            return
              (True, 74,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (138) then
            return
              (True, 75,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (139) then
            return
              (True, 76,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (140) then
            return
              (True, 77,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (141) then
            return
              (True, 78,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (142) then
            return
              (True, 79,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (143) then
            return
              (True, 80,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (144) then
            return
              (True, 81,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (145) then
            return
              (True, 82,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (146) then
            return
              (True, 83,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (147) then
            return
              (True, 84,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (148) then
            return
              (True, 85,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (149) then
            return
              (True, 86,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (150) then
            return
              (True, 87,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (151) then
            return
              (True, 88,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (152) then
            return
              (True, 89,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (153) then
            return
              (True, 90,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (154) then
            return
              (True, 97,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (155) then
            return
              (True, 98,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (156) then
            return
              (True, 99,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (157) then
            return
              (True, 100,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (158) then
            return
              (True, 101,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (159) then
            return
              (True, 102,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (160) then
            return
              (True, 103,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (161) then
            return
              (True, 104,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (162) then
            return
              (True, 105,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (163) then
            return
              (True, 106,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (164) then
            return
              (True, 107,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (165) then
            return
              (True, 108,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (166) then
            return
              (True, 109,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (167) then
            return
              (True, 110,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (168) then
            return
              (True, 111,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (169) then
            return
              (True, 112,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (170) then
            return
              (True, 113,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (171) then
            return
              (True, 114,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (172) then
            return
              (True, 115,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (173) then
            return
              (True, 116,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (174) then
            return
              (True, 117,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (175) then
            return
              (True, 118,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (176) then
            return
              (True, 119,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (177) then
            return
              (True, 120,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (178) then
            return
              (True, 121,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (179) then
            return
              (True, 122,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (180) then
            return
              (True, 65,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (181) then
            return
              (True, 66,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (182) then
            return
              (True, 67,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (183) then
            return
              (True, 68,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (184) then
            return
              (True, 69,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (185) then
            return
              (True, 70,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (186) then
            return
              (True, 71,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (187) then
            return
              (True, 72,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (188) then
            return
              (True, 73,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (189) then
            return
              (True, 74,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (190) then
            return
              (True, 75,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (191) then
            return
              (True, 76,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (128) then
            return
              (True, 77,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (129) then
            return
              (True, 78,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (130) then
            return
              (True, 79,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (131) then
            return
              (True, 80,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (132) then
            return
              (True, 81,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (133) then
            return
              (True, 82,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (134) then
            return
              (True, 83,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (135) then
            return
              (True, 84,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (136) then
            return
              (True, 85,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (137) then
            return
              (True, 86,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (138) then
            return
              (True, 87,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (139) then
            return
              (True, 88,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (140) then
            return
              (True, 89,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (141) then
            return
              (True, 90,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (142) then
            return
              (True, 97,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (143) then
            return
              (True, 98,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (144) then
            return
              (True, 99,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (145) then
            return
              (True, 100,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (146) then
            return
              (True, 101,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (147) then
            return
              (True, 102,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (148) then
            return
              (True, 103,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (149) then
            return
              (True, 104,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (150) then
            return
              (True, 105,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (151) then
            return
              (True, 106,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (152) then
            return
              (True, 107,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (153) then
            return
              (True, 108,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (154) then
            return
              (True, 109,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (155) then
            return
              (True, 110,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (156) then
            return
              (True, 111,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (157) then
            return
              (True, 112,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (158) then
            return
              (True, 113,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (159) then
            return
              (True, 114,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (160) then
            return
              (True, 115,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (161) then
            return
              (True, 116,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (162) then
            return
              (True, 117,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (163) then
            return
              (True, 118,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (164) then
            return
              (True, 119,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (165) then
            return
              (True, 120,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (166) then
            return
              (True, 121,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (167) then
            return
              (True, 122,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (168) then
            return
              (True, 65,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (169) then
            return
              (True, 66,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (170) then
            return
              (True, 67,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (171) then
            return
              (True, 68,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (172) then
            return
              (True, 69,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (173) then
            return
              (True, 70,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (174) then
            return
              (True, 71,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (175) then
            return
              (True, 72,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (176) then
            return
              (True, 73,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (177) then
            return
              (True, 74,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (178) then
            return
              (True, 75,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (179) then
            return
              (True, 76,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (180) then
            return
              (True, 77,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (181) then
            return
              (True, 78,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (182) then
            return
              (True, 79,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (183) then
            return
              (True, 80,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (184) then
            return
              (True, 81,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (185) then
            return
              (True, 82,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (186) then
            return
              (True, 83,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (187) then
            return
              (True, 84,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (188) then
            return
              (True, 85,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (189) then
            return
              (True, 86,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (190) then
            return
              (True, 87,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (191) then
            return
              (True, 88,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (128) then
            return
              (True, 89,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (129) then
            return
              (True, 90,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (130) then
            return
              (True, 97,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (131) then
            return
              (True, 98,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (132) then
            return
              (True, 99,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (133) then
            return
              (True, 100,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (134) then
            return
              (True, 101,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (135) then
            return
              (True, 102,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (136) then
            return
              (True, 103,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (137) then
            return
              (True, 104,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (138) then
            return
              (True, 105,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (139) then
            return
              (True, 106,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (140) then
            return
              (True, 107,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (141) then
            return
              (True, 108,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (142) then
            return
              (True, 109,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (143) then
            return
              (True, 110,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (144) then
            return
              (True, 111,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (145) then
            return
              (True, 112,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (146) then
            return
              (True, 113,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (147) then
            return
              (True, 114,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (148) then
            return
              (True, 115,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (149) then
            return
              (True, 116,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (150) then
            return
              (True, 117,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (151) then
            return
              (True, 118,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (152) then
            return
              (True, 119,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (153) then
            return
              (True, 120,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (154) then
            return
              (True, 121,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (155) then
            return
              (True, 122,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (156) then
            return
              (True, 65,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (157) then
            return
              (True, 66,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (158) then
            return
              (True, 67,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (159) then
            return
              (True, 68,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (160) then
            return
              (True, 69,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (161) then
            return
              (True, 70,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (162) then
            return
              (True, 71,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (163) then
            return
              (True, 72,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (164) then
            return
              (True, 73,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (165) then
            return
              (True, 74,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (166) then
            return
              (True, 75,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (167) then
            return
              (True, 76,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (168) then
            return
              (True, 77,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (169) then
            return
              (True, 78,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (170) then
            return
              (True, 79,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (171) then
            return
              (True, 80,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (172) then
            return
              (True, 81,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (173) then
            return
              (True, 82,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (174) then
            return
              (True, 83,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (175) then
            return
              (True, 84,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (176) then
            return
              (True, 85,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (177) then
            return
              (True, 86,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (178) then
            return
              (True, 87,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (179) then
            return
              (True, 88,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (180) then
            return
              (True, 89,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (181) then
            return
              (True, 90,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (132) then
            return
              (True, 65,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (133) then
            return
              (True, 66,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (134) then
            return
              (True, 67,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (135) then
            return
              (True, 68,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (136) then
            return
              (True, 69,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (137) then
            return
              (True, 70,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (138) then
            return
              (True, 71,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (139) then
            return
              (True, 72,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (140) then
            return
              (True, 73,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (141) then
            return
              (True, 74,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (142) then
            return
              (True, 75,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (143) then
            return
              (True, 76,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (144) then
            return
              (True, 77,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (145) then
            return
              (True, 78,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (146) then
            return
              (True, 79,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (147) then
            return
              (True, 80,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (148) then
            return
              (True, 81,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (149) then
            return
              (True, 82,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (150) then
            return
              (True, 83,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (151) then
            return
              (True, 84,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (152) then
            return
              (True, 85,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (153) then
            return
              (True, 86,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (154) then
            return
              (True, 87,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (155) then
            return
              (True, 88,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (156) then
            return
              (True, 89,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (157) then
            return
              (True, 90,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (158) then
            return
              (True, 97,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (159) then
            return
              (True, 98,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (160) then
            return
              (True, 99,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (161) then
            return
              (True, 100,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (162) then
            return
              (True, 101,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (163) then
            return
              (True, 102,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (164) then
            return
              (True, 103,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (165) then
            return
              (True, 104,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (166) then
            return
              (True, 105,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (167) then
            return
              (True, 106,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (168) then
            return
              (True, 107,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (169) then
            return
              (True, 108,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (170) then
            return
              (True, 109,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (171) then
            return
              (True, 110,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (172) then
            return
              (True, 111,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (173) then
            return
              (True, 112,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (174) then
            return
              (True, 113,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (175) then
            return
              (True, 114,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (176) then
            return
              (True, 115,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (177) then
            return
              (True, 116,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (178) then
            return
              (True, 117,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (179) then
            return
              (True, 118,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (180) then
            return
              (True, 119,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (181) then
            return
              (True, 120,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (182) then
            return
              (True, 121,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (183) then
            return
              (True, 122,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (184) then
            return
              (True, 65,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (185) then
            return
              (True, 66,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (186) then
            return
              (True, 67,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (187) then
            return
              (True, 68,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (188) then
            return
              (True, 69,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (189) then
            return
              (True, 70,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (190) then
            return
              (True, 71,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (191) then
            return
              (True, 72,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (128) then
            return
              (True, 73,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (129) then
            return
              (True, 74,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (130) then
            return
              (True, 75,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (131) then
            return
              (True, 76,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (132) then
            return
              (True, 77,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (133) then
            return
              (True, 78,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (134) then
            return
              (True, 79,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (135) then
            return
              (True, 80,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (136) then
            return
              (True, 81,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (137) then
            return
              (True, 82,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (138) then
            return
              (True, 83,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (139) then
            return
              (True, 84,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (140) then
            return
              (True, 85,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (141) then
            return
              (True, 86,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (142) then
            return
              (True, 87,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (143) then
            return
              (True, 88,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (144) then
            return
              (True, 89,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (145) then
            return
              (True, 90,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (156) then
            return
              (True, 107,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (172) then
            return
              (True, 65,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (173) then
            return
              (True, 66,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (174) then
            return
              (True, 67,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (175) then
            return
              (True, 68,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (176) then
            return
              (True, 69,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (177) then
            return
              (True, 70,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (178) then
            return
              (True, 71,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (179) then
            return
              (True, 72,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (180) then
            return
              (True, 73,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (181) then
            return
              (True, 74,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (182) then
            return
              (True, 75,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (183) then
            return
              (True, 76,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (184) then
            return
              (True, 77,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (185) then
            return
              (True, 78,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (186) then
            return
              (True, 79,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (187) then
            return
              (True, 80,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (188) then
            return
              (True, 81,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (189) then
            return
              (True, 82,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (190) then
            return
              (True, 83,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (191) then
            return
              (True, 84,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (128) then
            return
              (True, 85,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (129) then
            return
              (True, 86,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (130) then
            return
              (True, 87,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (131) then
            return
              (True, 88,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (132) then
            return
              (True, 89,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (133) then
            return
              (True, 90,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (134) then
            return
              (True, 97,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (135) then
            return
              (True, 98,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (136) then
            return
              (True, 99,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (137) then
            return
              (True, 100,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (138) then
            return
              (True, 101,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (139) then
            return
              (True, 102,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (140) then
            return
              (True, 103,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (141) then
            return
              (True, 104,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (142) then
            return
              (True, 105,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (143) then
            return
              (True, 106,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (144) then
            return
              (True, 107,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (145) then
            return
              (True, 108,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (146) then
            return
              (True, 109,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (147) then
            return
              (True, 110,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (148) then
            return
              (True, 111,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (149) then
            return
              (True, 112,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (150) then
            return
              (True, 113,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (151) then
            return
              (True, 114,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (152) then
            return
              (True, 115,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (153) then
            return
              (True, 116,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (154) then
            return
              (True, 117,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (155) then
            return
              (True, 118,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (156) then
            return
              (True, 119,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (157) then
            return
              (True, 120,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (158) then
            return
              (True, 121,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (159) then
            return
              (True, 122,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (160) then
            return
              (True, 65,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (161) then
            return
              (True, 66,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (162) then
            return
              (True, 67,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (163) then
            return
              (True, 68,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (164) then
            return
              (True, 69,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (165) then
            return
              (True, 70,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (166) then
            return
              (True, 71,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (167) then
            return
              (True, 72,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (168) then
            return
              (True, 73,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (169) then
            return
              (True, 74,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (170) then
            return
              (True, 75,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (171) then
            return
              (True, 76,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (172) then
            return
              (True, 77,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (173) then
            return
              (True, 78,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (174) then
            return
              (True, 79,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (175) then
            return
              (True, 80,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (176) then
            return
              (True, 81,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (177) then
            return
              (True, 82,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (178) then
            return
              (True, 83,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (179) then
            return
              (True, 84,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (180) then
            return
              (True, 85,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (181) then
            return
              (True, 86,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (182) then
            return
              (True, 87,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (183) then
            return
              (True, 88,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (184) then
            return
              (True, 89,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (185) then
            return
              (True, 90,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (186) then
            return
              (True, 97,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (187) then
            return
              (True, 98,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (188) then
            return
              (True, 99,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (189) then
            return
              (True, 100,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (190) then
            return
              (True, 101,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (191) then
            return
              (True, 102,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (128) then
            return
              (True, 103,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (129) then
            return
              (True, 104,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (130) then
            return
              (True, 105,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (131) then
            return
              (True, 106,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (132) then
            return
              (True, 107,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (133) then
            return
              (True, 108,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (134) then
            return
              (True, 109,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (135) then
            return
              (True, 110,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (136) then
            return
              (True, 111,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (137) then
            return
              (True, 112,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (138) then
            return
              (True, 113,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (139) then
            return
              (True, 114,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (140) then
            return
              (True, 115,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (141) then
            return
              (True, 116,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (142) then
            return
              (True, 117,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (143) then
            return
              (True, 118,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (144) then
            return
              (True, 119,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (145) then
            return
              (True, 120,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (146) then
            return
              (True, 121,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (147) then
            return
              (True, 122,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (148) then
            return
              (True, 65,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (149) then
            return
              (True, 66,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (150) then
            return
              (True, 67,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (151) then
            return
              (True, 68,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (152) then
            return
              (True, 69,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (153) then
            return
              (True, 70,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (154) then
            return
              (True, 71,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (155) then
            return
              (True, 72,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (156) then
            return
              (True, 73,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (157) then
            return
              (True, 74,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (158) then
            return
              (True, 75,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (159) then
            return
              (True, 76,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (160) then
            return
              (True, 77,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (161) then
            return
              (True, 78,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (162) then
            return
              (True, 79,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (163) then
            return
              (True, 80,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (164) then
            return
              (True, 81,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (165) then
            return
              (True, 82,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (166) then
            return
              (True, 83,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (167) then
            return
              (True, 84,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (168) then
            return
              (True, 85,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (169) then
            return
              (True, 86,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (170) then
            return
              (True, 87,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (171) then
            return
              (True, 88,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (172) then
            return
              (True, 89,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (173) then
            return
              (True, 90,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (174) then
            return
              (True, 97,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (175) then
            return
              (True, 98,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (176) then
            return
              (True, 99,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (177) then
            return
              (True, 100,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (178) then
            return
              (True, 101,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (179) then
            return
              (True, 102,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (180) then
            return
              (True, 103,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (181) then
            return
              (True, 104,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (182) then
            return
              (True, 105,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (183) then
            return
              (True, 106,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (184) then
            return
              (True, 107,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (185) then
            return
              (True, 108,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (186) then
            return
              (True, 109,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (187) then
            return
              (True, 110,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (188) then
            return
              (True, 111,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (189) then
            return
              (True, 112,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (190) then
            return
              (True, 113,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (191) then
            return
              (True, 114,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (128) then
            return
              (True, 115,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (129) then
            return
              (True, 116,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (130) then
            return
              (True, 117,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (131) then
            return
              (True, 118,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (132) then
            return
              (True, 119,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (133) then
            return
              (True, 120,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (134) then
            return
              (True, 121,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (135) then
            return
              (True, 122,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (136) then
            return
              (True, 65,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (137) then
            return
              (True, 66,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (138) then
            return
              (True, 67,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (139) then
            return
              (True, 68,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (140) then
            return
              (True, 69,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (141) then
            return
              (True, 70,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (142) then
            return
              (True, 71,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (143) then
            return
              (True, 72,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (144) then
            return
              (True, 73,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (145) then
            return
              (True, 74,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (146) then
            return
              (True, 75,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (147) then
            return
              (True, 76,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (148) then
            return
              (True, 77,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (149) then
            return
              (True, 78,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (150) then
            return
              (True, 79,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (151) then
            return
              (True, 80,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (152) then
            return
              (True, 81,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (153) then
            return
              (True, 82,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (154) then
            return
              (True, 83,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (155) then
            return
              (True, 84,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (156) then
            return
              (True, 85,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (157) then
            return
              (True, 86,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (158) then
            return
              (True, 87,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (159) then
            return
              (True, 88,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (160) then
            return
              (True, 89,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (161) then
            return
              (True, 90,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (162) then
            return
              (True, 97,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (163) then
            return
              (True, 98,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (164) then
            return
              (True, 99,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (165) then
            return
              (True, 100,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (166) then
            return
              (True, 101,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (167) then
            return
              (True, 102,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (168) then
            return
              (True, 103,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (169) then
            return
              (True, 104,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (170) then
            return
              (True, 105,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (171) then
            return
              (True, 106,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (172) then
            return
              (True, 107,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (173) then
            return
              (True, 108,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (174) then
            return
              (True, 109,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (175) then
            return
              (True, 110,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (176) then
            return
              (True, 111,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (177) then
            return
              (True, 112,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (178) then
            return
              (True, 113,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (179) then
            return
              (True, 114,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (180) then
            return
              (True, 115,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (181) then
            return
              (True, 116,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (182) then
            return
              (True, 117,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (183) then
            return
              (True, 118,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (184) then
            return
              (True, 119,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (185) then
            return
              (True, 120,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (186) then
            return
              (True, 121,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (187) then
            return
              (True, 122,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (153) & Character'Val (176) then
            return
              (True, 65,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (153) & Character'Val (177) then
            return
              (True, 66,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (153) & Character'Val (178) then
            return
              (True, 67,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (153) & Character'Val (179) then
            return
              (True, 68,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (153) & Character'Val (180) then
            return
              (True, 69,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (153) & Character'Val (181) then
            return
              (True, 70,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (153) & Character'Val (182) then
            return
              (True, 71,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (153) & Character'Val (183) then
            return
              (True, 72,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (153) & Character'Val (184) then
            return
              (True, 73,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (153) & Character'Val (185) then
            return
              (True, 74,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (153) & Character'Val (186) then
            return
              (True, 75,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (153) & Character'Val (187) then
            return
              (True, 76,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (153) & Character'Val (188) then
            return
              (True, 77,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (153) & Character'Val (189) then
            return
              (True, 78,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (153) & Character'Val (190) then
            return
              (True, 79,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (153) & Character'Val (191) then
            return
              (True, 80,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (128) then
            return
              (True, 81,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (129) then
            return
              (True, 82,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (130) then
            return
              (True, 83,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (131) then
            return
              (True, 84,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (132) then
            return
              (True, 85,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (133) then
            return
              (True, 86,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (134) then
            return
              (True, 87,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (135) then
            return
              (True, 88,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (136) then
            return
              (True, 89,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (137) then
            return
              (True, 90,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (138) then
            return
              (True, 97,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (139) then
            return
              (True, 98,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (140) then
            return
              (True, 99,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (141) then
            return
              (True, 100,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (142) then
            return
              (True, 101,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (143) then
            return
              (True, 102,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (144) then
            return
              (True, 103,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (145) then
            return
              (True, 104,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (146) then
            return
              (True, 105,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (147) then
            return
              (True, 106,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (148) then
            return
              (True, 107,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (149) then
            return
              (True, 108,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (150) then
            return
              (True, 109,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (151) then
            return
              (True, 110,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (152) then
            return
              (True, 111,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (153) then
            return
              (True, 112,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (154) then
            return
              (True, 113,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (155) then
            return
              (True, 114,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (156) then
            return
              (True, 115,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (157) then
            return
              (True, 116,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (158) then
            return
              (True, 117,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (159) then
            return
              (True, 118,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (160) then
            return
              (True, 119,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (161) then
            return
              (True, 120,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (162) then
            return
              (True, 121,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (163) then
            return
              (True, 122,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (142) then
            return
              (True, 48,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (143) then
            return
              (True, 49,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (144) then
            return
              (True, 50,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (145) then
            return
              (True, 51,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (146) then
            return
              (True, 52,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (147) then
            return
              (True, 53,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (148) then
            return
              (True, 54,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (149) then
            return
              (True, 55,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (150) then
            return
              (True, 56,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (151) then
            return
              (True, 57,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (162) then
            return
              (True, 48,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (163) then
            return
              (True, 49,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (164) then
            return
              (True, 50,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (165) then
            return
              (True, 51,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (166) then
            return
              (True, 52,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (167) then
            return
              (True, 53,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (168) then
            return
              (True, 54,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (169) then
            return
              (True, 55,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (170) then
            return
              (True, 56,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (171) then
            return
              (True, 57,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (172) then
            return
              (True, 48,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (173) then
            return
              (True, 49,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (174) then
            return
              (True, 50,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (175) then
            return
              (True, 51,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (176) then
            return
              (True, 52,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (177) then
            return
              (True, 53,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (178) then
            return
              (True, 54,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (179) then
            return
              (True, 55,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (180) then
            return
              (True, 56,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (181) then
            return
              (True, 57,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (182) then
            return
              (True, 48,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (183) then
            return
              (True, 49,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (184) then
            return
              (True, 50,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (185) then
            return
              (True, 51,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (186) then
            return
              (True, 52,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (187) then
            return
              (True, 53,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (188) then
            return
              (True, 54,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (189) then
            return
              (True, 55,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (190) then
            return
              (True, 56,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (191) then
            return
              (True, 57,
               Ordinary, Math_Italic);
         end if;
      end if;
      if Text_Mode = True then
         if Name =
           "!" then
            return
              (True, 33,
               Ordinary, Main_Regular);
         end if;
         if Name =
           """" then
            return
              (True, 34,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "'" then
            return
              (True, 8217,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "'" & "'" then
            return
              (True, 8221,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "(" then
            return
              (True, 40,
               Ordinary, Main_Regular);
         end if;
         if Name =
           ")" then
            return
              (True, 41,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "*" then
            return
              (True, 42,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "+" then
            return
              (True, 43,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "," then
            return
              (True, 44,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "-" then
            return
              (True, 45,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "-" & "-" then
            return
              (True, 8211,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "-" & "-" & "-" then
            return
              (True, 8212,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "." then
            return
              (True, 46,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "/" then
            return
              (True, 47,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "0" then
            return
              (True, 48,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "1" then
            return
              (True, 49,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "2" then
            return
              (True, 50,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "3" then
            return
              (True, 51,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "4" then
            return
              (True, 52,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "5" then
            return
              (True, 53,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "6" then
            return
              (True, 54,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "7" then
            return
              (True, 55,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "8" then
            return
              (True, 56,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "9" then
            return
              (True, 57,
               Ordinary, Main_Regular);
         end if;
         if Name =
           ":" then
            return
              (True, 58,
               Ordinary, Main_Regular);
         end if;
         if Name =
           ";" then
            return
              (True, 59,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "<" then
            return
              (True, 60,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "=" then
            return
              (True, 61,
               Ordinary, Main_Regular);
         end if;
         if Name =
           ">" then
            return
              (True, 62,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "?" then
            return
              (True, 63,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "@" then
            return
              (True, 64,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "A" then
            return
              (True, 65,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "B" then
            return
              (True, 66,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "C" then
            return
              (True, 67,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "D" then
            return
              (True, 68,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "E" then
            return
              (True, 69,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "F" then
            return
              (True, 70,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "G" then
            return
              (True, 71,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "H" then
            return
              (True, 72,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "I" then
            return
              (True, 73,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "J" then
            return
              (True, 74,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "K" then
            return
              (True, 75,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "L" then
            return
              (True, 76,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "M" then
            return
              (True, 77,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "N" then
            return
              (True, 78,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "O" then
            return
              (True, 79,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "P" then
            return
              (True, 80,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "Q" then
            return
              (True, 81,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "R" then
            return
              (True, 82,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "S" then
            return
              (True, 83,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "T" then
            return
              (True, 84,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "U" then
            return
              (True, 85,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "V" then
            return
              (True, 86,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "W" then
            return
              (True, 87,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "X" then
            return
              (True, 88,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "Y" then
            return
              (True, 89,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "Z" then
            return
              (True, 90,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "[" then
            return
              (True, 91,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "#" then
            return
              (True, 35,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "$" then
            return
              (True, 36,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "%" then
            return
              (True, 37,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "&" then
            return
              (True, 38,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "A" & "E" then
            return
              (True, 198,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "O" then
            return
              (True, 216,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "O" & "E" then
            return
              (True, 338,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "P" then
            return
              (True, 182,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "S" then
            return
              (True, 167,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "_" then
            return
              (True, 95,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "a" & "e" then
            return
              (True, 230,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "c" & "h" & "e" & "c" & "k" & "m" & "a" & "r" & "k" then
            return
              (True, 10003,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           "\" & "c" & "i" & "r" & "c" & "l" & "e" & "d" & "R" then
            return
              (True, 174,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           "\" & "d" & "a" & "g" then
            return
              (True, 8224,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "d" & "d" & "a" & "g" then
            return
              (True, 8225,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "d" & "e" & "g" & "r" & "e" & "e" then
            return
              (True, 176,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "i" then
            return
              (True, 305,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "j" then
            return
              (True, 567,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "l" & "b" & "r" & "a" & "c" & "k" then
            return
              (True, 91,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "l" & "d" & "o" & "t" & "s" then
            return
              (True, 8230,
               Inner, Main_Regular);
         end if;
         if Name =
           "\" & "m" & "a" & "l" & "t" & "e" & "s" & "e" then
            return
              (True, 10016,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           "\" & "o" then
            return
              (True, 248,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "o" & "e" then
            return
              (True, 339,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "p" & "o" & "u" & "n" & "d" & "s" then
            return
              (True, 163,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "r" & "b" & "r" & "a" & "c" & "k" then
            return
              (True, 93,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "s" & "s" then
            return
              (True, 223,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "t" & "e" & "x" & "t" & "a" & "s" & "c" & "i" & "i" & "c" & "i" & "r" & "c" & "u" & "m" then
            return
              (True, 94,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "t" & "e" & "x" & "t" & "a" & "s" & "c" & "i" & "i" & "t" & "i" & "l" & "d" & "e" then
            return
              (True, 126,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "t" & "e" & "x" & "t" & "b" & "a" & "c" & "k" & "s" & "l" & "a" & "s" & "h" then
            return
              (True, 92,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "t" & "e" & "x" & "t" & "b" & "a" & "r" then
            return
              (True, 124,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "t" & "e" & "x" & "t" & "b" & "a" & "r" & "d" & "b" & "l" then
            return
              (True, 8741,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "t" & "e" & "x" & "t" & "b" & "r" & "a" & "c" & "e" & "l" & "e" & "f" & "t" then
            return
              (True, 123,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "t" & "e" & "x" & "t" & "b" & "r" & "a" & "c" & "e" & "r" & "i" & "g" & "h" & "t" then
            return
              (True, 125,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "t" & "e" & "x" & "t" & "d" & "a" & "g" & "g" & "e" & "r" then
            return
              (True, 8224,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "t" & "e" & "x" & "t" & "d" & "a" & "g" & "g" & "e" & "r" & "d" & "b" & "l" then
            return
              (True, 8225,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "t" & "e" & "x" & "t" & "d" & "e" & "g" & "r" & "e" & "e" then
            return
              (True, 176,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "t" & "e" & "x" & "t" & "d" & "o" & "l" & "l" & "a" & "r" then
            return
              (True, 36,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "t" & "e" & "x" & "t" & "e" & "l" & "l" & "i" & "p" & "s" & "i" & "s" then
            return
              (True, 8230,
               Inner, Main_Regular);
         end if;
         if Name =
           "\" & "t" & "e" & "x" & "t" & "e" & "m" & "d" & "a" & "s" & "h" then
            return
              (True, 8212,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "t" & "e" & "x" & "t" & "e" & "n" & "d" & "a" & "s" & "h" then
            return
              (True, 8211,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "t" & "e" & "x" & "t" & "g" & "r" & "e" & "a" & "t" & "e" & "r" then
            return
              (True, 62,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "t" & "e" & "x" & "t" & "l" & "e" & "s" & "s" then
            return
              (True, 60,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "t" & "e" & "x" & "t" & "q" & "u" & "o" & "t" & "e" & "d" & "b" & "l" & "l" & "e" & "f" & "t" then
            return
              (True, 8220,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "t" & "e" & "x" & "t" & "q" & "u" & "o" & "t" & "e" & "d" & "b" & "l" & "r" & "i" & "g" & "h" & "t" then
            return
              (True, 8221,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "t" & "e" & "x" & "t" & "q" & "u" & "o" & "t" & "e" & "l" & "e" & "f" & "t" then
            return
              (True, 8216,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "t" & "e" & "x" & "t" & "q" & "u" & "o" & "t" & "e" & "r" & "i" & "g" & "h" & "t" then
            return
              (True, 8217,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "t" & "e" & "x" & "t" & "s" & "t" & "e" & "r" & "l" & "i" & "n" & "g" then
            return
              (True, 163,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "t" & "e" & "x" & "t" & "u" & "n" & "d" & "e" & "r" & "s" & "c" & "o" & "r" & "e" then
            return
              (True, 95,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "v" & "a" & "r" & "v" & "d" & "o" & "t" & "s" then
            return
              (True, 8942,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "y" & "e" & "n" then
            return
              (True, 165,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           "\" & "{" then
            return
              (True, 123,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "\" & "}" then
            return
              (True, 125,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "]" then
            return
              (True, 93,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "`" then
            return
              (True, 8216,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "`" & "`" then
            return
              (True, 8220,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "a" then
            return
              (True, 97,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "b" then
            return
              (True, 98,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "c" then
            return
              (True, 99,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "d" then
            return
              (True, 100,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "e" then
            return
              (True, 101,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "f" then
            return
              (True, 102,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "g" then
            return
              (True, 103,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "h" then
            return
              (True, 104,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "i" then
            return
              (True, 105,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "j" then
            return
              (True, 106,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "k" then
            return
              (True, 107,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "l" then
            return
              (True, 108,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "m" then
            return
              (True, 109,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "n" then
            return
              (True, 110,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "o" then
            return
              (True, 111,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "p" then
            return
              (True, 112,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "q" then
            return
              (True, 113,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "r" then
            return
              (True, 114,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "s" then
            return
              (True, 115,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "t" then
            return
              (True, 116,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "u" then
            return
              (True, 117,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "v" then
            return
              (True, 118,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "w" then
            return
              (True, 119,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "x" then
            return
              (True, 120,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "y" then
            return
              (True, 121,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "z" then
            return
              (True, 122,
               Ordinary, Main_Regular);
         end if;
         if Name =
           "|" then
            return
              (True, 124,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (194) & Character'Val (163) then
            return
              (True, 163,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (194) & Character'Val (165) then
            return
              (True, 165,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           Character'Val (194) & Character'Val (176) then
            return
              (True, 176,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (195) & Character'Val (134) then
            return
              (True, 198,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (195) & Character'Val (144) then
            return
              (True, 208,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (195) & Character'Val (152) then
            return
              (True, 216,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (195) & Character'Val (158) then
            return
              (True, 222,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (195) & Character'Val (159) then
            return
              (True, 223,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (195) & Character'Val (166) then
            return
              (True, 230,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (195) & Character'Val (176) then
            return
              (True, 240,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (195) & Character'Val (184) then
            return
              (True, 248,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (195) & Character'Val (190) then
            return
              (True, 254,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (196) & Character'Val (177) then
            return
              (True, 305,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (197) & Character'Val (146) then
            return
              (True, 338,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (197) & Character'Val (147) then
            return
              (True, 339,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (200) & Character'Val (183) then
            return
              (True, 567,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (128) & Character'Val (147) then
            return
              (True, 8211,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (128) & Character'Val (148) then
            return
              (True, 8212,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (128) & Character'Val (152) then
            return
              (True, 8216,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (128) & Character'Val (153) then
            return
              (True, 8217,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (128) & Character'Val (156) then
            return
              (True, 8220,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (128) & Character'Val (157) then
            return
              (True, 8221,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (128) & Character'Val (166) then
            return
              (True, 8230,
               Inner, Main_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (132) & Character'Val (130) then
            return
              (True, 67,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (132) & Character'Val (141) then
            return
              (True, 72,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (132) & Character'Val (142) then
            return
              (True, 104,
               Ordinary, Math_Italic);
         end if;
         if Name =
           Character'Val (226) & Character'Val (132) & Character'Val (149) then
            return
              (True, 78,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (132) & Character'Val (153) then
            return
              (True, 80,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (132) & Character'Val (154) then
            return
              (True, 81,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (132) & Character'Val (157) then
            return
              (True, 82,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           Character'Val (226) & Character'Val (132) & Character'Val (164) then
            return
              (True, 90,
               Ordinary, AMS_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (128) then
            return
              (True, 65,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (129) then
            return
              (True, 66,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (130) then
            return
              (True, 67,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (131) then
            return
              (True, 68,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (132) then
            return
              (True, 69,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (133) then
            return
              (True, 70,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (134) then
            return
              (True, 71,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (135) then
            return
              (True, 72,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (136) then
            return
              (True, 73,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (137) then
            return
              (True, 74,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (138) then
            return
              (True, 75,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (139) then
            return
              (True, 76,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (140) then
            return
              (True, 77,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (141) then
            return
              (True, 78,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (142) then
            return
              (True, 79,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (143) then
            return
              (True, 80,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (144) then
            return
              (True, 81,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (145) then
            return
              (True, 82,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (146) then
            return
              (True, 83,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (147) then
            return
              (True, 84,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (148) then
            return
              (True, 85,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (149) then
            return
              (True, 86,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (150) then
            return
              (True, 87,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (151) then
            return
              (True, 88,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (152) then
            return
              (True, 89,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (153) then
            return
              (True, 90,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (154) then
            return
              (True, 97,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (155) then
            return
              (True, 98,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (156) then
            return
              (True, 99,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (157) then
            return
              (True, 100,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (158) then
            return
              (True, 101,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (159) then
            return
              (True, 102,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (160) then
            return
              (True, 103,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (161) then
            return
              (True, 104,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (162) then
            return
              (True, 105,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (163) then
            return
              (True, 106,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (164) then
            return
              (True, 107,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (165) then
            return
              (True, 108,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (166) then
            return
              (True, 109,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (167) then
            return
              (True, 110,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (168) then
            return
              (True, 111,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (169) then
            return
              (True, 112,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (170) then
            return
              (True, 113,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (171) then
            return
              (True, 114,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (172) then
            return
              (True, 115,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (173) then
            return
              (True, 116,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (174) then
            return
              (True, 117,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (175) then
            return
              (True, 118,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (176) then
            return
              (True, 119,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (177) then
            return
              (True, 120,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (178) then
            return
              (True, 121,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (179) then
            return
              (True, 122,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (180) then
            return
              (True, 65,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (181) then
            return
              (True, 66,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (182) then
            return
              (True, 67,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (183) then
            return
              (True, 68,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (184) then
            return
              (True, 69,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (185) then
            return
              (True, 70,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (186) then
            return
              (True, 71,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (187) then
            return
              (True, 72,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (188) then
            return
              (True, 73,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (189) then
            return
              (True, 74,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (190) then
            return
              (True, 75,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (144) & Character'Val (191) then
            return
              (True, 76,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (128) then
            return
              (True, 77,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (129) then
            return
              (True, 78,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (130) then
            return
              (True, 79,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (131) then
            return
              (True, 80,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (132) then
            return
              (True, 81,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (133) then
            return
              (True, 82,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (134) then
            return
              (True, 83,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (135) then
            return
              (True, 84,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (136) then
            return
              (True, 85,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (137) then
            return
              (True, 86,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (138) then
            return
              (True, 87,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (139) then
            return
              (True, 88,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (140) then
            return
              (True, 89,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (141) then
            return
              (True, 90,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (142) then
            return
              (True, 97,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (143) then
            return
              (True, 98,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (144) then
            return
              (True, 99,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (145) then
            return
              (True, 100,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (146) then
            return
              (True, 101,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (147) then
            return
              (True, 102,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (148) then
            return
              (True, 103,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (149) then
            return
              (True, 104,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (150) then
            return
              (True, 105,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (151) then
            return
              (True, 106,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (152) then
            return
              (True, 107,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (153) then
            return
              (True, 108,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (154) then
            return
              (True, 109,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (155) then
            return
              (True, 110,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (156) then
            return
              (True, 111,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (157) then
            return
              (True, 112,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (158) then
            return
              (True, 113,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (159) then
            return
              (True, 114,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (160) then
            return
              (True, 115,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (161) then
            return
              (True, 116,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (162) then
            return
              (True, 117,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (163) then
            return
              (True, 118,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (164) then
            return
              (True, 119,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (165) then
            return
              (True, 120,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (166) then
            return
              (True, 121,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (167) then
            return
              (True, 122,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (168) then
            return
              (True, 65,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (169) then
            return
              (True, 66,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (170) then
            return
              (True, 67,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (171) then
            return
              (True, 68,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (172) then
            return
              (True, 69,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (173) then
            return
              (True, 70,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (174) then
            return
              (True, 71,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (175) then
            return
              (True, 72,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (176) then
            return
              (True, 73,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (177) then
            return
              (True, 74,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (178) then
            return
              (True, 75,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (179) then
            return
              (True, 76,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (180) then
            return
              (True, 77,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (181) then
            return
              (True, 78,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (182) then
            return
              (True, 79,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (183) then
            return
              (True, 80,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (184) then
            return
              (True, 81,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (185) then
            return
              (True, 82,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (186) then
            return
              (True, 83,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (187) then
            return
              (True, 84,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (188) then
            return
              (True, 85,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (189) then
            return
              (True, 86,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (190) then
            return
              (True, 87,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (145) & Character'Val (191) then
            return
              (True, 88,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (128) then
            return
              (True, 89,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (129) then
            return
              (True, 90,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (130) then
            return
              (True, 97,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (131) then
            return
              (True, 98,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (132) then
            return
              (True, 99,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (133) then
            return
              (True, 100,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (134) then
            return
              (True, 101,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (135) then
            return
              (True, 102,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (136) then
            return
              (True, 103,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (137) then
            return
              (True, 104,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (138) then
            return
              (True, 105,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (139) then
            return
              (True, 106,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (140) then
            return
              (True, 107,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (141) then
            return
              (True, 108,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (142) then
            return
              (True, 109,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (143) then
            return
              (True, 110,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (144) then
            return
              (True, 111,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (145) then
            return
              (True, 112,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (146) then
            return
              (True, 113,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (147) then
            return
              (True, 114,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (148) then
            return
              (True, 115,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (149) then
            return
              (True, 116,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (150) then
            return
              (True, 117,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (151) then
            return
              (True, 118,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (152) then
            return
              (True, 119,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (153) then
            return
              (True, 120,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (154) then
            return
              (True, 121,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (155) then
            return
              (True, 122,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (156) then
            return
              (True, 65,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (157) then
            return
              (True, 66,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (158) then
            return
              (True, 67,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (159) then
            return
              (True, 68,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (160) then
            return
              (True, 69,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (161) then
            return
              (True, 70,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (162) then
            return
              (True, 71,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (163) then
            return
              (True, 72,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (164) then
            return
              (True, 73,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (165) then
            return
              (True, 74,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (166) then
            return
              (True, 75,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (167) then
            return
              (True, 76,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (168) then
            return
              (True, 77,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (169) then
            return
              (True, 78,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (170) then
            return
              (True, 79,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (171) then
            return
              (True, 80,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (172) then
            return
              (True, 81,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (173) then
            return
              (True, 82,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (174) then
            return
              (True, 83,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (175) then
            return
              (True, 84,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (176) then
            return
              (True, 85,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (177) then
            return
              (True, 86,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (178) then
            return
              (True, 87,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (179) then
            return
              (True, 88,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (180) then
            return
              (True, 89,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (146) & Character'Val (181) then
            return
              (True, 90,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (132) then
            return
              (True, 65,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (133) then
            return
              (True, 66,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (134) then
            return
              (True, 67,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (135) then
            return
              (True, 68,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (136) then
            return
              (True, 69,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (137) then
            return
              (True, 70,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (138) then
            return
              (True, 71,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (139) then
            return
              (True, 72,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (140) then
            return
              (True, 73,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (141) then
            return
              (True, 74,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (142) then
            return
              (True, 75,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (143) then
            return
              (True, 76,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (144) then
            return
              (True, 77,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (145) then
            return
              (True, 78,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (146) then
            return
              (True, 79,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (147) then
            return
              (True, 80,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (148) then
            return
              (True, 81,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (149) then
            return
              (True, 82,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (150) then
            return
              (True, 83,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (151) then
            return
              (True, 84,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (152) then
            return
              (True, 85,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (153) then
            return
              (True, 86,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (154) then
            return
              (True, 87,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (155) then
            return
              (True, 88,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (156) then
            return
              (True, 89,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (157) then
            return
              (True, 90,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (158) then
            return
              (True, 97,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (159) then
            return
              (True, 98,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (160) then
            return
              (True, 99,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (161) then
            return
              (True, 100,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (162) then
            return
              (True, 101,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (163) then
            return
              (True, 102,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (164) then
            return
              (True, 103,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (165) then
            return
              (True, 104,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (166) then
            return
              (True, 105,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (167) then
            return
              (True, 106,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (168) then
            return
              (True, 107,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (169) then
            return
              (True, 108,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (170) then
            return
              (True, 109,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (171) then
            return
              (True, 110,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (172) then
            return
              (True, 111,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (173) then
            return
              (True, 112,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (174) then
            return
              (True, 113,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (175) then
            return
              (True, 114,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (176) then
            return
              (True, 115,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (177) then
            return
              (True, 116,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (178) then
            return
              (True, 117,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (179) then
            return
              (True, 118,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (180) then
            return
              (True, 119,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (181) then
            return
              (True, 120,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (182) then
            return
              (True, 121,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (183) then
            return
              (True, 122,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (184) then
            return
              (True, 65,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (185) then
            return
              (True, 66,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (186) then
            return
              (True, 67,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (187) then
            return
              (True, 68,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (188) then
            return
              (True, 69,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (189) then
            return
              (True, 70,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (190) then
            return
              (True, 71,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (148) & Character'Val (191) then
            return
              (True, 72,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (128) then
            return
              (True, 73,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (129) then
            return
              (True, 74,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (130) then
            return
              (True, 75,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (131) then
            return
              (True, 76,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (132) then
            return
              (True, 77,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (133) then
            return
              (True, 78,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (134) then
            return
              (True, 79,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (135) then
            return
              (True, 80,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (136) then
            return
              (True, 81,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (137) then
            return
              (True, 82,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (138) then
            return
              (True, 83,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (139) then
            return
              (True, 84,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (140) then
            return
              (True, 85,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (141) then
            return
              (True, 86,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (142) then
            return
              (True, 87,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (143) then
            return
              (True, 88,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (144) then
            return
              (True, 89,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (145) then
            return
              (True, 90,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (156) then
            return
              (True, 107,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (172) then
            return
              (True, 65,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (173) then
            return
              (True, 66,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (174) then
            return
              (True, 67,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (175) then
            return
              (True, 68,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (176) then
            return
              (True, 69,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (177) then
            return
              (True, 70,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (178) then
            return
              (True, 71,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (179) then
            return
              (True, 72,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (180) then
            return
              (True, 73,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (181) then
            return
              (True, 74,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (182) then
            return
              (True, 75,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (183) then
            return
              (True, 76,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (184) then
            return
              (True, 77,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (185) then
            return
              (True, 78,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (186) then
            return
              (True, 79,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (187) then
            return
              (True, 80,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (188) then
            return
              (True, 81,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (189) then
            return
              (True, 82,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (190) then
            return
              (True, 83,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (149) & Character'Val (191) then
            return
              (True, 84,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (128) then
            return
              (True, 85,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (129) then
            return
              (True, 86,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (130) then
            return
              (True, 87,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (131) then
            return
              (True, 88,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (132) then
            return
              (True, 89,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (133) then
            return
              (True, 90,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (134) then
            return
              (True, 97,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (135) then
            return
              (True, 98,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (136) then
            return
              (True, 99,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (137) then
            return
              (True, 100,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (138) then
            return
              (True, 101,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (139) then
            return
              (True, 102,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (140) then
            return
              (True, 103,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (141) then
            return
              (True, 104,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (142) then
            return
              (True, 105,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (143) then
            return
              (True, 106,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (144) then
            return
              (True, 107,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (145) then
            return
              (True, 108,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (146) then
            return
              (True, 109,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (147) then
            return
              (True, 110,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (148) then
            return
              (True, 111,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (149) then
            return
              (True, 112,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (150) then
            return
              (True, 113,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (151) then
            return
              (True, 114,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (152) then
            return
              (True, 115,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (153) then
            return
              (True, 116,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (154) then
            return
              (True, 117,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (155) then
            return
              (True, 118,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (156) then
            return
              (True, 119,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (157) then
            return
              (True, 120,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (158) then
            return
              (True, 121,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (159) then
            return
              (True, 122,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (160) then
            return
              (True, 65,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (161) then
            return
              (True, 66,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (162) then
            return
              (True, 67,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (163) then
            return
              (True, 68,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (164) then
            return
              (True, 69,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (165) then
            return
              (True, 70,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (166) then
            return
              (True, 71,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (167) then
            return
              (True, 72,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (168) then
            return
              (True, 73,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (169) then
            return
              (True, 74,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (170) then
            return
              (True, 75,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (171) then
            return
              (True, 76,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (172) then
            return
              (True, 77,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (173) then
            return
              (True, 78,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (174) then
            return
              (True, 79,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (175) then
            return
              (True, 80,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (176) then
            return
              (True, 81,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (177) then
            return
              (True, 82,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (178) then
            return
              (True, 83,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (179) then
            return
              (True, 84,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (180) then
            return
              (True, 85,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (181) then
            return
              (True, 86,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (182) then
            return
              (True, 87,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (183) then
            return
              (True, 88,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (184) then
            return
              (True, 89,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (185) then
            return
              (True, 90,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (186) then
            return
              (True, 97,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (187) then
            return
              (True, 98,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (188) then
            return
              (True, 99,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (189) then
            return
              (True, 100,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (190) then
            return
              (True, 101,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (150) & Character'Val (191) then
            return
              (True, 102,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (128) then
            return
              (True, 103,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (129) then
            return
              (True, 104,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (130) then
            return
              (True, 105,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (131) then
            return
              (True, 106,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (132) then
            return
              (True, 107,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (133) then
            return
              (True, 108,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (134) then
            return
              (True, 109,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (135) then
            return
              (True, 110,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (136) then
            return
              (True, 111,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (137) then
            return
              (True, 112,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (138) then
            return
              (True, 113,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (139) then
            return
              (True, 114,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (140) then
            return
              (True, 115,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (141) then
            return
              (True, 116,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (142) then
            return
              (True, 117,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (143) then
            return
              (True, 118,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (144) then
            return
              (True, 119,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (145) then
            return
              (True, 120,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (146) then
            return
              (True, 121,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (147) then
            return
              (True, 122,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (148) then
            return
              (True, 65,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (149) then
            return
              (True, 66,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (150) then
            return
              (True, 67,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (151) then
            return
              (True, 68,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (152) then
            return
              (True, 69,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (153) then
            return
              (True, 70,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (154) then
            return
              (True, 71,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (155) then
            return
              (True, 72,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (156) then
            return
              (True, 73,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (157) then
            return
              (True, 74,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (158) then
            return
              (True, 75,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (159) then
            return
              (True, 76,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (160) then
            return
              (True, 77,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (161) then
            return
              (True, 78,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (162) then
            return
              (True, 79,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (163) then
            return
              (True, 80,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (164) then
            return
              (True, 81,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (165) then
            return
              (True, 82,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (166) then
            return
              (True, 83,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (167) then
            return
              (True, 84,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (168) then
            return
              (True, 85,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (169) then
            return
              (True, 86,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (170) then
            return
              (True, 87,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (171) then
            return
              (True, 88,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (172) then
            return
              (True, 89,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (173) then
            return
              (True, 90,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (174) then
            return
              (True, 97,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (175) then
            return
              (True, 98,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (176) then
            return
              (True, 99,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (177) then
            return
              (True, 100,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (178) then
            return
              (True, 101,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (179) then
            return
              (True, 102,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (180) then
            return
              (True, 103,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (181) then
            return
              (True, 104,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (182) then
            return
              (True, 105,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (183) then
            return
              (True, 106,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (184) then
            return
              (True, 107,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (185) then
            return
              (True, 108,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (186) then
            return
              (True, 109,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (187) then
            return
              (True, 110,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (188) then
            return
              (True, 111,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (189) then
            return
              (True, 112,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (190) then
            return
              (True, 113,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (151) & Character'Val (191) then
            return
              (True, 114,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (128) then
            return
              (True, 115,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (129) then
            return
              (True, 116,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (130) then
            return
              (True, 117,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (131) then
            return
              (True, 118,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (132) then
            return
              (True, 119,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (133) then
            return
              (True, 120,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (134) then
            return
              (True, 121,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (135) then
            return
              (True, 122,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (136) then
            return
              (True, 65,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (137) then
            return
              (True, 66,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (138) then
            return
              (True, 67,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (139) then
            return
              (True, 68,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (140) then
            return
              (True, 69,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (141) then
            return
              (True, 70,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (142) then
            return
              (True, 71,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (143) then
            return
              (True, 72,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (144) then
            return
              (True, 73,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (145) then
            return
              (True, 74,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (146) then
            return
              (True, 75,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (147) then
            return
              (True, 76,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (148) then
            return
              (True, 77,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (149) then
            return
              (True, 78,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (150) then
            return
              (True, 79,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (151) then
            return
              (True, 80,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (152) then
            return
              (True, 81,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (153) then
            return
              (True, 82,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (154) then
            return
              (True, 83,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (155) then
            return
              (True, 84,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (156) then
            return
              (True, 85,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (157) then
            return
              (True, 86,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (158) then
            return
              (True, 87,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (159) then
            return
              (True, 88,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (160) then
            return
              (True, 89,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (161) then
            return
              (True, 90,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (162) then
            return
              (True, 97,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (163) then
            return
              (True, 98,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (164) then
            return
              (True, 99,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (165) then
            return
              (True, 100,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (166) then
            return
              (True, 101,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (167) then
            return
              (True, 102,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (168) then
            return
              (True, 103,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (169) then
            return
              (True, 104,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (170) then
            return
              (True, 105,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (171) then
            return
              (True, 106,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (172) then
            return
              (True, 107,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (173) then
            return
              (True, 108,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (174) then
            return
              (True, 109,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (175) then
            return
              (True, 110,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (176) then
            return
              (True, 111,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (177) then
            return
              (True, 112,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (178) then
            return
              (True, 113,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (179) then
            return
              (True, 114,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (180) then
            return
              (True, 115,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (181) then
            return
              (True, 116,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (182) then
            return
              (True, 117,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (183) then
            return
              (True, 118,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (184) then
            return
              (True, 119,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (185) then
            return
              (True, 120,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (186) then
            return
              (True, 121,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (152) & Character'Val (187) then
            return
              (True, 122,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (153) & Character'Val (176) then
            return
              (True, 65,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (153) & Character'Val (177) then
            return
              (True, 66,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (153) & Character'Val (178) then
            return
              (True, 67,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (153) & Character'Val (179) then
            return
              (True, 68,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (153) & Character'Val (180) then
            return
              (True, 69,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (153) & Character'Val (181) then
            return
              (True, 70,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (153) & Character'Val (182) then
            return
              (True, 71,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (153) & Character'Val (183) then
            return
              (True, 72,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (153) & Character'Val (184) then
            return
              (True, 73,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (153) & Character'Val (185) then
            return
              (True, 74,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (153) & Character'Val (186) then
            return
              (True, 75,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (153) & Character'Val (187) then
            return
              (True, 76,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (153) & Character'Val (188) then
            return
              (True, 77,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (153) & Character'Val (189) then
            return
              (True, 78,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (153) & Character'Val (190) then
            return
              (True, 79,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (153) & Character'Val (191) then
            return
              (True, 80,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (128) then
            return
              (True, 81,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (129) then
            return
              (True, 82,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (130) then
            return
              (True, 83,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (131) then
            return
              (True, 84,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (132) then
            return
              (True, 85,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (133) then
            return
              (True, 86,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (134) then
            return
              (True, 87,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (135) then
            return
              (True, 88,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (136) then
            return
              (True, 89,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (137) then
            return
              (True, 90,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (138) then
            return
              (True, 97,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (139) then
            return
              (True, 98,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (140) then
            return
              (True, 99,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (141) then
            return
              (True, 100,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (142) then
            return
              (True, 101,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (143) then
            return
              (True, 102,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (144) then
            return
              (True, 103,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (145) then
            return
              (True, 104,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (146) then
            return
              (True, 105,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (147) then
            return
              (True, 106,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (148) then
            return
              (True, 107,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (149) then
            return
              (True, 108,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (150) then
            return
              (True, 109,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (151) then
            return
              (True, 110,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (152) then
            return
              (True, 111,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (153) then
            return
              (True, 112,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (154) then
            return
              (True, 113,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (155) then
            return
              (True, 114,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (156) then
            return
              (True, 115,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (157) then
            return
              (True, 116,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (158) then
            return
              (True, 117,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (159) then
            return
              (True, 118,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (160) then
            return
              (True, 119,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (161) then
            return
              (True, 120,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (162) then
            return
              (True, 121,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (154) & Character'Val (163) then
            return
              (True, 122,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (142) then
            return
              (True, 48,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (143) then
            return
              (True, 49,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (144) then
            return
              (True, 50,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (145) then
            return
              (True, 51,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (146) then
            return
              (True, 52,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (147) then
            return
              (True, 53,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (148) then
            return
              (True, 54,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (149) then
            return
              (True, 55,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (150) then
            return
              (True, 56,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (151) then
            return
              (True, 57,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (162) then
            return
              (True, 48,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (163) then
            return
              (True, 49,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (164) then
            return
              (True, 50,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (165) then
            return
              (True, 51,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (166) then
            return
              (True, 52,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (167) then
            return
              (True, 53,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (168) then
            return
              (True, 54,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (169) then
            return
              (True, 55,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (170) then
            return
              (True, 56,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (171) then
            return
              (True, 57,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (172) then
            return
              (True, 48,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (173) then
            return
              (True, 49,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (174) then
            return
              (True, 50,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (175) then
            return
              (True, 51,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (176) then
            return
              (True, 52,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (177) then
            return
              (True, 53,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (178) then
            return
              (True, 54,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (179) then
            return
              (True, 55,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (180) then
            return
              (True, 56,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (181) then
            return
              (True, 57,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (182) then
            return
              (True, 48,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (183) then
            return
              (True, 49,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (184) then
            return
              (True, 50,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (185) then
            return
              (True, 51,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (186) then
            return
              (True, 52,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (187) then
            return
              (True, 53,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (188) then
            return
              (True, 54,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (189) then
            return
              (True, 55,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (190) then
            return
              (True, 56,
               Ordinary, Main_Regular);
         end if;
         if Name =
           Character'Val (240) & Character'Val (157) & Character'Val (159) & Character'Val (191) then
            return
              (True, 57,
               Ordinary, Main_Regular);
         end if;
      end if;
      return (others => <>);
   end Find;
   function Lookup_Math (Name : String) return Symbol_Record is
   begin
      return Find (Name, False);
   end Lookup_Math;
   function Lookup_Text (Name : String) return Symbol_Record is
   begin
      return Find (Name, True);
   end Lookup_Text;
end Math_Symbols;
