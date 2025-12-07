# ClipSync - Development Guide

## Prerequisites

### Required Tools

| Tool | Version | Purpose |
|------|---------|---------|
| Flutter | 3.16+ | App framework |
| Dart | 3.2+ | Programming language |
| Xcode | 15+ | macOS/iOS builds |
| Android Studio | Latest | Android builds |
| Visual Studio | 2022+ | Windows builds |
| Git | Latest | Version control |

### Optional Tools

| Tool | Purpose |
|------|---------|
| VS Code | Code editor (with Flutter extension) |
| Android Emulator | Android testing |
| iOS Simulator | iOS testing |

---

## Initial Setup

### 1. Install Flutter

```
macOS:
  brew install flutter

Windows:
  Download from flutter.dev
  Add to PATH

Verify:
  flutter doctor
```

### 2. Clone Repository

```
git clone https://github.com/yourorg/clipsync.git
cd clipsync
```

### 3. Install Dependencies

```
flutter pub get
```

### 4. Platform-Specific Setup

**macOS:**
```
cd macos
pod install
cd ..
```

**iOS:**
```
cd ios
pod install
cd ..
```

**Windows:**
```
No additional setup required
```

**Android:**
```
Open in Android Studio
Sync Gradle
```

---

## Project Commands

### Run Application

```
Development (Debug):
  flutter run -d macos        # macOS
  flutter run -d windows      # Windows
  flutter run -d ios          # iOS Simulator
  flutter run -d android      # Android Emulator

Release:
  flutter run --release -d macos
```

### Build Application

```
macOS:
  flutter build macos --release

Windows:
  flutter build windows --release

iOS:
  flutter build ios --release

Android:
  flutter build apk --release
  flutter build appbundle --release
```

### Run Tests

```
All tests:
  flutter test

Specific file:
  flutter test test/data/models/clip_item_test.dart

With coverage:
  flutter test --coverage
```

### Code Generation

```
Build runner (for freezed, json_serializable):
  flutter pub run build_runner build --delete-conflicting-outputs

Watch mode:
  flutter pub run build_runner watch
```

### Linting

```
Analyze code:
  flutter analyze

Fix issues:
  dart fix --apply
```

---

## Folder Responsibilities

### lib/core/

**Purpose:** Shared utilities used across the app

| Folder | Contents |
|--------|----------|
| `constants/` | App-wide constant values |
| `errors/` | Custom exception classes |
| `utils/` | Helper functions |
| `extensions/` | Dart extension methods |

### lib/data/

**Purpose:** Data handling and storage

| Folder | Contents |
|--------|----------|
| `models/` | Data classes (JSON serializable) |
| `repositories/` | Repository implementations |
| `sources/local/` | SQLite/local storage |
| `sources/remote/` | API/WebSocket clients |
| `mappers/` | Model transformations |

### lib/domain/

**Purpose:** Business logic (pure Dart, no Flutter)

| Folder | Contents |
|--------|----------|
| `entities/` | Business objects |
| `usecases/` | Business operations |
| `repositories/` | Repository interfaces |

### lib/presentation/

**Purpose:** UI components and state

| Folder | Contents |
|--------|----------|
| `common/` | Shared widgets |
| `clipboard/` | Clipboard feature |
| `sync/` | Sync feature |
| `settings/` | Settings feature |
| `pairing/` | Device pairing feature |

### lib/services/

**Purpose:** External service integrations

| Folder | Contents |
|--------|----------|
| `encryption/` | E2E encryption |
| `sync/` | Sync management |
| `clipboard/` | Clipboard operations |
| `storage/` | Secure storage |

### lib/platform/

**Purpose:** Platform-specific abstractions

| Folder | Contents |
|--------|----------|
| `clipboard/` | Clipboard platform code |
| `system_tray/` | Menu bar/tray |
| `hotkeys/` | Global shortcuts |
| `window/` | Window management |

---

## Creating New Features

### Step 1: Create Feature Folder

```
lib/presentation/[feature_name]/
  ├── screens/
  ├── widgets/
  └── providers/
```

### Step 2: Create Screen

```dart
// lib/presentation/[feature]/screens/[feature]_screen.dart

class FeatureScreen extends StatelessWidget {
  const FeatureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feature')),
      body: const Center(child: Text('Feature content')),
    );
  }
}
```

### Step 3: Create Provider

```dart
// lib/presentation/[feature]/providers/[feature]_provider.dart

class FeatureProvider extends ChangeNotifier {
  // State
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Methods
  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();
    
    // Load data...
    
    _isLoading = false;
    notifyListeners();
  }
}
```

### Step 4: Add Route

```dart
// lib/app/routes.dart

static const String feature = '/feature';

// In router configuration
GoRoute(
  path: feature,
  builder: (context, state) => const FeatureScreen(),
),
```

### Step 5: Register Provider

```dart
// lib/main.dart or lib/app/app.dart

MultiProvider(
  providers: [
    // ... existing providers
    ChangeNotifierProvider(create: (_) => FeatureProvider()),
  ],
  child: const MyApp(),
)
```

---

## Code Standards

### File Header

Every file should start with:

```dart
/// Brief description of what this file contains.
/// 
/// More detailed explanation if needed.
```

### Class Documentation

```dart
/// A widget that displays a single clipboard item.
/// 
/// Shows the content preview, source app icon, and timestamp.
/// Tapping the item copies it to clipboard.
class ClipListItem extends StatelessWidget {
  /// Creates a clip list item.
  /// 
  /// The [clip] parameter must not be null.
  const ClipListItem({
    super.key,
    required this.clip,
    this.onTap,
  });

  /// The clipboard item to display.
  final ClipItem clip;

  /// Called when the item is tapped.
  final VoidCallback? onTap;
}
```

### Method Documentation

```dart
/// Syncs the given clip to all paired devices.
/// 
/// Returns `true` if sync was successful, `false` otherwise.
/// 
/// Throws [SyncException] if no devices are paired.
/// Throws [EncryptionException] if encryption fails.
Future<bool> syncClip(ClipItem clip) async {
  // Implementation
}
```

---

## Testing Guidelines

### Unit Test Structure

```dart
// test/data/models/clip_item_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:clipsync/data/models/clip_item.dart';

void main() {
  group('ClipItem', () {
    test('creates with required fields', () {
      final clip = ClipItem(
        id: '123',
        content: 'Hello',
        type: ClipType.text,
      );
      
      expect(clip.id, '123');
      expect(clip.content, 'Hello');
    });

    test('toJson returns valid map', () {
      final clip = ClipItem(/* ... */);
      final json = clip.toJson();
      
      expect(json['id'], clip.id);
    });

    test('fromJson creates valid instance', () {
      final json = {'id': '123', 'content': 'Test'};
      final clip = ClipItem.fromJson(json);
      
      expect(clip.id, '123');
    });
  });
}
```

### Widget Test Structure

```dart
// test/presentation/clipboard/widgets/clip_list_item_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clipsync/presentation/clipboard/widgets/clip_list_item.dart';

void main() {
  group('ClipListItem', () {
    testWidgets('displays clip content', (tester) async {
      final clip = ClipItem(content: 'Test content');
      
      await tester.pumpWidget(
        MaterialApp(
          home: ClipListItem(clip: clip),
        ),
      );
      
      expect(find.text('Test content'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: ClipListItem(
            clip: ClipItem(content: 'Test'),
            onTap: () => tapped = true,
          ),
        ),
      );
      
      await tester.tap(find.byType(ClipListItem));
      expect(tapped, true);
    });
  });
}
```

---

## Git Workflow

### Branch Naming

```
feature/[feature-name]     # New features
fix/[issue-description]    # Bug fixes
refactor/[description]     # Code refactoring
docs/[description]         # Documentation
```

### Commit Messages

```
Format: [type]: [description]

Types:
  feat:     New feature
  fix:      Bug fix
  docs:     Documentation
  style:    Formatting
  refactor: Code restructuring
  test:     Adding tests
  chore:    Maintenance

Examples:
  feat: add clipboard sync functionality
  fix: resolve memory leak in clipboard monitor
  docs: update README with setup instructions
  refactor: extract encryption logic to service
```

### Pull Request Process

1. Create feature branch from `main`
2. Make changes with atomic commits
3. Write/update tests
4. Run `flutter analyze` and `flutter test`
5. Create PR with description
6. Request review
7. Address feedback
8. Merge when approved

---

## Debugging Tips

### Flutter DevTools

```
Open DevTools:
  flutter run
  Press 'd' in terminal
  Or: flutter pub global run devtools
```

### Logging

```dart
import 'package:clipsync/core/utils/logger.dart';

// Use throughout the app
Logger.info('Sync started');
Logger.error('Sync failed', error, stackTrace);
Logger.debug('Clip data: $clip');
```

### Platform Channel Debugging

```dart
// Enable verbose logging for method channels
import 'package:flutter/services.dart';

ServicesBinding.instance.defaultBinaryMessenger
    .setMockMessageHandler('clipboard_channel', (message) {
  print('Channel message: $message');
  return null;
});
```

---

## Common Issues

### macOS: App not starting

```
1. Check signing:
   Open Xcode > Signing & Capabilities
   
2. Reset sandbox:
   rm -rf ~/Library/Containers/com.clipsync.app

3. Check entitlements:
   macos/Runner/Release.entitlements
```

### Windows: Build fails

```
1. Run as Administrator
2. Check Visual Studio installation
3. flutter clean && flutter pub get
```

### iOS: Pod install fails

```
1. cd ios
2. rm -rf Pods Podfile.lock
3. pod install --repo-update
```

---

## Resources

| Resource | URL |
|----------|-----|
| Flutter Docs | flutter.dev/docs |
| Dart Docs | dart.dev/guides |
| Provider Package | pub.dev/packages/provider |
| Flutter DevTools | flutter.dev/docs/development/tools/devtools |
