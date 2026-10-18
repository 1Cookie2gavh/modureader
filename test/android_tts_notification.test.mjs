import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {mkdtempSync, rmSync, readdirSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {test} from 'node:test';

const read = path => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');

test('release shrinking preserves dynamically resolved notification icons', () => {
    const xml = read('android/app/src/main/res/raw/modu_notification_keep.xml');
    const keep = new Set(xml.match(/tools:keep="([^"]+)"/)[1].split(','));
    for (const icon of ['ic_stat_read_aloud', 'ic_stat_tts_exit',
        'audio_service_pause', 'audio_service_play_arrow',
        'audio_service_skip_next', 'audio_service_skip_previous']) {
        assert.ok(keep.has(`@drawable/${icon}`), `Missing keep rule: ${icon}`);
    }
});

test('every Android build applies the silent notification patch', () => {
    assert.match(read('android/build.gradle'), /apply from: 'modu_audio_notification.gradle'/);
    const patch = read('android/modu_audio_notification.gradle');
    for (const setting of ['.setSilent(true)', '.setOnlyAlertOnce(true)',
        '.setDefaults(0)', '.setSound(null)', '.setVibrate(null)',
        'channel.setSound(null, null)', 'channel.enableVibration(false)']) {
        assert.ok(patch.includes(setting), setting);
    }
    assert.match(patch, /android.sourceSets.main.java.setSrcDirs\(\[generated\]\)/);
    assert.match(patch, /dependsOn\(patchTask\)/);
    assert.match(patch, /lines.count\(builderAnchor\) != 1/);
    assert.match(patch, /lines.count\(channelAnchor\) != 1/);
    assert.match(patch, /throw new GradleException/);
});

test('foreground service and media controls are retained across pauses', () => {
    assert.match(read('lib/main.dart'), /androidStopForegroundOnPause: false/);
    assert.match(read('android/app/src/main/AndroidManifest.xml'),
        /android:foregroundServiceType="mediaPlayback"/);
    assert.match(read('lib/service/tts/tts_handler.dart'),
        /androidWillPauseWhenDucked: true/);
});

test('compatibility is off for normal builds and non-vivo/iQOO phones', () => {
    const output = mkdtempSync(join(tmpdir(), 'modu-media-policy-'));
    try {
        execFileSync('javac', ['-d', output,
            fileURLToPath(new URL('../android/audio_service/ModuMediaNotificationPolicy.java', import.meta.url)),
            fileURLToPath(new URL('native/MediaNotificationPolicyTest.java', import.meta.url))]);
        execFileSync('java', ['-cp', output, 'MediaNotificationPolicyTest']);
    } finally {
        rmSync(output, {recursive: true, force: true});
    }
});

test('only opted-in vivo/iQOO notification play bypasses media key forwarding', () => {
    const output = mkdtempSync(join(tmpdir(), 'modu-notification-play-'));
    const root = fileURLToPath(new URL('../', import.meta.url));
    const stubs = join(root, 'test/native/media_notification_stubs');
    try {
        for (const enabled of [false, true]) {
            const policy = join(output, 'ModuMediaNotificationPolicy.java');
            writeFileSync(policy, read('android/audio_service/ModuMediaNotificationPolicy.java')
                .replace('TEST_BUILD = false;', `TEST_BUILD = ${enabled};`));
            execFileSync('javac', ['-d', output, policy,
                join(root, 'android/audio_service/ModuNotificationPlay.java'),
                join(root, 'test/native/NotificationPlayTest.java'),
                ...readdirSync(stubs, {recursive: true}).filter(p => p.endsWith('.java'))
                    .map(p => join(stubs, p))]);
            execFileSync('java', ['-cp', output, 'NotificationPlayTest', String(enabled)]);
        }
    } finally {
        rmSync(output, {recursive: true, force: true});
    }
});

test('workaround retains MediaSession and gates each notification change', () => {
    const patch = read('android/modu_audio_notification.gradle');
    assert.match(patch, /defines.contains\('MODU_IQOO_MEDIA_COMPAT=true'\)/);
    assert.match(patch, /inputs.property\('moduIqooMediaCompat', iqooTest\)/);
    assert.match(patch, /ModuMediaNotificationPolicy.enabled\(ModuMediaNotificationPolicy.TEST_BUILD, Build.BRAND, Build.MANUFACTURER\)/);
    assert.match(patch, /TEST_BUILD = \$\{iqooTest\}/);
    assert.match(read('android/audio_service/ModuMediaNotificationPolicy.java'), /TEST_BUILD = false/);
    assert.match(patch, /Build.VERSION.SDK_INT < 33 \|\| moduMediaCompatEnabled\(\)/);
    assert.match(patch, /moduMediaCompatEnabled\(\) && control.actionCode == PlaybackStateCompat.ACTION_STOP/);
    assert.match(patch, /if \(moduMediaCompatEnabled\(\)\) \{/);
    for (const action of ['notificationCreated = false', 'legacyStopForeground(true)',
        'getNotificationManager().cancel(NOTIFICATION_ID)', 'releaseWakeLock()']) {
        assert.ok(patch.includes(action));
    }
    assert.match(patch, /\[classAnchor, customAnchor, compactAnchor, stopAnchor, playAnchor\].any/);
    assert.match(patch, /receiver.readLines\('UTF-8'\).count/);
    assert.match(patch, /ModuNotificationPlay.handle\(/);
    assert.match(patch, /AudioService.instance.getSessionToken\(\)/);
    assert.match(patch, /moduMediaCompatEnabled\(\)\) ModuMediaNotificationPolicy.sessionPlayCallbacks\+\+/);
    assert.doesNotMatch(patch, /mediaSession\.release|setPlaybackState|androidStopForegroundOnPause/);
});
