#ifndef CLIPBOOK_URL_REQUEST_INTERCEPTOR_H_
#define CLIPBOOK_URL_REQUEST_INTERCEPTOR_H_

#include "mobrowser.hpp"

static std::string kClipBookScheme = "clipbook";

class UrlRequestInterceptor {
 public:
  explicit UrlRequestInterceptor(std::string  profile_path, std::string  resources_dir);

  virtual void intercept(const mobrowser::InterceptUrlRequestArgs &args,
                         mobrowser::InterceptUrlRequestAction action);

 private:
  std::string profile_path_;
  std::string resources_dir_;
};

#endif  // CLIPBOOK_URL_REQUEST_INTERCEPTOR_H_
