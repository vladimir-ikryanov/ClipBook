#ifndef CLIPBOARD_SRC_CPP_SRC_MAIN_APP_H_
#define CLIPBOARD_SRC_CPP_SRC_MAIN_APP_H_

#include <memory>

#include "molybden.hpp"

using namespace molybden;

class MainApp {
 public:
  explicit MainApp(const std::shared_ptr<App>& app);

  virtual void show();
  virtual void hide();

 private:
  std::shared_ptr<App> app_;
  std::shared_ptr<Browser> browser_;
};

#endif //CLIPBOARD_SRC_CPP_SRC_MAIN_APP_H_
