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
  'review': ['code-review', 'pr', 'provid', 'receiv', 'feedback'],  // provid=providing, receiv=receiving
  'pr': ['pull-request', 'code-review', 'review', 'merg'],
  'pull': ['pull-request', 'code-review', 'pr', 'merg', 'request'],
  'request': ['pull', 'pr', 'code-review', 'merg'],

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
  'ticket': ['issu', 'linear', 'author', 'edit'],
  'issu': ['ticket', 'linear', 'author', 'bug', 'track'],
  'linear': ['issu', 'ticket', 'author', 'edit', 'verif'],
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

  // Debugging intents
  { patterns: ['test fail', 'tests fail', 'failing test', 'failing tests', 'test broken', 'flaky test', 'test error'],
    skills: ['systematic-debugging', 'vitest-testing-patterns', 'test-driven-development'] },
  { patterns: ['fail', 'broken', 'not work', "doesn't work", "can't figure", 'bug', 'error', 'crash', 'wrong'],
    skills: ['systematic-debugging', 'think-twice'] },

  // Planning intents
  { patterns: ['brainstorm', 'think about', 'figure out how', 'plan how'],
    skills: ['brainstorming', 'writing-plans'] },
  { patterns: ['build', 'create', 'implement', 'add feature', 'new feature', 'develop'],
    skills: ['brainstorming', 'writing-plans', 'test-driven-development'] },
  { patterns: ['plan', 'design', 'how to'],
    skills: ['brainstorming', 'writing-plans', 'innovation'] },

  // Documentation intents
  { patterns: ['wiki', 'document', 'docs', 'write doc', 'update page', 'edit page'],
    skills: ['wiki-editing', 'wiki-authoring', 'wiki-orchestrator'] },

  // Code review intents (before general "review" to catch "code review" specifically)
  { patterns: ['code review', 'pull request', 'pr review', 'review pr', 'review pull'],
    skills: ['providing-code-review', 'requesting-code-review', 'receiving-code-review'] },

  // Resume/CV review intents (before general "review")
  { patterns: ['resume', 'cv', 'candidate', 'screen candidate', 'review candidate', 'phone screen'],
    skills: ['cv-review-external', 'cv-review-agency', 'resume-screening', 'phone-screen-prep'] },

  // General review (less specific)
  { patterns: ['review'],
    skills: ['providing-code-review', 'requesting-code-review'] },

  // Issue tracking intents
  { patterns: ['ticket', 'linear issue', 'create issue', 'file bug', 'open issue'],
    skills: ['linear-issue-authoring', 'issue-authoring', 'issue-editing'] },
  { patterns: ['linear', 'issue'],
    skills: ['issue-authoring', 'issue-editing', 'linear-issue-authoring'] },

  // Security intents
  { patterns: ['security', 'vulnerab', 'cve', 'audit', 'scan depend', 'dependency'],
    skills: ['security-upgrade', 'public-repo-ip-audit'] },

  // Help/Stuck intents
  { patterns: ["don't know", "dont know", 'stuck', 'confused', 'unclear', 'not sure', 'help me'],
    skills: ['think-twice', 'perplexity-research', 'superpowers-help'] },

  // Git intents
  { patterns: ['multiple branch', 'work on branch', 'parallel branch', 'worktree', 'branches at once'],
    skills: ['using-git-worktrees', 'finishing-a-development-branch'] },
  { patterns: ['commit', 'push', 'before commit', 'pre-commit'],
    skills: ['pre-commit-gate', 'engineering-rigor'] },
];

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

  // Apply intent pattern matching (most important for semantic accuracy)
  const intentBoosts = {};
  for (const intent of INTENT_PATTERNS) {
    for (const pattern of intent.patterns) {
      if (queryLower.includes(pattern)) {
        for (const skillName of intent.skills) {
          // Store boost for both prefixed and unprefixed versions
          intentBoosts[skillName] = (intentBoosts[skillName] || 0) + 1.5;
          intentBoosts[`superpowers:${skillName}`] = (intentBoosts[`superpowers:${skillName}`] || 0) + 1.5;
        }
      }
    }
  }

  // Apply boosts
  for (const result of results) {
    const skill = skills.find(s => s.name === result.name);
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

  const results = Object.entries(cache.embeddings).map(([name, data]) => ({
    name,
    description: data.description,
    isSuperpower: data.isSuperpower,
    score: cosineSimilarity(queryEmbedding, data.embedding)
  }));

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
  cosineSimilarity,
  readCache,
  writeCache,
  EMBEDDINGS_CACHE_PATH,

  // For debugging
  INTENT_PATTERNS,
  stem
};
