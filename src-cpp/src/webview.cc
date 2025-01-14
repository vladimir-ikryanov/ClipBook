#include "webview.h"

#include <future>
#include <utility>

#include "url.h"

HeadlessWebView::HeadlessWebView(std::shared_ptr<molybden::App> app, std::string images_dir) : images_dir_(std::move(images_dir)) {
  browser_ = molybden::Browser::create(std::move(app));
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
    details.imageFileName = download(image_url);
  }

  auto favicon_url = frame->executeJavaScript(
      "document.querySelector('link[rel=\"icon\"]')?.getAttribute('href')").asString();
  if (!favicon_url.empty()) {
    details.faviconFileName = download(favicon_url);
  }

  return true;
}

std::string HeadlessWebView::download(const std::string &url) {
  if (!URL(url).isValid()) {
    return "";
  }

  std::promise<std::string> promise;
  std::future<std::string> future = promise.get_future();
  browser_->onStartDownload = [this, &promise](const molybden::StartDownloadArgs &args,
                                               molybden::StartDownloadAction action) {
    auto file = args.download->target().suggested_file_name;
    auto path = images_dir_ + "/" + file;
    args.download->onDownloadFinished += [file, &promise](const molybden::DownloadFinished &event) {
      promise.set_value(file);
    };
    args.download->onDownloadCanceled += [&promise](const molybden::DownloadCanceled &event) {
      promise.set_value("");
    };
    args.download->onDownloadInterrupted += [&promise](const molybden::DownloadInterrupted &event) {
      promise.set_value("");
    };
    action.download(path);
  };
  browser_->download(url);

  if (future.wait_for(std::chrono::seconds(3)) == std::future_status::ready) {
    return future.get();
  } else {
    return "";
  }
}
