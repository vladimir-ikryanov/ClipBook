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

MainAppMac::MainAppMac(const std::shared_ptr<App> &app,
                       const std::shared_ptr<AppSettings> &settings)
    : MainApp(app, settings), active_app_(nullptr) {
}

molybden::Shortcut MainAppMac::createShortcut(const std::string &shortcut_text) {
//  auto parts = split(shortcut_text, " + ");
//  // Extract key modifiers.
//  int32_t key_modifiers = 0;
//  for (const auto &part : parts) {
//    if (part == "Meta") {
//      key_modifiers |= KeyModifier::COMMAND_OR_CTRL;
//    } else if (part == "Control") {
//      key_modifiers |= KeyModifier::CTRL;
//    } else if (part == "Alt") {
//      key_modifiers |= KeyModifier::ALT;
//    } else if (part == "Shift") {
//      key_modifiers |= KeyModifier::SHIFT;
//    }
//  }
  // Extract key code.

  return molybden::Shortcut(KeyCode::V, KeyModifier::COMMAND_OR_CTRL | KeyModifier::SHIFT);
}

void MainAppMac::enableOpenAppShortcut() {
  auto shortcut_str = settings_->getOpenAppShortcut();
  open_app_shortcut_ = createShortcut(shortcut_str);
  app()->globalShortcuts()->registerShortcut(open_app_shortcut_, [this](const Shortcut &) {
    show();
  });
}

void MainAppMac::disableOpenAppShortcut() {
  app()->globalShortcuts()->unregisterShortcut(open_app_shortcut_);
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
