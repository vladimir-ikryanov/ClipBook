#include "clipboard_reader_mac.h"

#import <Cocoa/Cocoa.h>
#import <Vision/Vision.h>

#include <filesystem>

#include "utils.h"

namespace fs = std::filesystem;

void extractTextFromImage(NSImage *image, const std::string& imageFileName, const std::shared_ptr<MainApp>& app, ClipboardData &data) {
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

    data.content = content;

    auto js_window = app->browser()->mainFrame()->executeJavaScript("window");
    js_window.asJsObject()->call("setTextFromImage", imageFileName, content);
  }];

  // Perform the request
  NSError *error = nil;
  [handler performRequests:@[textRequest] error:&error];
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

std::string getThumbImageFileName(const std::string& imageFileName) {
  std::string thumbFileName = imageFileName;
  size_t pos = thumbFileName.find_last_of('_');
  if (pos != std::string::npos) {
    thumbFileName.insert(pos, "_thumb");
  }
  return thumbFileName;
}

bool findIdenticalImage(NSImage *srcImage, const fs::path &imagesDir, ImageInfo& imageInfo) {
  auto images = findImages(imagesDir, "image_", ".png");
  for (const auto &image_path : images) {
    NSImage *dstImage = [[NSImage alloc] initWithContentsOfFile:[NSString stringWithUTF8String:image_path.c_str()]];
    if (dstImage == nil) {
      continue;
    }
    // Compare the images.
    NSBitmapImageRep *srcImageRep = [NSBitmapImageRep imageRepWithData:[srcImage TIFFRepresentation]];
    NSBitmapImageRep *dstImageRep = [NSBitmapImageRep imageRepWithData:[dstImage TIFFRepresentation]];

    // Compare image dimensions.
    if ([dstImageRep pixelsWide] != [srcImageRep pixelsWide] ||
        [dstImageRep pixelsHigh] != [srcImageRep pixelsHigh]) {
      [dstImage release];
      continue;
    }

    // Compare bytes per row.
    if ([dstImageRep bytesPerRow] != [srcImageRep bytesPerRow]) {
      [dstImage release];
      continue;
    }

    // Compare pixels.
    NSUInteger bytesPerRow = [dstImageRep bytesPerRow];
    unsigned char *dstData = [dstImageRep bitmapData];
    unsigned char *srcData = [srcImageRep bitmapData];

    bool identical = true;
    for (NSUInteger row = 0; row < [dstImageRep pixelsHigh]; row++) {
      if (memcmp(dstData + row * bytesPerRow, srcData + row * bytesPerRow, bytesPerRow) != 0) {
        identical = false;
        break;
      }
    }

    if (!identical) {
      [dstImage release];
      continue;
    }

    if (identical) {
      imageInfo.file_name = image_path.filename().string();
      imageInfo.thumb_file_name = getThumbImageFileName(imageInfo.file_name);
      [dstImage release];
      return true;
    }

    [dstImage release];
  }
  return false;
}

std::shared_ptr<ClipboardReaderMac>
ClipboardReaderMac::create(const std::shared_ptr<MainApp> &app) {
  std::shared_ptr<ClipboardReaderMac> manager(new ClipboardReaderMac(app));
  return manager;
}

ClipboardReaderMac::ClipboardReaderMac(const std::shared_ptr<MainApp> &app)
    : ClipboardReader(app) {}

bool ClipboardReaderMac::readClipboardData(ClipboardData &data) {
  // Check if the clipboard has changed.
  NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
  auto changeCount = [pasteboard changeCount];
  if (changeCount == last_change_count_) {
    return false;
  }
  last_change_count_ = changeCount;

  // Check if the active app should be ignored.
  auto settings = app_->settings();
  data.active_app_info = app_->getActiveAppInfo();
  auto apps_to_ignore = settings->getAppsToIgnore();
  if (apps_to_ignore.find(data.active_app_info.path) != std::string::npos) {
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

  // Read text content.
  if ([types containsObject:NSPasteboardTypeString]) {
    std::string content = [[pasteboard stringForType:NSPasteboardTypeString] UTF8String];
    if (!isEmptyOrSpaces(content)) {
      data.content = content;
      return true;
    }
  }

  // Read image content.
  if ([types containsObject:NSPasteboardTypePNG]) {
    // Make sure the images directory exists.
    fs::path imagesDir = app_->getImagesDir();
    if (!fs::exists(imagesDir)) {
      fs::create_directories(imagesDir);
    }

    // Get image info.
    NSData *png_data = [pasteboard dataForType:NSPasteboardTypePNG];
    NSImage *image = [[NSImage alloc] initWithData:png_data];
    data.image_info.width = static_cast<int>([image size].width);
    data.image_info.height = static_cast<int>([image size].height);
    data.image_info.size_in_bytes = [png_data length];

    // Check if an identical image is already stored in the directory and use it.
    ImageInfo image_info;
    if (findIdenticalImage(image, imagesDir, image_info)) {
      data.image_info.file_name = image_info.file_name;
      data.image_info.thumb_file_name = image_info.thumb_file_name;
      [image release];
      return true;
    }

    int creation_time_in_ms = (int) [[NSDate date] timeIntervalSince1970];

    // Save image to file.
    NSString *image_filename = [NSString stringWithFormat:@"image_%d.png", creation_time_in_ms];
    NSString *images_dir = [NSString stringWithUTF8String:imagesDir.c_str()];
    NSString *image_path = [images_dir stringByAppendingPathComponent:image_filename];
    [png_data writeToFile:image_path atomically:YES];
    data.image_info.file_name = [image_filename UTF8String];

    // Save image thumbnail to file.
    NSImage *thumbnail = createThumbnail(image, 48, 48);
    NSData *thumbnail_data = [thumbnail TIFFRepresentation];
    NSBitmapImageRep *thumbnail_image_rep = [NSBitmapImageRep imageRepWithData:thumbnail_data];
    NSDictionary *thumbnail_props = @{};
    NSData *thumbnail_png_data = [thumbnail_image_rep representationUsingType:NSBitmapImageFileTypePNG properties:thumbnail_props];
    NSString *thumbnail_filename = [NSString stringWithFormat:@"image_thumb_%d.png", creation_time_in_ms];
    NSString *thumbnail_path = [images_dir stringByAppendingPathComponent:thumbnail_filename];
    [thumbnail_png_data writeToFile:thumbnail_path atomically:YES];
    data.image_info.thumb_file_name = [thumbnail_filename UTF8String];
    [thumbnail release];

    // Extract text from image.
    extractTextFromImage(image, [image_filename UTF8String], app_, data);

    // Release resources.
    [image release];

    return true;
  }
  return false;
}
