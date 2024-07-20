#include "main_app_mac.h"

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>

#define KEY_CODE_V ((CGKeyCode)9)

using namespace molybden;

/*
 * LaunchServices functions for managing login items are deprecated,
 * but there's actually no viable alternative.
 * SystemManagement functions are not viable, because they require a separate
 * helper tool (complete app bundle) to be running constantly, for the sole
 * purpose of launching the main application.
 * Also, using SystemManagement, there's no way for the user to control the
 * login item, as it does not appear in the System Preferences, meaning there's
 * no way to delete the login item without the original app...
 * Common Apple, I think you can do better...
 */
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static std::string kShortcutSeparator = " + ";
static std::string kMeta = "Meta";
static std::string kControl = "Control";
static std::string kAlt = "Alt";
static std::string kShift = "Shift";
static std::map<std::string, KeyCode> kKeyCodes = {
    {"a", KeyCode::A},
    {"b", KeyCode::B},
    {"c", KeyCode::C},
    {"d", KeyCode::D},
    {"e", KeyCode::E},
    {"f", KeyCode::F},
    {"g", KeyCode::G},
    {"h", KeyCode::H},
    {"i", KeyCode::I},
    {"j", KeyCode::J},
    {"k", KeyCode::K},
    {"l", KeyCode::L},
    {"m", KeyCode::M},
    {"n", KeyCode::N},
    {"o", KeyCode::O},
    {"p", KeyCode::P},
    {"q", KeyCode::Q},
    {"r", KeyCode::R},
    {"s", KeyCode::S},
    {"t", KeyCode::T},
    {"u", KeyCode::U},
    {"v", KeyCode::V},
    {"w", KeyCode::W},
    {"x", KeyCode::X},
    {"y", KeyCode::Y},
    {"z", KeyCode::Z},
    {"0", KeyCode::DIGIT0},
    {"1", KeyCode::DIGIT1},
    {"2", KeyCode::DIGIT2},
    {"3", KeyCode::DIGIT3},
    {"4", KeyCode::DIGIT4},
    {"5", KeyCode::DIGIT5},
    {"6", KeyCode::DIGIT6},
    {"7", KeyCode::DIGIT7},
    {"8", KeyCode::DIGIT8},
    {"9", KeyCode::DIGIT9},
    {"F1", KeyCode::F1},
    {"F2", KeyCode::F2},
    {"F3", KeyCode::F3},
    {"F4", KeyCode::F4},
    {"F5", KeyCode::F5},
    {"F6", KeyCode::F6},
    {"F7", KeyCode::F7},
    {"F8", KeyCode::F8},
    {"F9", KeyCode::F9},
    {"F10", KeyCode::F10},
    {"F11", KeyCode::F11},
    {"F12", KeyCode::F12},
    {"F13", KeyCode::F13},
    {"F14", KeyCode::F14},
    {"F15", KeyCode::F15},
    {"F16", KeyCode::F16},
    {"F17", KeyCode::F17},
    {"F18", KeyCode::F18},
    {"F19", KeyCode::F19},
    {"F20", KeyCode::F20},
    {"F21", KeyCode::F21},
    {"F22", KeyCode::F22},
    {"F23", KeyCode::F23},
    {"F24", KeyCode::F24},
    {"Escape", KeyCode::ESC},
    {"Backspace", KeyCode::BACKSPACE},
    {"Tab", KeyCode::TAB},
    {"Space", KeyCode::SPACE},
    {"Enter", KeyCode::ENTER},
    {"MENU", KeyCode::MENU},
    {"Delete", KeyCode::DEL},
    {"Home", KeyCode::HOME},
    {"End", KeyCode::END},
    {"PageUp", KeyCode::PAGE_UP},
    {"PageDown", KeyCode::PAGE_DOWN},
    {"ArrowUp", KeyCode::UP},
    {"ArrowDown", KeyCode::DOWN},
    {"ArrowLeft", KeyCode::LEFT},
    {"ArrowRight", KeyCode::RIGHT},
    {"CapsLock", KeyCode::CAPSLOCK},
    {"NumLock", KeyCode::NUM_LOCK},
    {"ScrollLock", KeyCode::SCROLL_LOCK},
    {"Insert", KeyCode::INSERT},
    {";", KeyCode::SEMICOLON},
    {"=", KeyCode::EQUALS},
    {",", KeyCode::COMMA},
    {"-", KeyCode::MINUS},
    {".", KeyCode::PERIOD},
    {"/", KeyCode::SLASH},
    {"\\", KeyCode::BACKSLASH},
    {"`", KeyCode::BACK_QUOTE},
    {"'", KeyCode::QUOTE},
    {"[", KeyCode::OPEN_BRACE},
    {"]", KeyCode::CLOSE_BRACE},
};

std::vector<std::string> split(const std::string &str, const std::string &delimiter) {
  std::vector<std::string> result;
  size_t pos = 0;
  size_t start = 0;
  while ((pos = str.find(delimiter, start)) != std::string::npos) {
    result.push_back(str.substr(start, pos - start));
    start = pos + delimiter.length();
  }
  result.push_back(str.substr(start));
  return result;
}

int32_t extractKeyModifiers(const std::string &shortcut) {
  auto parts = split(shortcut, kShortcutSeparator);
  int32_t key_modifiers = 0;
  for (const auto &part : parts) {
    if (part == kMeta) {
      key_modifiers |= KeyModifier::COMMAND_OR_CTRL;
    } else if (part == kControl) {
      key_modifiers |= KeyModifier::CTRL;
    } else if (part == kAlt) {
      key_modifiers |= KeyModifier::ALT;
    } else if (part == kShift) {
      key_modifiers |= KeyModifier::SHIFT;
    }
  }
  return key_modifiers;
}

KeyCode extractKeyCode(const std::string &shortcut) {
  auto parts = split(shortcut, kShortcutSeparator);
  for (const auto &part : parts) {
    if (part == kMeta || part == kControl || part == kAlt || part == kShift) {
      continue;
    }
    auto it = kKeyCodes.find(part);
    if (it != kKeyCodes.end()) {
      return it->second;
    }
  }
  return KeyCode::UNKNOWN;
}

MainAppMac::MainAppMac(const std::shared_ptr<App> &app,
                       const std::shared_ptr<AppSettings> &settings)
    : MainApp(app, settings), active_app_(nullptr) {
}

molybden::Shortcut MainAppMac::createShortcut(const std::string &shortcut) {
  int32_t key_modifiers = extractKeyModifiers(shortcut);
  KeyCode key_code = extractKeyCode(shortcut);
  return molybden::Shortcut(key_code, key_modifiers);
}

void MainAppMac::enableOpenAppShortcut() {
  disableOpenAppShortcut();
  auto shortcut_str = settings_->getOpenAppShortcut();
  open_app_shortcut_ = createShortcut(shortcut_str);
  open_menu_item_->setShortcut(open_app_shortcut_);
  if (open_app_shortcut_.key == KeyCode::UNKNOWN) {
    return;
  }
  app()->globalShortcuts()->registerShortcut(open_app_shortcut_, [this](const Shortcut &) {
    show();
  });
}

void MainAppMac::disableOpenAppShortcut() {
  if (open_app_shortcut_.key != KeyCode::UNKNOWN) {
    app()->globalShortcuts()->unregisterShortcut(open_app_shortcut_);
    open_app_shortcut_.key = KeyCode::UNKNOWN;
    open_menu_item_->setShortcut(open_app_shortcut_);
  }
}

std::string MainAppMac::getUserDataDir() {
  std::string user_home_dir = std::getenv("HOME");
  return user_home_dir + "/Library/Application Support/" + app_->name();
}

void MainAppMac::activate() {
  // Get a reference to your NSApplication instance
  NSApplication *app = [NSApplication sharedApplication];

  // Activate your application, bringing it to the front
  [app activateIgnoringOtherApps:YES];
}

void MainAppMac::show() {
  active_app_ = [[NSWorkspace sharedWorkspace] frontmostApplication];
  NSString *app_name = [active_app_ localizedName];
  MainApp::setActiveAppName([app_name UTF8String]);
  // Restore the window bounds before showing the window.
  restoreWindowBounds();
  // Show the browser window.
  MainApp::show();
}

void MainAppMac::hide() {
  // Save the window bounds before hiding the window.
  saveWindowBounds();
  // Hide the window.
  MainApp::hide();
  if (active_app_) {
    [active_app_ activateWithOptions:NSApplicationActivateIgnoringOtherApps];
  }
}

void MainAppMac::paste() {
  CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);

  CGEventRef keyDown = CGEventCreateKeyboardEvent(source, KEY_CODE_V, TRUE);
  CGEventSetFlags(keyDown, kCGEventFlagMaskCommand);
  CGEventRef keyUp = CGEventCreateKeyboardEvent(source, KEY_CODE_V, FALSE);

  CGEventPost(kCGAnnotatedSessionEventTap, keyDown);
  CGEventPost(kCGAnnotatedSessionEventTap, keyUp);

  CFRelease(keyUp);
  CFRelease(keyDown);
  CFRelease(source);
}

void MainAppMac::paste(const std::string &text) {
  // Hide the browser window and activate the previously active app.
  hide();

  // Clear the pasteboard and set the new text.
  auto pasteboard = [NSPasteboard generalPasteboard];
  [pasteboard clearContents];
  [pasteboard setString:[NSString stringWithUTF8String:text.c_str()] forType:NSPasteboardTypeString];

  // Simulate the key press of Command + V to paste the text into the active app.
  paste();
}

std::string MainAppMac::getUpdateServerUrl() {
  return "https://clipbook.app/downloads/mac/universal";
}

void MainAppMac::restoreWindowBounds() {
  NSScreen *mainScreen = [NSScreen mainScreen];
  NSNumber *screenNumber = [[mainScreen deviceDescription] objectForKey:@"NSScreenNumber"];
  auto bounds = settings_->getWindowBoundsForScreen([screenNumber intValue]);
  if (bounds.size.isEmpty()) {
    auto screen_x = static_cast<int32_t>([mainScreen frame].origin.x);
    auto screen_y = static_cast<int32_t>([mainScreen frame].origin.y);
    browser_->setPosition(screen_x, screen_y);
    browser_->centerWindow();
  } else {
    browser_->setBounds(bounds);
  }
}

void MainAppMac::saveWindowBounds() {
  NSScreen *mainScreen = [NSScreen mainScreen];
  NSNumber *screenNumber = [[mainScreen deviceDescription] objectForKey:@"NSScreenNumber"];
  settings_->saveWindowBoundsForScreen([screenNumber intValue], browser_->bounds());
}

void MainAppMac::setOpenAtLogin(bool open) {
  if (open) {
    addAppToLoginItems();
  } else {
    removeAppFromLoginItems();
  }
}

void MainAppMac::addAppToLoginItems() {
  NSURL *url = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];

  LSSharedFileListRef loginItemsRef;
  LSSharedFileListItemRef loginItemRef;
  loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
  if (!loginItemsRef) {
    return;
  }

  loginItemRef = LSSharedFileListInsertItemURL(
      loginItemsRef,
      kLSSharedFileListItemLast,
      NULL,
      NULL,
      ( __bridge CFURLRef) url,
      NULL,
      NULL
  );

  if (loginItemRef) {
    CFRelease(loginItemRef);
  }
}

void MainAppMac::removeAppFromLoginItems() {
  NSURL *url = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];

  UInt32 seedValue;
  CFURLRef path;
  CFArrayRef loginItems;
  LSSharedFileListRef loginItemsRef;
  id loginItem;
  LSSharedFileListItemRef loginItemRef;

  path = NULL;
  seedValue = 0;
  loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
  if (!loginItemsRef) {
    return;
  }

  loginItems = LSSharedFileListCopySnapshot(loginItemsRef, &seedValue);
  for (loginItem in ( __bridge NSArray *) loginItems) {
    loginItemRef = ( __bridge LSSharedFileListItemRef) loginItem;
    if (LSSharedFileListItemResolve(loginItemRef, 0, (CFURLRef *) &path, NULL) == noErr) {
      {
        NSString *s;
        s = url.path;
        if (s == nil) {
          continue;
        }
        if ([(( __bridge NSURL *) path).path hasPrefix:s]) {
          CFRelease(path);
          LSSharedFileListItemRemove(loginItemsRef, loginItemRef);
          break;
        }
        if (path != NULL) {
          CFRelease(path);
        }
      }
    }
  }

  if (loginItems != NULL) {
    CFRelease(loginItems);
  }
}

bool MainAppMac::init() {
  bool openAtLogin = settings_->shouldOpenAtLogin();
  bool appInLoginItems = isAppInLoginItems();
  if (openAtLogin && !appInLoginItems) {
    setOpenAtLogin(true);
  }
  if (!openAtLogin && appInLoginItems) {
    setOpenAtLogin(false);
  }
  return MainApp::init();
}

bool MainAppMac::isAppInLoginItems() {
  NSURL *url = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];

  BOOL found = NO;
  UInt32 seedValue = 0;
  CFURLRef path = NULL;
  LSSharedFileListRef loginItemsRef;
  CFArrayRef loginItems;
  id loginItem;
  LSSharedFileListItemRef loginItemRef;

  loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
  if (loginItemsRef == NULL) {
    return NO;
  }

  loginItems = LSSharedFileListCopySnapshot(loginItemsRef, &seedValue);
  for (loginItem in ( __bridge NSArray *) loginItems) {
    loginItemRef = ( __bridge LSSharedFileListItemRef) loginItem;

    if (LSSharedFileListItemResolve(loginItemRef, 0, (CFURLRef *) &path, NULL) == noErr) {
      {
        NSString *s;
        s = url.path;
        if (s == nil) {
          continue;
        }

        if ([(( __bridge NSURL *) path).path hasPrefix:s]) {
          CFRelease(path);
          found = YES;
          break;
        }

        if (path != NULL) {
          CFRelease(path);
        }
      }
    }
  }

  if (loginItems != NULL) {
    CFRelease(loginItems);
  }

  CFRelease(loginItemsRef);
  return found;
}
