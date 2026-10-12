import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { writeFileSync, unlinkSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

test('native lint recognizes Riverpod 2 annotations and keeps context checks', () => {
  const root = fileURLToPath(new URL('../', import.meta.url));
  const path = `${root}lib/modu_lint_canary_${process.pid}.dart`;
  writeFileSync(path, `
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
@riverpod
int lintCompatibilityCanary(Object ref, BuildContext context) => 0;
`, { flag: 'wx' });
  let output;
  try {
    try {
      output = execFileSync('dart', ['analyze', path, '--format', 'machine'],
        { cwd: root, encoding: 'utf8', timeout: 120_000 });
    } catch (error) {
      assert.equal(error.status, 2, `Unexpected analyzer failure: ${error.stderr}`);
      output = error.stdout;
    }
    assert.match(output, /AVOID_BUILD_CONTEXT_IN_PROVIDERS/);
    assert.doesNotMatch(output, /RIVERPOD_SYNTAX_ERROR|Missing implementation|Plugin .* threw/);
  } finally {
    unlinkSync(path);
  }
});
