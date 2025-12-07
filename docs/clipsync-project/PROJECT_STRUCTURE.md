# ClipSync - Project Structure

## Complete Folder Structure

```
clipsync/
│
├── README.md                           # Project overview
├── pubspec.yaml                        # Flutter dependencies
├── analysis_options.yaml               # Dart linting rules
│
├── lib/                                # Main Dart/Flutter code
│   │
│   ├── main.dart                       # App entry point
│   │
│   ├── app/                            # App configuration
│   │   ├── app.dart                    # Root app widget
│   │   ├── routes.dart                 # Navigation routes
│   │   └── themes.dart                 # App themes (light/dark)
│   │
│   ├── core/                           # Core utilities (shared)
│   │   ├── constants/
│   │   │   ├── app_constants.dart      # App-wide constants
│   │   │   ├── api_constants.dart      # API endpoints
│   │   │   └── storage_keys.dart       # Local storage keys
│   │   │
│   │   ├── errors/
│   │   │   ├── exceptions.dart         # Custom exceptions
│   │   │   └── failures.dart           # Failure classes
│   │   │
│   │   ├── utils/
│   │   │   ├── date_utils.dart         # Date formatting
│   │   │   ├── string_utils.dart       # String helpers
│   │   │   ├── file_utils.dart         # File helpers
│   │   │   └── logger.dart             # Logging utility
│   │   │
│   │   └── extensions/
│   │       ├── string_extensions.dart  # String extensions
│   │       ├── context_extensions.dart # BuildContext extensions
│   │       └── list_extensions.dart    # List extensions
│   │
│   ├── data/                           # Data layer
│   │   │
│   │   ├── models/                     # Data models
│   │   │   ├── clip_item.dart          # Clipboard item model
│   │   │   ├── device.dart             # Device model
│   │   │   ├── sync_message.dart       # Sync message model
│   │   │   ├── user_settings.dart      # Settings model
│   │   │   └── tag.dart                # Tag model
│   │   │
│   │   ├── repositories/               # Data repositories
│   │   │   ├── clip_repository.dart    # Clipboard data operations
│   │   │   ├── device_repository.dart  # Device management
│   │   │   ├── settings_repository.dart# Settings storage
│   │   │   └── sync_repository.dart    # Sync operations
│   │   │
│   │   ├── sources/                    # Data sources
│   │   │   ├── local/
│   │   │   │   ├── database.dart       # SQLite/SQLCipher setup
│   │   │   │   ├── clip_local_source.dart
│   │   │   │   ├── device_local_source.dart
│   │   │   │   └── settings_local_source.dart
│   │   │   │
│   │   │   └── remote/
│   │   │       ├── api_client.dart     # HTTP client
│   │   │       ├── websocket_client.dart # WebSocket client
│   │   │       └── sync_remote_source.dart
│   │   │
│   │   └── mappers/                    # Data transformers
│   │       ├── clip_mapper.dart        # Clip model <-> DB/API
│   │       └── device_mapper.dart      # Device model <-> DB/API
│   │
│   ├── domain/                         # Business logic layer
│   │   │
│   │   ├── entities/                   # Business entities
│   │   │   ├── clip.dart               # Clip entity
│   │   │   ├── device.dart             # Device entity
│   │   │   └── sync_status.dart        # Sync status entity
│   │   │
│   │   ├── usecases/                   # Use cases (business logic)
│   │   │   ├── clipboard/
│   │   │   │   ├── get_clip_history.dart
│   │   │   │   ├── add_clip.dart
│   │   │   │   ├── delete_clip.dart
│   │   │   │   ├── search_clips.dart
│   │   │   │   └── toggle_favorite.dart
│   │   │   │
│   │   │   ├── sync/
│   │   │   │   ├── sync_clip.dart
│   │   │   │   ├── receive_clip.dart
│   │   │   │   └── get_sync_status.dart
│   │   │   │
│   │   │   └── device/
│   │   │       ├── register_device.dart
│   │   │       ├── pair_device.dart
│   │   │       ├── get_paired_devices.dart
│   │   │       └── remove_device.dart
│   │   │
│   │   └── repositories/               # Repository interfaces
│   │       ├── i_clip_repository.dart
│   │       ├── i_device_repository.dart
│   │       └── i_sync_repository.dart
│   │
│   ├── presentation/                   # UI layer
│   │   │
│   │   ├── common/                     # Shared UI components
│   │   │   ├── widgets/
│   │   │   │   ├── app_button.dart
│   │   │   │   ├── app_text_field.dart
│   │   │   │   ├── app_card.dart
│   │   │   │   ├── loading_indicator.dart
│   │   │   │   ├── error_view.dart
│   │   │   │   └── empty_state.dart
│   │   │   │
│   │   │   └── dialogs/
│   │   │       ├── confirm_dialog.dart
│   │   │       ├── error_dialog.dart
│   │   │       └── loading_dialog.dart
│   │   │
│   │   ├── clipboard/                  # Clipboard feature
│   │   │   ├── screens/
│   │   │   │   ├── clipboard_screen.dart       # Main clipboard screen
│   │   │   │   └── clip_detail_screen.dart     # Clip detail view
│   │   │   │
│   │   │   ├── widgets/
│   │   │   │   ├── clip_list.dart              # List of clips
│   │   │   │   ├── clip_list_item.dart         # Single clip item
│   │   │   │   ├── clip_preview.dart           # Preview pane
│   │   │   │   ├── clip_text_preview.dart      # Text preview
│   │   │   │   ├── clip_image_preview.dart     # Image preview
│   │   │   │   ├── clip_link_preview.dart      # Link preview
│   │   │   │   ├── search_bar.dart             # Search input
│   │   │   │   ├── filter_chips.dart           # Filter options
│   │   │   │   └── sort_menu.dart              # Sort options
│   │   │   │
│   │   │   └── providers/
│   │   │       ├── clipboard_provider.dart     # Clipboard state
│   │   │       ├── search_provider.dart        # Search state
│   │   │       └── filter_provider.dart        # Filter state
│   │   │
│   │   ├── sync/                       # Sync feature
│   │   │   ├── screens/
│   │   │   │   ├── sync_screen.dart            # Sync/paste screen (mobile)
│   │   │   │   └── device_list_screen.dart     # Paired devices
│   │   │   │
│   │   │   ├── widgets/
│   │   │   │   ├── paste_input.dart            # Paste input field
│   │   │   │   ├── device_card.dart            # Device card
│   │   │   │   ├── sync_status_badge.dart      # Sync status indicator
│   │   │   │   └── qr_scanner.dart             # QR code scanner
│   │   │   │
│   │   │   └── providers/
│   │   │       ├── sync_provider.dart          # Sync state
│   │   │       └── device_provider.dart        # Device state
│   │   │
│   │   ├── pairing/                    # Device pairing feature
│   │   │   ├── screens/
│   │   │   │   ├── pairing_screen.dart         # Pairing flow
│   │   │   │   ├── qr_display_screen.dart      # Show QR code
│   │   │   │   └── qr_scan_screen.dart         # Scan QR code
│   │   │   │
│   │   │   ├── widgets/
│   │   │   │   ├── qr_code_display.dart        # QR code widget
│   │   │   │   ├── security_code.dart          # Verification code
│   │   │   │   └── pairing_progress.dart       # Progress indicator
│   │   │   │
│   │   │   └── providers/
│   │   │       └── pairing_provider.dart       # Pairing state
│   │   │
│   │   ├── settings/                   # Settings feature
│   │   │   ├── screens/
│   │   │   │   ├── settings_screen.dart        # Main settings
│   │   │   │   ├── general_settings.dart       # General options
│   │   │   │   ├── sync_settings.dart          # Sync options
│   │   │   │   ├── security_settings.dart      # Security options
│   │   │   │   ├── appearance_settings.dart    # Theme options
│   │   │   │   └── about_screen.dart           # About app
│   │   │   │
│   │   │   ├── widgets/
│   │   │   │   ├── settings_tile.dart          # Settings row
│   │   │   │   ├── settings_section.dart       # Settings group
│   │   │   │   └── settings_switch.dart        # Toggle setting
│   │   │   │
│   │   │   └── providers/
│   │   │       └── settings_provider.dart      # Settings state
│   │   │
│   │   ├── onboarding/                 # Onboarding flow
│   │   │   ├── screens/
│   │   │   │   ├── welcome_screen.dart
│   │   │   │   ├── permissions_screen.dart
│   │   │   │   └── setup_complete_screen.dart
│   │   │   │
│   │   │   └── widgets/
│   │   │       └── onboarding_page.dart
│   │   │
│   │   └── file_sharing/               # File sharing feature (NEW)
│   │       ├── screens/
│   │       │   ├── file_sharing_screen.dart    # Main file sharing tab
│   │       │   ├── send_files_screen.dart      # Send file flow
│   │       │   └── receive_files_screen.dart   # Receive file flow
│   │       │
│   │       ├── widgets/
│   │       │   ├── drop_zone.dart              # Drag & drop area
│   │       │   ├── nearby_device_card.dart     # Device card
│   │       │   ├── nearby_device_list.dart     # List of devices
│   │       │   ├── file_transfer_item.dart     # Single transfer item
│   │       │   ├── transfer_progress.dart      # Progress bar
│   │       │   └── incoming_request_dialog.dart# Accept/reject dialog
│   │       │
│   │       └── providers/
│   │           ├── file_sharing_provider.dart  # File sharing state
│   │           ├── nearby_devices_provider.dart# Device discovery state
│   │           └── transfer_provider.dart      # Transfer state
│   │
│   ├── services/                       # App services
│   │   ├── encryption/
│   │   │   ├── encryption_service.dart         # Encryption interface
│   │   │   ├── signal_protocol_service.dart    # Signal Protocol impl
│   │   │   └── key_storage_service.dart        # Key management
│   │   │
│   │   ├── sync/
│   │   │   ├── sync_service.dart               # Sync orchestration
│   │   │   ├── websocket_service.dart          # WebSocket management
│   │   │   └── push_notification_service.dart  # Push notifications
│   │   │
│   │   ├── clipboard/
│   │   │   └── clipboard_service.dart          # Clipboard operations
│   │   │
│   │   ├── file_sharing/                       # Local file sharing (NEW)
│   │   │   ├── discovery_service.dart          # UDP/mDNS device discovery
│   │   │   ├── http_server_service.dart        # Local HTTP server
│   │   │   ├── transfer_service.dart           # File transfer logic
│   │   │   └── nearby_device.dart              # Nearby device model
│   │   │
│   │   └── storage/
│   │       ├── secure_storage_service.dart     # Keychain/Keystore
│   │       └── preferences_service.dart        # Shared preferences
│   │
│   └── platform/                       # Platform-specific code
│       │
│       ├── clipboard/                  # Clipboard platform code
│       │   ├── clipboard_platform_interface.dart   # Interface
│       │   ├── clipboard_macos.dart                # macOS impl
│       │   ├── clipboard_windows.dart              # Windows impl
│       │   ├── clipboard_android.dart              # Android impl
│       │   └── clipboard_ios.dart                  # iOS impl
│       │
│       ├── system_tray/                # System tray (desktop only)
│       │   ├── system_tray_interface.dart
│       │   ├── system_tray_macos.dart
│       │   └── system_tray_windows.dart
│       │
│       ├── hotkeys/                    # Global hotkeys (desktop only)
│       │   ├── hotkey_interface.dart
│       │   ├── hotkey_macos.dart
│       │   └── hotkey_windows.dart
│       │
│       └── window/                     # Window management (desktop only)
│           ├── window_interface.dart
│           ├── window_macos.dart
│           └── window_windows.dart
│
├── test/                               # Unit and widget tests
│   ├── data/
│   │   ├── models/
│   │   └── repositories/
│   ├── domain/
│   │   └── usecases/
│   ├── presentation/
│   │   └── providers/
│   └── services/
│
├── integration_test/                   # Integration tests
│   └── app_test.dart
│
├── assets/                             # Static assets
│   ├── images/
│   │   ├── logo.png
│   │   └── icons/
│   ├── fonts/
│   └── translations/
│       ├── en.json
│       ├── de.json
│       └── es.json
│
├── android/                            # Android native code
│   └── app/
│       └── src/main/
│           └── kotlin/
│               └── com/clipsync/
│                   └── ClipboardPlugin.kt
│
├── ios/                                # iOS native code
│   └── Runner/
│       └── ClipboardPlugin.swift
│
├── macos/                              # macOS native code
│   └── Runner/
│       ├── ClipboardMonitor.swift      # Clipboard monitoring
│       ├── SystemTray.swift            # Menu bar
│       └── GlobalHotkey.swift          # Hotkeys
│
├── windows/                            # Windows native code
│   └── runner/
│       ├── clipboard_monitor.cpp       # Clipboard monitoring
│       ├── system_tray.cpp             # System tray
│       └── global_hotkey.cpp           # Hotkeys
│
└── server/                             # Backend server (separate repo?)
    ├── README.md
    ├── Dockerfile
    └── src/
        ├── main.rs                     # Entry point (Rust)
        ├── api/
        │   ├── mod.rs
        │   ├── devices.rs
        │   ├── messages.rs
        │   └── pairing.rs
        ├── models/
        ├── services/
        └── utils/
```

---

## File Counts by Section

| Section | File Count | Description |
|---------|------------|-------------|
| `lib/core/` | ~12 files | Utilities, constants, extensions |
| `lib/data/` | ~18 files | Models, repositories, data sources |
| `lib/domain/` | ~19 files | Entities, use cases, interfaces |
| `lib/presentation/` | ~52 files | Screens, widgets, providers |
| `lib/services/` | ~12 files | App services (incl. file sharing) |
| `lib/platform/` | ~12 files | Platform-specific code |
| `macos/` | ~3 files | macOS native code |
| `windows/` | ~3 files | Windows native code |
| `server/` | ~10 files | Backend server |
| **Total** | **~143 files** | Manageable, focused files |

### Feature Breakdown

| Feature | Files |
|---------|-------|
| Clipboard Sync | ~50 files |
| File Sharing (Local) | ~23 files |
| Settings | ~15 files |
| Device Pairing | ~12 files |
| Core/Shared | ~43 files |

---

## Key Principles Applied

### 1. Shared vs Platform-Specific

```
SHARED (lib/)                    PLATFORM (platform/, macos/, windows/)
─────────────────────────────    ────────────────────────────────────────
• UI widgets                     • Clipboard monitoring
• Business logic                 • System tray
• Data models                    • Global hotkeys
• Network/sync                   • Window management
• Encryption logic               • Native APIs
```

### 2. Feature-Based Organization

Each feature has its own folder with:
- `screens/` - Full page views
- `widgets/` - Reusable components
- `providers/` - State management

### 3. Clean Architecture Layers

```
presentation/     →  UI, widgets, state management
       ↓
domain/           →  Business logic, use cases
       ↓
data/             →  Data sources, repositories
       ↓
services/         →  External services, APIs
```

---

## Import Rules

### Within a Feature

```dart
// Inside lib/presentation/clipboard/widgets/clip_list_item.dart
import '../providers/clipboard_provider.dart';  // Relative OK
import 'clip_preview.dart';                      // Same folder OK
```

### Across Features

```dart
// Always use package imports
import 'package:clipsync/data/models/clip_item.dart';
import 'package:clipsync/presentation/common/widgets/app_button.dart';
```

---

## Notes

1. **Server can be separate repository** if preferred
2. **Tests mirror lib/ structure** for easy navigation
3. **Platform folders only contain native code** that can't be done in Dart
4. **Each file should have single responsibility**
