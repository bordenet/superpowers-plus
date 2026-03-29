/**
 * workflow-state.js — Lightweight advisory workflow phase tracker.
 *
 * Tracks which superpowers skills have been invoked in the current session.
 * State is stored in ~/.codex/.workflow-state.json, auto-expires after 24h.
 *
 * Wired integration points:
 *   - bootstrap: shows getStatus() when active workflow exists
 *   - use-skill: calls recordSkillInvocation() to track phase progression
 *   - doctor check 25: calls getStateAgeHours() for stale state detection
 */
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');

const STATE_FILE = path.join(os.homedir(), '.codex', '.workflow-state.json');
const STATE_MAX_AGE_MS = 24 * 60 * 60 * 1000; // 24 hours

const PHASES = [
    'brainstorming', 'think-twice', 'design-triad',
    'code-review-round-1', 'plan-and-execute', 'code-review-round-2', 'ship'
];

const LOCK_FILE = STATE_FILE + '.lock';
const LOCK_TTL_MS = 5000;

function acquireLock() {
    try {
        // O_EXCL: atomic create — fails if file already exists
        const fd = fs.openSync(LOCK_FILE, fs.constants.O_CREAT | fs.constants.O_EXCL | fs.constants.O_WRONLY);
        fs.writeSync(fd, String(process.pid));
        fs.closeSync(fd);
        return true;
    } catch (_) {
        // Check if stale (older than TTL) AND owner process is dead
        try {
            const stat = fs.statSync(LOCK_FILE);
            if (Date.now() - stat.mtimeMs > LOCK_TTL_MS) {
                // Verify owner is not still running before stealing
                try {
                    const ownerPid = parseInt(fs.readFileSync(LOCK_FILE, 'utf8').trim(), 10);
                    if (!isNaN(ownerPid)) {
                        try { process.kill(ownerPid, 0); return false; } // Owner alive — don't steal
                        catch (_3) {} // Owner dead — safe to steal
                    }
                } catch (_3) {}
                fs.unlinkSync(LOCK_FILE);
                return acquireLock(); // Retry once
            }
        } catch (_2) {}
        return false;
    }
}

function releaseLock() {
    // Only delete if we own the lock (PID matches)
    try {
        const owner = fs.readFileSync(LOCK_FILE, 'utf8').trim();
        if (owner === String(process.pid)) {
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
    try {
        state.updated_at = new Date().toISOString();
        const dir = path.dirname(STATE_FILE);
        if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
        const tmp = STATE_FILE + '.tmp.' + process.pid;
        fs.writeFileSync(tmp, JSON.stringify(state, null, 2));
        fs.renameSync(tmp, STATE_FILE);
    } catch (_) {}
}

function archiveState(state) {
    try {
        const dir = path.join(os.homedir(), '.codex', '.workflow-state-archive');
        fs.mkdirSync(dir, { recursive: true });
        const ts = new Date().toISOString().replace(/[:.]/g, '-');
        fs.writeFileSync(path.join(dir, `workflow-${ts}.json`), JSON.stringify(state, null, 2));
        try { fs.unlinkSync(STATE_FILE); } catch (_) {}
        // Keep last 20 archives
        const files = fs.readdirSync(dir).filter(f => f.endsWith('.json')).sort();
        while (files.length > 20) {
            try { fs.unlinkSync(path.join(dir, files.shift())); } catch (_) {}
        }
    } catch (_) {}
}

// Skills that participate in workflow phase tracking
const WORKFLOW_SKILLS = new Set([
    'brainstorming', 'think-twice', 'design-triad',
    'progressive-code-review-gate', 'code-review-battery',
    'plan-and-execute'
]);

function recordSkillInvocation(skillName) {
    if (!acquireLock()) return; // Advisory — skip if contended
    try {
        let state = readState();
        if (!state) {
            // Only auto-create state for workflow-relevant skills
            if (!WORKFLOW_SKILLS.has(skillName)) return;
            state = {
                workflow: 'auto', current_phase: 0, passed_phases: [],
                gates: {}, created_at: new Date().toISOString()
            };
        }
        const phaseMap = {
            'brainstorming': 'brainstorming',
            'think-twice': 'think-twice',
            'design-triad': 'design-triad',
            'progressive-code-review-gate': state.current_phase < 4
                ? 'code-review-round-1' : 'code-review-round-2',
            'code-review-battery': state.current_phase < 4
                ? 'code-review-round-1' : 'code-review-round-2',
            'plan-and-execute': 'plan-and-execute'
        };
        const phase = phaseMap[skillName];
        if (phase && !state.passed_phases.includes(phase)) {
            state.passed_phases.push(phase);
            const idx = PHASES.indexOf(phase);
            if (idx >= 0 && idx >= state.current_phase) state.current_phase = idx + 1;
        }
        if (['progressive-code-review-gate', 'code-review-battery'].includes(skillName)) {
            state.gates.code_review_dispatched = new Date().toISOString();
        }
        writeState(state);
        return state;
    } finally {
        releaseLock();
    }
}

function getStatus() {
    const state = readState();
    if (!state) return null;
    return `⚠️ Workflow: ${state.workflow} (phase ${state.current_phase}/${PHASES.length}) | phases: ${state.passed_phases.join(',')} | 👁️ADVISORY`;
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
    readState, writeState, recordSkillInvocation, getStatus,
    getStateAgeHours, clearWorkflow, archiveState, STATE_FILE, PHASES
};
