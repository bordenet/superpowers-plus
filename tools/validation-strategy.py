#!/usr/bin/env python3
"""Cheap in-process strategy foundation for trusted execution adapters.

S0 supports only existing full/fast and review-class contracts. This module
does not read or validate receipts, acquire locks, run tools, or dispatch models.
Adapters must validate evidence and elect the producer before calling choose;
the returned dictionary is observability, never a transferable clearance token.
No CLI accepts caller-provided state/commands. S1 activation is separate.
"""
import hashlib
import json
import time

SCHEMA = 1
TEST_COVERAGE = frozenset(('full', 'fast', 'exact', 'shellcheck', 'harsh', 'router'))
REVIEW_COVERAGE = frozenset(('code', 'skill', 'design'))
STATES = frozenset(('MISSING', 'PASS', 'ACTIVE', 'FAIL', 'INTERRUPTED',
                    'RUNNING_UNRESOLVED', 'INVALID'))


class Refused(RuntimeError):
    """No valid decision permits another expensive action."""


def fingerprint(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()


def choose(snapshot, kind, required, state, covered=(), checks=()):
    """Resolve validated producer evidence without performing any I/O.

    Unknown coverage fails closed. A full PASS may cover fast; no other
    cross-class implication exists. ACTIVE means a proven live owner, whereas
    a leftover journal is RUNNING_UNRESOLVED and stops identical-input retries.
    """
    required, covered = sorted(set(required)), sorted(set(covered))
    known = TEST_COVERAGE.union(checks) if kind == 'test' else REVIEW_COVERAGE if kind == 'review' else frozenset()
    valid = (isinstance(snapshot, str) and len(snapshot) == 64 and
             all(c in '0123456789abcdef' for c in snapshot) and
             bool(required) and set(required) <= known and set(covered) <= known and state in STATES)
    available = set(covered)
    if kind == 'test' and 'full' in available:
        available.update(('fast', 'shellcheck', 'harsh', 'router'))
    missing = [check for check in required if check not in available]
    if not valid:
        action, reason = 'STOP', 'unknown-contract'
    elif state in ('FAIL', 'INTERRUPTED', 'RUNNING_UNRESOLVED', 'INVALID'):
        action, reason = 'STOP', 'failed-or-unprovable-evidence'
    elif state == 'ACTIVE':
        action, reason = 'WAIT', 'active-producer-lock'
    elif state == 'PASS' and not missing:
        action, reason = 'REUSE', 'validated-covered-inputs'
    else:
        action = 'REVIEW_REQUIRED' if kind == 'review' else 'RUN_MINIMAL'
        reason = 'missing-coverage'
    selected = (missing if state == 'PASS' else required) if action in ('RUN_MINIMAL', 'REVIEW_REQUIRED') else []
    decision = {'schema': SCHEMA, 'snapshot': snapshot, 'kind': kind,
                'required': required, 'state': state, 'covered': covered,
                'registry': fingerprint(sorted(known)),
                'decision': action, 'reason': reason, 'selected': selected,
                'expected_executions': len(selected), 'heavyweight_calls': 0}
    decision['binding'] = fingerprint(decision)
    return decision


class Boundary:
    """Recheck snapshot and the in-process decision immediately before action.

    This guard cannot elect a lock owner or prove evidence itself. WAIT must
    return to the owning adapter to join the existing producer, never run here.
    An emit callback appends the bounded event to its adapter's private ledger.
    """
    def __init__(self, current_snapshot, emit, checks=()):
        self.current_snapshot = current_snapshot
        self.emit = emit
        self.executing = False
        self.checks = tuple(checks)

    def execute(self, decision, action):
        started = time.monotonic()
        if self.executing:
            raise Refused('recursive strategy/expensive-action entry refused')
        if not isinstance(decision, dict):
            raise Refused('missing strategy decision')
        try:
            expected = choose(decision['snapshot'], decision['kind'], decision['required'],
                              decision['state'], decision['covered'], self.checks)
        except (KeyError, TypeError, ValueError) as error:
            raise Refused('invalid strategy decision') from error
        if decision != expected or decision['snapshot'] != self.current_snapshot():
            raise Refused('stale or changed strategy decision')
        self.emit({'event': 'strategy.preflight', 'decision': decision['decision'],
                   'reason': decision['reason'], 'snapshot': decision['snapshot'],
                   'selected': decision['selected'], 'heavyweight_calls': 0,
                   'wall_seconds': time.monotonic() - started})
        if decision['decision'] == 'REUSE':
            self.emit({'event': decision['kind'] + '.reuse'})
            return 0
        if decision['decision'] not in ('RUN_MINIMAL', 'REVIEW_REQUIRED'):
            self.emit({'event': decision['kind'] + '.refusal'})
            raise Refused(decision['decision'] + ': ' + decision['reason'])
        self.executing = True
        try:
            self.emit({'event': 'review.dispatch' if decision['kind'] == 'review' else 'validation.execute',
                       'selected': decision['selected']})
            return action()
        finally:
            self.executing = False
