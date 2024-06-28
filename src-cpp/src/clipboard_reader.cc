#include "clipboard_reader.h"

#include <memory>
#include <thread>

std::shared_ptr<ClipboardReader>
ClipboardReader::create(const std::shared_ptr<MainApp> &app) {
  std::shared_ptr<ClipboardReader> manager(new ClipboardReader(app));
  return manager;
}

ClipboardReader::ClipboardReader(const std::shared_ptr<MainApp> &app) : app_(app) {}

void ClipboardReader::start() {
  std::thread t([this]() {
      while (!app_->browser()->isClosed()) {
        std::this_thread::sleep_for(std::chrono::seconds(1));
        auto data = readClipboardData(ClipboardDataType::plainText());
        if (data) {
          std::string data_str(reinterpret_cast<const char *>(data->data()), data->size());
          const JsValue &js_window = app_->browser()->mainFrame()->executeJavaScript("window");
          js_window.asJsObject()->call("addClipboardData", data_str);
        }
      }
  });
  t.join();
}

std::shared_ptr<ClipboardData> ClipboardReader::readClipboardData(
    const std::shared_ptr<ClipboardDataType> &type) {
  auto clipboard_data = app_->browser()->app()->clipboard()->read();
  for (const auto &data: clipboard_data) {
    if (data->type()->mimeType() == type->mimeType()) {
      if (clipboard_data_ == nullptr || clipboard_data_->size() != data->size()) {
        clipboard_data_ = data;
        return clipboard_data_;
      }
    }
  }
  return {};
}