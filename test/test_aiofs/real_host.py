"""Run aiofs with real amp callbacks and fstool in an isolated headless host."""
import argparse
import os
from pathlib import Path
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from test_fs.real_host import run_fixture


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mpv', default=os.environ.get('ELXLIB_MPV_BINARY'))
    args = parser.parse_args()
    run_fixture(Path(__file__).with_suffix('') / 'smoke.lua', args.mpv)


if __name__ == '__main__':
    main()
