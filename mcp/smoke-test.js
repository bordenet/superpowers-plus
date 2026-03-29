#!/usr/bin/env node

/**
 * Smoke test for superpowers-plus MCP server.
 *
 * Spawns the actual MCP server as a child process, sends real JSON-RPC
 * messages over stdio, and validates all three tools: find_skills,
 * use_skill, and match_skills.
 *
 * Respects PERSONAL_SKILLS_DIR / SUPERPOWERS_SKILLS_DIR env vars
 * for hermetic testing (used by test/integration-test.sh).
 */

import { spawn } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SERVER_PATH = path.join(__dirname, 'superpowers-mcp.js');
const TIMEOUT_MS = 15_000;

// ---------------------------------------------------------------------------
// JSON-RPC transport over stdio
// ---------------------------------------------------------------------------
class McpClient {
  constructor(proc) {
    this._proc = proc;
    this._nextId = 1;
    this._pending = new Map();
    this._buf = '';

    proc.stdout.on('data', (chunk) => {
      this._buf += chunk.toString();
      // Messages are newline-delimited JSON
      let nl;
      while ((nl = this._buf.indexOf('\n')) !== -1) {
        const line = this._buf.slice(0, nl).trim();
        this._buf = this._buf.slice(nl + 1);
        if (!line) continue;
        try {
          const msg = JSON.parse(line);
          if (msg.id != null && this._pending.has(msg.id)) {
            this._pending.get(msg.id)(msg);
            this._pending.delete(msg.id);
          }
        } catch { /* ignore non-JSON lines (e.g. startup banner) */ }
      }
    });
  }

  /** Send a JSON-RPC request and return the response (or throw on timeout). */
  send(method, params = {}) {
    return new Promise((resolve, reject) => {
      const id = this._nextId++;
      const timer = setTimeout(() => {
        this._pending.delete(id);
        reject(new Error(`Timeout waiting for response to ${method} (id=${id})`));
      }, TIMEOUT_MS);

      this._pending.set(id, (msg) => {
        clearTimeout(timer);
        if (msg.error) reject(new Error(`RPC error: ${JSON.stringify(msg.error)}`));
        else resolve(msg.result);
      });

      const req = JSON.stringify({ jsonrpc: '2.0', id, method, params }) + '\n';
      this._proc.stdin.write(req);
    });
  }

  kill() { this._proc.kill('SIGTERM'); }
}

// ---------------------------------------------------------------------------
// Test runner
// ---------------------------------------------------------------------------
let pass = 0;
let fail = 0;
const errors = [];

function ok(label) { console.log(`  ✅ ${label}`); pass++; }
function bad(label, detail) {
  console.log(`  ❌ ${label}${detail ? ': ' + detail : ''}`);
  errors.push(label);
  fail++;
}

function assert(cond, label, detail) {
  if (cond) ok(label);
  else bad(label, detail);
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
async function main() {
  console.log('superpowers-plus MCP Smoke Test\n');

  // Spawn the MCP server — pass through env so hermetic dirs are inherited
  const proc = spawn(process.execPath, [SERVER_PATH], {
    stdio: ['pipe', 'pipe', 'pipe'],
    env: { ...process.env },
  });

  let stderr = '';
  proc.stderr.on('data', (d) => { stderr += d.toString(); });

  const client = new McpClient(proc);

  // Give the server a moment to start (it logs to stderr when ready)
  await new Promise((r) => setTimeout(r, 500));

  try {
    // ── 1. initialize ──────────────────────────────────────────────────
    console.log('--- Initialize ---');
    const initResult = await client.send('initialize', {
      protocolVersion: '2024-11-05',
      capabilities: {},
      clientInfo: { name: 'smoke-test', version: '1.0.0' },
    });
    assert(initResult && initResult.serverInfo, 'initialize responds',
      JSON.stringify(initResult).slice(0, 120));
    assert(initResult?.serverInfo?.name === 'superpowers-plus',
      'server name is superpowers-plus',
      `got: ${initResult?.serverInfo?.name}`);

    // Send initialized notification (required by protocol)
    proc.stdin.write(JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized' }) + '\n');

    // ── 2. tools/list ──────────────────────────────────────────────────
    console.log('\n--- tools/list ---');
    const toolsResult = await client.send('tools/list', {});
    const toolNames = (toolsResult?.tools || []).map((t) => t.name).sort();
    assert(toolNames.includes('find_skills'), 'find_skills tool registered');
    assert(toolNames.includes('use_skill'), 'use_skill tool registered');
    assert(toolNames.includes('match_skills'), 'match_skills tool registered');

    // ── 3. find_skills ─────────────────────────────────────────────────
    console.log('\n--- find_skills ---');
    const findResult = await client.send('tools/call', {
      name: 'find_skills',
      arguments: {},
    });
    const findText = findResult?.content?.[0]?.text || '';
    assert(findText.includes('Superpowers Skills'), 'find_skills returns skill list');
    // Extract count from "Superpowers Skills (N total)"
    const countMatch = findText.match(/\((\d+) total\)/);
    const skillCount = countMatch ? parseInt(countMatch[1], 10) : 0;
    assert(skillCount > 0, `find_skills discovered ${skillCount} skills`,
      skillCount === 0 ? 'no skills found — check PERSONAL_SKILLS_DIR' : undefined);
    console.log(`  ℹ  ${skillCount} skills discovered`);

    // ── 4. use_skill ───────────────────────────────────────────────────
    console.log('\n--- use_skill ---');
    // Try a known-good skill name extracted from find_skills output
    const nameMatch = findText.match(/\*\*([a-z0-9_-]+)\*\*/);
    const sampleSkill = nameMatch ? nameMatch[1] : null;
    if (sampleSkill) {
      const useResult = await client.send('tools/call', {
        name: 'use_skill',
        arguments: { skill_name: sampleSkill },
      });
      const useText = useResult?.content?.[0]?.text || '';
      assert(useText.length > 50,
        `use_skill("${sampleSkill}") returned content (${useText.length} chars)`);
      assert(useText.includes(`# Skill: ${sampleSkill}`),
        'use_skill response has skill header');
    } else {
      bad('use_skill', 'could not extract a skill name from find_skills output');
    }

    // use_skill with nonexistent skill
    const missingResult = await client.send('tools/call', {
      name: 'use_skill',
      arguments: { skill_name: 'nonexistent-skill-xyz-999' },
    });
    const missingText = missingResult?.content?.[0]?.text || '';
    assert(missingText.includes('not found'), 'use_skill returns not-found for bad name');

    // ── 5. match_skills ────────────────────────────────────────────────
    console.log('\n--- match_skills ---');
    const matchResult = await client.send('tools/call', {
      name: 'match_skills',
      arguments: { query: 'my tests keep failing', top_n: 3 },
    });
    const matchText = matchResult?.content?.[0]?.text || '';
    assert(matchText.includes('Skill Match Results'), 'match_skills returns results');
    assert(matchText.includes('Rank'), 'match_skills output has ranking table');
    assert(matchText.includes('Top match:'), 'match_skills identifies a top match');

  } catch (err) {
    bad('protocol error', err.message);
  } finally {
    client.kill();
  }

  // ── Summary ──────────────────────────────────────────────────────────
  console.log('\n---');
  console.log(`Total: ${pass + fail} tests — ${pass} passed, ${fail} failed`);

  if (fail > 0) {
    console.log(`\nFailed: ${errors.join(', ')}`);
    process.exit(1);
  } else {
    console.log('\nAll skills passed validation. MCP server ready.');
    process.exit(0);
  }
}

main().catch((err) => {
  console.error('Smoke test crashed:', err);
  process.exit(1);
});
