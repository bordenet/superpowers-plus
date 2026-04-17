'use strict';
/**
 * mock-wiki-api.js
 * Minimal in-memory wiki API stub for wiki-write.sh / wiki-read.sh bats tests.
 * Supports: documents.info, documents.create, documents.update, documents.move,
 *           documents.search, documents.list
 *
 * Document tree (used by wiki-scope-check.sh parent walk):
 *   root-doc-1      (col-allowed, allowed-root)
 *     child-doc-1
 *   out-of-scope-doc (col-other)
 *
 * Usage: node mock-wiki-api.js <port>
 */
const http = require('node:http');
const PORT = parseInt(process.argv[2] || '19989', 10);

const DOCS = new Map();
function seed(id, fields) {
  DOCS.set(id, Object.assign({
    id, title: id, text: '',
    url: `https://wiki.example.test/doc/${id}`,
    collectionId: null, parentDocumentId: null,
  }, fields));
}
seed('root-doc-1',       { collectionId: 'col-allowed', title: 'Root 1' });
seed('child-doc-1',      { collectionId: 'col-allowed', parentDocumentId: 'root-doc-1', title: 'Child 1', text: 'body' });
seed('out-of-scope-doc', { collectionId: 'col-other',   title: 'Out of scope' });

let counter = 0;
function newId() { counter += 1; return `new-doc-${counter}`; }

function readBody(req) {
  return new Promise((resolve) => {
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => {
      try { resolve(JSON.parse(Buffer.concat(chunks).toString() || '{}')); }
      catch { resolve({}); }
    });
  });
}

function json(res, code, body) {
  res.writeHead(code, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(body));
}

const server = http.createServer(async (req, res) => {
  if (req.method !== 'POST') { res.writeHead(405); res.end(); return; }
  const path = (req.url.split('?')[0] || '').toLowerCase();
  const body = await readBody(req);

  if (path.endsWith('/documents.info')) {
    const doc = DOCS.get(body.id);
    if (!doc) return json(res, 404, { ok: false, error: 'not_found' });
    return json(res, 200, { ok: true, data: doc });
  }

  if (path.endsWith('/documents.create')) {
    const id = newId();
    const parent = body.parentDocumentId || null;
    const coll = body.collectionId || (parent && DOCS.get(parent)?.collectionId) || null;
    seed(id, { title: body.title || id, text: body.text || '', parentDocumentId: parent, collectionId: coll });
    return json(res, 200, { ok: true, data: DOCS.get(id) });
  }

  if (path.endsWith('/documents.update')) {
    const doc = DOCS.get(body.id);
    if (!doc) return json(res, 404, { ok: false, error: 'not_found' });
    if (body.title !== undefined) doc.title = body.title;
    if (body.text  !== undefined) doc.text  = body.text;
    return json(res, 200, { ok: true, data: doc });
  }

  if (path.endsWith('/documents.move')) {
    const doc = DOCS.get(body.id);
    if (!doc) return json(res, 404, { ok: false, error: 'not_found' });
    doc.parentDocumentId = body.parentDocumentId || null;
    return json(res, 200, { ok: true, data: { document: doc } });
  }

  if (path.endsWith('/documents.search')) {
    const q = (body.query || '').toLowerCase();
    const out = [];
    for (const d of DOCS.values()) {
      if (!q || d.title.toLowerCase().includes(q)) out.push({ ranking: 1, document: d });
    }
    return json(res, 200, { ok: true, data: out.slice(0, body.limit || 10) });
  }

  if (path.endsWith('/documents.list')) {
    const out = [];
    for (const d of DOCS.values()) {
      if (body.collectionId && d.collectionId !== body.collectionId) continue;
      if (body.parentDocumentId && d.parentDocumentId !== body.parentDocumentId) continue;
      out.push(d);
    }
    return json(res, 200, { ok: true, data: out.slice(0, body.limit || 25) });
  }

  json(res, 404, { ok: false, error: 'unknown_verb', path });
});

server.listen(PORT, '127.0.0.1', () => {
  process.stdout.write(`MOCK_WIKI_READY port=${PORT}\n`);
});
process.on('SIGTERM', () => server.close(() => process.exit(0)));
process.on('SIGINT',  () => server.close(() => process.exit(0)));
