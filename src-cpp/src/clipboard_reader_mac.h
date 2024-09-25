#ifndef CLIPBOOK_CLIPBOARD_READER_MAC_H_
#define CLIPBOOK_CLIPBOARD_READER_MAC_H_

#import <__filesystem/path.h>
#include "clipboard_reader.h"

class ClipboardReaderMac : public ClipboardReader {
 public:
  static std::shared_ptr<ClipboardReaderMac> create(const std::shared_ptr<MainApp> &app);

 protected:
  bool readClipboardData(ClipboardData &data) override;

 private:
  explicit ClipboardReaderMac(const std::shared_ptr<MainApp> &app);

  long last_change_count_ = 0;
};

#endif // CLIPBOOK_CLIPBOARD_READER_MAC_H_
