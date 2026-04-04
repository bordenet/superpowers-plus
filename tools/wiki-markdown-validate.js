#!/usr/bin/env node
'use strict';

const fs = require('fs');
const {
    assertArtifactFree,
    prepareMarkdownForValidation,
} = require('../lib/wiki-publish');

function usage() {
    console.error('Usage: node tools/wiki-markdown-validate.js [--strip-frontmatter] <file.md>');
    console.error('   or: cat file.md | node tools/wiki-markdown-validate.js --stdin [--strip-frontmatter]');
}

function parseArgs(argv) {
    const args = { stripFrontmatter: false, stdin: false, file: null };
    for (const arg of argv) {
        if (arg === '--strip-frontmatter') args.stripFrontmatter = true;
        else if (arg === '--stdin') args.stdin = true;
        else if (arg.startsWith('--')) throw new Error(`Unexpected argument: ${arg}`);
        else if (!args.file) args.file = arg;
        else throw new Error(`Unexpected argument: ${arg}`);
    }
    if ((args.stdin && args.file) || (!args.stdin && !args.file)) {
        throw new Error('Specify exactly one input source: <file> or --stdin');
    }
    return args;
}

function main() {
    const args = parseArgs(process.argv.slice(2));
    const raw = args.stdin ? fs.readFileSync(0, 'utf8') : fs.readFileSync(args.file, 'utf8');
    const prepared = prepareMarkdownForValidation(raw, { stripFrontmatter: args.stripFrontmatter });

    try {
        assertArtifactFree(prepared.markdown, { label: 'Markdown validation failed', lineOffset: prepared.lineOffset });
    } catch (error) {
        console.error(error.message);
        process.exit(1);
    }

    console.log('Markdown validation passed');
}

try {
    main();
} catch (error) {
    usage();
    console.error(error.message);
    process.exit(1);
}
