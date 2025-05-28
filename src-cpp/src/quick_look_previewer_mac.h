#import <Foundation/Foundation.h>

typedef void (^QLPreviewDidCloseCallback)(void);

@interface QuickLookPreviewer : NSObject

+ (instancetype)shared;
- (void)previewFileAtPath:(NSString *)path;
- (void)setOnCloseCallback:(QLPreviewDidCloseCallback)callback;

@end
