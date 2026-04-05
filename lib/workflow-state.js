/**
 * workflow-state.js — Persistent workflow state machine for superpowers.
 *
 * Tracks active workflow phases, gate evidence, and completion readiness.
 * State is stored in ~/.codex/.workflow-state.json and is advisory by default.
 *
 * Reuses patterns from investigation-engine.py:
 *   - Atomic writes (write to temp file, then rename)
 *   - Evidence hashing (sha256 of tool output)
 *   - Expiry-based cleanup (30 min for evidence, 24 hours for state)
 *
 * INTEGRATION STATUS (advisory mode, opt-in enforcement):
 *   Wired:
 *     - bootstrap: shows getStatus() when active workflow exists
 *     - use-skill: calls recordSkillInvocation() + auto-inits for workflow skills
 *     - pre-push hook: records code_review gate evidence on successful push
 *     - pre-commit hook: checks canCommit() when WORKFLOW_ENFORCEMENT=enforce
 *     - doctor check: calls getStateAgeHours() for stale state detection
 *   Advisory by default. Set WORKFLOW_ENFORCEMENT=enforce to enable gate blocking.
 *   Override STATE_FILE via WORKFLOW_STATE_FILE env var (used in tests).
 */
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');
const crypto = require('crypto');

const STATE_FILE = process.env.WORKFLOW_STATE_FILE || path.join(os.homedir(), '.codex', '.workflow-state.json');
const EVIDENCE_MAX_AGE_MS = 30 * 60 * 1000;  // 30 minutes
const STATE_MAX_AGE_MS = 24 * 60 * 60 * 1000; // 24 hours

const FEATURE_DEV_PHASES = [
    'brainstorming', 'think-twice', 'design-triad',
    'code-review-round-1', 'plan-and-execute', 'code-review-round-2', 'ship'
];

const COMMIT_GATES = ['lint', 'build', 'test'];
const COMPLETION_GATES = ['code_review', 'output_verification'];

function hashEvidence(output) {
    return crypto.createHash('sha256')
        .update(typeof output === 'string' ? output : JSON.stringify(output))
        .digest('hex').slice(0, 16);
}

const LOCK_FILE = STATE_FILE + '.lock';
const LOCK_TTL_MS = 5000; // 5 seconds — operations are fast

/**
 * Acquire advisory lock using O_EXCL for atomic creation.
 * Returns true if acquired, false if held by another process.
 * Lock auto-expires after LOCK_TTL_MS to prevent deadlocks from crashed processes.
 */
function acquireLock() {
    const lockContent = JSON.stringify({ pid: process.pid, ts: Date.now() });
    try {
        // O_EXCL: fail if file already exists — atomic "create if not exists"
        const fd = fs.openSync(LOCK_FILE, fs.constants.O_WRONLY | fs.constants.O_CREAT | fs.constants.O_EXCL);
        fs.writeSync(fd, lockContent);
        fs.closeSync(fd);
        return true;
    } catch (err) {
        if (err.code !== 'EEXIST') return true; // Unknown error — proceed (advisory)
        // Lock file exists — check if expired
        try {
            const lockData = JSON.parse(fs.readFileSync(LOCK_FILE, 'utf8'));
            const lockAge = Date.now() - lockData.ts;
            if (lockAge >= LOCK_TTL_MS) {
                // Expired lock — reap and re-acquire
                try { fs.unlinkSync(LOCK_FILE); } catch (_) {}
                try {
                    const fd = fs.openSync(LOCK_FILE, fs.constants.O_WRONLY | fs.constants.O_CREAT | fs.constants.O_EXCL);
                    fs.writeSync(fd, lockContent);
                    fs.closeSync(fd);
                    return true;
                } catch (_) { return false; } // Another process beat us to it
            }
            return false; // Lock is fresh — held by another process
        } catch (_) {
            // Can't read lock file — proceed anyway (advisory)
            return true;
        }
    }
}

function releaseLock() {
    try {
        // Only delete if we own the lock (check PID)
        const lockData = JSON.parse(fs.readFileSync(LOCK_FILE, 'utf8'));
        if (lockData.pid === process.pid) {
            fs.unlinkSync(LOCK_FILE);
        }
    } catch (_) {}
}

function readState() {
    try {
        if (!fs.existsSync(STATE_FILE)) return null;
        const state = JSON.parse(fs.readFileSync(STATE_FILE, 'utf8'));
        const age = Date.now() - new Date(state.created_at).getTime();
        if (age > STATE_MAX_AGE_MS) { archiveState(state); return null; }
        return state;
    } catch (_) { return null; }
}

function writeState(state) {
    if (!acquireLock()) {
        if (process.env.WORKFLOW_DEBUG) {
            console.error('workflow-state: could not acquire lock, skipping write');
        }
        return;
    }
    try {
        state.updated_at = new Date().toISOString();
        const dir = path.dirname(STATE_FILE);
        if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
        const tmp = STATE_FILE + '.tmp.' + process.pid;
        fs.writeFileSync(tmp, JSON.stringify(state, null, 2));
        fs.renameSync(tmp, STATE_FILE);
    } catch (err) {
        if (process.env.WORKFLOW_DEBUG) {
            console.error('workflow-state: write failed:', err.message);
        }
    } finally {
        releaseLock();
    }
}

function archiveState(state) {
    try {
        const dir = path.join(path.dirname(STATE_FILE), '.workflow-state-archive');
        fs.mkdirSync(dir, { recursive: true });
        const ts = new Date().toISOString().replace(/[:.]/g, '-');
        fs.writeFileSync(path.join(dir, `workflow-${ts}.json`), JSON.stringify(state, null, 2));
        try { fs.unlinkSync(STATE_FILE); } catch (_) {}
        const files = fs.readdirSync(dir).filter(f => f.endsWith('.json')).sort();
        while (files.length > 20) {
            try { fs.unlinkSync(path.join(dir, files.shift())); } catch (_) {}
        }
    } catch (_) {}
}

function initWorkflow(workflowName, metadata = {}) {
    const state = {
        session_id: `${Date.now()}-${process.ppid || process.pid}`,
        workflow: workflowName,
        current_phase: 0,
        passed_phases: [],
        gates: {},
        files_changed: [],
        evidence: {},
        enforcement: process.env.WORKFLOW_ENFORCEMENT || 'advisory',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
        ...metadata
    };
    writeState(state);
    return state;
}

function recordGate(gate, evidence = {}) {
    const state = readState();
    if (!state) return null;
    state.gates[gate] = {
        passed: true,
        timestamp: new Date().toISOString(),
        tool: evidence.tool || 'unknown',
        exit_code: evidence.exitCode != null ? evidence.exitCode : null,
        output_hash: evidence.output ? hashEvidence(evidence.output) : null
    };
    state.evidence[gate] = {
        hash: evidence.output ? hashEvidence(evidence.output) : null,
        timestamp: new Date().toISOString()
    };
    writeState(state);
    return state;
}

function recordSkillInvocation(skillName) {
    const state = readState();
    if (!state) return null;
    const phaseMap = {
        'brainstorming': 'brainstorming',
        'think-twice': 'think-twice',
        'design-triad': 'design-triad',
        'progressive-code-review-gate': state.current_phase < 4
            ? 'code-review-round-1' : 'code-review-round-2',
        'plan-and-execute': 'plan-and-execute'
    };
    const phase = phaseMap[skillName];
    if (phase && !state.passed_phases.includes(phase)) {
        state.passed_phases.push(phase);
        const idx = FEATURE_DEV_PHASES.indexOf(phase);
        if (idx >= 0 && idx >= state.current_phase) state.current_phase = idx + 1;
    }
    // Track that gate-relevant skills were loaded (dispatched), but do NOT
    // mark gates as passed. Gates are only satisfied via recordGate() with
    // actual evidence (exit codes, output hashes). Loading the skill just
    // means "the agent read the instructions" — not "the gate was satisfied."
    const gateSkills = {
        'progressive-code-review-gate': 'code_review',
        'code-review-battery': 'code_review',
        'output-verification': 'output_verification',
        'verification-before-completion': 'completion_verification'
    };
    if (gateSkills[skillName]) {
        const gateName = gateSkills[skillName];
        if (!state.gates[gateName]) {
            state.gates[gateName] = {};
        }
        state.gates[gateName].dispatched = true;
        state.gates[gateName].dispatched_at = new Date().toISOString();
        state.gates[gateName].tool = skillName;
        // Do NOT set passed = true here
    }
    writeState(state);
    return state;
}


/**
 * Check if a commit gate has valid (non-expired) evidence.
 * Commit gates (lint, build, test) expire after EVIDENCE_MAX_AGE_MS because
 * code may change between the gate pass and the commit.
 */
function checkGate(gate) {
    const state = readState();
    if (!state) return false;
    const g = state.gates[gate];
    if (!g || !g.passed) return false;
    return (Date.now() - new Date(g.timestamp).getTime()) < EVIDENCE_MAX_AGE_MS;
}

/**
 * Check if a completion gate has been passed.
 * Completion gates (code_review, output_verification) do NOT expire on
 * wall-clock time — they are invalidated only when new files are edited
 * after the gate was passed (checked via files_changed_after_gate).
 */
function checkCompletionGate(gate) {
    const state = readState();
    if (!state) return false;
    const g = state.gates[gate];
    if (!g || !g.passed) return false;
    // If files were changed AFTER this gate passed, the gate is stale
    if (state._files_changed_after_gate && state._files_changed_after_gate[gate]) {
        return false;
    }
    return true;
}

function canCommit() {
    const state = readState();
    if (!state) return { ready: true, missing: [], reason: 'no active workflow' };
    const missing = COMMIT_GATES.filter(g => !checkGate(g));
    return { ready: missing.length === 0, missing };
}

function canClaimDone() {
    const state = readState();
    if (!state) return { ready: true, missing: [], reason: 'no active workflow' };
    const missing = [];
    if (state.files_changed && state.files_changed.length > 0) {
        for (const gate of COMPLETION_GATES) {
            // Completion gates use edit-based invalidation, not time-based TTL
            if (!checkCompletionGate(gate)) missing.push(gate);
        }
    }
    return {
        ready: missing.length === 0, missing,
        reason: missing.length > 0 ? `Missing: ${missing.join(', ')}` : 'all gates passed'
    };
}

function recordFilesChanged(files) {
    const state = readState();
    if (!state) return null;
    const existing = new Set(state.files_changed || []);
    const newFiles = Array.isArray(files) ? files : [files];
    let addedNew = false;
    for (const f of newFiles) {
        if (!existing.has(f)) {
            existing.add(f);
            addedNew = true;
        }
    }
    state.files_changed = Array.from(existing);

    // If new files were added after completion gates passed, invalidate them
    if (addedNew) {
        if (!state._files_changed_after_gate) state._files_changed_after_gate = {};
        for (const gate of COMPLETION_GATES) {
            if (state.gates[gate] && state.gates[gate].passed) {
                state._files_changed_after_gate[gate] = true;
            }
        }
    }

    writeState(state);
    return state;
}

function getStatus() {
    const state = readState();
    if (!state) return null;
    const icons = {};
    for (const gate of [...COMMIT_GATES, ...COMPLETION_GATES]) {
        if (checkGate(gate)) icons[gate] = '✅';
        else if (state.gates[gate] && state.gates[gate].passed) icons[gate] = '⏰';
        else icons[gate] = '❌';
    }
    const gateStr = Object.entries(icons).map(([k, v]) => `${k}:${v}`).join(' ');
    const mode = (state.enforcement || 'advisory') === 'enforce' ? '🔒ENFORCE' : '👁️ADVISORY';
    return `⚠️ Workflow: ${state.workflow} (phase ${state.current_phase}/${FEATURE_DEV_PHASES.length}) | ${gateStr} | ${mode}`;
}

function getStateAgeHours() {
    const state = readState();
    if (!state) return null;
    return Math.round((Date.now() - new Date(state.created_at).getTime()) / 3600000 * 10) / 10;
}

function clearWorkflow() {
    const state = readState();
    if (state) archiveState(state);
}

module.exports = {
    readState, writeState, initWorkflow, recordGate, recordSkillInvocation,
    checkGate, checkCompletionGate, canCommit, canClaimDone, recordFilesChanged, getStatus,
    getStateAgeHours, clearWorkflow, archiveState, acquireLock, releaseLock,
    STATE_FILE, FEATURE_DEV_PHASES, COMMIT_GATES, COMPLETION_GATES,
    EVIDENCE_MAX_AGE_MS, STATE_MAX_AGE_MS
};
