"""Verify packaged Harmony entry points use the existing Modu artwork."""
import json
from pathlib import Path
import re
import struct
import unittest

ROOT = Path(__file__).resolve().parents[1]


class HarmonyIconsTest(unittest.TestCase):
    def test_app_launcher_and_start_window_share_modu_icon(self):
        app = json.loads((ROOT / 'ohos/AppScope/app.json5').read_text())
        module = (ROOT / 'ohos/entry/src/main/module.json5').read_text()
        references = [app['app']['icon']] + re.findall(
            r'"(?:icon|startWindowIcon)"\s*:\s*"([^"]+)"', module)
        self.assertEqual(references, ['$media:modu_app_icon'] * 3)
        icon = (ROOT / 'ohos/AppScope/resources/base/media/modu_app_icon.png').read_bytes()
        self.assertEqual(icon, (ROOT / 'web/icons/Icon-512.png').read_bytes())
        self.assertEqual(icon[:8], b'\x89PNG\r\n\x1a\n')
        self.assertEqual(struct.unpack('>II', icon[16:24]), (512, 512))


if __name__ == '__main__':
    unittest.main()
