#include "clipboard_reader.h"

#include <memory>
#include <thread>

static int kCheckIntervalInSeconds = 1;

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
      std::this_thread::sleep_for(std::chrono::seconds(kCheckIntervalInSeconds));
      if (app_->isPaused()) {
        continue;
      }
      if (readClipboardData(ClipboardDataType::plainText())) {
        auto source_app_info = app_->getActiveAppInfo();
        const JsValue &js_window = app_->browser()->mainFrame()->executeJavaScript("window");
        js_window.asJsObject()->call("addClipboardData",
                                     data_,
                                     source_app_info.id,
                                     source_app_info.name);
      }
    }
  });
  t.join();
}
#pragma clang diagnostic pop

bool ClipboardReader::readClipboardData(const std::shared_ptr<ClipboardDataType> &type) {
  auto settings = app_->settings();
  bool ignore_transient_content = settings->shouldIgnoreTransientContent();
  bool ignore_confidential_content = settings->shouldIgnoreConfidentialContent();
  auto clipboard_data = app_->browser()->app()->clipboard()->read();
  for (const auto &data : clipboard_data) {
    auto mime_type = data->type()->mimeType();
    if (ignore_transient_content && mime_type == "org.nspasteboard.TransientType") {
      return false;
    }
    if (ignore_confidential_content && mime_type == "org.nspasteboard.ConcealedType") {
      return false;
    }
  }
  for (const auto &data : clipboard_data) {
    if (data->type()->mimeType() == type->mimeType()) {
      std::string data_str(reinterpret_cast<const char *>(data->data()), data->size());
      if (data_ != data_str) {
        data_ = std::move(data_str);
        return true;
      }
    }
  }
  return false;
}
