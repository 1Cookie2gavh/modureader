package com.modu.reader

import android.Manifest
import android.app.ActivityManager
import android.app.Notification
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.media.MediaMetadata
import android.graphics.drawable.Icon
import com.ryanheise.audioservice.ModuMediaNotificationPolicy
import android.media.session.MediaController
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

/** Read-only, own-app diagnostics. No notification-listener permission or service binding.
 * Started only by the explicitly enabled diagnostic Dart build. */
class MediaDiagnosticsPlugin : FlutterPlugin {
    private lateinit var context: Context
    private var channel: MethodChannel? = null
    private val handler = Handler(Looper.getMainLooper())
    private var running = false
    private var controller: MediaController? = null
    private var lastSnapshot: Map<String, Any>? = null
    private var lastSent = 0L
    private var count = 0
    private var lastState: Map<String, Any>? = null
    private var lastMetadata: Map<String, Any>? = null

    private fun emit(fields: Map<String, Any>) {
        if (!running || count >= 2000) return
        count++
        channel?.invokeMethod("event", mapOf("source" to "android") + fields)
        if (count == 2000) stop()
    }

    private fun stateFields(state: PlaybackState?): Map<String, Any> {
        val actions = state?.actions ?: 0L
        return mapOf(
            "statePresent" to (state != null), "state" to (state?.state ?: -1),
            "actions" to actions, "errorPresent" to (!state?.errorMessage.isNullOrEmpty()),
            "canPlay" to (actions and PlaybackState.ACTION_PLAY != 0L),
            "canPause" to (actions and PlaybackState.ACTION_PAUSE != 0L),
            "canToggle" to (actions and PlaybackState.ACTION_PLAY_PAUSE != 0L),
        )
    }

    private val callback = object : MediaController.Callback() {
        override fun onPlaybackStateChanged(state: PlaybackState?) {
            val fields = stateFields(state)
            if (fields != lastState) {
                lastState = fields
                emit(mapOf("event" to "state") + fields)
            }
        }
        override fun onMetadataChanged(metadata: MediaMetadata?) {
            // Read only presence; never return title, chapter, art URI or extras.
            val fields = metadataFields(metadata)
            if (fields != lastMetadata) {
                lastMetadata = fields
                emit(mapOf("event" to "metadata") + fields)
            }
        }
        override fun onSessionDestroyed() {
            emit(mapOf("event" to "destroyed"))
            detachController()
        }
    }

    private fun metadataFields(metadata: MediaMetadata?): Map<String, Any> = mapOf(
        "titlePresent" to (!metadata?.getText(MediaMetadata.METADATA_KEY_TITLE).isNullOrEmpty()),
        "subtitlePresent" to (!metadata?.getText(MediaMetadata.METADATA_KEY_DISPLAY_SUBTITLE).isNullOrEmpty()),
        "artPresent" to (metadata?.containsKey(MediaMetadata.METADATA_KEY_ART) == true ||
            metadata?.containsKey(MediaMetadata.METADATA_KEY_ALBUM_ART) == true ||
            metadata?.containsKey(MediaMetadata.METADATA_KEY_ART_URI) == true),
    )

    private fun detachController() {
        try { controller?.unregisterCallback(callback) } catch (_: Exception) {}
        controller = null
        lastState = null
        lastMetadata = null
    }

    @Suppress("DEPRECATION")
    private fun snapshot(): Map<String, Any> {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        // getActiveNotifications returns only notifications posted by this app.
        val posted = manager.activeNotifications.filter { it.packageName == context.packageName }
        val notification = posted.firstOrNull {
            it.notification.channelId == "com.modu.reader.tts.channel.audio"
        }?.notification
        val token = notification?.extras?.getParcelable<MediaSession.Token>(Notification.EXTRA_MEDIA_SESSION)
        if (token != null && controller?.sessionToken != token) {
            detachController()
            val candidate = MediaController(context, token)
            if (candidate.packageName == context.packageName) {
                controller = candidate
                candidate.registerCallback(callback, handler)
            }
        }
        val notificationChannel = manager.getNotificationChannel("com.modu.reader.tts.channel.audio")
        val groupBlocked = if (Build.VERSION.SDK_INT >= 28 && notificationChannel?.group != null)
            manager.getNotificationChannelGroup(notificationChannel.group)?.isBlocked == true else false
        val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val activity = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val session = controller
        val attributes = session?.playbackInfo?.audioAttributes
        val flags = notification?.flags ?: 0
        return mapOf(
            "event" to "snapshot", "sdk" to Build.VERSION.SDK_INT,
            "compatActive" to ModuMediaNotificationPolicy.enabled(
                ModuMediaNotificationPolicy.TEST_BUILD, Build.BRAND, Build.MANUFACTURER),
            "stopCompatActive" to ModuMediaNotificationPolicy.stopActionEnabled(
                Build.VERSION.SDK_INT, Build.BRAND, Build.MANUFACTURER),
            "notificationPlayRequests" to ModuMediaNotificationPolicy.notificationPlayRequests,
            "sessionPlayCallbacks" to ModuMediaNotificationPolicy.sessionPlayCallbacks,
            "targetSdk" to context.applicationInfo.targetSdkVersion,
            "notificationsEnabled" to manager.areNotificationsEnabled(),
            "notificationPermission" to (Build.VERSION.SDK_INT < 33 ||
                context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED),
            "powerSave" to power.isPowerSaveMode,
            "backgroundRestricted" to (Build.VERSION.SDK_INT >= 28 && activity.isBackgroundRestricted),
            "notificationCount" to posted.size, "notificationPresent" to (notification != null),
            "tokenPresent" to (token != null), "sessionPresent" to (session != null),
            "ownSession" to (session?.packageName == context.packageName),
            "mediaCategory" to (notification?.category == Notification.CATEGORY_TRANSPORT),
            "mediaStyle" to (notification?.extras?.getString(Notification.EXTRA_TEMPLATE) == "android.app.Notification\$MediaStyle"),
            "notificationFlags" to flags,
            "foreground" to (flags and Notification.FLAG_FOREGROUND_SERVICE != 0),
            "ongoing" to (flags and Notification.FLAG_ONGOING_EVENT != 0),
            "channelPresent" to (notificationChannel != null),
            "importance" to (notificationChannel?.importance ?: -1),
            "channelBlocked" to (notificationChannel?.importance == NotificationManager.IMPORTANCE_NONE),
            "groupBlocked" to groupBlocked,
            "notificationActions" to (notification?.actions?.size ?: 0),
            "actionIntents" to (notification?.actions?.map { it.actionIntent != null } ?: emptyList<Boolean>()),
            "actionIcons" to (notification?.actions?.map { it.icon } ?: emptyList<Int>()),
            // Action.icon is a deprecated legacy field and can be zero even
            // when getIcon() contains a valid resource. Never log URI values.
            "actionIconPresent" to (notification?.actions?.map { it.getIcon() != null } ?: emptyList<Boolean>()),
            "actionIconTypes" to (if (Build.VERSION.SDK_INT >= 28)
                notification?.actions?.map { it.getIcon()?.type ?: 0 } ?: emptyList<Int>() else emptyList<Int>()),
            "actionIconResources" to (if (Build.VERSION.SDK_INT >= 28)
                notification?.actions?.map {
                    val icon = it.getIcon()
                    if (icon?.type == Icon.TYPE_RESOURCE) icon.resId else 0
                } ?: emptyList<Int>() else emptyList<Int>()),
            "semanticActions" to (if (Build.VERSION.SDK_INT >= 28)
                notification?.actions?.map { it.semanticAction } ?: emptyList<Int>() else emptyList<Int>()),
            "compact" to (notification?.extras?.getIntArray(Notification.EXTRA_COMPACT_ACTIONS)?.toList() ?: emptyList<Int>()),
            "flags" to (session?.flags ?: 0L),
            "audioUsage" to (attributes?.usage ?: -1),
            "audioContentType" to (attributes?.contentType ?: -1),
        ) + stateFields(session?.playbackState) + metadataFields(session?.metadata)
    }

    private val poll = object : Runnable {
        override fun run() {
            if (!running) return
            try {
                val fields = snapshot()
                val now = SystemClock.elapsedRealtime()
                if (fields != lastSnapshot || (controller != null && now - lastSent >= 30000)) {
                    lastSnapshot = fields
                    lastSent = now
                    emit(fields)
                }
            } catch (_: Exception) {
                val fields = mapOf<String, Any>("event" to "error")
                if (lastSnapshot != fields) { lastSnapshot = fields; emit(fields) }
            }
            if (running) handler.postDelayed(this, 2000)
        }
    }

    private fun stop() {
        running = false
        handler.removeCallbacks(poll)
        detachController()
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.modu.reader/media_diagnostics")
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    if (!running) { running = true; count = 0; handler.post(poll) }
                    result.success(null)
                }
                "stop" -> { stop(); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stop()
        channel?.setMethodCallHandler(null)
        channel = null
    }
}
