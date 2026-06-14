#!/usr/bin/env node
// language-scanner.js -- HARD-GATE profanity scanner for wiki content and docs.
// Exit codes (stable contract -- callers depend on these):
//   0  PASS  no profanity found
//   1  BLOCK profanity found (per-finding output on stderr)
//   2  USAGE/IO error (missing arg, unreadable file, multi-file invocation)
// Any other non-zero (e.g. 127 from missing node) MUST be treated as ABORT by
// the caller -- NEVER as PASS. See outline-wiki-editing Rule 6.

const fs = require('fs');

// Word-stem patterns: F-word / S-word / damn drop the leading \b so word-prefixed
// forms (motherfucker, clusterfuck, batshit, godamnit, absofuckinglutely) are caught.
// Ass-word and Hell KEEP \b because dropping it false-positives on class/pass/asset
// and hello/Mitchell/shellfish respectively.
const PROFANITY_PATTERNS = [
  { name: 'F-word family', regex: /f[fuU*0o.\-_~1!\t]+ck\w*/gi, severity: 'BLOCK', suggestion: '"broken", "frustrating", "unacceptable", "nightmare"' },
  { name: 'F-word phonetic (ph-)', regex: /\bph[uo0]+ck\w*/gi, severity: 'BLOCK', suggestion: 'rewrite without phonetic spelling' },
  { name: 'S-word family', regex: /sh[i1!*._\-~0\t]+t\w*/gi, severity: 'BLOCK', suggestion: '"garbage", "unacceptable", "non-functional"' },
  { name: 'Crude scatological', regex: /\b(crap|piss)\w*/gi, severity: 'BLOCK', suggestion: '"trash" / "broken"; "annoyed" / "irritated"' },
  { name: 'Explicit vulgarity (compound forms)', regex: /\b(cunt\w*|cocksuck\w*|dickhead\w*|dickwad\w*|cockblock\w*)\b/gi, severity: 'BLOCK', suggestion: 'rewrite without explicit terms' },
  { name: 'Ass-word (whole word)', regex: /\bass(es|hole\w*|hat\w*|wipe\w*)?\b/gi, severity: 'BLOCK', suggestion: '"jerk", "fool", or rephrase' },
  { name: 'Compound ass-word', regex: /\b(?:dumb|jack|kick|hard|fat|lard|smart|wise|kiss|bad|nice|fine|tight)ass(?:hole\w*|es|hat\w*)?\b/gi, severity: 'BLOCK', suggestion: 'rephrase without the compound' },
  { name: 'Gendered slur', regex: /\b(bitch|bastard|whore|slut)\w*/gi, severity: 'BLOCK', suggestion: 'rewrite without gendered slur' },
  { name: 'Religious profanity', regex: /damn\w*|goddamn\w*|\bjesus christ\b/gi, severity: 'BLOCK', suggestion: '"broken", "unacceptable"; drop the exclamation' },
  { name: 'Hell (standalone)', regex: /\bhell\b/gi, severity: 'BLOCK', suggestion: '"nightmare", "disaster", "extreme"; or drop the word' },
  { name: 'Internet shorthand profanity', regex: /\b(wtf|stfu|lmfao|gtfo)\b/gi, severity: 'BLOCK', suggestion: 'use plain language instead of shorthand' },
];

// NOTE on intentional omissions: bare `cock`, `dick`, `tits`, `boobs` are NOT in
// the pattern list. They false-positive on cockpit / peacock / Dickens / Dickson /
// titanic / book / boost in real wiki content (aviation, biographies). The
// explicit compound forms (cocksucker, dickhead, dickwad, cockblock) ARE caught.

// Cyrillic-to-Latin homoglyph table -- common ASCII-lookalike letters used to
// evade profanity scanners by typing visually identical Cyrillic characters.
const CYRILLIC_HOMOGLYPHS = {
  'а': 'a', 'А': 'A', 'е': 'e', 'Е': 'E', 'о': 'o', 'О': 'O',
  'р': 'p', 'Р': 'P', 'с': 'c', 'С': 'C', 'у': 'y', 'У': 'Y',
  'х': 'x', 'Х': 'X', 'і': 'i', 'І': 'I', 'ј': 'j', 'Ј': 'J',
  'ѕ': 's', 'Ѕ': 'S', 'к': 'k', 'К': 'K', 'т': 't', 'Т': 'T',
  'в': 'B', 'м': 'M', 'н': 'H'
};
const CYRILLIC_REGEX = new RegExp('[' + Object.keys(CYRILLIC_HOMOGLYPHS).join('') + ']', 'g');

// Allowlist marker spans -- the ONLY way to reference profanity in a doc that
// passes the gate. The marker keyword must match this whitelist; an optional
// body (after ': ' or whitespace) is permitted but is itself scanned for
// profanity -- a marker whose body contains profanity is INVALID and does not
// allowlist anything.
const ALLOWLIST_MARKER_KEYWORDS = /\[(?:F-WORD|S-WORD|EXPLETIVE|EXPLICIT|CRUDE|PROFANE|REDACTED|CENSORED)(?:[:\s][^\]\n]*)?\]/gi;

function normalize(content) {
  // NFD decomposes pre-composed glyphs into base + combining marks; strip the marks
  // (defeats "fu" + U+0307 + "ck" style insertions); NFKC re-canonicalizes (defeats
  // fullwidth ｆｕｃｋ, mathematical bold, circled letters, etc.).
  let out = content.normalize('NFD').replace(/\p{M}/gu, '').normalize('NFKC');
  // Cyrillic homoglyph fold -- NFKC does NOT fold Cyrillic to Latin because they
  // are distinct Unicode scripts. fuсk (with Cyrillic с U+0441) must become fuck.
  out = out.replace(CYRILLIC_REGEX, c => CYRILLIC_HOMOGLYPHS[c] || c);
  // Strip zero-width / soft-hyphen / BOM / word-joiner / CGJ / Mongolian vowel separator.
  // U+200B..U+200D = ZWSP, ZWNJ, ZWJ; U+2060 = WORD JOINER; U+034F = CGJ;
  // U+180E = MONGOLIAN VOWEL SEPARATOR; U+FEFF = BOM/ZWNBSP; U+00AD = SOFT HYPHEN.
  out = out.replace(/[​-‍⁠͏᠎﻿­]/g, '');
  // Decode HTML decimal and hex entities so &#102;&#117;&#99;&#107; -> fuck before scan.
  out = out
    .replace(/&#(\d+);/g, (_, code) => String.fromCharCode(parseInt(code, 10)))
    .replace(/&#x([0-9a-f]+);/gi, (_, code) => String.fromCharCode(parseInt(code, 16)));
  // Re-fold Cyrillic after HTML decode -- entities can decode to Cyrillic homoglyphs
  // (e.g., &#1089; -> с) that bypass the first fold.
  out = out.replace(CYRILLIC_REGEX, c => CYRILLIC_HOMOGLYPHS[c] || c);
  // Underscore is a \w char in regex, so \b doesn't anchor around _profanity_.
  // Replace _ with space (1:1 length, preserves line/col reporting) to restore word boundaries.
  out = out.replace(/_/g, ' ');
  return out;
}

function bodyHasProfanity(text) {
  for (const { regex } of PROFANITY_PATTERNS) {
    const re = new RegExp(regex.source, regex.flags);
    if (re.test(text)) return true;
  }
  return false;
}

function findValidMarkerSpans(content) {
  const spans = [];
  const re = new RegExp(ALLOWLIST_MARKER_KEYWORDS.source, ALLOWLIST_MARKER_KEYWORDS.flags);
  let match;
  while ((match = re.exec(content)) !== null) {
    const start = match.index;
    const end = start + match[0].length;
    // Marker is INVALID if its body contains profanity. Invalid markers don't allowlist.
    if (bodyHasProfanity(match[0])) continue;
    spans.push([start, end]);
  }
  return spans;
}

function isInsideMarker(spans, matchStart, matchEnd) {
  return spans.some(([s, e]) => matchStart >= s && matchEnd <= e);
}

function getLineAndColumn(content, position) {
  const lines = content.substring(0, position).split('\n');
  return { line: lines.length, column: lines[lines.length - 1].length + 1 };
}

function scanForProfanity(rawContent) {
  const content = normalize(rawContent);
  const validMarkerSpans = findValidMarkerSpans(content);
  const findings = [];
  for (const { name, regex, severity, suggestion } of PROFANITY_PATTERNS) {
    const re = new RegExp(regex.source, regex.flags);
    let match;
    while ((match = re.exec(content)) !== null) {
      const matchStart = match.index;
      const matchEnd = matchStart + match[0].length;
      if (isInsideMarker(validMarkerSpans, matchStart, matchEnd)) continue;
      const { line, column } = getLineAndColumn(content, matchStart);
      findings.push({ pattern: name, match: match[0], line, column, severity, suggestion });
    }
  }
  return { hasProfanity: findings.length > 0, findings };
}

function main() {
  const args = process.argv.slice(2);
  if (args.length === 0) {
    console.error('Usage: node language-scanner.js <file-to-scan>');
    process.exit(2);
  }
  if (args.length > 1) {
    console.error(`ERROR: only one file at a time is supported (received ${args.length}).`);
    console.error('       Loop in the caller if you need to scan multiple files.');
    process.exit(2);
  }

  let content;
  try {
    content = fs.readFileSync(args[0], 'utf-8');
  } catch (err) {
    console.error(`ERROR: cannot read ${args[0]}: ${err.message}`);
    process.exit(2);
  }

  const scan = scanForProfanity(content);
  if (!scan.hasProfanity) {
    console.log('Professional language audit: PASS. No profanity detected.');
    process.exit(0);
  }

  console.error('PROFESSIONAL LANGUAGE AUDIT FAILED\n');
  console.error('The following profanity / unprofessional language was found:\n');
  scan.findings.forEach((f) => {
    console.error(`  - Line ${f.line}, col ${f.column}: ${f.pattern} [${f.severity}]`);
    console.error(`    Match: "${f.match}"`);
    if (f.suggestion) console.error(`    Suggestion: ${f.suggestion}`);
    console.error('');
  });
  console.error('To fix:');
  console.error('  1. Replace each flagged term with professional language.');
  console.error('  2. If the term must be referenced verbatim (e.g., documenting profanity policy itself),');
  console.error('     wrap it in a redaction marker: [F-WORD], [EXPLETIVE], [REDACTED: reason], etc.');
  console.error('     The marker body itself must not contain bare profanity.');
  console.error('  3. Re-run the scanner before publishing.');
  process.exit(1);
}

if (require.main === module) {
  main();
}

module.exports = { scanForProfanity, normalize, findValidMarkerSpans, bodyHasProfanity };
