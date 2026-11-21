#!/usr/bin/env python3
"""Run fixed math exporter corpora normally and under Valgrind for comparison."""
import argparse, json, pathlib, re, subprocess, sys
p=argparse.ArgumentParser()
p.add_argument('label'); p.add_argument('binary',type=pathlib.Path)
a=p.parse_args(); root=pathlib.Path(__file__).resolve().parent
logdir=root/'logs'/a.label; logdir.mkdir(parents=True,exist_ok=True)
for name in ('baseline-regression','allocation-heavy','repeat-10'):
 corpus=root/'corpus'/f'{name}.jsonl'; normal=logdir/f'{name}.jsonl'; vgout=logdir/f'{name}.valgrind.jsonl'; vglog=logdir/f'{name}.valgrind.log'
 with corpus.open('rb') as src,normal.open('wb') as dst: subprocess.run([str(a.binary)],stdin=src,stdout=dst,check=True)
 command=['valgrind','--max-stackframe=4194304','--error-exitcode=1','--leak-check=full','--show-leak-kinds=all',f'--log-file={vglog}','--xtree-memory=allocs',f'--xtree-memory-file={logdir / (name + ".xtree.kcg")}',str(a.binary)]
 with corpus.open('rb') as src,vgout.open('wb') as dst: subprocess.run(command,stdin=src,stdout=dst,check=True)
 if normal.read_bytes()!=vgout.read_bytes(): raise SystemExit(f'{name}: normal and Valgrind output differs')
 text=vglog.read_text()
 totals=re.search(r'total heap usage: ([\d,]+) allocs, ([\d,]+) frees, ([\d,]+) bytes allocated',text)
 lost=re.search(r'definitely lost: ([^\n]+).*?indirectly lost: ([^\n]+).*?possibly lost: ([^\n]+)',text,re.S)
 errors=re.search(r'ERROR SUMMARY: ([^\n]+)',text)
 rows=[json.loads(line) for line in normal.read_text().splitlines()]
 if not rows or any(row.get('status')!='ok' for row in rows): raise SystemExit(f'{name}: non-ok or empty output')
 commands=sum(len(row.get('commands') or []) for row in rows)
 paths=[c for row in rows for c in row.get('commands') or [] if c.get('kind')=='path']
 segments=sum(len(c.get('segments') or []) for c in paths)
 print(f'{a.label}/{name}: records={len(rows)} commands={commands} paths={len(paths)} path_segments={segments} allocations={totals.group(1)} frees={totals.group(2)} heap_bytes={totals.group(3)} lost={lost.group(1).strip()} | {lost.group(2).strip()} | {lost.group(3).strip()} errors={errors.group(1).strip()}')
