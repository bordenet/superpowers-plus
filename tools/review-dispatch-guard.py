#!/usr/bin/env python3
"""PreToolUse adapter for managed review dispatch, with explicit deny output.

Review requests carry SPP_REVIEW_CLASS=code|skill|design and
SPP_REVIEW_SNAPSHOT=<native preflight hash>. No caller-provided decision can
authorize a dispatch. Role labels cannot bypass admission for a managed agent dispatch.
The fixture contract verifies downstream calls; live hook installation is a
separate support/installation result, never inferred from this script existing.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import types


def answer(allow, reason, decision='STOP'):
    payload = {'hookEventName': 'PreToolUse'}
    if allow:
        # Admit work without granting host permissions or bypassing prompts.
        payload['additionalContext'] = decision + ': ' + reason
    else:
        payload.update(permissionDecision='deny', permissionDecisionReason=decision + ': ' + reason)
    print(json.dumps({'hookSpecificOutput': payload}))


def load(name, path):
    module = types.ModuleType(name)
    module.__file__ = str(path)
    exec(compile(path.read_bytes(), str(path), 'exec'), module.__dict__)
    return module


def main():
    import fcntl
    event = json.load(sys.stdin)
    tool = event.get('tool_name', '')
    if tool not in ('Agent', 'Task', 'spawn_agent', 'followup_task') and not tool.endswith(('.spawn_agent', '.followup_task')):
        answer(True, 'not a managed agent-dispatch action', 'RUN_MINIMAL')
        return
    data = event.get('tool_input', {})
    message = data.get('message', data.get('prompt', ''))
    if not isinstance(message, str):
        answer(False, 'invalid dispatch message')
        return
    requested = re.search(r'\bSPP_REVIEW_CLASS=(code|skill|design)\b', message)
    supplied = re.search(r'\bSPP_REVIEW_SNAPSHOT=([a-f0-9]{64})\b', message)
    if not requested or not supplied:
        answer(False, 'managed review requires class and current native strategy snapshot')
        return
    for variable in ('GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_PREFIX'):
        os.environ.pop(variable, None)
    root = Path(subprocess.check_output(['git', '-C', event['cwd'], 'rev-parse', '--show-toplevel'],
                                       stderr=subprocess.PIPE, text=True).strip())
    os.chdir(root)
    preflight = load('preflight', root / 'tools/review-preflight.py')
    # Unstaged tracked content is outside the staged review request.
    if subprocess.run(['git', 'diff', '--quiet'], stdout=subprocess.DEVNULL).returncode:
        answer(False, 'stage the exact review snapshot before dispatch')
        return
    report = plan_report(preflight)
    resolved = report['strategy']
    name = requested[1]
    if (report['routes']['exit'] or resolved['status'] != 'RESOLVED' or
            supplied[1] != resolved['snapshot'] or name not in resolved['classes']):
        answer(False, 'stale, unsupported or unmatched review strategy')
        return
    decision = resolved['classes'][name]
    if decision['decision'] != 'REVIEW_REQUIRED':
        answer(False, 'native evidence does not require another reviewer', decision['decision'])
        return
    receipt = load('receipt', root / 'tools/validation-receipt.py')
    common = Path(subprocess.check_output(['git', 'rev-parse', '--git-common-dir'], text=True).strip())
    if not common.is_absolute():
        common = root / common
    directory = receipt.private_directory(common.resolve() / 'review-strategy-v1')
    filename = directory / (resolved['snapshot'] + '.' + name + '.json')
    with (directory / 'dispatch.lock').open('a+b') as lock:
        os.chmod(directory / 'dispatch.lock', 0o600)
        fcntl.flock(lock, fcntl.LOCK_EX)
        if filename.exists() or filename.is_symlink():
            # No PID guess or age-based stealing: an unresolved previous
            # dispatch remains evidence, including a failed/interrupted owner.
            answer(False, 'equivalent review has an unresolved dispatch; preserve its evidence', 'STOP')
            return
        if preflight.current_review_snapshot(root, report) != resolved['snapshot']:
            answer(False, 'snapshot changed before dispatch')
            return
        owner = hashlib.sha256(str(event.get('tool_use_id', '')).encode()).hexdigest()
        with filename.open('x') as stream:
            os.chmod(filename, 0o600)
            json.dump({'schema': 1, 'snapshot': resolved['snapshot'], 'class': name,
                       'owner': owner, 'result': 'DISPATCHING', 'decision': decision,
                       'heavyweight_calls_in_preflight': 0}, stream)
        answer(True, 'one current required-class review elected', 'REVIEW_REQUIRED')


def write_claim(directory, snapshot, name, row):
    filename = directory / (snapshot + '.' + name + '.json')
    temporary = directory / (snapshot + '.' + name + '.update.json')
    with temporary.open('x') as stream:
        os.chmod(temporary, 0o600)
        json.dump(row, stream)
    temporary.replace(filename)


def plan_report(preflight):
    staged = subprocess.run(['git', 'diff', '--cached', '--quiet', 'HEAD'],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode != 0
    return preflight.preflight('origin/dev', staged, None)


def native_write(name, filename, arguments):
    """Execute the registered native writer; a callback cannot mint evidence."""
    import fcntl
    import threading
    import time
    writers = {'code': 'run-battery.sh', 'skill': 'run-llm-skill-review.sh', 'design': 'run-phr.sh'}
    script = Path(filename)
    expected = Path(__file__).resolve().parent / writers[name]
    if script.is_symlink() or script.resolve() != expected:
        raise ValueError('unregistered native writer')
    source = script.read_bytes()
    marker = b'# REVIEW_NATIVE_BODY\n'
    if source.count(marker) != 1:
        raise ValueError('native writer body is unprovable')
    body = source.split(marker, 1)[1].decode().replace('${BASH_SOURCE[0]}', '$0')
    if any(arg in ('--help', '-h') for arg in arguments):
        code = subprocess.run(['bash', '-c', body, str(script), *arguments]).returncode
        return code if code >= 0 else 128 - code
    for key in ('GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_PREFIX'):
        os.environ.pop(key, None)
    location = subprocess.run(['git', 'rev-parse', '--show-toplevel'],
                              text=True, capture_output=True)
    if location.returncode:
        location = subprocess.run(['git', '-C', str(expected.parent.parent), 'rev-parse', '--show-toplevel'],
                                  text=True, capture_output=True, check=True)
    root = Path(location.stdout.strip())
    os.chdir(root)
    preflight = load('preflight', expected.parent / 'review-preflight.py')
    receipt = load('receipt', expected.parent / 'validation-receipt.py')
    strategy = load('strategy', expected.parent / 'validation-strategy.py')
    report = plan_report(preflight)
    snapshot = report['strategy']['snapshot']
    directory = receipt.private_directory(preflight.strategy_directory(root))
    # Never let a raw body acquire a second composer/receipt lock on its own
    # repository. A real inherited descriptor/inode proves this condition.
    inherited = os.environ.get('SPP_VALIDATION_LOCK_FD')
    if inherited:
        try:
            actual = os.fstat(int(inherited))
            owned = (directory.parent / 'validation-receipts-v1/run.lock').stat()
            if (actual.st_dev, actual.st_ino) == (owned.st_dev, owned.st_ino):
                raise ValueError('native writer from owned raw body refused')
        except (OSError, OverflowError):
            pass
    native_inherited = os.environ.get('SPP_NATIVE_WRITER_LOCK_FD')
    if native_inherited:
        actual = os.fstat(int(native_inherited))
        locks = [directory / (kind + '.native.lock') for kind in writers]
        if any(path.exists() and (actual.st_dev, actual.st_ino) ==
               (path.stat().st_dev, path.stat().st_ino) for path in locks):
            raise ValueError('recursive native writer from owned body refused')
        raise ValueError('unprovable inherited native writer ownership')
    with (directory / (name + '.native.lock')).open('a+b') as lock:
        os.chmod(directory / (name + '.native.lock'), 0o600)
        fcntl.flock(lock, fcntl.LOCK_EX)
        row = preflight.strategy_claim(root, snapshot, name) if snapshot else None
        sentinel = root / {'code': '.code-review-cleared', 'skill': '.llm-skill-review-cleared', 'design': '.phr-cleared'}[name]
        if sentinel.is_symlink():
            raise ValueError('native sentinel must not be a symlink')
        if row:
            if row.get('result') == 'PASS':
                if not preflight.native_binding_valid(root, row, sentinel.name):
                    raise ValueError('existing native review evidence is invalid')
            elif row.get('result') != 'DISPATCHING':
                raise ValueError('unchanged failed or unresolved native producer')
        def stamp():
            if not sentinel.is_file():
                return None
            stat = sentinel.stat()
            return (stat.st_ino, stat.st_mtime_ns, hashlib.sha256(sentinel.read_bytes()).hexdigest())
        before = stamp()
        started = time.time_ns()
        log = directory / ('native-' + name + '-' + str(started) + '.log')
        with log.open('xb') as stream:
            os.chmod(log, 0o600)
            mutex = threading.Lock()
            stream_errors = []
            def pump(source_stream, target):
                destination_open = log_open = True
                try:
                    while True:
                        chunk = source_stream.read1(65536)
                        if not chunk:
                            break
                        if log_open:
                            try:
                                with mutex:
                                    stream.write(chunk); stream.flush()
                            except (OSError, ValueError) as error:
                                log_open = False
                                stream_errors.append(type(error).__name__)
                        if destination_open:
                            try:
                                target.buffer.write(chunk); target.buffer.flush()
                            except (OSError, ValueError) as error:
                                destination_open = False
                                stream_errors.append(type(error).__name__)
                                try:
                                    sink = os.open(os.devnull, os.O_WRONLY)
                                    try: os.dup2(sink, target.fileno())
                                    finally: os.close(sink)
                                except OSError:
                                    pass
                        # Keep draining after either output failure. Stopping
                        # here can strand the child on a full pipe/held lock.
                except (OSError, ValueError) as error:
                    stream_errors.append(type(error).__name__)
            decision = strategy.choose(snapshot or hashlib.sha256(source).hexdigest(), 'test',
                ('native:' + name + '-clearance',), 'MISSING', checks=('native:' + name + '-clearance',))
            print('strategy: ' + json.dumps(decision), flush=True)
            boundary = strategy.Boundary(
                lambda: (preflight.current_review_snapshot(root, report) if snapshot else
                         hashlib.sha256(script.read_bytes()).hexdigest()),
                lambda event: print('strategy: ' + json.dumps(event), flush=True),
                ('native:' + name + '-clearance',))
            child_env = dict(os.environ, SPP_NATIVE_WRITER_LOCK_FD=str(lock.fileno()))
            def launch():
                if row:
                    row.update(result='NATIVE_RUNNING', native_attempt={
                        'started': started, 'snapshot': snapshot, 'script': script.name,
                        'log': log.name, 'args_sha256': hashlib.sha256(json.dumps(arguments).encode()).hexdigest()})
                    write_claim(directory, snapshot, name, row)
                return subprocess.Popen(['bash', '-c', body, str(script), *arguments],
                    cwd=root, env=child_env, pass_fds=(lock.fileno(),),
                    stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            process = boundary.execute(decision, launch)
            threads = [threading.Thread(target=pump, args=(process.stdout, sys.stdout)),
                       threading.Thread(target=pump, args=(process.stderr, sys.stderr))]
            for thread in threads: thread.start()
            code = process.wait()
            if code < 0: code = 128 - code
            for thread in threads: thread.join()
            if stream_errors: code = 1
        if code != 0:
            # A failed producer cannot leave a newly minted clearing artifact.
            # Preserve its bytes privately as failure evidence, never as PASS.
            if stamp() != before and sentinel.is_file() and not sentinel.is_symlink():
                failed_sentinel = directory / ('native-' + name + '-' + str(started) + '.failed-sentinel')
                with failed_sentinel.open('xb') as failed:
                    os.chmod(failed_sentinel, 0o600); failed.write(sentinel.read_bytes())
                sentinel.unlink()
            if row:
                row.update(result='FAIL', native_exit=code, native_log=log.name,
                           native_log_sha256=hashlib.sha256(log.read_bytes()).hexdigest())
                write_claim(directory, snapshot, name, row)
            return code
        if row is None:
            # Generic/legacy callers retain their normal writer behavior, but
            # no context clearance is invented without an original dispatch.
            return 0
        current = plan_report(preflight)
        state = current['sentinels'][sentinel.name]
        if (current['strategy']['snapshot'] != snapshot or script.read_bytes() != source or
                stamp() == before or state['state'] not in ('valid', 'stale') or
                state.get('verdict') not in ('PASS', 'PASS_WITH_NITS', 'PASS_WITH_RISKS')):
            raise ValueError('registered native writer did not produce fresh matching clearance')
        raw = sentinel.read_text()
        row.update(result='PASS', verdict=state['verdict'], sentinel_sha256=hashlib.sha256(raw.encode()).hexdigest(),
                   sentinel_record=raw, review_tree=subprocess.check_output(['git', 'write-tree'], text=True).strip(),
                   native_writer={'script': script.name, 'sha256': hashlib.sha256(source).hexdigest(),
                       'exit': 0, 'started': started, 'completed': time.time_ns(),
                       'snapshot': snapshot, 'log': log.name, 'log_sha256': hashlib.sha256(log.read_bytes()).hexdigest()})
        write_claim(directory, snapshot, name, row)
        return 0


if __name__ == '__main__':
    try:
        if len(sys.argv) >= 4 and sys.argv[1] == '--native-write':
            sys.exit(native_write(sys.argv[2], sys.argv[3], sys.argv[4:]))
        elif sys.argv[1:]:
            raise ValueError('unregistered producer command')
        else:
            main()
    except Exception as error:
        # Hook failures may fail open in the host. Always produce a supported
        # explicit denial, even for malformed input or unavailable POSIX locks.
        if sys.argv[1:]:
            print(json.dumps({'completed': False, 'reason': type(error).__name__}))
            sys.exit(1)
        answer(False, 'cannot prove review strategy: ' + type(error).__name__)
