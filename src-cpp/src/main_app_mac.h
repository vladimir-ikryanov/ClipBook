#ifndef CLIPBOARD_SRC_CPP_SRC_MAIN_APP_MAC_H_
#define CLIPBOARD_SRC_CPP_SRC_MAIN_APP_MAC_H_

#include "main_app.h"

#ifdef __OBJC__
#import <Cocoa/Cocoa.h>
#endif

using namespace molybden;

class MainAppMac : public MainApp {
 public:
  explicit MainAppMac(const std::shared_ptr<App>& app);

  void show() override;
  void hide() override;

 private:
#ifdef __OBJC__
  NSRunningApplication *active_app_;
#endif
};

#endif //CLIPBOARD_SRC_CPP_SRC_MAIN_APP_MAC_H_
