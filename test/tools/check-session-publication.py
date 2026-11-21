#!/usr/bin/env python3
"""Offline fault injection for guarded JSONL publication and fork rollback."""

import base64
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import tempfile
import zlib

ROOT = Path(__file__).resolve().parents[2]
WORKER = ROOT / 'test' / 'bin' / 'session_publication_worker'
SOURCE = '550e8400-e29b-41d4-a716-446655440000'
DRAWING = 'f50e8400-e29b-41d4-a716-446655440000'
PIXELS = b'\x12\x34\x56\x00'


def png():
    def chunk(kind, data):
        return (struct.pack('!I', len(data)) + kind + data
                + struct.pack('!I', zlib.crc32(kind + data)))

    return (b'\x89PNG\r\n\x1a\n'
            + chunk(b'IHDR', struct.pack('!IIBBBBB', 1, 1, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(b'\0' + PIXELS))
            + chunk(b'IEND', b''))


def private(path, data):
    path.write_bytes(data)
    path.chmod(0o600)
    return path


def encode(value):
    return (json.dumps(value, separators=(',', ':')) + '\n').encode()


def run(scratch):
    shim = scratch / 'fsync.so'
    subprocess.run(['cc', '-std=c11', '-Wall', '-Wextra', '-Wpedantic', '-Werror',
                    '-shared', '-fPIC', str(ROOT / 'test/native/session_publication_fsync.c'),
                    '-o', str(shim)], check=True, timeout=15)
    home = scratch / 'home'
    home.mkdir()

    def project(name):
        cwd = scratch / name
        cwd.mkdir()
        return str(cwd), home / '.coyote' / 'sessions' / (
            '--' + str(cwd).strip('/').replace('/', '-') + '--')

    def invoke(parent, fault, status, *args, trace=None):
        env = dict(HOME=str(home), PATH=os.defpath, LC_ALL='C', LD_PRELOAD=str(shim),
                   COYOTE_PUBLICATION_TEST_DIR=str(parent),
                   COYOTE_PUBLICATION_TEST_FAULT=fault)
        process = subprocess.run([str(WORKER), *args], env=env, capture_output=True,
                                 stdin=subprocess.DEVNULL, timeout=10)
        assert process.returncode == status, (args, process)
        traces = [row for row in process.stderr.splitlines() if row.startswith(b'fsync ')]
        assert traces == (trace if trace is not None else {
            'stage': [b'fsync stage fail'],
            'directory': [b'fsync stage pass', b'fsync directory fail'],
            'none': [b'fsync stage pass', b'fsync directory pass'],
        }[fault]), (args, process)
        return process.stdout.strip(), process.stderr

    for fault in ('stage', 'directory', 'none'):
        cwd, parent = project('create-' + fault)
        out, err = invoke(parent, fault, int(fault != 'none'), 'create', cwd)
        assert not list(parent.glob('.coyote-session-*'))
        logs = list(parent.glob('*.jsonl'))
        if fault == 'stage':
            assert not out and not logs and b'Cannot publish session header' in err
        else:
            log, = logs
            header = json.loads(log.read_bytes())
            assert header['version'] == 3 and header['id'] == log.stem and header['cwd'] == cwd
            if fault == 'directory':
                assert not out and log.stem.encode() in err and b'durability uncertain' in err
            else:
                assert out == log.stem.encode()

    cwd, parent = project('source')
    parent.mkdir()
    log = parent / (SOURCE + '.jsonl')
    side = parent / (SOURCE + '.canvas')
    side.mkdir(mode=0o700)
    digest = hashlib.sha256(b'coyote-rgba8-v1: 1: 1\n' + PIXELS).hexdigest()
    asset = digest + '.rgba'
    private(side / asset, PIXELS)
    state = [0, 0, 1, 1, 1, []]
    manifest = private(side / 'canvas.json', encode(dict(
        version=2, strokes=[], revisions=[[0, DRAWING, state]], base=1,
        draft=state, assets=[digest])))
    user = encode(dict(type='message', message=dict(role='user', content=[dict(
        type='image', media_type='image/png', width=1, height=1, drawingId=DRAWING,
        revisionId=DRAWING, data=base64.b64encode(png()).decode(), label='fixture')])))
    assistant = encode(dict(type='message', message=dict(role='assistant', content=[dict(
        type='text', text='answer')])))
    original = encode(dict(type='session', version=3, id=SOURCE, cwd=cwd)) + user + assistant
    private(log, original)
    original_manifest = manifest.read_bytes()
    for fault, status in [('stage', 1), ('directory', 2), ('none', 0)]:
        cwd, target = project('fork-' + fault)
        out, err = invoke(target, fault, status, 'fork', SOURCE, cwd)
        assert log.read_bytes() == original and manifest.read_bytes() == original_manifest
        assert (side / asset).read_bytes() == PIXELS
        assert not list(target.glob('.coyote-session-*'))
        if fault == 'stage':
            assert not out and not list(target.glob('*.jsonl'))
            assert not list(target.glob('*.canvas'))
            assert b'Cannot publish fork' in err
        else:
            fork, = target.glob('*.jsonl')
            assert fork.stem != SOURCE
            assert fork.read_bytes().endswith(user + assistant)
            fork_side = target / (fork.stem + '.canvas')
            assert (fork_side / asset).read_bytes() == PIXELS
            fork_manifest = json.loads((fork_side / 'canvas.json').read_bytes())
            assert fork_manifest['revisions'] == [[0, DRAWING, state]]
            if fault == 'directory':
                assert not out and fork.stem.encode() in err and b'durability uncertain' in err
            else:
                assert out == fork.stem.encode()

    # Exercise the legacy migration caller as well as the native replace API.
    image = json.loads(user)['message']['content'][0]
    legacy_message = dict(role='user', content=[dict(type='text', text='legacy')])
    source_legacy = encode(dict(version=1, id=SOURCE, createdAt=1000,
                                workDir=json.loads(original.splitlines()[0])['cwd']))
    source_legacy += encode(legacy_message)
    for fault in ('stage', 'directory', 'none'):
        private(log, source_legacy)
        out, err = invoke(parent, fault, int(fault != 'none'), 'migrate',
                          SOURCE, json.dumps(image))
        assert not out and not list(parent.glob('.coyote-session-*'))
        assert manifest.read_bytes() == original_manifest
        if fault == 'stage':
            assert log.read_bytes() == source_legacy
            assert b'Cannot publish Canvas session migration' in err
        else:
            header, prior, turn = map(json.loads, log.read_bytes().splitlines())
            assert header['id'] == SOURCE and header['version'] == 3
            assert prior == dict(type='message', message=legacy_message)
            assert turn['message']['content'] == [image]
            assert (b'durability uncertain' in err) == (fault == 'directory')
    private(log, original)

    _, directory = project('publication-modes')
    directory.mkdir()
    target = private(directory / (SOURCE + '.jsonl'), b'existing')
    stage = private(directory / '.coyote-session-fixture', b'new content')
    out, _ = invoke(directory, 'none', 0, 'publish', str(stage), str(target),
                    trace=[b'fsync stage pass'])
    assert out == b'NOT_PUBLISHED' and target.read_bytes() == b'existing' and stage.exists()

    for fault in ('stage', 'directory', 'none'):
        private(target, b'existing')
        private(stage, b'migrated')
        out, _ = invoke(directory, fault, 0, 'replace', str(stage), str(target))
        expected = dict(stage=b'NOT_PUBLISHED', directory=b'UNCERTAIN', none=b'DURABLE')
        assert out == expected[fault]
        assert stage.exists() == (fault == 'stage')
        assert target.read_bytes() == (b'existing' if fault == 'stage' else b'migrated')

    alias = directory / '.coyote-session-alias'
    alias.symlink_to(target)
    out, _ = invoke(directory, 'none', 0, 'replace', str(alias), str(target), trace=[])
    assert out == b'NOT_PUBLISHED' and alias.is_symlink() and target.read_bytes() == b'migrated'
    stage = private(directory / '.coyote-session-fixture', b'new content')
    out, _ = invoke(directory, 'none', 0, 'publish', str(stage), str(log), trace=[])
    assert out == b'NOT_PUBLISHED' and stage.exists() and log.read_bytes() == original


if __name__ == '__main__':
    with tempfile.TemporaryDirectory(prefix='coyote-publication-') as path:
        run(Path(path).resolve())
    print('Session publication: sync ordering, no replacement, and Canvas rollback verified.')
