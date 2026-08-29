# safe-fixes.md — the only mutations this skill performs

Every fix: re-fetch fresh → transform → secret scan → language scan → structural check → write (via your wiki write tool, which must invoke scope-check and re-fetch to verify). **Run scanners as plain top-level lines**, never inside a `for`/`$( )` loop (node may segfault inside subshells and the non-zero is mis-read as a finding). Log every fix in the report. **Nothing here deletes, merges, moves, or archives.**

> **Concurrency caveat (TOCTOU).** The write gate's re-fetch verify confirms your new content landed — it does NOT assert the base revision was unchanged since your read. A human edit inside the read→write window is silently clobbered. Keep the window tiny (transform in-memory, write immediately) and re-run the audit if the wiki is under active editing.

## 1. Bare short-id link resolution

Bare short-id links (no title slug) can 404 in-browser; full slugs always work.

```js
// Resolve via your wiki API's page-info call, then replace in text:
text = text.split("/doc/"+sid).join(resolved.url);
// Safe: a full slug is /doc/word-word-SHORTID — the exact substring /doc/SHORTID
// never occurs inside a full-slug link, so split/join only hits bare links.
// Skip any short-id that does not resolve.
```

## 2. Literal `\toc` repair

Replace the first **prose** `\toc` (fence-excluded) with a `+++`-wrapped TOC toggle built from the page's H2/H3:

```js
function anchor(h){return '#h-'+h.toLowerCase()
  .replace(/[`*_~]/g,'').replace(/[^a-z0-9\s-]/g,'')
  .trim().replace(/\s+/g,'-').replace(/-+/g,'-').replace(/^-|-$/g,'');}
// Collect H2/H3 outside code fences; build:
// +++\n**Table of contents**\n- [Heading](#h-heading)\n  - [Sub](#h-sub)\n+++
// Dash-collapse/trim matters: "A - B" must yield "a-b", not "a---b".
// Need ≥2 headings or skip.
```

Verify a sample anchor resolves against the live page before trusting the whole TOC.

**Language-scanner false positive:** a heading like "Refresh the cache" yields anchor `refresh-the-cache`, whose substring trips some word-block regexes and BLOCKS the write. Do not bypass — instead **strip the `\toc`** (remove the broken directive, add no TOC) and log "TOC omitted — anchor tripped language scanner." The visible defect is still fixed.

## 3. Double-escape repair — GATED, fence + inline-code guarded

Some pages were double-encoded at storage and render `\n`, `\uXXXX`, `\*` as literal text. This repair is **gated**: run it ONLY on a page that is genuinely double-escaped, detected by the same fence-aware count the scorer uses:

```js
function isDoubleEscaped(t){
  // Require MULTIPLE artifact classes — a page that merely DOCUMENTS \n must not be mis-classed.
  const nl  = proseScan(t,'\\\\n','count') >= 10;
  const uni = proseScan(t,'\\\\u[0-9a-fA-F]{4}','has');
  const dbs = proseScan(t,'\\\\\\\\','has');
  return nl && (uni || dbs);  // \n alone is NOT sufficient
}
```

Within a double-escaped page, protect fenced blocks AND inline backtick spans:

```js
function unescapeProse(t){
  const lines=t.split('\n'); let fence=false;
  return lines.map(l=>{
    if(/^\s*(```|~~~)/.test(l)){fence=!fence; return l;}
    // F3: 4-space indented code blocks are NOT excluded (shared with proseScan in scoring.md
    //     by design — scorer and fixer treat indented code identically, no divergence).
    if(fence) return l;
    if((l.split('`').length-1) % 2 !== 0) return l; // unbalanced backticks → ambiguous, leave
    return l.split('`').map((seg,i)=> i%2===1 ? seg :
      seg.replace(/\\\\u([0-9a-fA-F]{4})/g,(m,h)=>String.fromCharCode(parseInt(h,16)))
         .replace(/\\u([0-9a-fA-F]{4})/g,(m,h)=>String.fromCharCode(parseInt(h,16)))
         .replace(/\\n/g,'\n').replace(/\\t/g,'\t').replace(/\\"/g,'"')
         .replace(/\\([*_#\-.\[\]()])/g,'$1')
    ).join('`');
  }).join('\n');
}
```

## 4. Broken code-fence repair (state-machine) — runs BEFORE §3

Some double-escaped pages open code blocks with a single backtick (`` `bash ``) that renders as inline code instead of a block. Convert to triple-fence:

```js
function repairFences(t){
  const lines=t.split('\n'); let open=false;
  const out=lines.map(l=>{
    const m=l.match(/^`([a-zA-Z][\w-]*)\s*$/);
    if(m && !open){open=true; return '```'+m[1];}
    if(/^`\s*$/.test(l) && open){open=false; return '```';}
    return l;
  }).join('\n');
  const fences=(out.match(/^```/gm)||[]).length;
  if(fences % 2 !== 0) throw new Error('unbalanced fences after repair — abort, recommend manual');
  return out;
}
```

**Codified order (R3) — §4 before §3, skip-on-throw:**

```js
if (isDoubleEscaped(text)) {
  let t;
  try { t = repairFences(text); }         // §4 first
  catch (e) { recommendManual(page, e); } // odd fences → recommend-only, do NOT write
  if (t !== undefined) { t = unescapeProse(t); writeThroughGates(page, t); }
}
```

Never run §3 on a non-double-escaped page (R1 safeguard). `repairFences` throwing on an odd fence count downgrades to recommend-only — never write an ambiguous transform.

## What is NOT auto-fixed (recommend only)

- **DELETE / MERGE / ARCHIVE / MOVE / reparent** — destructive or judgment calls; human approval or `wiki-refactor`.
- **RETITLE** (title collisions) — changes the URL slug and inbound links; recommend, don't execute.
- **Content rewrites, dedup merges, filling skeletons** — that is `wiki-refactor`'s job.
- **Leading-`# H1` removal at scale** — mechanical but needs per-page confirmation; recommend a reviewed bulk sweep.
