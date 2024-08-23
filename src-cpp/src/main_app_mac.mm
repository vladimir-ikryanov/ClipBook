#include "main_app_mac.h"

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>

#define KEY_CODE_V ((CGKeyCode)9)

using namespace molybden;

/*
 * I have to use the deprecated LaunchServices functions for managing login items,
 * because there is no working alternative.
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
  open_app_item_->setShortcut(open_app_shortcut_);
  if (open_app_shortcut_.key == KeyCode::UNKNOWN) {
    return;
  }
  app()->globalShortcuts()->registerShortcut(open_app_shortcut_, [this](const Shortcut &) {
    // Users can set the same shortcut for opening and closing the app.
    if (settings_->getCloseAppShortcut() == settings_->getOpenAppShortcut()) {
      if (app_window_visible_) {
        hide();
      } else {
        show();
      }
    } else {
      show();
    }
  });
}

void MainAppMac::disableOpenAppShortcut() {
  if (open_app_shortcut_.key != KeyCode::UNKNOWN) {
    app()->globalShortcuts()->unregisterShortcut(open_app_shortcut_);
    open_app_shortcut_.key = KeyCode::UNKNOWN;
    open_app_item_->setShortcut(open_app_shortcut_);
  }
}

void MainAppMac::updateOpenSettingsShortcut() {
  auto shortcut_str = settings_->getOpenSettingsShortcut();
  open_settings_shortcut_ = createShortcut(shortcut_str);
  open_settings_item_->setShortcut(open_settings_shortcut_);
}

std::string MainAppMac::getUserDataDir() {
  std::string user_home_dir = std::getenv("HOME");
  return user_home_dir + "/Library/Application Support/" + app_->name();
}

void MainAppMac::activate() {
  // Activate the app to bring it to the front.
  NSApplication *app = [NSApplication sharedApplication];
  [app activateIgnoringOtherApps:YES];
}

void MainAppMac::show() {
  // Remember the active app to activate it after hiding the browser window.
  active_app_ = [[NSWorkspace sharedWorkspace] frontmostApplication];
  NSString *app_name = [active_app_ localizedName];
  MainApp::setActiveAppName([app_name UTF8String]);
  // Restore the window bounds before showing the window.
  restoreWindowBounds();
  // Show the browser window.
  MainApp::show();
}

void MainAppMac::hide() {
  // Do not hide the window at some conditions.
  if (auto_hide_disabled_) {
    return;
  }
  // Save the window bounds before hiding the window.
  saveWindowBounds();
  // Hide the window.
  MainApp::hide();
  // Activate the previously active app.
  if (active_app_) {
    [active_app_ activateWithOptions:NSApplicationActivateIgnoringOtherApps];
  }
}

void MainAppMac::paste() {
  // Simulate the key press of Command + V to paste the text into the active app.
  CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);

  CGEventRef key_down = CGEventCreateKeyboardEvent(source, KEY_CODE_V, TRUE);
  CGEventSetFlags(key_down, kCGEventFlagMaskCommand);
  CGEventRef key_up = CGEventCreateKeyboardEvent(source, KEY_CODE_V, FALSE);

  CGEventPost(kCGAnnotatedSessionEventTap, key_down);
  CGEventPost(kCGAnnotatedSessionEventTap, key_up);

  CFRelease(key_up);
  CFRelease(key_down);
  CFRelease(source);
}

void MainAppMac::paste(const std::string &text) {
  if (!isAccessibilityAccessGranted()) {
    showAccessibilityAccessDialog(text);
    return;
  }
  // Hide the browser window and activate the previously active app.
  hide();
  copyToClipboard(text);
  paste();
}

void MainAppMac::copyToClipboard(const std::string &text) {
  // Clear the pasteboard and set the new text.
  auto pasteboard = [NSPasteboard generalPasteboard];
  [pasteboard clearContents];
  [pasteboard setString:[NSString stringWithUTF8String:text.c_str()] forType:NSPasteboardTypeString];
}

std::string MainAppMac::getUpdateServerUrl() {
#ifdef ARCH_MAC_X64
  return "https://clipbook.app/downloads/mac/x64";
#endif
#ifdef ARCH_MAC_ARM64
  return "https://clipbook.app/downloads/mac/arm64";
#endif
#ifdef ARCH_MAC_UNIVERSAL
  return "https://clipbook.app/downloads/mac/universal";
#endif
}

void MainAppMac::restoreWindowBounds() {
  NSScreen *main_screen = [NSScreen mainScreen];
  NSNumber *screen_number = [[main_screen deviceDescription] objectForKey:@"NSScreenNumber"];
  auto bounds = settings_->getWindowBoundsForScreen([screen_number intValue]);
  if (bounds.size.isEmpty()) {
    auto screen_x = static_cast<int32_t>([main_screen frame].origin.x);
    auto screen_y = static_cast<int32_t>([main_screen frame].origin.y);
    app_window_->setPosition(screen_x, screen_y);
    app_window_->centerWindow();
  } else {
    app_window_->setBounds(bounds);
  }
}

void MainAppMac::saveWindowBounds() {
  NSScreen *main_screen = [NSScreen mainScreen];
  NSNumber *screen_number = [[main_screen deviceDescription] objectForKey:@"NSScreenNumber"];
  settings_->saveWindowBoundsForScreen([screen_number intValue], app_window_->bounds());
}

void MainAppMac::setOpenAtLogin(bool open) {
  if (open) {
    addAppToLoginItems();
  } else {
    removeAppFromLoginItems();
  }
}

AppInfo MainAppMac::getActiveAppInfo() {
  NSRunningApplication *app = [[NSWorkspace sharedWorkspace] frontmostApplication];
  if (app) {
    NSString *bundleId = [app bundleIdentifier];
    AppInfo app_info;
    app_info.id = [bundleId UTF8String];
    app_info.name = [[app localizedName] UTF8String];
    return app_info;
  }
  return {};
}

void MainAppMac::addAppToLoginItems() {
  LSSharedFileListRef items =
      LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
  if (!items) {
    return;
  }

  NSURL *url = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
  LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(
      items,
      kLSSharedFileListItemLast,
      NULL,
      NULL,
      ( __bridge CFURLRef) url,
      NULL,
      NULL
  );

  if (item) {
    CFRelease(item);
  }
}

void MainAppMac::removeAppFromLoginItems() {
  LSSharedFileListRef login_items_ref =
      LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
  if (!login_items_ref) {
    return;
  }

  NSURL *url = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];

  id login_item;
  CFURLRef path = NULL;
  UInt32 seed_value = 0;
  CFArrayRef login_items = LSSharedFileListCopySnapshot(login_items_ref, &seed_value);
  for (login_item in ( __bridge NSArray *) login_items) {
    LSSharedFileListItemRef login_item_ref = ( __bridge LSSharedFileListItemRef) login_item;
    if (LSSharedFileListItemResolve(login_item_ref, 0, (CFURLRef *) &path, NULL) == noErr) {
      {
        NSString *url_path = url.path;
        if (url_path == nil) {
          continue;
        }
        if ([(( __bridge NSURL *) path).path hasPrefix:url_path]) {
          CFRelease(path);
          LSSharedFileListItemRemove(login_items_ref, login_item_ref);
          break;
        }
        if (path != NULL) {
          CFRelease(path);
        }
      }
    }
  }

  if (login_items != NULL) {
    CFRelease(login_items);
  }
}

bool MainAppMac::init() {
  bool open_at_login = settings_->shouldOpenAtLogin();
  bool app_in_login_items = isAppInLoginItems();
  if (open_at_login && !app_in_login_items) {
    setOpenAtLogin(true);
  }
  if (!open_at_login && app_in_login_items) {
    setOpenAtLogin(false);
  }
  return MainApp::init();
}

bool MainAppMac::isAppInLoginItems() {
  LSSharedFileListRef login_items_ref =
      LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
  if (login_items_ref == NULL) {
    return NO;
  }

  NSURL *url = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];

  BOOL found = NO;

  id login_item;
  CFURLRef path = NULL;
  UInt32 seed_value = 0;
  CFArrayRef login_items = LSSharedFileListCopySnapshot(login_items_ref, &seed_value);
  for (login_item in ( __bridge NSArray *) login_items) {
    LSSharedFileListItemRef login_item_ref = ( __bridge LSSharedFileListItemRef) login_item;
    if (LSSharedFileListItemResolve(login_item_ref, 0, (CFURLRef *) &path, NULL) == noErr) {
      {
        NSString *url_path = url.path;
        if (url_path == nil) {
          continue;
        }
        if ([(( __bridge NSURL *) path).path hasPrefix:url_path]) {
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

  if (login_items != NULL) {
    CFRelease(login_items);
  }

  CFRelease(login_items_ref);
  return found;
}

bool MainAppMac::isAccessibilityAccessGranted() {
  return AXIsProcessTrusted();
}

void MainAppMac::showAccessibilityAccessDialog(const std::string &text) {
  MessageDialogOptions options;
  options.message = "Accessibility access required";
  options.informative_text = "ClipBook needs accessibility access to paste directly into other apps.";
  options.buttons = {
      MessageDialogButton("Enable Accessibility Access", MessageDialogButtonType::kDefault),
      MessageDialogButton("Copy to Clipboard"),
      MessageDialogButton("Cancel", MessageDialogButtonType::kCancel)
  };
  auto_hide_disabled_ = true;
  MessageDialog::show(app_window_, options, [this, text](const MessageDialogResult &result) {
    auto_hide_disabled_ = false;
    if (result.button.type == MessageDialogButtonType::kDefault) {
      hide();
      showSystemAccessibilityPreferencesDialog();
    }
    if (result.button.type == MessageDialogButtonType::kNone) {
      hide();
      copyToClipboard(text);
    }
  });
}

void MainAppMac::showSystemAccessibilityPreferencesDialog() {
  [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"]];
}
