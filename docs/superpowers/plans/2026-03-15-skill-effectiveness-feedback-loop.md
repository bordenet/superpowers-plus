# Skill Effectiveness Feedback Loop — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:executing-plans to implement this plan.

**Goal:** Add outcome tracking and learning to the superpowers skill system.

**Architecture:** Local JSON file stores outcomes, trigger metrics, and suggestions. Integrated into existing `superpowers-augment.js`.

**Tech Stack:** Node.js (matches existing), JSON schema, shell integration.

---

## Chunk 1: Core Data Model

### Task 1.1: Create Learning State Manager

**Files:**
- Create: `lib/learning-state.js`

- [ ] **Step 1: Create lib directory and learning-state.js with schema**

```javascript
// lib/learning-state.js
const fs = require('fs');
const path = require('path');
const os = require('os');

const LEARNING_STATE_PATH = path.join(os.homedir(), '.codex', '.learning-state.json');

const EMPTY_STATE = {
  version: '1.0.0',
  last_updated: new Date().toISOString(),
  outcomes: [],
  trigger_metrics: {},
  skill_suggestions: [],
  pattern_observations: []
};

function ensureDir() {
  const dir = path.dirname(LEARNING_STATE_PATH);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

function readState() {
  ensureDir();
  if (!fs.existsSync(LEARNING_STATE_PATH)) return { ...EMPTY_STATE };
  try {
    return JSON.parse(fs.readFileSync(LEARNING_STATE_PATH, 'utf8'));
  } catch (e) {
    console.error('Warning: corrupted learning state, resetting');
    return { ...EMPTY_STATE };
  }
}

function writeState(state) {
  ensureDir();
  state.last_updated = new Date().toISOString();
  const backup = LEARNING_STATE_PATH + '.bak';
  if (fs.existsSync(LEARNING_STATE_PATH)) {
    fs.copyFileSync(LEARNING_STATE_PATH, backup);
  }
  fs.writeFileSync(LEARNING_STATE_PATH, JSON.stringify(state, null, 2));
}

module.exports = { readState, writeState, LEARNING_STATE_PATH, EMPTY_STATE };
```

- [ ] **Step 2: Test learning state manager**

Run: `node -e "const ls = require('./lib/learning-state'); console.log(ls.readState())"`
Expected: JSON object with version "1.0.0"

- [ ] **Step 3: Commit**

```bash
git add lib/learning-state.js
git commit -m "feat(learning): add learning state manager with read/write"
```

---

### Task 1.2: Add Outcome Recording

**Files:**
- Modify: `lib/learning-state.js` (add recordOutcome function)

- [ ] **Step 1: Add recordOutcome function**

```javascript
function recordOutcome(skill, outcome, evidence = '', triggerPhrase = '') {
  const state = readState();
  const id = `outcome-${Date.now()}`;
  state.outcomes.push({
    id,
    skill,
    timestamp: new Date().toISOString(),
    trigger_phrase: triggerPhrase,
    outcome, // 'success' | 'failure'
    evidence
  });
  // Update trigger metrics
  if (!state.trigger_metrics[skill]) {
    state.trigger_metrics[skill] = {
      total_fires: 0, successes: 0, failures: 0,
      success_rate: 0, common_triggers: [], suggested_triggers: []
    };
  }
  const metrics = state.trigger_metrics[skill];
  metrics.total_fires++;
  if (outcome === 'success') metrics.successes++;
  else metrics.failures++;
  metrics.success_rate = metrics.successes / metrics.total_fires;
  if (triggerPhrase && !metrics.common_triggers.includes(triggerPhrase)) {
    metrics.common_triggers.push(triggerPhrase);
    if (metrics.common_triggers.length > 10) metrics.common_triggers.shift();
  }
  writeState(state);
  return id;
}

module.exports = { readState, writeState, recordOutcome, LEARNING_STATE_PATH, EMPTY_STATE };
```

- [ ] **Step 2: Test outcome recording**

Run: `node -e "const ls = require('./lib/learning-state'); ls.recordOutcome('test-skill', 'success', 'test passed'); console.log(ls.readState().outcomes)"`
Expected: Array with one outcome entry

- [ ] **Step 3: Commit**

```bash
git add lib/learning-state.js
git commit -m "feat(learning): add outcome recording with metrics aggregation"
```

---

## Chunk 2: CLI Integration

### Task 2.1: Add record-outcome command to superpowers-augment.js

**Files:**
- Modify: `superpowers-augment.js`

- [ ] **Step 1: Import learning-state module at top**

Add after line 8:
```javascript
const { readState, writeState, recordOutcome } = require('./lib/learning-state');
```

- [ ] **Step 2: Add record-outcome command handler**

Add to switch statement:
```javascript
case 'record-outcome':
    const skill = args[0];
    const outcome = args[1]; // success|failure
    const evidence = args.slice(2).join(' ') || '';
    if (!skill || !outcome) {
        console.error('Usage: record-outcome <skill> <success|failure> [evidence]');
        process.exit(1);
    }
    const id = recordOutcome(skill, outcome, evidence);
    console.log(`✓ Recorded ${outcome} for ${skill} (${id})`);
    break;
```

- [ ] **Step 3: Test record-outcome command**

Run: `node superpowers-augment.js record-outcome systematic-debugging success "bug fixed, tests pass"`
Expected: "✓ Recorded success for systematic-debugging (outcome-...)"

- [ ] **Step 4: Commit**

```bash
git add superpowers-augment.js
git commit -m "feat(cli): add record-outcome command"
```

---

### Task 2.2: Add analyze-triggers command

**Files:**
- Modify: `superpowers-augment.js`

- [ ] **Step 1: Add analyzeTriggers function**

```javascript
function analyzeTriggers() {
    const state = readState();
    console.log('# Trigger Effectiveness Analysis\n');
    const skills = Object.entries(state.trigger_metrics);
    if (skills.length === 0) {
        console.log('No data yet. Record outcomes with: record-outcome <skill> <success|failure>');
        return;
    }
    console.log('| Skill | Fires | Success Rate | Status |');
    console.log('|-------|-------|--------------|--------|');
    for (const [skill, m] of skills) {
        const rate = (m.success_rate * 100).toFixed(0);
        const status = m.success_rate >= 0.8 ? '✅' : m.success_rate >= 0.5 ? '🟡' : '🔴';
        console.log(`| ${skill} | ${m.total_fires} | ${rate}% | ${status} |`);
    }
    // Suggestions
    const suggestions = state.skill_suggestions.filter(s => s.status === 'pending');
    if (suggestions.length > 0) {
        console.log('\n## Suggested Improvements\n');
        for (const s of suggestions) {
            console.log(`- Add trigger "${s.suggested}" to ${s.skill} (${s.evidence_count} observations)`);
        }
    }
}
```

- [ ] **Step 2: Add to switch statement**

```javascript
case 'analyze-triggers':
    analyzeTriggers();
    break;
```

- [ ] **Step 3: Test analyze-triggers**

Run: `node superpowers-augment.js analyze-triggers`
Expected: Table showing skill metrics

- [ ] **Step 4: Commit**

```bash
git add superpowers-augment.js
git commit -m "feat(cli): add analyze-triggers command"
```

---

## Chunk 3: Bootstrap Integration

### Task 3.1: Show learning insights on bootstrap

**Files:**
- Modify: `superpowers-augment.js` (bootstrap function)

- [ ] **Step 1: Add learning insights to bootstrap**

In bootstrap() function, after findSkills(), add:
```javascript
// Learning insights
const state = readState();
const metrics = Object.entries(state.trigger_metrics);
if (metrics.length > 0) {
    console.log('\n---\n');
    console.log('📊 Learning Insights\n');
    const lowPerformers = metrics.filter(([_, m]) => m.success_rate < 0.7 && m.total_fires >= 3);
    if (lowPerformers.length > 0) {
        console.log('⚠️ Skills with <70% success rate:');
        for (const [skill, m] of lowPerformers) {
            console.log(`  - ${skill}: ${(m.success_rate * 100).toFixed(0)}% (${m.total_fires} fires)`);
        }
    }
    const topPerformers = metrics.filter(([_, m]) => m.success_rate >= 0.9 && m.total_fires >= 5);
    if (topPerformers.length > 0) {
        console.log('✅ Top performing skills:');
        for (const [skill, m] of topPerformers) {
            console.log(`  - ${skill}: ${(m.success_rate * 100).toFixed(0)}% (${m.total_fires} fires)`);
        }
    }
}
```

- [ ] **Step 2: Test bootstrap with learning data**

Run: `node superpowers-augment.js bootstrap`
Expected: See "Learning Insights" section if outcome data exists

- [ ] **Step 3: Commit**

```bash
git add superpowers-augment.js
git commit -m "feat(bootstrap): show learning insights on session start"
```

---

## Chunk 4: Skill Skill & Documentation

### Task 4.1: Create skill-effectiveness skill

**Files:**
- Create: `skills/observability/skill-effectiveness/skill.md`

- [ ] **Step 1: Write skill definition**

Create the skill file with triggers and instructions for recording outcomes.

- [ ] **Step 2: Update README.md**

Add skill-effectiveness to the observability section.

- [ ] **Step 3: Commit**

```bash
git add skills/observability/skill-effectiveness/
git add README.md
git commit -m "feat(skill): add skill-effectiveness observability skill"
```

---

## Verification Checklist

- [ ] `node superpowers-augment.js record-outcome test success "it works"` — records outcome
- [ ] `cat ~/.codex/.learning-state.json | jq .outcomes` — shows recorded outcomes
- [ ] `node superpowers-augment.js analyze-triggers` — shows trigger report
- [ ] `node superpowers-augment.js bootstrap` — shows learning insights section
- [ ] Recording multiple outcomes updates success_rate correctly
