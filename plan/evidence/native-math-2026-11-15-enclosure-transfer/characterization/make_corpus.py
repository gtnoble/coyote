import json, pathlib, sys
out=pathlib.Path(sys.argv[1]); c=out/'corpus'; c.mkdir(parents=True,exist_ok=True)
base=[r'\colorbox{red}{x}',r'\fcolorbox{blue}{#ffffff}{A}',r'\phase{x}',r'\phase{\frac{x}{y}}',r'\xcancel{x}',r'\widehat{abcdef}',r'\xrightarrow[b]{a}',r'\colorbox{#336699}{\sqrt{\frac{x_1+1}{y^2}}}',r'\fcolorbox{black}{#ffff00}{\xcancel{\widehat{xy}}}',r'\phase{\xrightarrow{\frac{a}{b}}}',r'a+\colorbox{red}{x}+b',r'\left(\fcolorbox{blue}{white}{\sqrt{x}}\right)',r'\widehat{\frac{a+b}{c}}',r'\xrightarrow[\colorbox{gray}{b}]{\widehat{a}}']
records=[]
for i in range(52):
 s=base[i%len(base)]
 if i%4==1: s=r'\colorbox{red}{'+s+r'}'
 if i%4==2: s=r'\fcolorbox{blue}{#ffeecc}{'+s+r'}'
 records.append({'id':f'base-{i:03}','source':s,'displayMode':bool(i%2), **({'options':{'fleqn':True}} if i%7==0 else {})})
(c/'baseline-regression.jsonl').write_text(''.join(json.dumps(x,separators=(',',':'))+'\n' for x in records))
heavy=[]
payloads=[r'x',r'\sqrt{\frac{a_1+b^2}{c_3+d}}',r'\xrightarrow[\frac{p}{q}]{\widehat{uv}}',r'\phase{\xcancel{\frac{m+n}{r}}}',r'\widehat{\sqrt{\frac{x+y}{z}}}']
for depth in (1,2,4,8,12,16):
 for variant in range(12):
  s=payloads[variant%len(payloads)]
  for k in range(depth):
   layer=(k+variant)%5
   if layer==0: s=r'\colorbox{#336699}{'+s+'}'
   elif layer==1: s=r'\fcolorbox{black}{#ffeecc}{'+s+'}'
   elif layer==2: s=r'\phase{'+s+'}'
   elif layer==3: s=r'\xcancel{'+s+'}'
   else: s=r'\widehat{'+s+'}'
  s=s+'+'+r'\xrightarrow[\colorbox{gray}{b}]{\widehat{a}}'
  heavy.append({'id':f'heavy-d{depth}-v{variant:02}','source':s,'displayMode':bool(variant%2), 'sequence':f'repeat-{variant%10}' if variant%3==0 else ''})
(c/'allocation-heavy.jsonl').write_text(''.join(json.dumps(x,separators=(',',':'))+'\n' for x in heavy))
repeat={'source':r'\colorbox{#336699}{\fcolorbox{black}{#ffeecc}{\phase{\xcancel{\widehat{\sqrt{\frac{a_1+b^2}{c_3+d}}}}}}}','displayMode':False}
(c/'repeat-10.jsonl').write_text(''.join(json.dumps(dict(repeat,id=f'repeat-{i:02}'),separators=(',',':'))+'\n' for i in range(10)))
for p in c.glob('*.jsonl'):
 rows=[json.loads(line) for line in p.read_text().splitlines()]
 assert max(map(lambda r:len(r['source'].encode()),rows))<65536
 assert all(r['source'].count('{')==r['source'].count('}') for r in rows)
 print(p.name,'records=',len(rows),'max_source_bytes=',max(len(r['source'].encode()) for r in rows),'total_source_bytes=',sum(len(r['source'].encode()) for r in rows))
