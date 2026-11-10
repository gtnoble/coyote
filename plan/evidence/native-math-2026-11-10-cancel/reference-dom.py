import functools, http.server, json, subprocess, threading
package='/tmp/coyote-katex-support-check/package'
handler=functools.partial(http.server.SimpleHTTPRequestHandler,directory=package)
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),handler)
threading.Thread(target=server.serve_forever,daemon=True).start()
def run(*args):
    return subprocess.check_output(['browser-ctl',*args],text=True).strip()
run('start'); sid='cancel-dom-probe'; run('session','new','--browser','chromium',sid)
try:
    run('navigate',sid,f'http://127.0.0.1:{server.server_port}/')
    js=r'''(async()=>{
      document.head.innerHTML='<link rel="stylesheet" href="/dist/katex.css"><style>.katex{font-size:1em}</style>';
      const script=document.createElement('script');script.src='/dist/katex.js';
      document.head.appendChild(script);await new Promise(r=>script.onload=r);
      const rows=[];
      for(const size of [24,48]) for(const source of ['T','\\cancel{T}','\\dot{\\cancel{T}}','TT','\\cancel{TT}','\\bcancel{T}','\\xcancel{T}','\\cancel{\\dot{T}}','\\cancel{\\textcolor{red}{T}}']) {
        document.body.innerHTML='<div id="m" style="font-size:'+size+'px"></div>';
        katex.render(source,document.querySelector('#m')); await document.fonts.ready;
        const rect=e=>{const r=e.getBoundingClientRect();return {x:r.x,y:r.y,w:r.width,h:r.height}};
        rows.push({source,size,leaves:[...document.querySelectorAll('.katex-html span')].filter(e=>!e.children.length&&e.textContent).map(e=>({text:e.textContent,...rect(e),marginRight:getComputedStyle(e).marginRight})),svg:[...document.querySelectorAll('svg')].map(e=>({rect:rect(e),overflow:getComputedStyle(e).overflow,fontSize:getComputedStyle(e).fontSize,lines:[...e.querySelectorAll('line')].map(l=>({x1:l.x1.baseVal.value,y1:l.y1.baseVal.value,x2:l.x2.baseVal.value,y2:l.y2.baseVal.value,stroke:getComputedStyle(l).strokeWidth,linecap:getComputedStyle(l).strokeLinecap}))})),bases:[...document.querySelectorAll('.katex-html > .base')].map(rect)});
      } return JSON.stringify(rows);
    })()'''
    value=run('eval',sid,js)
    print(value)
finally:
    run('session','delete',sid); server.shutdown()
