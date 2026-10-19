import AVFoundation

enum SoundEffect: String, CaseIterable, Identifiable {
  case copy
  case paste
  case delete
  case selectionAdd
  case selectionRemove

  var id: String { rawValue }

  var title: String {
    switch self {
    case .copy: L10n.string("Copy item")
    case .paste: L10n.string("Paste item to active app")
    case .delete: L10n.string("Delete item")
    case .selectionAdd: L10n.string("Add item to selection")
    case .selectionRemove: L10n.string("Remove item from selection")
    }
  }

  var preferenceKeyPath: WritableKeyPath<AppPreferences, Bool> {
    switch self {
    case .copy: \.playSoundOnCopy
    case .paste: \.playSoundOnPaste
    case .delete: \.playSoundOnDelete
    case .selectionAdd: \.playSoundOnSelectionAdd
    case .selectionRemove: \.playSoundOnSelectionRemove
    }
  }

  fileprivate var resource: (name: String, extension: String) {
    switch self {
    case .copy: ("copy", "aiff")
    case .paste: ("paste", "aiff")
    case .delete: ("delete", "aiff")
    case .selectionAdd: ("selection-add", "aiff")
    case .selectionRemove: ("selection-remove", "aiff")
    }
  }
}

@MainActor
final class SoundService {
  private let player = SoundPlayer()

  func play(_ effect: SoundEffect) {
    player.play(resource: effect.resource)
  }
}

/// Starting a sound waits on the audio server, which held the main thread for
/// about 15 ms each time, and longer for the first sound of a kind while it was
/// read. A sound played right after deleting an item kept the list from showing
/// the item gone until then, so sounds are read and played on a queue of their
/// own. Only that queue touches the players.
private nonisolated final class SoundPlayer: @unchecked Sendable {
  private let queue = DispatchQueue(label: "com.ikryanov.clipbook.sound", qos: .userInteractive)
  private var playersByName: [String: AVAudioPlayer] = [:]

  func play(resource: (name: String, extension: String)) {
    queue.async { [self] in
      guard let player = player(forResourceNamed: resource.name, withExtension: resource.extension) else {
        return
      }

      // A sound still playing starts over rather than being stopped, which
      // would let go of what it prepared and delay it.
      player.currentTime = 0
      if !player.isPlaying {
        player.play()
      }
    }
  }

  private func player(forResourceNamed name: String, withExtension fileExtension: String) -> AVAudioPlayer? {
    if let player = playersByName[name] {
      return player
    }

    // Resource folders are flattened into the bundle's Resources directory, so
    // sounds are looked up by name only.
    guard let url = Bundle.main.url(forResource: name, withExtension: fileExtension),
          let player = try? AVAudioPlayer(contentsOf: url) else {
      return nil
    }

    player.prepareToPlay()
    playersByName[name] = player
    return player
  }
}
