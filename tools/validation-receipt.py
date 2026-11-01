#!/usr/bin/env python3
"""Content receipts for test-all.sh; no public skip/force-pass mode.

The contract is the complete working input tree (including ignored dependencies),
selected arguments, normalized execution environment, platform, installed guidance,
git configuration and executable tools. Git history/ref names are deliberately not
inputs: tests must exercise source contents, not the promotion commit's identity.
Environment/config values are fingerprinted privately. Execution output and result
metadata are retained as mode-0600 evidence, including failures and interruptions.
A single common-dir flock serializes runs across worktrees. Never unlink its inode:
a live child inherits it, including when the parent is killed, so PID/time guesses
cannot steal a live run. The kernel releases stale locks automatically.
Supported runtime: POSIX Bash on macOS/Linux, including WSL. Native Windows
Python lacks the required flock/process-group semantics and fails explicitly.
"""
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import shutil
import signal
import stat
import subprocess
import sys
import time
import threading
import types
import re

try:
    import fcntl
except ImportError:
    print('validation: POSIX Bash/Python with flock is required; use Linux, macOS or WSL',
          file=sys.stderr)
    sys.exit(1)

SCHEMA = 3
PRODUCER = 'test-all.sh/validation-receipt-v3'
CHECKS = ('shellcheck', 'harsh', 'router')
NATIVE_CHECKS = ('native:pre-commit-static', 'native:commit-default')
MARKER = '# VALIDATION_RECEIPT_BODY\n'
TOOLS = ('bash', 'git', 'node', 'npm', 'python3', 'bats', 'parallel', 'shellcheck',
         'jq', 'curl', 'timeout', 'gtimeout', 'sh', 'sed', 'awk', 'find', 'sort',
         'grep', 'perl', 'ruby', 'rsync', 'file', 'head', 'tail', 'wc', 'tr')
# These are outputs of review/installation, not test inputs. Everything else,
# including ignored files and node_modules, participates in the content digest.
OUTPUTS = {'.git', '.code-review-cleared', '.phr-cleared', '.llm-skill-review-cleared',
           '.branch-flow-cleared', '.cr-battery-runs', '.trigger-audit-runs', '.ci-validation',
           '__pycache__', '.DS_Store', '.worktrees', '.cache',
           '.slop-metrics.json', '.superpowers-session', 'install-state'}
HOME_INPUTS = ('.codex/skills', '.codex/superpowers-augment', '.codex/superpowers-plus',
               '.codex/.superpowers-ecosystem', '.codex/config.toml', '.codex/.env',
               '.codex/hooks.json', '.codex/hooks',
               '.agents/skills', '.claude/hooks',
               '.claude/skills', '.claude/commands', '.claude/settings.json',
               '.claude/settings.local.json',
               '.augment/rules', '.golden-agents', '.config/git', '.gitconfig',
               '.config/claude-hooks', '.local/bin')
OVERRIDE_INPUTS = {
    'CODEX_HOME': ('skills', 'superpowers-augment', 'superpowers-plus',
                   '.superpowers-ecosystem', 'config.toml', '.env', 'hooks.json', 'hooks'),
    'CLAUDE_CONFIG_DIR': ('hooks', 'skills', 'commands', 'settings.json',
                          'settings.local.json'),
}

# Exact external-hook telemetry outputs from session-start-rules-integrity.sh
# and user-prompt-submit-skill-router.sh. Cache/seen-marker state is retained.
HOOK_OUTPUTS = {'hook-audit.log', 'hook-audit.log.1', 'hook-audit.log.2',
                'skill-router-metrics.jsonl', 'skill-router-metrics.jsonl.1',
                '.log-rotation.lock', '.log-rotation.reclaim', '.log-rotation.reclaim.lock'}


def digest(value):
    return hashlib.sha256(value).hexdigest()


def source_module(name, path):
    """Execute the source bytes we fingerprint, without reading/writing pycache."""
    module = types.ModuleType(name)
    module.__file__ = str(path)
    exec(compile(path.read_bytes(), str(path), 'exec'), module.__dict__)
    return module


def git(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args], stderr=subprocess.PIPE)


def tree(path, seen=None, root=False, tracked=None, relative="", omissions=frozenset(), selected=frozenset()):
    """Hash bytes, relative names, type, permissions and resolved symlink inputs."""
    seen = set() if seen is None else seen
    h = hashlib.sha256()
    try:
        info = path.lstat()
    except FileNotFoundError:
        return 'absent'
    h.update(str(stat.S_IMODE(info.st_mode)).encode())
    if stat.S_ISLNK(info.st_mode):
        h.update(b'link\0' + os.fsencode(os.readlink(path)))
        target = path.resolve()
        if target not in seen:
            seen.add(target)
            h.update(tree(target, seen, tracked=tracked, relative=relative,
                          omissions=omissions, selected=selected).encode())
    elif stat.S_ISREG(info.st_mode):
        h.update(b'file\0')
        with path.open('rb') as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b''):
                h.update(chunk)
    elif stat.S_ISDIR(info.st_mode):
        h.update(b'dir\0')
        for child in sorted(path.iterdir()):
            child_relative = relative + '/' + child.name if relative else child.name
            if child_relative in selected:
                continue
            # Only declared root-relative outputs are excluded. A tracked input
            # always wins, even below a directory named cache/install-state.
            tracked_input = tracked and any(name == child_relative or name.startswith(
                child_relative + '/') for name in tracked)
            if child.name == '.git' or ((child_relative in omissions or
                    (root and child_relative in OUTPUTS)) and not tracked_input):
                continue
            if child.name == '__pycache__' and not tracked_input:
                continue
            h.update(os.fsencode(child.name) + b'\0' + tree(
                child, seen, root=root, tracked=tracked, relative=child_relative,
                omissions=omissions, selected=selected).encode())
    else:
        raise RuntimeError('unsupported special input: ' + str(path))
    return h.hexdigest()


def external_tree(path, hooks=False):
    if not hooks or not path.is_dir():
        return tree(path)
    # Hook roots can be symlinks into a source checkout. Tracked source always
    # wins over the telemetry omission, even for an output-like filename.
    try:
        tracked = set(os.fsdecode(name) for name in git(
            path.resolve(), 'ls-files', '-z').split(b'\0') if name)
    except subprocess.CalledProcessError:
        tracked = set()
    return tree(path, tracked=tracked, omissions=HOOK_OUTPUTS)


def context(root, args, env, check=None, foundation=None):
    inputs = source_module('validation_inputs', root / 'tools/validation-inputs.py')
    selected = inputs.selection(root, check)
    staged_inputs = [row for row in git(root, 'ls-files', '--stage', '-z').split(b'\0')
                     if row and os.fsdecode(row.rsplit(b'\t', 1)[-1]) not in selected['omissions']]
    index_selection = digest(b'\0'.join(staged_inputs))
    # Native checks inspect the HEAD-relative staged path selector. A soft
    # reset can change it without changing any working or indexed blob.
    native_selection = digest(git(root, 'diff', '--cached', '--name-only',
                                  '--diff-filter=ACMRT')) if check == 'native:pre-commit-static' else None
    if foundation and 'payload' in foundation:
        payload = dict(foundation['payload'])
        payload.update(tree=tree(root, root=True, tracked=set(payload['tracked-selection']),
                                 selected=frozenset(selected['omissions'])), args=args, selection=selected)
        payload['index-selection'] = index_selection
        payload['native-selection'] = native_selection
        return digest(json.dumps(payload, sort_keys=True).encode())
    tools = {}
    for name in TOOLS:
        location = shutil.which(name, path=env.get('PATH'))
        tools[name] = (location, tree(Path(location))) if location else None
    # Directory inventories catch a newly installed command taking precedence.
    inventories = []
    for directory in env.get('PATH', '').split(os.pathsep):
        p = Path(directory or '.')
        inventories.append((str(p), sorted(os.listdir(p)) if p.is_dir() else None))
    external = {}
    home = Path(env.get('HOME', '/nonexistent'))
    for name in HOME_INPUTS:
        external['home/' + name] = external_tree(home / name, name in ('.claude/hooks', '.codex/hooks'))
    # Override profiles cover the same guidance/config inputs as default HOME
    # profiles; chat logs, sessions, databases and caches remain output state.
    for variable, names in OVERRIDE_INPUTS.items():
        if env.get(variable):
            for name in names:
                external[variable + '/' + name] = external_tree(Path(env[variable]) / name, name == 'hooks')
    # These variables are the runner's declared external fixture inputs. Other
    # environment variables are still hashed verbatim, but are not blindly
    # traversed (an output/evidence path is not an input directory).
    for name in ('SPP_SOURCE_DIR', 'PERSONAL_SKILLS_DIR', 'AUGMENT_MENU_DIR',
                 'GIT_CONFIG_GLOBAL', 'GIT_CONFIG_SYSTEM', 'GITHUB_EVENT_PATH'):
        value = env.get(name)
        if value:
            p = Path(value)
            if p.is_absolute() and p != root and root not in p.parents:
                # /dev/null explicitly disables Git config in isolated native
                # wrappers. Never open/read a device while fingerprinting it.
                if name.startswith('GIT_CONFIG_') and p.resolve() == Path(os.devnull).resolve():
                    external[name] = 'disabled-config:/dev/null'
                else:
                    external[name] = tree(p)
    # Tracking a different branch is promotion metadata, not a test input.
    # Keep all other effective configuration (core options, includes, identity,
    # remotes, etc.) without leaking its values into the persisted receipt.
    config = sorted(entry for entry in git(root, 'config', '--null', '--list').split(b'\0')
                    if entry and not entry.split(b'\n', 1)[0].startswith(b'branch.'))
    tracked = set(os.fsdecode(name) for name in git(root, 'ls-files', '-z').split(b'\0') if name)
    payload = {'schema': SCHEMA, 'tree': tree(root, root=True, tracked=tracked,
                   selected=frozenset(selected['omissions'])), 'args': args, 'selection': selected,
               # Selection is also an input: shellcheck discovers files with
               # git ls-files, so staging a new path changes required coverage
               # even when its already-present working bytes are unchanged.
               'tracked-selection': sorted(tracked),
               'index-selection': index_selection, 'native-selection': native_selection,
               'environment': sorted(env.items()), 'tools': tools,
               'path-inventory': inventories, 'external': external,
               'git-config': digest(b'\0'.join(config)),
               'platform': [platform.platform(), platform.machine(), sys.version,
                            tree(Path(sys.executable))]}
    if foundation is not None:
        foundation['payload'] = payload
    return digest(json.dumps(payload, sort_keys=True).encode())


def private_directory(path):
    try:
        path.mkdir(mode=0o700)
    except FileExistsError:
        pass
    info = path.lstat()
    if (not stat.S_ISDIR(info.st_mode) or info.st_uid != os.geteuid() or
            stat.S_IMODE(info.st_mode) != 0o700):
        raise RuntimeError('scratch path must be a nonsymlink mode-0700 directory owned '
                           'by the current user: ' + str(path))
    return path


def outside_git(path, env):
    return subprocess.run(['git', '-C', str(path), 'rev-parse', '--git-dir'], env=env,
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode != 0


def execution_sandbox(common, env):
    # Never derive this from caller TMPDIR: it may itself be inside a checkout.
    # Common-dir identity gives all linked worktrees the same execution profile.
    identity = digest(os.fsencode(str(common.resolve())))[:32]
    for location in ('/tmp', '/var/tmp'):
        base = Path(location).resolve()
        if not base.is_dir() or not outside_git(base, env):
            continue
        owner_root = private_directory(base / ('spp-validation-' + str(os.geteuid()) + '-v1'))
        sandbox = private_directory(owner_root / identity)
        if not outside_git(sandbox, env):
            raise RuntimeError('owned execution sandbox unexpectedly belongs to a Git repository')
        return sandbox
    raise RuntimeError('no supported OS temporary root exists outside any Git repository')


def registered_checks(root):
    registry = {name: ('static', name) for name in CHECKS}
    registry.update({name: ('native', name) for name in NATIVE_CHECKS})
    for suffix, prefix in (('.test.js', 'node'), ('.test.sh', 'shell')):
        for path in sorted((root / 'test').glob('*' + suffix)):
            if path.is_file() and re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]*', path.name):
                registry[prefix + ':' + path.name] = (prefix, path.name)
    manifest = root / 'config/validation-checks.json'
    if manifest.exists():
        configured = json.loads(manifest.read_text())
        if not isinstance(configured, dict) or configured.get('schema') != 1:
            raise RuntimeError('unknown registered-check schema')
        for name in configured['ci_checks']:
            if not re.fullmatch(r'ci:[a-z0-9-]+', name):
                raise RuntimeError('invalid registered CI check')
            registry[name] = ('ci', name)
    return registry


def coverage_checks(args, root=None):
    files = sorted(name for name, item in registered_checks(root).items()
                   if item[0] in ('node', 'shell') and name != 'node:skill-router.test.js') if root else []
    if args == []:
        return list(CHECKS) + files
    if args == ['--fast']:
        return ['router'] + files
    if len(args) == 2 and args[0] == '--check':
        return ['shellcheck', 'harsh'] if args[1] == 'harsh' else [args[1]]
    return []


def verify_dependencies(dependencies, cache, root, parents=frozenset()):
    if not isinstance(dependencies, list):
        raise ValueError('missing or malformed dependency evidence')
    for reference in dependencies:
        if (not isinstance(reference, dict) or set(reference) !=
                {'receipt', 'receipt_sha256', 'key', 'base_context', 'args'}):
            raise ValueError('invalid dependency reference')
        key = reference['key']
        if (not isinstance(key, str) or not re.fullmatch(r'[a-f0-9]{64}', key) or
                reference['receipt'] != key + '.json'):
            raise ValueError('invalid dependency receipt path')
        arguments = reference['args']
        if (not isinstance(arguments, list) or len(arguments) != 2 or
                arguments[0] != '--check' or arguments[1] not in CHECKS):
            raise ValueError('unregistered dependency coverage')
        dependency = cache / reference['receipt']
        if dependency.is_symlink() or digest(dependency.read_bytes()) != reference['receipt_sha256']:
            raise ValueError('dependency receipt hash mismatch')
        saved, _, _, _ = read_receipt(dependency, cache, key, reference['base_context'],
                                      arguments, root, parents)
        if saved['result'] != 'PASS':
            raise ValueError('dependency evidence does not prove PASS')


def read_receipt(receipt, cache, expected_key, base_context, expected_args, root, parents=frozenset()):
    try:
        if receipt.name in parents:
            raise ValueError('cyclic dependency evidence')
        parents = parents | {receipt.name}
        if receipt.is_symlink():
            raise ValueError('receipt must not be a symlink')
        saved = json.loads(receipt.read_text())
        if not isinstance(saved, dict):
            raise ValueError('receipt must be an object')
        if (saved.get('schema') != SCHEMA or saved.get('producer') != PRODUCER or
                saved.get('key') != expected_key or saved.get('base_context') != base_context or
                saved.get('coverage') != ('full' if expected_args == [] else
                    'fast' if expected_args == ['--fast'] else 'exact') or
                saved.get('checks') != coverage_checks(expected_args, root) or
                saved.get('result') not in (
                    'PASS', 'FAIL', 'INTERRUPTED', 'INPUTS_CHANGED', 'OUTPUT_ERROR') or
                saved.get('args') != expected_args):
            raise ValueError('receipt schema/context/arguments mismatch')
        code = saved.get('code')
        if (type(code) is not int or not 0 <= code <= 255 or
                (saved['result'] == 'PASS') != (code == 0)):
            raise ValueError('invalid result/exit-code pairing')
        started, completed = saved.get('started'), saved.get('completed')
        if (type(started) not in (int, float) or type(completed) not in (int, float) or
                not math.isfinite(started) or not math.isfinite(completed) or
                not 0 <= started <= completed):
            raise ValueError('invalid receipt timestamps')
        reference = Path(saved.get('log', ''))
        if reference.parent != Path('logs') or reference.name in ('', '.', '..'):
            raise ValueError('invalid execution log reference')
        evidence = cache / reference
        if evidence.is_symlink() or not evidence.is_file():
            raise ValueError('execution log is missing or not a regular file')
        if digest(evidence.read_bytes()) != saved.get('log_sha256'):
            raise ValueError('execution log hash mismatch')
        verify_dependencies(saved.get('dependencies'), cache, root, parents)
    except (OSError, ValueError, TypeError) as error:
        raise RuntimeError('existing validation receipt is invalid; refusing duplicate '
                           'validation: ' + str(error)) from error
    return saved, code, completed, evidence


def main():
    script = Path(sys.argv[1]).resolve()
    root = script.parent.parent
    if (script != (root / 'tools/test-all.sh').resolve() or
            Path(__file__).resolve() != (root / 'tools/validation-receipt.py').resolve()):
        raise RuntimeError('coverage requires the canonical registered producer entrypoint')
    args = sys.argv[2:]
    if args == ['--check', 'node:skill-router.test.js']:
        args = ['--check', 'router']
    registry = registered_checks(root)
    named = len(args) == 2 and args[0] == '--check'
    if '--check' in args and (not named or args[1] not in registry):
        raise RuntimeError('unknown registered check')
    strategy = source_module('validation_strategy', root / 'tools/validation-strategy.py')
    required = coverage_checks(args, root) if named else ['fast' if args == ['--fast'] else 'full' if not args else 'exact']
    env = dict(os.environ)
    inherited_origin = env.pop('SPP_VALIDATION_LOCK_PATH', None)
    os.environ.pop('SPP_VALIDATION_LOCK_PATH', None)
    # Hook-local Git variables must never redirect nested fixture repositories.
    for name in ('GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_PREFIX',
                 'PWD', 'OLDPWD', 'SHLVL', '_', 'SPP_NATIVE_WRITER_LOCK_FD',
                 'CODEX_TOOL_CALL_ID', 'CODEX_THREAD_ID', 'CODEX_SESSION_ID'):
        env.pop(name, None)
        os.environ.pop(name, None)
    if 'GIT_EXEC_PATH' not in env:
        env['GIT_EXEC_PATH'] = os.fsdecode(subprocess.check_output(
            ['git', '--exec-path'], env=env)).rstrip('\n')
    # Git prepends its helper directory when launching a native hook. Give
    # direct callers the same execution PATH before hashing or running tests;
    # retain every caller-supplied directory and custom GIT_EXEC_PATH override.
    paths = env.get('PATH', os.defpath).split(os.pathsep)
    while paths and paths[0] == env['GIT_EXEC_PATH']:
        paths.pop(0)
    env['PATH'] = os.pathsep.join([env['GIT_EXEC_PATH'], *paths])
    # Configured sources use one cheap compatibility contract before locks,
    # input traversal or any heavy body. Legacy copied producers without this
    # contract retain their existing behavior, explicitly outside this support.
    policy = root / 'config/validation-toolchain.json'
    declared = policy.exists() or b'config/validation-toolchain.json' in git(root, 'ls-files', '-z').split(b'\0')
    if declared:
        toolchain = source_module('validation_toolchain', root / 'tools/validation-toolchain.py')
        print('toolchain: ' + json.dumps(toolchain.preflight(root, required, env), sort_keys=True), flush=True)
    else:
        print('toolchain: UNENFORCED legacy source has no declared contract', flush=True)
    common = Path(os.fsdecode(git(root, 'rev-parse', '--git-common-dir')).strip())
    if not common.is_absolute():
        common = root / common
    cache = common.resolve() / 'validation-receipts-v1'
    cache.mkdir(mode=0o700, parents=True, exist_ok=True)
    # An inherited descriptor is checked against the real common lock inode.
    # An ambient flag alone can never establish ownership or authorize reuse.
    # Some launchers (including Bats) close inherited descriptors. The path
    # hint may only REFUSE same-lock reentry; it never proves ownership or
    # grants reuse. A different fixture repository still has its own lock.
    if inherited_origin == str(cache / 'run.lock'):
        raise RuntimeError('recursive receipt front door from owned raw body refused (descriptor may be closed)')
    inherited = env.pop('SPP_VALIDATION_LOCK_FD', None)
    if inherited is not None:
        try:
            descriptor = int(inherited)
            actual = os.fstat(descriptor)
            expected = (cache / 'run.lock').stat()
            if (actual.st_dev, actual.st_ino) == (expected.st_dev, expected.st_ino):
                raise RuntimeError('recursive receipt front door from owned raw body refused')
        except (ValueError, OSError):
            pass
    with (cache / 'run.lock').open('a+b') as lock:
        print('validation: waiting for shared test lock', flush=True)
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            waiting = strategy.choose(tree(root, root=True), 'test', required, 'ACTIVE', checks=registry)
            print('strategy: ' + json.dumps(waiting, sort_keys=True), flush=True)
            fcntl.flock(lock, fcntl.LOCK_EX)
        # Canonical temp placement prevents random wrapper TMPDIR paths from
        # invalidating equivalent runs. Tests still use independent mktemp paths.
        sandbox = execution_sandbox(common, env)
        temp = private_directory(sandbox / 'tmp')
        if not outside_git(temp, env):
            raise RuntimeError('execution TMPDIR unexpectedly belongs to a Git repository')
        env['TMPDIR'] = str(temp) + os.sep
        env.pop('TMP', None)
        env.pop('TEMP', None)
        home = Path(env['HOME']) if env.get('HOME') else None
        if home and home.is_dir() and not any(home.iterdir()):
            # Equivalent EMPTY homes execute at the SAME path. We do not assert
            # arbitrary user homes/configurations are equivalent.
            clean_home = private_directory(sandbox / 'empty-home')
            # Only this verified helper-owned scratch HOME may be cleaned.
            # The caller's HOME and all other user directories are untouched.
            if any(clean_home.iterdir()):
                shutil.rmtree(clean_home)
                clean_home.mkdir(mode=0o700)
            if not outside_git(clean_home, env):
                raise RuntimeError('execution HOME unexpectedly belongs to a Git repository')
            for variable in OVERRIDE_INPUTS:
                if env.get(variable):
                    try:
                        suffix = Path(env[variable]).resolve().relative_to(home.resolve())
                    except ValueError:
                        continue
                    env[variable] = str(clean_home / suffix)
            env['HOME'] = str(clean_home)
        # Healing declared debris is part of the authoritative entry point,
        # even on a reuse. Refused/missing guards cannot yield a receipt hit.
        guard = root / 'tools' / 'test-tree-guard.sh'
        if not os.access(guard, os.X_OK):
            raise RuntimeError('working-tree guard missing or not executable')
        subprocess.run([str(guard), 'sweep'], cwd=root, env=env, check=True)
        active_check = args[1] if named else None
        foundation = {}
        base_context = context(root, [], env, active_check, foundation)
        contexts = {active_check: base_context}
        def request_context(arguments):
            check = arguments[1] if len(arguments) == 2 and arguments[0] == '--check' else None
            if check not in contexts:
                contexts[check] = context(root, [], env, check, foundation)
            return contexts[check]
        def result_key(arguments):
            return digest(json.dumps({'context': request_context(arguments), 'args': arguments},
                                     sort_keys=True).encode())
        before = result_key(args)
        receipt = cache / (before + '.json')
        journal = cache / (before + '.running.json')
        expected_key, expected_args = before, args
        from_full = False
        # The default FULL runner contains every fast bats/node/engineering
        # target. No partial flag set, help invocation, or fast result can
        # establish this superset. Exact negative/unresolved results win.
        if ((args == ['--fast'] or named) and not receipt.exists() and not receipt.is_symlink() and
                not journal.exists() and not journal.is_symlink()):
            candidates = [[]] if (not named or set(required) <= set(coverage_checks([], root))) else []
            if named and set(required) <= set(coverage_checks(['--fast'], root)):
                candidates.append(['--fast'])
            if args == ['--check', 'shellcheck']:
                candidates.append(['--check', 'harsh'])
            for candidate in candidates:
                full_receipt = cache / (result_key(candidate) + '.json')
                if full_receipt.exists() or full_receipt.is_symlink():
                    receipt = full_receipt
                    expected_key, expected_args, from_full = result_key(candidate), candidate, True
                    break
        if receipt.exists() or receipt.is_symlink():
            saved, code, completed, evidence = read_receipt(
                receipt, cache, expected_key, request_context(expected_args), expected_args, root)
            if not from_full or saved['result'] == 'PASS':
                covered = (['full'] if expected_args == [] else ['fast'] if expected_args == ['--fast'] else []) + coverage_checks(expected_args, root)
                if not covered:
                    covered = ['exact']
                reuse = strategy.choose(base_context, 'test', required,
                                        'PASS' if saved['result'] == 'PASS' else 'FAIL', covered, registry)
                # Strategy and validated producer evidence precede reuse/STOP;
                # neither path launches an expensive body or another reviewer.
                print('strategy: ' + json.dumps(reuse, sort_keys=True), flush=True)
                print('validation: reusing ' + saved['result'] +
                      (' from default FULL coverage' if from_full and expected_args == [] else
                       ' from registered superset coverage' if from_full else '') +
                      ' for identical contents and execution context ' + expected_key[:12] +
                      ' (exit ' + str(code) + ')', flush=True)
                print('validation: evidence ' + str(evidence) + ' sha256:' + saved['log_sha256'] +
                      ' completed:' + str(completed) + ' producer-args:' + json.dumps(expected_args),
                      flush=True)
                return code
            # A failure in FULL may belong to slow-only coverage. It cannot
            # claim either success or failure for a fast run that never ran.
            receipt = cache / (before + '.json')
        if journal.exists() or journal.is_symlink():
            print('strategy: ' + json.dumps(strategy.choose(
                base_context, 'test', required, 'RUNNING_UNRESOLVED', checks=registry), sort_keys=True), flush=True)
            try:
                if journal.is_symlink():
                    raise ValueError('journal must not be a symlink')
                pending = json.loads(journal.read_text())
                if (not isinstance(pending, dict) or pending.get('schema') != SCHEMA or
                        pending.get('producer') != PRODUCER or pending.get('key') != before or
                        pending.get('args') != args or pending.get('base_context') != base_context or
                        pending.get('result') != 'RUNNING' or
                        type(pending.get('started')) not in (int, float) or
                        not math.isfinite(pending['started']) or pending['started'] < 0):
                    raise ValueError('journal schema/context mismatch')
                reference = Path(pending.get('log', ''))
                if reference.parent != Path('logs') or reference.name in ('', '.', '..'):
                    raise ValueError('invalid journal log reference')
                evidence = cache / reference
                if evidence.is_symlink() or not evidence.is_file():
                    raise ValueError('journal execution log missing or invalid')
                log_hash = digest(evidence.read_bytes())
            except (OSError, ValueError, TypeError) as error:
                raise RuntimeError('existing execution journal is invalid; refusing duplicate '
                                   'validation: ' + str(error)) from error
            print('validation: prior execution is interrupted or unresolved; refusing to '
                  'repeat identical inputs without explicit retry authorization', file=sys.stderr)
            print('validation: unresolved evidence ' + str(evidence) + ' sha256:' + log_hash,
                  file=sys.stderr)
            return 1
        source = script.read_text()
        if source.count(MARKER) != 1:
            raise RuntimeError('test entry point must contain one receipt body marker')
        body = source.split(MARKER, 1)[1]
        if named:
            body = ('set -euo pipefail\n'
                    'SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"\n'
                    'REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"\n'
                    'source "$SCRIPT_DIR/lib/validation-check-bodies.sh"\n'
                    'validation_check_body "$2"\n')
        # Only validated receipts can remove registered bodies from a broader
        # execution. The raw-body library never interprets a caller skip flag.
        already = set()
        dependencies = []
        needed_priors = CHECKS if not args else ('shellcheck',) if args == ['--check', 'harsh'] else ()
        for check in needed_priors:
            check_args = ['--check', check]
            check_key = result_key(check_args)
            prior = cache / (check_key + '.json')
            pending = cache / (check_key + '.running.json')
            if pending.exists() or pending.is_symlink():
                raise RuntimeError('registered check has interrupted or unresolved evidence')
            if prior.exists() or prior.is_symlink():
                row, exit_code, _, evidence = read_receipt(
                    prior, cache, check_key, request_context(check_args), check_args, root)
                if row['result'] != 'PASS':
                    raise RuntimeError('registered check has failed evidence; refusing unchanged retry')
                already.update(row['checks'])
                dependencies.append({'receipt': prior.name, 'receipt_sha256': digest(prior.read_bytes()),
                                     'key': row['key'], 'base_context': row['base_context'], 'args': row['args']})
        if named and args[1] == 'harsh' and 'shellcheck' not in already:
            body = body.replace('validation_check_body "$2"',
                                'validation_check_body shellcheck\nvalidation_check_body "$2"')
        if args == []:
            for check, statement in (
                ('shellcheck', '[[ "$RUN_SHELLCHECK" -eq 1 ]] && run_suite "shellcheck"      run_shellcheck'),
                ('harsh', '[[ "$RUN_HARSH"      -eq 1 ]] && run_suite "harsh-review.sh" run_harsh_review')):
                if check in already:
                    body = body.replace(statement, 'echo "validation: REUSE registered ' + check + '"')
            if 'router' in already:
                body = body.replace('for f in test/*.test.js; do',
                    'for f in test/*.test.js; do\n        [[ "$f" == test/skill-router.test.js ]] && continue')
        # The strategy foundation is read-only; only validated internal state
        # reaches it. This adapter executes the existing full/fast unit or a
        # registered static body, never an arbitrary caller-supplied command.
        decision = strategy.choose(base_context, 'test', required,
                                   'PASS' if already else 'MISSING', already, registry)
        print('strategy: ' + json.dumps(decision, sort_keys=True), flush=True)
        interrupted = []
        child = None

        def stop(signum, _frame):
            interrupted.append(signum)
            if child is not None:
                try:
                    os.killpg(child.pid, signum)
                except ProcessLookupError:
                    pass

        for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
            signal.signal(sig, stop)
        logs = cache / 'logs'
        logs.mkdir(mode=0o700, exist_ok=True)
        started = time.time()
        log = logs / (before + '.' + str(time.time_ns()) + '-' + str(os.getpid()) + '.log')
        with log.open('xb') as evidence_stream:
            os.chmod(log, 0o600)
            output_lock = threading.Lock()
            stream_errors = []
            log_errors = []
            pending = {'schema': SCHEMA, 'producer': PRODUCER, 'key': before,
                       'args': args, 'base_context': base_context, 'result': 'RUNNING', 'started': started,
                       'log': str(log.relative_to(cache))}
            journal_temp = journal.with_suffix('.tmp')
            with journal_temp.open('w') as state_stream:
                os.chmod(journal_temp, 0o600)
                json.dump(pending, state_stream)
                state_stream.flush()
                os.fsync(state_stream.fileno())
            journal_temp.replace(journal)

            def tee(source_stream, destination):
                destination_open = True
                try:
                    while True:
                        chunk = source_stream.read1(65536)
                        if not chunk:
                            break
                        try:
                            with output_lock:
                                evidence_stream.write(chunk)
                                evidence_stream.flush()
                        except OSError as error:
                            log_errors.append(error)
                        if destination_open:
                            try:
                                destination.buffer.write(chunk)
                                destination.buffer.flush()
                            except OSError as error:
                                # A closed consumer must not strand a live child
                                # on a full pipe while holding the shared lock.
                                destination_open = False
                                stream_errors.append(error)
                                # Prevent Python's shutdown flush from changing
                                # our recorded exit code to BrokenPipe exit 120.
                                try:
                                    sink = os.open(os.devnull, os.O_WRONLY)
                                    try:
                                        os.dup2(sink, destination.fileno())
                                    finally:
                                        os.close(sink)
                                except OSError:
                                    pass
                except OSError as error:
                    stream_errors.append(error)

            child_env = dict(env, SPP_VALIDATION_LOCK_FD=str(lock.fileno()),
                             SPP_VALIDATION_LOCK_PATH=str(cache / 'run.lock'))
            def fresh_snapshot():
                # The authoritative resolver has just fingerprinted tools,
                # guidance and environment. Recheck the working input/policy
                # snapshot here without another installed-tree traversal.
                # Final receipt issuance revalidates the complete context.
                result = context(root, [], env, active_check, foundation)
                if result != base_context:
                    print('strategy: working input/policy snapshot changed',
                        file=sys.stderr)
                return result
            boundary = strategy.Boundary(fresh_snapshot,
                                         lambda event: print('strategy: ' + json.dumps(event), flush=True), registry)
            def launch():
                return subprocess.Popen([shutil.which('bash', path=env.get('PATH')), '-c', body, str(script), *args],
                                     cwd=root, env=child_env, pass_fds=(lock.fileno(),),
                                     start_new_session=True, stdout=subprocess.PIPE,
                                     stderr=subprocess.PIPE)
            child = boundary.execute(decision, launch)
            pumps = [threading.Thread(target=tee, args=(child.stdout, sys.stdout)),
                     threading.Thread(target=tee, args=(child.stderr, sys.stderr))]
            for pump in pumps:
                pump.start()
            result = child.wait()
            for pump in pumps:
                pump.join()
        if log_errors:
            raise RuntimeError('execution log failed; prior journal remains unresolved')
        if interrupted:
            code, outcome = 128 + interrupted[0], 'INTERRUPTED'
        elif result:
            code, outcome = result if result > 0 else 128 - result, 'FAIL'
        elif stream_errors:
            code, outcome = 1, 'OUTPUT_ERROR'
        elif context(root, [], env, active_check) != base_context:
            print('validation: inputs changed during run; no PASS receipt written', file=sys.stderr)
            code, outcome = 1, 'INPUTS_CHANGED'
        else:
            code, outcome = 0, 'PASS'
        temporary = receipt.with_suffix('.tmp')
        # Revalidate the exact reused producer chain before sealing coverage.
        # A missing/tampered ancestor leaves the journal unresolved, never PASS.
        verify_dependencies(dependencies, cache, root)
        temporary.write_text(json.dumps({'schema': SCHEMA, 'producer': PRODUCER,
                                         'key': before, 'base_context': base_context, 'result': outcome,
                                         'code': code, 'args': args,
                                         'coverage': 'full' if args == [] else
                                             'fast' if args == ['--fast'] else 'exact',
                                         'checks': coverage_checks(args, root),
                                         'dependencies': dependencies,
                                         'started': started, 'completed': time.time(),
                                         'log': str(log.relative_to(cache)),
                                         'log_sha256': digest(log.read_bytes())}) + '\n')
        os.chmod(temporary, 0o600)
        temporary.replace(receipt)
        journal.unlink()
        print('validation: saved ' + outcome + ' ' + before[:12] + ' (exit ' + str(code) + ')',
              file=sys.stderr if stream_errors else sys.stdout, flush=True)
        return code


if __name__ == '__main__':
    try:
        code = main()
        # IP/ancestry/publication authority is live, never part of reusable
        # static validation. Run it even when the static producer was reused.
        arguments = sys.argv[2:]
        dynamic = ((not arguments or '--check' not in arguments) and
                   not any(a in arguments for a in ('--fast', '--no-harsh', '--help', '-h')))
        dynamic = dynamic or arguments in (['--check', 'harsh'], ['--check', 'ci:security-scan-ip-disclosure-audit'])
        if code == 0 and dynamic:
            root = Path(sys.argv[1]).resolve().parent.parent
            audit = root / 'tools/public-repo-ip-check.sh'
            if not audit.is_file():
                raise RuntimeError('fresh IP authorization tool is missing')
            code = subprocess.run(['bash', str(audit)], cwd=root).returncode
        sys.exit(code)
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        print('strategy: ' + json.dumps({'decision': 'STOP', 'reason': 'unprovable-execution-context',
                                        'heavyweight_calls': 0}), file=sys.stderr)
        print('validation: cannot establish safe receipt context: ' + str(error), file=sys.stderr)
        sys.exit(1)
