#!/usr/bin/env python3
"""Read-only action admission against a private, owner-approved phase registry.

This is phase/scope control, not a test receipt or publication authorization.
The caller invokes it before its managed edit/check/review boundary. It never
runs tests/models, edits phase state, or declares acceptance on the caller's behalf.
"""
import json
import hashlib
import os
from pathlib import Path
import sys


def fingerprint(state, phase, gap):
    inputs = state['phases'][phase]['criteria'][gap].get('inputs')
    if not isinstance(inputs, list) or not inputs:
        raise ValueError('registered proof inputs are missing: ' + gap)
    root = Path(state['root']).resolve()
    rows = []
    for name in sorted(set(inputs)):
        path = (root / name).resolve()
        path.relative_to(root)
        rows.append((name, path.stat().st_mode, hashlib.sha256(path.read_bytes()).hexdigest()))
    ignored = {'PWD', 'OLDPWD', 'SHLVL', '_', 'GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE',
               'GIT_PREFIX', 'CODEX_TOOL_CALL_ID', 'CODEX_THREAD_ID', 'CODEX_SESSION_ID'}
    environment = sorted((k, v) for k, v in os.environ.items() if k not in ignored)
    payload = {'inputs': rows, 'environment': environment, 'python': sys.version}
    return hashlib.sha256(json.dumps(payload, sort_keys=True).encode()).hexdigest()


def admit(state, request):
    if state.get('schema') != 1:
        raise ValueError('unknown execution-control schema')
    action = state['actions'].get(request.get('action'))
    if not action or request.get('kind') != action['kind']:
        raise ValueError('unregistered action or action kind')
    phase = state['phases'][action['phase']]
    if action['phase'] != state['active']:
        raise ValueError('successor expansion refused; close the active slice first')
    for predecessor in phase['predecessors']:
        if any(item['status'] != 'accepted' for item in state['phases'][predecessor]['criteria'].values()):
            raise ValueError('predecessor acceptance remains open')
    gap = request.get('gap')
    if (gap not in action['gaps'] or gap not in phase['criteria'] or
            phase['criteria'][gap]['status'] == 'accepted'):
        raise ValueError('action has no open registered acceptance gap')
    for needed in action.get('requires_verified', []):
        criterion = phase['criteria'][needed]
        if criterion['status'] not in ('verified', 'accepted'):
            raise ValueError('focused proof required before broader verification: ' + needed)
        if criterion.get('fingerprint') != fingerprint(state, action['phase'], needed):
            raise ValueError('verified prerequisite inputs changed: ' + needed)
    root = Path(state['root']).resolve()
    if action['kind'] == 'edit':
        patch = Path(request['patch']).read_text()
        paths = []
        for line in patch.splitlines():
            for marker in ('*** Add File: ', '*** Update File: ', '*** Delete File: ', '*** Move to: '):
                if line.startswith(marker):
                    candidate = Path(line[len(marker):])
                    resolved = (candidate if candidate.is_absolute() else root/candidate).resolve()
                    paths.append(resolved.relative_to(root).as_posix())
        if not paths or not set(paths) <= set(action['paths']):
            raise ValueError('patch paths do not belong to this registered action')
    elif action['kind'] == 'check':
        argv = request.get('argv', [])
        if 'argv' in action and argv != action['argv']:
            raise ValueError('check command does not match registered coverage')
        prefix = action.get('argv_prefix')
        if prefix and (argv[:len(prefix)] != prefix or len(argv) != len(prefix)+1 or not argv[-1]):
            raise ValueError('focused check selector is missing or unregistered')
        if prefix and argv[-1] not in action.get('selectors', {}).get(gap, []):
            raise ValueError('focused selector does not belong to the claimed gap')
    elif action['kind'] == 'review':
        if not set(request.get('paths', [])) <= set(action['paths']):
            raise ValueError('review scope exceeds the active slice')
    result = {'admit': True, 'phase': action['phase'], 'gap': gap,
              'reason': 'registered action advances an open active-slice criterion'}
    if phase['criteria'][gap].get('inputs'):
        result['input_fingerprint'] = fingerprint(state, action['phase'], gap)
    return result


if __name__ == '__main__':
    try:
        if sys.argv[1:] in (['--help'], ['-h']):
            print(__doc__)
            sys.exit(0)
        state = json.loads(Path(sys.argv[1]).read_text())
        if len(sys.argv) == 4 and sys.argv[2] == '--fingerprint':
            print(json.dumps({'fingerprint': fingerprint(state, state['active'], sys.argv[3])}))
        else:
            print(json.dumps(admit(state, json.load(sys.stdin))))
    except (OSError, ValueError, KeyError, TypeError, IndexError) as error:
        print(json.dumps({'admit': False, 'decision': 'STOP', 'reason': str(error)}))
        sys.exit(1)
