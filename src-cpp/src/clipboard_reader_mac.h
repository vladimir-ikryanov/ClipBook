#ifndef CLIPBOOK_CLIPBOARD_READER_MAC_H_
#define CLIPBOOK_CLIPBOARD_READER_MAC_H_

#include "main_app.h"

struct ImageInfo {
  int width = 0;
  int height = 0;
  unsigned long size_in_bytes = 0;
  std::string file_name;
  std::string thumb_file_name;
  std::string text;
};

struct ClipboardData {
  AppInfo active_app_info;
  std::string content;
  ImageInfo image_info;
};

class ClipboardReaderMac {
 public:
  static std::shared_ptr<ClipboardReaderMac> create(const std::shared_ptr<MainApp> &app);
  void start();

 private:
  explicit ClipboardReaderMac(const std::shared_ptr<MainApp> &app);

  bool readClipboardData(ClipboardData &data);

  std::shared_ptr<MainApp> app_;
  long last_change_count_ = 0;
};

#endif // CLIPBOOK_CLIPBOARD_READER_MAC_H_
