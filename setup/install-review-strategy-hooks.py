#!/usr/bin/env python3
"""Register scoped review strategy hooks for explicitly selected local hosts.

Use --host codex and/or --host claude. --home isolates standard host profiles;
without it CODEX_HOME is honored. --refresh-existing updates only registrations
already owned by this installer. This never starts a host or bypasses hook trust.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import stat
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent
MARKER = b'# Managed by superpowers-plus review-strategy installer.'
NAME = 'pre-tool-use-review-strategy'


def safe(path):
    for item in (path, *path.parents):
        if item.is_symlink():
            raise ValueError('refusing symlinked hook/profile path')


def atomic(path, data, mode=0o600):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, prefix='.'+path.name, delete=False) as stream:
        temporary = Path(stream.name)
        os.chmod(temporary, mode); stream.write(data); stream.flush(); os.fsync(stream.fileno())
    temporary.replace(path)


def prepare(host, home, explicit_home, refresh, remove):
    base = home/('.codex' if host == 'codex' else '.claude')
    if host == 'codex' and not explicit_home and os.environ.get('CODEX_HOME'):
        base = Path(os.environ['CODEX_HOME']).expanduser().absolute()
    target = base/('hooks.json' if host == 'codex' else 'settings.json')
    safe(target)
    original = target.read_bytes() if target.exists() else None
    data = json.loads(original) if original is not None else {}
    if not isinstance(data, dict) or not isinstance(data.get('hooks', {}), dict):
        raise ValueError('invalid native hook configuration')
    blocks = data.get('hooks', {}).get('PreToolUse', [])
    if not isinstance(blocks, list):
        raise ValueError('invalid native PreToolUse configuration')
    script = base/'hooks'/(NAME+'.sh')
    shell = shutil.which('bash')
    if not shell and not remove:
        raise ValueError('Bash is required for a fail-closed native hook entrypoint')
    command = shlex.quote(shell) + ' ' + shlex.quote(str(script)) if shell else None
    matcher = r'^(spawn_agent|followup_task|.*\.(spawn_agent|followup_task))$' if host == 'codex' else r'^(Agent|Task)$'
    def owned(hook):
        if not isinstance(hook, dict) or hook.get('type') != 'command':
            return False
        try:
            parts = shlex.split(hook.get('command', ''))
        except (TypeError, ValueError):
            return False
        return (len(parts) == 2 and Path(parts[0]).is_absolute() and
                Path(parts[0]).name == 'bash' and parts[1] == str(script))
    registered = any(isinstance(block, dict) and block.get('matcher') == matcher and
        any(owned(hook) for hook in block.get('hooks', [])) for block in blocks)
    if (refresh or remove) and not registered:
        return None
    if not registered and not remove:
        data.setdefault('hooks', {}).setdefault('PreToolUse', []).append({
            'matcher': matcher, 'hooks': [{'type': 'command', 'command': command, 'timeout': 60}]})
    if registered and not remove:
        for block in blocks:
            if isinstance(block, dict):
                for hook in block.get('hooks', []):
                    if owned(hook):
                        hook['command'] = command
    if remove:
        kept = []
        for block in blocks:
            hooks = block.get('hooks', [])
            filtered = [hook for hook in hooks if not owned(hook)]
            if filtered or len(filtered) == len(hooks):
                kept.append(dict(block, hooks=filtered))
        data['hooks']['PreToolUse'] = kept
    files = []
    for suffix in ('.sh', '.py'):
        destination = base/'hooks'/(NAME+suffix);safe(destination)
        source = (ROOT/'tools/claude-hooks'/(NAME+suffix)).read_bytes()
        previous = destination.read_bytes() if destination.exists() else None
        if previous is not None and MARKER not in previous[:1024]:
            raise ValueError('foreign file occupies managed review-hook path')
        files.append((destination, source, previous))
    encoded = (json.dumps(data, indent=2)+'\n').encode()
    return target, original, encoded, files, registered


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--host', action='append', choices=('codex', 'claude'))
    parser.add_argument('--home', type=Path, help='isolated standard-profile HOME; ignores external CODEX_HOME')
    parser.add_argument('--refresh-existing', action='store_true')
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--remove', action='store_true', help='unregister owned hooks; preserve modified copies')
    args = parser.parse_args()
    if not args.host and not args.refresh_existing:
        parser.error('select at least one --host')
    home = (args.home or Path.home()).expanduser().resolve()
    plans = [prepare(host, home, args.home is not None, args.refresh_existing, args.remove)
             for host in sorted(set(args.host or ('codex', 'claude')))]
    plans = [plan for plan in plans if plan is not None]
    retained = 0
    for target, original, encoded, files, registered in plans:
        if args.check:
            if not args.remove and (not registered or original is None or any(previous != source for _,source,previous in files)):
                raise ValueError('registered review hook is missing or stale')
            continue
        # Preserve foreign settings and detect concurrent edits before writes.
        if (target.read_bytes() if target.exists() else None) != original:
            raise ValueError('hook configuration changed concurrently')
        for destination, source, previous in files:
            if args.remove:
                if previous == source:
                    destination.unlink()
                elif previous is not None:
                    retained += 1
                continue
            if previous != source:
                if previous is not None:
                    atomic(destination.with_name(destination.name+'.before-'+str(time.time_ns())), previous)
                atomic(destination, source, 0o700)
        if original != encoded:
            if original is not None:
                atomic(target.with_name(target.name+'.before-review-strategy-'+str(time.time_ns())), original)
            atomic(target, encoded, stat.S_IMODE(target.stat().st_mode) if target.exists() else 0o600)
    print(json.dumps({'profiles': len(plans), 'mode': 'check' if args.check else 'remove' if args.remove else 'refresh' if args.refresh_existing else 'register',
                      'retained_modified_files': retained,
                      'live_host_probe': False, 'hook_trust_bypassed': False}))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, TypeError) as error:
        raise SystemExit('review hook installation refused: '+str(error))
