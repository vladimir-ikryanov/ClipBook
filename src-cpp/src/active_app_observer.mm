#include "active_app_observer.h"

#include "main_app_mac.h"

@implementation ActiveAppObserver

- (instancetype)initWithCallback:(std::function<void(void*)>)callback {
  self = [super init];
  if (self) {
    callback_ = callback;
  }
  return self;
}

- (void)startObserving {
  [[[NSWorkspace sharedWorkspace] notificationCenter]
      addObserver:self
         selector:@selector(activeAppChanged:)
             name:NSWorkspaceDidActivateApplicationNotification
           object:nil];
}

- (void)activeAppChanged:(NSNotification*)notification {
  if (callback_) {
    NSDictionary *userInfo = notification.userInfo;
    if (userInfo) {
      callback_(userInfo[NSWorkspaceApplicationKey]);
    }
  }
}

- (void)dealloc {
  [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
  [super dealloc];
}

@end
