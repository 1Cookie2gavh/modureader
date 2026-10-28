import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func application(_ sender: NSApplication, openFiles filenames: [String]) {
    ExternalBookFiles.shared.receive(filenames.map { URL(fileURLWithPath: $0) })
    sender.reply(toOpenOrPrint: .success)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

/// Copy while the OS-granted scope is alive; Flutter only receives private files.
final class ExternalBookFiles {
  static let shared = ExternalBookFiles()
  private var channel: FlutterMethodChannel?
  private var ready = false
  private var pending = [String]()
  private var failed = false
  private let worker = DispatchQueue(label: "com.modu.reader.external-files")
  private let extensions: Set<String> = ["epub", "mobi", "azw3", "fb2", "txt", "pdf", "md", "markdown", "umd"]

  func register(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "com.modu.reader/external_files", binaryMessenger: messenger)
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self, call.method == "ready" else {
        result(FlutterMethodNotImplemented); return
      }
      self.ready = true
      result(self.pending)
      self.pending.removeAll()
      if self.failed {
        self.failed = false
        channel.invokeMethod("error", arguments: "Unable to read the shared document. Check file access and retry.")
      }
    }
  }

  func receive(_ urls: [URL]) {
    for url in Set(urls) where url.isFileURL && extensions.contains(url.pathExtension.lowercased()) {
      let scoped = url.startAccessingSecurityScopedResource()
      worker.async {
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("modu-open-\(UUID().uuidString)")
        do {
          try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
          let target = folder.appendingPathComponent(url.lastPathComponent)
          var coordinationError: NSError?
          var copyError: Error?
          NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { source in
            do {
              guard try source.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
                throw CocoaError(.fileReadUnsupportedScheme)
              }
              try FileManager.default.copyItem(at: source, to: target)
            } catch { copyError = error }
          }
          if let error = coordinationError { throw error }
          if let error = copyError { throw error }
          guard FileManager.default.fileExists(atPath: target.path) else { throw CocoaError(.fileReadUnknown) }
          DispatchQueue.main.async {
            if self.ready { self.channel?.invokeMethod("files", arguments: [target.path]) }
            else { self.pending.append(target.path) }
          }
        } catch {
          try? FileManager.default.removeItem(at: folder)
          DispatchQueue.main.async {
            if self.ready {
              self.channel?.invokeMethod("error", arguments: "Unable to read the shared document. Check file access and retry.")
            } else { self.failed = true }
          }
        }
      }
    }
  }
}
