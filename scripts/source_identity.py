"""Identify build inputs even when a local copy contains uncommitted changes."""
import argparse
import hashlib
import json
from pathlib import Path


def identify(root):
    files = []
    for folder in ('Atelier', 'AtelierTests', 'Atelier.xcodeproj', 'scripts', '.github/workflows'):
        for path in sorted((root / folder).rglob('*')):
            if not path.is_file() or any(p in ('__pycache__', 'xcuserdata') for p in path.parts):
                continue
            if path.suffix in ('.pyc', '.xcuserstate'):
                continue
            if path.is_symlink():
                raise ValueError(f'Build input is a symbolic link: {path}')
            files.append({'path': path.relative_to(root).as_posix(),
                          'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    files.sort(key=lambda f: f['path'])
    digest = hashlib.sha256(json.dumps(files, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    return {'schema': 1, 'source_sha256': digest, 'files': files,
            'scope': 'App, tests, Xcode project, scripts and workflows; excludes docs, work, build, Git metadata'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    report = json.dumps(identify(Path(__file__).resolve().parents[1]), indent=2) + '\n'
    if args.output:
        args.output.write_text(report, encoding='utf8')
    else:
        print(report, end='')
