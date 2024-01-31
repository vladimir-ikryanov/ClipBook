#include "molybden.hpp"

using namespace molybden;

std::string greet(std::string name) {
  return "Hello " + name + "! This message comes from C++";
}

void launch() {
  App::init([](std::shared_ptr<App> app) {
    auto browser = Browser::create(app);
    browser->onInjectJs = [](const InjectJsArgs& args, InjectJsAction action) {
      args.window->putProperty("greet", greet);
      action.proceed();
    };
    browser->loadUrl(app->baseUrl());
    browser->show();
  });
}
