#include "app_settings.h"

#if OS_MAC
#include "app_settings_mac.h"
#endif

std::shared_ptr<AppSettings> AppSettings::create() {
#if OS_MAC
  return std::make_shared<AppSettingsMac>();
#endif
  return nullptr;
}
