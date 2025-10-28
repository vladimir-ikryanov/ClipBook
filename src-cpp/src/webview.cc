#include "webview.h"

#include <utility>
#include <thread>
#include <chrono>

#include "url.h"
#include "utils.h"

HeadlessWebView::HeadlessWebView(std::shared_ptr<mobrowser::App> app, std::string images_dir) : images_dir_(std::move(images_dir)) {
  browser_ = mobrowser::Browser::create(std::move(app));
  // Mute audio to avoid playing sounds on the web page while fetching link preview details.
  browser_->media()->muteAudio();
}

HeadlessWebView::~HeadlessWebView() {
  browser_->close();
}

bool HeadlessWebView::fetchLinkPreviewDetails(const std::string &url, LinkPreviewDetails& details) {
  auto nav_result = browser_->navigation()->loadUrlAndWait(url);
  if (nav_result.hasNavigationTimedOut()) {
    return false;
  }
  auto frame = browser_->mainFrame();
  auto title = frame->executeJavaScript("document.title").asString();
  if (title.empty()) {
    title = frame->executeJavaScript(
        "document.querySelector('meta[property=\"og:title\"]')?.getAttribute('content')").asString();
  }
  details.title = title;

  auto description = frame->executeJavaScript(
      "document.querySelector('meta[property=\"og:description\"]')?.getAttribute('content')").asString();
  if (description.empty()) {
    description = frame->executeJavaScript(
        "document.querySelector('meta[name=\"description\"]')?.getAttribute('content')").asString();
  }
  details.description = description;

  auto image_url = frame->executeJavaScript(
      "document.querySelector('meta[property=\"og:image\"]')?.getAttribute('content')").asString();
  if (image_url.empty()) {
    image_url = frame->executeJavaScript(
        "document.querySelector('meta[name=\"twitter:image\"]')?.getAttribute('content')").asString();
  }
  if (!image_url.empty()) {
    details.imageFileName = download(image_url, "preview_");
  }

  auto favicon_url = frame->executeJavaScript(
      "document.querySelector('link[rel=\"icon\"]')?.getAttribute('href')").asString();
  if (!favicon_url.empty()) {
    details.faviconFileName = download(favicon_url, "favicon_");
  }

  return true;
}

std::string HeadlessWebView::download(const std::string &url, const std::string& file_name_prefix) {
  if (!URL(url).isValid()) {
    return "";
  }

  std::string result;
  bool completed = false;
  
  browser_->onStartDownload = [this, &result, &completed, &file_name_prefix]
      (const mobrowser::StartDownloadArgs &args, mobrowser::StartDownloadAction action) {
    // Get current time in milliseconds to generate a unique file name.
    std::string file = file_name_prefix + std::to_string(getCurrentTimeMillis()) + ".png";
    auto path = images_dir_ + "/" + file;
    args.download->onDownloadFinished += [file, &result, &completed](const mobrowser::DownloadFinished &event) {
      result = file;
      completed = true;
    };
    args.download->onDownloadCanceled += [&result, &completed](const mobrowser::DownloadCanceled &event) {
      result = "";
      completed = true;
    };
    args.download->onDownloadInterrupted += [&result, &completed](const mobrowser::DownloadInterrupted &event) {
      result = "";
      completed = true;
    };
    action.download(path);
  };
  browser_->download(url);

  // Wait for the download to complete or timeout after 10 seconds.
  auto start = std::chrono::steady_clock::now();
  while (!completed && (std::chrono::steady_clock::now() - start) < std::chrono::seconds(10)) {
    std::this_thread::sleep_for(std::chrono::milliseconds(10));
  }
  
  return completed ? result : "";
}
