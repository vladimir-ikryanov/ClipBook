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
  std::thread t([this]() {
    while (!browser_->isClosed()) {
      std::this_thread::sleep_for(std::chrono::seconds(1));
      auto data = readClipboardData(ClipboardDataType::plainText());
      if (data) {
        std::string data_str(reinterpret_cast<const char *>(data->data()), data->size());
        browser_->mainFrame()->executeJavaScript("addClipboardData(\"" + data_str + "\")");
      }
    }
  });
  t.join();
}

std::shared_ptr<ClipboardData> ClipboardManager::readClipboardData(
    const std::shared_ptr<ClipboardDataType> &type) {
  auto clipboard_data = browser_->app()->clipboard()->read();
  for (const auto &data : clipboard_data) {
    if (data->type()->mimeType() == type->mimeType()) {
      if (clipboard_data_ == nullptr || clipboard_data_->size() != data->size()) {
        clipboard_data_ = data;
        return clipboard_data_;
      }
    }
  }
  return {};
}
