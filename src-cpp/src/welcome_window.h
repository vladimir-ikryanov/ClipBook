#ifndef CLIPBOARD_SRC_CPP_SRC_WELCOME_WINDOW_H_
#define CLIPBOARD_SRC_CPP_SRC_WELCOME_WINDOW_H_

#include <memory>
#include <string>

#include "molybden.hpp"

class WelcomeWindow {
 public:
  explicit WelcomeWindow(const std::shared_ptr<molybden::App> &app);

  [[nodiscard]] std::shared_ptr<molybden::Browser> browser() const;

  virtual void show();
  virtual void hide();

 private:
  std::shared_ptr<molybden::App> app_;
  std::shared_ptr<molybden::Browser> browser_;
};

#endif //CLIPBOARD_SRC_CPP_SRC_WELCOME_WINDOW_H_
