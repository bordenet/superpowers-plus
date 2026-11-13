#!/usr/bin/env python3
"""Audited input selection. Unknown dependencies retain the entire tree.

Only enumerated documentation bytes may be omitted from ShellCheck, and only
while every shell source still matches the audited snapshot. All configuration,
policy, runtime, installed guidance and tracked selection remain global inputs.
Harsh/router/aggregate/CI closures remain global until independently audited.
"""
import hashlib
import json
from pathlib import Path


def shell_snapshot(root):
    h = hashlib.sha256()
    for p in sorted(root.rglob('*')):
        if any(part in ('.git', 'node_modules', '__pycache__', '.worktrees') for part in p.relative_to(root).parts):
            continue
        relative = p.relative_to(root).as_posix()
        if p.suffix != '.sh' and relative not in ('tools/pre-commit', 'tools/pre-push', 'tools/commit-msg'):
            continue
        h.update(relative.encode() + b'\0')
        if p.is_symlink():
            h.update(b'symlink\0' + str(p.resolve()).encode())
        if p.is_file():
            h.update(str(p.stat().st_mode).encode() + p.read_bytes())
        else:
            h.update(b'absent')
    return h.hexdigest()


def selection(root, check):
    root = Path(root)
    policy = root / 'config/validation-inputs.json'
    result = {'omissions': [], 'reason': 'global-unknown-closure', 'policy_sha256': 'absent'}
    try:
        raw = policy.read_bytes()
        result['policy_sha256'] = hashlib.sha256(raw).hexdigest()
        data = json.loads(raw)
        if not isinstance(data, dict) or data.get('schema') != 1 or check != 'shellcheck':
            return result
        omissions = data['shellcheck_exclusions']
        if (not isinstance(omissions, list) or not omissions or
                any(not isinstance(name, str) or not name.startswith('docs/') or
                    Path(name).suffix != '.md' or '..' in Path(name).parts or
                    (root/name).is_symlink() or not (root/name).is_file()
                    for name in omissions)):
            return result
        if shell_snapshot(root) != data['shell_audit']:
            result['reason'] = 'shell-audit-invalidated'
            return result
        result.update(omissions=sorted(set(omissions)), reason='audited-shellcheck-docs')
    except (OSError, ValueError, KeyError, TypeError):
        pass
    return result
