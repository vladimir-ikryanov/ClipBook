#ifndef CLIPBOARD_SRC_CPP_SRC_MAIN_APP_WIN_H_
#define CLIPBOARD_SRC_CPP_SRC_MAIN_APP_WIN_H_

#include "main_app.h"

class MainAppWin: public MainApp {
 public:
  explicit MainAppWin(const std::shared_ptr<molybden::App> &app);

  void show() override;
  void hide() override;
  void activate() override;
  void paste(const std::string &text) override;
};

#endif //CLIPBOARD_SRC_CPP_SRC_MAIN_APP_WIN_H_
