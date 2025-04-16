#include "clipboard_reader_mac.h"

#import <Cocoa/Cocoa.h>
#import <CommonCrypto/CommonDigest.h>
#import <QuickLookThumbnailing/QuickLookThumbnailing.h>
#import <Vision/Vision.h>

#include <filesystem>
#include <fstream>
#include <memory>
#include <thread>

#include "utils.h"

namespace fs = std::filesystem;

static int kCheckInterval = 500;
static int kCopyToClipboardAfterMergeDelay = 500;

bool hasCustomClip(NSPasteboard *pasteboard) {
  return [pasteboard availableTypeFromArray:@[@"com.clipbook.data"]] != nil;
}

void extractTextFromImage(NSImage *image,
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
        if (string != nil) {
          const char *text = [string UTF8String];
          if (text != nullptr) {
            content += text;
            content += "\n";
          }
        }
      }
    }

    if (content.empty()) {
      return;
    }

    data->image_info.text = content;
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
                                 const std::string &excludeFilePrefix,
                                 const std::string &fileExtension) {
  std::vector<fs::path> images;
  for (const auto &entry : fs::directory_iterator(dir)) {
    if (entry.is_regular_file()) {
      std::string filename = entry.path().filename().string();
      if (filename.find(excludeFilePrefix) == 0) {
        continue;
      }
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

bool findIdenticalImage(NSImage *srcImage,
                        const fs::path &imagesDir,
                        const std::shared_ptr<ClipboardData> &data) {
  @autoreleasepool {

    CGImageRef srcCGImage = [srcImage CGImageForProposedRect:nullptr context:nil hints:nil];
    size_t srcWidth = CGImageGetWidth(srcCGImage);
    size_t srcHeight = CGImageGetHeight(srcCGImage);

    auto images = findImages(imagesDir, "image_", "image_thumb_", ".png");
    for (const auto &image_path : images) {
      // Get file name without extension.
      auto image_info_path = image_path.string().replace(
          image_path.string().find(".png"), 4, ".info");
      bool file_exists = fs::exists(image_info_path);
      if (file_exists) {
        std::ifstream input_file(image_info_path);
        if (input_file.is_open()) {
          std::string line;
          int width = 0;
          int height = 0;
          int size_in_bytes = 0;
          while (std::getline(input_file, line)) {
            if (line.find("width: ") == 0) {
              width = std::stoi(line.substr(7));
            } else if (line.find("height: ") == 0) {
              height = std::stoi(line.substr(8));
            }
          }
          input_file.close();

          if (width != data->image_info.width || height != data->image_info.height) {
            continue;
          }
        }
      }

      // Compare image pixels.
      auto imagePath = [NSString stringWithUTF8String:image_path.c_str()];
      NSImage *dstImage = [[NSImage alloc] initWithContentsOfFile:imagePath];
      CGImageRef dstCGImage = [dstImage CGImageForProposedRect:nullptr context:nil hints:nil];

      size_t dstWidth = CGImageGetWidth(dstCGImage);
      size_t dstHeight = CGImageGetHeight(dstCGImage);

      if (!file_exists) {
        const NSSize &dstImageSize = [dstImage size];
        // Create image info file for old images.
        std::string text_to_write =
            "width: " + std::to_string(static_cast<int>(dstImageSize.width)) + "\n" +
            "height: " + std::to_string(static_cast<int>(dstImageSize.height)) + "\n";
        std::ofstream output_file(image_info_path);
        if (output_file.is_open()) {
          output_file << text_to_write;
          output_file.close();
        }
      }

      if (srcWidth != dstWidth || srcHeight != dstHeight) {
        continue;
      }

      CFDataRef data1 = CGDataProviderCopyData(CGImageGetDataProvider(srcCGImage));
      CFDataRef data2 = CGDataProviderCopyData(CGImageGetDataProvider(dstCGImage));

      BOOL identical = CFDataGetLength(data1) == CFDataGetLength(data2) &&
                       memcmp(CFDataGetBytePtr(data1),
                              CFDataGetBytePtr(data2),
                              CFDataGetLength(data1)) == 0;

      CFRelease(data1);
      CFRelease(data2);

      if (identical) {
        data->image_info.file_name = image_path.filename().string();
        data->image_info.thumb_file_name = getThumbImageFileName(data->image_info.file_name);
        return true;
      }
    }
  }
  return false;
}

NSImage *getThumbnailForFile(NSString *filePath, CGSize maxSize) {
  @autoreleasepool {
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];

    QLThumbnailGenerationRequest *request =
        [[QLThumbnailGenerationRequest alloc] initWithFileAtURL:fileURL
                                                           size:maxSize
                                                          scale:[NSScreen mainScreen].backingScaleFactor
                                            representationTypes:QLThumbnailGenerationRequestRepresentationTypeAll];

    __block NSImage *thumbnailImage = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    [[QLThumbnailGenerator sharedGenerator]
        generateBestRepresentationForRequest:request
                           completionHandler:^(QLThumbnailRepresentation *_Nullable thumbnail,
                                               NSError *_Nullable error) {
                             if (thumbnail) {
                               CGImageRef imageRef = thumbnail.CGImage;
                               thumbnailImage = [[NSImage alloc] initWithCGImage:imageRef size:NSZeroSize];
                             }
                             dispatch_semaphore_signal(semaphore);
                           }];

    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

    // Release the request manually to avoid memory leaks
    request = nil;

    return thumbnailImage;
  }
}

// Function to generate SHA256 hash of a file path
NSString *getHashForPath(NSString *filePath) {
  const char *ptr = [filePath UTF8String];
  unsigned char hash[CC_SHA256_DIGEST_LENGTH];
  CC_SHA256(ptr, (CC_LONG)strlen(ptr), hash);

  NSMutableString *hashedString = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
  for (unsigned char i : hash) {
    [hashedString appendFormat:@"%02x", i];
  }

  return hashedString;
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

  auto resources = app_->app()->getPath(molybden::PathKey::kAppResources) + "/sound.aiff";
  auto *sound_file_path = [NSString stringWithUTF8String:resources.c_str()];
  sound_ = [[NSSound alloc] initWithContentsOfFile:sound_file_path byReference:YES];

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
      std::this_thread::sleep_for(std::chrono::milliseconds(kCheckInterval));
      readClipboardData();
    }
  });
  t.detach();
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
  if (app_->settings()->shouldPlaySoundOnCopy()) {
    [sound_ play];
  }

  auto frame = app_->browser()->mainFrame();
  auto window = frame->executeJavaScript("window");
  if (data->file_paths.empty()) {
    window.asJsObject()->call("addClipboardData",
                              data->text,
                              data->active_app_info.path,
                              data->image_info.file_name,
                              data->image_info.thumb_file_name,
                              data->image_info.width,
                              data->image_info.height,
                              data->image_info.size_in_bytes,
                              data->image_info.text,
                              "",
                              "",
                              "",
                              0,
                              false,
                              data->rtf,
                              data->html);
  } else {
    for (const auto &file_path : data->file_paths) {
      window.asJsObject()->call("addClipboardData",
                                file_path.file_path,
                                data->active_app_info.path,
                                data->image_info.file_name,
                                data->image_info.thumb_file_name,
                                data->image_info.width,
                                data->image_info.height,
                                data->image_info.size_in_bytes,
                                data->image_info.text,
                                file_path.file_path,
                                file_path.file_preview_name,
                                file_path.file_thumb_name,
                                file_path.size_in_bytes,
                                file_path.folder,
                                "",
                                "");
    }
  }
}

void ClipboardReaderMac::mergeClipboardData(const std::shared_ptr<ClipboardData> &data) {
  if (app_->settings()->shouldPlaySoundOnCopy()) {
    [sound_ play];
  }
  auto frame = app_->browser()->mainFrame();
  auto window = frame->executeJavaScript("window");
  if (data->file_paths.empty()) {
    window.asJsObject()->call("mergeClipboardData",
                              data->text,
                              data->active_app_info.path,
                              data->image_info.file_name,
                              data->image_info.thumb_file_name,
                              data->image_info.width,
                              data->image_info.height,
                              data->image_info.size_in_bytes,
                              data->image_info.text,
                              "", "", "", 0, false);
  } else {
    for (const auto &file_path : data->file_paths) {
      window.asJsObject()->call("mergeClipboardData",
                                data->text,
                                data->active_app_info.path,
                                data->image_info.file_name,
                                data->image_info.thumb_file_name,
                                data->image_info.width,
                                data->image_info.height,
                                data->image_info.size_in_bytes,
                                data->image_info.text,
                                file_path.file_path,
                                file_path.file_preview_name,
                                file_path.file_thumb_name,
                                file_path.size_in_bytes,
                                file_path.folder);
    }
  }
}

void ClipboardReaderMac::readClipboardData() {
  // Let the user press Command+C second time and do not read the clipboard
  // if the time since the last Command+C is less than 0.5 seconds.
  if (app_->settings()->isCopyAndMergeEnabled()) {
    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
    if (currentTime - lastTapTime < 0.5) {
      return;
    }
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

bool ClipboardReaderMac::readImageData(const std::shared_ptr<ClipboardData> &data) {
  NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
  NSArray *types = [pasteboard types];
  // If the clipboard contains a file URL, then skip reading the image data.
  if ([types containsObject:NSPasteboardTypeFileURL]) {
    return false;
  }
  // Read image content in the PNG and TIFF formats.
  if ([types containsObject:NSPasteboardTypePNG] || [types containsObject:NSPasteboardTypeTIFF]) {
    // Make sure the images directory exists.
    fs::path imagesDir = app_->getImagesDir();
    if (!fs::exists(imagesDir)) {
      fs::create_directories(imagesDir);
    }

    @autoreleasepool {
      // Get image info.
      NSData *png_data = nil;
      if ([types containsObject:NSPasteboardTypePNG]) {
        png_data = [pasteboard dataForType:NSPasteboardTypePNG];
      } else {
        NSData *tiff_data = [pasteboard dataForType:NSPasteboardTypeTIFF];
        NSBitmapImageRep *image_rep = [NSBitmapImageRep imageRepWithData:tiff_data];
        if (image_rep) {
          png_data = [image_rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        }
      }

      if (!png_data) {
        return false;
      }

      NSImage *image = [[NSImage alloc] initWithData:png_data];
      data->image_info.width = static_cast<int>([image size].width);
      data->image_info.height = static_cast<int>([image size].height);
      data->image_info.size_in_bytes = [png_data length];

      // Check if an identical image is already stored in the directory and use it.
      if (findIdenticalImage(image, imagesDir, data)) {
        return true;
      }

      int creation_time_in_ms = (int) [[NSDate date] timeIntervalSince1970];

      // Save image to file.
      NSString *image_filename = [NSString stringWithFormat:@"image_%d.png", creation_time_in_ms];
      NSString *images_dir = [NSString stringWithUTF8String:imagesDir.c_str()];
      NSString *image_path = [images_dir stringByAppendingPathComponent:image_filename];
      [png_data writeToFile:image_path atomically:YES];
      data->image_info.file_name = [image_filename UTF8String];

      // Save image info to file.
      std::string image_info_filename = "image_" + std::to_string(creation_time_in_ms) + ".info";
      std::string text_to_write = "width: " + std::to_string(data->image_info.width) + "\n" +
                                  "height: " + std::to_string(data->image_info.height) + "\n";
      std::ofstream output_file(imagesDir / image_info_filename);
      if (output_file.is_open()) {
        output_file << text_to_write;
        output_file.close();
      }

      // Save image thumbnail to file.
      NSImage *thumb = createThumbnail(image, 48, 48);
      NSData *tiff_data = [thumb TIFFRepresentation];
      NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:tiff_data];
      NSData *thumb_png_data = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
      NSString *thumb_filename = [NSString stringWithFormat:@"image_thumb_%d.png", creation_time_in_ms];
      NSString *thumb_path = [images_dir stringByAppendingPathComponent:thumb_filename];
      [thumb_png_data writeToFile:thumb_path atomically:YES];
      data->image_info.thumb_file_name = [thumb_filename UTF8String];

      // Extract text from image.
      extractTextFromImage(image, app_, data);
    }
    return true;
  }
  return false;
}

std::string ClipboardReaderMac::readPasteboard(NSPasteboardType type) {
  NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
  NSArray *types = [pasteboard types];
  // Read text content.
  if ([types containsObject:type]) {
    auto string = [pasteboard stringForType:type];
    if (string) {
      const char *text = [string UTF8String];
      if (text != nullptr && !isEmptyOrSpaces(text)) {
        return text;
      }
    }
  }
  return "";
}

bool ClipboardReaderMac::readTextData(const std::shared_ptr<ClipboardData> &data) {
  data->text = readPasteboard(NSPasteboardTypeString);
  data->rtf = readPasteboard(NSPasteboardTypeRTF);
  data->html = readPasteboard(NSPasteboardTypeHTML);
  return !data->text.empty();
}

bool ClipboardReaderMac::readFilesData(const std::shared_ptr<ClipboardData> &data) {
  NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
  NSArray *types = [pasteboard types];
  bool success = false;
  if ([types containsObject:NSPasteboardTypeFileURL]) {
    NSArray<NSURL *> *fileURLs = [pasteboard readObjectsForClasses:@[[NSURL class]] options:nil];
    if (fileURLs.count > 0) {
      for (NSURL *fileURL in fileURLs) {
        @autoreleasepool {
          FilePathInfo file_path_info;
          NSString *filePath = [fileURL path];
          file_path_info.file_path = filePath.UTF8String;

          // If the file is an image, read the image size and extract text from it.
          if ([filePath hasSuffix:@".png"] || [filePath hasSuffix:@".jpg"] || [filePath hasSuffix:@".jpeg"] ||
              [filePath hasSuffix:@".gif"] || [filePath hasSuffix:@".bmp"] || [filePath hasSuffix:@".tiff"]) {
              NSImage *image = [[NSImage alloc] initWithContentsOfFile:filePath];
              if (image) {
                auto size = [image size];
                data->image_info.width = static_cast<int>(size.width);
                data->image_info.height = static_cast<int>(size.height);
                extractTextFromImage(image, app_, data);
              }
          }

          // Get file image and save it to the Images directory.
          fs::path imagesDir = app_->getImagesDir();
          if (!fs::exists(imagesDir)) {
            fs::create_directories(imagesDir);
          }
          NSString *images_dir = [NSString stringWithUTF8String:imagesDir.c_str()];
          NSString *file_path_hash = getHashForPath(filePath);

          NSString *preview_file_name = [NSString stringWithFormat:@"file_preview_%@.png", file_path_hash];
          NSString *preview_file_path = [images_dir stringByAppendingPathComponent:preview_file_name];
          file_path_info.file_preview_name = [preview_file_name UTF8String];
          // If the file preview does not exist, get the preview image and save it.
          if (!fs::exists(preview_file_path.UTF8String)) {
            NSImage *preview = getThumbnailForFile(filePath, CGSizeMake(1024, 1024));
            if (preview) {
              NSData *tiff_data = [preview TIFFRepresentation];
              NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:tiff_data];
              NSData *png_data = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
              [png_data writeToFile:preview_file_path atomically:YES];
              file_path_info.file_preview_name = [preview_file_name UTF8String];
            }
          }

          NSString *file_thumb_name = [NSString stringWithFormat:@"file_thumb_%@.png", file_path_hash];
          NSString *file_thumb_path = [images_dir stringByAppendingPathComponent:file_thumb_name];
          file_path_info.file_thumb_name = [file_thumb_name UTF8String];
          // If the file thumbnail does not exist, get the thumbnail and save it.
          if (!fs::exists(file_thumb_path.UTF8String)) {
            NSImage *thumb = getThumbnailForFile(filePath, CGSizeMake(48, 48));
            if (thumb) {
              NSData *tiff_data = [thumb TIFFRepresentation];
              NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:tiff_data];
              NSData *png_data = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
              [png_data writeToFile:file_thumb_path atomically:YES];
              file_path_info.file_thumb_name = [file_thumb_name UTF8String];
            }
          }

          // Read file size in bytes.
          NSFileManager *fileManager = [NSFileManager defaultManager];
          NSDictionary *attr = [fileManager attributesOfItemAtPath:filePath error:nil];
          if (attr) {
            unsigned long long fileSize = [attr fileSize];
            file_path_info.size_in_bytes = static_cast<int>(fileSize);
            if (data->image_info.width > 0 && data->image_info.height > 0) {
              data->image_info.size_in_bytes = file_path_info.size_in_bytes;
            }
          }
          // Check if it's a folder.
          BOOL isDirectory = NO;
          BOOL exists = [fileManager fileExistsAtPath:filePath isDirectory:&isDirectory];
          file_path_info.folder = exists && isDirectory;

          data->file_paths.emplace_back(file_path_info);
          success = true;
        }
      }
    }
  }
  return success;
}

bool ClipboardReaderMac::readClipboardData(const std::shared_ptr<ClipboardData> &data) {
  // Check if the clipboard has changed.
  NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
  auto changeCount = [pasteboard changeCount];
  if (changeCount == last_change_count_) {
    return false;
  }
  last_change_count_ = changeCount;

  if (app_->isPaused()) {
    return false;
  }

  // If the clipboard contains the custom clip, it means that ClipBook put
  // this data and should not read it again.
  if (hasCustomClip(pasteboard)) {
    return false;
  }

  // Check if the active app should be ignored.
  auto settings = app_->settings();
  data->active_app_info = app_->getActiveAppInfo();
  auto active_app_path = data->active_app_info.path;
  if (!active_app_path.empty()) {
    auto apps_to_ignore = settings->getAppsToIgnore();
    if (apps_to_ignore.find(active_app_path) != std::string::npos) {
      return false;
    }
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

  bool has_image = readImageData(data);
  bool has_text = readTextData(data);
  bool has_files = readFilesData(data);
  return has_image || has_text || has_files;
}
