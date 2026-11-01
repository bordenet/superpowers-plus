#!/usr/bin/env python3
"""One authoritative context resolution, then in-request reader freshness.

No persistent cache, receipt, lock, test or model call. Observe the actual tree
and Git readers while resolving; before dispatch, compare metadata and repeat
only the bounded read-only Git queries. A change refuses the old decision.
"""
import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess

IGNORED_ENV = frozenset(('PWD', 'OLDPWD', 'SHLVL', '_', 'GIT_DIR', 'GIT_WORK_TREE',
    'GIT_INDEX_FILE', 'GIT_PREFIX', 'CODEX_TOOL_CALL_ID', 'CODEX_THREAD_ID',
    'CODEX_SESSION_ID', 'SPP_NATIVE_WRITER_LOCK_FD', 'SPP_VALIDATION_LOCK_FD',
    'SPP_VALIDATION_LOCK_PATH'))


def environment():
    return {key: value for key, value in os.environ.items() if key not in IGNORED_ENV}


def stamp(path):
    try:
        value = Path(path).lstat()
        return (value.st_dev, value.st_ino, value.st_mode, value.st_size,
                value.st_mtime_ns, value.st_ctime_ns,
                os.readlink(path) if stat.S_ISLNK(value.st_mode) else None)
    except FileNotFoundError:
        return None


def query_digest(args, value):
    if args == ('config', '--null', '--list'):
        # Match authoritative configuration normalization: branch bookkeeping
        # changes history metadata, not reviewed behavior.
        value = b'\0'.join(sorted(row for row in value.split(b'\0') if row and
            not row.split(b'\n', 1)[0].startswith(b'branch.')))
    return hashlib.sha256(value).hexdigest()


def resolve(receipt, root):
    root = Path(root)
    initial_env = environment()
    observations, queries = {}, {}
    original_tree, original_git = receipt.tree, receipt.git

    def remember(path, value):
        key = str(Path(path).absolute())
        if key in observations and observations[key] != value:
            raise RuntimeError('review input changed while resolving context')
        observations[key] = value

    def observed_tree(path, *args, **kwargs):
        before = stamp(path)
        remember(path, before)
        result = original_tree(path, *args, **kwargs)
        after = stamp(path)
        if before != after:
            raise RuntimeError('review input changed while reading content')
        remember(path, after)
        return result

    def observe_query(directory, args, outcome):
        key = (str(Path(directory).absolute()), args)
        if key in queries and queries[key] != outcome:
            raise RuntimeError('review Git inputs changed while resolving context')
        queries[key] = outcome

    def observed_git(directory, *args):
        try:
            value = original_git(directory, *args)
        except subprocess.CalledProcessError as error:
            observe_query(directory, args, ('error', error.returncode))
            raise
        observe_query(directory, args, ('ok', query_digest(args, value)))
        return value

    # PATH inventories are readers too, even for directories that did not
    # provide one of the currently selected executables.
    path_entries = [Path(item or '.') for item in initial_env.get('PATH', '').split(os.pathsep)]
    directories = list(dict.fromkeys(path_entries + [path.resolve() for path in path_entries]))
    for path in directories:
        remember(path, stamp(path))
    receipt.tree, receipt.git = observed_tree, observed_git
    try:
        home = Path(initial_env.get('HOME', '/nonexistent'))
        guidance = {name: receipt.tree(home/name)
                    for name in ('.codex/AGENTS.md', '.claude/CLAUDE.md')}
        for variable, name in (('CODEX_HOME', 'AGENTS.md'), ('CLAUDE_CONFIG_DIR', 'CLAUDE.md')):
            if initial_env.get(variable):
                guidance[variable + '/' + name] = receipt.tree(Path(initial_env[variable])/name)
        payload = {'schema': 2, 'context': receipt.context(root, [], initial_env),
                   'review_guidance': guidance}
    finally:
        receipt.tree, receipt.git = original_tree, original_git
    for path in directories:
        remember(path, stamp(path))
    stats = {'full_resolutions': 1, 'paths_observed': len(observations), 'git_queries': len(queries)}

    def fresh():
        try:
            if environment() != initial_env:
                return False
            if any(stamp(path) != expected for path, expected in observations.items()):
                return False
            for (directory, args), expected in queries.items():
                try:
                    current = ('ok', query_digest(args, original_git(Path(directory), *args)))
                except subprocess.CalledProcessError as error:
                    current = ('error', error.returncode)
                if current != expected:
                    return False
            return True
        except (OSError, ValueError, RuntimeError):
            return False
    return payload, fresh, stats
