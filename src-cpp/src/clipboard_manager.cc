#include "clipboard_manager.h"

#include <memory>
#include <thread>

std::shared_ptr<ClipboardManager> ClipboardManager::create(const std::shared_ptr<Browser> &browser) {
  std::shared_ptr<ClipboardManager> manager(new ClipboardManager(browser));
  return manager;
}

ClipboardManager::ClipboardManager(const std::shared_ptr<Browser> &browser) : browser_(
    browser) {}

void ClipboardManager::start() {
  // Create a thread for the periodic function
  std::thread t([this]() {
    while (!browser_->isClosed()) {
      std::this_thread::sleep_for(std::chrono::seconds(3));
      // Get clipboard content
      // Compare it with the previous content
      // If it's different, send it to the web app
      browser_->mainFrame()->executeJavaScript("greet()");
    }
  });
  t.join();
}
