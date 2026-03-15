/**
 * Semantic Skill Router
 * 
 * Uses OpenAI embeddings to match user queries to skills based on semantic
 * similarity rather than static trigger phrase matching.
 * 
 * Features:
 * - Embeds skill descriptions + triggers at initialization
 * - Caches embeddings to avoid repeated API calls
 * - Returns top-N matches with cosine similarity scores
 * 
 * Location: lib/skill-router.js
 * Cache: ~/.codex/.skill-embeddings.json
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

const EMBEDDINGS_CACHE_PATH = path.join(os.homedir(), '.codex', '.skill-embeddings.json');
const EMBEDDING_MODEL = 'text-embedding-3-small';

/**
 * Get OpenAI API key from environment
 */
function getApiKey() {
  const key = process.env.OPENAI_API_KEY;
  if (!key) {
    throw new Error('OPENAI_API_KEY environment variable not set');
  }
  return key;
}

/**
 * Read cached embeddings
 */
function readCache() {
  if (!fs.existsSync(EMBEDDINGS_CACHE_PATH)) {
    return { version: '1.0.0', embeddings: {}, last_updated: null };
  }
  try {
    return JSON.parse(fs.readFileSync(EMBEDDINGS_CACHE_PATH, 'utf8'));
  } catch (e) {
    console.error('Warning: corrupted embeddings cache, resetting');
    return { version: '1.0.0', embeddings: {}, last_updated: null };
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
 * Generate embedding for text using OpenAI API
 */
async function getEmbedding(text, apiKey) {
  const response = await fetch('https://api.openai.com/v1/embeddings', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      model: EMBEDDING_MODEL,
      input: text
    })
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`OpenAI API error: ${response.status} - ${error}`);
  }

  const data = await response.json();
  return data.data[0].embedding;
}

/**
 * Calculate cosine similarity between two vectors
 */
function cosineSimilarity(a, b) {
  if (a.length !== b.length) throw new Error('Vector length mismatch');
  let dot = 0, normA = 0, normB = 0;
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  return dot / (Math.sqrt(normA) * Math.sqrt(normB));
}

/**
 * Build embedding text for a skill (description + triggers)
 */
function buildSkillText(skill) {
  const parts = [skill.name];
  if (skill.description) parts.push(skill.description);
  if (skill.triggers && skill.triggers.length > 0) {
    parts.push('Triggers: ' + skill.triggers.join(', '));
  }
  return parts.join('. ');
}

/**
 * Embed all skills (with caching)
 */
async function embedSkills(skills, forceRefresh = false) {
  const apiKey = getApiKey();
  const cache = readCache();
  let updated = false;

  for (const skill of skills) {
    const key = skill.name;
    const text = buildSkillText(skill);
    const textHash = Buffer.from(text).toString('base64').slice(0, 32);

    // Skip if cached and text hasn't changed
    if (!forceRefresh && cache.embeddings[key] && cache.embeddings[key].textHash === textHash) {
      continue;
    }

    console.log(`Embedding: ${skill.name}...`);
    const embedding = await getEmbedding(text, apiKey);
    cache.embeddings[key] = {
      name: skill.name,
      description: skill.description || '',
      isSuperpower: skill.isSuperpower,
      textHash,
      embedding
    };
    updated = true;

    // Rate limit: small delay between requests
    await new Promise(r => setTimeout(r, 100));
  }

  if (updated) {
    writeCache(cache);
  }

  return cache;
}

/**
 * Match a query to skills, returning top-N matches with scores
 */
async function matchSkills(query, skills, topN = 3) {
  const apiKey = getApiKey();
  const cache = await embedSkills(skills);

  // Get query embedding
  const queryEmbedding = await getEmbedding(query, apiKey);

  // Calculate similarity to all skills
  const results = [];
  for (const [name, data] of Object.entries(cache.embeddings)) {
    const similarity = cosineSimilarity(queryEmbedding, data.embedding);
    results.push({
      name,
      description: data.description,
      isSuperpower: data.isSuperpower,
      score: similarity
    });
  }

  // Sort by similarity (descending) and return top-N
  results.sort((a, b) => b.score - a.score);
  return results.slice(0, topN);
}

module.exports = {
  matchSkills,
  embedSkills,
  getEmbedding,
  cosineSimilarity,
  buildSkillText,
  readCache,
  writeCache,
  EMBEDDINGS_CACHE_PATH
};
