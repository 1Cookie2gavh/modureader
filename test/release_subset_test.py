"""A beta subset must contain exactly the requested installers and checksums."""
import hashlib
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts/release'))
from validate_assets import validate


class SubsetReleaseTest(unittest.TestCase):
    def test_exact_subset_and_no_other_platforms(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            names = ['android-arm64.apk', 'macos-arm64.dmg', 'windows-x64-setup.exe']
            for suffix in names:
                path = root / f'Modu-1.2.10-beta.1-{suffix}'
                path.write_bytes(b'fixture')
                path.with_name(path.name + '.sha256').write_text(
                    hashlib.sha256(b'fixture').hexdigest() + '  ' + path.name + '\n')
            targets = 'android,macos-arm64,windows-x64'
            self.assertEqual(validate(root, 'v1.2.10-beta.1', targets=targets), 3)
            with self.assertRaises(ValueError):
                validate(root, 'v1.2.10-beta.1')
            for invalid in ['', 'macos', targets + ',android']:
                with self.assertRaises(ValueError):
                    validate(root, 'v1.2.10-beta.1', targets=invalid)
            ios = root / 'Modu-1.2.10-beta.1-ios-arm64.ipa'
            ios.write_bytes(b'fixture')
            ios.with_name(ios.name + '.sha256').write_text(
                hashlib.sha256(b'fixture').hexdigest() + '  ' + ios.name + '\n')
            targets += ',ios'
            self.assertEqual(validate(root, 'v1.2.10-beta.1', targets=targets), 4)
            (root / 'unrequested.ipa').write_bytes(b'fixture')
            with self.assertRaises(ValueError):
                validate(root, 'v1.2.10-beta.1', targets=targets)


if __name__ == '__main__':
    unittest.main()
