#!/usr/bin/env node
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const ARCHIVE_SHA256 = 'e9e0d167db3175481cbadaff38e8d90b130f6a3ddb451a47e43c577fd511f365';
const BUNDLE_SHA256 = '8f1f4fb1080439c012bb8fddf424fa253e9144ab4cdd7dc0eae0e92cd04a5e33';
function sha(data) { return crypto.createHash('sha256').update(data).digest('hex'); }
function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === 'object') return Object.fromEntries(Object.keys(value).sort().map(k => [k, canonical(value[k])]));
  return value;
}
function die(message) { console.error(`reference export: ${message}`); process.exit(2); }
if (process.argv.length !== 4) die('usage: node export-math-reference.cjs <pinned-katex.tgz> <package-root> < input.jsonl > output.jsonl');
const archive = path.resolve(process.argv[2]);
const packageRoot = path.resolve(process.argv[3]);
if (sha(fs.readFileSync(archive)) !== ARCHIVE_SHA256) die('archive SHA-256 mismatch');
const bundlePath = path.join(packageRoot, 'dist/katex.js');
if (sha(fs.readFileSync(bundlePath)) !== BUNDLE_SHA256) die('dist/katex.js SHA-256 mismatch');
const manifest = JSON.parse(fs.readFileSync(path.join(packageRoot, 'package.json'), 'utf8'));
if (manifest.version !== '0.16.22') die('package version is not 0.16.22');
let katex;
try { katex = require(bundlePath); } catch (error) { die(`cannot load verified bundle: ${error.message}`); }
if (katex.version !== '0.16.22') die(`loaded version mismatch: ${katex.version}`);
const input = fs.readFileSync(0, 'utf8').split('\n').filter(Boolean);
const provenance = {archiveSha256: ARCHIVE_SHA256, bundleSha256: BUNDLE_SHA256, version: '0.16.22'};
const sharedMacros = new Map();
const BASE = {throwOnError: true, trust: false, strict: 'warn', maxSize: 100, maxExpand: 1000};
function plainTree(node) {
  if (node == null || typeof node !== 'object') return node;
  if (Array.isArray(node)) return node.map(plainTree);
  const result = {};
  for (const key of Object.keys(node)) {
    const value = node[key];
    if (key === 'text') { result[key] = value; continue; }
    if (typeof value !== 'function' && key !== 'parent' && key !== 'prev' && key !== 'next') result[key] = plainTree(value);
  }
  return result;
}
function snapshotMacros(macros) {
  const result = {};
  for (const key of Object.keys(macros || {}).sort()) {
    const value = macros[key];
    if (typeof value === 'string') result[key] = value;
    else if (value && typeof value === 'object' && Array.isArray(value.tokens)) {
      result[key] = {tokens: value.tokens.map(t => ({text: String(t.text || ''), loc: t.loc ? {start: t.loc.start, end: t.loc.end} : null})), numArgs: Number.isInteger(value.numArgs) ? value.numArgs : null};
    } else result[key] = {unsupportedValueType: typeof value};
  }
  return result;
}
function projectMathML(node) {
  if (!node || typeof node !== 'object') return null;
  if (Array.isArray(node)) return node.map(projectMathML).flat(2).filter(Boolean);
  if (node.constructor?.name === 'TextNode' && typeof node.toText === 'function') return node.toText();
  if (node.type === 'annotation') return null;
  if (node.type) return {type:node.type,attributes:node.attributes||{},children:(node.children||[]).map(projectMathML).flat(2).filter(Boolean)};
  return (node.children||[]).map(projectMathML).flat(2).filter(Boolean);
}
function svgPaths(markup) {
  const paths = [];
  for (const svg of markup.matchAll(/<svg\b([^>]*)>([\s\S]*?)<\/svg>/g)) {
    const viewBox = svg[1].match(/\bviewBox="([^"]+)"/);
    if (!viewBox) continue;
    const box = viewBox[1].trim().split(/[ ,]+/).map(Number);
    if (box.length !== 4 || box.some(x => !Number.isFinite(x)) || box[2] <= 0 || box[3] <= 0) continue;
    const clip = svg[2].match(/<clipPath\b[^>]*>[\s\S]*?<rect\b([^>]*)\/?>(?:[\s\S]*?<\/clipPath>)?/);
    let clipRect = null;
    if (clip) {
      const attrs = Object.fromEntries([...clip[1].matchAll(/([\w:-]+)="([^"]*)"/g)].map(m => [m[1], Number(m[2])]));
      if (['x','y','width','height'].every(k => Number.isFinite(attrs[k]))) clipRect = {x:attrs.x,y:attrs.y,width:attrs.width,height:attrs.height};
    }
    for (const pathNode of svg[2].matchAll(/<path\b[^>]*\bd="([^"]*)"/g)) {
      paths.push({viewBox:box, clip:clipRect, d:pathNode[1].replaceAll('&amp;','&').replaceAll('&quot;','\"').replaceAll('&lt;','<').replaceAll('&gt;','>')});
    }
  }
  return paths;
}
function walk(node, out, visual=false) {
  if (!node || typeof node !== 'object') return;
  if (Array.isArray(node)) { for (const child of node) walk(child, out, visual); return; }
  const isVisual=visual || (Array.isArray(node.classes) && node.classes.includes('katex-html'));
  if (isVisual && typeof node.text === 'string') out.push({text:node.text,font:node.font||null});
  if (node.classes?.includes('katex-mathml') && !visual) return;
  for (const key of Object.keys(node)) if (key !== 'parent' && key !== 'prev' && key !== 'next') walk(node[key], out, isVisual);
}
for (const line of input) {
  let req;
  try { req = JSON.parse(line); } catch (error) { die(`invalid request JSON: ${error.message}`); }
  if (!req || typeof req.id !== 'string' || typeof req.source !== 'string' || typeof req.displayMode !== 'boolean') die('each request needs string id/source and boolean displayMode');
  const supplied = req.options || {};
  const supported = ['trust','strict','maxSize','maxExpand','throwOnError','displayMode'];
  const fixed = Object.keys(supplied).filter(k => !supported.includes(k) || (k === 'displayMode' ? supplied[k] !== req.displayMode : supplied[k] !== BASE[k]));
  if (fixed.length) die(`${req.id}: unsupported/non-baseline option ${fixed.join(', ')}`);
  const options = Object.assign({displayMode: req.displayMode}, BASE);
  const sequence = typeof req.sequence === 'string' ? req.sequence : null;
  if (sequence) {
    if (!sharedMacros.has(sequence)) sharedMacros.set(sequence, {});
    options.macros = sharedMacros.get(sequence);
  }
  const serialOptions = canonical({displayMode:req.displayMode, throwOnError:true, trust:false, strict:'warn', maxSize:100, maxExpand:1000});
  const identity = {id:req.id, source:req.source, displayMode:req.displayMode, sequence, options:serialOptions};
  const hashOptions = canonical(serialOptions);
  const out = {schema:'coyote.math-reference.v1',engine:'katex-0.16.22',provenance,id:req.id,source:req.source,displayMode:req.displayMode,sequence,options:serialOptions,caseHash:sha(JSON.stringify(identity)),configHash:sha(JSON.stringify(hashOptions)),sourceHash:sha(req.source),delimiterSeparatedSourceHash:sha(req.displayMode?`$$${req.source}$$`:`$${req.source}$`),status:'ok',error:null,warnings:[],html:null,tree:null,metrics:null,glyphs:[],paths:[],macroState:null,capabilities:{successfulRender:false,policyRefusal:false,tree:true,mathMLTree:true,heightDepth:true,glyphText:true,glyphFont:true,origin:false,widths:false,paths:false,colors:false,semantic:false,sharedMacros:!!sequence,macroStateSnapshot:!!sequence,browserPixels:false}};
  const oldWarn = console.warn;
  const consoleWarnings = [];
  console.warn = (...args) => consoleWarnings.push(args.map(String).join(' '));
  try {
    const tree = katex.__renderToDomTree(req.source, options);
    function findMath(node) {
      if (!node || typeof node !== 'object') return null;
      if (Array.isArray(node)) { for (const child of node) { const found = findMath(child); if (found) return found; } return null; }
      if (node.type === 'math') return node;
      for (const child of node.children || []) { const found = findMath(child); if (found) return found; }
      return null;
    }
    const mathNode = findMath(tree);
    out.mathMLTree = mathNode ? projectMathML(mathNode) : null;
    out.tree = plainTree(tree);
    out.html = tree.toMarkup();
    out.paths = svgPaths(out.html);
    out.capabilities.paths = out.paths.length > 0;
    out.metrics = {height:tree.height,depth:tree.depth,style:req.displayMode?'display':'text',unit:'em',knownStyle:true};
    walk(out.tree, out.glyphs);
    out.capabilities.successfulRender = true;
    out.capabilities.policyRefusal = /katex-error|class="merror"/.test(out.html) || /\\(?:href|url|includegraphics|htmlClass|htmlId|htmlStyle|htmlData)<\/span>/.test(out.html);
    if (out.capabilities.policyRefusal) out.status = 'policy-visible-command';
  } catch (error) {
    out.status = 'parse-error';
    out.error = {name:error.name || 'Error',message:error.message || String(error),position:Number.isInteger(error.position)?error.position:null,raw:plainTree({name:error.name,message:error.message,position:error.position,token:error.token&&{text:error.token.text,loc:error.token.loc}})};
    out.warnings.push({kind:'render-error',message:out.error.message,position:out.error.position});
  } finally {
    console.warn = oldWarn;
    for (const message of consoleWarnings) out.warnings.push({kind:'console-warning',message});
  }
  if (sequence) out.macroState = snapshotMacros(sharedMacros.get(sequence));
  process.stdout.write(`${JSON.stringify(out)}\n`);
}
