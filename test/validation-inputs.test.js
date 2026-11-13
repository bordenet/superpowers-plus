#!/usr/bin/env node
'use strict';
const assert = require('assert');
const path = require('path');
const { spawnSync } = require('child_process');
const result = spawnSync('python3', ['-c', String.raw`
import importlib.util, json, pathlib, subprocess, sys, tempfile
spec = importlib.util.spec_from_file_location('inputs', sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
with tempfile.TemporaryDirectory() as d:
    root = pathlib.Path(d)
    (root/'docs').mkdir(); (root/'tools').mkdir(); (root/'config').mkdir()
    (root/'docs/note.md').write_text('baseline')
    (root/'tools/lint.sh').write_text('#!/usr/bin/env bash\necho ok\n')
    policy = {'schema':1, 'shell_audit':m.shell_snapshot(root), 'shellcheck_exclusions':['docs/note.md']}
    (root/'config/validation-inputs.json').write_text(json.dumps(policy))
    def exclusions(check='shellcheck'): return m.selection(root, check)['omissions']
    assert exclusions() == ['docs/note.md']
    (root/'docs/note.md').write_text('changed documentation')
    assert exclusions() == ['docs/note.md']
    assert exclusions('harsh') == [] and exclusions('router') == []
    (root/'tools/lint.sh').write_text('#!/usr/bin/env bash\nsource docs/note.md\n')
    assert exclusions() == [], 'changed audited shell source must fall back globally'
    (root/'tools/lint.sh').write_text('#!/usr/bin/env bash\necho ok\n')
    (root/'docs/note.md').unlink()
    assert exclusions() == [], 'deleted exclusion must fall back globally'
    (root/'docs/note.md').symlink_to('../tools/lint.sh')
    assert exclusions() == [], 'symlinked exclusion must fall back globally'
    (root/'docs/note.md').unlink(); (root/'docs/note.md').write_text('restored')
    assert exclusions() == ['docs/note.md']
    policy['shellcheck_exclusions'] = ['tools/lint.sh']
    (root/'config/validation-inputs.json').write_text(json.dumps(policy))
    assert exclusions() == [], 'policy cannot omit executable source'
    policy['schema'] = 99
    (root/'config/validation-inputs.json').write_text(json.dumps(policy))
    assert exclusions() == [], 'unknown policy must fall back globally'
    (root/'config/validation-inputs.json').write_text('{invalid')
    assert exclusions() == []
    for malformed in ([], None, 'not an object', 1):
        (root/'config/validation-inputs.json').write_text(json.dumps(malformed))
        assert exclusions() == [], 'non-object JSON policy must fall back globally'
print('input policy: audited docs only; changed/deleted/symlink/unknown policy fallbacks pass')
`, path.join(__dirname, '../tools/validation-inputs.py')], { encoding: 'utf8', timeout: 10000 });
assert.strictEqual(result.status, 0, result.stdout + result.stderr);
process.stdout.write(result.stdout);
