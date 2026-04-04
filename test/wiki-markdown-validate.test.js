#!/usr/bin/env node
'use strict';

const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');
const {
    stripFrontmatterWithOffset,
    stripFrontmatter,
    detectMalformedTables,
    findMarkdownArtifacts,
} = require('../lib/wiki-markdown');
const {
    assertArtifactFree,
    assertRoundTripArtifacts,
    prepareMarkdownForValidation,
} = require('../lib/wiki-publish');

const validTable = [
    '| Phase | What It Does | Admin Required? |',
    '|-------|--------------|-----------------|',
    '| **Phase 1** | Install WSL, Ubuntu, Node.js | Yes |',
].join('\n');

assert.deepStrictEqual(detectMalformedTables(validTable), []);

const collapsedTable = '| Phase | What It Does | Admin Required? | |-------|--------------|-----------------| | **Phase 1** | Install WSL, Ubuntu, Node.js | Yes |';
const tableIssues = detectMalformedTables(collapsedTable);
assert.strictEqual(tableIssues.length, 1);
assert.match(tableIssues[0], /collapsed table rows detected/);
assert.match(tableIssues[0], /line 1:/);

const collapsedNoLeadingPipe = 'Phase | What It Does | Admin Required? |-------|--------------|-----------------| | **Phase 1** | Install WSL, Ubuntu, Node.js | Yes |';
assert.strictEqual(detectMalformedTables(collapsedNoLeadingPipe).length, 1);

const inlineCodeTable = '| Example | Value |\n|---------|-------|\n| A | `| --- |` |';
assert.deepStrictEqual(detectMalformedTables(inlineCodeTable), []);

const artifactIssues = findMarkdownArtifacts(`See [doc]()\n${collapsedTable}\nValue: &nbsp;`);
assert(artifactIssues.includes('line 1: empty href found'));
assert(artifactIssues.includes('line 3: literal &nbsp; found'));
assert(artifactIssues.some(issue => issue.includes('collapsed table rows detected')));

const fencedExample = ['```markdown', collapsedTable, 'Escaped: \\[', 'Empty: [doc]()', '```'].join('\n');
assert.deepStrictEqual(detectMalformedTables(fencedExample), []);
assert.deepStrictEqual(findMarkdownArtifacts(fencedExample), []);

const fourBacktickFence = ['````markdown', '```', '[doc]()', '````'].join('\n');
assert.deepStrictEqual(findMarkdownArtifacts(fourBacktickFence), []);

const indentedCode = ['    [doc]()', '    | bad | row | |---|---|', 'Visible &nbsp;'].join('\n');
const indentedIssues = findMarkdownArtifacts(indentedCode);
assert.deepStrictEqual(indentedIssues, ['line 3: literal &nbsp; found']);

const blockquoteIndentedCode = ['>', '>     [doc]()', '>     | bad | row | |---|---|', '> Visible text'].join('\n');
assert.deepStrictEqual(findMarkdownArtifacts(blockquoteIndentedCode), []);

assert.strictEqual(stripFrontmatter('---\nid: abc\n---\n\nbody\n'), 'body\n');
assert.strictEqual(stripFrontmatter('---\r\nid: abc\r\n---\r\n\r\nbody\r\n'), 'body\n');
assert.deepStrictEqual(stripFrontmatterWithOffset('---\nid: abc\n---\n\nbody\n'), { markdown: 'body\n', lineOffset: 4 });
assert.deepStrictEqual(prepareMarkdownForValidation('---\nid: abc\n---\n\nbody\n', { stripFrontmatter: true }), { markdown: 'body\n', lineOffset: 4 });
assert.doesNotThrow(() => assertArtifactFree('Clean line'));
assert.throws(() => assertArtifactFree('[doc]()', { label: 'sample' }), /sample:\n  - line 1: empty href found/);
assert.throws(() => assertRoundTripArtifacts({ outboundMarkdown: '[doc]()', persistedMarkdown: 'clean' }), /outbound markdown:/);

const cliPass = spawnSync('node', ['tools/wiki-markdown-validate.js', '--stdin', '--strip-frontmatter'], {
    cwd: process.cwd(),
    input: '---\nid: abc\n---\n\n| ok | yes |\n|----|-----|\n| a | b |\n',
    encoding: 'utf8',
});
assert.strictEqual(cliPass.status, 0);
assert.match(cliPass.stdout, /Markdown validation passed/);

const cliFail = spawnSync('node', ['tools/wiki-markdown-validate.js', '--stdin'], {
    cwd: process.cwd(),
    input: collapsedNoLeadingPipe,
    encoding: 'utf8',
});
assert.strictEqual(cliFail.status, 1);
assert.match(cliFail.stderr, /Markdown validation failed:/);
assert.match(cliFail.stderr, /collapsed table rows detected/);

const cliFrontmatterLine = spawnSync('node', ['tools/wiki-markdown-validate.js', '--stdin', '--strip-frontmatter'], {
    cwd: process.cwd(),
    input: '---\nid: abc\n---\n\n[doc]()\n',
    encoding: 'utf8',
});
assert.strictEqual(cliFrontmatterLine.status, 1);
assert.match(cliFrontmatterLine.stderr, /line 5: empty href found/);

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'wiki-md-validate-'));
const filePath = path.join(tmpDir, 'sample.md');
fs.writeFileSync(filePath, '| ok | yes |\n|----|-----|\n| a | b |\n');
const cliFilePass = spawnSync('node', ['tools/wiki-markdown-validate.js', filePath], {
    cwd: process.cwd(),
    encoding: 'utf8',
});
assert.strictEqual(cliFilePass.status, 0);
assert.match(cliFilePass.stdout, /Markdown validation passed/);

const cliMissingInput = spawnSync('node', ['tools/wiki-markdown-validate.js'], {
    cwd: process.cwd(),
    encoding: 'utf8',
});
assert.strictEqual(cliMissingInput.status, 1);
assert.match(cliMissingInput.stderr, /Specify exactly one input source/);

const cliMixedInput = spawnSync('node', ['tools/wiki-markdown-validate.js', '--stdin', filePath], {
    cwd: process.cwd(),
    encoding: 'utf8',
});
assert.strictEqual(cliMixedInput.status, 1);
assert.match(cliMixedInput.stderr, /Specify exactly one input source/);

const cliUnexpectedArg = spawnSync('node', ['tools/wiki-markdown-validate.js', filePath, 'extra.md'], {
    cwd: process.cwd(),
    encoding: 'utf8',
});
assert.strictEqual(cliUnexpectedArg.status, 1);
assert.match(cliUnexpectedArg.stderr, /Unexpected argument: extra.md/);

const cliUnexpectedFlag = spawnSync('node', ['tools/wiki-markdown-validate.js', '--bogus'], {
    cwd: process.cwd(),
    encoding: 'utf8',
});
assert.strictEqual(cliUnexpectedFlag.status, 1);
assert.match(cliUnexpectedFlag.stderr, /Unexpected argument: --bogus/);

console.log('wiki-markdown-validate tests passed');
