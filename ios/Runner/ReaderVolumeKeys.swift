import Foundation

// Also compiled by the host-side regression test without an iPhone runtime.
struct ReaderVolumeKeyState {
  private(set) var generation = 0
  private var enabled = false
  private var previous: Float?

  mutating func configure(enabled: Bool, volume: Float) {
    generation += 1
    self.enabled = enabled
    previous = volume.isFinite && (0...1).contains(volume) ? volume : nil
  }

  mutating func consume(_ volume: Float, generation: Int) -> Int? {
    guard enabled, self.generation == generation,
          volume.isFinite, (0...1).contains(volume) else { return nil }
    defer { previous = volume }
    guard let previous, abs(volume - previous) > 0.0001 else { return nil }
    return volume > previous ? -1 : 1
  }
}

#if os(iOS)
import AVFoundation
import Flutter
import UIKit

/// Public KVO only: do not steal TTS's session, reset volume, or hide system UI.
/// shortcut: outputVolume cannot distinguish keys from external volume changes
/// or repeated presses at 0/1; replace only if iOS adds a reader key API.
final class ReaderVolumeKeysPlugin: NSObject, FlutterPlugin {
  private let channel: FlutterMethodChannel
  private weak var viewController: UIViewController?
  private var observation: NSKeyValueObservation?
  private var notifications = [NSObjectProtocol]()
  private var requested = false
  private var interrupted = false
  private var state = ReaderVolumeKeyState()

  private init(registrar: FlutterPluginRegistrar) {
    channel = FlutterMethodChannel(name: "com.modu.reader/page_keys",
                                   binaryMessenger: registrar.messenger())
    viewController = registrar.viewController
    super.init()
    for name in [UIApplication.willResignActiveNotification,
                 UIApplication.didBecomeActiveNotification,
                 UIScene.willDeactivateNotification, UIScene.didActivateNotification,
                 AVAudioSession.routeChangeNotification,
                 AVAudioSession.mediaServicesWereResetNotification,
                 AVAudioSession.interruptionNotification] {
      notifications.append(NotificationCenter.default.addObserver(
        forName: name, object: nil, queue: .main) { [weak self] event in
          guard let self else { return }
          if event.name == AVAudioSession.interruptionNotification {
            let type = event.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            self.interrupted = type == AVAudioSession.InterruptionType.began.rawValue
          }
          // Invalidate queued events before the Dart route/lifecycle catches up.
          let resigning = event.name == UIApplication.willResignActiveNotification ||
                          event.name == UIScene.willDeactivateNotification
          self.refresh(suspended: resigning)
          if !resigning { self.channel.invokeMethod("hostStateChanged", arguments: nil) }
        })
    }
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = ReaderVolumeKeysPlugin(registrar: registrar)
    registrar.addMethodCallDelegate(plugin, channel: plugin.channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "configure" else { result(FlutterMethodNotImplemented); return }
    let args = call.arguments as? [String: Any] ?? [:]
    requested = args["active"] as? Bool == true && args["volume"] as? Bool == true
    refresh()
    result(nil)
  }

  private var foreground: Bool {
    UIApplication.shared.applicationState == .active &&
      viewController?.viewIfLoaded?.window?.windowScene?.activationState == .foregroundActive
  }

  private func refresh(suspended: Bool = false) {
    observation?.invalidate()
    observation = nil
    let session = AVAudioSession.sharedInstance()
    let enabled = requested && foreground && !interrupted && !suspended
    state.configure(enabled: enabled, volume: session.outputVolume)
    guard enabled else { return }
    let generation = state.generation
    observation = session.observe(\.outputVolume, options: [.new]) { [weak self] _, change in
      guard let volume = change.newValue else { return }
      DispatchQueue.main.async {
        guard let self, self.foreground,
              let direction = self.state.consume(volume, generation: generation) else { return }
        self.channel.invokeMethod("turnPage", arguments: direction)
      }
    }
  }

  deinit {
    observation?.invalidate()
    for observer in notifications { NotificationCenter.default.removeObserver(observer) }
  }
}
#endif
