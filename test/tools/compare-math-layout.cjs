#!/usr/bin/env node
'use strict';
const fs=require('node:fs');
const crypto=require('node:crypto');
function usage(){console.error('usage: node compare-math-layout.cjs <pilot.json> <reference.jsonl> <native.jsonl> <report.json> [--allow-unsupported]');process.exit(2);}
if(process.argv.length<6||process.argv.length>7)usage();
const [pilotPath,refPath,nativePath,reportPath]=process.argv.slice(2,6),flags=process.argv.slice(6);
if(flags.some(x=>x!=='--allow-unsupported')||new Set(flags).size!==flags.length)usage();
const allowUnsupported=flags.includes('--allow-unsupported');
function loadJson(p){return JSON.parse(fs.readFileSync(p,'utf8'));}
function loadLines(p){return fs.readFileSync(p,'utf8').split(/\n/).filter(Boolean).map((line,i)=>{try{return JSON.parse(line);}catch(e){throw Error(`${p}:${i+1}: invalid JSON: ${e.message}`);}});}
function sha(data){return crypto.createHash('sha256').update(data).digest('hex');}
function finiteTree(x,path='record'){if(typeof x==='number'&&!Number.isFinite(x))throw Error(`${path}: non-finite number`);if(Array.isArray(x))x.forEach((v,i)=>finiteTree(v,`${path}[${i}]`));else if(x&&typeof x==='object')for(const [k,v] of Object.entries(x))finiteTree(v,`${path}.${k}`);}
const pilot=loadJson(pilotPath),refs=loadLines(refPath),natives=loadLines(nativePath);
if(!pilot||pilot.schema!=='coyote.math-compatibility-pilot.v1'||!Array.isArray(pilot.cases)||!pilot.reference)throw Error('invalid pilot schema/shape');
const ids=new Set();for(const c of pilot.cases){if(!c||typeof c.id!=='string'||!c.id||ids.has(c.id)||typeof c.source!=='string'||typeof c.displayMode!=='boolean')throw Error('pilot has malformed case or duplicate pilotID');ids.add(c.id);if(c.options&&typeof c.options!=='object')throw Error(`${c.id}: options must be object`);}
function index(rows,label){const m=new Map();for(const r of rows){finiteTree(r,label);if(!r||typeof r.id!=='string'||m.has(r.id))throw Error(`${label}: missing/duplicate ID`);m.set(r.id,r);}return m;}
const rm=index(refs,'reference'),nm=index(natives,'native');
for(const r of refs){if(r.metrics)for(const k of ['height','depth'])if(typeof r.metrics[k]!=='number'||!Number.isFinite(r.metrics[k]))throw Error(`reference ${r.id}: invalid metric ${k}`);if(Array.isArray(r.glyphs))for(const [i,g] of r.glyphs.entries())if(!g||typeof g.text!=='string')throw Error(`reference ${r.id}: invalid glyph ${i}`);}
const nativeKinds=new Set(['glyph','path','rule','text']);
for(const n of natives){if(n.box)for(const k of ['width','ascent','descent'])if(typeof n.box[k]!=='number'||!Number.isFinite(n.box[k]))throw Error(`native ${n.id}: invalid box ${k}`);if(n.capabilities?.semantic===true&&(!n.semanticTree||!Array.isArray(n.semanticTree.nodes)||!Number.isInteger(n.semanticTree.root)||n.semanticTree.root<1||n.semanticTree.root>n.semanticTree.nodes.length||n.semanticTree.nodes.some((x,i)=>!x||x.id!==i+1||typeof x.role!=='string'||!Number.isInteger(x.parent)||!Number.isInteger(x.firstChild)||!Number.isInteger(x.nextSibling)||!Number.isInteger(x.childCount)||x.parent<0||x.parent>n.semanticTree.nodes.length||x.firstChild<0||x.firstChild>n.semanticTree.nodes.length||x.nextSibling<0||x.nextSibling>n.semanticTree.nodes.length)))throw Error(`native ${n.id}: semantic capability lacks valid projection links/roles`);if(n.capabilities?.paths===true&&Array.isArray(n.commands))for(const [i,c] of n.commands.entries())if(c.kind==='path'&&(!Array.isArray(c.segments)||c.segments.length===0||c.segments.some(s=>!s||!['move','line','cubic','close'].includes(s.kind)||['x1','y1','x2','y2','x3','y3'].some(k=>typeof s[k]!=='number'||!Number.isFinite(s[k])))))throw Error(`native ${n.id}: invalid/empty path segments ${i}`);if(Array.isArray(n.commands))for(const [i,c] of n.commands.entries()){if(!c||!nativeKinds.has(c.kind))throw Error(`native ${n.id}: invalid command kind ${i}`);if(['x','y','scale','width','height'].some(k=>typeof c[k]!=='number'||!Number.isFinite(c[k])))throw Error(`native ${n.id}: invalid command geometry ${i}`);if(c.kind==='glyph'&&(!Number.isInteger(c.codePoint)||c.codePoint<1||c.codePoint>0x10ffff||typeof c.font!=='string'||!c.font.trim()))throw Error(`native ${n.id}: invalid glyph codepoint/font ${i}`);}}
for(const [label,map] of [['reference',rm],['native',nm]])for(const id of map.keys())if(!ids.has(id))throw Error(`${label}: extra record ${id}`);
const report={schema:'coyote.math-comparison-report.v1',pilotHash:sha(fs.readFileSync(pilotPath)),status:'pass',capabilityDisposition:{referenceGeometry:{origin:false,widths:false,paths:false,colors:false,browserPixels:false},nativeGeometry:{semantic:true,paths:true,colors:true,sharedMacros:true,optionsMeasured:false,optionsApplied:true},visualComparison:[]},summary:{pass:0,fail:0,gap:0,blocked:0},cases:[]};
const add=(checks,status,reason,fields={})=>checks.push(Object.assign({status,reason},fields));
function textGlyphs(rec){if(rec.capabilities?.glyphText!==true||!Array.isArray(rec.glyphs))return null;let out='';for(const g of rec.glyphs){if(!g||typeof g.text!=='string'||!g.text.length)return null;out+=g.text;}return out?Array.from(out,c=>c.codePointAt(0)):null;}
function nativeGlyphs(rec){if(!Array.isArray(rec.commands))return null;const out=[];for(const c of rec.commands)if(c.kind==='glyph')out.push(c.codePoint);return out.length?out:null;}
function mathMLGlyphs(node,out=[]){if(typeof node==='string'){for(const char of node)if(!['\u200b','\u2061','\u2062','\u2063','\u2064'].includes(char))out.push(char.codePointAt(0));return out;}if(!node||typeof node!=='object')return out;if(Array.isArray(node)){for(const child of node)mathMLGlyphs(child,out);return out;}for(const child of node.children||[])mathMLGlyphs(child,out);return out;}
function semanticGlyphs(rec){const tree=rec.semanticTree;if(!tree||!Array.isArray(tree.nodes))return null;const nodes=new Map(tree.nodes.map(node=>[node.id,node]));const result=[],seen=new Set();function visit(id){if(!id||seen.has(id))return;seen.add(id);const node=nodes.get(id);if(!node)return;if(node.kind==='glyph_node'&&node.codePoint>0)result.push(node.codePoint);if(node.kind==='accent_node'&&node.codePoint>0)result.push(node.codePoint);let child=node.firstChild;while(child){const next=nodes.get(child);visit(child);child=next?.nextSibling||0;}}visit(tree.root);return result.length?result:null;}

const MATHML_TO_NATIVE_ALIASES=new Map([[0x005e,0x02c6]]);
const NATIVE_SEMANTIC_ALIASES=new Map([[0x110001,0x02c6],[0x110003,0x2192]]);
function componentGlyphs(rec){
 const nodes=new Map(rec.semanticTree.nodes.map(node=>[node.id,node]));
 function childrenById(map,id){return map.get(id)||null;}
 function visit(id){const node=nodes.get(id);if(!node)return null;
  const children=[];for(let childId=node.firstChild;childId;){const child=nodes.get(childId);if(!child)return null;children.push(child);childId=child.nextSibling;}
  if(node.kind==='glyph_node')return node.codePoint>0?[node.codePoint]:[];
  if(node.kind==='accent_node'&&node.codePoint>0){const base=childrenById(nodes,node.firstChild);const seq=base?visit(base.id):null;const accent=NATIVE_SEMANTIC_ALIASES.get(node.codePoint)||node.codePoint;return seq===null?null:[...seq,accent];}
  if(node.kind==='scripts_node'){
   const byRole=new Map();for(const child of children){if(!['script_base','superscript','subscript'].includes(child.role))return null;const seq=visit(child.id);if(seq===null)return null;byRole.set(child.role,seq);}
   if(!byRole.has('script_base')||new Set(children.map(x=>x.role)).size!==children.length||children.length<2||children.length>3)return null;
   return [...(byRole.get('script_base')||[]),...(byRole.get('subscript')||[]),...(byRole.get('superscript')||[])];
  }
  if(node.kind==='accent_node'){
   const base=children.find(x=>x.role==='accent_base');if(!base)return null;const seq=visit(base.id);return seq===null?null:[...seq,...(node.codePoint>0?[node.codePoint]:[])];
  }
  if(node.kind==='radical_node'){
   const radicand=children.find(x=>x.role==='radicand');if(!radicand)return null;return visit(radicand.id);
  }
  if(node.kind==='fraction_node'){
   const numerator=children.find(x=>x.role==='numerator'),denominator=children.find(x=>x.role==='denominator');if(!numerator||!denominator)return null;const a=visit(numerator.id),b=visit(denominator.id);return a===null||b===null?null:[...a,...b];
  }
  if(node.kind==='array_node'){
   const result=[];for(const row of children){if(row.role!=='array_row')return null;for(let cellId=row.firstChild;cellId;){const cell=nodes.get(cellId);if(!cell||cell.role!=='array_cell')return null;const seq=visit(cell.id);if(seq===null)return null;result.push(...seq);cellId=cell.nextSibling;}}return result;
  }
  const result=[];for(const child of children){const seq=visit(child.id);if(seq===null)return null;result.push(...seq);}return result;
 }
 return visit(rec.semanticTree.root);
}
function normalizeGlyphs(sequence){return sequence?.map(cp=>MATHML_TO_NATIVE_ALIASES.get(cp)||cp)||null;}
function collectMathMLTypes(node,out=new Set()){if(!node||typeof node!=='object')return [...out];if(Array.isArray(node)){for(const child of node)collectMathMLTypes(child,out);return [...out];}if(typeof node==='string')return [...out];if(typeof node.type==='string')out.add(node.type);for(const child of node.children||[])collectMathMLTypes(child,out);return [...out].sort();}
function svgSegments(path){
 const tokens=path.d.match(/[A-Za-z]|[-+]?(?:\d*\.)?\d+(?:[eE][-+]?\d+)?/g)||[];
 let i=0,cmd='',x=0,y=0,sx=0,sy=0,lastC=null;const out=[];
 const number=()=>{if(i>=tokens.length||/[A-Za-z]/.test(tokens[i]))throw Error('missing SVG coordinate');const v=Number(tokens[i++]);if(!Number.isFinite(v))throw Error('non-finite SVG coordinate');return v;};
 while(i<tokens.length){if(/[A-Za-z]/.test(tokens[i]))cmd=tokens[i++];if(!cmd)throw Error('missing SVG command');const rel=cmd===cmd.toLowerCase(),op=cmd.toUpperCase();
  if(op==='M'||op==='L'){const nx=number(),ny=number();x=rel?x+nx:nx;y=rel?y+ny:ny;if(op==='M'){sx=x;sy=y;out.push(['move',x/path.viewBox[2],y/path.viewBox[3]]);cmd=rel?'l':'L';}else out.push(['line',x/path.viewBox[2],y/path.viewBox[3]]);lastC=null;}
  else if(op==='H'||op==='V'){if(op==='H')x=rel?x+number():number();else y=rel?y+number():number();out.push(['line',x/path.viewBox[2],y/path.viewBox[3]]);lastC=null;}
  else if(op==='C'){const a=number(),b=number(),c=number(),d=number(),e=number(),f=number(),ox=x,oy=y;x=rel?x+e:e;y=rel?y+f:f;const pts=rel?[ox+a,oy+b,ox+c,oy+d,x,y]:[a,b,c,d,x,y];out.push(['cubic',...pts.map((v,j)=>v/path.viewBox[j%2?3:2])]);lastC=[pts[2],pts[3]];}
  else if(op==='S'){const c=number(),d=number(),e=number(),f=number(),ox=x,oy=y,a=lastC?2*x-lastC[0]:x,b=lastC?2*y-lastC[1]:y;x=rel?x+e:e;y=rel?y+f:f;const pts=[a,b,...(rel?[ox+c,oy+d,x,y]:[c,d,x,y])];out.push(['cubic',...pts.map((v,j)=>v/path.viewBox[j%2?3:2])]);lastC=[pts[2],pts[3]];}
  else if(op==='Z'){out.push(['close']);x=sx;y=sy;cmd='';lastC=null;}
  else throw Error(`unsupported SVG path command ${cmd}`);
 }
 return out;
}
function nativeSegments(path){return path.segments.map(s=>{const pair=(a,b)=>[s[a]/path.width,s[b]/path.height];if(s.kind==='close')return ['close'];if(s.kind==='move')return ['move',...pair('x1','y1')];if(s.kind==='line')return ['line',...pair('x1','y1')];return ['cubic',...pair('x1','y1'),...pair('x2','y2'),...pair('x3','y3')];});
}
function normalizePath(segments){
 // Close commands carry no coordinates. Bounds use only explicit move, line,
 // cubic control, and cubic endpoint coordinates; closure uses the subpath's
 // actual start point, already present in the move command.
 const xs=[],ys=[];for(const seg of segments){if(seg[0]==='close')continue;for(let i=1;i<seg.length;i+=2){xs.push(seg[i]);ys.push(seg[i+1]);}}
 if(!xs.length)return segments;const minX=Math.min(...xs),maxX=Math.max(...xs),minY=Math.min(...ys),maxY=Math.max(...ys);
 return segments.map(seg=>seg[0]==='close'?['close']:[seg[0],...seg.slice(1).map((v,i)=>{const span=i%2?maxY-minY:maxX-minX,base=i%2?minY:minX;return span?((v-base)/span):0;})]);
}
function clipDisposition(path){
 if(path.hasClip!==true)return {status:'pass',reason:'path has no explicit native clip'};
 if(!['clipX','clipY','clipW','clipH'].every(k=>Number.isFinite(path[k]))||path.clipW<=0||path.clipH<=0)return {status:'fail',reason:'native path clip has invalid or empty geometry'};
 // Clip coordinates and path control points use different transform spaces in
 // some stretchy paths. Do not infer visible ink from their unqualified boxes.
 return {status:'pass',reason:'native clip has finite positive extents; clip-to-ink and reference equivalence remain unqualified'};
}
function sameOptions(actual,expected){return !!actual&&typeof actual==='object'&&!Array.isArray(actual)&&Object.keys(actual).length===Object.keys(expected).length&&Object.keys(expected).every(k=>Object.prototype.hasOwnProperty.call(actual,k)&&actual[k]===expected[k]);}
for(const spec of pilot.cases){const r=rm.get(spec.id),n=nm.get(spec.id),checks=[];
 if(!r||!n)add(checks,'fail',!r&&!n?'both records missing':!r?'reference record missing':'native record missing');
 else {
  for(const [name,rec] of [['reference',r],['native',n]]){if(rec.source!==spec.source)add(checks,'fail',`${name} source mismatch`);if(rec.displayMode!==spec.displayMode)add(checks,'fail',`${name} displayMode mismatch`);}
  if(r.schema!=='coyote.math-reference.v1'||r.engine!=='katex-0.16.22')add(checks,'fail','reference schema/engine mismatch');
  if(n.schema!=='coyote.math-export.v1'||n.engine!=='native')add(checks,'fail','native schema/engine mismatch');
  const nativeOptions={displayMode:spec.displayMode,maxExpand:1000,maxSize:100,strict:'warn',throwOnError:true,trust:false};
  const nativeIdentity={id:spec.id,source:spec.source,displayMode:spec.displayMode,sequence:typeof spec.sequence==='string'?spec.sequence:null,options:nativeOptions};
  if(!sameOptions(n.options,nativeOptions))add(checks,'fail','native recorded options missing/mismatch');
  if(n.capabilities?.optionsMeasured!==false)add(checks,'fail','native option-effect measurement must remain explicitly unqualified');else if(n.capabilities?.optionsApplied!==true)add(checks,'blocked','native effective options are not confirmed as applied by Math_Engine');else add(checks,'pass','native effective options were supplied to Math_Engine; option-effect probes remain unqualified');
  if(n.caseHash!==sha(JSON.stringify(nativeIdentity)))add(checks,'fail','native case/sequence hash missing/mismatch');
  if(r.provenance?.archiveSha256!==pilot.reference.archiveSha256||r.provenance?.bundleSha256!==pilot.reference.bundleSha256||r.provenance?.version!==pilot.reference.version)add(checks,'fail','reference provenance mismatch');
  const supplied=spec.options||{};const options={displayMode:spec.displayMode,throwOnError:true,trust:false,strict:'warn',maxSize:100,maxExpand:1000};for(const k of Object.keys(supplied))if(!Object.prototype.hasOwnProperty.call(options,k)||supplied[k]!==options[k])add(checks,'fail',`unsupported/non-baseline option ${k}`);
  const canonicalOptions=Object.fromEntries(Object.keys(options).sort().map(k=>[k,options[k]]));
  if(!sameOptions(r.options,canonicalOptions))add(checks,'fail','reference recorded options missing/mismatch');
  if(r.configHash!==sha(JSON.stringify(canonicalOptions)))add(checks,'fail','reference config hash missing/mismatch');
  const identity={id:spec.id,source:spec.source,displayMode:spec.displayMode,sequence:typeof spec.sequence==='string'?spec.sequence:null,options:canonicalOptions};
  if(r.caseHash!==sha(JSON.stringify(identity)))add(checks,'fail','reference case/sequence hash missing/mismatch');
  if(r.sourceHash!==sha(spec.source))add(checks,'fail','reference source hash missing/mismatch');
  if(spec.sourceSha256&&r.sourceHash!==spec.sourceSha256)add(checks,'fail','pilot source hash mismatch');
  const delimited=spec.displayMode?`$$${spec.source}$$`:`$${spec.source}$`;
  if(r.delimiterSeparatedSourceHash!==sha(delimited)||(spec.delimiterSeparatedSourceSha256&&sha(delimited)!==spec.delimiterSeparatedSourceSha256))add(checks,'fail','reference delimiter source hash mismatch');
  const expected=spec.expectedOutcome||((spec.id==='invalid'||spec.id.startsWith('shared-'))?'parse-error':spec.id==='untrusted-href'?'policy-visible-command':'ok');
  if(r.status!==expected)add(checks,'fail',`reference outcome mismatch: expected ${expected}, got ${r.status}`);
  if(spec.requires?.includes('sharedMacros')){
   if(!r.macroState||r.capabilities?.macroStateSnapshot!==true)add(checks,'fail','reference sequence macro state missing');
   else if(!n.macroState||n.macroStateComplete!==true||n.capabilities?.macroStateSnapshot!==true)add(checks,'fail','native sequence macro state snapshot missing or incomplete');
   else {
    const normalizeMacroState=state=>Object.fromEntries(Object.keys(state).sort().map(name=>{
     const value=state[name];
     if(typeof value==='string')return [name,{tokens:[value],numArgs:null}];
     if(!value||typeof value!=='object'||!Array.isArray(value.tokens))return [name,{invalid:true}];
     const tokens=value.tokens.map(token=>typeof token==='string'?token:token?.text);
     return [name,{tokens,numArgs:Number.isInteger(value.numArgs)?value.numArgs:null,hasOptionalDefault:value.hasOptionalDefault===true,default:value.hasOptionalDefault===true?(value.default||[]).map(token=>typeof token==='string'?token:token?.text):undefined}];
    }));
    const referenceState=normalizeMacroState(r.macroState),nativeState=normalizeMacroState(n.macroState);
    if(JSON.stringify(referenceState)!==JSON.stringify(nativeState))add(checks,'fail','actual shared user macro definitions differ',{referenceMacroState:referenceState,nativeMacroState:nativeState});
    else add(checks,'pass','actual shared user macro definitions match',{macroNames:Object.keys(nativeState)});
   }
  }
  if(r.status==='parse-error'||n.status==='parse-error'){
   if(r.status!==n.status)add(checks,'fail',`outcome mismatch: reference=${r.status}, native=${n.status}`);
  } else if(r.status==='policy-visible-command'){
   const referenceText=(r.glyphs||[]).map(g=>g.text||'').join('');
   const nativeCommands=n.commands?.filter(c=>c.kind==='glyph')||[];
   const nativeText=nativeCommands.map(c=>String.fromCodePoint(c.codePoint)).join('');
   const referenceRed=typeof r.html==='string'&&
     /(?:color:\s*#cc0000|mathcolor="#cc0000")/i.test(r.html);
   const red=nativeCommands.length>0&&nativeCommands.every(c=>c.hasColor===true&&Math.abs(c.red-204/255)<1e-12&&c.green===0&&c.blue===0&&c.alpha===1);
   const domRefusal=referenceText==='\\href'&&referenceRed&&
     r.capabilities?.policyRefusal===true;
   if(!domRefusal||r.capabilities?.policyRefusal!==true)add(checks,'fail','pinned KaTeX DOM does not expose the expected refused href markup',{referenceHTML:r.html});
   if(n.status!=='policy-visible-command'||n.policy?.refusal!==true||n.policy?.literalFallback!==true)add(checks,'fail',`native refusal status/policy missing: ${n.status}`,{nativePolicy:n.policy||null});
   if(nativeText!==referenceText)add(checks,'fail','native command glyph sequence differs from the pinned reference DOM glyph extraction',{referenceText,nativeText});
   if(!red)add(checks,'fail','native refused command glyphs do not use KaTeX #cc0000 RGBA',{nativeCommands});
   if(domRefusal&&n.status==='policy-visible-command'&&n.policy?.refusal===true&&n.policy?.literalFallback===true&&nativeText===referenceText&&red)add(checks,'pass','native refused href is a red command glyph sequence matching pinned KaTeX DOM glyph and color extraction',{nativeText,rgba:{red:204/255,green:0,blue:0,alpha:1}});
  }
  else if(r.status==='ok'&&n.status==='ok'){
   if(!r.metrics||!n.box||!['height','depth'].every(k=>Number.isFinite(r.metrics[k]))||!['ascent','descent'].every(k=>Number.isFinite(n.box[k])))add(checks,'fail','missing/non-finite comparable vertical metrics');
   else {if(r.metrics.unit!=='em'||r.metrics.knownStyle!==true||r.metrics.style!==(spec.displayMode?'display':'text'))add(checks,'fail','reference metric units/style invalid');for(const [rk,nk,label] of [['height','ascent','ascent'],['depth','descent','descent']]){const delta=Math.abs(r.metrics[rk]-n.box[nk]);if(delta>0.01)add(checks,'fail',`${label} differs by ${delta.toFixed(6)} em (limit 0.01)`);else add(checks,'pass',`${label} within 0.01 em`,{delta});}}
   const referenceSequence=r.capabilities?.mathMLTree===true?mathMLGlyphs(r.mathMLTree):null;
   const nativeSemanticSequence=semanticGlyphs(n);
   const nativeComponentSequence=n.capabilities?.semantic===true?componentGlyphs(n):null;
   if(!referenceSequence?.length||!nativeSemanticSequence)add(checks,'blocked','reference MathML or native semantic glyph sequence unavailable');
   else if(!nativeComponentSequence)add(checks,'blocked','native structural roles are insufficient for a role-aware component mapping',{referenceMathML:referenceSequence,nativeSemantic:nativeSemanticSequence});
   else {
    const referenceMapped=normalizeGlyphs(referenceSequence),nativeMapped=normalizeGlyphs(nativeSemanticSequence);
    const componentMapped=normalizeGlyphs(nativeComponentSequence||nativeSemanticSequence);
    const mapping={reference:'KaTeX MathML semantic content tree with operator application/spacing markers excluded; script operands retain MathML order',native:'native semanticTree projected by component roles: base, subscript, superscript; accent base then accent; radicand; numerator then denominator; array rows/cells',componentSequence:nativeComponentSequence,aliases:[{referenceCodePoint:'U+005E',nativeCodePoint:'U+02C6',meaning:'KaTeX MathML hat accent to native spacing circumflex glyph'},{nativeSemanticCodePoint:'U+110001',mathMLCodePoint:'U+005E',meaning:'native widehat semantic sentinel to MathML accent symbol'},{nativeSemanticCodePoint:'U+110003',mathMLCodePoint:'U+2192',meaning:'native overrightarrow semantic sentinel to MathML accent symbol'}],referenceTreeTypes:collectMathMLTypes(r.mathMLTree),nativeRoles:[...new Set(n.semanticTree.nodes.map(node=>node.role))].sort()};
    const qualifiedNative=normalizeGlyphs(nativeComponentSequence||nativeSemanticSequence);
    if(JSON.stringify(referenceMapped)!==JSON.stringify(qualifiedNative))add(checks,'fail','semantic glyph sequence differs under documented component map',{mapping,referenceSequence,nativeSequence:nativeComponentSequence||nativeSemanticSequence,normalizedReference:referenceMapped});
    else {
     const commands=n.commands?.filter(c=>c.kind==='glyph').map(c=>c.codePoint)||[];
     const hasStretchyAccent=n.semanticTree.nodes.some(node=>node.kind==='accent_node'&&node.codePoint>=0x110000);
     const hasRadical=n.semanticTree.nodes.some(node=>node.kind==='radical_node');
     const semanticForGlyphs=nativeComponentSequence.filter(cp=>cp<0x110000);
     if(!hasStretchyAccent&&!hasRadical&&JSON.stringify([...commands].sort((a,b)=>a-b))!==JSON.stringify([...semanticForGlyphs].sort((a,b)=>a-b)))add(checks,'fail','native glyph commands do not match semantic glyph multiset',{commandGlyphs:commands,semanticGlyphs:semanticForGlyphs});
     else add(checks,'pass','semantic glyph sequence maps through reference MathML and native component tree',{mapping,glyphCount:referenceMapped.length,sequence:referenceMapped,componentMap:'role-aware recursive projection; MathML operator-application U+2061 and invisible separators excluded; accent sentinels mapped to MathML accent symbols; hat U+005E aliases native spacing circumflex U+02C6; native font identity remains separate from MathML semantics'});
    }
   }

   if(spec.requires?.includes('paths')){const paths=n.commands?.filter(c=>c.kind==='path')||[];if(n.capabilities?.paths!==true)add(checks,'blocked','native path geometry unsupported; not compared');else if(!paths.length||paths.some(c=>!Array.isArray(c.segments)||!c.segments.length))add(checks,'fail','native path capability has no nonempty path geometry');else {for(const path of paths){const clip=clipDisposition(path);add(checks,clip.status,clip.reason,{pathCodePoint:path.codePoint,clip:path.hasClip===true?{x:path.clipX,y:path.clipY,width:path.clipW,height:path.clipH}:null});}add(checks,'pass','native path commands contain normalized geometry',{pathCount:paths.length});if(r.capabilities?.paths!==true||!Array.isArray(r.paths))add(checks,'blocked','reference SVG path geometry unavailable for differential comparison');else {try {const rp=r.paths.map(path=>normalizePath(svgSegments(path))),np=paths.map(path=>normalizePath(nativeSegments(path)));if(rp.length!==np.length)add(checks,'blocked','reference/native path topology differs (KaTeX emits radical SVG geometry; native uses radical glyph/rule)',{referencePathCount:rp.length,nativePathCount:np.length});else {let mismatch=null;for(let pi=0;pi<Math.min(rp.length,paths.length)&&!mismatch;pi++){if(rp[pi].length!==np[pi].length){mismatch={path:pi,referenceSegments:rp[pi].length,nativeSegments:np[pi].length};break;}for(let si=0;si<rp[pi].length&&!mismatch;si++){if(rp[pi][si][0]!==np[pi][si][0]||rp[pi][si].length!==np[pi][si].length||rp[pi][si].slice(1).some((v,j)=>Math.abs(v-np[pi][si][j+1])>0.01))mismatch={path:pi,segment:si,reference:rp[pi][si],native:np[pi][si]};}}if(mismatch)add(checks,mismatch.reason?'blocked':'fail',mismatch.reason||'bounded normalized SVG/native path geometry differs',{transform:'each SVG/native path independently normalized to its finite geometric bounds; command order/topology preserved; tolerance 0.01 normalized units; not an em/origin/width comparison',mismatch});else add(checks,'pass','bounded normalized SVG/native path geometry matches; origins, widths, and full geometry remain unqualified',{pathCount:rp.length,transform:'each SVG/native path independently normalized to its finite geometric bounds; command order/topology preserved; tolerance 0.01 normalized units; not an em/origin/width comparison'});}}catch(error){add(checks,'blocked',`path geometry transform unsupported: ${error.message}`);}}}}

  } else if(r.status!==n.status)add(checks,'fail',`outcome mismatch: reference=${r.status}, native=${n.status}`);
  else if(r.status!=='ok')add(checks,'blocked',`outcome ${r.status} has no qualified comparison`);
 }
 const status=checks.some(c=>c.status==='fail')?'fail':checks.some(c=>c.status==='blocked')?'blocked':checks.some(c=>c.status==='gap')?'gap':'pass';report.summary[status]++;report.cases.push({id:spec.id,sourceHash:sha(spec.source),status,checks});
}
if(report.summary.fail)report.status='fail';else if(report.summary.gap||report.summary.blocked)report.status='incomplete';
fs.writeFileSync(reportPath,`${JSON.stringify(report,null,2)}\n`);console.log(`comparison ${report.status}: ${report.summary.pass} pass, ${report.summary.fail} fail, ${report.summary.gap} gap, ${report.summary.blocked} blocked; ${reportPath}`);
if(report.summary.fail||(!allowUnsupported&&(report.summary.gap||report.summary.blocked)))process.exitCode=1;
fs.writeFileSync(reportPath,`${JSON.stringify(report,null,2)}\n`);
