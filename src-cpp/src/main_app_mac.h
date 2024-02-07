#ifndef CLIPBOARD_SRC_CPP_SRC_MAIN_APP_MAC_H_
#define CLIPBOARD_SRC_CPP_SRC_MAIN_APP_MAC_H_

#include "main_app.h"

using namespace molybden;

class MainAppMac : public MainApp {
 public:
  explicit MainAppMac(const std::shared_ptr<App>& app);

  void show() override;
  void hide() override;
};

#endif //CLIPBOARD_SRC_CPP_SRC_MAIN_APP_MAC_H_
