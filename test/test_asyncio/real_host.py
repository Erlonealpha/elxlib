"""Run the optional amp smoke test in an isolated headless mpv/mpv.net host."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mpv', default=os.environ.get('ELXLIB_MPV_BINARY'))
    args = parser.parse_args()
    binary = shutil.which(args.mpv) if args.mpv else next(
        (found for name in ('mpvnet.com', 'mpv.com', 'mpv.exe')
         if (found := shutil.which(name))), None)
    if not binary:
        parser.error('mpv not found; specify --mpv or ELXLIB_MPV_BINARY')
    root = Path(__file__).resolve().parents[2]
    with tempfile.TemporaryDirectory(prefix='elxlib-amp-host-') as directory:
        fixture = Path(directory)
        script = fixture / 'smoke'
        script.mkdir()
        shutil.copy2(Path(__file__).with_suffix('') / 'smoke.lua', script / 'main.lua')
        report = fixture / 'result.txt'
        log = fixture / 'mpv.log'
        env = dict(os.environ, ELXLIB_TEST_ROOT=str(root), ELXLIB_TEST_REPORT=str(report))
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
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            detail = log.read_text(encoding='utf-8', errors='replace') if log.exists() else ''
            # Only terminate the tree rooted at the process created above.
            if os.name == 'nt':
                subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
            else:
                process.kill()
            process.wait(timeout=5)
            raise RuntimeError(f'headless amp smoke test timed out\n{detail[-6000:]}') from None
        if not report.exists() or process.returncode != 0:
            detail = log.read_text(encoding='utf-8', errors='replace') if log.exists() else ''
            raise RuntimeError(f'amp smoke failed (exit {process.returncode})\n{detail[-6000:]}')
        print(report.read_text(encoding='utf-8').strip())


if __name__ == '__main__':
    main()
