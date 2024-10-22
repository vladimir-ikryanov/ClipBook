#include "clipboard_reader_mac.h"

#import <Cocoa/Cocoa.h>
#import <Vision/Vision.h>

#include <filesystem>
#include <memory>
#include <thread>

#include "utils.h"

namespace fs = std::filesystem;

static int kCheckInterval = 500;
static int kCopyToClipboardAfterMergeDelay = 500;

void extractTextFromImage(NSImage *image,
                          const std::string &imageFileName,
                          const std::shared_ptr<MainApp> &app,
                          const std::shared_ptr<ClipboardData> &data) {
  // Convert NSImage to CGImage
  CGImageRef cgImage = [image CGImageForProposedRect:nullptr context:nil hints:nil];
  if (cgImage == nil) {
    return;
  }

  // Create a VNImageRequestHandler with the CGImage
  VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCGImage:cgImage options:@{}];

  // Create a text recognition request
  VNRecognizeTextRequest *textRequest = [[VNRecognizeTextRequest alloc] initWithCompletionHandler:^(
      VNRequest *request,
      NSError *_Nullable error) {
    if (error != nil) {
      return;
    }

    // Process the text recognition results
    std::string content;
    NSArray *observations = request.results;
    for (VNRecognizedTextObservation *observation in observations) {
      VNRecognizedText *recognizedText = [[observation topCandidates:1] firstObject];
      if (recognizedText != nil) {
        NSString *string = recognizedText.string;
        content += [string UTF8String];
        content += "\n";
      }
    }

    if (content.empty()) {
      return;
    }

    data->content = content;

    auto js_window = app->browser()->mainFrame()->executeJavaScript("window");
    js_window.asJsObject()->call("setTextFromImage", imageFileName, content);
  }];

  // Perform the request
  NSError *error = nil;
  [handler performRequests:@[textRequest] error:&error];

  // Clean up.
  [textRequest release];
  [handler release];
  CGImageRelease(cgImage);
}

NSImage *createThumbnail(NSImage *image, int width, int height) {
  // Get the original image dimensions
  NSSize originalSize = [image size];

  // Calculate the scale factor to maintain the aspect ratio
  CGFloat widthRatio = width / originalSize.width;
  CGFloat heightRatio = height / originalSize.height;
  CGFloat scaleFactor = MIN(widthRatio, heightRatio);

  // Calculate the new size, maintaining aspect ratio
  NSSize newSize = NSMakeSize(originalSize.width * scaleFactor, originalSize.height * scaleFactor);

  // Create a new NSImage with the calculated size
  NSImage *thumbnail = [[NSImage alloc] initWithSize:newSize];

  // Start drawing the original image into the new size
  [thumbnail lockFocus];
  [image setSize:newSize];

  // Draw the scaled-down image in the new context
  [image drawAtPoint:NSZeroPoint
            fromRect:NSMakeRect(0, 0, originalSize.width, originalSize.height)
           operation:NSCompositingOperationSourceOver
            fraction:1.0];

  [thumbnail unlockFocus];

  return thumbnail;
}

std::vector<fs::path> findImages(const fs::path &dir,
                                 const std::string &filePrefix,
                                 const std::string &fileExtension) {
  std::vector<fs::path> images;
  for (const auto &entry : fs::directory_iterator(dir)) {
    if (entry.is_regular_file()) {
      std::string filename = entry.path().filename().string();
      if (filename.find(filePrefix) == 0 &&
          filename.find(fileExtension) == filename.size() - fileExtension.size()) {
        images.push_back(entry.path());
      }
    }
  }
  return images;
}

std::string getThumbImageFileName(const std::string &imageFileName) {
  std::string thumbFileName = imageFileName;
  size_t pos = thumbFileName.find_last_of('_');
  if (pos != std::string::npos) {
    thumbFileName.insert(pos, "_thumb");
  }
  return thumbFileName;
}

NSSize getImageSizeFromFile(NSString *imagePath) {
  NSURL *imageURL = [NSURL fileURLWithPath:imagePath];

  CGImageSourceRef imageSource = CGImageSourceCreateWithURL((__bridge CFURLRef)imageURL, nullptr);
  if (!imageSource) {
    return NSZeroSize;
  }

  auto imageProperties = (__bridge NSDictionary *)CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nullptr);
  if (!imageProperties) {
    CFRelease(imageSource);
    return NSZeroSize;
  }

  NSNumber *width = imageProperties[(NSString *)kCGImagePropertyPixelWidth];
  NSNumber *height = imageProperties[(NSString *)kCGImagePropertyPixelHeight];

  CFRelease(imageSource);

  if (width && height) {
    return NSMakeSize(width.floatValue, height.floatValue);
  } else {
    return NSZeroSize;
  }
}

bool findIdenticalImage(NSImage *srcImage, const fs::path &imagesDir, ImageInfo &imageInfo) {
  CGImageRef srcCGImage = [srcImage CGImageForProposedRect:nullptr context:nil hints:nil];
  auto images = findImages(imagesDir, "image_", ".png");
  for (const auto &image_path : images) {
    auto imagePath = [NSString stringWithUTF8String:image_path.c_str()];
    // Compare image pixels.
    NSImage *dstImage = [[NSImage alloc] initWithContentsOfFile:imagePath];
    CGImageRef dstCGImage = [dstImage CGImageForProposedRect:nullptr context:nil hints:nil];

    size_t width1 = CGImageGetWidth(srcCGImage);
    size_t height1 = CGImageGetHeight(srcCGImage);
    size_t width2 = CGImageGetWidth(dstCGImage);
    size_t height2 = CGImageGetHeight(dstCGImage);

    if (width1 != width2 || height1 != height2) {
      [dstImage release];
      continue;
    }

    CFDataRef data1 = CGDataProviderCopyData(CGImageGetDataProvider(srcCGImage));
    CFDataRef data2 = CGDataProviderCopyData(CGImageGetDataProvider(dstCGImage));

    BOOL identical = CFDataGetLength(data1) == CFDataGetLength(data2) &&
                     memcmp(CFDataGetBytePtr(data1), CFDataGetBytePtr(data2), CFDataGetLength(data1)) == 0;

    CFRelease(data1);
    CFRelease(data2);

    [dstImage release];

    if (identical) {
      imageInfo.file_name = image_path.filename().string();
      imageInfo.thumb_file_name = getThumbImageFileName(imageInfo.file_name);
      return true;
    }
  }
  return false;
}

static CFAbsoluteTime lastTapTime = 0;

ClipboardReaderMac::ClipboardReaderMac() = default;

ClipboardReaderMac::~ClipboardReaderMac() {
  if (monitor_ != nil) {
    [NSEvent removeMonitor:monitor_];
  }
}

#pragma clang diagnostic push
#pragma ide diagnostic ignored "EndlessLoop"

void ClipboardReaderMac::start(const std::shared_ptr<MainApp> &app) {
  app_ = app;

  // Initialize the last change count on start to ignore the initial clipboard content.
  last_change_count_ = [[NSPasteboard generalPasteboard] changeCount];

  monitor_ = [NSEvent addGlobalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^(NSEvent *event) {
    if (!app_->settings()->isCopyAndMergeEnabled() || app_->isPaused()) {
      return;
    }
    if (([event modifierFlags] & NSEventModifierFlagCommand) &&
        [[event characters] isEqualToString:@"c"]) {
      CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
      if (currentTime - lastTapTime < 0.5) {
        copy_and_merge_requested_ = true;
      }
      lastTapTime = currentTime;
    }
  }];

  std::thread t([this]() {
    while (true) {
      if (app_->isPaused()) {
        std::this_thread::sleep_for(std::chrono::milliseconds(kCheckInterval));
        continue;
      }
      std::this_thread::sleep_for(std::chrono::milliseconds(kCheckInterval));
      readClipboardData();
    }
  });
  t.join();
}

#pragma clang diagnostic pop

void ClipboardReaderMac::copyToClipboardAfterMerge(std::string text) {
  std::thread t([this, text]() {
    do {
      std::this_thread::sleep_for(std::chrono::milliseconds(kCopyToClipboardAfterMergeDelay));
    } while (copy_and_merge_requested_);
    std::lock_guard<std::mutex> guard(mutex_);
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    NSString *string = [NSString stringWithUTF8String:text.c_str()];
    [pasteboard setString:string forType:NSPasteboardTypeString];
    readClipboardData(data_);
  });
  t.detach();
}

void ClipboardReaderMac::addClipboardData(const std::shared_ptr<ClipboardData> &data) {
  auto frame = app_->browser()->mainFrame();
  auto window = frame->executeJavaScript("window");
  window.asJsObject()->call("addClipboardData",
                            data->content,
                            data->active_app_info.path,
                            data->image_info.file_name,
                            data->image_info.thumb_file_name,
                            data->image_info.width,
                            data->image_info.height,
                            data->image_info.size_in_bytes,
                            data->image_info.text);
}

void ClipboardReaderMac::mergeClipboardData(const std::shared_ptr<ClipboardData> &data) {
  auto frame = app_->browser()->mainFrame();
  auto window = frame->executeJavaScript("window");
  window.asJsObject()->call("mergeClipboardData",
                            data->content,
                            data->active_app_info.path,
                            data->image_info.file_name,
                            data->image_info.thumb_file_name,
                            data->image_info.width,
                            data->image_info.height,
                            data->image_info.size_in_bytes,
                            data->image_info.text);
}

void ClipboardReaderMac::readClipboardData() {
  // Let the user press Command+C second time and do not read the clipboard
  // if the time since the last Command+C is less than 0.5 seconds.
  CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
  if (currentTime - lastTapTime < 0.5) {
    return;
  }
  std::lock_guard<std::mutex> guard(mutex_);
  std::shared_ptr<ClipboardData> data = std::make_shared<ClipboardData>();
  if (readClipboardData(data)) {
    data_ = data;
    if (copy_and_merge_requested_) {
      mergeClipboardData(data);
    } else {
      addClipboardData(data);
    }
  }
  copy_and_merge_requested_ = false;
}

bool ClipboardReaderMac::readClipboardData(const std::shared_ptr<ClipboardData> &data) {
  // Check if the clipboard has changed.
  NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
  auto changeCount = [pasteboard changeCount];
  if (changeCount == last_change_count_) {
    return false;
  }
  last_change_count_ = changeCount;

  // Check if the active app should be ignored.
  auto settings = app_->settings();
  data->active_app_info = app_->getActiveAppInfo();
  auto apps_to_ignore = settings->getAppsToIgnore();
  if (apps_to_ignore.find(data->active_app_info.path) != std::string::npos) {
    return false;
  }

  // Check if the clipboard has transient or confidential content.
  bool ignore_transient_content = settings->shouldIgnoreTransientContent();
  bool ignore_confidential_content = settings->shouldIgnoreConfidentialContent();
  NSArray *types = [pasteboard types];
  if (ignore_transient_content && [types containsObject:@"org.nspasteboard.TransientType"]) {
    return false;
  }
  if (ignore_confidential_content && [types containsObject:@"org.nspasteboard.ConcealedType"]) {
    return false;
  }

  // Read image content in the PNG and TIFF formats.
  if ([types containsObject:NSPasteboardTypePNG] || [types containsObject:NSPasteboardTypeTIFF]) {
    // Make sure the images directory exists.
    fs::path imagesDir = app_->getImagesDir();
    if (!fs::exists(imagesDir)) {
      fs::create_directories(imagesDir);
    }

    // Get image info.
    NSData *png_data = nil;
    if ([types containsObject:NSPasteboardTypePNG]) {
      png_data = [pasteboard dataForType:NSPasteboardTypePNG];
    } else {
      NSData *tiff_data = [pasteboard dataForType:NSPasteboardTypeTIFF];
      NSBitmapImageRep *image_rep = [NSBitmapImageRep imageRepWithData:tiff_data];
      png_data = [image_rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    }

    NSImage *image = [[NSImage alloc] initWithData:png_data];
    data->image_info.width = static_cast<int>([image size].width);
    data->image_info.height = static_cast<int>([image size].height);
    data->image_info.size_in_bytes = [png_data length];

    // Check if an identical image is already stored in the directory and use it.
    ImageInfo image_info;
    if (findIdenticalImage(image, imagesDir, image_info)) {
      data->image_info.file_name = image_info.file_name;
      data->image_info.thumb_file_name = image_info.thumb_file_name;
      [image release];
      return true;
    }

    int creation_time_in_ms = (int) [[NSDate date] timeIntervalSince1970];

    // Save image to file.
    NSString *image_filename = [NSString stringWithFormat:@"image_%d.png", creation_time_in_ms];
    NSString *images_dir = [NSString stringWithUTF8String:imagesDir.c_str()];
    NSString *image_path = [images_dir stringByAppendingPathComponent:image_filename];
    [png_data writeToFile:image_path atomically:YES];
    data->image_info.file_name = [image_filename UTF8String];

    // Save image thumbnail to file.
    NSImage *thumbnail = createThumbnail(image, 48, 48);
    NSData *thumbnail_data = [thumbnail TIFFRepresentation];
    NSBitmapImageRep *thumbnail_image_rep = [NSBitmapImageRep imageRepWithData:thumbnail_data];
    NSDictionary *thumbnail_props = @{};
    NSData *thumbnail_png_data = [thumbnail_image_rep representationUsingType:NSBitmapImageFileTypePNG properties:thumbnail_props];
    NSString *thumbnail_filename = [NSString stringWithFormat:@"image_thumb_%d.png", creation_time_in_ms];
    NSString *thumbnail_path = [images_dir stringByAppendingPathComponent:thumbnail_filename];
    [thumbnail_png_data writeToFile:thumbnail_path atomically:YES];
    data->image_info.thumb_file_name = [thumbnail_filename UTF8String];
    [thumbnail_png_data release];
    [thumbnail_image_rep release];
    [thumbnail_data release];
    [thumbnail release];

    // Extract text from image.
    extractTextFromImage(image, [image_filename UTF8String], app_, data);

    // Release resources.
    [image release];

    if ([types containsObject:NSPasteboardTypeString]) {
      std::string content = [[pasteboard stringForType:NSPasteboardTypeString] UTF8String];
      if (!isEmptyOrSpaces(content)) {
        data->image_info.text = content;
      }
    }

    return true;
  }

  // Read text content.
  if ([types containsObject:NSPasteboardTypeString]) {
    std::string content = [[pasteboard stringForType:NSPasteboardTypeString] UTF8String];
    if (!isEmptyOrSpaces(content)) {
      data->content = content;
      return true;
    }
  }
  return false;
}
