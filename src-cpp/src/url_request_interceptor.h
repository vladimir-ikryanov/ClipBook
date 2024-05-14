#ifndef CLIPBOOK_URL_REQUEST_INTERCEPTOR_H_
#define CLIPBOOK_URL_REQUEST_INTERCEPTOR_H_

#include "molybden.hpp"

static std::string kClipBookScheme = "clipbook";

class UrlRequestInterceptor {
 public:
  virtual void intercept(const molybden::InterceptUrlRequestArgs &args,
                         molybden::InterceptUrlRequestAction action);
};

#endif  // CLIPBOOK_URL_REQUEST_INTERCEPTOR_H_
