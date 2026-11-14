#!/usr/bin/env python3
"""Cheap compatibility preflight; explicit isolated ShellCheck provisioning.

No test, model, recursive runner or automatic user-machine upgrade. Local and
CI consume the same version contract. Exact executable bytes remain receipt
inputs; a compatible version is not evidence that two runtimes are identical.
"""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import tarfile
import urllib.request


def contract(root):
    policy = Path(root)/'config/validation-toolchain.json'
    if policy.is_symlink():
        raise RuntimeError('toolchain contract must not be symlinked')
    data = json.loads(policy.read_text())
    if not isinstance(data, dict) or data.get('schema') != 1:
        raise RuntimeError('unknown validation toolchain contract')
    return data


def required_tools(checks):
    names = {'bash', 'python3', 'git'}
    for check in checks:
        if check in ('full', 'fast', 'exact'):
            names.update(('node', 'bats'))
        if check in ('full', 'exact', 'shellcheck', 'harsh', 'native:pre-commit-static') or 'fence-scan' in check:
            names.add('shellcheck')
        if check == 'router' or check.startswith(('node:', 'ci:node-')):
            names.add('node')
        if check == 'native:commit-default' or 'bats' in check:
            names.add('bats')
    return sorted(names)


def preflight(root, checks, env=None):
    env = dict(os.environ) if env is None else env
    data = contract(root)
    system, machine = platform.system(), platform.machine()
    if machine not in data['platforms'].get(system, []):
        raise RuntimeError('unsupported validation platform: '+system+'/'+machine+'; use supported POSIX Bash/Python')
    report = []
    for name in required_tools(checks):
        rule = data['tools'][name]
        actual = shutil.which(name, path=env.get('PATH'))
        configured = shutil.which(rule['command'], path=env.get('PATH'))
        if not actual or not configured:
            raise RuntimeError(name+': required configured executable unavailable; install the declared tool before validation')
        if Path(actual).resolve() != Path(configured).resolve():
            raise RuntimeError(name+': configured executable differs from actual PATH dispatch')
        if name == 'python3' and Path(actual).resolve() != Path(sys.executable).resolve():
            raise RuntimeError('python3: running interpreter differs from actual PATH dispatch')
        result = subprocess.run([actual, '--version'], text=True, capture_output=True, timeout=3, env=env)
        match = re.search(r'(\d+)\.(\d+)(?:\.(\d+))?', result.stdout)
        if result.returncode or not match:
            raise RuntimeError(name+': cannot establish executable version at '+actual)
        version = tuple(int(value or 0) for value in match.groups())
        exact = tuple(rule.get('exact', version))
        minimum = tuple(rule.get('min', (0, 0)))
        before = tuple(rule.get('before', (999, 0)))
        if version != exact or version[:2] < minimum or version[:2] >= before:
            expectation = '.'.join(map(str, exact)) if 'exact' in rule else '>='+'.'.join(map(str, minimum))+' <'+'.'.join(map(str, before))
            raise RuntimeError(name+': '+'.'.join(map(str, version))+' at '+actual+'; required '+expectation+'; update the selected tool explicitly')
        report.append({'tool': name, 'executable': actual, 'version': '.'.join(map(str, version))})
    return {'schema': 1, 'platform': [system, machine], 'tools': report, 'heavyweight_calls': 0}


def provision_shellcheck(root, output):
    data = contract(root)['shellcheck_release']
    system = {'Darwin': 'darwin', 'Linux': 'linux'}.get(platform.system())
    arch = {'arm64': 'aarch64', 'aarch64': 'aarch64', 'x86_64': 'x86_64'}.get(platform.machine())
    asset = data['assets'].get(str(system)+'.'+str(arch))
    if not asset:
        raise RuntimeError('no pinned ShellCheck distribution for this platform')
    if not asset['url'].startswith('https://github.com/koalaman/shellcheck/releases/download/v'+data['version']+'/'):
        raise RuntimeError('untrusted ShellCheck distribution URL')
    # Explicit CI output only, never a global install or PATH mutation here.
    output = Path(output).absolute()
    if output.is_symlink() or any(p.is_symlink() for p in output.parents):
        raise RuntimeError('refusing symlinked provisioning output')
    if output.exists() and any(output.iterdir()):
        raise RuntimeError('provisioning output must be empty')
    request = urllib.request.Request(asset['url'], headers={'User-Agent': 'superpowers-plus-toolchain'})
    with urllib.request.urlopen(request, timeout=30) as response:
        raw = response.read(32*1024*1024+1)
    if len(raw) > 32*1024*1024 or hashlib.sha256(raw).hexdigest() != asset['sha256']:
        raise RuntimeError('official ShellCheck archive hash mismatch')
    with tarfile.open(fileobj=io.BytesIO(raw), mode='r:xz') as archive:
        member = archive.getmember('shellcheck-v'+data['version']+'/shellcheck')
        if not member.isfile() or member.size > 128*1024*1024:
            raise RuntimeError('unexpected ShellCheck archive member')
        binary = archive.extractfile(member).read()
    output.mkdir(parents=True, exist_ok=True)
    target = output/'shellcheck'
    with target.open('xb') as stream:
        stream.write(binary)
    target.chmod(0o755)
    print(json.dumps({'provisioned': 'shellcheck', 'version': data['version'], 'archive_sha256': asset['sha256'], 'directory': str(output)}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--provision-shellcheck', type=Path, metavar='EMPTY_DIRECTORY')
    parser.add_argument('--check', action='append', default=[])
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    if args.provision_shellcheck:
        provision_shellcheck(root, args.provision_shellcheck)
    else:
        print(json.dumps(preflight(root, args.check or ['full'])))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError, RuntimeError, subprocess.SubprocessError) as error:
        raise SystemExit('toolchain: STOP: '+str(error))
