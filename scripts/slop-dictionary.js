#!/usr/bin/env node
/**
 * slop-dictionary.js
 * CLI tool for managing the slop dictionary
 *
 * Usage:
 *   node slop-dictionary.js add <phrase> <category>
 *   node slop-dictionary.js except <phrase> [scope]
 *   node slop-dictionary.js remove <phrase>
 *   node slop-dictionary.js list [category]
 *   node slop-dictionary.js exceptions
 *   node slop-dictionary.js top [n]
 *   node slop-dictionary.js seed-profanity
 *   node slop-dictionary.js scan-profanity [file]
 *   node slop-dictionary.js seed-ai-process-refs
 *   node slop-dictionary.js scan-ai-process-refs [file]
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const DICTIONARY_FILE = path.join(process.cwd(), '.slop-dictionary.json');
const PROFANITY_PATTERNS_FILE = path.join(__dirname, '.profanity-patterns.txt');
const AI_PROCESS_REFS_PATTERNS_FILE = path.join(__dirname, '.ai-process-refs-patterns.txt');

const CATEGORIES = [
  'generic-booster',
  'buzzword',
  'filler-phrase',
  'hedge-pattern',
  'sycophantic-phrase',
  'transitional-filler',
  'profanity',
  'ai-process-reference'
];

/**
 * Load newline-delimited patterns from a file, checking scripts/ first and
 * falling back to the repo root. Shared by profanity and AI-process-reference
 * pattern loaders to keep external words/phrases out of main codebase.
 */
function loadPatternsFromFile(scriptsDirFile, rootFileName) {
  if (fs.existsSync(scriptsDirFile)) {
    return fs.readFileSync(scriptsDirFile, 'utf8')
      .split('\n')
      .map(line => line.trim().toLowerCase())
      .filter(line => line && !line.startsWith('#'));
  }
  const rootFile = path.join(process.cwd(), rootFileName);
  if (fs.existsSync(rootFile)) {
    return fs.readFileSync(rootFile, 'utf8')
      .split('\n')
      .map(line => line.trim().toLowerCase())
      .filter(line => line && !line.startsWith('#'));
  }
  return [];
}

function loadProfanityPatterns() {
  return loadPatternsFromFile(PROFANITY_PATTERNS_FILE, '.profanity-patterns.txt');
}

/**
 * Load AI-process self-reference patterns (this toolkit's own internal
 * workflow language -- harsh-review, cr-battery, PHR, etc.) that should
 * never appear in PR descriptions or commit messages for a downstream
 * adopter's own product repo, where this vocabulary means nothing to a
 * reviewer. Skipped entirely inside superpowers-plus itself (see
 * isToolkitSelfRepo below), where naming these skills is normal subject
 * matter, not a violation.
 */
function loadAiProcessRefPatterns() {
  return loadPatternsFromFile(AI_PROCESS_REFS_PATTERNS_FILE, '.ai-process-refs-patterns.txt');
}

/**
 * True when the current working directory is inside superpowers-plus
 * itself (or a fork/mirror of it) -- naming these skills (harsh-review,
 * cr-battery, PHR, etc.) is normal subject matter there, not a violation.
 * Checked via the git remote first (fast, works for any real clone), falling
 * back to a content marker in the repo's own AGENTS.md (works for a fork or
 * mirror under a different remote name/path).
 */
function isToolkitSelfRepo() {
  try {
    const remote = execSync('git remote get-url origin', { cwd: process.cwd(), stdio: ['pipe', 'pipe', 'ignore'] })
      .toString()
      .trim();
    if (/[:/]superpowers-plus(\.git)?\/?$/.test(remote)) {
      return true;
    }
  } catch {
    // No remote, or not a git repo -- fall through to the marker check.
  }

  try {
    const toplevel = execSync('git rev-parse --show-toplevel', { cwd: process.cwd(), stdio: ['pipe', 'pipe', 'ignore'] })
      .toString()
      .trim();
    const agentsMd = path.join(toplevel, 'AGENTS.md');
    if (fs.existsSync(agentsMd) && fs.readFileSync(agentsMd, 'utf8').includes('AI Agent Guidelines - superpowers-plus')) {
      return true;
    }
  } catch {
    // Not a git repo, or no AGENTS.md at the root.
  }

  return false;
}

function loadDictionary() {
  if (!fs.existsSync(DICTIONARY_FILE)) {
    return {
      version: '1.0',
      created: new Date().toISOString(),
      patterns: [],
      exceptions: []
    };
  }
  return JSON.parse(fs.readFileSync(DICTIONARY_FILE, 'utf8'));
}

function saveDictionary(dict) {
  fs.writeFileSync(DICTIONARY_FILE, JSON.stringify(dict, null, 2));
}

function addPattern(phrase, category) {
  if (!CATEGORIES.includes(category)) {
    console.error(`Invalid category: ${category}`);
    console.error(`Valid categories: ${CATEGORIES.join(', ')}`);
    process.exit(1);
  }
  
  const dict = loadDictionary();
  const existing = dict.patterns.find(p => p.phrase.toLowerCase() === phrase.toLowerCase());
  
  if (existing) {
    existing.count = (existing.count || 0) + 1;
    console.log(`Updated '${phrase}' count to ${existing.count}`);
  } else {
    dict.patterns.push({
      phrase: phrase.toLowerCase(),
      category,
      count: 1,
      added: new Date().toISOString().split('T')[0],
      source: 'user'
    });
    console.log(`Added '${phrase}' to ${category}`);
  }
  
  saveDictionary(dict);
}

function addException(phrase, scope = 'permanent') {
  const dict = loadDictionary();
  const existing = dict.exceptions.find(e => e.phrase.toLowerCase() === phrase.toLowerCase());
  
  if (existing) {
    console.log(`'${phrase}' is already excepted`);
    return;
  }
  
  dict.exceptions.push({
    phrase: phrase.toLowerCase(),
    scope,
    added: new Date().toISOString().split('T')[0]
  });
  
  console.log(`Added '${phrase}' to exceptions (${scope})`);
  saveDictionary(dict);
}

function removePattern(phrase) {
  const dict = loadDictionary();
  const idx = dict.patterns.findIndex(p => p.phrase.toLowerCase() === phrase.toLowerCase());
  
  if (idx === -1) {
    console.log(`'${phrase}' not found in patterns`);
    return;
  }
  
  dict.patterns.splice(idx, 1);
  console.log(`Removed '${phrase}' from patterns`);
  saveDictionary(dict);
}

function listPatterns(category) {
  if (category && !CATEGORIES.includes(category)) {
    console.error(`Invalid category: ${category}`);
    console.error(`Valid categories: ${CATEGORIES.join(', ')}`);
    process.exit(1);
  }

  const dict = loadDictionary();
  let patterns = dict.patterns;

  if (category) {
    patterns = patterns.filter(p => p.category === category);
  }
  
  if (patterns.length === 0) {
    console.log(category ? `No patterns in category: ${category}` : 'No patterns in dictionary');
    return;
  }
  
  console.log(`\nPatterns${category ? ` (${category})` : ''}:`);
  patterns.sort((a, b) => (b.count || 0) - (a.count || 0));
  patterns.forEach(p => {
    console.log(`  ${p.phrase} [${p.category}] - count: ${p.count || 0}`);
  });
}

function listExceptions() {
  const dict = loadDictionary();
  
  if (dict.exceptions.length === 0) {
    console.log('No exceptions in dictionary');
    return;
  }
  
  console.log('\nExceptions:');
  dict.exceptions.forEach(e => {
    console.log(`  ${e.phrase} (${e.scope}) - added: ${e.added}`);
  });
}

function topPatterns(n = 10) {
  const dict = loadDictionary();
  const sorted = [...dict.patterns].sort((a, b) => (b.count || 0) - (a.count || 0));
  const top = sorted.slice(0, n);

  if (top.length === 0) {
    console.log('No patterns in dictionary');
    return;
  }

  console.log(`\nTop ${Math.min(n, top.length)} patterns:`);
  top.forEach((p, i) => {
    console.log(`  ${i + 1}. ${p.phrase} [${p.category}] - count: ${p.count || 0}`);
  });
}

/**
 * Seed the dictionary with patterns from an external file under a given
 * category. Shared by seedProfanity and seedAiProcessRefs.
 */
function seedPatternsFromFile(patterns, category, sourceLabel, fileHint) {
  if (patterns.length === 0) {
    console.error(`No ${category} patterns loaded.`);
    console.error(`Create ${fileHint} in scripts/ or repo root.`);
    console.error('Format: one pattern per line, # for comments');
    process.exit(1);
  }

  const dict = loadDictionary();
  let added = 0;
  let skipped = 0;

  for (const phrase of patterns) {
    const existing = dict.patterns.find(p => p.phrase.toLowerCase() === phrase.toLowerCase());
    if (!existing) {
      dict.patterns.push({
        phrase: phrase.toLowerCase(),
        category,
        count: 0,
        added: new Date().toISOString().split('T')[0],
        source: sourceLabel
      });
      added++;
    } else {
      skipped++;
    }
  }

  if (added > 0) {
    saveDictionary(dict);
    console.log(`Seeded ${added} ${category} patterns to dictionary`);
    if (skipped > 0) {
      console.log(`Skipped ${skipped} patterns (already present)`);
    }
  } else {
    console.log(`${category} patterns already present in dictionary`);
  }

  return added;
}

/**
 * Seed the dictionary with profanity patterns from external file
 * Profanity patterns are HARD BLOCK - they add +50 points each
 */
function seedProfanity() {
  return seedPatternsFromFile(loadProfanityPatterns(), 'profanity', 'built-in-profanity', '.profanity-patterns.txt');
}

/**
 * Seed the dictionary with AI-process self-reference patterns from external
 * file. Same HARD BLOCK treatment as profanity.
 */
function seedAiProcessRefs() {
  return seedPatternsFromFile(loadAiProcessRefPatterns(), 'ai-process-reference', 'built-in-ai-process-refs', '.ai-process-refs-patterns.txt');
}

/**
 * Scan a file or stdin against a pattern list.
 *
 * Exit codes:
 *   0 - clean, no match
 *   1 - match found
 *   2 - input was empty/whitespace-only -- nothing was scanned. This is
 *       deliberately distinct from 0 so a caller can't mistake "the variable
 *       I meant to scan was never set" for "scanned and clean".
 *
 * Matches span the whole content, not line-by-line, so a multi-word pattern
 * split across a line wrap (a normal thing in hand-wrapped PR prose) is
 * still caught; a literal space in a pattern matches any run of whitespace,
 * including a newline. Pattern text is regex-escaped before use.
 *
 * Shared by scanProfanity and scanAiProcessRefs.
 */
function scanForPatterns(patterns, filePath, label, seedCommand) {
  let content;
  if (filePath && filePath !== '-') {
    if (!fs.existsSync(filePath)) {
      console.error(`File not found: ${filePath}`);
      process.exit(1);
    }
    content = fs.readFileSync(filePath, 'utf8');
  } else {
    // Read from stdin
    content = fs.readFileSync(0, 'utf8');
  }

  // Checked before the patterns-loaded check below so an empty/whitespace-only
  // input always reports as empty (exit 2), never masked by an unrelated
  // missing-pattern-file error (exit 1) when both conditions happen to hold.
  if (content.trim() === '') {
    console.error(`ERROR: input is empty -- nothing was scanned for ${label.toLowerCase()}.`);
    console.error('This is not a clean pass. A variable that was never set produces an empty file; populate the real content before scanning.');
    process.exit(2);
  }

  if (patterns.length === 0) {
    console.error(`No ${label.toLowerCase()} patterns loaded. Run: node slop-dictionary.js ${seedCommand}`);
    process.exit(1);
  }

  const lines = content.split('\n');
  const matches = [];

  const escaped = patterns.map((p) => p.replace(/[.*+?^${}()|[\]\\]/g, '\\$&').replace(/ /g, '\\s+'));
  const regex = new RegExp(`\\b(${escaped.join('|')})\\b`, 'gi');

  let match;
  while ((match = regex.exec(content)) !== null) {
    const upToMatch = content.slice(0, match.index);
    const lineNum = upToMatch.split('\n').length;
    const lineStart = upToMatch.lastIndexOf('\n') + 1;
    matches.push({
      line: lineNum,
      column: match.index - lineStart + 1,
      // Collapse whitespace so a match spanning a line wrap still prints as
      // one readable table row instead of breaking across lines.
      text: match[0].replace(/\s+/g, ' '),
      context: (lines[lineNum - 1] || '').trim().substring(0, 60)
    });
  }

  if (matches.length > 0) {
    console.log(`\n⛔ ${label} DETECTED — ${matches.length} match(es)\n`);
    console.log('| Line | Match | Context |');
    console.log('|------|-------|---------|');
    matches.forEach(m => {
      console.log(`| ${m.line} | "${m.text}" | ${m.context}... |`);
    });
    console.log('\nAction: Replace flagged terms before commit/publish.');
    process.exit(1);
  } else {
    console.log(`✅ No ${label.toLowerCase()} detected`);
    process.exit(0);
  }
}

/**
 * Scan a file or stdin for profanity patterns
 * Returns exit code 1 if profanity found (for CI/pre-commit hooks)
 */
function scanProfanity(filePath) {
  scanForPatterns(loadProfanityPatterns(), filePath, 'PROFANITY', 'seed-profanity');
}

/**
 * Scan a file or stdin (or a PR description written to a temp file) for
 * AI-process self-reference patterns. Returns exit code 1 if found. Skipped
 * (exit 0, with a visible notice) when run inside superpowers-plus itself
 * or a fork/mirror of it, where naming these skills is normal subject matter.
 */
function scanAiProcessRefs(filePath) {
  if (isToolkitSelfRepo()) {
    console.log('ℹ️  ai-process-reference scan skipped (superpowers-plus self-repo exemption)');
    process.exit(0);
  }
  scanForPatterns(loadAiProcessRefPatterns(), filePath, 'AI-PROCESS REFERENCE', 'seed-ai-process-refs');
}

// Main
const [,, command, ...args] = process.argv;

switch (command) {
  case 'add':
    if (args.length < 2) {
      console.error('Usage: node slop-dictionary.js add <phrase> <category>');
      process.exit(1);
    }
    addPattern(args[0], args[1]);
    break;
  case 'except':
    if (args.length < 1) {
      console.error('Usage: node slop-dictionary.js except <phrase> [scope]');
      process.exit(1);
    }
    addException(args[0], args[1]);
    break;
  case 'remove':
    if (args.length < 1) {
      console.error('Usage: node slop-dictionary.js remove <phrase>');
      process.exit(1);
    }
    removePattern(args[0]);
    break;
  case 'list':
    listPatterns(args[0]);
    break;
  case 'exceptions':
    listExceptions();
    break;
  case 'top':
    topPatterns(parseInt(args[0]) || 10);
    break;
  case 'seed-profanity':
    seedProfanity();
    break;
  case 'scan-profanity':
    scanProfanity(args[0]);
    break;
  case 'seed-ai-process-refs':
    seedAiProcessRefs();
    break;
  case 'scan-ai-process-refs':
    scanAiProcessRefs(args[0]);
    break;
  default:
    console.log('Usage: node slop-dictionary.js <command> [args]');
    console.log('\nCommands:');
    console.log('  add <phrase> <category>       Add pattern to dictionary');
    console.log('  except <phrase> [scope]       Add exception (default: permanent)');
    console.log('  remove <phrase>               Remove pattern from dictionary');
    console.log('  list [category]               List patterns (optionally by category)');
    console.log('  exceptions                    List all exceptions');
    console.log('  top [n]                       Show top N patterns by count');
    console.log('  seed-profanity                Seed dictionary with profanity patterns');
    console.log('  scan-profanity [file]         Scan file for profanity (exit 1 if found)');
    console.log('  seed-ai-process-refs          Seed dictionary with AI-process-reference patterns');
    console.log('  scan-ai-process-refs [file]   Scan file for AI-process references (exit 1 if found)');
    console.log('\nCategories:', CATEGORIES.join(', '));
    console.log('\nProfanity patterns: Place .profanity-patterns.txt in scripts/ or repo root');
    console.log('AI-process-ref patterns: Place .ai-process-refs-patterns.txt in scripts/ or repo root');
}
