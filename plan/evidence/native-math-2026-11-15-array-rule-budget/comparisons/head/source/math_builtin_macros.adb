--  Generated from KaTeX 0.16.22 builtin macro templates.
--  Inventory SHA-256: 445511f22cbf79b0300a505c4f096bc57066b40daaa095bd9d39fc614943604d
--  dist/katex.js SHA-256: 8f1f4fb1080439c012bb8fddf424fa253e9144ab4cdd7dc0eae0e92cd04a5e33

with Ada.Strings.Unbounded;

package body Math_Builtin_Macros is
   use Ada.Strings.Unbounded;
   type Macro_Entry is record
      Name : Unbounded_String;
      Template : Unbounded_String;
      Num_Params : Natural;
   end record;
   Entries : constant array (Positive range 1 .. 318) of Macro_Entry :=
     (
      1 => (To_Unbounded_String ("\!"),
        To_Unbounded_String ("\tmspace-{3mu}{.1667em}"), 0),
      2 => (To_Unbounded_String ("\,"),
        To_Unbounded_String ("\tmspace+{3mu}{.1667em}"), 0),
      3 => (To_Unbounded_String ("\:"),
        To_Unbounded_String ("\tmspace+{4mu}{.2222em}"), 0),
      4 => (To_Unbounded_String ("\;"),
        To_Unbounded_String ("\tmspace+{5mu}{.2777em}"), 0),
      5 => (To_Unbounded_String ("\>"),
        To_Unbounded_String ("\mskip{4mu}"), 0),
      6 => (To_Unbounded_String ("\@hspace"),
        To_Unbounded_String ("\hskip #1\relax"), 1),
      7 => (To_Unbounded_String ("\@hspacer"),
        To_Unbounded_String ("\rule{0pt}{0pt}\hskip #1\relax"), 1),
      8 => (To_Unbounded_String ("\@ifstar"),
        To_Unbounded_String ("\@ifnextchar *{\@firstoftwo{#1}}"), 1),
      9 => (To_Unbounded_String ("\AA"),
        To_Unbounded_String ("\r A"), 0),
      10 => (To_Unbounded_String ("\Alpha"),
        To_Unbounded_String ("\mathrm{A}"), 0),
      11 => (To_Unbounded_String ("\Bbbk"),
        To_Unbounded_String ("\Bbb{k}"), 0),
      12 => (To_Unbounded_String ("\Beta"),
        To_Unbounded_String ("\mathrm{B}"), 0),
      13 => (To_Unbounded_String ("\Bra"),
        To_Unbounded_String ("\left\langle#1\right|"), 1),
      14 => (To_Unbounded_String ("\Braket"),
        To_Unbounded_String ("\bra@ket{\left\langle}{\,\middle\vert\,}{\,\middle\vert\,}{\right\rangle}"), 0),
      15 => (To_Unbounded_String ("\Chi"),
        To_Unbounded_String ("\mathrm{X}"), 0),
      16 => (To_Unbounded_String ("\Colonapprox"),
        To_Unbounded_String ("\html@mathml{\mathrel{\dblcolon\mathrel{\mkern-1.2mu}\approx}}{\mathop{\char""2237\char""2248}}"), 0),
      17 => (To_Unbounded_String ("\Coloneq"),
        To_Unbounded_String ("\html@mathml{\mathrel{\dblcolon\mathrel{\mkern-1.2mu}\mathrel{-}}}{\mathop{\char""2237\char""2212}}"), 0),
      18 => (To_Unbounded_String ("\Coloneqq"),
        To_Unbounded_String ("\html@mathml{\mathrel{\dblcolon\mathrel{\mkern-1.2mu}=}}{\mathop{\char""2237\char""3d}}"), 0),
      19 => (To_Unbounded_String ("\Colonsim"),
        To_Unbounded_String ("\html@mathml{\mathrel{\dblcolon\mathrel{\mkern-1.2mu}\sim}}{\mathop{\char""2237\char""223c}}"), 0),
      20 => (To_Unbounded_String ("\Complex"),
        To_Unbounded_String ("\mathbb{C}"), 0),
      21 => (To_Unbounded_String ("\DOTSB"),
        To_Unbounded_String ("\relax"), 0),
      22 => (To_Unbounded_String ("\DOTSI"),
        To_Unbounded_String ("\relax"), 0),
      23 => (To_Unbounded_String ("\DOTSX"),
        To_Unbounded_String ("\relax"), 0),
      24 => (To_Unbounded_String ("\Dagger"),
        To_Unbounded_String ("\ddagger"), 0),
      25 => (To_Unbounded_String ("\Darr"),
        To_Unbounded_String ("\Downarrow"), 0),
      26 => (To_Unbounded_String ("\Epsilon"),
        To_Unbounded_String ("\mathrm{E}"), 0),
      27 => (To_Unbounded_String ("\Eqcolon"),
        To_Unbounded_String ("\html@mathml{\mathrel{\mathrel{-}\mathrel{\mkern-1.2mu}\dblcolon}}{\mathop{\char""2212\char""2237}}"), 0),
      28 => (To_Unbounded_String ("\Eqqcolon"),
        To_Unbounded_String ("\html@mathml{\mathrel{=\mathrel{\mkern-1.2mu}\dblcolon}}{\mathop{\char""3d\char""2237}}"), 0),
      29 => (To_Unbounded_String ("\Eta"),
        To_Unbounded_String ("\mathrm{H}"), 0),
      30 => (To_Unbounded_String ("\Harr"),
        To_Unbounded_String ("\Leftrightarrow"), 0),
      31 => (To_Unbounded_String ("\Iota"),
        To_Unbounded_String ("\mathrm{I}"), 0),
      32 => (To_Unbounded_String ("\KaTeX"),
        To_Unbounded_String ("\textrm{\html@mathml{K\kern-.17em\raisebox{0.205em}{\scriptstyle A}\kern-.15em\TeX}{KaTeX}}"), 0),
      33 => (To_Unbounded_String ("\Kappa"),
        To_Unbounded_String ("\mathrm{K}"), 0),
      34 => (To_Unbounded_String ("\Ket"),
        To_Unbounded_String ("\left|#1\right\rangle"), 1),
      35 => (To_Unbounded_String ("\LaTeX"),
        To_Unbounded_String ("\textrm{\html@mathml{L\kern-.36em\raisebox{0.205em}{\scriptstyle A}\kern-.15em\TeX}{LaTeX}}"), 0),
      36 => (To_Unbounded_String ("\Larr"),
        To_Unbounded_String ("\Leftarrow"), 0),
      37 => (To_Unbounded_String ("\Lrarr"),
        To_Unbounded_String ("\Leftrightarrow"), 0),
      38 => (To_Unbounded_String ("\Mu"),
        To_Unbounded_String ("\mathrm{M}"), 0),
      39 => (To_Unbounded_String ("\N"),
        To_Unbounded_String ("\mathbb{N}"), 0),
      40 => (To_Unbounded_String ("\Nu"),
        To_Unbounded_String ("\mathrm{N}"), 0),
      41 => (To_Unbounded_String ("\Omicron"),
        To_Unbounded_String ("\mathrm{O}"), 0),
      42 => (To_Unbounded_String ("\R"),
        To_Unbounded_String ("\mathbb{R}"), 0),
      43 => (To_Unbounded_String ("\Rarr"),
        To_Unbounded_String ("\Rightarrow"), 0),
      44 => (To_Unbounded_String ("\Reals"),
        To_Unbounded_String ("\mathbb{R}"), 0),
      45 => (To_Unbounded_String ("\Rho"),
        To_Unbounded_String ("\mathrm{P}"), 0),
      46 => (To_Unbounded_String ("\Set"),
        To_Unbounded_String ("\bra@set{\left\{\:}{\;\middle\vert\;}{\;\middle\Vert\;}{\:\right\}}"), 0),
      47 => (To_Unbounded_String ("\Tau"),
        To_Unbounded_String ("\mathrm{T}"), 0),
      48 => (To_Unbounded_String ("\TeX"),
        To_Unbounded_String ("\textrm{\html@mathml{T\kern-.1667em\raisebox{-.5ex}{E}\kern-.125emX}{TeX}}"), 0),
      49 => (To_Unbounded_String ("\Uarr"),
        To_Unbounded_String ("\Uparrow"), 0),
      50 => (To_Unbounded_String ("\Z"),
        To_Unbounded_String ("\mathbb{Z}"), 0),
      51 => (To_Unbounded_String ("\Zeta"),
        To_Unbounded_String ("\mathrm{Z}"), 0),
      52 => (To_Unbounded_String ("\aa"),
        To_Unbounded_String ("\r a"), 0),
      53 => (To_Unbounded_String ("\alef"),
        To_Unbounded_String ("\aleph"), 0),
      54 => (To_Unbounded_String ("\alefsym"),
        To_Unbounded_String ("\aleph"), 0),
      55 => (To_Unbounded_String ("\angln"),
        To_Unbounded_String ("{\angl n}"), 0),
      56 => (To_Unbounded_String ("\approxcolon"),
        To_Unbounded_String ("\mathrel{\approx\mathrel{\mkern-1.2mu}\vcentcolon}"), 0),
      57 => (To_Unbounded_String ("\approxcoloncolon"),
        To_Unbounded_String ("\mathrel{\approx\mathrel{\mkern-1.2mu}\dblcolon}"), 0),
      58 => (To_Unbounded_String ("\argmax"),
        To_Unbounded_String ("\DOTSB\operatorname*{arg\,max}"), 0),
      59 => (To_Unbounded_String ("\argmin"),
        To_Unbounded_String ("\DOTSB\operatorname*{arg\,min}"), 0),
      60 => (To_Unbounded_String ("\bgroup"),
        To_Unbounded_String ("{"), 0),
      61 => (To_Unbounded_String ("\blue"),
        To_Unbounded_String ("\textcolor{##6495ed}{#1}"), 1),
      62 => (To_Unbounded_String ("\blueA"),
        To_Unbounded_String ("\textcolor{##ccfaff}{#1}"), 1),
      63 => (To_Unbounded_String ("\blueB"),
        To_Unbounded_String ("\textcolor{##80f6ff}{#1}"), 1),
      64 => (To_Unbounded_String ("\blueC"),
        To_Unbounded_String ("\textcolor{##63d9ea}{#1}"), 1),
      65 => (To_Unbounded_String ("\blueD"),
        To_Unbounded_String ("\textcolor{##11accd}{#1}"), 1),
      66 => (To_Unbounded_String ("\blueE"),
        To_Unbounded_String ("\textcolor{##0c7f99}{#1}"), 1),
      67 => (To_Unbounded_String ("\bmod"),
        To_Unbounded_String ("\mathchoice{\mskip1mu}{\mskip1mu}{\mskip5mu}{\mskip5mu}\mathbin{\rm mod}\mathchoice{\mskip1mu}{\mskip1mu}{\mskip5mu}{\mskip5mu}"), 0),
      68 => (To_Unbounded_String ("\boxed"),
        To_Unbounded_String ("\fbox{$\displaystyle{#1}$}"), 1),
      69 => (To_Unbounded_String ("\bra"),
        To_Unbounded_String ("\mathinner{\langle{#1}|}"), 1),
      70 => (To_Unbounded_String ("\braket"),
        To_Unbounded_String ("\mathinner{\langle{#1}\rangle}"), 1),
      71 => (To_Unbounded_String ("\bull"),
        To_Unbounded_String ("\bullet"), 0),
      72 => (To_Unbounded_String ("\clap"),
        To_Unbounded_String ("\mathclap{\textrm{#1}}"), 1),
      73 => (To_Unbounded_String ("\clubs"),
        To_Unbounded_String ("\clubsuit"), 0),
      74 => (To_Unbounded_String ("\cnums"),
        To_Unbounded_String ("\mathbb{C}"), 0),
      75 => (To_Unbounded_String ("\colon"),
        To_Unbounded_String ("\nobreak\mskip2mu\mathpunct{}\mathchoice{\mkern-3mu}{\mkern-3mu}{}{}{:}\mskip6mu\relax"), 0),
      76 => (To_Unbounded_String ("\colonapprox"),
        To_Unbounded_String ("\html@mathml{\mathrel{\vcentcolon\mathrel{\mkern-1.2mu}\approx}}{\mathop{\char""3a\char""2248}}"), 0),
      77 => (To_Unbounded_String ("\coloncolon"),
        To_Unbounded_String ("\dblcolon"), 0),
      78 => (To_Unbounded_String ("\coloncolonapprox"),
        To_Unbounded_String ("\Colonapprox"), 0),
      79 => (To_Unbounded_String ("\coloncolonequals"),
        To_Unbounded_String ("\Coloneqq"), 0),
      80 => (To_Unbounded_String ("\coloncolonminus"),
        To_Unbounded_String ("\Coloneq"), 0),
      81 => (To_Unbounded_String ("\coloncolonsim"),
        To_Unbounded_String ("\Colonsim"), 0),
      82 => (To_Unbounded_String ("\coloneq"),
        To_Unbounded_String ("\html@mathml{\mathrel{\vcentcolon\mathrel{\mkern-1.2mu}\mathrel{-}}}{\mathop{\char""3a\char""2212}}"), 0),
      83 => (To_Unbounded_String ("\coloneqq"),
        To_Unbounded_String ("\html@mathml{\mathrel{\vcentcolon\mathrel{\mkern-1.2mu}=}}{\mathop{\char""2254}}"), 0),
      84 => (To_Unbounded_String ("\colonequals"),
        To_Unbounded_String ("\coloneqq"), 0),
      85 => (To_Unbounded_String ("\colonminus"),
        To_Unbounded_String ("\coloneq"), 0),
      86 => (To_Unbounded_String ("\colonsim"),
        To_Unbounded_String ("\html@mathml{\mathrel{\vcentcolon\mathrel{\mkern-1.2mu}\sim}}{\mathop{\char""3a\char""223c}}"), 0),
      87 => (To_Unbounded_String ("\copyright"),
        To_Unbounded_String ("\TextOrMath{\textcopyright}{\text{\textcopyright}}"), 0),
      88 => (To_Unbounded_String ("\dArr"),
        To_Unbounded_String ("\Downarrow"), 0),
      89 => (To_Unbounded_String ("\darr"),
        To_Unbounded_String ("\downarrow"), 0),
      90 => (To_Unbounded_String ("\dblcolon"),
        To_Unbounded_String ("\html@mathml{\mathrel{\vcentcolon\mathrel{\mkern-.9mu}\vcentcolon}}{\mathop{\char""2237}}"), 0),
      91 => (To_Unbounded_String ("\ddddot"),
        To_Unbounded_String ("{\overset{\raisebox{-0.1ex}{\normalsize ....}}{#1}}"), 1),
      92 => (To_Unbounded_String ("\dddot"),
        To_Unbounded_String ("{\overset{\raisebox{-0.1ex}{\normalsize ...}}{#1}}"), 1),
      93 => (To_Unbounded_String ("\diamonds"),
        To_Unbounded_String ("\diamondsuit"), 0),
      94 => (To_Unbounded_String ("\dotsb"),
        To_Unbounded_String ("\cdots"), 0),
      95 => (To_Unbounded_String ("\dotsi"),
        To_Unbounded_String ("\!\cdots"), 0),
      96 => (To_Unbounded_String ("\dotsm"),
        To_Unbounded_String ("\cdots"), 0),
      97 => (To_Unbounded_String ("\dotsx"),
        To_Unbounded_String ("\ldots\,"), 0),
      98 => (To_Unbounded_String ("\egroup"),
        To_Unbounded_String ("}"), 0),
      99 => (To_Unbounded_String ("\empty"),
        To_Unbounded_String ("\emptyset"), 0),
      100 => (To_Unbounded_String ("\enskip"),
        To_Unbounded_String ("\hskip.5em\relax"), 0),
      101 => (To_Unbounded_String ("\enspace"),
        To_Unbounded_String ("\kern.5em "), 0),
      102 => (To_Unbounded_String ("\eqcolon"),
        To_Unbounded_String ("\html@mathml{\mathrel{\mathrel{-}\mathrel{\mkern-1.2mu}\vcentcolon}}{\mathop{\char""2239}}"), 0),
      103 => (To_Unbounded_String ("\eqqcolon"),
        To_Unbounded_String ("\html@mathml{\mathrel{=\mathrel{\mkern-1.2mu}\vcentcolon}}{\mathop{\char""2255}}"), 0),
      104 => (To_Unbounded_String ("\equalscolon"),
        To_Unbounded_String ("\eqqcolon"), 0),
      105 => (To_Unbounded_String ("\equalscoloncolon"),
        To_Unbounded_String ("\Eqqcolon"), 0),
      106 => (To_Unbounded_String ("\exist"),
        To_Unbounded_String ("\exists"), 0),
      107 => (To_Unbounded_String ("\goldA"),
        To_Unbounded_String ("\textcolor{##ffd0a9}{#1}"), 1),
      108 => (To_Unbounded_String ("\goldB"),
        To_Unbounded_String ("\textcolor{##ffbb71}{#1}"), 1),
      109 => (To_Unbounded_String ("\goldC"),
        To_Unbounded_String ("\textcolor{##ff9c39}{#1}"), 1),
      110 => (To_Unbounded_String ("\goldD"),
        To_Unbounded_String ("\textcolor{##e07d10}{#1}"), 1),
      111 => (To_Unbounded_String ("\goldE"),
        To_Unbounded_String ("\textcolor{##a75a05}{#1}"), 1),
      112 => (To_Unbounded_String ("\gray"),
        To_Unbounded_String ("\textcolor{gray}{#1}"), 1),
      113 => (To_Unbounded_String ("\grayA"),
        To_Unbounded_String ("\textcolor{##f6f7f7}{#1}"), 1),
      114 => (To_Unbounded_String ("\grayB"),
        To_Unbounded_String ("\textcolor{##f0f1f2}{#1}"), 1),
      115 => (To_Unbounded_String ("\grayC"),
        To_Unbounded_String ("\textcolor{##e3e5e6}{#1}"), 1),
      116 => (To_Unbounded_String ("\grayD"),
        To_Unbounded_String ("\textcolor{##d6d8da}{#1}"), 1),
      117 => (To_Unbounded_String ("\grayE"),
        To_Unbounded_String ("\textcolor{##babec2}{#1}"), 1),
      118 => (To_Unbounded_String ("\grayF"),
        To_Unbounded_String ("\textcolor{##888d93}{#1}"), 1),
      119 => (To_Unbounded_String ("\grayG"),
        To_Unbounded_String ("\textcolor{##626569}{#1}"), 1),
      120 => (To_Unbounded_String ("\grayH"),
        To_Unbounded_String ("\textcolor{##3b3e40}{#1}"), 1),
      121 => (To_Unbounded_String ("\grayI"),
        To_Unbounded_String ("\textcolor{##21242c}{#1}"), 1),
      122 => (To_Unbounded_String ("\green"),
        To_Unbounded_String ("\textcolor{##28ae7b}{#1}"), 1),
      123 => (To_Unbounded_String ("\greenA"),
        To_Unbounded_String ("\textcolor{##b6ffb0}{#1}"), 1),
      124 => (To_Unbounded_String ("\greenB"),
        To_Unbounded_String ("\textcolor{##8af281}{#1}"), 1),
      125 => (To_Unbounded_String ("\greenC"),
        To_Unbounded_String ("\textcolor{##74cf70}{#1}"), 1),
      126 => (To_Unbounded_String ("\greenD"),
        To_Unbounded_String ("\textcolor{##1fab54}{#1}"), 1),
      127 => (To_Unbounded_String ("\greenE"),
        To_Unbounded_String ("\textcolor{##0d923f}{#1}"), 1),
      128 => (To_Unbounded_String ("\gvertneqq"),
        To_Unbounded_String ("\html@mathml{\@gvertneqq}{" &
          Character'Val (16#E2#) &
          Character'Val (16#89#) &
          Character'Val (16#A9#) &
          "}"), 0),
      129 => (To_Unbounded_String ("\hArr"),
        To_Unbounded_String ("\Leftrightarrow"), 0),
      130 => (To_Unbounded_String ("\harr"),
        To_Unbounded_String ("\leftrightarrow"), 0),
      131 => (To_Unbounded_String ("\hearts"),
        To_Unbounded_String ("\heartsuit"), 0),
      132 => (To_Unbounded_String ("\hspace"),
        To_Unbounded_String ("\@ifstar\@hspacer\@hspace"), 0),
      133 => (To_Unbounded_String ("\iff"),
        To_Unbounded_String ("\DOTSB\;\Longleftrightarrow\;"), 0),
      134 => (To_Unbounded_String ("\image"),
        To_Unbounded_String ("\Im"), 0),
      135 => (To_Unbounded_String ("\imath"),
        To_Unbounded_String ("\html@mathml{\@imath}{" &
          Character'Val (16#C4#) &
          Character'Val (16#B1#) &
          "}"), 0),
      136 => (To_Unbounded_String ("\impliedby"),
        To_Unbounded_String ("\DOTSB\;\Longleftarrow\;"), 0),
      137 => (To_Unbounded_String ("\implies"),
        To_Unbounded_String ("\DOTSB\;\Longrightarrow\;"), 0),
      138 => (To_Unbounded_String ("\infin"),
        To_Unbounded_String ("\infty"), 0),
      139 => (To_Unbounded_String ("\injlim"),
        To_Unbounded_String ("\DOTSB\operatorname*{inj\,lim}"), 0),
      140 => (To_Unbounded_String ("\isin"),
        To_Unbounded_String ("\in"), 0),
      141 => (To_Unbounded_String ("\jmath"),
        To_Unbounded_String ("\html@mathml{\@jmath}{" &
          Character'Val (16#C8#) &
          Character'Val (16#B7#) &
          "}"), 0),
      142 => (To_Unbounded_String ("\kaBlue"),
        To_Unbounded_String ("\textcolor{##314453}{#1}"), 1),
      143 => (To_Unbounded_String ("\kaGreen"),
        To_Unbounded_String ("\textcolor{##71B307}{#1}"), 1),
      144 => (To_Unbounded_String ("\ket"),
        To_Unbounded_String ("\mathinner{|{#1}\rangle}"), 1),
      145 => (To_Unbounded_String ("\lArr"),
        To_Unbounded_String ("\Leftarrow"), 0),
      146 => (To_Unbounded_String ("\lBrace"),
        To_Unbounded_String ("\html@mathml{\mathopen{\{\mkern-3.2mu[}}{\mathopen{\char`" &
          Character'Val (16#E2#) &
          Character'Val (16#A6#) &
          Character'Val (16#83#) &
          "}}"), 0),
      147 => (To_Unbounded_String ("\lang"),
        To_Unbounded_String ("\langle"), 0),
      148 => (To_Unbounded_String ("\larr"),
        To_Unbounded_String ("\leftarrow"), 0),
      149 => (To_Unbounded_String ("\liminf"),
        To_Unbounded_String ("\DOTSB\operatorname*{lim\,inf}"), 0),
      150 => (To_Unbounded_String ("\limsup"),
        To_Unbounded_String ("\DOTSB\operatorname*{lim\,sup}"), 0),
      151 => (To_Unbounded_String ("\llap"),
        To_Unbounded_String ("\mathllap{\textrm{#1}}"), 1),
      152 => (To_Unbounded_String ("\llbracket"),
        To_Unbounded_String ("\html@mathml{\mathopen{[\mkern-3.2mu[}}{\mathopen{\char`" &
          Character'Val (16#E2#) &
          Character'Val (16#9F#) &
          Character'Val (16#A6#) &
          "}}"), 0),
      153 => (To_Unbounded_String ("\llcorner"),
        To_Unbounded_String ("\html@mathml{\@llcorner}{\mathop{\char""231e}}"), 0),
      154 => (To_Unbounded_String ("\lq"),
        To_Unbounded_String ("`"), 0),
      155 => (To_Unbounded_String ("\lrArr"),
        To_Unbounded_String ("\Leftrightarrow"), 0),
      156 => (To_Unbounded_String ("\lrarr"),
        To_Unbounded_String ("\leftrightarrow"), 0),
      157 => (To_Unbounded_String ("\lrcorner"),
        To_Unbounded_String ("\html@mathml{\@lrcorner}{\mathop{\char""231f}}"), 0),
      158 => (To_Unbounded_String ("\lvertneqq"),
        To_Unbounded_String ("\html@mathml{\@lvertneqq}{" &
          Character'Val (16#E2#) &
          Character'Val (16#89#) &
          Character'Val (16#A8#) &
          "}"), 0),
      159 => (To_Unbounded_String ("\maroonA"),
        To_Unbounded_String ("\textcolor{##ffbde0}{#1}"), 1),
      160 => (To_Unbounded_String ("\maroonB"),
        To_Unbounded_String ("\textcolor{##ff92c6}{#1}"), 1),
      161 => (To_Unbounded_String ("\maroonC"),
        To_Unbounded_String ("\textcolor{##ed5fa6}{#1}"), 1),
      162 => (To_Unbounded_String ("\maroonD"),
        To_Unbounded_String ("\textcolor{##ca337c}{#1}"), 1),
      163 => (To_Unbounded_String ("\maroonE"),
        To_Unbounded_String ("\textcolor{##9e034e}{#1}"), 1),
      164 => (To_Unbounded_String ("\mathstrut"),
        To_Unbounded_String ("\vphantom{(}"), 0),
      165 => (To_Unbounded_String ("\medspace"),
        To_Unbounded_String ("\:"), 0),
      166 => (To_Unbounded_String ("\mintA"),
        To_Unbounded_String ("\textcolor{##f5f9e8}{#1}"), 1),
      167 => (To_Unbounded_String ("\mintB"),
        To_Unbounded_String ("\textcolor{##edf2df}{#1}"), 1),
      168 => (To_Unbounded_String ("\mintC"),
        To_Unbounded_String ("\textcolor{##e0e5cc}{#1}"), 1),
      169 => (To_Unbounded_String ("\minuscolon"),
        To_Unbounded_String ("\eqcolon"), 0),
      170 => (To_Unbounded_String ("\minuscoloncolon"),
        To_Unbounded_String ("\Eqcolon"), 0),
      171 => (To_Unbounded_String ("\minuso"),
        To_Unbounded_String ("\mathbin{\html@mathml{{\mathrlap{\mathchoice{\kern{0.145em}}{\kern{0.145em}}{\kern{0.1015em}}{\kern{0.0725em}}\circ}{-}}}{\char`" &
          Character'Val (16#E2#) &
          Character'Val (16#A6#) &
          Character'Val (16#B5#) &
          "}}"), 0),
      172 => (To_Unbounded_String ("\mod"),
        To_Unbounded_String ("\allowbreak\mathchoice{\mkern18mu}{\mkern12mu}{\mkern12mu}{\mkern12mu}{\rm mod}\,\,#1"), 1),
      173 => (To_Unbounded_String ("\natnums"),
        To_Unbounded_String ("\mathbb{N}"), 0),
      174 => (To_Unbounded_String ("\ne"),
        To_Unbounded_String ("\neq"), 0),
      175 => (To_Unbounded_String ("\negmedspace"),
        To_Unbounded_String ("\tmspace-{4mu}{.2222em}"), 0),
      176 => (To_Unbounded_String ("\negthickspace"),
        To_Unbounded_String ("\tmspace-{5mu}{.277em}"), 0),
      177 => (To_Unbounded_String ("\negthinspace"),
        To_Unbounded_String ("\!"), 0),
      178 => (To_Unbounded_String ("\neq"),
        To_Unbounded_String ("\html@mathml{\mathrel{\not=}}{\mathrel{\char`" &
          Character'Val (16#E2#) &
          Character'Val (16#89#) &
          Character'Val (16#A0#) &
          "}}"), 0),
      179 => (To_Unbounded_String ("\newline"),
        To_Unbounded_String ("\\\relax"), 0),
      180 => (To_Unbounded_String ("\ngeqq"),
        To_Unbounded_String ("\html@mathml{\@ngeqq}{" &
          Character'Val (16#E2#) &
          Character'Val (16#89#) &
          Character'Val (16#B1#) &
          "}"), 0),
      181 => (To_Unbounded_String ("\ngeqslant"),
        To_Unbounded_String ("\html@mathml{\@ngeqslant}{" &
          Character'Val (16#E2#) &
          Character'Val (16#89#) &
          Character'Val (16#B1#) &
          "}"), 0),
      182 => (To_Unbounded_String ("\nleqq"),
        To_Unbounded_String ("\html@mathml{\@nleqq}{" &
          Character'Val (16#E2#) &
          Character'Val (16#89#) &
          Character'Val (16#B0#) &
          "}"), 0),
      183 => (To_Unbounded_String ("\nleqslant"),
        To_Unbounded_String ("\html@mathml{\@nleqslant}{" &
          Character'Val (16#E2#) &
          Character'Val (16#89#) &
          Character'Val (16#B0#) &
          "}"), 0),
      184 => (To_Unbounded_String ("\nonumber"),
        To_Unbounded_String ("\gdef\@eqnsw{0}"), 0),
      185 => (To_Unbounded_String ("\not"),
        To_Unbounded_String ("\html@mathml{\mathrel{\mathrlap\@not}}{\char""338}"), 0),
      186 => (To_Unbounded_String ("\notag"),
        To_Unbounded_String ("\nonumber"), 0),
      187 => (To_Unbounded_String ("\notin"),
        To_Unbounded_String ("\html@mathml{\mathrel{{\in}\mathllap{/\mskip1mu}}}{\mathrel{\char`" &
          Character'Val (16#E2#) &
          Character'Val (16#88#) &
          Character'Val (16#89#) &
          "}}"), 0),
      188 => (To_Unbounded_String ("\notni"),
        To_Unbounded_String ("\html@mathml{\not\ni}{\mathrel{\char`" &
          Character'Val (16#E2#) &
          Character'Val (16#88#) &
          Character'Val (16#8C#) &
          "}}"), 0),
      189 => (To_Unbounded_String ("\nshortmid"),
        To_Unbounded_String ("\html@mathml{\@nshortmid}{" &
          Character'Val (16#E2#) &
          Character'Val (16#88#) &
          Character'Val (16#A4#) &
          "}"), 0),
      190 => (To_Unbounded_String ("\nshortparallel"),
        To_Unbounded_String ("\html@mathml{\@nshortparallel}{" &
          Character'Val (16#E2#) &
          Character'Val (16#88#) &
          Character'Val (16#A6#) &
          "}"), 0),
      191 => (To_Unbounded_String ("\nsubseteqq"),
        To_Unbounded_String ("\html@mathml{\@nsubseteqq}{" &
          Character'Val (16#E2#) &
          Character'Val (16#8A#) &
          Character'Val (16#88#) &
          "}"), 0),
      192 => (To_Unbounded_String ("\nsupseteqq"),
        To_Unbounded_String ("\html@mathml{\@nsupseteqq}{" &
          Character'Val (16#E2#) &
          Character'Val (16#8A#) &
          Character'Val (16#89#) &
          "}"), 0),
      193 => (To_Unbounded_String ("\operatorname"),
        To_Unbounded_String ("\@ifstar\operatornamewithlimits\operatorname@"), 0),
      194 => (To_Unbounded_String ("\orange"),
        To_Unbounded_String ("\textcolor{##ffa500}{#1}"), 1),
      195 => (To_Unbounded_String ("\ordinarycolon"),
        To_Unbounded_String (":"), 0),
      196 => (To_Unbounded_String ("\pink"),
        To_Unbounded_String ("\textcolor{##ff00af}{#1}"), 1),
      197 => (To_Unbounded_String ("\plim"),
        To_Unbounded_String ("\DOTSB\mathop{\operatorname{plim}}\limits"), 0),
      198 => (To_Unbounded_String ("\plusmn"),
        To_Unbounded_String ("\pm"), 0),
      199 => (To_Unbounded_String ("\pmod"),
        To_Unbounded_String ("\pod{{\rm mod}\mkern6mu#1}"), 1),
      200 => (To_Unbounded_String ("\pod"),
        To_Unbounded_String ("\allowbreak\mathchoice{\mkern18mu}{\mkern8mu}{\mkern8mu}{\mkern8mu}(#1)"), 1),
      201 => (To_Unbounded_String ("\projlim"),
        To_Unbounded_String ("\DOTSB\operatorname*{proj\,lim}"), 0),
      202 => (To_Unbounded_String ("\purple"),
        To_Unbounded_String ("\textcolor{##9d38bd}{#1}"), 1),
      203 => (To_Unbounded_String ("\purpleA"),
        To_Unbounded_String ("\textcolor{##ddd7ff}{#1}"), 1),
      204 => (To_Unbounded_String ("\purpleB"),
        To_Unbounded_String ("\textcolor{##c6b9fc}{#1}"), 1),
      205 => (To_Unbounded_String ("\purpleC"),
        To_Unbounded_String ("\textcolor{##aa87ff}{#1}"), 1),
      206 => (To_Unbounded_String ("\purpleD"),
        To_Unbounded_String ("\textcolor{##7854ab}{#1}"), 1),
      207 => (To_Unbounded_String ("\purpleE"),
        To_Unbounded_String ("\textcolor{##543b78}{#1}"), 1),
      208 => (To_Unbounded_String ("\qquad"),
        To_Unbounded_String ("\hskip2em\relax"), 0),
      209 => (To_Unbounded_String ("\quad"),
        To_Unbounded_String ("\hskip1em\relax"), 0),
      210 => (To_Unbounded_String ("\rArr"),
        To_Unbounded_String ("\Rightarrow"), 0),
      211 => (To_Unbounded_String ("\rBrace"),
        To_Unbounded_String ("\html@mathml{\mathclose{]\mkern-3.2mu\}}}{\mathclose{\char`" &
          Character'Val (16#E2#) &
          Character'Val (16#A6#) &
          Character'Val (16#84#) &
          "}}"), 0),
      212 => (To_Unbounded_String ("\rang"),
        To_Unbounded_String ("\rangle"), 0),
      213 => (To_Unbounded_String ("\rarr"),
        To_Unbounded_String ("\rightarrow"), 0),
      214 => (To_Unbounded_String ("\ratio"),
        To_Unbounded_String ("\vcentcolon"), 0),
      215 => (To_Unbounded_String ("\real"),
        To_Unbounded_String ("\Re"), 0),
      216 => (To_Unbounded_String ("\reals"),
        To_Unbounded_String ("\mathbb{R}"), 0),
      217 => (To_Unbounded_String ("\red"),
        To_Unbounded_String ("\textcolor{##df0030}{#1}"), 1),
      218 => (To_Unbounded_String ("\redA"),
        To_Unbounded_String ("\textcolor{##fca9a9}{#1}"), 1),
      219 => (To_Unbounded_String ("\redB"),
        To_Unbounded_String ("\textcolor{##ff8482}{#1}"), 1),
      220 => (To_Unbounded_String ("\redC"),
        To_Unbounded_String ("\textcolor{##f9685d}{#1}"), 1),
      221 => (To_Unbounded_String ("\redD"),
        To_Unbounded_String ("\textcolor{##e84d39}{#1}"), 1),
      222 => (To_Unbounded_String ("\redE"),
        To_Unbounded_String ("\textcolor{##bc2612}{#1}"), 1),
      223 => (To_Unbounded_String ("\rlap"),
        To_Unbounded_String ("\mathrlap{\textrm{#1}}"), 1),
      224 => (To_Unbounded_String ("\rq"),
        To_Unbounded_String ("'"), 0),
      225 => (To_Unbounded_String ("\rrbracket"),
        To_Unbounded_String ("\html@mathml{\mathclose{]\mkern-3.2mu]}}{\mathclose{\char`" &
          Character'Val (16#E2#) &
          Character'Val (16#9F#) &
          Character'Val (16#A7#) &
          "}}"), 0),
      226 => (To_Unbounded_String ("\sdot"),
        To_Unbounded_String ("\cdot"), 0),
      227 => (To_Unbounded_String ("\sect"),
        To_Unbounded_String ("\S"), 0),
      228 => (To_Unbounded_String ("\set"),
        To_Unbounded_String ("\bra@set{\{\,}{\mid}{}{\,\}}"), 0),
      229 => (To_Unbounded_String ("\simcolon"),
        To_Unbounded_String ("\mathrel{\sim\mathrel{\mkern-1.2mu}\vcentcolon}"), 0),
      230 => (To_Unbounded_String ("\simcoloncolon"),
        To_Unbounded_String ("\mathrel{\sim\mathrel{\mkern-1.2mu}\dblcolon}"), 0),
      231 => (To_Unbounded_String ("\spades"),
        To_Unbounded_String ("\spadesuit"), 0),
      232 => (To_Unbounded_String ("\sub"),
        To_Unbounded_String ("\subset"), 0),
      233 => (To_Unbounded_String ("\sube"),
        To_Unbounded_String ("\subseteq"), 0),
      234 => (To_Unbounded_String ("\substack"),
        To_Unbounded_String ("\begin{subarray}{c}#1\end{subarray}"), 1),
      235 => (To_Unbounded_String ("\supe"),
        To_Unbounded_String ("\supseteq"), 0),
      236 => (To_Unbounded_String ("\tag"),
        To_Unbounded_String ("\@ifstar\tag@literal\tag@paren"), 0),
      237 => (To_Unbounded_String ("\tag@paren"),
        To_Unbounded_String ("\tag@literal{({#1})}"), 1),
      238 => (To_Unbounded_String ("\tealA"),
        To_Unbounded_String ("\textcolor{##94fff5}{#1}"), 1),
      239 => (To_Unbounded_String ("\tealB"),
        To_Unbounded_String ("\textcolor{##26edd5}{#1}"), 1),
      240 => (To_Unbounded_String ("\tealC"),
        To_Unbounded_String ("\textcolor{##01d1c1}{#1}"), 1),
      241 => (To_Unbounded_String ("\tealD"),
        To_Unbounded_String ("\textcolor{##01a995}{#1}"), 1),
      242 => (To_Unbounded_String ("\tealE"),
        To_Unbounded_String ("\textcolor{##208170}{#1}"), 1),
      243 => (To_Unbounded_String ("\textcopyright"),
        To_Unbounded_String ("\html@mathml{\textcircled{c}}{\char`" &
          Character'Val (16#C2#) &
          Character'Val (16#A9#) &
          "}"), 0),
      244 => (To_Unbounded_String ("\textregistered"),
        To_Unbounded_String ("\html@mathml{\textcircled{\scriptsize R}}{\char`" &
          Character'Val (16#C2#) &
          Character'Val (16#AE#) &
          "}"), 0),
      245 => (To_Unbounded_String ("\thetasym"),
        To_Unbounded_String ("\vartheta"), 0),
      246 => (To_Unbounded_String ("\thickspace"),
        To_Unbounded_String ("\;"), 0),
      247 => (To_Unbounded_String ("\thinspace"),
        To_Unbounded_String ("\,"), 0),
      248 => (To_Unbounded_String ("\tmspace"),
        To_Unbounded_String ("\TextOrMath{\kern#1#3}{\mskip#1#2}\relax"), 3),
      249 => (To_Unbounded_String ("\uArr"),
        To_Unbounded_String ("\Uparrow"), 0),
      250 => (To_Unbounded_String ("\uarr"),
        To_Unbounded_String ("\uparrow"), 0),
      251 => (To_Unbounded_String ("\ulcorner"),
        To_Unbounded_String ("\html@mathml{\@ulcorner}{\mathop{\char""231c}}"), 0),
      252 => (To_Unbounded_String ("\underbar"),
        To_Unbounded_String ("\underline{\text{#1}}"), 1),
      253 => (To_Unbounded_String ("\urcorner"),
        To_Unbounded_String ("\html@mathml{\@urcorner}{\mathop{\char""231d}}"), 0),
      254 => (To_Unbounded_String ("\varDelta"),
        To_Unbounded_String ("\mathit{\Delta}"), 0),
      255 => (To_Unbounded_String ("\varGamma"),
        To_Unbounded_String ("\mathit{\Gamma}"), 0),
      256 => (To_Unbounded_String ("\varLambda"),
        To_Unbounded_String ("\mathit{\Lambda}"), 0),
      257 => (To_Unbounded_String ("\varOmega"),
        To_Unbounded_String ("\mathit{\Omega}"), 0),
      258 => (To_Unbounded_String ("\varPhi"),
        To_Unbounded_String ("\mathit{\Phi}"), 0),
      259 => (To_Unbounded_String ("\varPi"),
        To_Unbounded_String ("\mathit{\Pi}"), 0),
      260 => (To_Unbounded_String ("\varPsi"),
        To_Unbounded_String ("\mathit{\Psi}"), 0),
      261 => (To_Unbounded_String ("\varSigma"),
        To_Unbounded_String ("\mathit{\Sigma}"), 0),
      262 => (To_Unbounded_String ("\varTheta"),
        To_Unbounded_String ("\mathit{\Theta}"), 0),
      263 => (To_Unbounded_String ("\varUpsilon"),
        To_Unbounded_String ("\mathit{\Upsilon}"), 0),
      264 => (To_Unbounded_String ("\varXi"),
        To_Unbounded_String ("\mathit{\Xi}"), 0),
      265 => (To_Unbounded_String ("\varinjlim"),
        To_Unbounded_String ("\DOTSB\operatorname*{\underrightarrow{lim}}"), 0),
      266 => (To_Unbounded_String ("\varliminf"),
        To_Unbounded_String ("\DOTSB\operatorname*{\underline{lim}}"), 0),
      267 => (To_Unbounded_String ("\varlimsup"),
        To_Unbounded_String ("\DOTSB\operatorname*{\overline{lim}}"), 0),
      268 => (To_Unbounded_String ("\varprojlim"),
        To_Unbounded_String ("\DOTSB\operatorname*{\underleftarrow{lim}}"), 0),
      269 => (To_Unbounded_String ("\varsubsetneq"),
        To_Unbounded_String ("\html@mathml{\@varsubsetneq}{" &
          Character'Val (16#E2#) &
          Character'Val (16#8A#) &
          Character'Val (16#8A#) &
          "}"), 0),
      270 => (To_Unbounded_String ("\varsubsetneqq"),
        To_Unbounded_String ("\html@mathml{\@varsubsetneqq}{" &
          Character'Val (16#E2#) &
          Character'Val (16#AB#) &
          Character'Val (16#8B#) &
          "}"), 0),
      271 => (To_Unbounded_String ("\varsupsetneq"),
        To_Unbounded_String ("\html@mathml{\@varsupsetneq}{" &
          Character'Val (16#E2#) &
          Character'Val (16#8A#) &
          Character'Val (16#8B#) &
          "}"), 0),
      272 => (To_Unbounded_String ("\varsupsetneqq"),
        To_Unbounded_String ("\html@mathml{\@varsupsetneqq}{" &
          Character'Val (16#E2#) &
          Character'Val (16#AB#) &
          Character'Val (16#8C#) &
          "}"), 0),
      273 => (To_Unbounded_String ("\vcentcolon"),
        To_Unbounded_String ("\mathrel{\mathop\ordinarycolon}"), 0),
      274 => (To_Unbounded_String ("\vdots"),
        To_Unbounded_String ("{\varvdots\rule{0pt}{15pt}}"), 0),
      275 => (To_Unbounded_String ("\weierp"),
        To_Unbounded_String ("\wp"), 0),
      276 => (To_Unbounded_String ("~"),
        To_Unbounded_String ("\nobreakspace"), 0),
      277 => (To_Unbounded_String (Character'Val (16#C2#) &
          Character'Val (16#A9#)),
        To_Unbounded_String ("\copyright"), 0),
      278 => (To_Unbounded_String (Character'Val (16#C2#) &
          Character'Val (16#AE#)),
        To_Unbounded_String ("\textregistered"), 0),
      279 => (To_Unbounded_String (Character'Val (16#C2#) &
          Character'Val (16#B7#)),
        To_Unbounded_String ("\cdotp"), 0),
      280 => (To_Unbounded_String (Character'Val (16#E2#) &
          Character'Val (16#80#) &
          Character'Val (16#BC#)),
        To_Unbounded_String ("\mathclose{!\mkern-0.8mu!}"), 0),
      281 => (To_Unbounded_String (Character'Val (16#E2#) &
          Character'Val (16#84#) &
          Character'Val (16#8B#)),
        To_Unbounded_String ("\mathscr{H}"), 0),
      282 => (To_Unbounded_String (Character'Val (16#E2#) &
          Character'Val (16#84#) &
          Character'Val (16#8C#)),
        To_Unbounded_String ("\mathfrak{H}"), 0),
      283 => (To_Unbounded_String (Character'Val (16#E2#) &
          Character'Val (16#84#) &
          Character'Val (16#90#)),
        To_Unbounded_String ("\mathscr{I}"), 0),
      284 => (To_Unbounded_String (Character'Val (16#E2#) &
          Character'Val (16#84#) &
          Character'Val (16#92#)),
        To_Unbounded_String ("\mathscr{L}"), 0),
      285 => (To_Unbounded_String (Character'Val (16#E2#) &
          Character'Val (16#84#) &
          Character'Val (16#9B#)),
        To_Unbounded_String ("\mathscr{R}"), 0),
      286 => (To_Unbounded_String (Character'Val (16#E2#) &
          Character'Val (16#84#) &
          Character'Val (16#A8#)),
        To_Unbounded_String ("\mathfrak{Z}"), 0),
      287 => (To_Unbounded_String (Character'Val (16#E2#) &
          Character'Val (16#84#) &
          Character'Val (16#AC#)),
        To_Unbounded_String ("\mathscr{B}"), 0),
      288 => (To_Unbounded_String (Character'Val (16#E2#) &
          Character'Val (16#84#) &
          Character'Val (16#AD#)),
        To_Unbounded_String ("\mathfrak{C}"), 0),
      289 => (To_Unbounded_String (Character'Val (16#E2#) &
          Character'Val (16#84#) &
          Character'Val (16#B0#)),
        To_Unbounded_String ("\mathscr{E}"), 0),
      290 => (To_Unbounded_String (Character'Val (16#E2#) &
          Character'Val (16#84#) &
          Character'Val (16#B1#)),
        To_Unbounded_String ("\mathscr{F}"), 0),
      291 => (To_Unbounded_String (Character'Val (16#E2#) &
          Character'Val (16#84#) &
          Character'Val (16#B3#)),
        To_Unbounded_String ("\mathscr{M}"), 0),
      292 => (To_Unbounded_String (Character'Val (16#E2#) &
          Character'Val (16#88#) &
          Character'Val (16#89#)),
        To_Unbounded_String ("\notin"), 0),
      293 => (To_Unbounded_String (Character'Val (16#E2#) &
          Character'Val (16#88#) &
          Character'Val (16#8C#)),
        To_Unbounded_String ("\notni"), 0),
      294 => (To_Unbounded_String (Character'Val (16#E2#) &
          Character'Val (16#88#) &
          Character'Val (16#B7#)),
        To_Unbounded_String ("\dblcolon"), 0),
      295 => (To_Unbounded_String (Character'Val (16#E2#) &
          Character'Val (16#88#) &
          Character'Val (16#B9#)),
        To_Unbounded_String ("\eqcolon"), 0),
      296 => (To_Unbounded_String (Character'Val (16#E2#) &
          Character'Val (16#89#) &
          Character'Val (16#94#)),
        To_Unbounded_String ("\coloneqq"), 0),
      297 => (To_Unbounded_String (Character'Val (16#E2#) &
          Character'Val (16#89#) &
          Character'Val (16#95#)),
        To_Unbounded_String ("\eqqcolon"), 0),
      298 => (To_Unbounded_String (Character'Val (16#E2#) &
          Character'Val (16#89#) &
          Character'Val (16#98#)),
        To_Unbounded_String ("\html@mathml{\mathrel{=\kern{-1em}\raisebox{0.4em}{$\scriptsize\frown$}}}{\mathrel{\char`" &
          Character'Val (16#E2#) &
          Character'Val (16#89#) &
          Character'Val (16#98#) &
          "}}"), 0),
      299 => (To_Unbounded_String (Character'Val (16#E2#) &
          Character'Val (16#89#) &
          Character'Val (16#99#)),
        To_Unbounded_String ("\html@mathml{\stackrel{\tiny\wedge}{=}}{\mathrel{\char`" &
          Character'Val (16#E2#) &
          Character'Val (16#89#) &
          Character'Val (16#98#) &
          "}}"), 0),
      300 => (To_Unbounded_String (Character'Val (16#E2#) &
          Character'Val (16#89#) &
          Character'Val (16#9A#)),
        To_Unbounded_String ("\html@mathml{\stackrel{\tiny\vee}{=}}{\mathrel{\char`" &
          Character'Val (16#E2#) &
          Character'Val (16#89#) &
          Character'Val (16#9A#) &
          "}}"), 0),
      301 => (To_Unbounded_String (Character'Val (16#E2#) &
          Character'Val (16#89#) &
          Character'Val (16#9B#)),
        To_Unbounded_String ("\html@mathml{\stackrel{\scriptsize\star}{=}}{\mathrel{\char`" &
          Character'Val (16#E2#) &
          Character'Val (16#89#) &
          Character'Val (16#9B#) &
          "}}"), 0),
      302 => (To_Unbounded_String (Character'Val (16#E2#) &
          Character'Val (16#89#) &
          Character'Val (16#9D#)),
        To_Unbounded_String ("\html@mathml{\stackrel{\tiny\mathrm{def}}{=}}{\mathrel{\char`" &
          Character'Val (16#E2#) &
          Character'Val (16#89#) &
          Character'Val (16#9D#) &
          "}}"), 0),
      303 => (To_Unbounded_String (Character'Val (16#E2#) &
          Character'Val (16#89#) &
          Character'Val (16#9E#)),
        To_Unbounded_String ("\html@mathml{\stackrel{\tiny\mathrm{m}}{=}}{\mathrel{\char`" &
          Character'Val (16#E2#) &
          Character'Val (16#89#) &
          Character'Val (16#9E#) &
          "}}"), 0),
      304 => (To_Unbounded_String (Character'Val (16#E2#) &
          Character'Val (16#89#) &
          Character'Val (16#9F#)),
        To_Unbounded_String ("\html@mathml{\stackrel{\tiny?}{=}}{\mathrel{\char`" &
          Character'Val (16#E2#) &
          Character'Val (16#89#) &
          Character'Val (16#9F#) &
          "}}"), 0),
      305 => (To_Unbounded_String (Character'Val (16#E2#) &
          Character'Val (16#89#) &
          Character'Val (16#A0#)),
        To_Unbounded_String ("\neq"), 0),
      306 => (To_Unbounded_String (Character'Val (16#E2#) &
          Character'Val (16#8B#) &
          Character'Val (16#AE#)),
        To_Unbounded_String ("\vdots"), 0),
      307 => (To_Unbounded_String (Character'Val (16#E2#) &
          Character'Val (16#8C#) &
          Character'Val (16#9C#)),
        To_Unbounded_String ("\ulcorner"), 0),
      308 => (To_Unbounded_String (Character'Val (16#E2#) &
          Character'Val (16#8C#) &
          Character'Val (16#9D#)),
        To_Unbounded_String ("\urcorner"), 0),
      309 => (To_Unbounded_String (Character'Val (16#E2#) &
          Character'Val (16#8C#) &
          Character'Val (16#9E#)),
        To_Unbounded_String ("\llcorner"), 0),
      310 => (To_Unbounded_String (Character'Val (16#E2#) &
          Character'Val (16#8C#) &
          Character'Val (16#9F#)),
        To_Unbounded_String ("\lrcorner"), 0),
      311 => (To_Unbounded_String (Character'Val (16#E2#) &
          Character'Val (16#9F#) &
          Character'Val (16#82#)),
        To_Unbounded_String ("\perp"), 0),
      312 => (To_Unbounded_String (Character'Val (16#E2#) &
          Character'Val (16#9F#) &
          Character'Val (16#A6#)),
        To_Unbounded_String ("\llbracket"), 0),
      313 => (To_Unbounded_String (Character'Val (16#E2#) &
          Character'Val (16#9F#) &
          Character'Val (16#A7#)),
        To_Unbounded_String ("\rrbracket"), 0),
      314 => (To_Unbounded_String (Character'Val (16#E2#) &
          Character'Val (16#A6#) &
          Character'Val (16#83#)),
        To_Unbounded_String ("\lBrace"), 0),
      315 => (To_Unbounded_String (Character'Val (16#E2#) &
          Character'Val (16#A6#) &
          Character'Val (16#84#)),
        To_Unbounded_String ("\rBrace"), 0),
      316 => (To_Unbounded_String (Character'Val (16#E2#) &
          Character'Val (16#A6#) &
          Character'Val (16#B5#)),
        To_Unbounded_String ("\minuso"), 0),
      317 => (To_Unbounded_String (Character'Val (16#E2#) &
          Character'Val (16#A9#) &
          Character'Val (16#B4#)),
        To_Unbounded_String ("\Coloneqq"), 0),
      318 => (To_Unbounded_String (Character'Val (16#EF#) &
          Character'Val (16#B8#) &
          Character'Val (16#8F#)),
        To_Unbounded_String ("\textregistered"), 0));
   function Lookup (Name : String) return Macro_Record is
      Low : Integer := Entries'First;
      High : Integer := Entries'Last;
   begin
      while Low <= High loop
         declare
            Middle : constant Integer := (Low + High) / 2;
            Candidate : constant String := To_String (Entries (Middle).Name);
         begin
            if Name = Candidate then
               return (True, Entries (Middle).Template,
                 Entries (Middle).Num_Params);
            elsif Name < Candidate then
               High := Middle - 1;
            else
               Low := Middle + 1;
            end if;
         end;
      end loop;
      return (others => <>);
   end Lookup;
end Math_Builtin_Macros;
