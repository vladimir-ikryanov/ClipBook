#include "active_app_observer.h"

#include "main_app_mac.h"

@implementation ActiveAppObserver

- (instancetype)initWithOwner:(MainAppMac*)owner {
  self = [super init];
  if (self) {
    owner_ = owner;
    [[[NSWorkspace sharedWorkspace] notificationCenter]
        addObserver:self
           selector:@selector(activeAppChanged:)
               name:NSWorkspaceDidActivateApplicationNotification
             object:nil];
  }
  return self;
}

- (void)activeAppChanged:(NSNotification*)notification {
  if (owner_) {
    owner_->onActiveAppChanged(notification);
  }
}

- (void)dealloc {
  [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
  [super dealloc];
}

@end
