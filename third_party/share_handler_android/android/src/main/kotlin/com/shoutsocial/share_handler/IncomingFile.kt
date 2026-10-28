package com.shoutsocial.share_handler

import java.io.File
import java.io.IOException
import java.io.InputStream
import java.util.UUID

/** Never resolve a document URI to a guessed path or reuse an external name in cache root. */
internal object IncomingFile {
  fun copy(cache: File, displayName: String?, extension: String?, open: () -> InputStream?): File {
    var name = (displayName ?: "book").substringAfterLast('/').substringAfterLast('\\')
      .replace(Regex("[\\x00-\\x1f]"), "_").trim()
    if (name.isEmpty() || name == "." || name == "..") name = "book"
    if (File(name).extension.isEmpty() && !extension.isNullOrEmpty()) name += ".$extension"
    val folder = File(cache, "modu-open-${UUID.randomUUID()}")
    if (!folder.mkdirs()) throw IOException("Cannot create import staging directory")
    try {
      val target = File(folder, name)
      val input = open() ?: throw IOException("Document provider returned no stream")
      input.use { source -> target.outputStream().use { source.copyTo(it) } }
      if (!target.isFile) throw IOException("Imported document is not a regular file")
      return target
    } catch (error: Exception) {
      folder.deleteRecursively()
      throw error
    }
  }
}
