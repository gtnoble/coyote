from pathlib import Path
import hashlib,subprocess,os
p=Path('test/src/coyote_gui_conversation_stack_tests.adb');saved=p.read_text();out=Path('/tmp/coyote-conversation-ownership');(out/'baseline.adb').write_text(saved)
start=saved.index('   procedure Test_Conversation_Preserves_Mixed_Math_Response');end=saved.index('   end Test_Conversation_Preserves_Mixed_Math_Response;',start)+len('   end Test_Conversation_Preserves_Mixed_Math_Response;')
proc=saved[start:end]
selstart=proc.index('         Buffer.Get_Iter_At_Line (First, 0);');selend=proc.index('         Buffer.Place_Cursor (First);',selstart)+len('         Buffer.Place_Cursor (First);')
variants={'baseline':proc,'no-copy':proc[:selstart]+proc[selend:],'unrealized':proc.replace('         T.Parent.Show_All;','         null;')}
env=os.environ.copy();env.pop('WAYLAND_DISPLAY',None);env['GDK_BACKEND']='x11';env['G_DEBUG']='fatal-criticals'
try:
 for name,v in variants.items():
  q=out/name;q.mkdir(exist_ok=True);p.write_text(saved[:start]+v+saved[end:]);(q/'source.sha256').write_text(hashlib.sha256(p.read_bytes()).hexdigest()+'\n')
  (q/'variant.patch').write_text(subprocess.check_output(['git','diff','--','test/src/coyote_gui_conversation_stack_tests.adb'],text=True))
  with (q/'build.log').open('w') as f:r=subprocess.run(['alr','build','--development','--profiles=coyote=development'],cwd='test',stdout=f,stderr=subprocess.STDOUT,timeout=120)
  assert r.returncode==0,name
  with (q/'probe.log').open('w') as f:r=subprocess.run(['xvfb-run','-a','-s','-screen 0 1280x1024x24 -nolisten tcp','./bin/coyote_test','Coyote.GUI.Conversation_Stack preserves mixed math response source'],cwd='test',env=env,stdout=f,stderr=subprocess.STDOUT,timeout=30)
  print(name,'rc',r.returncode,flush=True)
  for line in (q/'probe.log').read_text().splitlines():
   if any(t in line for t in ['baseline=','Failed Assertions','CONVERSATION_MATH']):print(line,flush=True)
finally:
 p.write_text(saved)
 with (out/'restored-build.log').open('w') as f:r=subprocess.run(['alr','build','--development','--profiles=coyote=development'],cwd='test',stdout=f,stderr=subprocess.STDOUT,timeout=120)
 assert r.returncode==0
 assert p.read_text()==saved
 print('RESTORED',hashlib.sha256(p.read_bytes()).hexdigest())
