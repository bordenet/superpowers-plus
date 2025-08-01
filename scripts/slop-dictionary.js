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
 */

const fs = require('fs');
const path = require('path');

const DICTIONARY_FILE = path.join(process.cwd(), '.slop-dictionary.json');

const CATEGORIES = [
  'generic-booster',
  'buzzword', 
  'filler-phrase',
  'hedge-pattern',
  'sycophantic-phrase',
  'transitional-filler'
];

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
  default:
    console.log('Usage: node slop-dictionary.js <command> [args]');
    console.log('\nCommands:');
    console.log('  add <phrase> <category>  Add pattern to dictionary');
    console.log('  except <phrase> [scope]  Add exception (default: permanent)');
    console.log('  remove <phrase>          Remove pattern from dictionary');
    console.log('  list [category]          List patterns (optionally by category)');
    console.log('  exceptions               List all exceptions');
    console.log('  top [n]                  Show top N patterns by count');
    console.log('\nCategories:', CATEGORIES.join(', '));
}

