#include "main_app_mac.h"

#import <Foundation/Foundation.h>

#define KEY_CODE_V ((CGKeyCode)9)

using namespace molybden;

MainAppMac::MainAppMac(const std::shared_ptr<App> &app) : MainApp(app), active_app_(nullptr) {
  // Register a global shortcut to show the browser window.
  auto global_shortcuts = app->globalShortcuts();
  auto shortcut_show = Shortcut(KeyCode::V, KeyModifier::COMMAND_OR_CTRL | KeyModifier::SHIFT);
  global_shortcuts->registerShortcut(shortcut_show, [this](const Shortcut &) {
    show();
  });
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
  return "";
}

void MainAppMac::restoreWindowBounds() {
  NSScreen *mainScreen = [NSScreen mainScreen];
  NSNumber *screenNumber = [[mainScreen deviceDescription] objectForKey:@"NSScreenNumber"];
  NSString *key = [NSString stringWithFormat:@"screen_%@", screenNumber];
  NSDictionary *prefValue = [[NSUserDefaults standardUserDefaults] objectForKey:key];
  if (prefValue) {
    auto x = [[prefValue objectForKey:@"window.bounds.x"] intValue];
    auto y = [[prefValue objectForKey:@"window.bounds.y"] intValue];
    auto width = [[prefValue objectForKey:@"window.bounds.width"] unsignedIntValue];
    auto height = [[prefValue objectForKey:@"window.bounds.height"] unsignedIntValue];
    browser_->setBounds(molybden::Rect(molybden::Point(x, y), molybden::Size(width, height)));
  } else {
    auto screen_x = static_cast<int32_t>([mainScreen frame].origin.x);
    auto screen_y = static_cast<int32_t>([mainScreen frame].origin.y);
    browser_->setPosition(screen_x, screen_y);
    browser_->centerWindow();
  }
}

void MainAppMac::saveWindowBounds() {
  NSScreen *mainScreen = [NSScreen mainScreen];
  NSNumber *screenNumber = [[mainScreen deviceDescription] objectForKey:@"NSScreenNumber"];
  auto window_bounds = browser_->bounds();
  NSMutableDictionary *prefValue = [[NSMutableDictionary alloc] init];
  prefValue[@"window.bounds.x"] = [NSNumber numberWithInt:window_bounds.origin.x];
  prefValue[@"window.bounds.y"] = [NSNumber numberWithInt:window_bounds.origin.y];
  prefValue[@"window.bounds.width"] = [NSNumber numberWithUnsignedInt:window_bounds.size.width];
  prefValue[@"window.bounds.height"] = [NSNumber numberWithUnsignedInt:window_bounds.size.height];

  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *key = [NSString stringWithFormat:@"screen_%@", screenNumber];
  [defaults setObject:prefValue forKey:key];
  [defaults synchronize];
}
