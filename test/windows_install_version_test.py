"""Keep Windows numeric-version checks strict for stable and beta installers."""
from pathlib import Path
import sys
import subprocess
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts/release'))
import verify_windows_install as verifier


class UnsupportedSwitchTest(unittest.TestCase):
    def verify(self, *, code=1, encoding='utf-8', message=None, installs=False):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)

            def run(args, timeout):
                self.assertEqual(timeout, 30)
                self.assertNotIn('/VERYSILENT', args)
                self.assertIn(args[1], ('/S', '/s'))
                log = Path(next(arg[5:] for arg in args if arg.startswith('/LOG=')))
                diagnostic = message if message is not None else (
                    'Unsupported /S: use /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- instead.')
                log.write_bytes(diagnostic.encode(encoding))
                if installs:
                    Path(next(arg[5:] for arg in args if arg.startswith('/DIR='))).mkdir()
                return subprocess.CompletedProcess(args, code)

            with patch.object(verifier.subprocess, 'run', side_effect=run) as mock:
                verifier.verify_unsupported_switch(root / 'setup.exe', root)
                self.assertEqual(mock.call_count, 2)

    def test_rejection_requires_exit_diagnostic_and_no_install(self):
        for encoding in ('utf-8', 'utf-16le'):
            with self.subTest(encoding=encoding):
                self.verify(encoding=encoding)
        for kwargs in ({'code': 0}, {'code': 2}, {'installs': True},
                       {'message': 'An unrelated initialization failure'}):
            with self.subTest(kwargs=kwargs), self.assertRaises(RuntimeError):
                self.verify(**kwargs)

    def test_hung_installer_fails_the_smoke_check(self):
        with tempfile.TemporaryDirectory() as tmp:
            with patch.object(verifier.subprocess, 'run',
                              side_effect=subprocess.TimeoutExpired('setup.exe', 30)):
                with self.assertRaises(subprocess.TimeoutExpired):
                    verifier.verify_unsupported_switch(Path('setup.exe'), Path(tmp))


class InstalledVersionTest(unittest.TestCase):
    def verify(self, version, native, installed_version=None, provenance='abc123'):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'pubspec.yaml').write_text(f'version: {version}\n')
            install = root / 'installed'
            assets = install / 'data/flutter_assets'
            assets.mkdir(parents=True)
            (assets / 'pubspec.yaml').write_text(
                f'version: {installed_version or version}\n')
            (install / 'SOURCE.txt').write_text(provenance)
            with patch.object(verifier, '__file__',
                              str(root / 'scripts/release/verify_windows_install.py')):
                with patch.object(verifier.subprocess, 'check_output',
                                  side_effect=[native, 'abc123']):
                    verifier.verify_installed_version(install)

    def test_stable_and_beta_numeric_versions(self):
        for version in ('1.2.10+10128', '1.2.10-beta.1+10128'):
            with self.subTest(version=version):
                self.verify(version, '1.2.10.10128')

    def test_wrong_native_version_still_rejected(self):
        for native in ('1.2.9.10128', '1.2.10.10127'):
            with self.subTest(native=native):
                with self.assertRaisesRegex(RuntimeError, 'Native version mismatch'):
                    self.verify('1.2.10-beta.1+10128', native)

    def test_full_dart_version_including_beta_still_checked(self):
        with self.assertRaisesRegex(RuntimeError, 'Dart payload version mismatch'):
            self.verify('1.2.10-beta.1+10128', '1.2.10.10128',
                        installed_version='1.2.10+10128')

    def test_source_provenance_still_checked(self):
        with self.assertRaisesRegex(RuntimeError, 'source provenance mismatch'):
            self.verify('1.2.10-beta.1+10128', '1.2.10.10128', provenance='other')


if __name__ == '__main__':
    unittest.main()
