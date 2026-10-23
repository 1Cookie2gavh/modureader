import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts/harmony'))
from patch_app import ANCHOR_COUNTS, PATCHES, install, plan


class AppCompatibilityTest(unittest.TestCase):
    def test_removed_onboarding_leaves_one_changelog_sheet_per_entry(self):
        self.assertFalse((ROOT / 'lib/page/onboarding_screen.dart').exists())
        for relative in ('lib/service/initialization_check.dart',
                         'lib/page/settings_page/advanced.dart'):
            source = (ROOT / relative).read_text()
            self.assertEqual(source.count('showCupertinoSheet('), 1)
            self.assertEqual(ANCHOR_COUNTS[relative], 1)
            self.assertNotIn('OnboardingScreen', source)

    def test_sheet_adapter_retains_contents_without_unused_controller(self):
        edits = plan(ROOT)
        for relative in ('lib/widgets/home_navigation_shell.dart',
                         'lib/service/initialization_check.dart',
                         'lib/page/settings_page/advanced.dart'):
            path = ROOT / relative
            original = path.read_text()
            before, after = PATCHES[relative]
            self.assertEqual(original.count(before), ANCHOR_COUNTS.get(relative, 1))
            self.assertNotIn('scrollableBuilder:', edits[path])
            self.assertEqual(edits[path].replace(after, before), original)
            self.assertEqual(path.read_text(), original)

    def test_hero_adapter_only_removes_unsupported_arguments_from_copy(self):
        path = ROOT / 'lib/widgets/page_router/reader_cover_hero.dart'
        original = path.read_text()
        adapted = plan(ROOT)[path]
        self.assertIn('curve: Curves.linear,', original)
        self.assertIn('reverseCurve: Curves.linear,', original)
        self.assertNotIn('curve: Curves.linear,', adapted)
        self.assertNotIn('reverseCurve: Curves.linear,', adapted)
        self.assertIn('transitionOnUserGestures: true', adapted)
        self.assertNotIn('defaultTargetPlatform != TargetPlatform.android', adapted)
        self.assertIn('createRectTween: readerCoverRectTween', adapted)
        self.assertEqual(path.read_text(), original)

    def test_real_source_has_exact_reviewed_callbacks(self):
        originals = {ROOT / name: (ROOT / name).read_bytes() for name in PATCHES}
        edits = plan(ROOT)
        for path, text in edits.items():
            self.assertNotIn('onReorderItem:', text)
            self.assertEqual(path.read_bytes(), originals[path])
            before, after = PATCHES[str(path.relative_to(ROOT))]
            self.assertEqual(text.replace(after, before), originals[path].decode())

    def test_all_current_reorder_callbacks_have_an_adapter(self):
        edits = plan(ROOT)
        for path in (ROOT / 'lib').rglob('*.dart'):
            if 'onReorderItem:' in path.read_text():
                self.assertIn(str(path.relative_to(ROOT)), PATCHES)
                self.assertNotIn('onReorderItem:', edits[path])

    def test_old_to_new_index_normalization_for_all_moves(self):
        for count in range(1, 12):
            for old in range(count):
                for raw_new in range(count + 1):
                    desired = list(range(count))
                    marker = desired[old]
                    desired.insert(raw_new, marker + 100)
                    desired.remove(marker)
                    desired[desired.index(marker + 100)] = marker
                    adapted = list(range(count))
                    target = raw_new - 1 if raw_new > old else raw_new
                    adapted.insert(target, adapted.pop(old))
                    self.assertEqual(adapted, desired)

    def test_local_execution_refused(self):
        with patch.dict(os.environ, {'GITHUB_ACTIONS': 'false'}):
            with self.assertRaisesRegex(ValueError, 'GitHub Actions'):
                install(ROOT)

    def test_missing_anchor_aborts_before_writes_and_double_apply_refused(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp).resolve()
            paths = []
            for relative, (before, _) in PATCHES.items():
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(before * ANCHOR_COUNTS.get(relative, 1))
                paths.append(path)
            paths[-1].write_text('changed')
            env = {'GITHUB_ACTIONS': 'true', 'GITHUB_WORKSPACE': str(root)}
            with patch.dict(os.environ, env), patch('sys.platform', 'linux'):
                with self.assertRaises(ValueError):
                    install(root)
                self.assertEqual(paths[0].read_text(), next(iter(PATCHES.values()))[0])
                paths[-1].write_text(list(PATCHES.values())[-1][0])
                install(root)
                with self.assertRaises(ValueError):
                    install(root)


if __name__ == '__main__':
    unittest.main()
