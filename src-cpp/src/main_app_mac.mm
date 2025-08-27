#include "main_app_mac.h"

#include "active_app_observer.h"
#include "quick_look_previewer_mac.h"

#import <ApplicationServices/ApplicationServices.h>
#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>

#include <filesystem>
#include <sys/sysctl.h>
#include <thread>

#define KEY_CODE_V ((CGKeyCode)9)
#define KEY_CODE_RETURN ((CGKeyCode)36)
#define KEY_CODE_TAB ((CGKeyCode)48)

using namespace molybden;

namespace fs = std::filesystem;

/*
 * I have to use the deprecated LaunchServices functions for managing login items,
 * because there is no working alternative.
 */
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// Open window strategy pref values.
static std::string kActiveScreenLastPosition = "activeScreenLastPosition";
static std::string kActiveScreenCenter = "activeScreenCenter";
static std::string kActiveWindowCenter = "activeWindowCenter";
static std::string kScreenWithCursor = "screenWithCursor";
static std::string kMouseCursor = "mouseCursor";
static std::string kInputCursor = "inputCursor";

// The minimum width and height of an active app window we can use to center the ClipBook window.
static int kMinAppWindowSize = 200;

static std::string kFilePathsSeparator = ":";
static std::string kAppInfoSeparator = "|";
static std::string kAppInfoListSeparator = "*";

static std::string kShortcutSeparator = " + ";
static std::string kMetaLeft = "MetaLeft";
static std::string kMetaRight = "MetaRight";
static std::string kControlLeft = "ControlLeft";
static std::string kControlRight = "ControlRight";
static std::string kAltLeft = "AltLeft";
static std::string kAltRight = "AltRight";
static std::string kShiftLeft = "ShiftLeft";
static std::string kShiftRight = "ShiftRight";
static std::map<std::string, KeyCode> kKeyCodes = {
    {"KeyA", KeyCode::A},
    {"KeyB", KeyCode::B},
    {"KeyC", KeyCode::C},
    {"KeyD", KeyCode::D},
    {"KeyE", KeyCode::E},
    {"KeyF", KeyCode::F},
    {"KeyG", KeyCode::G},
    {"KeyH", KeyCode::H},
    {"KeyI", KeyCode::I},
    {"KeyJ", KeyCode::J},
    {"KeyK", KeyCode::K},
    {"KeyL", KeyCode::L},
    {"KeyM", KeyCode::M},
    {"KeyN", KeyCode::N},
    {"KeyO", KeyCode::O},
    {"KeyP", KeyCode::P},
    {"KeyQ", KeyCode::Q},
    {"KeyR", KeyCode::R},
    {"KeyS", KeyCode::S},
    {"KeyT", KeyCode::T},
    {"KeyU", KeyCode::U},
    {"KeyV", KeyCode::V},
    {"KeyW", KeyCode::W},
    {"KeyX", KeyCode::X},
    {"KeyY", KeyCode::Y},
    {"KeyZ", KeyCode::Z},
    {"Digit0", KeyCode::DIGIT0},
    {"Digit1", KeyCode::DIGIT1},
    {"Digit2", KeyCode::DIGIT2},
    {"Digit3", KeyCode::DIGIT3},
    {"Digit4", KeyCode::DIGIT4},
    {"Digit5", KeyCode::DIGIT5},
    {"Digit6", KeyCode::DIGIT6},
    {"Digit7", KeyCode::DIGIT7},
    {"Digit8", KeyCode::DIGIT8},
    {"Digit9", KeyCode::DIGIT9},
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
    {"Semicolon", KeyCode::SEMICOLON},
    {"Equal", KeyCode::EQUALS},
    {"Comma", KeyCode::COMMA},
    {"Minus", KeyCode::MINUS},
    {"Period", KeyCode::PERIOD},
    {"Slash", KeyCode::SLASH},
    {"Backslash", KeyCode::BACKSLASH},
    {"Backquote", KeyCode::BACK_QUOTE},
    {"Quote", KeyCode::QUOTE},
    {"BracketLeft", KeyCode::OPEN_BRACE},
    {"BracketRight", KeyCode::CLOSE_BRACE},
};

void copyCustomClip(NSPasteboard *pasteboard) {
  NSString *str = @"ClipBook";
  NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];
  [pasteboard setData:data forType:@"com.clipbook.data"];
}

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
    if (part == kMetaLeft || part == kMetaRight) {
      key_modifiers |= KeyModifier::COMMAND_OR_CTRL;
    } else if (part == kControlLeft || part == kControlRight) {
      key_modifiers |= KeyModifier::CTRL;
    } else if (part == kAltLeft || part == kAltRight) {
      key_modifiers |= KeyModifier::ALT;
    } else if (part == kShiftLeft || part == kShiftRight) {
      key_modifiers |= KeyModifier::SHIFT;
    }
  }
  return key_modifiers;
}

KeyCode extractKeyCode(const std::string &shortcut) {
  auto parts = split(shortcut, kShortcutSeparator);
  for (const auto &part : parts) {
    if (part == kMetaLeft || part == kMetaRight
        || part == kControlLeft || part == kControlRight
        || part == kAltLeft || part == kAltRight
        || part == kShiftLeft || part == kShiftRight) {
      continue;
    }
    auto it = kKeyCodes.find(part);
    if (it != kKeyCodes.end()) {
      return it->second;
    }
  }
  return KeyCode::UNKNOWN;
}

/**
 * Returns true if the current machine is an Apple Silicon Mac.
 */
bool isAppleSilicon() {
  size_t size;
  sysctlbyname("hw.processor64", nullptr, &size, nullptr, 0);

  char processor[256];
  sysctlbyname("hw.machine", processor, &size, nullptr, 0);

  NSString *processorString = [NSString stringWithUTF8String:processor];
  if ([processorString containsString:@"arm64"]) {
    return true;
  }
  return false;
}

MainAppMac::MainAppMac(const std::shared_ptr<App> &app,
                       const std::shared_ptr<AppSettings> &settings) : MainApp(app, settings) {
  clipboard_reader_ = std::make_shared<ClipboardReaderMac>();
}

void MainAppMac::setActiveAppInfo(NSRunningApplication* activeApp) {
  if (activeApp) {
    auto app_path = [[activeApp bundleURL] fileSystemRepresentation];
    std::string app_name = getAppNameFromPath(app_path);
    if (app_name == "ClipBook") {
      should_activate_app_ = true;
      return;
    }
    should_activate_app_ = false;
    active_app_pid_ = activeApp.processIdentifier;
    std::string app_icon = getFileIconAsBase64(app_path, false);
    MainApp::setActiveAppInfo(app_name, app_icon);
  }
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
  auto shortcuts = app()->globalShortcuts();
  bool success = shortcuts->registerShortcut(open_app_shortcut_, [this](const Shortcut &) {
    // Users can set the same shortcut for opening and closing the app.
    auto openAppShortcut = settings_->getOpenAppShortcut();
    auto closeAppShortcut = settings_->getCloseAppShortcut();
    auto closeAppShortcut2 = settings_->getCloseAppShortcut2();
    auto closeAppShortcut3 = settings_->getCloseAppShortcut3();
    if (closeAppShortcut == openAppShortcut ||
        closeAppShortcut2 == openAppShortcut ||
        closeAppShortcut3 == openAppShortcut) {
      if (app_window_visible_) {
        hide(true);
      } else {
        show();
      }
    } else {
      show();
    }
  });
  if (!success) {
    LOG(ERROR) << "Failed to register global shortcut: " << shortcut_str;
    open_app_shortcut_ = molybden::Shortcut();
  }
}

void MainAppMac::disableOpenAppShortcut() {
  if (open_app_shortcut_.key != KeyCode::UNKNOWN) {
    app()->globalShortcuts()->unregisterShortcut(open_app_shortcut_);
    open_app_shortcut_.key = KeyCode::UNKNOWN;
    open_app_item_->setShortcut(open_app_shortcut_);
  }
}

void MainAppMac::enablePauseResumeShortcut() {
  disablePauseResumeShortcut();
  auto shortcut_str = settings_->getPauseResumeShortcut();
  pause_resume_shortcut_ = createShortcut(shortcut_str);
  pause_resume_item_->setShortcut(pause_resume_shortcut_);
  if (pause_resume_shortcut_.key == KeyCode::UNKNOWN) {
    return;
  }
  auto shortcuts = app()->globalShortcuts();
  bool success = shortcuts->registerShortcut(pause_resume_shortcut_, [this](const Shortcut &) {
    if (isPaused()) {
      resume();
    } else {
      pause();
    }
  });
  if (!success) {
    LOG(ERROR) << "Failed to register global shortcut: " << shortcut_str;
    pause_resume_shortcut_ = molybden::Shortcut();
  }
}

void MainAppMac::disablePauseResumeShortcut() {
  if (pause_resume_shortcut_.key != KeyCode::UNKNOWN) {
    app()->globalShortcuts()->unregisterShortcut(pause_resume_shortcut_);
    pause_resume_shortcut_.key = KeyCode::UNKNOWN;
    pause_resume_item_->setShortcut(pause_resume_shortcut_);
  }
}

void MainAppMac::enablePasteNextItemShortcut() {
  disablePasteNextItemShortcut();
  auto shortcut_str = settings_->getPasteNextItemShortcut();
  paste_next_item_shortcut_ = createShortcut(shortcut_str);
  if (paste_next_item_shortcut_.key == KeyCode::UNKNOWN) {
    return;
  }
  auto shortcuts = app()->globalShortcuts();
  bool success = shortcuts->registerShortcut(paste_next_item_shortcut_, [this](const Shortcut &) {
    pasteNextItemToActiveApp();
  });
  if (!success) {
    LOG(ERROR) << "Failed to register global shortcut: " << shortcut_str;
    // Reset the shortcut to an empty one if registration fails to avoid crash when we try to
    // unregister it later.
    paste_next_item_shortcut_ = molybden::Shortcut();
  }
}

void MainAppMac::disablePasteNextItemShortcut() {
  if (paste_next_item_shortcut_.key != KeyCode::UNKNOWN) {
    app()->globalShortcuts()->unregisterShortcut(paste_next_item_shortcut_);
    paste_next_item_shortcut_.key = KeyCode::UNKNOWN;
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
  // Update the active app info because it may be already active when the window is shown.
  setActiveAppInfo([[NSWorkspace sharedWorkspace] frontmostApplication]);
  // Restore the window bounds before showing the window.
  restoreWindowBounds();
  // Show the browser window.
  MainApp::show();
}

void MainAppMac::hide() {
  MainApp::hide();
}

void MainAppMac::hide(bool force) {
  // Do not hide the window at some conditions.
  if (auto_hide_disabled_) {
    return;
  }
  // Save the window bounds before hiding the window.
  saveWindowBounds();
  // Hide the window.
  MainApp::hide(force);
  // Activate the previously active app.
  if (should_activate_app_ && active_app_pid_ != 0) {
    auto runningApps = [[NSWorkspace sharedWorkspace] runningApplications];
    for (NSRunningApplication *app in runningApps) {
      if (app.processIdentifier == active_app_pid_) {
        [app activateWithOptions:NSApplicationActivateIgnoringOtherApps];
        break;
      }
    }
    // 150 milliseconds delay to let the target app process the activation.
    usleep(150000);
  }
}

void MainAppMac::sendKey(MainApp::Key key) {
  CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);

  CGEventRef key_down = nullptr;
  CGEventRef key_up = nullptr;

  if (key == Key::kCmdV) {
    key_down = CGEventCreateKeyboardEvent(source, KEY_CODE_V, TRUE);
    CGEventSetFlags(key_down, kCGEventFlagMaskCommand);
    key_up = CGEventCreateKeyboardEvent(source, KEY_CODE_V, FALSE);
  } else if (key == Key::kReturn) {
    key_down = CGEventCreateKeyboardEvent(source, KEY_CODE_RETURN, TRUE);
    key_up = CGEventCreateKeyboardEvent(source, KEY_CODE_RETURN, FALSE);
  } else if (key == Key::kTab) {
    key_down = CGEventCreateKeyboardEvent(source, KEY_CODE_TAB, TRUE);
    key_up = CGEventCreateKeyboardEvent(source, KEY_CODE_TAB, FALSE);
  } else {
    CFRelease(source);
    return;
  }

  CGEventPost(kCGAnnotatedSessionEventTap, key_down);
  CGEventPost(kCGAnnotatedSessionEventTap, key_up);

  CFRelease(key_up);
  CFRelease(key_down);
  CFRelease(source);

  // 50 milliseconds delay to let the target app process the key combination.
  usleep(50000);
}

void MainAppMac::paste() {
  sendKey(Key::kCmdV);
}

void MainAppMac::paste(const std::string &filePaths) {
  if (!isAccessibilityAccessGranted()) {
    showAccessibilityAccessDialog(filePaths);
    return;
  }
  // Hide the browser window and activate the previously active app.
  hide();
  copyToClipboard(filePaths, true);
  paste();
}

void MainAppMac::paste(const std::string &text,
                       const std::string &rtf,
                       const std::string &html,
                       const std::string &imageFileName,
                       const std::string &filePath) {
  if (!isAccessibilityAccessGranted()) {
    showAccessibilityAccessDialog(text, imageFileName, filePath);
    return;
  }
  // Hide the browser window and activate the previously active app.
  hide();
  copyToClipboard(text, rtf, html, imageFileName, filePath, true);
  paste();
}

void MainAppMac::copyToClipboard(const std::string &filePaths, bool ghost) {
  if (filePaths.empty()) {
    return;
  }

  auto pasteboard = [NSPasteboard generalPasteboard];
  // Clear the pasteboard and set the new text.
  [pasteboard clearContents];

  NSMutableArray *items = [NSMutableArray array];

  // Copy files.
  auto paths = split(filePaths, kFilePathsSeparator);
  for (const auto &path : paths) {
    auto fileUrl = [NSURL fileURLWithPath:[NSString stringWithUTF8String:path.c_str()]];
    NSPasteboardItem *fileItem = [[NSPasteboardItem alloc] init];
    [fileItem setString:[fileUrl absoluteString] forType:NSPasteboardTypeFileURL];
    [items addObject:fileItem];
  }

  [pasteboard writeObjects:items];
  if (ghost) {
    copyCustomClip(pasteboard);
  }
}

void MainAppMac::copyToClipboard(const std::string &text,
                                 const std::string &rtf,
                                 const std::string &html,
                                 const std::string &imageFileName,
                                 const std::string &filePath,
                                 bool ghost) {
  auto pasteboard = [NSPasteboard generalPasteboard];
  // Clear the pasteboard and set the new text.
  [pasteboard clearContents];

  NSMutableArray *items = [NSMutableArray array];

  // Copy file.
  if (!filePath.empty()) {
    auto fileUrl = [NSURL fileURLWithPath:[NSString stringWithUTF8String:filePath.c_str()]];
    NSPasteboardItem *fileItem = [[NSPasteboardItem alloc] init];
    [fileItem setString:[fileUrl absoluteString] forType:NSPasteboardTypeFileURL];
    [items addObject:fileItem];
  }

  // Copy image.
  if (!imageFileName.empty()) {
    fs::path imagesDir = getImagesDir();
    auto imageFilePath = [NSString stringWithUTF8String:imagesDir.append(imageFileName).c_str()];
    NSImage *image = [[NSImage alloc] initWithContentsOfFile:imageFilePath];
    if (image) {
      NSBitmapImageRep *imageRep = [[NSBitmapImageRep alloc] initWithData:[image TIFFRepresentation]];
      NSData *data = [imageRep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
      NSPasteboardItem *imageItem = [[NSPasteboardItem alloc] init];
      [imageItem setData:data forType:NSPasteboardTypePNG];
      [items addObject:imageItem];
      [imageRep release];
      [image release];
    }
  }

  // Copy text.
  if (!text.empty()) {
    // Copy plain text.
    NSPasteboardItem *textItem = [[NSPasteboardItem alloc] init];
    [textItem setString:[NSString stringWithUTF8String:text.c_str()] forType:NSPasteboardTypeString];

    // Copy RTF text.
    if (!rtf.empty()) {
      [textItem setString:[NSString stringWithUTF8String:rtf.c_str()] forType:NSPasteboardTypeRTF];
    }

    // Copy HTML text.
    if (!html.empty()) {
      [textItem setString:[NSString stringWithUTF8String:html.c_str()] forType:NSPasteboardTypeHTML];
    }

    [items addObject:textItem];
  }

  [pasteboard writeObjects:items];
  if (ghost) {
    copyCustomClip(pasteboard);
  }
}

void MainAppMac::copyToClipboardAfterMerge(std::string text) {
  clipboard_reader_->copyToClipboardAfterMerge(std::move(text));
}

std::string MainAppMac::getUpdateServerUrl() {
  if (isAppleSilicon()) {
    return "https://clipbook.app/downloads/mac/arm64";
  }
  return "https://clipbook.app/downloads/mac/x64";
}

void MainAppMac::restoreWindowBounds() {
  auto strategy = settings_->getOpenWindowStrategy();
  if (strategy == kActiveScreenLastPosition) {
    moveToLastPositionOnActiveScreen();
  }
  if (strategy == kActiveScreenCenter) {
    moveToActiveScreenCenter();
  }
  if (strategy == kActiveWindowCenter) {
    if (!moveToActiveWindowCenter()) {
      moveToActiveScreenCenter();
    }
  }
  if (strategy == kScreenWithCursor) {
    if (!moveToScreenWithMousePointer()) {
      moveToActiveScreenCenter();
    }
  }
  if (strategy == kMouseCursor) {
    moveToMousePointerLocation();
  }
  if (strategy == kInputCursor) {
    if (!moveToInputCursorLocation()) {
      if (!moveToActiveWindowCenter()) {
        moveToActiveScreenCenter();
      }
    }
  }
}

NSScreen *screenContainingMousePointer() {
  // Get the current mouse location in global screen coordinates
  NSPoint mouseLocation = [NSEvent mouseLocation];
  for (NSScreen *screen in [NSScreen screens]) {
    if (NSPointInRect(mouseLocation, screen.frame)) {
      return screen;
    }
  }
  return nil;
}

void MainAppMac::moveToScreen(NSScreen *screen) {
  auto window_size = restoreWindowSize();
  auto primary_screen = [[NSScreen screens] firstObject];
  auto primary_screen_bounds = [primary_screen frame];
  auto screen_bounds = [screen frame];
  auto x = static_cast<int32_t>((screen_bounds.size.width - window_size.width) / 2);
  auto y = static_cast<int32_t>((screen_bounds.size.height - window_size.height) / 2);
  x += static_cast<int32_t>(screen_bounds.origin.x);
  y += static_cast<int32_t>(primary_screen_bounds.size.height - (screen_bounds.origin.y + screen_bounds.size.height));
  app_window_->setPosition(x, y);
}

bool MainAppMac::moveToScreenWithMousePointer() {
  auto screen = screenContainingMousePointer();
  if (screen) {
    moveToScreen(screen);
    return true;
  }
  return false;
}

void MainAppMac::moveToMousePointerLocation() {
  auto window_size = restoreWindowSize();
  NSPoint mouse_location = [NSEvent mouseLocation];
  auto x = static_cast<int32_t>(mouse_location.x);
  auto primary_screen = [[NSScreen screens] firstObject];
  auto primary_screen_bounds = [primary_screen frame];
  auto y = static_cast<int32_t>(primary_screen_bounds.size.height - mouse_location.y);
  app_window_->setPosition(x + 5, y + 5);
}

bool MainAppMac::moveToInputCursorLocation() {
  auto caret_position = getInputCursorLocationOnScreen();
  if (caret_position.x == 0 && caret_position.y == 0) {
    return false;
  }
  restoreWindowSize();
  auto x = static_cast<int32_t>(caret_position.x);
  auto y = static_cast<int32_t>(caret_position.y);
  app_window_->setPosition(x, y);
  return true;
}

molybden::Size MainAppMac::restoreWindowSize() {
  auto window_bounds = settings_->getWindowBounds();
  if (!window_bounds.size.isEmpty()) {
    app_window_->setSize(window_bounds.size);
    return window_bounds.size;
  }
  return app_window_->bounds().size;
}

void MainAppMac::moveToActiveScreenCenter() {
  auto screen = [NSScreen mainScreen];
  moveToScreen(screen);
}

NSRect MainAppMac::getActiveWindowBounds(NSRunningApplication *app) {
  // Exclude desktop elements and include only on-screen windows.
  CFArrayRef windowListInfo = CGWindowListCopyWindowInfo(
      kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID);
  if (!windowListInfo) {
    return {};
  }
  NSRect windowBounds = {};
  auto windowInfoList = (__bridge NSArray *)windowListInfo;
  for (NSDictionary *info in windowInfoList) {
    NSNumber *windowPID = info[(__bridge NSString *)kCGWindowOwnerPID];
    if (windowPID && windowPID.unsignedIntValue == [app processIdentifier]) {
      NSDictionary *boundsDict = info[(__bridge NSString *)kCGWindowBounds];
      if (boundsDict) {
        NSNumber *x = boundsDict[@"X"];
        NSNumber *y = boundsDict[@"Y"];
        NSNumber *width = boundsDict[@"Width"];
        NSNumber *height = boundsDict[@"Height"];
        if (x && y && width && height) {
          // The last window in the list is the active window.
          windowBounds = NSMakeRect(x.doubleValue, y.doubleValue, width.doubleValue, height.doubleValue);
        }
      }
    }
  }
  CFRelease(windowListInfo);
  return windowBounds;
}

bool MainAppMac::moveToActiveWindowCenter() {
  auto window_size = restoreWindowSize();
  // Get the active window bounds on screen.
  auto active_app = [[NSWorkspace sharedWorkspace] frontmostApplication];
  if (active_app) {
    auto active_window_bounds = getActiveWindowBounds(active_app);
    if (!NSIsEmptyRect(active_window_bounds) &&
        (active_window_bounds.size.width > kMinAppWindowSize &&
         active_window_bounds.size.height > kMinAppWindowSize)) {
      // Move the window to the center of the active window.
      auto x = static_cast<int32_t>(active_window_bounds.origin.x +
                                    (active_window_bounds.size.width - window_size.width) / 2);
      auto y = static_cast<int32_t>(active_window_bounds.origin.y +
                                    (active_window_bounds.size.height - window_size.height) / 2);
      app_window_->setPosition(x, y);
      return true;
    }
  }
  return false;
}

void MainAppMac::moveToLastPositionOnActiveScreen() {
  NSScreen *main_screen = [NSScreen mainScreen];
  NSNumber *screen_number = [[main_screen deviceDescription] objectForKey:@"NSScreenNumber"];
  int screen_id = [screen_number intValue];
  auto screen_frame = [main_screen frame];
  auto screen_origin = molybden::Point(static_cast<int32_t>(screen_frame.origin.x),
                                       static_cast<int32_t>(screen_frame.origin.y));
  auto screen_size = molybden::Size(static_cast<int32_t>(screen_frame.size.width),
                                    static_cast<int32_t>(screen_frame.size.height));
  auto screen_bounds = molybden::Rect(screen_origin, screen_size);
  auto window_bounds = settings_->getWindowBoundsForScreen(screen_id, screen_bounds);
  if (!window_bounds.size.isEmpty()) {
    app_window_->setBounds(window_bounds);
  } else {
    moveToScreen(main_screen);
  }
}

void MainAppMac::saveWindowBounds() {
  NSScreen *main_screen = [NSScreen mainScreen];
  NSNumber *screen_number = [[main_screen deviceDescription] objectForKey:@"NSScreenNumber"];
  int screen_id = [screen_number intValue];
  auto screen_frame = [main_screen frame];
  auto screen_origin = molybden::Point(static_cast<int32_t>(screen_frame.origin.x),
                                       static_cast<int32_t>(screen_frame.origin.y));
  auto screen_size = molybden::Size(static_cast<int32_t>(screen_frame.size.width),
                                    static_cast<int32_t>(screen_frame.size.height));
  auto screen_bounds = molybden::Rect(screen_origin, screen_size);
  auto window_bounds = app_window_->bounds();
  settings_->saveWindowBoundsForScreen(screen_id, screen_bounds, window_bounds);
  settings_->saveWindowBounds(window_bounds);
}

void MainAppMac::setOpenAtLogin(bool open) {
  if (open) {
    addAppToLoginItems();
  } else {
    removeAppFromLoginItems();
  }
}

AppInfo MainAppMac::getAppInfo() {
  AppInfo app_info;
  NSString *app_path = [[NSBundle mainBundle] bundlePath];
  app_info.path = [app_path fileSystemRepresentation];
  return app_info;
}

AppInfo MainAppMac::getActiveAppInfo() {
  AppInfo app_info;
  NSRunningApplication *app = [[NSWorkspace sharedWorkspace] frontmostApplication];
  if (app) {
    app_info.path = [[app bundleURL] fileSystemRepresentation];
    return app_info;
  }
  return app_info;
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

void MainAppMac::launch() {
  MainApp::launch();
  clipboard_reader_->start(shared_from_this());
  ActiveAppObserver* active_app_watcher = nullptr;
  active_app_watcher = [[ActiveAppObserver alloc] initWithCallback:[this](void* app) {
    NSRunningApplication* activeApp = (__bridge NSRunningApplication *)app;
    this->setActiveAppInfo(activeApp);
  }];
  [active_app_watcher startObserving];

  // Set up observer for application activation events.
  setupApplicationObservers();
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

void MainAppMac::showAccessibilityAccessDialog(const std::string &filePaths) {
  MessageDialogOptions options;
  options.message = i18n("app.dialogs.accessibilityAccessRequired.message");
  options.informative_text = i18n("app.dialogs.accessibilityAccessRequired.informativeText");
  options.buttons = {
      MessageDialogButton(i18n("app.dialogs.accessibilityAccessRequired.enableAccessibility"), MessageDialogButtonType::kDefault),
      MessageDialogButton(i18n("app.dialogs.accessibilityAccessRequired.copyToClipboard")),
      MessageDialogButton(i18n("app.dialogs.accessibilityAccessRequired.cancel"), MessageDialogButtonType::kCancel)
  };
  auto_hide_disabled_ = true;
  MessageDialog::show(app_window_, options, [this, filePaths](const MessageDialogResult &result) {
    auto_hide_disabled_ = false;
    if (result.button.type == MessageDialogButtonType::kDefault) {
      hide();
      showSystemAccessibilityPreferencesDialog();
    }
    if (result.button.type == MessageDialogButtonType::kNone) {
      hide();
      copyToClipboard(filePaths, true);
    }
  });
}

void MainAppMac::showAccessibilityAccessDialog(const std::string &text,
                                               const std::string &imageFileName,
                                               const std::string &filePath) {
  MessageDialogOptions options;
  options.message = i18n("app.dialogs.accessibilityAccessRequired.message");
  options.informative_text = i18n("app.dialogs.accessibilityAccessRequired.informativeText");
  options.buttons = {
      MessageDialogButton(i18n("app.dialogs.accessibilityAccessRequired.enableAccessibility"),
                          MessageDialogButtonType::kDefault),
      MessageDialogButton(i18n("app.dialogs.accessibilityAccessRequired.copyToClipboard")),
      MessageDialogButton(i18n("app.dialogs.accessibilityAccessRequired.cancel"),
                          MessageDialogButtonType::kCancel)
  };
  auto_hide_disabled_ = true;
  MessageDialog::show(app_window_, options, [this, text, imageFileName, filePath](const MessageDialogResult &result) {
    auto_hide_disabled_ = false;
    if (result.button.type == MessageDialogButtonType::kDefault) {
      hide();
      showSystemAccessibilityPreferencesDialog();
    }
    if (result.button.type == MessageDialogButtonType::kNone) {
      hide();
      copyToClipboard(text, "", "", imageFileName, filePath, true);
    }
  });
}

void MainAppMac::showSystemAccessibilityPreferencesDialog() {
  [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"]];
}

std::string MainAppMac::getFileIconAsBase64(const std::string &app_path, bool large) {
  @autoreleasepool {
    std::string path = app_path;
    // Check if the given app_path is "ClipBook.app".
    if (app_path.find("ClipBook.app") != std::string::npos) {
      path = getAppInfo().path;
    }

    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    NSImage *image = [workspace iconForFile:[NSString stringWithUTF8String:path.c_str()]];
    if (large) {
      [image setSize:NSMakeSize(512, 512)];
    }
    // Convert NSImage to NSData (using PNG format in this example).
    CGImageRef cgRef = [image CGImageForProposedRect:nullptr context:nil hints:nil];
    NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithCGImage:cgRef];
    [newRep setSize:[image size]];   // Ensure correct size

    NSData *imageData = [newRep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];

    // Base64 encode the data
    NSString *base64String = [imageData base64EncodedStringWithOptions:0];

    return [base64String UTF8String];
  }
}

std::string MainAppMac::getAppNameFromPath(const std::string &app_path) {
  @autoreleasepool {
    std::string path = app_path;
    // Check if the given app_path is "ClipBook.app".
    if (app_path.find("ClipBook.app") != std::string::npos) {
      path = getAppInfo().path;
    }

    NSBundle *appBundle = [NSBundle bundleWithPath:[NSString stringWithUTF8String:path.c_str()]];
    if (appBundle) {
      NSString *appName = [[appBundle infoDictionary] objectForKey:@"CFBundleName"];
      if (!appName) {
        appName = [[appBundle infoDictionary] objectForKey:@"CFBundleDisplayName"];
      }
      return appName ? [appName UTF8String] : "";
    }
    return {};
  }
}

long MainAppMac::getSystemBootTime() {
  struct timeval boot_time{};
  size_t size = sizeof(boot_time);
  int mib[2] = {CTL_KERN, KERN_BOOTTIME};
  if (sysctl(mib, 2, &boot_time, &size, nullptr, 0) != -1 && boot_time.tv_sec != 0) {
    return boot_time.tv_sec;
  }
  return -1;
}

NSPoint MainAppMac::getInputCursorLocationOnScreen() {
  // Get the system-wide accessibility object
  AXUIElementRef systemWideElement = AXUIElementCreateSystemWide();

  // Get the focused element
  AXUIElementRef focusedElement = nullptr;
  AXError error = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute, (CFTypeRef *)&focusedElement);
  CFRelease(systemWideElement);

  if (error != kAXErrorSuccess || focusedElement == nullptr) {
    NSLog(@"Failed to get the focused element");
    return NSZeroPoint;
  }

  // Check if the focused element supports the AXSelectedTextRange attribute
  Boolean hasTextRange = false;
  error = AXUIElementIsAttributeSettable(focusedElement, kAXSelectedTextRangeAttribute, &hasTextRange);
  if (error != kAXErrorSuccess || !hasTextRange) {
    NSLog(@"Focused element does not support text ranges");
    CFRelease(focusedElement);
    return NSZeroPoint;
  }

  // Get the selected text range (text caret location)
  CFTypeRef textRangeValue = nullptr;
  error = AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextRangeAttribute, &textRangeValue);
  if (error != kAXErrorSuccess || textRangeValue == nullptr) {
    NSLog(@"Failed to get the selected text range");
    CFRelease(focusedElement);
    return NSZeroPoint;
  }

  // Request the bounds for the selected text range
  CFTypeRef boundsValue = nullptr;
  error = AXUIElementCopyParameterizedAttributeValue(focusedElement, kAXBoundsForRangeParameterizedAttribute, textRangeValue, &boundsValue);
  CFRelease(textRangeValue);

  if (error != kAXErrorSuccess || boundsValue == nullptr) {
    NSLog(@"Failed to get the bounds for the text range");
    CFRelease(focusedElement);
    return NSZeroPoint;
  }

  CGRect caretBounds = CGRectZero;
  if (AXValueGetValue((AXValueRef)boundsValue, kAXValueTypeCGRect, &caretBounds)) {
    NSLog(@"Caret bounds: (%f, %f), size: (%f, %f)", caretBounds.origin.x, caretBounds.origin.y, caretBounds.size.width, caretBounds.size.height);
  }
  CFRelease(boundsValue);
  CFRelease(focusedElement);
  caretBounds.origin.x += 4;
  caretBounds.origin.y += caretBounds.size.height + 6;

  // Return the caret's position as an NSPoint
  return NSPointFromCGPoint(caretBounds.origin);
}

std::string MainAppMac::getAppInfo(const std::string &app_path) {
  auto appName = getAppNameFromPath(app_path);
  if (appName.empty()) {
    return "";
  }
  auto appIcon = getFileIconAsBase64(app_path, false);
  if (appIcon.empty()) {
    return "";
  }
  return appName + kAppInfoSeparator + app_path + kAppInfoSeparator + appIcon;
}

std::string MainAppMac::getDefaultAppInfo(const std::string &file_path) {
  NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
  // Get the default app path for the given file path.
  NSURL *appUrl = [workspace URLForApplicationToOpenURL:[NSURL fileURLWithPath:[NSString stringWithUTF8String:file_path.c_str()]]];
  if (appUrl) {
    return getAppInfo([appUrl fileSystemRepresentation]);
  }
  return "";
}

std::string MainAppMac::getRecommendedAppsInfo(const std::string &file_path) {
  @autoreleasepool {
    std::string result;
    NSURL *fileUrl = [NSURL fileURLWithPath:[NSString stringWithUTF8String:file_path.c_str()]];
    NSArray<NSURL *> *appUrls = [[NSWorkspace sharedWorkspace] URLsForApplicationsToOpenURL:fileUrl];
    if (appUrls) {
      for (NSURL *appUrl in appUrls) {
        auto appInfo = getAppInfo([appUrl fileSystemRepresentation]);
        if (!appInfo.empty()) {
          result += appInfo + kAppInfoListSeparator;
        }
      }
    }
    return result;
  }
}

std::string MainAppMac::getAllAppsInfo() {
  @autoreleasepool {
    std::string result;
    NSString *applicationsPath = @"/Applications";
    NSArray<NSString *> *appList = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:applicationsPath error:nil];
    for (NSString *appName in appList) {
      if ([appName.pathExtension isEqualToString:@"app"]) {
        NSString *fullPath = [applicationsPath stringByAppendingPathComponent:appName];
        auto appInfo = getAppInfo([fullPath UTF8String]);
        if (!appInfo.empty()) {
          result += appInfo + kAppInfoListSeparator;
        }
      }
    }
    return result;
  }
}

void MainAppMac::openInApp(const std::string &file_path, const std::string &app_path) {
  @autoreleasepool {
    NSString *nsFilePath = [NSString stringWithUTF8String:file_path.c_str()];
    NSString *nsAppPath = [NSString stringWithUTF8String:app_path.c_str()];

    NSURL *fileURL = [NSURL fileURLWithPath:nsFilePath];
    NSURL *appURL = [NSURL fileURLWithPath:nsAppPath];

    NSError *error = nil;
    NSRunningApplication *app = [[NSWorkspace sharedWorkspace] openURLs:@[fileURL]
                                                   withApplicationAtURL:appURL
                                                                options:NSWorkspaceLaunchDefault
                                                          configuration:@{}
                                                                  error:&error];
    if (app == nil) {
      NSLog(@"Failed to open file: %@", error.localizedDescription);
    }
  }
}

void MainAppMac::preview(const std::string &file_path) {
  auto_hide_disabled_ = true;
  app_window_->setAlwaysOnTop(false);
  NSString *filePath = [NSString stringWithUTF8String:file_path.c_str()];
  dispatch_async(dispatch_get_main_queue(), ^{
    [[QuickLookPreviewer shared] setOnCloseCallback:^{
      auto_hide_disabled_ = false;
      app_window_->setAlwaysOnTop(true);
    }];
    [[QuickLookPreviewer shared] previewFileAtPath:filePath];
  });
}

void MainAppMac::setupApplicationObservers() {
  // Set up observer for application activation events.
  [[NSNotificationCenter defaultCenter]
      addObserverForName:NSApplicationDidBecomeActiveNotification
                  object:[NSApplication sharedApplication]
                   queue:[NSOperationQueue mainQueue]
              usingBlock:^(NSNotification *notification) {
                // When the app becomes active (e.g., launched by Raycast),
                // check if we should hide it from dock and re-hide if necessary.
                // Use a small delay to ensure the activation process is complete.
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 50 * NSEC_PER_MSEC),
                               dispatch_get_main_queue(), ^{
                      std::thread([this]() {
                        if (app()->dock()->isVisible()) {
                          app()->dock()->hide();
                        }
                      }).detach();
                    });
              }];
}
