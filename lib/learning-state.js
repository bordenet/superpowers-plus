/**
 * Learning State Manager
 * 
 * Manages the persistent learning state for skill effectiveness tracking.
 * Stores outcomes, trigger metrics, and improvement suggestions.
 * 
 * Location: ~/.codex/.learning-state.json
 */

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

/**
 * Ensure the directory exists for the learning state file
 */
function ensureDir() {
  const dir = path.dirname(LEARNING_STATE_PATH);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

/**
 * Read the current learning state from disk
 * @returns {Object} The learning state object
 */
function readState() {
  ensureDir();
  if (!fs.existsSync(LEARNING_STATE_PATH)) {
    return { ...EMPTY_STATE, last_updated: new Date().toISOString() };
  }
  try {
    const content = fs.readFileSync(LEARNING_STATE_PATH, 'utf8');
    const state = JSON.parse(content);
    // Ensure all required fields exist (migration safety)
    return {
      ...EMPTY_STATE,
      ...state
    };
  } catch (e) {
    console.error('Warning: corrupted learning state, resetting:', e.message);
    return { ...EMPTY_STATE, last_updated: new Date().toISOString() };
  }
}

/**
 * Write the learning state to disk with backup
 * @param {Object} state - The learning state to write
 */
function writeState(state) {
  ensureDir();
  state.last_updated = new Date().toISOString();
  
  // Create backup before writing
  const backup = LEARNING_STATE_PATH + '.bak';
  if (fs.existsSync(LEARNING_STATE_PATH)) {
    fs.copyFileSync(LEARNING_STATE_PATH, backup);
  }
  
  fs.writeFileSync(LEARNING_STATE_PATH, JSON.stringify(state, null, 2));
}

/**
 * Record an outcome for a skill invocation
 * @param {string} skill - The skill name
 * @param {string} outcome - 'success' or 'failure'
 * @param {string} evidence - Optional evidence for the outcome
 * @param {string} triggerPhrase - Optional trigger phrase that invoked the skill
 * @returns {string} The outcome ID
 */
function recordOutcome(skill, outcome, evidence = '', triggerPhrase = '') {
  const state = readState();
  const id = `outcome-${Date.now()}`;
  
  // Add to outcomes array
  state.outcomes.push({
    id,
    skill,
    timestamp: new Date().toISOString(),
    trigger_phrase: triggerPhrase,
    outcome, // 'success' | 'failure'
    evidence
  });
  
  // Keep only last 1000 outcomes to prevent unbounded growth
  if (state.outcomes.length > 1000) {
    state.outcomes = state.outcomes.slice(-1000);
  }
  
  // Update trigger metrics
  if (!state.trigger_metrics[skill]) {
    state.trigger_metrics[skill] = {
      total_fires: 0,
      successes: 0,
      failures: 0,
      success_rate: 0,
      common_triggers: [],
      suggested_triggers: [],
      false_positive_phrases: []
    };
  }
  
  const metrics = state.trigger_metrics[skill];
  metrics.total_fires++;
  
  if (outcome === 'success') {
    metrics.successes++;
  } else {
    metrics.failures++;
  }
  
  metrics.success_rate = metrics.total_fires > 0 
    ? metrics.successes / metrics.total_fires 
    : 0;
  
  // Track common trigger phrases
  if (triggerPhrase && !metrics.common_triggers.includes(triggerPhrase)) {
    metrics.common_triggers.push(triggerPhrase);
    // Keep only last 10 triggers
    if (metrics.common_triggers.length > 10) {
      metrics.common_triggers.shift();
    }
  }
  
  writeState(state);
  return id;
}

/**
 * Get metrics summary for all skills
 * @returns {Object} Metrics by skill
 */
function getMetricsSummary() {
  const state = readState();
  return state.trigger_metrics;
}

/**
 * Add a suggestion for skill improvement
 * @param {string} type - 'new_trigger' | 'remove_trigger' | 'new_skill'
 * @param {string} skill - The skill name
 * @param {string} suggested - The suggested value
 * @param {number} evidenceCount - Number of observations supporting this
 */
function addSuggestion(type, skill, suggested, evidenceCount = 1) {
  const state = readState();
  
  // Check if suggestion already exists
  const existing = state.skill_suggestions.find(
    s => s.type === type && s.skill === skill && s.suggested === suggested
  );
  
  if (existing) {
    existing.evidence_count += evidenceCount;
  } else {
    state.skill_suggestions.push({
      type,
      skill,
      suggested,
      evidence_count: evidenceCount,
      status: 'pending',
      created: new Date().toISOString()
    });
  }
  
  writeState(state);
}

/**
 * Record a pattern observation (for future skill synthesis)
 * @param {string} pattern - Description of the observed pattern
 * @param {string} potentialSkill - Suggested skill name
 */
function recordPattern(pattern, potentialSkill) {
  const state = readState();

  // Check if pattern already exists
  const existing = state.pattern_observations.find(p => p.pattern === pattern);

  if (existing) {
    existing.frequency++;
    existing.last_seen = new Date().toISOString();
  } else {
    state.pattern_observations.push({
      pattern,
      potential_skill: potentialSkill,
      frequency: 1,
      status: 'observed',
      first_seen: new Date().toISOString(),
      last_seen: new Date().toISOString()
    });
  }

  // Keep only top 50 patterns by frequency
  state.pattern_observations.sort((a, b) => b.frequency - a.frequency);
  state.pattern_observations = state.pattern_observations.slice(0, 50);

  writeState(state);
}

/**
 * Mark a suggestion as applied or dismissed
 * @param {number} index - Index of the suggestion
 * @param {string} status - 'applied' | 'dismissed'
 */
function updateSuggestionStatus(index, status) {
  const state = readState();
  if (state.skill_suggestions[index]) {
    state.skill_suggestions[index].status = status;
    state.skill_suggestions[index].resolved_at = new Date().toISOString();
    writeState(state);
    return true;
  }
  return false;
}

/**
 * Get skills that need attention based on metrics
 * @returns {Array} Skills with low success rates or other issues
 */
function getSkillsNeedingAttention() {
  const state = readState();
  const issues = [];

  for (const [skill, m] of Object.entries(state.trigger_metrics)) {
    // Low success rate with enough data
    if (m.total_fires >= 3 && m.success_rate < 0.7) {
      issues.push({
        skill,
        issue: 'low_success_rate',
        rate: m.success_rate,
        fires: m.total_fires,
        message: `${skill} has ${(m.success_rate * 100).toFixed(0)}% success rate`
      });
    }

    // High failure count
    if (m.failures >= 5) {
      issues.push({
        skill,
        issue: 'high_failures',
        failures: m.failures,
        message: `${skill} has ${m.failures} recorded failures`
      });
    }
  }

  return issues;
}

/**
 * Generate a report of trigger phrase effectiveness
 * @returns {Object} Report with trigger analysis
 */
function generateTriggerReport() {
  const state = readState();

  const report = {
    generated_at: new Date().toISOString(),
    overall: {
      total_fires: 0,
      total_successes: 0,
      total_failures: 0,
      success_rate: 0
    },
    by_skill: {},
    suggestions: state.skill_suggestions.filter(s => s.status === 'pending'),
    patterns: state.pattern_observations.filter(p => p.frequency >= 3)
  };

  for (const [skill, m] of Object.entries(state.trigger_metrics)) {
    report.overall.total_fires += m.total_fires;
    report.overall.total_successes += m.successes;
    report.overall.total_failures += m.failures;

    report.by_skill[skill] = {
      fires: m.total_fires,
      successes: m.successes,
      failures: m.failures,
      success_rate: m.success_rate,
      common_triggers: m.common_triggers,
      status: m.success_rate >= 0.8 ? 'healthy' : m.success_rate >= 0.5 ? 'monitor' : 'needs_work'
    };
  }

  if (report.overall.total_fires > 0) {
    report.overall.success_rate = report.overall.total_successes / report.overall.total_fires;
  }

  return report;
}

module.exports = {
  readState,
  writeState,
  recordOutcome,
  getMetricsSummary,
  addSuggestion,
  recordPattern,
  updateSuggestionStatus,
  getSkillsNeedingAttention,
  generateTriggerReport,
  LEARNING_STATE_PATH,
  EMPTY_STATE
};

