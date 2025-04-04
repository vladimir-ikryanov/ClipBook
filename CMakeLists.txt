cmake_minimum_required(VERSION 3.21)

# The official build flag is used to enable/disable certain features.
set(OFFICIAL_BUILD FALSE)

# Set deployment target for macOS
set(CMAKE_OSX_DEPLOYMENT_TARGET "11.0" CACHE STRING "Minimum macOS deployment version" FORCE)

# Configures your project.
project(ClipBook LANGUAGES CXX)

# Imports the Molybden app configuration and setups the auxiliary targets, resources, etc.
# Important: Do not move this include above the project declaration.
include(node_modules/@molybden-apps/molybden/Molybden.cmake)

# The source files of your app.
set(APP_SOURCES
        src-cpp/src/main.cc
        src-cpp/src/main_app.h
        src-cpp/src/main_app.cc
        src-cpp/src/url.h
        src-cpp/src/url.cc
        src-cpp/src/utils.h
        src-cpp/src/utils.cc
        src-cpp/src/url_request_interceptor.h
        src-cpp/src/url_request_interceptor.cc
        src-cpp/src/app_settings.h
        src-cpp/src/app_settings.cc
        src-cpp/src/webview.h
        src-cpp/src/webview.cc
)

if (OS_WIN)
    set(APP_SOURCES_WIN
            src-cpp/src/main_app_win.h
            src-cpp/src/main_app_win.cc
    )
endif ()

if (OS_MAC)
    set(APP_SOURCES_MAC
            src-cpp/src/active_app_observer.h
            src-cpp/src/active_app_observer.mm
            src-cpp/src/main_app_mac.h
            src-cpp/src/main_app_mac.mm
            src-cpp/src/app_settings_mac.h
            src-cpp/src/app_settings_mac.mm
            src-cpp/src/clipboard_reader_mac.h
            src-cpp/src/clipboard_reader_mac.mm
    )
    if (OFFICIAL_BUILD)
        set(LICENSING_SOURCES_MAC
                src-cpp/src/licensing/licensing.h
                src-cpp/src/licensing/licensing.mm
        )
    endif ()
endif ()

# Add additional compile definitions.
if (OFFICIAL_BUILD)
    add_compile_definitions(OFFICIAL_BUILD)
endif ()

# Defines the main target of the application.
add_library(molybden_lib STATIC ${APP_SOURCES} ${APP_SOURCES_WIN} ${APP_SOURCES_MAC} ${LICENSING_SOURCES_MAC})

# The Molybden API requires C++20.
set_property(TARGET molybden_lib PROPERTY CXX_STANDARD 20)

# Adds the Molybden API to the include path.
# Provide the additional include directories if needed.
target_include_directories(molybden_lib PRIVATE ${MOLYBDEN_SDK_DIR}/include)

if (OS_MAC)
    target_link_libraries(molybden_lib PRIVATE "-framework Cocoa -framework Vision -framework IOKit -framework QuickLookThumbnailing")
endif ()
