#include "utils.h"

bool isEmptyOrSpaces(const std::string &str) {
  // Check if the string is empty or contains only spaces
  return str.empty() || std::all_of(str.begin(), str.end(), [](char c) {
    return std::isspace(static_cast<unsigned char>(c));
  });
}

std::string getUserHomeDir() {
  const char *homeDir = getenv("HOME");
  if (homeDir != nullptr) {
    return {homeDir};
  }
  return "";
}

std::string getAppDataDir() {
  std::string homeDir = getUserHomeDir();
  if (homeDir.empty()) {
    return "";
  }
  return homeDir + "/Library/Application Support/ClipBook";
}

long long getCurrentTimeMillis() {
  return duration_cast<std::chrono::milliseconds>(
      std::chrono::system_clock::now().time_since_epoch()).count();
}
