"""Keep Windows numeric-version checks strict for stable and beta installers."""
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts/release'))
import verify_windows_install as verifier


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
