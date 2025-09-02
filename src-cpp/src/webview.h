#ifndef WEBVIEW_H_
#define WEBVIEW_H_

#include "mobrowser.hpp"

struct LinkPreviewDetails {
  std::string title;
  std::string description;
  std::string imageFileName;
  std::string faviconFileName;
};

class HeadlessWebView {
 public:
  explicit HeadlessWebView(std::shared_ptr<mobrowser::App> app, std::string images_dir);
  ~HeadlessWebView();

  std::string download(const std::string &url, const std::string& file_name_prefix);
  bool fetchLinkPreviewDetails(const std::string &url, LinkPreviewDetails& details);

 private:
  std::string images_dir_;
  std::shared_ptr<mobrowser::Browser> browser_;
};

#endif  // WEBVIEW_H_
