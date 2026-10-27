#!/usr/bin/env python3
"""Generate the production adapter for KaTeX 0.16.22 metrics."""
import hashlib
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_bytes()
expected = '1e72fc6b451a565e60b1eb7e89f4738eb74f35edfcf3c9c273015700b42ae04d'
if hashlib.sha256(source).hexdigest() != expected:
    raise SystemExit('Expected unmodified KaTeX 0.16.22 fontMetricsData.js')

faces = [
    ('AMS_Regular', 'AMS_Regular'),
    ('Caligraphic_Bold', 'Caligraphic_Bold'),
    ('Caligraphic_Regular', 'Caligraphic_Regular'),
    ('Fraktur_Bold', 'Fraktur_Bold'),
    ('Fraktur_Regular', 'Fraktur_Regular'),
    ('Main_Regular', 'Main_Regular'),
    ('Main_Bold', 'Main_Bold'),
    ('Main_Bold_Italic', 'Main_BoldItalic'),
    ('Main_Italic', 'Main_Italic'),
    ('Math_Bold_Italic', 'Math_BoldItalic'),
    ('Math_Italic', 'Math_Italic'),
    ('Sans_Serif_Bold', 'SansSerif_Bold'),
    ('Sans_Serif_Italic', 'SansSerif_Italic'),
    ('Sans_Serif_Regular', 'SansSerif_Regular'),
    ('Script_Regular', 'Script_Regular'),
    ('Size_1', 'Size1_Regular'),
    ('Size_2', 'Size2_Regular'),
    ('Size_3', 'Size3_Regular'),
    ('Size_4', 'Size4_Regular'),
    ('Typewriter_Regular', 'Typewriter_Regular'),
]
lines = [
    '--  GENERATED metric adapter for the complete KaTeX 0.16.22 tables.',
    '--  The authoritative glyph values and skew live in Math_Font_Data.',
    'with Math_Font_Data;',
    'with Math_Model;',
    '',
    'package body Math_Metrics is',
    '   function Face_For (Font : Math_Model.Font_Kind)',
    '      return Math_Font_Data.Font_Face',
    '   is',
    '   begin',
    '      case Font is',
]
for model_face, data_face in faces:
    lines += [
        f'         when Math_Model.{model_face} =>',
        f'            return Math_Font_Data.{data_face};',
    ]
lines += [
    '      end case;',
    '   end Face_For;',
    '',
    '   function Lookup',
    '     (Font : Math_Model.Font_Kind;',
    '      Code_Point : Natural) return Glyph_Metric',
    '   is',
    '      Value : constant Math_Font_Data.Glyph_Metric :=',
    '        Math_Font_Data.Lookup (Face_For (Font), Code_Point);',
    '   begin',
    '      return',
    '        (Found   => Value.Found,',
    '         Width   => Value.Width,',
    '         Ascent  => Value.Ascent,',
    '         Descent => Value.Descent,',
    '         Italic  => Value.Italic,',
    '         Skew    => Value.Skew);',
    '   end Lookup;',
    'end Math_Metrics;',
    '',
]
Path(sys.argv[2]).write_text('\n'.join(lines))
print('source sha256=' + hashlib.sha256(source).hexdigest())
print('generated ' + sys.argv[2])
