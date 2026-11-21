#!/usr/bin/env python3
"""Verify inspect/apply against isolated Canvas storage, without GTK or providers."""

import fcntl
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile

COYOTE = Path(__file__).resolve().parents[2] / 'bin' / 'coyote'
LIVE = '550e8400-e29b-41d4-a716-446655440000'
ORPHAN = '550e8400-e29b-41d4-a716-446655440001'
STRAY = 'b' * 64 + '.rgba'
KEY = 'f50e8400-e29b-41d4-a716-446655440000'
CHECKPOINT = 'f50e8400-e29b-41d4-a716-446655440001'


def private(path, data):
    path.write_bytes(data)
    path.chmod(0o600)
    return path


def tree(directory):
    return {p.name: p.read_bytes() for p in directory.iterdir()}


def log_bytes(uuid):
    return (json.dumps(dict(type='session', version=3, id=uuid)) + '\n').encode()


def main():
    with tempfile.TemporaryDirectory(prefix='canvas-reclaim-') as scratch:
        root = Path(scratch).resolve()
        home = root / 'home'
        cwd = root / 'project'
        cwd.mkdir()
        sessions = home / '.coyote' / 'sessions'
        parent = sessions / ('--' + str(cwd).strip('/').replace('/', '-') + '--')
        parent.mkdir(parents=True)
        env = dict(PATH=os.defpath, HOME=str(home), LC_ALL='C',
                   COYOTE_FRONTEND='gui', COYOTE_RECURSION_DEPTH='invalid')

        def run(*args, error=None):
            command = [str(COYOTE), 'canvas', 'reclaim', *args]
            p = subprocess.run(command, cwd=cwd, env=env, capture_output=True,
                               timeout=10, stdin=subprocess.DEVNULL)
            if error is None:
                assert p.returncode == 0 and not p.stderr, (command, p)
                return p.stdout
            assert p.returncode != 0 and not p.stdout, (command, p)
            assert error in p.stderr, (command, p)

        log = private(parent / f'2026-11-21_{LIVE}.jsonl', log_bytes(LIVE))
        side = parent / f'{LIVE}.canvas'
        side.mkdir(mode=0o700)
        pixels = b'\x12\x34\x56\x00'  # Preserve even RGB hidden by alpha.
        digest = hashlib.sha256(b'coyote-rgba8-v1: 1: 1\n' + pixels).hexdigest()
        referenced = private(side / (digest + '.rgba'), pixels)
        state = [0, 0, 1, 1, 1, []]
        manifest_bytes = json.dumps(dict(
            version=2, strokes=[], revisions=[[0, KEY, state], [1, CHECKPOINT, state]],
            base=2, draft=state, assets=[digest, ' ' * 64],
        )).encode()
        manifest = private(side / 'canvas.json', manifest_bytes)
        unreferenced = private(side / STRAY, b'old raster')
        temp = private(side / '.canvas.tmp', b'interrupted')
        other = sessions / 'other-project'
        other.mkdir()
        other_side = other / side.name
        other_side.mkdir(mode=0o700)
        private(other_side / STRAY, b'unrelated workspace')
        private(other / log.name, log_bytes(LIVE))
        before = tree(side)
        assert run(LIVE) == b'Would remove 2 file(s), 21 byte(s).\n'
        assert tree(side) == before and tree(other_side) == {STRAY: b'unrelated workspace'}
        run('--orphan', '--apply', LIVE, error=b'refusing unsafe')

        # Both writer locks and the long-lived editor lease block cleanup.
        for lock in (parent / f'.{LIVE}.session-writer', side / '.writer',
                     side / '.gtk-writer'):
            if not lock.exists():
                private(lock, b'')
            snapshot = tree(side)
            with lock.open('rb+') as handle:
                fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
                run('--apply', LIVE, error=b'is busy')
                assert tree(side) == snapshot

        # Corrupt reference and manifest; nothing is reclaimed if either fails.
        for path, wrong, correct in ((referenced, b'bad!', pixels),
                                     (manifest, b'{"version":9}', manifest_bytes),
                                     (log, log_bytes(ORPHAN), log_bytes(LIVE))):
            private(path, wrong)
            snapshot = tree(side)
            run('--apply', LIVE, error=b'refusing unsafe')
            assert tree(side) == snapshot
            private(path, correct)
        referenced.unlink()
        run('--apply', LIVE, error=b'refusing unsafe')
        assert unreferenced.exists()
        private(referenced, pixels)

        # Validate the whole flat layout before unlinking any candidate.
        extra = side / 'unknown'
        extra.mkdir()
        run('--apply', LIVE, error=b'refusing unsafe')
        assert unreferenced.exists() and temp.exists()
        extra.rmdir()
        temp.unlink()
        temp.symlink_to(referenced)
        run('--apply', LIVE, error=b'refusing unsafe')
        assert temp.is_symlink() and unreferenced.exists()
        temp.unlink()
        temp.hardlink_to(referenced)
        run('--apply', LIVE, error=b'refusing unsafe')
        assert unreferenced.exists()
        temp.unlink()
        private(temp, b'interrupted')
        unreferenced.chmod(0o644)
        run('--apply', LIVE, error=b'refusing unsafe')
        assert unreferenced.exists() and temp.exists()
        unreferenced.chmod(0o600)
        twin = private(parent / f'{LIVE}.jsonl', log_bytes(LIVE))
        run('--apply', LIVE, error=b'refusing unsafe')
        twin.unlink()
        assert run('--apply', LIVE) == b'Removed 2 file(s), 21 byte(s).\n'
        assert log.read_bytes() == log_bytes(LIVE)
        assert tree(side) == {'canvas.json': manifest_bytes, referenced.name: pixels,
                              '.writer': b'', '.gtk-writer': b''}
        assert tree(other_side) == {STRAY: b'unrelated workspace'}
        assert run('--apply', LIVE) == b'Removed 0 file(s), 0 byte(s).\n'

        # Interrupted fork/deletion can leave a logless, incomplete sidecar.
        orphan = parent / f'{ORPHAN}.canvas'
        orphan.mkdir(mode=0o700)
        private(orphan / 'canvas.json', b'incomplete')
        private(orphan / STRAY, b'incomplete asset')
        private(orphan / '.writer', b'')
        run('--apply', ORPHAN, error=b'no matching session log')
        assert run('--orphan', ORPHAN) == (
            b'Would remove 3 file(s), 26 byte(s) and the logless Canvas directory.\n')
        with (orphan / '.writer').open('rb+') as handle:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
            run('--orphan', '--apply', ORPHAN, error=b'is busy')
        dangling = parent / f'fork_{ORPHAN}.jsonl'
        dangling.symlink_to('missing')
        run('--orphan', '--apply', ORPHAN, error=b'refusing unsafe')
        dangling.unlink()
        odd = private(parent / f'legacy-{ORPHAN}-old.jsonl', log_bytes(ORPHAN))
        run('--orphan', '--apply', ORPHAN, error=b'refusing unsafe')
        odd.unlink()
        assert run('--orphan', '--apply', ORPHAN) == (
            b'Removed 3 file(s), 26 byte(s) and the logless Canvas directory.\n')
        assert not orphan.exists()
        assert (parent / f'.{ORPHAN}.session-writer').is_file()
        orphan.symlink_to(side, target_is_directory=True)
        run('--orphan', '--apply', ORPHAN, error=b'refusing unsafe')
        assert tree(side)['canvas.json'] == manifest_bytes and orphan.is_symlink()
        orphan.unlink()
        orphan.mkdir(mode=0o700)
        assert run('--apply', '--orphan', ORPHAN) == (
            b'Removed 0 file(s), 0 byte(s) and the logless Canvas directory.\n')
        assert not orphan.exists()
        run('--orphan', '--apply', ORPHAN, error=b'no matching session log')
        run('--apply', '--apply', LIVE, error=b'repeated')
        run('--apply', LIVE[:-1], error=b'full lowercase session UUID')

        # Do not resolve the project entry into another project's storage.
        parked = sessions / 'parked'
        parent.rename(parked)
        parent.symlink_to(other, target_is_directory=True)
        run('--apply', LIVE, error=b'symlinked project session directory')
        assert tree(other_side) == {STRAY: b'unrelated workspace'}

    print('Canvas reclaim: inspection, exact cleanup, contention, and refusal checks passed.')


if __name__ == '__main__':
    main()
