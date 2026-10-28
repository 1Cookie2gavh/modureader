package com.shoutsocial.share_handler

import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import android.provider.OpenableColumns
import android.util.Log
import android.webkit.MimeTypeMap

import androidx.annotation.NonNull
import androidx.core.app.Person
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.*

private const val kEventsChannel = "com.shoutsocial.share_handler/sharedMediaStream"

/** ShareHandlerPlugin */
class ShareHandlerPlugin : FlutterPlugin, Messages.ShareHandlerApi, EventChannel.StreamHandler, ActivityAware,
  PluginRegistry.NewIntentListener {
  private val pendingMedia = mutableListOf<Messages.SharedMedia>()
  private var pendingError = false
  private var initialMedia: Messages.SharedMedia? = null
  private var eventChannel: EventChannel? = null
  private var eventSink: EventChannel.EventSink? = null

  private var binding: ActivityPluginBinding? = null
  private lateinit var applicationContext: Context

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    applicationContext = flutterPluginBinding.applicationContext

    val messenger = flutterPluginBinding.binaryMessenger
    Messages.ShareHandlerApi.setup(messenger, this)

    eventChannel = EventChannel(messenger, kEventsChannel)
    eventChannel?.setStreamHandler(this)
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    Messages.ShareHandlerApi.setup(binding.binaryMessenger, null)
  }

  override fun getInitialSharedMedia(result: Messages.Result<Messages.SharedMedia>?) {
    result?.success(initialMedia)
  }

  override fun recordSentMessage(media: Messages.SharedMedia) {
    val packageName = applicationContext.packageName
    val intent = Intent(applicationContext, Class.forName("$packageName.MainActivity")).apply {
      action = Intent.ACTION_SEND
      putExtra("conversationIdentifier", media.conversationIdentifier)
    }
    val shortcutTarget = "$packageName.dynamic_share_target"
    val shortcutBuilder = ShortcutInfoCompat.Builder(applicationContext, media.conversationIdentifier ?: "")
      .setShortLabel(media.speakableGroupName ?: "Unknown")
      .setIsConversation()
      .setCategories(setOf(shortcutTarget))
      .setIntent(intent)
      .setLongLived(true)

    val personBuilder = Person.Builder()
      .setKey(media.conversationIdentifier)
      .setName(media.speakableGroupName)

    media.imageFilePath?.let {
      val bitmap = BitmapFactory.decodeFile(it)
      val icon = IconCompat.createWithAdaptiveBitmap(bitmap)
      shortcutBuilder.setIcon(icon)
      personBuilder.setIcon(icon)
    }

    val person = personBuilder.build()
    shortcutBuilder.setPerson(person)

    val shortcut = shortcutBuilder.build()

    ShortcutManagerCompat.addDynamicShortcuts(applicationContext, listOf(shortcut))
  }

  override fun resetInitialSharedMedia() {
    initialMedia = null
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    eventSink = events
    for (media in pendingMedia) events?.success(media.toMap())
    pendingMedia.clear()
    if (pendingError) events?.error("IMPORT_FAILED", "Unable to read the shared file. Check file access and retry.", null)
    pendingError = false
  }

  override fun onCancel(arguments: Any?) {
    eventSink = null
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    this.binding = binding
    binding.addOnNewIntentListener(this)
    val flags: Int = binding.activity.intent.flags
    if ((flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0) {
      // The activity was launched from history
      Log.w("TAG", "Handle skip: The activity was launched from history")
    } else {
      handleIntent(binding.activity.intent, true)
    }
  }

  override fun onDetachedFromActivityForConfigChanges() {
    binding?.removeOnNewIntentListener(this)
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    this.binding = binding
    binding.addOnNewIntentListener(this)
  }

  override fun onDetachedFromActivity() {
    binding?.removeOnNewIntentListener(this)
  }

  override fun onNewIntent(intent: Intent): Boolean {
    handleIntent(intent, false)
    return false
  }

  private fun handleIntent(intent: Intent, initial: Boolean) {
    val attachments: List<Messages.SharedAttachment>? = try {
      attachmentsFromIntent(intent)
    } catch (e: Exception) {
      Log.e("TAG", "Unable to stage shared file: " + e.javaClass.simpleName)
      if (eventSink != null) eventSink?.error("IMPORT_FAILED", "Unable to read the shared file. Check file access and retry.", null)
      else pendingError = true
      null
    }

    val text: String? = when (intent.action) {
      Intent.ACTION_SEND, Intent.ACTION_SEND_MULTIPLE -> intent.getStringExtra(Intent.EXTRA_TEXT)
      else -> null
    }

    val conversationIdentifier = intent.getStringExtra("android.intent.extra.shortcut.ID")
      ?: intent.getStringExtra("conversationIdentifier")

    if (attachments != null || text != null || conversationIdentifier != null) {
      val mediaBuilder = Messages.SharedMedia.Builder()
      attachments?.let { mediaBuilder.setAttachments(it) }
      text?.let { mediaBuilder.setContent(it) }
      conversationIdentifier?.let { mediaBuilder.setConversationIdentifier(it) }
      val media = mediaBuilder.build()

      if (initial) {
        synchronized(this) {
          initialMedia = media
        }
      }

      if (eventSink != null) {
        eventSink?.success(media.toMap())
      } else {
        if (!initial) pendingMedia.add(media)
      }
    }
  }

  private fun attachmentsFromIntent(intent: Intent?): List<Messages.SharedAttachment>? {
    if (intent == null || intent.action !in listOf(
        Intent.ACTION_VIEW, Intent.ACTION_SEND, Intent.ACTION_SEND_MULTIPLE)) return null
    val uris = linkedSetOf<Uri>()
    if (intent.action == Intent.ACTION_SEND_MULTIPLE) {
      intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)?.let { uris.addAll(it) }
    } else {
      intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)?.let { uris.add(it) }
    }
    intent.clipData?.let { clip ->
      for (index in 0 until clip.itemCount) clip.getItemAt(index).uri?.let { uris.add(it) }
    }
    intent.data?.let { uris.add(it) }
    return uris.filter { it.scheme == "content" || it.scheme == "file" }
      .map { attachmentForUri(it, intent.type) }.takeIf { it.isNotEmpty() }
  }

  private fun attachmentForUri(uri: Uri, intentMime: String?): Messages.SharedAttachment {
    val resolver = applicationContext.contentResolver
    val mime = resolver.getType(uri) ?: intentMime
    var name: String? = null
    if (uri.scheme == "content") {
      // A provider may permit streaming while refusing metadata queries.
      try {
        resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
          if (it.moveToFirst()) {
            val index = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index >= 0) name = it.getString(index)
          }
        }
      } catch (_: Exception) { }
    }
    val extension = when (mime?.lowercase()?.substringBefore(';')) {
      "application/pdf" -> "pdf"
      "application/epub+zip" -> "epub"
      "application/x-mobipocket-ebook" -> "mobi"
      "application/vnd.amazon.ebook", "application/x-mobi8-ebook" -> "azw3"
      "application/x-fictionbook+xml" -> "fb2"
      "text/plain" -> "txt"
      "text/markdown", "text/x-markdown" -> "md"
      else -> mime?.let { MimeTypeMap.getSingleton().getExtensionFromMimeType(it) }
    }
    val file = IncomingFile.copy(applicationContext.cacheDir,
      name ?: uri.lastPathSegment, extension) { resolver.openInputStream(uri) }
    return Messages.SharedAttachment.Builder().setPath(file.absolutePath)
      .setType(getAttachmentType(mime)).build()
  }

  // Function to determine the attachment type using the MIME type
  private fun getAttachmentType(mimeType: String?): Messages.SharedAttachmentType {
    return when {
      mimeType?.startsWith("image") == true -> Messages.SharedAttachmentType.image
      mimeType?.startsWith("video") == true -> Messages.SharedAttachmentType.video
      mimeType?.startsWith("audio") == true -> Messages.SharedAttachmentType.audio
      else -> Messages.SharedAttachmentType.file
    }
  }
}
