#include "clipboard_reader.h"

#include <memory>
#include <thread>

static int kCheckIntervalInSeconds = 1;

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
      ClipboardData data;
      if (readClipboardData(data)) {
        auto js_window = app_->browser()->mainFrame()->executeJavaScript("window");
        js_window.asJsObject()->call("addClipboardData",
                                     data.content,
                                     data.active_app_info.path,
                                     data.image_info.file_name,
                                     data.image_info.thumb_file_name,
                                     data.image_info.width,
                                     data.image_info.height,
                                     data.image_info.size_in_bytes);
      }
    }
  });
  t.join();
}

#pragma clang diagnostic pop
