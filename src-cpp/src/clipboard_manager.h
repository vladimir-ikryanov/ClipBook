#ifndef CLIPBOARD_SRC_CPP_SRC_CLIPBOARD_MANAGER_H_
#define CLIPBOARD_SRC_CPP_SRC_CLIPBOARD_MANAGER_H_

#include "molybden.hpp"

using namespace molybden;

class ClipboardManager {
 public:
  static std::shared_ptr<ClipboardManager> create(const std::shared_ptr<Browser> &browser);

  void start();

 private:
  explicit ClipboardManager(const std::shared_ptr<Browser> &browser);

  std::shared_ptr<ClipboardData> readClipboardData(const std::shared_ptr<ClipboardDataType> &type);

  std::shared_ptr<Browser> browser_;
  std::shared_ptr<ClipboardData> clipboard_data_;
};

#endif //CLIPBOARD_SRC_CPP_SRC_CLIPBOARD_MANAGER_H_
