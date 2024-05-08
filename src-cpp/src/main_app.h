#ifndef CLIPBOARD_SRC_CPP_SRC_MAIN_APP_H_
#define CLIPBOARD_SRC_CPP_SRC_MAIN_APP_H_

#include <memory>
#include <string>

#include "molybden.hpp"

class MainApp {
 public:
  explicit MainApp(const std::shared_ptr<molybden::App> &app);

  [[nodiscard]] std::shared_ptr<molybden::App> app() const;
  [[nodiscard]] std::shared_ptr<molybden::Browser> browser() const;

  bool init();
  void launch();

  virtual void show();
  virtual void hide();
  virtual void activate() = 0;
  virtual void paste(const std::string &text) = 0;

 protected:
  void setActiveAppName(const std::string &app_name);
  void clearHistory();
  void checkForUpdates(const std::function<void()>& complete);
  void showAboutDialog();

  virtual std::string getUserDataDir() = 0;

 protected:
  bool first_run_;
  std::shared_ptr<molybden::App> app_;
  std::shared_ptr<molybden::Browser> browser_;

 private:
  std::shared_ptr<molybden::CustomCheckboxMenuItem> dark_menu_item_;
  std::shared_ptr<molybden::CustomCheckboxMenuItem> light_menu_item_;
  std::shared_ptr<molybden::CustomCheckboxMenuItem> system_menu_item_;
};

#endif //CLIPBOARD_SRC_CPP_SRC_MAIN_APP_H_
