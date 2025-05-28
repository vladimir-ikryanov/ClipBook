#import "quick_look_previewer_mac.h"

#import <Quartz/Quartz.h>

@interface QuickLookPreviewer ()<QLPreviewPanelDataSource, QLPreviewPanelDelegate>
@property(nonatomic, strong) NSArray<NSURL *> *previewItems;
@property(nonatomic, copy) QLPreviewDidCloseCallback closeCallback;
@end

@implementation QuickLookPreviewer

+ (instancetype)shared {
  static QuickLookPreviewer *sharedInstance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[QuickLookPreviewer alloc] init];
  });
  return sharedInstance;
}

- (void)previewFileAtPath:(NSString *)path {
  NSURL *fileURL = [NSURL fileURLWithPath:path];
  self.previewItems = @[fileURL];

  QLPreviewPanel *panel = [QLPreviewPanel sharedPreviewPanel];
  [panel setDataSource:self];
  [panel setDelegate:self];

  if (![QLPreviewPanel sharedPreviewPanelExists] || ![panel isVisible]) {
    [panel makeKeyAndOrderFront:nil];
  } else {
    [panel reloadData];
  }
}

#pragma mark - QLPreviewPanelDataSource

- (void)setOnCloseCallback:(QLPreviewDidCloseCallback)callback {
  self.closeCallback = callback;
}

- (NSInteger)numberOfPreviewItemsInPreviewPanel:(QLPreviewPanel *)panel {
  return self.previewItems.count; // NOLINT(*-narrowing-conversions)
}

- (id<QLPreviewItem>)previewPanel:(QLPreviewPanel *)panel previewItemAtIndex:(NSInteger)index {
  return self.previewItems[index];
}

- (void)windowWillClose:(NSNotification *)notification {
  if (self.closeCallback) {
    self.closeCallback();
    self.closeCallback = nil;
  }
}

@end
