#ifndef WEBVIEW_H_
#define WEBVIEW_H_

#include "molybden.hpp"

struct LinkPreviewDetails {
  std::string title;
  std::string description;
  std::string imageFileName;
  std::string faviconFileName;
};

class HeadlessWebView {
 public:
  explicit HeadlessWebView(std::shared_ptr<molybden::App> app, std::string images_dir);
  ~HeadlessWebView();

  std::string download(const std::string &url);
  bool fetchLinkPreviewDetails(const std::string &url, LinkPreviewDetails& details);

 private:
  std::string images_dir_;
  std::shared_ptr<molybden::Browser> browser_;
};

#endif  // WEBVIEW_H_
