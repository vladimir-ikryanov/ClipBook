#ifndef CLIPBOOK_CLIPBOARD_READER_MAC_H_
#define CLIPBOOK_CLIPBOARD_READER_MAC_H_

#include "main_app.h"

#include <mutex>

#ifdef __OBJC__
#import <Cocoa/Cocoa.h>
#endif

struct ImageInfo {
  int width = 0;
  int height = 0;
  unsigned long size_in_bytes = 0;
  std::string file_name;
  std::string thumb_file_name;
  std::string text;
};

struct FilePathInfo {
  std::string file_path;
  std::string file_preview_name;
  std::string file_thumb_name;
  int size_in_bytes = 0;
  bool folder = false;
};

struct ClipboardData {
  AppInfo active_app_info;
  std::string text;
  std::string html;
  std::string rtf;
  ImageInfo image_info;
  std::vector<FilePathInfo> file_paths;
};

class ClipboardReaderMac {
 public:
  explicit ClipboardReaderMac();
  ~ClipboardReaderMac();

  void start(const std::shared_ptr<MainApp> &app);
  void copyToClipboardAfterMerge(std::string text);

 private:
#ifdef __OBJC__
  static std::string readPasteboard(NSPasteboardType type);
#endif
  static bool readTextData(const std::shared_ptr<ClipboardData> &data);

  void readClipboardData();
  bool readClipboardData(const std::shared_ptr<ClipboardData> &data);
  bool readImageData(const std::shared_ptr<ClipboardData> &data);
  bool readFilesData(const std::shared_ptr<ClipboardData> &data);
  void addClipboardData(const std::shared_ptr<ClipboardData>& data);
  void mergeClipboardData(const std::shared_ptr<ClipboardData>& data);

 private:
  std::shared_ptr<MainApp> app_;
  std::shared_ptr<ClipboardData> data_;
  long last_change_count_ = 0;
  bool copy_and_merge_requested_ = false;
#ifdef __OBJC__
  id monitor_ = nil;
  NSSound *sound_ = nil;
#endif
  std::mutex mutex_;
};

#endif // CLIPBOOK_CLIPBOARD_READER_MAC_H_
