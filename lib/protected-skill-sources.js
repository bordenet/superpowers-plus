'use strict';

const fs = require('fs');
const path = require('path');

const DEBUG_CONDUCTOR_HELPERS = [
    'evidence-adjudicator.md',
    'infra-config-investigator.md',
    'llm-behavior-investigator.md',
    'reproduction-experiment-investigator.md',
    'state-consistency-investigator.md',
    'timeline-trace-investigator.md',
];

function getProtectedSourcePaths(skillPath) {
    const skillDir = path.dirname(skillPath);
    const sources = [skillPath];
    const siblingReference = path.join(skillDir, 'reference.md');
    if (fs.existsSync(siblingReference)) sources.push(siblingReference);
    if (path.basename(skillDir) === 'debug-conductor') {
        for (const name of DEBUG_CONDUCTOR_HELPERS) {
            const helper = path.join(skillDir, 'references', name);
            if (fs.existsSync(helper)) sources.push(helper);
        }
    }
    return sources;
}

module.exports = { DEBUG_CONDUCTOR_HELPERS, getProtectedSourcePaths };
