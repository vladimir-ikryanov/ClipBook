#ifndef CLIPBOOK_CLIPBOARD_MANAGER_H_
#define CLIPBOOK_CLIPBOARD_MANAGER_H_

#include "molybden.hpp"

using namespace molybden;

class ClipboardReader {
 public:
  static std::shared_ptr<ClipboardReader> create(const std::shared_ptr<Browser> &browser);

  void start();

 private:
  explicit ClipboardReader(const std::shared_ptr<Browser> &browser);

  std::shared_ptr<ClipboardData> readClipboardData(const std::shared_ptr<ClipboardDataType> &type);

  std::shared_ptr<Browser> browser_;
  std::shared_ptr<ClipboardData> clipboard_data_;
};

#endif // CLIPBOOK_CLIPBOARD_MANAGER_H_
