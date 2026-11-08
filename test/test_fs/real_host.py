"""Validate filesystem modules with the bundled fstool in an isolated mpv host."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def run_fixture(script_file: Path, mpv: str | None):
    binary = shutil.which(mpv) if mpv else next(
        (found for name in ('mpvnet.com', 'mpv.com', 'mpv.exe')
         if (found := shutil.which(name))), None)
    if not binary:
        raise RuntimeError('mpv not found; specify --mpv or ELXLIB_MPV_BINARY')
    root = Path(__file__).resolve().parents[2]
    with tempfile.TemporaryDirectory(prefix='elxlib-fs-host-') as directory:
        fixture = Path(directory)
        script = fixture / 'smoke'
        script.mkdir()
        shutil.copy2(script_file, script / 'main.lua')
        data = fixture / 'files 中文 space'
        data.mkdir()
        payload = b'abc\x00xyz'
        (data / 'source.bin').write_bytes(payload)
        report = fixture / 'result.txt'
        log = fixture / 'mpv.log'
        env = dict(os.environ, ELXLIB_TEST_ROOT=str(root), ELXLIB_TEST_REPORT=str(report),
                   ELXLIB_TEST_FILES=str(data))
        command = [binary, f'--config-dir={fixture}', '--idle=yes', '--force-window=no',
                   '--load-scripts=no', '--osc=no', '--terminal=no', '--vo=null', '--ao=null',
                   f'--script={script}', f'--log-file={log}']
        startup = None
        if os.name == 'nt':
            startup = subprocess.STARTUPINFO()
            startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
            startup.wShowWindow = 0
        process = subprocess.Popen(command, env=env, stdout=subprocess.DEVNULL,
                                   stderr=subprocess.DEVNULL, startupinfo=startup)
        try:
            process.wait(timeout=15)
        except subprocess.TimeoutExpired:
            if os.name == 'nt':
                subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
            else:
                process.kill()
            process.wait(timeout=5)
            detail = log.read_text(encoding='utf-8', errors='replace') if log.exists() else ''
            raise RuntimeError(f'filesystem host timed out\n{detail[-6000:]}') from None
        if not report.exists() or process.returncode != 0:
            detail = log.read_text(encoding='utf-8', errors='replace') if log.exists() else ''
            raise RuntimeError(f'filesystem smoke failed (exit {process.returncode})\n{detail[-6000:]}')
        assert (data / 'copied.bin').read_bytes() == payload, 'copied bytes differ'
        assert (data / 'tree-copy' / 'nested.bin').read_bytes() == payload, 'recursive copy differs'
        print(report.read_text(encoding='utf-8').strip())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mpv', default=os.environ.get('ELXLIB_MPV_BINARY'))
    args = parser.parse_args()
    run_fixture(Path(__file__).with_suffix('') / 'smoke.lua', args.mpv)


if __name__ == '__main__':
    main()
