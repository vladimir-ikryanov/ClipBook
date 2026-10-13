import AppKit

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
    case .paste: ("paste", "mp3")
    case .delete: ("delete", "mp3")
    case .selectionAdd: ("selection-add", "mp3")
    case .selectionRemove: ("selection-remove", "mp3")
    }
  }
}

@MainActor
final class SoundService {
  private var soundsByEffect: [SoundEffect: NSSound] = [:]

  func play(_ effect: SoundEffect) {
    guard let sound = sound(for: effect) else {
      return
    }

    if sound.isPlaying {
      sound.stop()
    }
    sound.currentTime = 0
    sound.play()
  }

  private func sound(for effect: SoundEffect) -> NSSound? {
    if let sound = soundsByEffect[effect] {
      return sound
    }

    // Resource folders are flattened into the bundle's Resources directory, so
    // sounds are looked up by name only.
    guard let url = Bundle.main.url(forResource: effect.resource.name, withExtension: effect.resource.extension),
          let sound = NSSound(contentsOf: url, byReference: false) else {
      return nil
    }

    soundsByEffect[effect] = sound
    return sound
  }
}
