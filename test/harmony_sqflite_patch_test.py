import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import yaml

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts/harmony'))
import patch_sqflite as adapter


class SnapshotPatchTest(unittest.TestCase):
    def test_exact_anchor_and_duplicate_patch_fail_closed(self):
        original = adapter.IMPORT + '\n' + adapter.ANCHOR + '\n  }\n'
        changed = adapter.transform(original)
        self.assertIn("if (sql === 'MODU_BACKUP_DATABASE')", changed)
        self.assertIn('await backupModuSnapshot(operation, db);', changed)
        for invalid in ('', original + original, changed):
            with self.assertRaises(ValueError):
                adapter.transform(invalid)

    def test_plan_only_overrides_ohos_and_does_not_write_cache(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            config = root / '.dart_tool/package_config.json'
            config.parent.mkdir()
            config.write_text(json.dumps({'packages': [{'name': 'sqflite_ohos', 'rootUri': (root / 'cache').as_uri()}]}))
            (root / 'pubspec.lock').write_text(yaml.safe_dump({'packages': {
                'sqflite_ohos': {'source': 'git', 'description': {'ref': adapter.PIN}}
            }}))
            overlay = root / 'pubspec_overrides.yaml'
            overlay.write_text('dependency_overrides:\n  other: any\n')
            before = overlay.read_bytes()
            files = {
                f'{adapter.NATIVE}/Database.ets': ((adapter.IMPORT + '\n' + adapter.ANCHOR).encode(), 0o644),
                'sqflite_ohos/pubspec.yaml': (b'name: sqflite_ohos\n', 0o644),
            }
            with patch.object(adapter, 'verified_files', return_value=files) as verify:
                result, new_overlay = adapter.plan(root)
            self.assertEqual(verify.call_args.kwargs, {'pin': adapter.PIN, 'repository': adapter.REPOSITORY})
            self.assertEqual(new_overlay['dependency_overrides']['other'], 'any')
            self.assertEqual(set(new_overlay['dependency_overrides']), {'other', 'sqflite_ohos'})
            self.assertIn(f'{adapter.NATIVE}/ModuSnapshot.ets', result)
            self.assertEqual(overlay.read_bytes(), before)
            self.assertFalse((root / 'build').exists())

    def test_installer_rejects_normal_development_checkout(self):
        with patch.dict(os.environ, {'GITHUB_ACTIONS': 'false'}):
            with self.assertRaises(ValueError):
                adapter.install(ROOT)

    def test_install_and_failed_resolution_preserve_inputs(self):
        for fail in (False, True):
            with self.subTest(fail=fail), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp).resolve()
                config = root / '.dart_tool/package_config.json'
                config.parent.mkdir()
                original = {
                    root / 'pubspec_overrides.yaml': b'dependency_overrides: {}\n',
                    root / 'pubspec.lock': b'packages: {}\n',
                    config: b'{"packages": []}\n',
                }
                for path, data in original.items():
                    path.write_bytes(data)
                files = {'sqflite_ohos/pubspec.yaml': (b'name: sqflite_ohos\n', 0o644)}
                overlay = {'dependency_overrides': {'sqflite_ohos': {
                    'path': str(adapter.DESTINATION / adapter.PACKAGE)}}}

                def pub_get(command, **kwargs):
                    self.assertEqual(command, ['/isolated/flutter', 'pub', 'get'])
                    config.write_text(json.dumps({'packages': [{
                        'name': adapter.PACKAGE,
                        'rootUri': (root / adapter.DESTINATION / adapter.PACKAGE).as_uri(),
                    }]}))
                    if fail:
                        (root / 'pubspec.lock').write_text('partial resolution')
                        raise subprocess.CalledProcessError(1, command)

                with patch.object(adapter, 'assert_runner', return_value=Path('/isolated/flutter')), \
                        patch.object(adapter, 'plan', return_value=(files, overlay)), \
                        patch.object(adapter.subprocess, 'run', side_effect=pub_get):
                    if fail:
                        with self.assertRaises(subprocess.CalledProcessError):
                            adapter.install(root)
                        for path, data in original.items():
                            self.assertEqual(path.read_bytes(), data)
                    else:
                        adapter.install(root)
                        self.assertEqual(yaml.safe_load((root / 'pubspec_overrides.yaml').read_text()), overlay)
                        self.assertTrue((root / adapter.DESTINATION / 'PROVENANCE.json').is_file())

    def test_workflow_installs_snapshot_adapter_before_build(self):
        source = (ROOT / '.github/workflows/harmony-cloud.yml').read_text()
        self.assertLess(source.index('python3 scripts/harmony/patch_sqflite.py'), source.index('name: Build unsigned HAP'))


if __name__ == '__main__':
    unittest.main()
