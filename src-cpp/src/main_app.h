#ifndef CLIPBOOK_MAIN_APP_H_
#define CLIPBOOK_MAIN_APP_H_

#include <memory>
#include <string>

#include "molybden.hpp"
#include "url_request_interceptor.h"

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
  virtual void paste() = 0;
  virtual void paste(const std::string &text) = 0;

 protected:
  void setActiveAppName(const std::string &app_name);
  void clearHistory();
  void showAboutDialog();

  virtual std::string getUserDataDir() = 0;

 protected:
  bool first_run_;
  std::shared_ptr<molybden::App> app_;
  std::shared_ptr<molybden::Browser> browser_;

 private:
  std::shared_ptr<UrlRequestInterceptor> request_interceptor_;
  std::shared_ptr<molybden::CustomCheckboxMenuItem> dark_menu_item_;
  std::shared_ptr<molybden::CustomCheckboxMenuItem> light_menu_item_;
  std::shared_ptr<molybden::CustomCheckboxMenuItem> system_menu_item_;
};

#endif // CLIPBOOK_MAIN_APP_H_
