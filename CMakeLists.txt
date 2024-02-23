cmake_minimum_required(VERSION 3.21)

# Configures your project.
project(Clipboard LANGUAGES CXX)

# Imports the Molybden app configuration and setups the auxiliary targets, resources, etc.
# Important: Do not move this include above the project declaration.
include(node_modules/@molybden-apps/molybden/Molybden.cmake)

# The source files of your app.
set(APP_SOURCES
        src-cpp/src/main.cc
        src-cpp/src/main_app.h
        src-cpp/src/main_app.cc
        src-cpp/src/main_app_mac.h
        src-cpp/src/main_app_mac.mm
        src-cpp/src/clipboard_manager.h
        src-cpp/src/clipboard_manager.cc
)

# Defines the main target of the application.
add_library(molybden_lib STATIC ${APP_SOURCES})

# The Molybden API requires C++20.
set_property(TARGET molybden_lib PROPERTY CXX_STANDARD 20)

# Adds the Molybden API to the include path.
# Provide the additional include directories if needed.
target_include_directories(molybden_lib PRIVATE ${MOLYBDEN_SDK_DIR}/include)

if (${CMAKE_SYSTEM_NAME} MATCHES Darwin)
    target_link_libraries(molybden_lib PRIVATE "-framework Cocoa")
endif ()
