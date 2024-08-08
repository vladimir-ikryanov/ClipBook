#include "clipboard_reader.h"

#include <memory>
#include <thread>

std::shared_ptr<ClipboardReader>
ClipboardReader::create(const std::shared_ptr<MainApp> &app) {
  std::shared_ptr<ClipboardReader> manager(new ClipboardReader(app));
  return manager;
}

ClipboardReader::ClipboardReader(const std::shared_ptr<MainApp> &app) : app_(app) {}

#pragma clang diagnostic push
#pragma ide diagnostic ignored "EndlessLoop"
void ClipboardReader::start() {
  std::thread t([this]() {
    while (true) {
      std::this_thread::sleep_for(std::chrono::seconds(1));
      if (app_->isPaused()) {
        continue;
      }
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
#pragma clang diagnostic pop

std::shared_ptr<ClipboardData> ClipboardReader::readClipboardData(
    const std::shared_ptr<ClipboardDataType> &type) {
  auto settings = app_->settings();
  bool ignore_transient_content = settings->shouldIgnoreTransientContent();
  bool ignore_confidential_content = settings->shouldIgnoreConfidentialContent();
  auto clipboard_data = app_->browser()->app()->clipboard()->read();
  for (const auto &data : clipboard_data) {
    auto mime_type = data->type()->mimeType();
    if (ignore_transient_content && mime_type == "org.nspasteboard.TransientType") {
      return {};
    }
    if (ignore_confidential_content && mime_type == "org.nspasteboard.ConcealedType") {
      return {};
    }
  }
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
