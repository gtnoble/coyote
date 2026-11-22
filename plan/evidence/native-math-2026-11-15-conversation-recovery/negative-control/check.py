from pathlib import Path
import subprocess,os,hashlib
p=Path('src/coyote_gui/coyote_gui-rich_text.adb');fixed=p.read_bytes();old=subprocess.check_output(['git','show','HEAD:src/coyote_gui/coyote_gui-rich_text.adb']);out=Path('/tmp/coyote-conversation-negative');(out/'fixed.sha256').write_text(hashlib.sha256(fixed).hexdigest()+'\n');(out/'old.sha256').write_text(hashlib.sha256(old).hexdigest()+'\n');(out/'tests.sha256').write_text(hashlib.sha256(Path('test/src/coyote_gui_conversation_stack_tests.adb').read_bytes()).hexdigest()+'\n')
env=os.environ.copy();env.pop('WAYLAND_DISPLAY',None);env['GDK_BACKEND']='x11';env['G_DEBUG']='fatal-criticals'
try:
 p.write_bytes(old)
 with (out/'old-build.log').open('w') as f:r=subprocess.run(['alr','build','--development','--profiles=coyote=development'],cwd='test',stdout=f,stderr=subprocess.STDOUT,timeout=120)
 assert r.returncode==0
 for name,case in [('retained','Coyote.GUI.Conversation_Stack releases retained math buffer images'),('conversation','Coyote.GUI.Conversation_Stack preserves mixed math response source')]:
  with (out/(name+'.log')).open('w') as f:r=subprocess.run(['xvfb-run','-a','-s','-screen 0 1280x1024x24 -nolisten tcp','./bin/coyote_test',case],cwd='test',env=env,stdout=f,stderr=subprocess.STDOUT,timeout=30)
  print(name,'old-body exit',r.returncode,flush=True);assert r.returncode==1
finally:
 p.write_bytes(fixed)
 with (out/'restored-build.log').open('w') as f:r=subprocess.run(['alr','build','--development','--profiles=coyote=development'],cwd='test',stdout=f,stderr=subprocess.STDOUT,timeout=120)
 assert r.returncode==0 and p.read_bytes()==fixed
print('PASS both final regressions reject old cleanup; fixed body restored and rebuilt')
