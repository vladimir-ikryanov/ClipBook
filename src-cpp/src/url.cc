#include "url.h"

URL::URL(std::string url) : url_(std::move(url)) {
  // Find the scheme separator (i.e., "://")
  if (std::size_t scheme_pos = url_.find("://");
      scheme_pos != std::string::npos) {
    scheme_ = url_.substr(0, scheme_pos);
    // Move past the "://" separator
    host_ = url_.substr(scheme_pos + 3);
  } else {
    scheme_ = "";
    host_ = url_;
  }

  // Find the path separator (i.e., "/")
  if (std::size_t path_pos = host_.find('/'); path_pos != std::string::npos) {
    path_ = host_.substr(path_pos + 1);
    // Move back to the start of the host
    host_ = host_.substr(0, path_pos);
  } else {
    path_ = "";
  }

  // Exclude query part from path
  if (std::size_t query_pos = path_.find('?'); query_pos != std::string::npos) {
    path_ = path_.substr(0, query_pos);
  }

  // Find the port separator (i.e., ":")
  if (std::size_t port_pos = host_.find(':'); port_pos != std::string::npos) {
    port_ = host_.substr(port_pos + 1);
    // Move back to the start of the host
    host_ = host_.substr(0, port_pos);
  } else {
    port_ = "";
  }

  // Split path into items
  std::size_t start = 0;
  std::size_t end = path_.find('/');
  while (end != std::string::npos) {
    path_items_.push_back(path_.substr(start, end - start));
    start = end + 1;
    end = path_.find('/', start);
  }
  std::string path_item = path_.substr(start);
  if (!path_item.empty()) {
    path_items_.push_back(path_item);
  }
}

std::string URL::scheme() {
  return scheme_;
}

std::string URL::host() {
  return host_;
}

std::string URL::port() {
  return port_;
}

std::string URL::path() {
  return path_;
}

std::vector<std::string> URL::pathItems() {
  return path_items_;
}

std::string URL::string() {
  return url_;
}

bool URL::isValid() {
  return !scheme_.empty() && !host_.empty();
}
