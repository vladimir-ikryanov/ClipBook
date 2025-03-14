#ifndef CLIPBOOK_MAIN_APP_WIN_H_
#define CLIPBOOK_MAIN_APP_WIN_H_

#include "main_app.h"

class MainAppWin: public MainApp {
 public:
  explicit MainAppWin(const std::shared_ptr<molybden::App> &app,
                      const std::shared_ptr<AppSettings> &settings);

  void show() override;
  void hide() override;
  void activate() override;
  void paste() override;
  void paste(const std::string &text) override;

 protected:
  std::string getUserDataDir() override;
  std::string getUpdateServerUrl() override;
};

#endif // CLIPBOOK_MAIN_APP_WIN_H_
