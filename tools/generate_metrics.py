#!/usr/bin/env python3
"""Generate Ada glyph metrics from the pinned KaTeX 0.16.22 data export."""
import hashlib
import json
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_bytes()
expected = '1e72fc6b451a565e60b1eb7e89f4738eb74f35edfcf3c9c273015700b42ae04d'
if hashlib.sha256(source).hexdigest() != expected:
    raise SystemExit('Expected unmodified KaTeX 0.16.22 fontMetricsData.js')
text = source.decode().split('export default ', 1)[1].strip().rstrip(';')
text = text.replace(',\n    }', '\n    }').replace(',\n}', '\n}')
data = json.loads(text)
fonts = [('Main_Regular', 'Main-Regular'), ('Main_Bold', 'Main-Bold'),
         ('AMS_Regular', 'AMS-Regular'),
         ('Caligraphic_Regular', 'Caligraphic-Regular'),
         ('Math_Italic', 'Math-Italic'),
         ('Size_1', 'Size1-Regular'), ('Size_2', 'Size2-Regular'),
         ('Size_3', 'Size3-Regular'), ('Size_4', 'Size4-Regular')]
lines = ['--  GENERATED from KaTeX 0.16.22 src/fontMetricsData.js (MIT).',
         '--  Copyright (c) 2013-2020 Khan Academy and other contributors.',
         '--  See ../../share/coyote/math/licenses/KaTeX-MIT.txt and',
         '--  ../../share/coyote/math/PROVENANCE.md.',
         'with Math_Model; use Math_Model;', '',
         'package body Math_Metrics is',
         '   function Lookup (Font : Font_Kind; Code_Point : Natural) return Glyph_Metric',
         '   is', '   begin', '      case Font is']
for ada, upstream in fonts:
    lines += [f'         when {ada} =>', '            case Code_Point is']
    for code, (depth, height, italic, skew, width) in data[upstream].items():
        prefix = '                  '
        code_value = str(code)
        code_value = f'{int(code_value):,}'.replace(',', '_')
        values = [float(width), float(height), float(depth), float(italic)]
        formatted = []
        for value in values:
            whole, fraction = f'{value:.9f}'.split('.')
            formatted.append(
                f'{whole}.{fraction[:3]}_{fraction[3:6]}_{fraction[6:]}')
        lines += [f'               when {code_value} =>',
                  f'{prefix}return',
                  f'                    (True, {formatted[0]}, {formatted[1]}, {formatted[2]},',
                  f'                     {formatted[3]});']
    lines += ['               when others =>',
              '                  return (others => <>);',
              '            end case;']
lines += ['      end case;', '   end Lookup;', 'end Math_Metrics;', '']
Path(sys.argv[2]).write_text('\n'.join(lines))
print('source sha256=' + hashlib.sha256(source).hexdigest())
print('generated ' + sys.argv[2])
