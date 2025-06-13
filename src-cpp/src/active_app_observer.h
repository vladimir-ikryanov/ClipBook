#ifndef CLIPBOOK_ACTIVE_APP_OBSERVER_H_
#define CLIPBOOK_ACTIVE_APP_OBSERVER_H_

#import <Cocoa/Cocoa.h>

#include <memory>
#include <functional>

class MainAppMac;

@interface ActiveAppObserver : NSObject {
 @private
  std::function<void(void*)> callback_;
}

- (instancetype)initWithCallback:(std::function<void(void*)>)callback;
- (void)startObserving;
- (void)activeAppChanged:(NSNotification *)notification;

@end

#endif // CLIPBOOK_ACTIVE_APP_OBSERVER_H_
