#ifndef CLIPBOOK_URL_H_
#define CLIPBOOK_URL_H_

#include <string>
#include <vector>

class URL {
 public:
  explicit URL(std::string url);

  /**
   * Indicates if the URL is valid and has at least scheme and host.
   */
  bool isValid();

  std::string scheme();
  std::string host();
  std::string port();
  std::string path();
  std::vector<std::string> pathItems();

  std::string string();

 private:
  std::string url_;
  std::string scheme_;
  std::string host_;
  std::string port_;
  std::string path_;
  std::vector<std::string> path_items_;
};

#endif  // CLIPBOOK_URL_H_
