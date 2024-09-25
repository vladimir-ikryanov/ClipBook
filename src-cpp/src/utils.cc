#include "utils.h"

bool isEmptyOrSpaces(const std::string &str) {
  // Check if the string is empty or contains only spaces
  return str.empty() || std::all_of(str.begin(), str.end(), [](char c) {
    return std::isspace(static_cast<unsigned char>(c));
  });
}
