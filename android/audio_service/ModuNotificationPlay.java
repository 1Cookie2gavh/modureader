package com.ryanheise.audioservice;

import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.view.KeyEvent;
import android.support.v4.media.session.MediaControllerCompat;
import android.support.v4.media.session.MediaSessionCompat;

/** Avoid forwarding audio_service's synthetic mute key through system key filtering. */
public final class ModuNotificationPlay {
    @SuppressWarnings("deprecation")
    public static boolean handle(Context context, Intent intent, MediaSessionCompat.Token token) {
        if (!ModuMediaNotificationPolicy.playActionEnabled(ModuMediaNotificationPolicy.TEST_BUILD,
                Build.VERSION.SDK_INT, Build.BRAND, Build.MANUFACTURER)
                || token == null || intent == null
                || !Intent.ACTION_MEDIA_BUTTON.equals(intent.getAction())) return false;
        KeyEvent event = intent.getParcelableExtra(Intent.EXTRA_KEY_EVENT);
        if (event == null || event.getAction() != KeyEvent.ACTION_DOWN
                || event.getKeyCode() != KeyEvent.KEYCODE_MUTE) return false;
        ModuMediaNotificationPolicy.notificationPlayRequests++;
        new MediaControllerCompat(context, token).getTransportControls().play();
        return true;
    }
}
