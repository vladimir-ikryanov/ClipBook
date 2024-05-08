#ifndef CLIPBOARD_SRC_CPP_SRC_WELCOME_WINDOW_H_
#define CLIPBOARD_SRC_CPP_SRC_WELCOME_WINDOW_H_

#include <memory>
#include <string>

#include "molybden.hpp"
#include "main_app.h"

class WelcomeWindow {
 public:
  explicit WelcomeWindow(const std::shared_ptr<MainApp> &app);

  virtual void show();
  virtual void hide();

 private:
  std::shared_ptr<MainApp> app_;
  std::shared_ptr<molybden::Browser> browser_;
};

#endif //CLIPBOARD_SRC_CPP_SRC_WELCOME_WINDOW_H_
