#ifndef CLIPBOOK_UTILS_H_
#define CLIPBOOK_UTILS_H_

#include <string>
#include <vector>

/**
 * Returns true if the string is empty or contains only spaces.
 */
bool isEmptyOrSpaces(const std::string &str);

/**
 * Returns the path to the user's home directory.
 */
std::string getUserHomeDir();

/**
 * Returns the path to the application data directory.
 */
std::string getAppDataDir();

#endif  // CLIPBOOK_UTILS_H_
