#ifndef CLIPBOOK_CLIPBOARD_READER_H_
#define CLIPBOOK_CLIPBOARD_READER_H_

#include "main_app.h"

#include "molybden.hpp"

using namespace molybden;

class ClipboardReader {
 public:
  static std::shared_ptr<ClipboardReader> create(const std::shared_ptr<MainApp> &app);

  void start();

 private:
  explicit ClipboardReader(const std::shared_ptr<MainApp> &app);

  std::shared_ptr<ClipboardData> readClipboardData(const std::shared_ptr<ClipboardDataType> &type);

  std::shared_ptr<MainApp> app_;
  std::shared_ptr<ClipboardData> clipboard_data_;
};

#endif // CLIPBOOK_CLIPBOARD_READER_H_
