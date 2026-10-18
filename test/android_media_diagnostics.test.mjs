import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {test} from 'node:test';
const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const native = read('android/app/src/main/kotlin/com/modu/reader/MediaDiagnosticsPlugin.kt');

test('diagnostic observer only reads own notifications and their session token', () => {
  assert.match(native, /manager.activeNotifications.filter \{ it.packageName == context.packageName \}/);
  assert.match(native, /Notification.EXTRA_MEDIA_SESSION/);
  assert.match(native, /candidate.packageName == context.packageName/);
  assert.match(native, /candidate.registerCallback\(callback, handler\)/);
  assert.doesNotMatch(native, /transportControls|startForeground|setPlaybackState|getActiveSessions|bindService/);
  assert.doesNotMatch(read('android/app/src/main/AndroidManifest.xml'), /MEDIA_CONTENT_CONTROL|BIND_NOTIFICATION_LISTENER_SERVICE/);
});

test('diagnostics are registered, opt-in, bounded and detached with engine', () => {
  assert.match(read('android/app/src/main/kotlin/com/modu/reader/MainActivity.kt'), /plugins.add\(MediaDiagnosticsPlugin\(\)\)/);
  assert.match(read('lib/service/tts/media_diagnostics.dart'), /bool.fromEnvironment\('MODU_MEDIA_DIAGNOSTICS'\)/);
  assert.match(read('lib/main.dart'), /MediaDiagnostics.enabled && AnxPlatform.isAndroid/);
  assert.match(native, /count >= 2000/);
  assert.match(native, /postDelayed\(this, 2000\)/);
  assert.match(native, /unregisterCallback\(callback\)/);
  assert.match(native, /removeCallbacks\(poll\)/);
  assert.match(native, /override fun onDetachedFromEngine[\s\S]*?stop\(\)/);
});
