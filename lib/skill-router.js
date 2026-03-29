/**
 * Semantic Skill Router
 *
 * Matches user queries to skills using multiple strategies:
 * 1. TF-IDF: Fast, offline, zero dependencies (primary)
 * 2. Embeddings: OpenAI API for enhanced accuracy (optional)
 *
 * The router automatically uses the best available method.
 *
 * Location: lib/skill-router.js
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

const EMBEDDINGS_CACHE_PATH = path.join(os.homedir(), '.codex', '.skill-embeddings.json');

// ============================================================================
// TF-IDF Implementation (Primary - No API Required)
// ============================================================================

/**
 * Simple stemmer - removes common suffixes
 */
function stem(word) {
  return word
    .replace(/ing$/, '')
    .replace(/ed$/, '')
    .replace(/s$/, '')
    .replace(/ly$/, '')
    .replace(/tion$/, 't')
    .replace(/ment$/, '');
}

/**
 * Tokenize text into normalized, stemmed terms
 */
function tokenize(text) {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, ' ')  // Keep alphanumeric and hyphens
    .split(/\s+/)
    .filter(t => t.length > 1)      // Skip single chars
    .map(stem);                      // Apply stemming
}

/**
 * Common English stop words to ignore
 */
const STOP_WORDS = new Set([
  'a', 'an', 'the', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
  'of', 'with', 'by', 'from', 'as', 'is', 'was', 'are', 'were', 'been',
  'be', 'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could',
  'should', 'may', 'might', 'must', 'shall', 'can', 'need', 'dare', 'ought',
  'used', 'it', 'its', 'this', 'that', 'these', 'those', 'i', 'you', 'he',
  'she', 'we', 'they', 'what', 'which', 'who', 'when', 'where', 'why', 'how',
  'all', 'each', 'every', 'both', 'few', 'more', 'most', 'other', 'some',
  'such', 'no', 'not', 'only', 'same', 'so', 'than', 'too', 'very', 'just',
  'use', 'using', 'used', 'invoke', 'skill', 'before', 'after', 'any',
  'my', 'your', 'our', 'their', 'keep', 'want', 'like', 'get', 'go'
]);

/**
 * Build text for a skill (name + description + triggers)
 */
function buildSkillText(skill) {
  const parts = [
    skill.name.replace(/-/g, ' '),  // Convert kebab-case to spaces
    skill.name,                      // Keep original for exact matches
  ];
  if (skill.description) parts.push(skill.description);
  if (skill.triggers && skill.triggers.length > 0) {
    parts.push(skill.triggers.join(' '));
  }
  return parts.join(' ');
}

/**
 * Calculate TF-IDF scores for a corpus of documents
 */
function buildTfIdfIndex(skills) {
  const documents = skills.map(s => ({
    skill: s,
    text: buildSkillText(s),
    terms: tokenize(buildSkillText(s)).filter(t => !STOP_WORDS.has(t))
  }));

  // Calculate document frequency (DF) for each term
  // Use Object.create(null) to avoid prototype pollution with terms like "constructor"
  const df = Object.create(null);
  for (const doc of documents) {
    const seen = new Set();
    for (const term of doc.terms) {
      if (!seen.has(term)) {
        df[term] = (df[term] || 0) + 1;
        seen.add(term);
      }
    }
  }

  // Calculate TF-IDF vectors for each document
  const N = documents.length;
  for (const doc of documents) {
    // Use Object.create(null) to avoid prototype pollution with terms like "constructor"
    const tf = Object.create(null);
    for (const term of doc.terms) {
      tf[term] = (tf[term] || 0) + 1;
    }

    doc.tfidf = {};
    for (const [term, count] of Object.entries(tf)) {
      // TF: log-normalized frequency
      const tfScore = 1 + Math.log(count);
      // IDF: inverse document frequency with smoothing
      // Note: Must use Object.hasOwn() to avoid prototype pollution with terms like "constructor"
      const docFreq = Object.hasOwn(df, term) ? df[term] : 1;
      const idfScore = Math.log(N / docFreq);
      doc.tfidf[term] = tfScore * idfScore;
    }

    // Calculate magnitude for cosine similarity
    doc.magnitude = Math.sqrt(
      Object.values(doc.tfidf).reduce((sum, v) => sum + v * v, 0)
    );
  }

  return { documents, df, N };
}

/**
 * Calculate TF-IDF similarity between query and document
 */
function tfidfSimilarity(queryTerms, doc, df, N) {
  if (doc.magnitude === 0) return 0;

  // Calculate query TF-IDF
  const queryTf = {};
  for (const term of queryTerms) {
    queryTf[term] = (queryTf[term] || 0) + 1;
  }

  const queryTfidf = {};
  let queryMagnitude = 0;
  for (const [term, count] of Object.entries(queryTf)) {
    const tfScore = 1 + Math.log(count);
    // Note: Must use Object.hasOwn() to avoid prototype pollution with terms like "constructor"
    const docFreq = Object.hasOwn(df, term) ? df[term] : 1;
    const idfScore = Math.log(N / docFreq);
    queryTfidf[term] = tfScore * idfScore;
    queryMagnitude += queryTfidf[term] * queryTfidf[term];
  }
  queryMagnitude = Math.sqrt(queryMagnitude);

  if (queryMagnitude === 0) return 0;

  // Calculate dot product
  let dotProduct = 0;
  for (const [term, score] of Object.entries(queryTfidf)) {
    if (doc.tfidf[term]) {
      dotProduct += score * doc.tfidf[term];
    }
  }

  return dotProduct / (queryMagnitude * doc.magnitude);
}

/**
 * Domain-specific concept mappings for query expansion
 * Keys are STEMMED forms (after our stem() function)
 * Values include both stemmed and full forms for matching
 */
const CONCEPT_EXPANSIONS = {
  // Debugging/Testing concepts (stemmed: fail, test, bug, error, crash, flak)
  'fail': ['debug', 'systematic', 'fix', 'error', 'bug', 'broken', 'systematic-debug'],
  'test': ['debug', 'tdd', 'vitest', 'fail', 'systematic', 'test-driven'],
  'bug': ['debug', 'systematic', 'fix', 'error', 'fail', 'systematic-debug'],
  'error': ['debug', 'systematic', 'fix', 'bug', 'fail'],
  'crash': ['debug', 'systematic', 'error', 'fix', 'fail'],
  'flak': ['test', 'debug', 'vitest', 'systematic'],  // flaky -> flak after stemming
  'broken': ['debug', 'fix', 'systematic', 'error'],
  'debug': ['systematic', 'bug', 'error', 'fix', 'fail'],

  // Code review concepts
  'review': ['code-review', 'pr', 'provid', 'receiv', 'feedback', 'battery'],  // provid=providing, receiv=receiving
  'pr': ['pull-request', 'code-review', 'review', 'merg'],
  'pull': ['pull-request', 'code-review', 'pr', 'merg', 'request'],
  'request': ['pull', 'pr', 'code-review', 'merg'],

  // Code review battery concepts (parallel specialized review)
  'battery': ['review', 'parallel', 'code-review', 'special', 'multi-agent'],
  'parallel': ['battery', 'concurrent', 'simultaneous', 'multi-agent', 'dispatch'],
  'multi-agent': ['battery', 'parallel', 'special', 'dispatch'],
  'special': ['battery', 'focus', 'expert', 'parallel'],  // specialized

  // Wiki/Documentation concepts
  'wiki': ['edit', 'author', 'document', 'doc', 'orchestrat'],
  'doc': ['wiki', 'document', 'readme', 'author', 'writ'],
  'document': ['wiki', 'doc', 'author', 'writ', 'edit'],
  'updat': ['edit', 'modif', 'chang', 'wiki'],  // update -> updat
  'page': ['wiki', 'edit', 'document', 'author'],

  // Planning concepts
  'plan': ['writ', 'brainstorm', 'design', 'implement'],
  'think': ['brainstorm', 'plan', 'design', 'innovat'],
  'build': ['brainstorm', 'implement', 'creat', 'featur', 'plan'],
  'featur': ['brainstorm', 'plan', 'implement', 'design'],
  'brainstorm': ['plan', 'think', 'design', 'creat'],

  // Issue tracking
  'ticket': ['issu', 'author', 'edit', 'track'],
  'issu': ['ticket', 'author', 'bug', 'track', 'creat'],
  'track': ['issu', 'ticket', 'author', 'edit', 'verif'],
  'creat': ['author', 'issu', 'new', 'add'],

  // Security
  'secur': ['upgrad', 'vulnerab', 'cve', 'audit', 'scan'],  // security -> secur
  'vulnerab': ['secur', 'cve', 'upgrad', 'audit', 'scan'],  // vulnerability -> vulnerab
  'cve': ['secur', 'vulnerab', 'upgrad', 'scan'],
  'scan': ['secur', 'vulnerab', 'audit', 'cve'],

  // Git concepts
  'branch': ['git', 'worktree', 'merg', 'checkout'],
  'worktree': ['git', 'branch', 'parallel', 'multipl'],
  'commit': ['git', 'pre-commit', 'push', 'merg', 'gate'],
  'merg': ['git', 'branch', 'pr', 'pull'],

  // Stuck/Help
  'stuck': ['think-twic', 'help', 'research', 'perplexit'],
  'help': ['superpower', 'think-twic', 'research', 'find'],
  'research': ['perplexit', 'stuck', 'learn', 'find'],
  'don': ['stuck', 'help', 'think-twic'],  // "don't know" -> don after stemming
  'know': ['stuck', 'help', 'research', 'think-twic'],

  // Output verification / completion concepts
  // stem('verify')='verify', stem('verified')='verifi', stem('verification')='verificat'
  'verify': ['output', 'inspect', 'complete', 'done', 'check', 'gate'],
  'verifi': ['output', 'inspect', 'complete', 'done', 'check', 'gate'],  // verified
  'verificat': ['output', 'inspect', 'complete', 'done', 'check'],  // verification
  'output': ['verify', 'inspect', 'generate', 'artifact', 'result', 'render'],
  'inspect': ['verify', 'output', 'read', 'check', 'render'],
  'render': ['output', 'inspect', 'diagram', 'pdf', 'html', 'chart'],
  'artifact': ['output', 'generate', 'verify', 'file', 'result'],
  // stem('complete')='complete', stem('completed')='complet', stem('completion')='complet'
  'complete': ['verify', 'done', 'finish', 'gate', 'claim'],
  'complet': ['verify', 'done', 'finish', 'gate', 'claim'],  // completed/completion
  'done': ['complet', 'complete', 'verify', 'finish', 'ship', 'gate'],
  'claim': ['verify', 'complete', 'done', 'output'],
  'pdf': ['render', 'output', 'inspect', 'generate', 'artifact'],
  'result': ['output', 'verify', 'inspect', 'artifact', 'check'],
  // stem('generate')='generate', stem('generated')='generat', stem('generating')='generat'
  'generate': ['output', 'artifact', 'creat', 'verify', 'inspect'],
  'generat': ['output', 'artifact', 'creat', 'verify', 'inspect'],  // generated/generating
};

/**
 * Expand query terms with domain-specific synonyms
 */
function expandQueryTerms(terms) {
  const expanded = new Set(terms);
  for (const term of terms) {
    const expansions = CONCEPT_EXPANSIONS[term];
    if (expansions) {
      for (const exp of expansions) {
        expanded.add(exp);
      }
    }
  }
  return Array.from(expanded);
}

/**
 * Semantic intent patterns - maps user intent phrases to skill keywords
 * This is the key to matching "tests failing" → "debugging"
 * Patterns are checked in order; more specific patterns should come first
 */
const INTENT_PATTERNS = [
  // Testing intents (before debugging, so "test first" doesn't match "test fail")
  { patterns: ['write test', 'add test', 'tdd', 'test first', 'tests first', 'test-driven', 'before implementing'],
    skills: ['test-driven-development', 'vitest-testing-patterns'] },

  // Bug report intents (before debugging — "file bug" / "bug report" = issue authoring, not debugging)
  { patterns: ['file bug', 'bug report', 'report bug', 'report a bug', 'submit bug', 'log bug'],
    skills: ['issue-authoring'], boost: 3 },

  // Debugging intents
  { patterns: ['test fail', 'tests fail', 'failing test', 'failing tests', 'test broken', 'flaky test', 'test error'],
    skills: ['systematic-debugging', 'vitest-testing-patterns', 'test-driven-development'] },
  { patterns: ['fail', 'broken', 'not work', "doesn't work", "can't figure", 'error', 'crash', 'wrong'],
    skills: ['systematic-debugging', 'think-twice'] },
  { patterns: ['bug'],
    skills: ['systematic-debugging', 'think-twice'] },

  // Innovation intents (before brainstorming — "radical" signals innovation, not general brainstorm)
  { patterns: ['radical idea', 'radical brainstorm', '10x idea', '10x solution', 'wild idea',
               'moonshot', 'breakthrough idea', 'disruptive', 'unconventional approach',
               'think bigger', 'go big', 'crazy idea'],
    skills: ['innovation'], boost: 5 },

  // Wiki verification intents (before generic wiki — "accuracy"/"verify" signals wiki-verify)
  { patterns: ['check wiki for accuracy', 'verify wiki', 'wiki accuracy', 'wiki accurate',
               'wiki correct', 'wiki claims', 'wiki facts', 'audit wiki', 'wiki outdated',
               'wiki stale', 'wiki wrong', 'check wiki accuracy'],
    skills: ['wiki-verify', 'wiki-content-coherence'], boost: 3 },

  // Design evaluation / phased execution intents (before broad planning)
  { patterns: ['compare design approaches', 'design comparison matrix', 'evaluate design alternatives',
               'design options with adversarial review', 'generate options compare and red team',
               'three design options', 'design triad'],
    skills: ['design-triad'], boost: 3 },
  { patterns: ['plan and execute', 'plan-and-execute', 'plan then execute', 'phased execution',
               'break into phases', 'execute in phases', 'structured execution', 'project plan with phases',
               'plan out this', 'plan out the', 'plan this out', 'plan it out'],
    skills: ['plan-and-execute'], boost: 3 },

  // Strategic decision intents (before planning — more specific)
  { patterns: ["what's the best approach", "where should we put", "which option", "how should this be structured",
               "best location for", "where to store", "which is better",
               "recommend a strategy", "evaluate alternatives", "what would you recommend", "what's the best place"],
    skills: ['thinking-orchestrator', 'design-triad', 'plan-and-execute'] },


  // Quantitative decision gate (before planning — catches 'should I', 'which approach')
  { patterns: ['should i extract', 'should i refactor', 'should i split', 'should i use',
               'deciding between', 'trade-off', 'weighing options', 'which approach',
               'evaluate options', 'score options', 'decision matrix'],
    skills: ['quantitative-decision-gate'], boost: 3 },

  // Failure autopsy (before debugging — catches 'wrong approach', 'misdiagnosed')
  { patterns: ['was wrong', 'that was wrong', 'i was wrong', 'misdiagnosed', 'incorrect assumption',
               'wrong approach', 'wasted time', 'failed approach', 'post-mortem',
               'what went wrong', 'why did that fail'],
    skills: ['failure-autopsy'], boost: 8 },

  // Measurement integrity (before general metrics — catches 'coverage is', 'accuracy is')
  { patterns: ['coverage is', 'accuracy is', 'pass rate', 'score is',
               'percent complete', 'out of', 'metric', 'validate measurement',
               'cross-validate', 'verify the count'],
    skills: ['measurement-integrity'], boost: 3 },

  // TODO guardian (before planning — catches 'handle later', 'come back to')
  { patterns: ['handle later', 'come back to', 'remember to', 'needs follow-up',
               'revisit later', 'defer this', 'stale todo', 'orphaned todo'],
    skills: ['todo-guardian'], boost: 3 },

  // Autonomous chain controller (before general build — catches 'end to end', 'full workflow')
  { patterns: ['end to end', 'full workflow', 'fix and ship', 'build and deploy',
               'implement the full', 'complete lifecycle', 'orchestrate'],
    skills: ['autonomous-chain-controller'], boost: 3 },

  // Evolution loop (before skill-authoring — catches 'improve the skills', 'self-improve')
  { patterns: ['improve the skills', 'self-improve', 'learn from mistakes',
               'skill evolution', 'recurring pattern', 'keeps happening',
               'evolve the system', 'meta-improvement'],
    skills: ['evolution-loop'], boost: 4 },



  // Receiving code review (processing feedback from reviewer)
  { patterns: ['received review', 'review feedback', 'reviewer comments',
               'address review comments', 'reviewer said', 'review findings'],
    skills: ['receiving-code-review'], boost: 5 },

  // Code review request (dispatch/request side)
  { patterns: ['request code review', 'submit for review', 'need review',
               'get this reviewed', 'dispatch review'],
    skills: ['code-review'], boost: 5 },

  // Code review respond (reviewer agent protocol)
  { patterns: ['reviewer agent', 'read request.md', 'reviewer protocol',
               'respond to review request', 'review response'],
    skills: ['code-review-respond'], boost: 6 },

  // Progressive code review gate (commit-time review)
  { patterns: ['code review before commit', 'review my code changes',
               'pre-merge review', 'commit gate review', 'review gate'],
    skills: ['progressive-code-review-gate'], boost: 5 },

  // Progressive harsh review (writing/content review)
  { patterns: ['progressive review', 'red team this', 'content review',
               'writing review', 'review this harshly'],
    skills: ['progressive-harsh-review'], boost: 5 },

  // Micro harsh review (before general review — catches 'review this change')
  { patterns: ['review this change', 'review this code', 'micro review',
               'harsh review this', 'code quality check', 'quick review'],
    skills: ['micro-harsh-review'], boost: 4 },

  // Code change intents (before planning — any code change triggers feature-development)
  { patterns: ['code change', 'modify code', 'write code', 'update code', 'change code',
               'fix this', 'add this', 'refactor this', 'make changes',
               'start feature', 'full development workflow', 'feature development'],
    skills: ['feature-development', 'brainstorming', 'design-triad'], boost: 2 },

  // Design evaluation / phased execution intents (before broad planning)
  { patterns: ['compare design approaches', 'design comparison matrix', 'evaluate design alternatives',
               'design options with adversarial review', 'generate options compare and red team',
               'three design options', 'design triad'],
    skills: ['design-triad'], boost: 3 },
  { patterns: ['plan and execute', 'plan-and-execute', 'plan then execute', 'phased execution',
               'break into phases', 'execute in phases', 'structured execution', 'project plan with phases'],
    skills: ['plan-and-execute'], boost: 3 },

  // Strategic decision intents (before planning — more specific)
  { patterns: ["what's the best approach", "where should we put", "which option", "how should this be structured",
               "best location for", "where to store", "which is better",
               "recommend a strategy", "evaluate alternatives", "what would you recommend", "what's the best place"],
    skills: ['thinking-orchestrator', 'design-triad', 'plan-and-execute'] },

  // Planning intents
  { patterns: ['brainstorm', 'think about', 'figure out how', 'plan how'],
    skills: ['brainstorming', 'writing-plans'] },
  { patterns: ['build', 'create', 'implement', 'add feature', 'new feature', 'develop'],
    skills: ['feature-development', 'brainstorming', 'writing-plans', 'test-driven-development'] },
  { patterns: ['plan', 'design', 'how to'],
    skills: ['brainstorming', 'writing-plans', 'innovation'] },

  // README intents (before generic documentation)
  { patterns: ['write readme', 'write a readme', 'readme', 'read me'],
    skills: ['readme-authoring'], boost: 3 },

  // Web search intents (before generic planning)
  { patterns: ['search the web', 'search online', 'look up', 'web search',
               'research online', 'find information', 'best practices'],
    skills: ['perplexity-research'], boost: 3 },

  // Wiki writing intents (before generic wiki — "write wiki page" = wiki-editing, not orchestrator)
  { patterns: ['write wiki', 'write a wiki', 'create wiki page', 'new wiki page', 'draft wiki'],
    skills: ['wiki-editing', 'wiki-authoring'], boost: 3 },

  // Documentation intents
  { patterns: ['wiki', 'document', 'docs', 'write doc', 'update page', 'edit page'],
    skills: ['wiki-editing', 'wiki-authoring', 'wiki-orchestrator'] },

  // Code review battery intents (before general code review — catch "battery" explicitly)
  { patterns: ['battery review', 'run the battery', 'parallel review', 'parallel code review',
               'specialized review', 'multi-agent review', 'review battery',
               'run all reviewers', 'five reviewer', 'five-agent review'],
    skills: ['code-review-battery'], boost: 3 },

  // Code review intents (before general "review" to catch "code review" specifically)
  { patterns: ['code review', 'pull request', 'pr review', 'review pr', 'review pull'],
    skills: ['providing-code-review', 'requesting-code-review', 'receiving-code-review'] },

  // Resume/CV review intents (before general "review")
  { patterns: ['resume', 'cv', 'candidate', 'screen candidate', 'review candidate', 'phone screen'],
    skills: ['cv-review-external', 'cv-review-agency', 'resume-screening', 'phone-screen-prep'] },

  // General review (less specific)
  { patterns: ['review'],
    skills: ['providing-code-review', 'requesting-code-review'] },

  // Core Boards intents (authoring before reading — more specific first)
  { patterns: ['announce this wiki', 'post to core', 'promote this document', 'internal announcement', 'publish to core', 'core board announcement'],
    skills: ['core-boards'] },
  { patterns: ['unread board', 'action feed', 'board digest', 'catch me up', 'callout', "what's new on core", 'summarize board', 'search board', 'core boards'],
    skills: ['core-boards-reader'] },

  // Skill health intents (before issue tracking — "skill files" / "skill issues" = health check)
  { patterns: ['skill file', 'skill files', 'check skill', 'skill issue', 'skill health', 'skill lint'],
    skills: ['skill-health-check'], boost: 3 },

  // Security intents (before issue tracking — "security issues" = security, not issues)
  { patterns: ['security issue', 'security vulnerab', 'security', 'vulnerab', 'cve', 'audit',
               'scan depend', 'dependency'],
    skills: ['security-upgrade', 'public-repo-ip-audit'] },

  // Issue tracking intents
  { patterns: ['ticket', 'create issue', 'file bug', 'open issue'],
    skills: ['issue-authoring', 'issue-editing'] },
  { patterns: ['issue tracker', 'issue'],
    skills: ['issue-authoring', 'issue-editing'] },

  // Help/Stuck intents
  { patterns: ["don't know", "dont know", 'stuck', 'confused', 'unclear', 'not sure', 'help me'],
    skills: ['think-twice', 'perplexity-research', 'superpowers-help'] },

  // Output verification / completion intents (before git — catch "done" before "commit")
  { patterns: ['verify output', 'inspect output', 'read output', 'check output',
               'describe generated', 'review generated', 'inspect artifact',
               'verify rendered', 'check pdf', 'check html',
               'ready to share', 'ready to hand off', 'ready to deliver',
               'output looks good', 'rendered correctly', 'diagrams look correct'],
    skills: ['output-verification', 'verification-before-completion'], boost: 3 },
  { patterns: ['done', 'finished', 'complete', 'shipped', 'all set',
               'claiming done', 'mark as done', 'work complete',
               'before marking done', 'verified the output'],
    skills: ['verification-before-completion', 'output-verification'] },

  // Git intents
  { patterns: ['multiple branch', 'work on branch', 'parallel branch', 'worktree', 'branches at once'],
    skills: ['using-git-worktrees', 'finishing-a-development-branch'] },
  { patterns: ['commit', 'push', 'before commit', 'pre-commit'],
    skills: ['pre-commit-gate', 'engineering-rigor'] },
];

function buildIntentBoosts(queryLower) {
  const intentBoosts = {};
  for (const intent of INTENT_PATTERNS) {
    const boost = intent.boost || 1.5;
    for (const pattern of intent.patterns) {
      if (queryLower.includes(pattern)) {
        for (const skillName of intent.skills) {
          // Store boost for both prefixed and unprefixed versions
          intentBoosts[skillName] = (intentBoosts[skillName] || 0) + boost;
          intentBoosts[`superpowers:${skillName}`] = (intentBoosts[`superpowers:${skillName}`] || 0) + boost;
        }
      }
    }
  }
  return intentBoosts;
}

function applyHeuristicBoosts(results, skills, queryLower, rawTerms) {
  const intentBoosts = buildIntentBoosts(queryLower);
  const skillMap = new Map(skills.map(skill => [skill.name, skill]));

  // Apply boosts
  for (const result of results) {
    const skill = skillMap.get(result.name);
    if (!skill) continue;
    // Get the base name without prefix for matching
    const baseName = result.name.replace(/^superpowers:/, '');

    // Intent pattern boost (strongest signal) - check both prefixed and unprefixed
    const boost = intentBoosts[result.name] || intentBoosts[baseName] || 0;
    if (boost > 0) {
      result.score += boost;
    }

    // Exact name match boost
    if (skill.name.toLowerCase().includes(queryLower) ||
        queryLower.includes(skill.name.toLowerCase().replace(/-/g, ' '))) {
      result.score += 0.5;
    }

    // Trigger phrase match boost (take best match only)
    if (skill.triggers) {
      let bestTriggerBoost = 0;
      for (const trigger of skill.triggers) {
        if (queryLower.includes(trigger.toLowerCase())) {
          // Full match - this is the best possible
          bestTriggerBoost = 1.2;
          break;
        }
        // Partial trigger match
        const triggerWords = trigger.toLowerCase().split(/\s+/);
        const matchCount = triggerWords.filter(w => queryLower.includes(w)).length;
        if (matchCount >= 2 || (matchCount === 1 && triggerWords.length === 1)) {
          const partialBoost = 0.6 * (matchCount / triggerWords.length);
          if (partialBoost > bestTriggerBoost) {
            bestTriggerBoost = partialBoost;
          }
        }
      }
      if (bestTriggerBoost > 0) {
        result.score += bestTriggerBoost;
      }
    }

    // Skill name word match boost
    const nameWords = skill.name.toLowerCase().replace(/-/g, ' ').split(/\s+/);
    for (const word of nameWords) {
      if (queryLower.includes(word) && word.length > 3) {
        result.score += 0.3;
      }
    }

    // Description keyword match boost
    if (skill.description) {
      const descLower = skill.description.toLowerCase();
      for (const term of rawTerms) {
        if (descLower.includes(term)) {
          result.score += 0.2;
        }
      }
    }
  }

  return results;
}

/**
 * Match skills using hybrid TF-IDF + intent patterns (fast, offline)
 */
function matchSkillsTfIdf(query, skills, topN = 5) {
  const index = buildTfIdfIndex(skills);
  const rawTerms = tokenize(query).filter(t => !STOP_WORDS.has(t));
  const queryTerms = expandQueryTerms(rawTerms);
  const queryLower = query.toLowerCase();

  const results = index.documents.map(doc => ({
    name: doc.skill.name,
    description: doc.skill.description || '',
    isSuperpower: doc.skill.isSuperpower,
    score: tfidfSimilarity(queryTerms, doc, index.df, index.N)
  }));

  applyHeuristicBoosts(results, skills, queryLower, rawTerms);

  results.sort((a, b) => b.score - a.score);
  return results.slice(0, topN);
}

// ============================================================================
// OpenAI Embeddings (Optional - Enhanced Accuracy)
// ============================================================================

const EMBEDDING_MODEL = 'text-embedding-3-small';

/**
 * Check if OpenAI API is available
 */
function hasOpenAiKey() {
  return !!process.env.OPENAI_API_KEY;
}

/**
 * Read cached embeddings
 */
function readCache() {
  if (!fs.existsSync(EMBEDDINGS_CACHE_PATH)) {
    return { version: '2.0.0', embeddings: {}, last_updated: null };
  }
  try {
    return JSON.parse(fs.readFileSync(EMBEDDINGS_CACHE_PATH, 'utf8'));
  } catch (e) {
    return { version: '2.0.0', embeddings: {}, last_updated: null };
  }
}

/**
 * Write embeddings cache
 */
function writeCache(cache) {
  const dir = path.dirname(EMBEDDINGS_CACHE_PATH);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
  cache.last_updated = new Date().toISOString();
  fs.writeFileSync(EMBEDDINGS_CACHE_PATH, JSON.stringify(cache, null, 2));
}

/**
 * Generate embedding using OpenAI API
 */
async function getEmbedding(text) {
  const apiKey = process.env.OPENAI_API_KEY;
  const response = await fetch('https://api.openai.com/v1/embeddings', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ model: EMBEDDING_MODEL, input: text })
  });

  if (!response.ok) {
    throw new Error(`OpenAI API error: ${response.status}`);
  }

  const data = await response.json();
  if (!data.data || !data.data[0] || !data.data[0].embedding) {
    throw new Error(`OpenAI API returned unexpected response: missing embedding data`);
  }
  return data.data[0].embedding;
}

/**
 * Calculate cosine similarity between two vectors
 */
function cosineSimilarity(a, b) {
  let dot = 0, normA = 0, normB = 0;
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  return dot / (Math.sqrt(normA) * Math.sqrt(normB));
}

/**
 * Embed all skills (with caching)
 */
async function embedSkills(skills, forceRefresh = false) {
  if (!hasOpenAiKey()) {
    throw new Error('OPENAI_API_KEY not set. Use TF-IDF mode instead.');
  }

  const cache = readCache();
  let updated = false;

  for (const skill of skills) {
    const text = buildSkillText(skill);
    const textHash = Buffer.from(text).toString('base64').slice(0, 32);

    if (!forceRefresh && cache.embeddings[skill.name]?.textHash === textHash) {
      continue;
    }

    console.log(`Embedding: ${skill.name}...`);
    cache.embeddings[skill.name] = {
      name: skill.name,
      description: skill.description || '',
      isSuperpower: skill.isSuperpower,
      textHash,
      embedding: await getEmbedding(text)
    };
    updated = true;
    await new Promise(r => setTimeout(r, 100));
  }

  if (updated) writeCache(cache);
  return cache;
}

/**
 * Match skills using OpenAI embeddings
 */
async function matchSkillsEmbedding(query, skills, topN = 5) {
  const cache = await embedSkills(skills);
  const queryEmbedding = await getEmbedding(query);
  const rawTerms = tokenize(query).filter(t => !STOP_WORDS.has(t));
  const queryLower = query.toLowerCase();
  const skillNames = new Set(skills.map(skill => skill.name));

  const results = Object.entries(cache.embeddings)
    .filter(([name]) => skillNames.has(name))
    .map(([name, data]) => ({
    name,
    description: data.description,
    isSuperpower: data.isSuperpower,
    score: cosineSimilarity(queryEmbedding, data.embedding)
    }));

  applyHeuristicBoosts(results, skills, queryLower, rawTerms);
  results.sort((a, b) => b.score - a.score);
  return results.slice(0, topN);
}

// ============================================================================
// Unified Interface
// ============================================================================

/**
 * Match skills using best available method
 *
 * @param {string} query - User's natural language query
 * @param {Array} skills - Array of skill objects
 * @param {Object} options - Configuration options
 * @param {number} options.topN - Number of results to return (default: 5)
 * @param {string} options.method - Force method: 'tfidf', 'embedding', or 'auto'
 * @returns {Promise<Array>} Ranked skill matches with scores
 */
async function matchSkills(query, skills, options = {}) {
  const { topN = 5, method = 'auto' } = options;

  // Determine which method to use
  let useMethod = method;
  if (method === 'auto') {
    useMethod = hasOpenAiKey() ? 'embedding' : 'tfidf';
  }

  if (useMethod === 'embedding') {
    if (!hasOpenAiKey()) {
      console.log('⚠️  OPENAI_API_KEY not set, falling back to TF-IDF');
      useMethod = 'tfidf';
    }
  }

  // Execute matching
  if (useMethod === 'embedding') {
    return matchSkillsEmbedding(query, skills, topN);
  } else {
    return matchSkillsTfIdf(query, skills, topN);
  }
}

/**
 * Get information about available matching methods
 */
function getRouterInfo() {
  return {
    tfidf: { available: true, description: 'Fast offline matching (no API required)' },
    embedding: {
      available: hasOpenAiKey(),
      description: 'OpenAI embeddings (optional, set OPENAI_API_KEY)'
    },
    default: hasOpenAiKey() ? 'embedding' : 'tfidf'
  };
}

// ============================================================================
// Skill Auto-Composition Engine (RFC-001)
// ============================================================================

/**
 * Parse composition metadata from skill frontmatter
 * @param {Object} skill - Skill object with parsed YAML frontmatter
 * @returns {Object|null} Composition metadata or null if not defined
 */
function getComposition(skill) {
  if (!skill.composition) return null;
  return {
    produces: skill.composition.produces || [],
    consumes: skill.composition.consumes || [],
    capabilities: skill.composition.capabilities || [],
    priority: skill.composition.priority ?? 50,
    optional: skill.composition.optional ?? false,
    requires_all: skill.composition.requires_all ?? false
  };
}

/**
 * Find all skills that produce a specific artifact
 * @param {Array} skills - Array of skill objects with composition metadata
 * @param {string} artifact - The artifact name to find producers for
 * @returns {Array} Skills that produce this artifact, sorted by priority
 */
function findProducers(skills, artifact) {
  return skills
    .filter(s => {
      const comp = getComposition(s);
      return comp && comp.produces.includes(artifact);
    })
    .sort((a, b) => {
      const compA = getComposition(a);
      const compB = getComposition(b);
      return (compA?.priority ?? 50) - (compB?.priority ?? 50);
    });
}

/**
 * Find a skill that has a specific capability
 * @param {Array} skills - Array of skill objects
 * @param {string} capability - The capability to find
 * @returns {Object|null} The skill with lowest priority that has this capability
 */
function findSkillWithCapability(skills, capability) {
  const matches = skills
    .filter(s => {
      const comp = getComposition(s);
      return comp && comp.capabilities.includes(capability);
    })
    .sort((a, b) => {
      const compA = getComposition(a);
      const compB = getComposition(b);
      return (compA?.priority ?? 50) - (compB?.priority ?? 50);
    });
  return matches[0] || null;
}

/**
 * Build an execution pipeline for a target capability
 *
 * Algorithm:
 * 1. Find the skill that provides the target capability
 * 2. Recursively resolve dependencies (consumed artifacts)
 * 3. Sort by priority for stable ordering
 * 4. Detect cycles via visited set
 *
 * @param {string} targetCapability - The capability we want (e.g., 'publishes-wiki')
 * @param {Array} skills - All available skills with composition metadata
 * @param {Array} availableArtifacts - Artifacts already available (default: ['user-intent'])
 * @param {Object} options - Configuration options
 * @param {boolean} options.explain - If true, return explanation instead of just pipeline
 * @returns {Object} { pipeline: Array, produced: Set, explanation: Array }
 */
function buildPipeline(targetCapability, skills, availableArtifacts = ['user-intent'], options = {}) {
  const pipeline = [];
  const produced = new Set(availableArtifacts);
  const visited = new Set();
  const explanation = [];

  // Filter to only skills with composition metadata
  const composableSkills = skills.filter(s => getComposition(s) !== null);

  if (composableSkills.length === 0) {
    return {
      pipeline: [],
      produced,
      explanation: ['No skills with composition metadata found'],
      error: 'NO_COMPOSABLE_SKILLS'
    };
  }

  // Find the target skill
  const targetSkill = findSkillWithCapability(composableSkills, targetCapability);
  if (!targetSkill) {
    return {
      pipeline: [],
      produced,
      explanation: [`No skill provides capability: ${targetCapability}`],
      error: 'CAPABILITY_NOT_FOUND'
    };
  }

  explanation.push(`Target: ${targetSkill.name} (capability: ${targetCapability})`);

  /**
   * Recursively resolve a skill's dependencies
   */
  function resolve(skill) {
    const skillName = skill.name;

    // Cycle detection
    if (visited.has(skillName)) {
      explanation.push(`  [SKIP] ${skillName} (already visited - cycle prevention)`);
      return true;
    }
    visited.add(skillName);

    const comp = getComposition(skill);
    if (!comp) {
      explanation.push(`  [SKIP] ${skillName} (no composition metadata)`);
      return false;
    }

    // Check which consumed artifacts are missing
    const missing = comp.consumes.filter(a => !produced.has(a));

    if (missing.length > 0) {
      explanation.push(`  ${skillName} needs: [${missing.join(', ')}]`);

      // For each missing artifact, find a producer and resolve it first
      for (const artifact of missing) {
        const producers = findProducers(composableSkills, artifact);

        if (producers.length === 0) {
          if (comp.optional) {
            explanation.push(`    [SKIP] No producer for ${artifact}, but ${skillName} is optional`);
            return false; // Skip this optional skill
          } else {
            explanation.push(`    [ERROR] No skill produces: ${artifact}`);
            return false;
          }
        }

        // Use the highest priority (lowest number) producer
        const producer = producers[0];
        explanation.push(`    → ${producer.name} produces ${artifact}`);

        if (!resolve(producer)) {
          if (comp.optional) {
            explanation.push(`    [SKIP] ${skillName} is optional and dependency failed`);
            return false;
          }
        }
      }
    }

    // Check if requires_all is satisfied
    if (comp.requires_all) {
      const stillMissing = comp.consumes.filter(a => !produced.has(a));
      if (stillMissing.length > 0) {
        explanation.push(`  [BLOCKED] ${skillName} requires ALL of: [${comp.consumes.join(', ')}], missing: [${stillMissing.join(', ')}]`);
        return false;
      }
    }

    // Add this skill to pipeline
    pipeline.push(skill);
    explanation.push(`  [ADD] ${skillName} (priority: ${comp.priority})`);

    // Mark its outputs as available
    for (const artifact of comp.produces) {
      produced.add(artifact);
      explanation.push(`    ✓ produces: ${artifact}`);
    }

    return true;
  }

  // Start resolution from target skill
  resolve(targetSkill);

  // Sort pipeline by priority for deterministic ordering
  pipeline.sort((a, b) => {
    const compA = getComposition(a);
    const compB = getComposition(b);
    return (compA?.priority ?? 50) - (compB?.priority ?? 50);
  });

  explanation.push('');
  explanation.push('Final pipeline order:');
  pipeline.forEach((s, i) => {
    const comp = getComposition(s);
    explanation.push(`  ${i + 1}. ${s.name} (priority: ${comp?.priority})`);
  });

  return {
    pipeline,
    produced,
    explanation,
    error: null
  };
}

/**
 * Format pipeline as Mermaid diagram
 * @param {Array} pipeline - Array of skills in execution order
 * @returns {string} Mermaid flowchart syntax
 */
function pipelineToMermaid(pipeline) {
  if (pipeline.length === 0) return 'graph LR\n  empty[No pipeline]';

  const lines = ['graph LR'];
  for (let i = 0; i < pipeline.length; i++) {
    const skill = pipeline[i];
    const comp = getComposition(skill);
    const label = `${skill.name}`;

    if (i === 0) {
      lines.push(`  user-intent([user-intent]) --> ${skill.name}[${label}]`);
    }

    if (i < pipeline.length - 1) {
      const next = pipeline[i + 1];
      // Find the artifact that connects them
      const artifacts = comp?.produces || [];
      const nextComp = getComposition(next);
      const consumed = nextComp?.consumes || [];
      const connection = artifacts.filter(a => consumed.includes(a))[0] || '';
      lines.push(`  ${skill.name} -->|${connection}| ${next.name}[${next.name}]`);
    } else {
      // Last skill - show output
      const outputs = comp?.produces || [];
      if (outputs.length > 0) {
        lines.push(`  ${skill.name} --> ${outputs[0]}([${outputs[0]}])`);
      }
    }
  }

  return lines.join('\n');
}

/**
 * Explain a pipeline without executing (--explain flag support)
 * @param {string} targetCapability - The capability we want
 * @param {Array} skills - All available skills
 * @param {Array} availableArtifacts - Starting artifacts
 * @returns {string} Human-readable explanation
 */
function explainPipeline(targetCapability, skills, availableArtifacts = ['user-intent']) {
  const result = buildPipeline(targetCapability, skills, availableArtifacts, { explain: true });

  const output = [];
  output.push('=== Skill Auto-Composition Engine ===');
  output.push(`Target capability: ${targetCapability}`);
  output.push(`Available artifacts: [${availableArtifacts.join(', ')}]`);
  output.push('');
  output.push('Resolution trace:');
  output.push(result.explanation.join('\n'));
  output.push('');

  if (result.error) {
    output.push(`Error: ${result.error}`);
  } else {
    output.push('Mermaid diagram:');
    output.push('```mermaid');
    output.push(pipelineToMermaid(result.pipeline));
    output.push('```');
  }

  return output.join('\n');
}

module.exports = {
  // Primary API
  matchSkills,
  getRouterInfo,

  // TF-IDF specific
  matchSkillsTfIdf,
  buildTfIdfIndex,

  // Embedding specific (optional)
  matchSkillsEmbedding,
  embedSkills,
  hasOpenAiKey,

  // Auto-Composition Engine (RFC-001)
  buildPipeline,
  explainPipeline,
  pipelineToMermaid,
  getComposition,
  findProducers,
  findSkillWithCapability,

  // Utilities
  buildSkillText,
  tokenize,
  buildIntentBoosts,
  applyHeuristicBoosts,
  cosineSimilarity,
  readCache,
  writeCache,
  EMBEDDINGS_CACHE_PATH,

  // For debugging
  INTENT_PATTERNS,
  stem
};
