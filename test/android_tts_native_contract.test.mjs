import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {test} from 'node:test';

const root = new URL('../', import.meta.url);
const read = path => readFileSync(new URL(path, root), 'utf8');

test('Android builds resolve the patched audio backend', () => {
    assert.match(read('pubspec.yaml'), /dependency_overrides:[\s\S]*?\n  audioplayers_android:\s+path: third_party\/audioplayers_android/);
});

test('starting Android speech reports native playback and acquires its wake lock', () => {
    const source = read('third_party/audioplayers_android/android/src/main/kotlin/xyz/luan/audioplayers/player/MediaPlayerWrapper.kt');
    const start = source.match(/override fun start\(\) \{([\s\S]*?)\n    \}/)?.[1];
    assert.ok(start);
    assert.match(start, /setRate\(wrappedPlayer.rate\)/);
    assert.match(start, /\n\s*mediaPlayer.start\(\)/);
    assert.ok(start.indexOf('setRate(') < start.lastIndexOf('mediaPlayer.start()'));
});

test('lazy native creation honors the context set before the first audio source', () => {
    const source = read('third_party/audioplayers_android/android/src/main/kotlin/xyz/luan/audioplayers/player/MediaPlayerWrapper.kt');
    const create = source.match(/private fun createMediaPlayer[\s\S]*?return mediaPlayer/)?.[0];
    assert.match(create, /if \(wrappedPlayer.context.stayAwake\)/);
    assert.match(create, /mediaPlayer.setWakeMode\(wrappedPlayer.applicationContext, PowerManager.PARTIAL_WAKE_LOCK\)/);
});


test('MiMo native pitch is validated, preserves speed and does not resume paused audio', () => {
    const wrapped = read('third_party/audioplayers_android/android/src/main/kotlin/xyz/luan/audioplayers/player/WrappedPlayer.kt');
    const setter = wrapped.slice(wrapped.indexOf('    var pitch ='), wrapped.indexOf('    var releaseMode ='));
    assert.match(setter, /value.isFinite\(\).*0\.5f\.\.2\.0f/);
    assert.match(setter, /playerMode == MEDIA_PLAYER/);
    assert.match(setter, /if \(playing && prepared\) player\?\.setRate\(rate\)/);
    assert.doesNotMatch(setter, /\.start\(|\.resume\(/);
    const media = read('third_party/audioplayers_android/android/src/main/kotlin/xyz/luan/audioplayers/player/MediaPlayerWrapper.kt');
    assert.match(media, /setSpeed\(rate\)\.setPitch\(wrappedPlayer.pitch\)/);
    const channel = read('third_party/audioplayers_android/android/src/main/kotlin/xyz/luan/audioplayers/AudioplayersPlugin.kt');
    assert.match(channel, /"setPitch" -> \{[\s\S]*?player.pitch = pitch.toFloat\(\)/);
});
