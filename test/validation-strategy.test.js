#!/usr/bin/env node
'use strict';
// Exercise the production boundary with real subprocess counters. No fabricated receipts.
const assert = require('assert');
const path = require('path');
const { spawnSync } = require('child_process');
const result = spawnSync('python3', ['-c', String.raw`
import importlib.util
import pathlib
import sys
import tempfile
import subprocess

spec = importlib.util.spec_from_file_location('strategy', sys.argv[1])
s = importlib.util.module_from_spec(spec)
spec.loader.exec_module(s)
snapshot = 'a' * 64
calls = []
events = []
def current(): return snapshot
def execute():
    calls.append('execute')
    return subprocess.run([sys.executable, '-c', 'print("executed")'], capture_output=True).returncode
def emit(event): events.append(event)
guard = s.Boundary(current, emit)
def decision(kind='test', coverage='fast', state='MISSING', covered=()):
    return s.choose(snapshot, kind, (coverage,), state, covered)
def refused(d):
    before = len(calls)
    try: guard.execute(d, execute)
    except s.Refused: pass
    else: raise AssertionError('boundary did not refuse')
    assert len(calls) == before

missing = decision()
assert missing['decision'] == 'RUN_MINIMAL'
assert missing['selected'] == ['fast']
assert guard.execute(missing, execute) == 0
assert len(calls) == 1
assert events[0]['event'] == 'strategy.preflight'
assert events[1]['event'] == 'validation.execute'
assert events[0]['heavyweight_calls'] == 0

reuse = decision(state='PASS', covered=('full',))
assert reuse['decision'] == 'REUSE'
assert guard.execute(reuse, execute) == 0
assert len(calls) == 1
assert decision(coverage='full', state='PASS', covered=('fast',))['decision'] == 'RUN_MINIMAL'
assert decision(coverage='fast', state='PASS', covered=('unknown',))['decision'] == 'STOP'
for state in ('FAIL', 'INTERRUPTED', 'RUNNING_UNRESOLVED', 'INVALID'):
    d = decision(state=state)
    assert d['decision'] == 'STOP'
    refused(d)
waiting = decision(state='ACTIVE')
assert waiting['decision'] == 'WAIT'
refused(waiting)  # caller must join producer, never execute a second copy
refused(None)
refused({**missing, 'selected': ['full']})
snapshot = 'b' * 64
refused(missing)
fresh = decision()
assert guard.execute(fresh, execute) == 0
assert len(calls) == 2
review = decision(kind='review', coverage='code')
assert review['decision'] == 'REVIEW_REQUIRED'
assert guard.execute(review, execute) == 0
assert len(calls) == 3
assert decision(kind='review', coverage='code', state='PASS', covered=('code',))['decision'] == 'REUSE'
assert decision(kind='review', coverage='code', state='PASS', covered=('skill',))['decision'] == 'REVIEW_REQUIRED'

def recursive(): return guard.execute(decision(), execute)
refused_recursive = False
try: guard.execute(decision(), recursive)
except s.Refused: refused_recursive = True
assert refused_recursive and len(calls) == 3
assert all(e.get('heavyweight_calls', 0) == 0 for e in events if e['event'] == 'strategy.preflight')
print('strategy: coarse decisions, refusal, freshness, coverage, zero extra subprocesses and recursion controls pass')
`, path.join(__dirname, '../tools/validation-strategy.py')], { encoding: 'utf8', timeout: 10000 });
assert.strictEqual(result.status, 0, result.stdout + result.stderr);
process.stdout.write(result.stdout);
