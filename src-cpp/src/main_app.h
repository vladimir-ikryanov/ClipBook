#ifndef CLIPBOARD_SRC_CPP_SRC_MAIN_APP_H_
#define CLIPBOARD_SRC_CPP_SRC_MAIN_APP_H_

#include <memory>

#include "molybden.hpp"

class MainApp {
 public:
  explicit MainApp(const std::shared_ptr<molybden::App>& app);

  std::shared_ptr<molybden::Browser> browser() const;

  virtual void show();
  virtual void hide();
  virtual void paste(const std::string& text) = 0;

 private:
  std::shared_ptr<molybden::App> app_;
  std::shared_ptr<molybden::Browser> browser_;
};

#endif //CLIPBOARD_SRC_CPP_SRC_MAIN_APP_H_