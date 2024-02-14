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

void MainAppMac::show() {
  active_app_ = [[NSWorkspace sharedWorkspace] frontmostApplication];
  NSString *app_name = [active_app_ localizedName];
  MainApp::setActiveAppName([app_name UTF8String]);
  MainApp::show();
}

void MainAppMac::hide() {
  MainApp::hide();
  if (active_app_) {
    [active_app_ activateWithOptions:NSApplicationActivateIgnoringOtherApps];
  }
}

void MainAppMac::paste(const std::string &text) {
  // Hide the browser window and activate the previously active app.
  hide();

  // Clear the pasteboard and set the new text.
  auto pasteboard = [NSPasteboard generalPasteboard];
  [pasteboard clearContents];
  [pasteboard setString:[NSString stringWithUTF8String:text.c_str()] forType:NSPasteboardTypeString];

  // Simulate the key press of Command + V to paste the text into the active app.
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
