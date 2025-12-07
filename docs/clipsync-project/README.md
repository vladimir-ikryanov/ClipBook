# ClipSync - Project Documentation

## Overview

ClipSync is a cross-platform clipboard synchronization and file sharing application built with Flutter.

### Key Features

1. **Clipboard Sync** - Sync clipboard across Mac, Windows, Android, iOS via cloud
2. **File Sharing** - Share files directly on local network (like LocalSend/AirDrop)

---

## Documentation Index

| Document | Description |
|----------|-------------|
| `README.md` | This file - project overview and documentation index |
| `PROJECT_STRUCTURE.md` | Complete folder and file structure |
| `ARCHITECTURE.md` | System architecture and design |
| `FILE_SHARING_ARCHITECTURE.md` | Local file sharing feature design |
| `NAMING_CONVENTIONS.md` | Naming rules for files, folders, and code |
| `DEVELOPMENT_GUIDE.md` | How to set up and develop |

---

## Quick Links

- **Architecture**: See `ARCHITECTURE.md` for system design
- **Project Structure**: See `PROJECT_STRUCTURE.md` for all folders and files
- **Naming Rules**: See `NAMING_CONVENTIONS.md` for conventions

---

## Project Organization Rules

### 1. Folder Structure Principle

```
shared/          → Code that works on ALL platforms
platform/        → Platform-specific code
  ├── android/   → Android-only code
  ├── ios/       → iOS-only code
  ├── macos/     → macOS-only code
  └── windows/   → Windows-only code
```

### 2. File Size Principle

- **Maximum 300 lines per file** (prefer under 200)
- One class/widget per file
- Split large files into smaller focused files

### 3. Naming Principle

- **Folders**: `snake_case` (e.g., `clipboard_history/`)
- **Files**: `snake_case.dart` (e.g., `clip_item.dart`)
- **Classes**: `PascalCase` (e.g., `ClipItem`)
- **Functions**: `camelCase` (e.g., `getClipHistory()`)

### 4. Import Organization

```dart
// 1. Dart/Flutter imports
import 'dart:async';
import 'package:flutter/material.dart';

// 2. Package imports
import 'package:provider/provider.dart';

// 3. Local imports
import '../models/clip_item.dart';
```

---

## Core Principles

1. **Separation of Concerns** - UI, Logic, Data are separate
2. **Single Responsibility** - Each file does one thing
3. **Platform Abstraction** - Shared interface, platform implementation
4. **Clean Code** - Readable, maintainable, testable

---

## Getting Started

See `DEVELOPMENT_GUIDE.md` for setup instructions.
