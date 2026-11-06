with Ada.Text_IO;
with Ada.Strings.Unbounded;
with Math_Layout;
with Math_Paths;
with Math_Syntax;

procedure Math_Geometry_Probe is
   use type Math_Layout.Math_Style;
   use type Math_Layout.Command_Kind;

   procedure Show
     (Name, Source : String;
      Style : Math_Layout.Math_Style := Math_Layout.Text_Style)
   is
      Settings : Math_Syntax.Options :=
        (Display_Mode => Style = Math_Layout.Display_Style, others => <>);
      Layout : constant Math_Layout.Box := Math_Layout.Build
        (Math_Syntax.Parse (Source, Settings), Style);
   begin
      if Layout.Valid then
         Ada.Text_IO.Put_Line
           (Name & " " & Long_Float'Image (Layout.Ascent) & " " &
            Long_Float'Image (Layout.Descent) & " " &
            Long_Float'Image (Layout.Width));
      else
         Ada.Text_IO.Put_Line (Name & " ERROR");
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            Name & " ERROR " &
              Ada.Strings.Unbounded.To_String (Layout.Message));
      end if;
   end Show;

   procedure Check_Right_Arrow_Clip is
      Layout : constant Math_Layout.Box := Math_Layout.Build
        (Math_Syntax.Parse ("\xrightarrow{abcdef}"));
      Found : Boolean := False;
   begin
      if Layout.Valid then
         for Command of Layout.Commands loop
            if Command.Kind = Math_Layout.Path_Command and then
              Command.Has_Clip
            then
               declare
                  Max_X : Long_Float := Long_Float'First;
               begin
                  Found := True;
                  for Segment of Command.Path_Data loop
                     Max_X := Long_Float'Max (Max_X, Segment.First.X);
                     Max_X := Long_Float'Max (Max_X, Segment.Second.X);
                     Max_X := Long_Float'Max (Max_X, Segment.Third.X);
                  end loop;
                  if Max_X < Command.Clip_X or else
                    Command.Clip_X + Command.Clip_W - Max_X > 0.001
                  then
                     Ada.Text_IO.Put_Line
                       (Ada.Text_IO.Standard_Error,
                        "rightarrow tip not visible at clip edge: tip=" &
                        Long_Float'Image (Max_X) & " clip=" &
                        Long_Float'Image (Command.Clip_X) & ".." &
                        Long_Float'Image
                          (Command.Clip_X + Command.Clip_W));
                     raise Program_Error;
                  end if;
               end;
            end if;
         end loop;
      end if;
      if not Found then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error, "rightarrow clip path missing");
         raise Program_Error;
      end if;
   end Check_Right_Arrow_Clip;
begin
   Check_Right_Arrow_Clip;
   Show ("contour-oiint-text", "\oiint");
   Show ("contour-oiint-display", "\oiint", Math_Layout.Display_Style);
   Show ("contour-oiiint-text", "\oiiint");
   Show ("contour-oiiint-display", "\oiiint", Math_Layout.Display_Style);
   Show ("contour-raw-oiint-text", "∯");
   Show ("contour-raw-oiint-display", "∯", Math_Layout.Display_Style);
   Show ("contour-raw-oiiint-text", "∰");
   Show ("contour-raw-oiiint-display", "∰", Math_Layout.Display_Style);
   Show
     ("array-hline-top", "\begin{array}{c}\hline a\end{array}");
   Show
     ("array-hline-interior",
      "\begin{array}{c}a\\\hline b\end{array}");
   Show ("array-hline-repeated-top", "\begin{array}{c}\hline\hline a\end{array}");
   Show ("array-hline-repeated-interior",
     "\begin{array}{c}a\\\hline\hline b\end{array}");
   Show
     ("array-hdashline", "\begin{array}{c}a\\\hdashline b\end{array}");
   Show ("dot-x", "\dot{x}");
   Show ("ddot-T-sub-a", "\ddot{T}_a");
   Show ("heatbalance-first-term", "\dot{Q}_{\mathrm{in}}");
   Show ("hat-x", "\hat{x}");
   Show ("T-sub-a", "T_a");
   Show ("x-sub-a", "x_a");
   Show ("dot-T-sub-a", "\dot T_a");
   Show ("dot-group-T-sub-a", "\dot{T_a}");
   Show ("hat-x-sup-2", "\hat{x}^2");
   Show ("frac-sub-script", "\frac{a}{b}_c");
   Show ("fraction-xy", "\frac{x}{y}");
   Show ("spacing-medspace-colon", "a\:b");
   Show ("spacing-medspace-greater", "a\>b");
   Show ("break-allow", "a\allowbreak b");
   Show ("break-forbid", "a\nobreak b");
   Show ("callable-newline", "\newline");
   Show ("callable-notag", "\notag");
   Show ("callable-nonumber", "\nonumber");
   Show ("callable-tag-literal", "\tag{A}x", Math_Layout.Display_Style);
   Show ("callable-approx-equal", "≘");
   Show ("callable-approx-equal-composed", "a≘b");
   Show ("callable-not-equal", "\ne");
   Show ("callable-not-equal-alias", "\neq");
   Show ("sqrt-abcdef", "\sqrt{abcdef}");
   Show ("sqrt-nested-fraction", "\sqrt{\frac{x}{y}}");
   Show ("sqrt-x-plus-one", "\sqrt{x+1}");
   Show ("widehat-abcdef", "\widehat{abcdef}");
   Show ("overrightarrow-xy", "\overrightarrow{xy}");
   Show ("wideaccent-pilot", "\widehat{abcdef}+\overrightarrow{xy}+\sqrt{abcdef}");
   Show ("widecheck-one", "\widecheck{x}");
   Show ("widecheck-two", "\widecheck{xy}");
   Show ("widecheck-three", "\widecheck{xyz}");
   Show ("widecheck-four", "\widecheck{wxyz}");
   Show ("widecheck-five", "\widecheck{vwxyz}");
   Show ("widecheck-six", "\widecheck{uvwxyz}");
   Show ("widecheck-long", "\widecheck{abcdefg}");
   Show ("utilde-one", "\utilde{x}");
   Show ("utilde-two", "\utilde{xy}");
   Show ("utilde-three", "\utilde{xyz}");
   Show ("utilde-four", "\utilde{wxyz}");
   Show ("utilde-five", "\utilde{vwxyz}");
   Show ("utilde-six", "\utilde{uvwxyz}");
   Show ("phase-one", "\phase{x}");
   Show ("phase-fraction", "\phase{\frac{x}{y}}");
   Show ("angl-one", "\angl{x}");
   Show ("angl-group", "\angl{xy}");
   Show ("sqrt-x-squared-text", "\sqrt{x^2}");
   Show ("frac-x-squared-text", "\frac{x^2}{y^2}");
   Show ("sqrt-frac-squared-text", "\sqrt{\frac{1}{x^2}}");
   Show ("sqrt-x-squared-display", "\sqrt{x^2}", Math_Layout.Display_Style);
   Show ("frac-x-squared-display", "\frac{x^2}{y^2}", Math_Layout.Display_Style);
   Show ("sqrt-frac-squared-display", "\sqrt{\frac{1}{x^2}}", Math_Layout.Display_Style);
   Show ("script-cascade", "\scriptstyle{\sqrt{\frac{1}{x^2}}^2}");
   Show ("display-script-cascade", "\displaystyle\sqrt{\frac{1}{x^2}}^2");
   Show ("frac-default", "\frac{a}{b}");
   Show ("tfrac-default", "\tfrac{a}{b}");
   Show ("dfrac-text", "\dfrac{a}{b}");
   Show ("frac-nested", "\frac{1+\frac{x}{y}}{z}");
   Show ("tfrac-nested", "\tfrac{1+\tfrac{x}{y}}{z}");
   Show ("dfrac-script", "\scriptstyle{\dfrac{x^2}{\frac{1}{y}}}");
   Show ("sqrt-index", "\sqrt[3]{x^2+1}");
   Show ("sqrt-index-fraction", "\sqrt[\frac{1}{2}]{\dfrac{x}{y}}");
   Show ("display-tfrac", "\tfrac{a+b}{c+d}", Math_Layout.Display_Style);
   Show ("display-nested-dfrac", "\dfrac{1+\dfrac{x}{y}}{z}", Math_Layout.Display_Style);
   Show ("smallmatrix-fraction", "\begin{smallmatrix}1 & \frac{x}{y} \\ a^2 & \sqrt{b}\end{smallmatrix}");
   Show ("dcases-radical", "\begin{dcases} \sqrt{x} & x \ge 0 \\ \frac{1}{x} & x < 0 \end{dcases}");
   Show ("rule-default", "\rule{1em}{0.1em}");
   Show ("rule-raised-positive", "\rule[0.2em]{1em}{0.1em}");
   Show ("rule-raised-negative", "\rule[-0.2em]{1em}{0.1em}");
   Show ("raisebox-positive", "\raisebox{0.2em}{x}");
   Show ("raisebox-negative", "\raisebox{-0.2em}{x}");
   Show ("hbox-inline-multatom", "x+y");
   Show ("hbox-display-multatom", "x+y", Math_Layout.Display_Style);
   Show ("sized-tiny-half", "\tiny{x}");
   Show ("sized-sixpt-six-tenths", "\sixptsize{x}");
   Show ("sized-huge", "\Huge{x}");
   Show ("sized-huge-multatom", "\Huge x+y");
   Show ("sized-tiny-huge-nested", "\tiny{\Huge{x}}");
   Show ("sized-huge-tiny-nested", "\Huge{\tiny{x}}");
   Show ("style-textstyle-scope", "\textstyle{\sqrt{x^2}}");
   Show ("style-displaystyle-scope", "\displaystyle{\sqrt{x^2}}");
   Show ("style-scriptstyle-scope", "\scriptstyle{\sqrt{x^2}}");
   Show ("style-scriptscriptstyle-scope", "\scriptscriptstyle{\sqrt{x^2}}");
   Show ("cancel-x", "\cancel{x}");
   Show ("bcancel-x", "\bcancel{x}");
   Show ("xcancel-x", "\xcancel{x}");
   Show ("sout-x", "\sout{x}");
   Show ("smash-x", "\smash{x}");
   Show ("smash-x-squared", "\smash{x^2}");
   Show ("style-textstyle-multatom", "\textstyle{x+y}");
   Show ("overbrace-x", "\overbrace{x}");
   Show ("underbrace-x", "\underbrace{x}");
   Show ("overbrace-x-plus-y", "\overbrace{x+y}");
   Show ("underbrace-x-plus-y", "\underbrace{x+y}");
   Show ("overbrace-script", "\overbrace{x+y}^{n}");
   Show ("underbrace-script", "\underbrace{x+y}_{n}");
   Show ("overbrace-opposite-script", "\overbrace{x+y}_{n}");
   Show ("underbrace-opposite-script", "\underbrace{x+y}^{n}");
   Show ("label-xrightarrow-text", "\xrightarrow[b]{a}");
   Show ("label-xleftarrow-display", "\xleftarrow[b]{a}", Math_Layout.Display_Style);
   Show ("label-Overrightarrow-text", "\Overrightarrow[b]{a}");
   Show ("label-xRightarrow-display", "\xRightarrow[b]{a}", Math_Layout.Display_Style);
   Show ("label-xLeftarrow-text", "\xLeftarrow[b]{a}");
   Show ("label-overleftharpoon-display", "\overleftharpoon[b]{a}", Math_Layout.Display_Style);
   Show ("label-xleftharpoonup-text", "\xleftharpoonup[b]{a}");
   Show ("label-xleftharpoondown-display", "\xleftharpoondown[b]{a}", Math_Layout.Display_Style);
   Show ("label-overrightharpoon-text", "\overrightharpoon[b]{a}");
   Show ("label-xrightharpoonup-display", "\xrightharpoonup[b]{a}", Math_Layout.Display_Style);
   Show ("label-xrightharpoondown-text", "\xrightharpoondown[b]{a}");
   Show ("label-xlongequal-display", "\xlongequal[b]{a}", Math_Layout.Display_Style);
   Show ("label-xtwoheadleftarrow-text", "\xtwoheadleftarrow[b]{a}");
   Show ("label-xtwoheadrightarrow-display", "\xtwoheadrightarrow[b]{a}", Math_Layout.Display_Style);
   Show ("label-xleftrightarrow-text", "\xleftrightarrow[b]{a}");
   Show ("label-xLeftrightarrow-display", "\xLeftrightarrow[b]{a}", Math_Layout.Display_Style);
   Show ("label-xrightleftharpoons-text", "\xrightleftharpoons[b]{a}");
   Show ("label-xleftrightharpoons-display", "\xleftrightharpoons[b]{a}", Math_Layout.Display_Style);
   Show ("label-xhookleftarrow-text", "\xhookleftarrow[b]{a}");
   Show ("label-xhookrightarrow-display", "\xhookrightarrow[b]{a}", Math_Layout.Display_Style);
   Show ("label-xmapsto-text", "\xmapsto[b]{a}");
   Show ("label-xtofrom-display", "\xtofrom[b]{a}", Math_Layout.Display_Style);
   Show ("accent-overrightarrow-text", "\overrightarrow{abcdef}");
   Show ("accent-underleftarrow-display", "\underleftarrow{abcdef}", Math_Layout.Display_Style);
   Show ("sized-big-left-paren", "\bigl(");
   Show ("sized-big-right-paren", "\bigr)");
   Show ("sized-big-right-bracket", "\bigr]");
   Show ("sized-big-right-brace", "\bigr\}");
   Show ("sized-big-bar", "\big|");
   Show ("delimiter-braket-macro", "\Braket{a}{b}");
   Show ("delimiter-braket-middle", "\left\langle a \middle| b \right\rangle");
   Show ("sized-Big-left-paren", "\Bigl(");
   Show ("sized-Big-right-paren", "\Bigr)");
   Show ("sized-Big-right-bracket", "\Bigr]");
   Show ("sized-Big-right-brace", "\Bigr\}");
   Show ("sized-Big-bar", "\Big|");
   Show ("sized-bigg-left-paren", "\biggl(");
   Show ("sized-bigg-right-paren", "\biggr)");
   Show ("sized-bigg-right-bracket", "\biggr]");
   Show ("sized-bigg-right-brace", "\biggr\}");
   Show ("sized-bigg-bar", "\bigg|");
   Show ("sized-Bigg-left-paren", "\Biggl(");
   Show ("sized-Bigg-right-paren", "\Biggr)");
   Show ("sized-Bigg-right-bracket", "\Biggr]");
   Show ("sized-Bigg-right-brace", "\Biggr\}");
   Show ("sized-Bigg-bar", "\Bigg|");
   Show ("mathchoice-text", "\mathchoice{a}{\sqrt{x}}{x^2}{\sum}");
   Show ("mathchoice-display", "\mathchoice{a}{\sqrt{x}}{x^2}{\sum}", Math_Layout.Display_Style);
   Show ("mathchoice-script", "\scriptstyle{\mathchoice{a}{\sqrt{x}}{x^2}{\sum}}");
   Show ("mathchoice-scriptscript", "\scriptscriptstyle{\mathchoice{a}{\sqrt{x}}{x^2}{\sum}}");
   Show ("mathchoice-text-cramped", "\sqrt{\mathchoice{a}{\sqrt{x}}{x^2}{\sum}}");
   Show ("mathchoice-display-cramped", "\sqrt{\mathchoice{a}{\sqrt{x}}{x^2}{\sum}}", Math_Layout.Display_Style);
   Show ("mathchoice-script-cramped", "\scriptstyle{\sqrt{\mathchoice{a}{\sqrt{x}}{x^2}{\sum}}}");
   Show ("mathchoice-scriptscript-cramped", "\scriptscriptstyle{\sqrt{\mathchoice{a}{\sqrt{x}}{x^2}{\sum}}}");
   Show ("fraction-genfrac-default", "\genfrac{}{}{}{}{a}{b}");
   Show ("fraction-genfrac-nobar-zero", "\genfrac{}{}{0pt}{}{a}{b}");
   Show ("fraction-genfrac-custom-02", "\genfrac{}{}{0.2pt}{}{a}{b}");
   Show ("fraction-genfrac-custom-05", "\genfrac{}{}{0.5pt}{}{x+y}{z}");
   Show ("fraction-genfrac-delimited", "\genfrac{(}{)}{0.2pt}{}{a}{b}");
   Show ("fraction-genfrac-left-only", "\genfrac{[}{}{0pt}{}{a}{b}");
   Show ("fraction-genfrac-style-display", "\genfrac{}{}{0pt}{0}{a}{b}");
   Show ("fraction-genfrac-style-text", "\genfrac{}{}{0pt}{1}{a}{b}");
   Show ("fraction-genfrac-style-script", "\genfrac{}{}{0pt}{2}{a}{b}");
   Show ("fraction-genfrac-style-scriptscript", "\genfrac{}{}{0pt}{3}{a}{b}");
   Show ("fraction-genfrac-display-bar", "\genfrac{}{}{0.2pt}{0}{x+y}{z}");
   Show ("fraction-genfrac-text-bar", "\genfrac{}{}{0.2pt}{1}{x+y}{z}");
   Show ("fraction-genfrac-script-bar", "\genfrac{}{}{0.2pt}{2}{x+y}{z}");
   Show ("fraction-genfrac-sscript-bar", "\genfrac{}{}{0.2pt}{3}{x+y}{z}");
   Show ("fraction-cfrac-default", "\cfrac{a}{b}");
   Show ("fraction-cfrac-left", "\cfrac[l]{x+y}{z}");
   Show ("fraction-cfrac-right", "\cfrac[r]{x+y}{z}");
   Show ("fraction-cfrac-display", "\cfrac{\frac{a}{b}}{c}", Math_Layout.Display_Style);
   Show ("fraction-infix-over", "a\over b");
   Show ("fraction-infix-choose", "a\choose b");
   Show ("fraction-infix-atop", "a\atop b");
   Show ("fraction-infix-brace", "a\brace b");
   Show ("fraction-infix-above-zero", "a\above{0pt}b");
   Show ("fraction-infix-above-custom", "a\above{0.2pt}b");
   Show ("fraction-stack-above", "\stackrel{n}{=}");
   Show ("fraction-stack-binary", "a+\stackrel{n}{=}b");
   Show ("fraction-overset-relation", "a\overset{n}{=}b");
   Show ("fraction-overset-binary", "a\overset{n}{+}b");
   Show ("support-vcenter-frac",
     "\vcenter{\hbox{$\frac{a+b}{\dfrac{c}{d}}$}}");
   Show ("support-vcenter-x", "\vcenter{\hbox{$x$}}");
   Show ("support-vcenter-atom", "\vcenter{x}");
   Show ("support-pmb-x", "\pmb{x}");
   Show ("support-pmb-relation", "a\pmb{\leq}b");
   Show ("support-pmb-display", "\pmb{x+y}", Math_Layout.Display_Style);
   Show ("verb-plain", "\verb|a b~|", Math_Layout.Text_Style);
   Show ("verb-starred", "\verb*|a b~|", Math_Layout.Text_Style);
   Show ("verb-subscript", "x_{\verb*|a b|}", Math_Layout.Text_Style);
   Show ("verb-superscript", "x^{\verb|a b|}", Math_Layout.Text_Style);
   Show ("verb-display-style", "\verb*|a b|", Math_Layout.Display_Style);
   Show ("verb-star-space-only", "\verb*| |", Math_Layout.Text_Style);
   Show ("text-cedilla-below", "\text{\c{c}}");
   Show ("text-circled-full", "\text{\textcircled{R}}");
   Show ("colorbox-red-x", "\colorbox{red}{x}");
   Show ("colorbox-text-space", "\colorbox{red}{a b}");
   Show ("fcolorbox-white-a", "\fcolorbox{blue}{#ffffff}{A}");
   Show ("fcolorbox-math-dollar", "\fcolorbox{blue}{#ffffff}{$x^2$}");
   Show ("cd-empty", "\begin{CD}\end{CD}");
   Show ("cd-empty-horizontal-label", "\begin{CD}A@>x>>B\end{CD}");
   Show ("cd-empty-vertical-label", "\begin{CD}A@VVV\\B\end{CD}");
   Show
     ("cd-two-by-two",
      "\begin{CD} A @>f>> B \\ @VgVV @AAhA \\ C @>>k> D \end{CD}");
   Show
     ("cd-grouped-label",
      "\begin{CD}A@>{x>y}>z>B\end{CD}");
   Show ("cd-horizontal-right", "\begin{CD}A@>f>>B\end{CD}");
   Show ("cd-horizontal-left", "\begin{CD}X@<g<<Y\end{CD}");
   Show ("cd-long-equal", "\begin{CD}C@=D\end{CD}");
   Show ("cd-vertical-up", "\begin{CD}A@AfAAB\\C\end{CD}");
   Show ("cd-vertical-down", "\begin{CD}X@VgVV\\Y\end{CD}");
   Show ("cd-markers", "\begin{CD}A@|B@.C\\D@|E@.F\end{CD}");
   Show ("cd-mixed", "\begin{CD}P@>f>>Q&R@VgVV\\S@<h<<T&U\end{CD}");
   Show ("delimiter-angle", "\left\langle x \right\rangle");
   Show ("delimiter-angle-raw", "\left< x \right>");
   Show ("delimiter-floor", "\left\lfloor x \right\rfloor");
   Show ("delimiter-ceiling", "\left\lceil x \right\rceil");
   Show ("delimiter-floor-large", "\left\lfloor \frac{x}{y} \right\rfloor");
   Show ("delimiter-ceiling-large", "\left\lceil \frac{x}{y} \right\rceil");
   Show ("delimiter-angle-sized", "\bigl\langle");
   Show ("delimiter-floor-sized", "\bigl\lfloor");
   Show ("delimiter-ceiling-sized", "\bigl\lceil");
   Show ("delimiter-doublebar", "\left\Vert x \right\Vert");
   Show ("delimiter-doublebar-sized", "\Big\Vert");
   Show ("raw-vertical-bar", "a|b");
end Math_Geometry_Probe;
