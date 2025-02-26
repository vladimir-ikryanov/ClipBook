#ifndef CLIPBOOK_ACTIVE_APP_OBSERVER_H_
#define CLIPBOOK_ACTIVE_APP_OBSERVER_H_

#import <Cocoa/Cocoa.h>

#include <memory>

class MainAppMac;

@interface ActiveAppObserver : NSObject {
 @private
  MainAppMac* owner_;
}

- (instancetype)initWithOwner:(MainAppMac*)owner;
- (void)activeAppChanged:(NSNotification *)notification;

@end

#endif // CLIPBOOK_ACTIVE_APP_OBSERVER_H_
