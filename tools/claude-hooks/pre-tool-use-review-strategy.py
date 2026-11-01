#!/usr/bin/env python3
# Managed by superpowers-plus review-strategy installer.
"""Project-scoped native hook broker. Never grants host permissions."""
import json
import os
from pathlib import Path
import subprocess
import sys


def response(reason, deny=False):
    payload = {'hookEventName': 'PreToolUse'}
    if deny:
        payload.update(permissionDecision='deny', permissionDecisionReason='STOP: ' + reason)
    else:
        payload['additionalContext'] = 'strategy: UNENFORCED ' + reason
    return {'hookSpecificOutput': payload}


def handle(event):
    if not isinstance(event, dict) or not isinstance(event.get('cwd'), str):
        return response('invalid native event', True)
    env = dict(os.environ)
    for name in ('GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_PREFIX'):
        env.pop(name, None)
    location = subprocess.run(['git', '-C', event['cwd'], 'rev-parse', '--show-toplevel'],
        env=env, text=True, capture_output=True, timeout=3)
    if location.returncode:
        return response('outside a configured Git project')
    root = Path(location.stdout.strip())
    policy = root/'config/review-strategy.json'
    if not policy.exists() and not policy.is_symlink():
        committed = subprocess.run(['git', '-C', str(root), 'cat-file', '-e', 'HEAD:config/review-strategy.json'],
            env=env, capture_output=True, timeout=3).returncode == 0
        return response('configured project policy is missing', True) if committed else response('project has no review strategy contract')
    if policy.is_symlink() or policy.parent.is_symlink():
        return response('project strategy policy must not be a symlink', True)
    data = json.loads(policy.read_text())
    if not isinstance(data, dict) or type(data.get('schema')) is not int or data.get('schema') != 1 or data.get('enabled') is not True:
        return response('project strategy policy is unprovable', True)
    backend = root/'tools/review-dispatch-guard.py'
    if not backend.is_file() or backend.is_symlink():
        return response('configured project strategy backend is missing', True)
    result = subprocess.run([sys.executable, str(backend)], input=json.dumps(event),
        cwd=root, env=env, text=True, capture_output=True, timeout=20)
    if result.returncode:
        return response('strategy backend failed', True)
    answer = json.loads(result.stdout)
    payload = answer.get('hookSpecificOutput')
    if (not isinstance(payload, dict) or payload.get('hookEventName') != 'PreToolUse' or
            payload.get('permissionDecision') not in (None, 'deny') or
            set(answer) != {'hookSpecificOutput'} or
            not set(payload) <= {'hookEventName', 'permissionDecision', 'permissionDecisionReason', 'additionalContext'} or
            (payload.get('permissionDecision') is None and not str(payload.get('additionalContext', '')).startswith('REVIEW_REQUIRED:'))):
        return response('invalid or permission-granting strategy output', True)
    return answer


if __name__ == '__main__':
    try:
        answer = handle(json.load(sys.stdin))
    except Exception as error:
        answer = response('cannot prove strategy: ' + type(error).__name__, True)
    print(json.dumps(answer))
