#!/usr/bin/env node
'use strict';
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const {spawnSync} = require('node:child_process');

const ROOT = path.resolve(__dirname, '../..');
const ARCHIVE_SHA256 = 'e9e0d167db3175481cbadaff38e8d90b130f6a3ddb451a47e43c577fd511f365';
const BUNDLE_SHA256 = '8f1f4fb1080439c012bb8fddf424fa253e9144ab4cdd7dc0eae0e92cd04a5e33';
const FONT_BASES = ['KaTeX_AMS-Regular','KaTeX_Caligraphic-Bold','KaTeX_Caligraphic-Regular','KaTeX_Fraktur-Bold','KaTeX_Fraktur-Regular','KaTeX_Main-BoldItalic','KaTeX_Main-Bold','KaTeX_Main-Italic','KaTeX_Main-Regular','KaTeX_Math-BoldItalic','KaTeX_Math-Italic','KaTeX_SansSerif-Bold','KaTeX_SansSerif-Italic','KaTeX_SansSerif-Regular','KaTeX_Script-Regular','KaTeX_Size1-Regular','KaTeX_Size2-Regular','KaTeX_Size3-Regular','KaTeX_Size4-Regular','KaTeX_Typewriter-Regular'];
const ASSET_FILES = ['package/package.json','package/dist/katex.js','package/dist/katex.css', ...FONT_BASES.flatMap(name => ['ttf','woff','woff2'].map(ext => `package/dist/fonts/${name}.${ext}`))];
function extractAssets(archive, dest) {
  if (sha(fs.readFileSync(archive)) !== ARCHIVE_SHA256) die('KaTeX archive SHA-256 mismatch');
  const entries = [];
  for (const member of ASSET_FILES) {
    const listing = spawnSync('tar', ['-tvzf', archive, member], {encoding:'utf8'});
    const rows = listing.stdout.trim().split('\n');
    const match = rows.find(row => row.slice(0,10).trimStart().startsWith('-') && row.endsWith(` ${member}`));
    if (listing.status !== 0 || !match) die(`archive member is missing or not a regular file: ${member}`);
    const extracted = spawnSync('tar', ['-xOzf', archive, member], {encoding:null,maxBuffer:32*1024*1024});
    if (extracted.status !== 0) die(`cannot read archive member ${member}`);
    const rel = member.slice('package/'.length), output = path.join(dest, rel);
    fs.mkdirSync(path.dirname(output), {recursive:true});
    fs.writeFileSync(output, extracted.stdout);
    entries.push([rel, sha(extracted.stdout)]);
  }
  const version = JSON.parse(fs.readFileSync(path.join(dest,'package.json'),'utf8')).version;
  if (version !== '0.16.22') die(`archive package version is ${version}, expected 0.16.22`);
  if (sha(fs.readFileSync(path.join(dest,'dist/katex.js'))) !== BUNDLE_SHA256) die('KaTeX archive bundle SHA-256 mismatch');
  entries.sort((a,b) => a[0].localeCompare(b[0]));
  return {version, verifiedFilesHash:sha(entries.map(([name,hash]) => `${name} ${hash}\n`).join('')), verifiedFiles:entries};
}
function die(message) { console.error(`math browser export: ${message}`); process.exit(2); }
function sha(bytes) { return crypto.createHash('sha256').update(bytes).digest('hex'); }
function run(args, options={}) {
  const p = spawnSync(process.env.BROWSER_CTL || 'browser-ctl', args, {encoding:'utf8',timeout:120000,maxBuffer:32*1024*1024,...options});
  if (p.error || p.status !== 0) throw Error((p.stderr || p.error?.message || `command exited ${p.status}`).trim());
  return p.stdout.trim();
}
if (process.argv.length !== 4) die('usage: node export-math-browser.cjs <pinned-katex.tgz> <package-root> < requests.jsonl > browser.jsonl');
const archive = path.resolve(process.argv[2]), pkg = path.resolve(process.argv[3]);
try { if (!fs.statSync(pkg).isDirectory()) die('package-root argument is not a directory'); } catch (e) { die(e.message); }
const requests = fs.readFileSync(0,'utf8').split(/\n/).filter(Boolean).map((line,i)=>{let c;try{c=JSON.parse(line)}catch(e){die(`line ${i+1}: ${e.message}`)}if(typeof c.id!=='string'||typeof c.source!=='string'||typeof c.displayMode!=='boolean')die(`line ${i+1}: needs string id/source and boolean displayMode`);if(c.sequence||c.options?.macros)die(`${c.id}: shared macro state is unsupported by isolated browser cases`);return c;});
if (!requests.length) die('input contains no cases');
const temp = fs.mkdtempSync(path.join(os.tmpdir(),'coyote-math-browser-'));
const sid = 'coyote-math-browser-' + process.pid + '-' + crypto.randomBytes(4).toString('hex');
try {
 const extracted=extractAssets(archive,temp);
 const dist=temp;
 const embedded=JSON.stringify(requests).replace(/</g,'\\u003c');
 const html=`<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="stylesheet" href="dist/katex.css"><script src="dist/katex.js"><\/script><style>*{box-sizing:border-box}html,body{margin:0;background:transparent}body{width:800px;padding:8px;color:#000;font:24px "KaTeX_Main",serif}.katex{font-size:24px!important}.case{display:block;margin:0 0 8px;white-space:pre-wrap}.katex-display{margin:0;text-align:left}</style></head><body><main id="cases"></main><script>const cases=${embedded};window.__mathBrowser={version:katex.version};for(const c of cases){const row=document.createElement('section');row.className='case';row.dataset.id=c.id;document.querySelector('#cases').append(row);try{katex.render(c.source,row,{displayMode:c.displayMode,throwOnError:true,trust:false,strict:'warn',maxSize:100,maxExpand:1000});row.dataset.status='ok'}catch(e){row.dataset.status='parse-error';row.dataset.error=String(e.message||e)}}document.fonts.ready.then(()=>{window.__mathBrowser.fontStatus=document.fonts.status;window.__mathBrowser.viewport={width:innerWidth,height:innerHeight,deviceScaleFactor:devicePixelRatio};window.__mathBrowser.rows=[...document.querySelectorAll('.case')].map(row=>{const r=row.querySelector('.katex')||row, b=r.getBoundingClientRect(), style=getComputedStyle(r), rect=q=>{const x=q.getBoundingClientRect();return{x:x.x,y:x.y,width:x.width,height:x.height}}, strut=r.querySelector('.katex-html .base .strut'), strutStyle=strut?getComputedStyle(strut):null, strutRect=strut?strut.getBoundingClientRect():null, baseline=strut?strutRect.top+parseFloat(strutStyle.height)+(parseFloat(strutStyle.verticalAlign)||0):null, glyphs=[...row.querySelectorAll('.katex-html span')].filter(e=>e.children.length===0&&e.textContent).map(e=>({text:e.textContent,font:e.className||null,box:rect(e)})),paths=[...row.querySelectorAll('svg path')].map(p=>({d:p.getAttribute('d'),box:rect(p)}));return{id:row.dataset.id,status:row.dataset.status,error:row.dataset.error||null,fontSizePx:parseFloat(style.fontSize),box:{x:b.x,y:b.y,width:b.width,height:b.height},strut:strut?{top:strutRect.top,height:parseFloat(strutStyle.height),verticalAlign:(parseFloat(strutStyle.verticalAlign)||0),baseline,baselineSource:'DOM strut top + computed height + computed vertical-align'}:null,glyphs,paths}})});</script></body></html>`;
 fs.writeFileSync(path.join(temp,'index.html'),html);
 run(['session','new','--browser','chromium',sid]);
 run(['navigate',sid,new URL(`file://${path.join(temp,'index.html')}`).href]);
 let data=null; const deadline=Date.now()+20000;
 while(!data){
  const raw=run(['eval',sid,'JSON.stringify(window.__mathBrowser||null)']);
  data=JSON.parse(raw);
  if(!data&&Date.now()>deadline)die('browser KaTeX measurements did not settle');
  if(!data)Atomics.wait(new Int32Array(new SharedArrayBuffer(4)),0,0,100);
 }
 const browserScreenshot=process.env.MATH_BROWSER_SCREENSHOT ? path.resolve(process.env.MATH_BROWSER_SCREENSHOT) : null;
 if(browserScreenshot) run(['screenshot',sid,'--output',browserScreenshot]);
 if(data.version!=='0.16.22'||data.fontStatus!=='loaded'||!Array.isArray(data.rows)||data.rows.length!==requests.length)die('browser did not return complete KaTeX/font measurements');
 for(const row of data.rows)if(row.fontSizePx!==24)die(`${row.id}: computed KaTeX font size ${row.fontSizePx}px, expected 24px`);
 for(let i=0;i<requests.length;i++){
  const c=requests[i],r=data.rows[i]; if(c.id!==r.id)die(`browser case order mismatch at ${i}`);
  const provenance={version:data.version,archiveSha256:ARCHIVE_SHA256,bundleSha256:BUNDLE_SHA256,verifiedFilesHash:extracted.verifiedFilesHash,verifiedFiles:extracted.verifiedFiles,browser:run(['eval',sid,'navigator.userAgent'])};
  process.stdout.write(JSON.stringify({schema:'coyote.math-browser.v1',engine:'katex-0.16.22-browser',provenance,id:r.id,source:c.source,displayMode:c.displayMode,status:r.status,error:r.error,viewport:{...data.viewport,contentWidth:800,fontSizePx:24,background:'transparent'},fontSizePx:r.fontSizePx,box:r.box,strut:r.strut,glyphs:r.glyphs,paths:r.paths,capabilities:{browserDOMGeometry:true,glyphBounds:true,svgPathData:true,pixels:false,semanticTree:false,componentMapping:false,unroundedStrutBaseline:r.strut!==null},screenshot:browserScreenshot,measurement:'Chromium DOM client rectangles in CSS pixels; baseline derives from unrounded strut DOM top and computed height/vertical-align; glyph records are leaf span boxes and may aggregate multiple code points; SVG paths are raw KaTeX path data with DOM bounds; not a native-vs-KaTeX pixel comparison'})+'\n');
 }
} catch(e) { die(e.message); }
finally {if(sid)try{run(['session','delete',sid])}catch{}fs.rmSync(temp,{recursive:true,force:true});}
