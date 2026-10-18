"""OHOS-only native snapshots. Copy the pinned adapter; never modify PUB_CACHE.

Run after initial OHOS pub get in a fresh Actions checkout. Local diagnosis can
use plan() in its disposable copy, just like the existing WebView/UI adapters.
"""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

import yaml

from patch_webview import assert_runner, package_roots, verified_files

PIN = '5ef0761001378455e872e46d1c0620d39dcc1002'
REPOSITORY = 'https://gitcode.com/CPF-Flutter/flutter_sqflite.git'
PACKAGE = 'sqflite_ohos'
DESTINATION = Path('build/harmony-sqflite-adapter')
NATIVE = f'{PACKAGE}/ohos/src/main/ets/io/flutter/plugins/sqflite'
IMPORT = "import { DatabaseHelper } from './DatabaseHelper';"
ANCHOR = '''  public static async execute(operation: Operation, db: relationalStore.RdbStore): Promise<void> {
    const sql = operation.getSqlCommand().getSql();'''


def transform(source):
    if (source.count(IMPORT) != 1 or source.count(ANCHOR) != 1 or
            'backupModuSnapshot' in source):
        raise ValueError('sqflite snapshot anchors changed; re-audit required')
    return source.replace(IMPORT, IMPORT + "\nimport { backupModuSnapshot } from './ModuSnapshot';").replace(
        ANCHOR, ANCHOR + '''
    if (sql === 'MODU_BACKUP_DATABASE') {
      await backupModuSnapshot(operation, db);
      return;
    }''')


def plan(root):
    roots = package_roots(root)
    entry = yaml.safe_load((root / 'pubspec.lock').read_text())['packages'][PACKAGE]
    if entry['source'] != 'git':
        raise ValueError('sqflite_ohos must initially resolve to the pinned Git package')
    files = verified_files(roots[PACKAGE], PACKAGE, entry['description'],
                           pin=PIN, repository=REPOSITORY)
    name = f'{NATIVE}/Database.ets'
    data, mode = files[name]
    files[name] = (transform(data.decode()).encode(), mode)
    files[f'{NATIVE}/ModuSnapshot.ets'] = (
        Path(__file__).with_name('sqflite_snapshot.ets').read_bytes(), 0o644)
    overlay = yaml.safe_load((root / 'pubspec_overrides.yaml').read_text())
    overlay['dependency_overrides'][PACKAGE] = {'path': str(DESTINATION / PACKAGE)}
    return files, overlay


def install(root):
    root = root.resolve()
    flutter = assert_runner(root)
    destination = root / DESTINATION
    inputs = [root / path for path in (
        'pubspec_overrides.yaml', 'pubspec.lock', '.dart_tool/package_config.json')]
    if (destination.exists() or destination.is_symlink() or
            (root / 'build').is_symlink() or any(path.is_symlink() for path in inputs)):
        raise ValueError('Use a fresh checkout without symlink build/resolution files')
    files, overlay = plan(root)
    originals = {path: path.read_bytes() for path in inputs}
    destination.parent.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix='.sqflite-', dir=destination.parent))
    published = False
    try:
        for name, (data, mode) in files.items():
            target = stage / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            target.chmod(mode)
        (stage / 'PROVENANCE.json').write_text(json.dumps({
            'repository': REPOSITORY, 'commit': PIN,
            'files': {name: hashlib.sha256(data).hexdigest() for name, (data, _) in files.items()},
        }, indent=2) + '\n')
        stage.rename(destination)
        published = True
        inputs[0].write_text(yaml.safe_dump(overlay, sort_keys=False))
        subprocess.run([str(flutter), 'pub', 'get'], cwd=root, check=True)
        if package_roots(root)[PACKAGE] != destination / PACKAGE:
            raise ValueError('pub get did not select the OHOS snapshot adapter')
    except BaseException:
        if published:
            for path, data in originals.items():
                path.write_bytes(data)
        raise
    finally:
        if not published:
            shutil.rmtree(stage)
    print('Installed pinned OHOS native snapshot adapter.')


if __name__ == '__main__':
    try:
        install(Path.cwd())
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
