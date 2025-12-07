# ClipSync - Naming Conventions

## Overview

Consistent naming makes code easier to read, navigate, and maintain. This document defines all naming rules for the project.

---

## File and Folder Naming

### Folders

```
✓ CORRECT                    ✗ WRONG
───────────────────────────────────────────────────────
clip_history/                clipHistory/
user_settings/               userSettings/
sync_service/                SyncService/
```

**Rule**: Always use `snake_case` for folder names

### Dart Files

```
✓ CORRECT                    ✗ WRONG
───────────────────────────────────────────────────────
clip_item.dart               ClipItem.dart
clipboard_provider.dart      clipboardProvider.dart
sync_service.dart           sync-service.dart
```

**Rule**: Always use `snake_case.dart` for Dart files

### Native Files

```
Platform    Convention              Example
───────────────────────────────────────────────────────
Swift       PascalCase.swift        ClipboardMonitor.swift
Kotlin      PascalCase.kt           ClipboardPlugin.kt
C++         snake_case.cpp/h        clipboard_monitor.cpp
```

---

## Code Naming

### Classes and Enums

```dart
// Classes - PascalCase
class ClipboardProvider { }
class SyncService { }
class ClipItem { }

// Enums - PascalCase for enum, PascalCase for values
enum ClipType {
  text,
  image,
  link,
  file,
}

enum SyncStatus {
  idle,
  syncing,
  error,
  success,
}
```

### Functions and Methods

```dart
// Functions - camelCase
void syncClipboard() { }
Future<List<ClipItem>> getClipHistory() { }
bool isDevicePaired(String deviceId) { }

// Private - prefix with underscore
void _handleSyncComplete() { }
int _calculateHash() { }
```

### Variables

```dart
// Local variables - camelCase
String clipContent = '';
int itemCount = 0;
bool isLoading = false;

// Private fields - underscore prefix
String _deviceId;
List<ClipItem> _clipHistory;

// Constants - camelCase or SCREAMING_CASE
const int maxClipHistory = 1000;
const String API_BASE_URL = 'https://api.clipsync.app';
```

### Parameters

```dart
// Named parameters - camelCase
void addClip({
  required String content,
  required ClipType type,
  String? sourceApp,
  bool isFavorite = false,
}) { }
```

---

## Widget Naming

### Screens (Full Pages)

```dart
// Pattern: [Feature]Screen
class ClipboardScreen extends StatelessWidget { }
class SettingsScreen extends StatelessWidget { }
class PairingScreen extends StatelessWidget { }

// File: clipboard_screen.dart
```

### Widgets (Components)

```dart
// Pattern: [Purpose][Type]
class ClipListItem extends StatelessWidget { }
class SearchBar extends StatelessWidget { }
class SyncStatusBadge extends StatelessWidget { }
class DeviceCard extends StatelessWidget { }

// File: clip_list_item.dart
```

### Dialogs

```dart
// Pattern: [Purpose]Dialog
class ConfirmDeleteDialog extends StatelessWidget { }
class ErrorDialog extends StatelessWidget { }
class PairingSuccessDialog extends StatelessWidget { }

// File: confirm_delete_dialog.dart
```

---

## Provider/State Naming

### Providers

```dart
// Pattern: [Feature]Provider
class ClipboardProvider extends ChangeNotifier { }
class SyncProvider extends ChangeNotifier { }
class SettingsProvider extends ChangeNotifier { }

// File: clipboard_provider.dart
```

### State Classes

```dart
// Pattern: [Feature]State
class ClipboardState {
  final List<ClipItem> clips;
  final bool isLoading;
  final String? error;
}
```

---

## Model Naming

### Data Models

```dart
// Pattern: Simple descriptive name
class ClipItem { }
class Device { }
class SyncMessage { }
class UserSettings { }

// File: clip_item.dart
```

### DTOs (Data Transfer Objects)

```dart
// Pattern: [Model]Dto
class ClipItemDto { }
class DeviceDto { }

// File: clip_item_dto.dart
```

---

## Service Naming

### Services

```dart
// Pattern: [Purpose]Service
class EncryptionService { }
class SyncService { }
class StorageService { }

// File: encryption_service.dart
```

### Repositories

```dart
// Pattern: [Entity]Repository
class ClipRepository { }
class DeviceRepository { }
class SettingsRepository { }

// File: clip_repository.dart
```

### Interfaces

```dart
// Pattern: I[Name] or [Name]Interface
abstract class IClipRepository { }
abstract class ClipboardPlatformInterface { }

// File: i_clip_repository.dart
```

---

## Use Case Naming

### Use Cases

```dart
// Pattern: [Action][Entity]
class GetClipHistory { }
class AddClip { }
class DeleteClip { }
class SyncClipboard { }
class PairDevice { }

// File: get_clip_history.dart
```

---

## Test File Naming

```dart
// Pattern: [original_file_name]_test.dart

// Source: lib/data/models/clip_item.dart
// Test:   test/data/models/clip_item_test.dart

// Source: lib/services/sync_service.dart
// Test:   test/services/sync_service_test.dart
```

---

## Constants Naming

### File Names

```dart
// Pattern: [category]_constants.dart
app_constants.dart
api_constants.dart
storage_keys.dart
```

### Constant Values

```dart
// App constants
class AppConstants {
  static const String appName = 'ClipSync';
  static const int maxClipHistory = 1000;
  static const Duration syncTimeout = Duration(seconds: 30);
}

// API constants
class ApiConstants {
  static const String baseUrl = 'https://api.clipsync.app';
  static const String wsUrl = 'wss://api.clipsync.app/ws';
}

// Storage keys
class StorageKeys {
  static const String deviceId = 'device_id';
  static const String privateKey = 'private_key';
  static const String theme = 'theme';
}
```

---

## Asset Naming

### Images

```
✓ CORRECT                    ✗ WRONG
───────────────────────────────────────────────────────
logo.png                     Logo.png
icon_sync.svg                iconSync.svg
bg_onboarding.jpg            bgOnboarding.jpg
```

### Translations

```
✓ CORRECT
───────────────────────────────────────────────────────
en.json                      # English
de.json                      # German
es.json                      # Spanish
zh_CN.json                   # Chinese (Simplified)
```

---

## Summary Table

| Element | Convention | Example |
|---------|------------|---------|
| Folders | snake_case | `clip_history/` |
| Dart files | snake_case.dart | `clip_item.dart` |
| Classes | PascalCase | `ClipboardProvider` |
| Functions | camelCase | `getClipHistory()` |
| Variables | camelCase | `clipContent` |
| Private | _prefix | `_deviceId` |
| Constants | camelCase/UPPER | `maxHistory` |
| Screens | [Feature]Screen | `ClipboardScreen` |
| Widgets | [Purpose][Type] | `ClipListItem` |
| Providers | [Feature]Provider | `SyncProvider` |
| Services | [Purpose]Service | `EncryptionService` |
| Use Cases | [Action][Entity] | `AddClip` |
| Tests | _test.dart suffix | `clip_item_test.dart` |

---

## Quick Reference

```
folder_name/
  file_name.dart
    class ClassName
      void methodName()
      String variableName
      String _privateField
```
