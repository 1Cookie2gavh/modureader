// swiftc ios/Runner/ReaderVolumeKeys.swift test/native/ReaderVolumeKeysTest.swift -o /tmp/modu-volume-test
@main
struct ReaderVolumeKeysTest {
  static func main() {
    var state = ReaderVolumeKeyState()
    precondition(state.consume(0.6, generation: state.generation) == nil)
    state.configure(enabled: true, volume: 0.5)
    let first = state.generation
    precondition(state.consume(0.5, generation: first) == nil)
    precondition(state.consume(0.5625, generation: first) == -1)
    precondition(state.consume(0.5, generation: first) == 1)
    precondition(state.consume(.nan, generation: first) == nil)
    precondition(state.consume(.infinity, generation: first) == nil)
    precondition(state.consume(-1, generation: first) == nil)
    precondition(state.consume(2, generation: first) == nil)
    precondition(state.consume(0.4375, generation: first) == 1)
    state.configure(enabled: false, volume: 0.4)
    precondition(state.consume(0.5, generation: state.generation) == nil)
    state.configure(enabled: true, volume: 0.8)
    precondition(state.consume(0.9, generation: first) == nil, "Discard pre-dialog/background callbacks")
    precondition(state.consume(0.8, generation: state.generation) == nil, "Resume must not turn a page")
    precondition(state.consume(1, generation: state.generation) == -1)
    precondition(state.consume(1, generation: state.generation) == nil, "No fabricated presses at maximum")
    precondition(state.consume(0, generation: state.generation) == 1)
    precondition(state.consume(0, generation: state.generation) == nil, "No fabricated presses at minimum")
    state.configure(enabled: true, volume: .nan)
    precondition(state.consume(0.5, generation: state.generation) == nil)
    precondition(state.consume(0.6, generation: state.generation) == -1)
    print("Reader volume key state checks passed")
  }
}
