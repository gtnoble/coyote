#!/usr/bin/env node
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const fixture = JSON.parse(fs.readFileSync(path.join(root, 'test/fixtures/math-compatibility/callable-probes.json'), 'utf8'));
const die = message => { console.error(`math callable check: ${message}`); process.exit(2); };
const cliFlags = process.argv.slice(2).filter(arg => arg.startsWith('--'));
if (cliFlags.some(flag => !['--diagnostic','--self-test'].includes(flag))) die(`unknown option: ${cliFlags.find(flag => !['--diagnostic','--self-test'].includes(flag))}`);
const positional = process.argv.slice(2).filter(arg => !arg.startsWith('--'));
const archive = positional[0] ? path.resolve(positional[0]) : '';
const packageRoot = positional[1] ? path.resolve(positional[1]) : '';
if (positional.length !== 2) die('usage: check-math-callables.cjs <pinned-katex.tgz> <verified-package-root> [--diagnostic|--self-test]');
const semanticComparator=require('./math_semantic_compare.cjs');
const REPORT_SCOPE='role-aware MathML/native semantic projection; outcome match does not qualify geometry, font identity, options effectiveness, visual pixels, or full dialect parity';
const nativeProject=path.join(root,'test/native/math_export.gpr');
const buildRootEnv=process.env.MATH_CALLABLE_BUILD_ROOT;
const nativeBuildRoot=path.resolve(buildRootEnv || fs.mkdtempSync(path.join(require('node:os').tmpdir(),'coyote-math-callables-')));
const native = path.resolve(process.env.MATH_EXPORT_BIN || path.join(nativeBuildRoot,'bin/math_export'));
function ensureNative() {
 if(process.env.MATH_EXPORT_BIN) { if(!fs.existsSync(native)) die(`explicit native exporter does not exist: ${native}`); return; }
 const build=spawnSync('alr',['exec','--','gprbuild','-P',nativeProject,`-XMATH_EXPORT_ROOT=${nativeBuildRoot}`],{cwd:root,encoding:'utf8',timeout:240000,maxBuffer:16*1024*1024});
 if(build.error||build.status!==0) die(`fresh native exporter build failed: ${build.error?.message||build.stderr||build.status}\nstdout:\n${build.stdout||''}\nstderr:\n${build.stderr||''}`);
 if(!fs.existsSync(native)) die(`fresh native exporter missing after build: ${native}`);
}
const refExporter = path.join(root, 'test/tools/export-math-reference.cjs');
const timeoutMs = Number(process.env.MATH_CALLABLE_TIMEOUT_MS || 5000);
const diagnostic = process.argv.includes('--diagnostic');
if (!fs.existsSync(archive) || !fs.existsSync(packageRoot)) die('native exporter and verified local KaTeX package/archive are required');
if (fixture.schema !== 'coyote.math-callable-probes.v1' || fixture.entries.length !== 338 || fixture.count !== 338) die('fixture must contain exactly 338 entries');
function semanticWithAST(row) {
 const ast=new Map((row.nodes||[]).map(node=>[node.id,node]));
 if(!row.semanticTree||!Array.isArray(row.semanticTree.nodes))return row;
 return {...row,semanticTree:{...row.semanticTree,nodes:row.semanticTree.nodes.map(node=>({...node,ast:ast.get(node.astId)||null}))}};
}
const inventory = JSON.parse(fs.readFileSync(path.join(root, 'plan/native-math-katex-0.16.22-inventory.json'), 'utf8'));
const registry = inventory.registries.builtinMacros;
const sha = p => crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
if (sha(archive) !== fixture.reference.archiveSha256 || sha(path.join(packageRoot, 'dist/katex.js')) !== fixture.reference.bundleSha256) die('pinned archive/bundle hash mismatch');
const names = Object.keys(registry).sort();
if (names.length !== 338 || JSON.stringify(names) !== JSON.stringify(fixture.entries.map(e => e.macro).sort())) die('fixture macro names do not exactly cover pinned builtin inventory');
const hash = p => crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
let identity;
function runOne(command,args,request) {
 const r=spawnSync(command,args,{input:JSON.stringify(request)+'\n',encoding:'utf8',timeout:timeoutMs,maxBuffer:16*1024*1024});
 if(r.error||r.status!==0)return {failure:r.error?.code==='ETIMEDOUT'?'timeout':`process-error:${r.error?.message||r.stderr||r.status}`,stderr:r.stderr||''};
 const rows=[],sideOutput=[]; for(const line of r.stdout.split(/\n/).filter(Boolean)){try{rows.push(JSON.parse(line));}catch(_){sideOutput.push(line);}}
 return {rows,sideOutput,stderr:r.stderr||''};
}
const functionCallers = {'\\bra@ket':'\\Braket','\\bra@set':'\\Set','\\tag@literal':'\\tag'};
if(process.argv.includes('--self-test')) {
 const def=registry;
 const source=fixture.entries.find(e=>e.kind==='callable');
 const template=fixture.entries.find(e=>e.kind==='template'&&e.templateArity>0);
 const validResponse=(rows,id,src)=>rows.length===1&&rows[0].id===id&&rows[0].source===src;
 const semanticControls=semanticComparator.structuralNegativeControls();
 const semanticControlNames=['sameGrouping','roleMutationRejected','parentMismatchRejected','orphanRejected','spaceMatches','spaceAmountMutationRejected','unsupportedSpaceUnitRejected','unsupportedSpaceAttributeRejected','cycleRejected','phantomMatches','phantomRoleMutationRejected','choiceTextMatches','choiceDisplayBranchMatches','missingNativeColorRejected','colorMatches','colorMutationRejected'];
 for(const name of semanticControlNames)console.log(`${semanticControls[name]?'PASS':'FAIL'} negative-control: semantic ${name}`);
 if(semanticControlNames.some(name=>!semanticControls[name]))process.exit(2);
 const controls=[['callable source mutation rejected',!!(()=>{const e={...source,source:'\\Unknown'};const target=functionCallers[e.macro]||e.macro;return !e.source.startsWith(target)})()],['template arity mutation rejected',(()=>{const e={...template,templateArity:99};let n=0;const d=def[e.macro];for(let i=0;i<d.length;i++){if(d[i]==='#'&&d[i+1]==='#'){i++;continue;}if(d[i]==='#'&&/[1-9]/.test(d[i+1]||''))n=Math.max(n,Number(d[++i]));}return e.templateArity!==n})()],['duplicate response rejected',!validResponse([{id:'same',source:'x'},{id:'same',source:'x'}],'same','x')],['mutated identity rejected',!validResponse([{id:'valid',source:'changed'}],'valid','expected')],['invalid fixture source rejected',(()=>{const e=fixture.entries.find(x=>x.macro==='\\tag');return validateEntry({...e,source:'\\tag'})!==null})()],['missing JSON record rejected',!validResponse([],'valid','expected')],['failed exporter rejected',!!({failure:'process-error:synthetic'}).failure],['all repaired sources have valid contexts',fixture.entries.every(e=>!validateEntry(e))],['all original invalid sources removed',!fixture.entries.some(e=>['\\@hspace{x1}','\\@hspacer{x1}','\\@ifstar{x1}','\\Braket','\\Set','\\bgroup','\\egroup','\\hspace','\\operatorname','\\set','\\tag','\\tag@paren{x1}','\\tmspace{x1}{x2}{x3}'].includes(e.source))]];
 for(const [name,ok] of controls)console.log(`${ok?'PASS':'FAIL'} negative-control: ${name}`);
 if(controls.some(([,ok])=>!ok))process.exit(2);
 process.exit(0);
}
if (!fs.existsSync(archive) || !fs.existsSync(path.join(packageRoot, 'dist/katex.js'))) die('verified local KaTeX package/archive are required');
ensureNative();
if (!fs.existsSync(native)) die(`native exporter missing after build: ${native}`);
identity={fixtureSha256:hash(path.join(root,'test/fixtures/math-compatibility/callable-probes.json')),archiveSha256:sha(archive),bundleSha256:sha(path.join(packageRoot,'dist/katex.js')),nativeExecutable:native,nativeExecutableSha256:hash(native),freshBuild:!process.env.MATH_EXPORT_BIN};
function validateEntry(e) {
 const def=registry[e.macro];
 if(def==='[function]') {
  if(e.kind!=='callable')return 'fixture kind disagrees with function registry entry';
  const target=functionCallers[e.macro]||e.macro;
  if(!e.source.startsWith(target)&&e.macro!=='\\renewcommand')return `callable source does not invoke ${target}`;
  if(e.macro==='\\@firstoftwo'||e.macro==='\\@secondoftwo') {
   const rest=e.source.slice(e.macro.length);if(!/^\s*\{[^{}]*\}\s*\{[^{}]*\}/.test(rest))return 'callable requires two explicit braced alternatives';
  }
  if(e.macro==='\\@ifnextchar'&&!/^\\@ifnextchar\s+\S\s*\{[^{}]*\}\s*\{[^{}]*\}/.test(e.source))return 'callable requires lookahead token and both branches';
  if(e.macro==='\\TextOrMath'&&!/^\\TextOrMath\s*\{[^{}]*\}\s*\{[^{}]*\}/.test(e.source))return 'callable requires explicit text and math branches';
  if(['\\bra@ket','\\bra@set'].includes(e.macro)&&!/^\\(Braket|Set)\s*\{[^{}]+\}/.test(e.source))return 'helper requires valid public caller with one nonempty argument';
  if(e.macro==='\\tag@literal'&&(!e.displayMode||!/^\\tag\s*\{[^{}]+\}/.test(e.source)))return 'tag renderer requires display mode and nonempty public tag argument';
 } else if(typeof def==='string') {
  if(e.kind!=='template')return 'fixture kind disagrees with string-template registry definition';
  let arity=0;for(let i=0;i<def.length;i++){if(def[i]==='#'&&def[i+1]==='#'){i++;continue;}if(def[i]==='#'&&/[1-9]/.test(def[i+1]||''))arity=Math.max(arity,Number(def[++i]));}
  if(e.templateArity!==arity)return `template arity mismatch: fixture=${e.templateArity} registry=${arity}`;
  if(e.macro==='\\tag'&&(!e.displayMode||!/^\\begin\{(?:equation|align|gather|multline|flalign|alignat)\*?\}[^]*?\\tag\s*\{[^{}]+\}[^]*?\\end\{/.test(e.source)))return 'tag requires a nonempty argument inside an AMS display row';
  if(e.macro==='\\tag@paren'&&(!e.displayMode||!/^\\begin\{(?:equation|align|gather|multline|flalign|alignat)\*?\}[^]*?\\tag\s*\{[^{}]+\}[^]*?\\end\{/.test(e.source)))return 'tag helper requires public AMS display-row caller context';
  if(e.macro==='\\bgroup'&&!/\\bgroup[^]*\\egroup/.test(e.source))return 'opening group helper requires balanced closing context';
  if(e.macro==='\\egroup'&&!/\\bgroup[^]*\\egroup/.test(e.source))return 'closing group helper requires balanced opening context';
  if(e.macro==='\\@hspace'||e.macro==='\\@hspacer'||e.macro==='\\hspace'){if(!/\\(?:@hspace|@hspacer|hspace)\s*\{\s*(?:\d+(?:\.\d+)?|\.\d+)(?:em|ex|mu|pt|pc|px|mm|cm|in)\s*\}/.test(e.source))return 'spacing helper requires a valid dimension';}
  if(e.macro==='\\operatorname'&&!/\\operatorname\s*\{[^{}]+\}/.test(e.source))return 'operatorname requires a nonempty argument';
  if((e.macro==='\\Braket'||e.macro==='\\Set'||e.macro==='\\set')&&(!e.source.startsWith(e.macro)||!/^\\(?:Braket|Set|set)\s*\{[^{}]+\}/.test(e.source)))return 'set helper requires a nonempty argument';
  if(e.macro==='\\@ifstar'&&!/^\\@ifstar\s*\{[^{}]*\}\s*\{[^{}]*\}/.test(e.source))return 'star helper requires both branches';
  if(e.macro==='\\tmspace'&&!/^\\tmspace[+-]\s*\{\s*(?:\d+(?:\.\d+)?|\.\d+)mu\s*\}\s*\{\s*(?:\d+(?:\.\d+)?|\.\d+)(?:em|ex|mu|pt)\s*\}/.test(e.source))return 'tmspace requires valid signed math-unit and spacing dimensions';
  if(e.macro==='\\renewcommand'){const match=e.source.match(/^\\newcommand\s*\{(\\[A-Za-z]+)\}\s*\{[^{}]+\}\s*\\renewcommand\s*\{(\\[A-Za-z]+)\}\s*\{[^{}]+\}\s*(\\[A-Za-z]+)$/);if(!match||match[1]!==match[2]||match[1]!==match[3])return 'renewcommand probe must define, renew, and use the same local command';}
  const contextualTemplate=['\\egroup','\\tag','\\tag@paren'].includes(e.macro);
  if(!e.source.startsWith(e.macro)&&!contextualTemplate)return 'source does not begin with the registered macro token';
 } else return 'registry definition is neither a string template nor [function]';
 return null;
}
const malformed=fixture.entries.map(e=>({e,reason:validateEntry(e)})).filter(x=>x.reason);
if(malformed.length) die(`invalid fixture source/arity/context: ${malformed.map(x=>x.e.macro+': '+x.reason).join(' | ')}`);
const rows=[];
const outcomeSummary={match:0,deviation:0,blocked:0};
const semanticSummary={match:0,gap:0};
const mutationControl={fraction:{available:false,rejected:false},subscript:{available:false,rejected:false}};
const structuralControl=semanticComparator.structuralNegativeControls();
if(!structuralControl.sameGrouping||!structuralControl.roleMutationRejected||!structuralControl.parentMismatchRejected||!structuralControl.orphanRejected||!structuralControl.spaceMatches||!structuralControl.spaceAmountMutationRejected||!structuralControl.unsupportedSpaceUnitRejected||!structuralControl.unsupportedSpaceAttributeRejected||!structuralControl.cycleRejected||!structuralControl.phantomMatches||!structuralControl.phantomRoleMutationRejected||!structuralControl.choiceTextMatches||!structuralControl.choiceDisplayBranchMatches||!structuralControl.missingNativeColorRejected||!structuralControl.colorMatches||!structuralControl.colorMutationRejected) die(`semantic structure controls failed: ${JSON.stringify(structuralControl)}`);
for(const e of fixture.entries) {
 const request={id:e.macro,source:e.source,displayMode:e.displayMode===true};
 const ref=runOne(process.execPath,[refExporter,archive,packageRoot],request), nat=runOne(native,[],request);
 const checks=[], base={macro:e.macro,source:e.source,kind:e.kind,displayMode:request.displayMode,referenceStatus:'missing',nativeStatus:'missing',checks};
 const bad=(r)=>r.failure||r.rows.length!==1||r.rows[0].id!==request.id||r.rows[0].source!==request.source;
 if(bad(ref)||bad(nat)) { rows.push({...base,result:'blocked',blockedReason:'missing, duplicate, failed, or identity-mismatched exporter record',referenceFailure:ref.failure||ref.stderr||null,nativeFailure:nat.failure||nat.stderr||null});outcomeSummary.blocked++;continue; }
 const rr=ref.rows[0], nn=semanticWithAST(nat.rows[0]);base.referenceStatus=rr.status;base.nativeStatus=nn.status;
 if(rr.source!==request.source||nn.source!==request.source||rr.id!==request.id||nn.id!==request.id){rows.push({...base,result:'blocked',blockedReason:'reference/native source or ID identity mismatch'});outcomeSummary.blocked++;continue;}
 if(rr.status!=='ok'&&rr.status!=='policy-visible-command') {
  rows.push({...base,result:'blocked',rootCause:`invalid-reference-probe:${rr.status}`,blockedReason:`reference probe did not render successfully (${rr.status}); no native comparison is valid`,referenceError:rr.error||null,nativeError:nn.error||null,referenceStderr:ref.stderr||null,nativeStderr:nat.stderr||null});outcomeSummary.blocked++;continue;
 }
 if(nn.status!=='ok'&&nn.status!=='policy-visible-command') {
  checks.push('pinned KaTeX successfully rendered; native rejected or failed layout');
  rows.push({...base,result:'deviation',rootCause:'reference-success/native-failure',referenceError:null,nativeError:nn.error||null,referenceStderr:ref.stderr||null,nativeStderr:nat.stderr||null});outcomeSummary.deviation++;continue;
 }
 if(nn.status!==rr.status) { rows.push({...base,result:'deviation',rootCause:'reference-native-outcome-status-mismatch'});outcomeSummary.deviation++;continue; }
 outcomeSummary.match++;
 const comparison=semanticComparator.compareSemantic(rr,nn);
 semanticSummary[comparison.status]++;
 rows.push({...base,result:comparison.status==='match'?'pass':'comparisonGap',rootCause:comparison.status==='match'?null:'semantic-comparison-gap',outcomeStatus:'match',comparisonStatus:comparison.status,semanticComparison:comparison,qualification:'scoped semantic outcome only; geometry, font identity, options effect, pixels, and full-dialect behavior remain unqualified'});
}
for(const [label,source] of [['fraction','\\frac{a}{b}'],['subscript','x^2_3']]) {
 const request={id:`semantic-control-${label}`,source,displayMode:false};
 const ref=runOne(process.execPath,[refExporter,archive,packageRoot],request),nat=runOne(native,[],request);
 if(ref.failure||nat.failure||ref.rows?.length!==1||nat.rows?.length!==1||ref.rows[0].id!==request.id||nat.rows[0].id!==request.id||ref.rows[0].source!==source||nat.rows[0].source!==source) die(`${label} mutation control exporter identity/status failure`);
 const expectedKind=label==='fraction'?'fraction_node':'scripts_node';
 const actual=nat.rows[0].semanticTree?.nodes?.find(node=>node.kind===expectedKind);
 if(ref.rows[0].status!=='ok'||nat.rows[0].status!=='ok'||!actual) die(`${label} mutation control lacks expected native semantic node`);
 const result=semanticComparator.mutationControls(ref.rows[0],nat.rows[0]);
 mutationControl[label]=result;
}
if(!mutationControl.fraction.available||!mutationControl.fraction.rejected||!mutationControl.subscript.available||!mutationControl.subscript.rejected) die(`semantic role mutation controls failed: ${JSON.stringify(mutationControl)}`);
const summary={pass:rows.filter(r=>r.result==='pass').length,deviation:rows.filter(r=>r.result==='deviation').length,comparisonGap:rows.filter(r=>r.result==='comparisonGap').length,blocked:rows.filter(r=>r.result==='blocked').length};
const rootCauseSummary=Object.fromEntries([...new Set(rows.map(r=>r.rootCause||r.blockedReason||'other'))].map(k=>[k,rows.filter(r=>(r.rootCause||r.blockedReason||'other')===k).length]));
const report={schema:'coyote.math-callables-audit.v2',qualification:'NOT_QUALIFIED',identity,reference:{name:fixture.reference.name,version:fixture.reference.version},timeoutMs,fixtureCount:fixture.entries.length,inventoryCount:names.length,rootCauseSummary,outcomeSummary,semanticSummary,mutationControl,structuralControl,comparisonScopes:{outcome:'independently counted exact-ID/source successful outcomes; reference-success/native-failure is a deviation; reference parse errors block probe validity',semantic:`${REPORT_SCOPE}; exact known semantic mappings only; unknown kinds, attributes and unavailable native payload remain explicit gaps`,layout:'not compared; geometry, font identity, options effect, pixels and full-dialect behavior remain unqualified'},summary,entries:rows};
const reportPath=process.env.MATH_CALLABLE_REPORT||'/tmp/coyote-native-callables-audit.json';
fs.writeFileSync(reportPath,JSON.stringify(report,null,2)+'\n');
console.log(`Callable audit: ${JSON.stringify(summary)}; semantic ${JSON.stringify(semanticSummary)}; qualification ${report.qualification}; report ${reportPath}`);
if(!diagnostic&&(summary.deviation||summary.comparisonGap||summary.blocked||semanticSummary.gap))process.exitCode=1;
