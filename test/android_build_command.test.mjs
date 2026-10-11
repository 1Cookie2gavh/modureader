import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync, mkdirSync, writeFileSync, readFileSync, realpathSync, existsSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {spawnSync} from 'node:child_process';
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

test('emulator uses the pinned SDK parser and preserves the runner original', () => {
  const workflow = readFileSync(new URL('../.github/workflows/build.yaml', import.meta.url), 'utf8');
  assert.match(workflow, /cmdline-tools-version: '12266719'/);
  const block = workflow.split('- name: Use the same SDK parser for the emulator runner')[1]
    .split('- name: Load dedicated release signing identity')[0];
  const script = block.split('run: |\n')[1].replace(/^          /gm, '');
  for (const scenario of ['older', 'same', 'missing', 'backup-exists', 'wrong-version']) {
    const root = mkdtempSync(join(tmpdir(), 'modu-sdk-parser-'));
    try {
      const tools = join(root, 'cmdline-tools');
      const latest = join(tools, 'latest');
      const selected = scenario === 'same' ? latest : join(tools, '16.0');
      mkdirSync(join(selected, 'bin'), {recursive: true});
      writeFileSync(join(selected, 'source.properties'), `Pkg.Revision=${scenario === 'wrong-version' ? '12.0' : '16.0'}\n`);
      writeFileSync(join(selected, 'bin/sdkmanager'), '#!/bin/sh\necho 16.0\n', {mode: 0o755});
      if (['older', 'backup-exists', 'wrong-version'].includes(scenario)) {
        mkdirSync(latest);
        writeFileSync(join(latest, 'original'), 'keep');
      }
      if (scenario === 'backup-exists') mkdirSync(join(tools, 'modu-runner-original'));
      const result = spawnSync('bash', ['-eu', '-c', script], {
        env: {...process.env, ANDROID_HOME: root, PATH: `${selected}/bin:${process.env.PATH}`}, encoding: 'utf8',
      });
      if (['backup-exists', 'wrong-version'].includes(scenario)) {
        assert.notEqual(result.status, 0);
        assert.equal(readFileSync(join(latest, 'original'), 'utf8'), 'keep');
      } else {
        assert.equal(result.status, 0, result.stderr);
        assert.equal(realpathSync(latest), realpathSync(selected));
        if (scenario === 'older') assert.equal(readFileSync(join(tools, 'modu-runner-original/original'), 'utf8'), 'keep');
        else assert.equal(existsSync(join(tools, 'modu-runner-original')), false);
      }
    } finally {
      rmSync(root, {recursive: true, force: true});
    }
  }
});
