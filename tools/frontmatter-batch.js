#!/usr/bin/env node
'use strict';

const fs = require('fs');
const { StringDecoder } = require('string_decoder');
const { parseFrontmatter } = require('../lib/frontmatter');

const MAX_FRONTMATTER_BYTES = 64 * 1024;
const READ_CHUNK_BYTES = 4096;

function normalizeNewlines(content) {
    return content.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
}

function completeFrontmatter(content, atEof = false) {
    const normalized = normalizeNewlines(content);
    const firstNewline = normalized.indexOf('\n');
    if (firstNewline >= 0 && normalized.slice(0, firstNewline) !== '---') {
        return { error: 'missing opening frontmatter delimiter', content: null };
    }

    const terminated = normalized.match(/^---\n[\s\S]*?\n---\n/);
    if (terminated) return { error: null, content: terminated[0] };
    if (atEof && /^---\n[\s\S]*?\n---$/.test(normalized)) {
        return { error: null, content: normalized };
    }
    return null;
}

function readFrontmatter(filePath) {
    const fd = fs.openSync(filePath, 'r');
    const decoder = new StringDecoder('utf8');
    const buffer = Buffer.alloc(READ_CHUNK_BYTES);
    let content = '';
    let bytesRead = 0;
    try {
        while (bytesRead < MAX_FRONTMATTER_BYTES) {
            const remaining = MAX_FRONTMATTER_BYTES - bytesRead;
            const count = fs.readSync(fd, buffer, 0, Math.min(buffer.length, remaining), null);
            if (count === 0) {
                content += decoder.end();
                const complete = completeFrontmatter(content, true);
                if (complete) return complete;
                const normalized = normalizeNewlines(content);
                const error = normalized.split('\n', 1)[0] === '---'
                    ? 'missing closing frontmatter delimiter'
                    : 'missing opening frontmatter delimiter';
                return { error, content: null };
            }
            bytesRead += count;
            content += decoder.write(buffer.subarray(0, count));
            const complete = completeFrontmatter(content);
            if (complete) return complete;
        }
        return {
            error: `frontmatter exceeds ${MAX_FRONTMATTER_BYTES} bytes or has no closing delimiter`,
            content: null
        };
    } finally {
        fs.closeSync(fd);
    }
}

function main() {
    let paths;
    try {
        paths = JSON.parse(fs.readFileSync(0, 'utf8'));
    } catch (error) {
        console.error(`ERROR: invalid path list: ${error.message}`);
        process.exit(2);
    }
    if (!Array.isArray(paths) || paths.some(value => typeof value !== 'string')) {
        console.error('ERROR: path list must be a JSON array of strings');
        process.exit(2);
    }

    const results = [];
    for (const filePath of paths) {
        try {
            const prefix = readFrontmatter(filePath);
            const frontmatter = prefix.error ? null : parseFrontmatter(prefix.content);
            results.push({ path: filePath, error: prefix.error, frontmatter });
        } catch (error) {
            results.push({ path: filePath, error: error.message, frontmatter: null });
        }
    }
    process.stdout.write(`${JSON.stringify({ schema_version: 1, results })}\n`);
}

main();
