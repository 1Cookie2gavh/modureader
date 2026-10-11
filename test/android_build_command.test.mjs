import test from 'node:test';
import assert from 'node:assert/strict';
import {androidBuildArgs} from '../scripts/build_android.mjs';

test('Android release builds refresh plugins and default to ARM64', () => {
  assert.deepEqual(androidBuildArgs([]), [
    'build', 'apk', '--release', '--target-platform=android-arm64', '--split-per-abi',
  ]);
  assert.throws(() => androidBuildArgs(['--no-pub']), /Remove --no-pub/);
});

test('explicit emulator target and preview identity are preserved', () => {
  const args = ['--target-platform', 'android-arm64,android-x64', '--split-per-abi',
    '--build-name=1.2.6-preview.1', '--build-number=10103'];
  assert.deepEqual(androidBuildArgs(args), ['build', 'apk', '--release', ...args]);
  assert.deepEqual(androidBuildArgs(['--target-platform=android-x64']), [
    'build', 'apk', '--release', '--split-per-abi', '--target-platform=android-x64',
  ]);
});
