cmake_minimum_required(VERSION 3.21)

# The official build flag is used to enable/disable certain features.
if(DEFINED ENV{CLIPBOOK_CODESIGN_IDENTITY})
  set(OFFICIAL_BUILD TRUE)
  message(STATUS "Official build enabled")
else()
  set(OFFICIAL_BUILD FALSE)
  message(STATUS "Official build disabled")
endif()

# Set deployment target for macOS
set(CMAKE_OSX_DEPLOYMENT_TARGET "12.0" CACHE STRING "Minimum macOS deployment version" FORCE)

# Force use of older C++ standard library symbols compatible with macOS 12
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -mmacosx-version-min=12.0")

# Use libc++ but with backward compatibility
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -stdlib=libc++ -D_LIBCPP_DISABLE_AVAILABILITY")

# Additional flags for backward compatibility
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fno-aligned-allocation")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-unguarded-availability-new")

# Configures your project.
project(ClipBook LANGUAGES CXX)

# Imports the MoBrowser app configuration and setups the auxiliary targets, resources, etc.
# Important: Do not move this include above the project declaration.
include(node_modules/@mobrowser-apps/mobrowser/MoBrowser.cmake)

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
            src-cpp/src/quick_look_previewer_mac.h
            src-cpp/src/quick_look_previewer_mac.mm
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
add_library(mobrowser_lib STATIC ${APP_SOURCES} ${APP_SOURCES_WIN} ${APP_SOURCES_MAC} ${LICENSING_SOURCES_MAC})

# The MoBrowser API requires C++20.
set_property(TARGET mobrowser_lib PROPERTY CXX_STANDARD 20)

# Adds the MoBrowser API to the include path.
# Provide the additional include directories if needed.
target_include_directories(mobrowser_lib PRIVATE ${MOBROWSER_SDK_DIR}/include)

if (OS_MAC)
    target_link_libraries(mobrowser_lib PRIVATE "-framework Cocoa -framework Vision -framework IOKit -framework QuickLookThumbnailing -framework QuickLook -framework Quartz")
endif ()
