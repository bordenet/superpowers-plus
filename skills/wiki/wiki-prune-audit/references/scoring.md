# scoring.md — enumeration + badness scoring

All read-only. Persist intermediate data to a scratch file, not context.

## Phase 1 — recursive enumerator

Takes one or more root page IDs/slugs. For each root, recursively list children via your wiki API, capturing `id, title, url, updatedAt, textLen, text, parentDocumentId`. One list call per parent (paginate if needed — do NOT do one fetch per page). Run as a background job for large trees. `ENUM_ERRORS` must be 0 for a complete audit — if any subtree is dropped, re-run rather than publish a partial worklist.

```js
// enum.js <outfile.jsonl> <rootSlug...>
// Adapt the wiki-api calls below to your wiki API client.
const {execFileSync}=require('child_process'), fs=require('fs');
const OUT=fs.createWriteStream(process.argv[2]);
const api=(m,p)=>JSON.parse(execFileSync('wiki-api',[m,JSON.stringify(p)],{maxBuffer:2e8}).toString());
function emit(d,depth,pid,root){OUT.write(JSON.stringify({id:d.id,title:d.title,depth,url:d.url,
  updatedAt:d.updatedAt,createdBy:(d.createdBy||{}).name,parentDocumentId:pid,
  textLen:(d.text||'').length,text:d.text||'',root})+'\n');}
let ERRORS=0;
function listRetry(pid,off){for(let a=0;a<3;a++){try{return api('documents.list',{parentDocumentId:pid,limit:100,offset:off});}
  catch(e){process.stderr.write('retry '+a+' '+pid+' '+e.message+'\n');}}
  ERRORS++; process.stderr.write('DROPPED subtree under '+pid+' (offset '+off+')\n'); return null;}
function walk(pid,depth,root){let off=0,kids=[];while(true){
  const r=listRetry(pid,off); if(!r) break;
  const docs=r.data||[];for(const d of docs){emit(d,depth,pid,root);kids.push(d.id);}
  if(docs.length<100)break;off+=100;}
  for(const k of kids)walk(k,depth+1,root);}
for(const s of process.argv.slice(3)){const info=api('documents.info',{id:s}).data;
  emit(info,0,null,info.title);walk(info.id,1,info.title);}
OUT.end();
process.stderr.write('ENUM_ERRORS='+ERRORS+'\n');
```

## Phase 2 — scoring signals

Per page, sum weighted signals (higher = worse). Tune thresholds to taste.

- **near-empty** `textLen<120` (+40) / **thin** `<350` (+22) / **short** `<700` (+8)
- **obsolescence**: age >540d (+18) / >365d (+10); `:::warning …superseded|on ice|deprecated` banner (+25); expired dated deadline in body (+15)
- **duplication**: build inverted index of k=8 word shingles → Jaccard `shared/(a+b-shared)` per pair; flag pairs >0.35 (up to +40). **Apply a document-frequency cap** — drop any shingle appearing in >5% of pages (or hard-cap at ~30 pages) before pairing; templated footers share boilerplate shingles across many pages and generate O(N²) pairs without the cap.
- **unfinished skeleton**: count `(to be filled in)`, `TBD`, `(attach or link here)`; +6 each, capped
- **structural**: prose literal `\toc` (+20, fence-excluded); ≥10 escaped `\n` outside fences (+20); leading `# H1` matching title (+8)
- **link-rot**: bare short-id links (no slug) +4 each, capped
- **orphan**: 0 inbound `/doc/` links AND a second defect present (+25). **Never score orphan alone.**
- **title collision**: exact-duplicate title with an unrelated page (+12)

Normalize text before shingling: lowercase, strip code fences, `[^a-z0-9]→space`, collapse whitespace.

## Orphan / inbound-link computation

Map each page's outbound links to target IDs; count inbound per target. A page with `inbound===0` and `parentDocumentId!=null` is an orphan candidate — pair with a content defect before listing.

## Structural scan (fence-aware — avoids the mermaid trap)

```js
// Fence-aware scanner for \toc presence (has mode) and escaped \n count (count mode).
// F1: use String.prototype.match(rx) per line, NOT rx.test()/rx.exec() with /g — the latter
//     advances lastIndex and silently alternates results. Build rx per call or use match().
// F3: 4-space indented code blocks are NOT excluded (same in safe-fixes.md, by design —
//     scorer and fixer treat them identically so they never diverge).
function proseScan(t,re,mode){const L=t.split('\n');let f=false,n=0;const rx=new RegExp(re,'g');
  for(const l of L){
    if(/^\s*(```|~~~)/.test(l)){f=!f;continue;} if(f)continue;
    const parts=l.split('`');
    if(parts.length%2===0)continue; // unbalanced backticks → ambiguous, skip
    let c=0; for(let i=0;i<parts.length;i+=2){c+=(parts[i].match(rx)||[]).length;}
    if(mode==='has'){if(c)return true;} else n+=c;}
  return mode==='has'?false:n;}
// Usage:
// literal \toc:    proseScan(text,'\\\\toc','has')
// escaped \n ≥10:  proseScan(text,'\\\\n','count') >= 10
// leadingH1:       /^\s*#\s+\S/.test(text)
```

`\n` inside a mermaid node label (`Push["a\nb"]`) is valid — the fence guard excludes it.
`\n` inside an inline backtick span is valid — the backtick-split excludes it.
This mirrors `unescapeProse` in `safe-fixes.md` exactly (same guards), so the score and the fixer never diverge.

## Phase 3 — digest for PHR

For the top ~40, emit `{title, url, textLen, ageDays, childCount, reasons, head(420), tail(260)}`. Child count distinguishes an empty nav node (has children → ADD-INTRO) from dead weight (no children → DELETE candidate). Hand the digest to the PHR panel; require it to re-fetch and quote evidence, and cut anything resting on a single weak signal.
