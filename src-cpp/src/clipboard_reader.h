#ifndef CLIPBOOK_CLIPBOARD_READER_H_
#define CLIPBOOK_CLIPBOARD_READER_H_

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

class ClipboardReader {
 public:
  void start();

 protected:
  explicit ClipboardReader(const std::shared_ptr<MainApp> &app);

  virtual bool readClipboardData(ClipboardData &data) = 0;

  std::shared_ptr<MainApp> app_;
};

#endif // CLIPBOOK_CLIPBOARD_READER_H_
