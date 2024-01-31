cmake_minimum_required(VERSION 3.21)

message(STATUS "CMAKE_BUILD_TYPE: ${CMAKE_BUILD_TYPE}")

# Configure project properties.
set(TARGET_NAME "app")
set(LIB_NAME "molybden_client")
set(DIST_DIR ${CMAKE_BINARY_DIR}/bin)

# Read JSON configuration and configure app properties.
file(READ ${CMAKE_CURRENT_SOURCE_DIR}/molybden.conf.json MOLYBDEN_CONF_JSON)
string(JSON APP_NAME GET ${MOLYBDEN_CONF_JSON} app name)
string(JSON APP_VERSION_MAJOR GET ${MOLYBDEN_CONF_JSON} app version major)
string(JSON APP_VERSION_MINOR GET ${MOLYBDEN_CONF_JSON} app version minor)
string(JSON APP_VERSION_PATCH GET ${MOLYBDEN_CONF_JSON} app version patch)
string(JSON APP_DESCRIPTION GET ${MOLYBDEN_CONF_JSON} app description)
string(JSON APP_COPYRIGHT GET ${MOLYBDEN_CONF_JSON} app copyright)
string(JSON APP_AUTHOR GET ${MOLYBDEN_CONF_JSON} app author)
string(JSON APP_BUNDLE_ID GET ${MOLYBDEN_CONF_JSON} app bundle macOS bundleID)
string(JSON APP_WINDOWS_ICON GET ${MOLYBDEN_CONF_JSON} app bundle Windows icon)
string(JSON APP_MAC_ICON GET ${MOLYBDEN_CONF_JSON} app bundle macOS icon)
string(JSON APP_LINUX_ICON GET ${MOLYBDEN_CONF_JSON} app bundle Linux icon)
string(JSON APP_BASE_DEV_URL GET ${MOLYBDEN_CONF_JSON} app configurations development url)
string(JSON APP_BASE_PROD_URL GET ${MOLYBDEN_CONF_JSON} app configurations production url)

# https://stackoverflow.com/questions/26434308/cmake-system-name-blank
project(${APP_NAME}
        VERSION ${APP_VERSION_MAJOR}.${APP_VERSION_MINOR}.${APP_VERSION_PATCH}
        DESCRIPTION "${APP_DESCRIPTION}"
        LANGUAGES CXX)

# Configure SDK directory.
if (${CMAKE_SYSTEM_NAME} MATCHES Windows)
    set(MOLYBDEN_SDK_DIR "node_modules/@molybden-apps/molybden-win-x64")
elseif (${CMAKE_SYSTEM_NAME} MATCHES Darwin)
    if (CMAKE_SYSTEM_PROCESSOR STREQUAL "x86_64")
        set(MOLYBDEN_SDK_DIR "node_modules/@molybden-apps/molybden-darwin-x64")
    else ()
        set(MOLYBDEN_SDK_DIR "node_modules/@molybden-apps/molybden-darwin-arm64")
    endif ()
elseif (${CMAKE_SYSTEM_NAME} MATCHES Linux)
    set(MOLYBDEN_SDK_DIR "node_modules/@molybden-apps/molybden-linux-x64")
endif ()

cmake_path(ABSOLUTE_PATH MOLYBDEN_SDK_DIR NORMALIZE)
message(STATUS "MOLYBDEN_SDK_DIR: ${MOLYBDEN_SDK_DIR}")
set(MOLYBDEN_SDK_BIN_DIR ${MOLYBDEN_SDK_DIR}/bin)
set(MOLYBDEN_SDK_RUNTIME_DIR ${MOLYBDEN_SDK_DIR}/runtime)
set(MOLYBDEN_SDK_ASSETS_DIR ${MOLYBDEN_SDK_DIR}/assets)

# Initialize platform-specific properties.
if (${CMAKE_SYSTEM_NAME} MATCHES Windows)
    set(RUNTIME_EXECUTABLE_PATH)
    set(RUNTIME_LIBRARIES_PATH)
    set(RUNTIME_RESOURCES_PATH resources)
elseif (${CMAKE_SYSTEM_NAME} MATCHES Linux)
    set(RUNTIME_EXECUTABLE_PATH)
    set(RUNTIME_LIBRARIES_PATH)
    set(RUNTIME_RESOURCES_PATH resources)
elseif (${CMAKE_SYSTEM_NAME} MATCHES Darwin)
    set(RUNTIME_CONTENTS_PATH ${APP_NAME}.app/Contents)
    set(RUNTIME_EXECUTABLE_PATH "${RUNTIME_CONTENTS_PATH}/MacOS")
    set(RUNTIME_LIBRARIES_PATH "${RUNTIME_CONTENTS_PATH}/Frameworks/Chromium Framework.framework/Libraries")
    set(RUNTIME_RESOURCES_PATH ${RUNTIME_CONTENTS_PATH}/Resources)
    set(RUNTIME_HELPERS_PATH "${RUNTIME_CONTENTS_PATH}/Frameworks/Chromium Framework.framework/Helpers")
    set(ALERT_HELPER_RESOURCE_PATH "${RUNTIME_HELPERS_PATH}/${APP_NAME}\ Helper\ \(Alerts\).app/Contents/Resources")
endif ()

if (${CMAKE_SYSTEM_NAME} MATCHES Windows)
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
endif ()

if (PRODUCTION_BUILD)
    add_compile_definitions(PRODUCTION_MODE)
    add_compile_definitions(APP_BASE_URL="${APP_BASE_PROD_URL}")
else ()
    add_compile_definitions(APP_BASE_URL="${APP_BASE_DEV_URL}")
endif ()
add_compile_definitions(APP_NAME="${APP_NAME}")
add_compile_definitions(APP_VERSION="${APP_VERSION_MAJOR}.${APP_VERSION_MINOR}.${APP_VERSION_PATCH}")
add_compile_definitions(APP_COPYRIGHT="${APP_COPYRIGHT}")
add_compile_definitions(APP_DESCRIPTION="${APP_DESCRIPTION}")

add_library(${LIB_NAME} SHARED src-cpp/src/main.cc ${MOLYBDEN_SDK_ASSETS_DIR}/app/toolkit.cc)
set_property(TARGET ${LIB_NAME} PROPERTY CXX_STANDARD 20)

target_include_directories(${LIB_NAME} PRIVATE ${MOLYBDEN_SDK_DIR}/include)
if (CMAKE_BUILD_TYPE STREQUAL Debug)
    set(CMAKE_CONFIGURATION_TYPES "Debug")
    set(LIBRARIES_OUTPUT_DIR ${MOLYBDEN_SDK_DIR}/lib/debug)
else ()
    set(CMAKE_CONFIGURATION_TYPES "RelWithDebInfo")
    set(LIBRARIES_OUTPUT_DIR ${MOLYBDEN_SDK_DIR}/lib/release)
endif ()

if (${CMAKE_SYSTEM_NAME} MATCHES Linux)
    # Temporary solution for Linux: we need maintaining static libraries link order and link explicitly some libs
    SET(Molybden_LIBRARIES
            "${LIBRARIES_OUTPUT_DIR}/libmolybden.a"
            "${LIBRARIES_OUTPUT_DIR}/libmolybden_boost_filesystem.a"
            "${LIBRARIES_OUTPUT_DIR}/libprotobuf$<$<CONFIG:Debug>:d>.a"
            -pthread -ldl)
else ()
    file(GLOB Molybden_LIBRARIES ${LIBRARIES_OUTPUT_DIR}/*)
endif ()

target_link_libraries(${LIB_NAME} ${Molybden_LIBRARIES})

set_target_properties(${LIB_NAME}
        PROPERTIES
        ARCHIVE_OUTPUT_DIRECTORY "${DIST_DIR}/${RUNTIME_LIBRARIES_PATH}"
        ARCHIVE_OUTPUT_DIRECTORY_RELEASE "${DIST_DIR}/${RUNTIME_LIBRARIES_PATH}"
        ARCHIVE_OUTPUT_DIRECTORY_DEBUG "${DIST_DIR}/${RUNTIME_LIBRARIES_PATH}"
        RUNTIME_OUTPUT_DIRECTORY "${DIST_DIR}/${RUNTIME_LIBRARIES_PATH}"
        RUNTIME_OUTPUT_DIRECTORY_RELEASE "${DIST_DIR}/${RUNTIME_LIBRARIES_PATH}"
        RUNTIME_OUTPUT_DIRECTORY_DEBUG "${DIST_DIR}/${RUNTIME_LIBRARIES_PATH}"
        LIBRARY_OUTPUT_DIRECTORY "${DIST_DIR}/${RUNTIME_LIBRARIES_PATH}"
        LIBRARY_OUTPUT_DIRECTORY_RELEASE "${DIST_DIR}/${RUNTIME_LIBRARIES_PATH}"
        LIBRARY_OUTPUT_DIRECTORY_DEBUG "${DIST_DIR}/${RUNTIME_LIBRARIES_PATH}")

# Configure app bundle on macOS.
if (${CMAKE_SYSTEM_NAME} MATCHES Darwin)
    # Remove the previous app bundle if any
    file(REMOVE_RECURSE ${DIST_DIR}/${APP_NAME}.app)

    file(COPY ${MOLYBDEN_SDK_RUNTIME_DIR}/Chromium.app/
            DESTINATION ${DIST_DIR}/${APP_NAME}.app/)
    file(COPY ${CMAKE_CURRENT_SOURCE_DIR}/${APP_MAC_ICON}
            DESTINATION ${DIST_DIR}/${RUNTIME_RESOURCES_PATH}/)
    file(REMOVE ${DIST_DIR}/${APP_NAME}.app/Contents/MacOS/Chromium)
    configure_file(${CMAKE_SOURCE_DIR}/src-cpp/assets/app-Info.plist
            ${DIST_DIR}/${RUNTIME_CONTENTS_PATH}/Info.plist)

    # Configure the main helper application
    file(RENAME ${DIST_DIR}/${RUNTIME_HELPERS_PATH}/Chromium\ Helper.app ${DIST_DIR}/${RUNTIME_HELPERS_PATH}/${APP_NAME}\ Helper.app)
    file(RENAME ${DIST_DIR}/${RUNTIME_HELPERS_PATH}/${APP_NAME}\ Helper.app/Contents/MacOS/Chromium\ Helper ${DIST_DIR}/${RUNTIME_HELPERS_PATH}/${APP_NAME}\ Helper.app/Contents/MacOS/${APP_NAME}\ Helper)
    configure_file(${CMAKE_SOURCE_DIR}/src-cpp/assets/app-helper-Info.plist
            ${DIST_DIR}/${RUNTIME_HELPERS_PATH}/${APP_NAME}\ Helper.app/Contents/Info.plist)

    # Configure rest of the helper applications
    set(HELPER_LIBS Renderer Plugin GPU Alerts)
    foreach (lib ${HELPER_LIBS})
        file(RENAME ${DIST_DIR}/${RUNTIME_HELPERS_PATH}/Chromium\ Helper\ \(${lib}\).app ${DIST_DIR}/${RUNTIME_HELPERS_PATH}/${APP_NAME}\ Helper\ \(${lib}\).app)
        file(RENAME ${DIST_DIR}/${RUNTIME_HELPERS_PATH}/${APP_NAME}\ Helper\ \(${lib}\).app/Contents/MacOS/Chromium\ Helper\ \(${lib}\) ${DIST_DIR}/${RUNTIME_HELPERS_PATH}/${APP_NAME}\ Helper\ \(${lib}\).app/Contents/MacOS/${APP_NAME}\ Helper\ \(${lib}\))
        configure_file(${CMAKE_SOURCE_DIR}/src-cpp/assets/app-helper\ \(${lib}\)-Info.plist
                ${DIST_DIR}/${RUNTIME_HELPERS_PATH}/${APP_NAME}\ Helper\ \(${lib}\).app/Contents/Info.plist)
    endforeach ()

    file(COPY ${CMAKE_CURRENT_SOURCE_DIR}/${APP_MAC_ICON}
            DESTINATION ${DIST_DIR}/${ALERT_HELPER_RESOURCE_PATH}/)
endif ()

# Configure app on Windows.
if (${CMAKE_SYSTEM_NAME} MATCHES Windows)
    file(COPY ${MOLYBDEN_SDK_RUNTIME_DIR}/ DESTINATION ${DIST_DIR}/)
    file(REMOVE ${DIST_DIR}/chromium${CMAKE_EXECUTABLE_SUFFIX})

    file(COPY ${MOLYBDEN_SDK_ASSETS_DIR}/resource_patcher/ DESTINATION ${CMAKE_BINARY_DIR}/resource_patcher/)
    file(COPY ${CMAKE_CURRENT_SOURCE_DIR}/${APP_WINDOWS_ICON} DESTINATION ${CMAKE_BINARY_DIR}/resource_patcher/)
    get_filename_component(APP_WINDOWS_ICON_NAME ${CMAKE_BINARY_DIR}/resource_patcher/${APP_WINDOWS_ICON} NAME)
    configure_file(${MOLYBDEN_SDK_ASSETS_DIR}/resource_patcher/resource.rc ${CMAKE_BINARY_DIR}/resource_patcher/resource.rc)

    add_executable(resource_patcher ${CMAKE_BINARY_DIR}/resource_patcher/main.cc)
    target_sources(resource_patcher
            PRIVATE
            ${CMAKE_BINARY_DIR}/resource_patcher/resource.rc
            ${CMAKE_BINARY_DIR}/resource_patcher/updater.cc
            ${CMAKE_BINARY_DIR}/resource_patcher/updater.h)
endif ()

# Configure app on Linux.
if (${CMAKE_SYSTEM_NAME} MATCHES Linux)
    file(COPY ${MOLYBDEN_SDK_RUNTIME_DIR}/ DESTINATION ${DIST_DIR}/)
    file(REMOVE ${DIST_DIR}/chromium${CMAKE_EXECUTABLE_SUFFIX})

    file(MAKE_DIRECTORY ${DIST_DIR}/${RUNTIME_RESOURCES_PATH}/)
    file(COPY_FILE ${CMAKE_CURRENT_SOURCE_DIR}/${APP_LINUX_ICON} ${DIST_DIR}/${RUNTIME_RESOURCES_PATH}/app128.png)
endif ()

# This function let us watch the given file and reload CMake if it's changed.
function(watch)
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${ARGV})
endfunction()

# Watch JSON with the project configs to force CMake reload on every change.
watch(${CMAKE_CURRENT_SOURCE_DIR}/molybden.conf.json)

# Allow running Molybden application from IDE.
if (CMAKE_SYSTEM_NAME STREQUAL "Windows")
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} /MANIFEST:NO")
endif ()

file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/null.cc" "\
    #if _WIN32
    #include <windows.h>
    int APIENTRY WinMain(HINSTANCE, HINSTANCE, PSTR, int) { return 0; }
    #endif
    int main() { return 0; }")
add_executable(${TARGET_NAME} WIN32 "${CMAKE_CURRENT_BINARY_DIR}/null.cc")
set_target_properties(${TARGET_NAME}
        PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY "${DIST_DIR}/${RUNTIME_EXECUTABLE_PATH}"
        RUNTIME_OUTPUT_DIRECTORY_RELEASE "${DIST_DIR}/${RUNTIME_EXECUTABLE_PATH}"
        RUNTIME_OUTPUT_DIRECTORY_DEBUG "${DIST_DIR}/${RUNTIME_EXECUTABLE_PATH}"
        OUTPUT_NAME ${APP_NAME})
add_dependencies(${TARGET_NAME} ${LIB_NAME})

if (${CMAKE_SYSTEM_NAME} MATCHES Windows)
    # Configure the default startup project in a Visual Studio solution.
    set_property(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} PROPERTY VS_STARTUP_PROJECT ${APP_NAME})
endif ()

# Replace the dummy executable with Chromium.
if (${CMAKE_SYSTEM_NAME} MATCHES Linux OR ${CMAKE_SYSTEM_NAME} MATCHES Windows)
    set(CHROMIUM_BIN ${MOLYBDEN_SDK_RUNTIME_DIR}/chromium${CMAKE_EXECUTABLE_SUFFIX})
elseif (${CMAKE_SYSTEM_NAME} MATCHES Darwin)
    set(CHROMIUM_BIN ${MOLYBDEN_SDK_RUNTIME_DIR}/Chromium.app/Contents/MacOS/Chromium)
endif ()

add_custom_command(TARGET ${TARGET_NAME}
        POST_BUILD
        DEPENDS ${TARGET_NAME}
        COMMAND ${CMAKE_COMMAND} -E copy_if_different ${CHROMIUM_BIN} $<TARGET_FILE:${TARGET_NAME}>)

if (${CMAKE_SYSTEM_NAME} MATCHES Windows)
    # Configure branding on Windows.
    add_custom_command(TARGET ${TARGET_NAME}
            POST_BUILD
            DEPENDS ${TARGET_NAME}
            COMMAND resource_patcher
            $<TARGET_FILE:${TARGET_NAME}>
            ${DIST_DIR}/chrome.dll)
    # Move binaries with PDBs to the /bin directory.
    if (CMAKE_BUILD_TYPE STREQUAL RelWithDebInfo)
        add_custom_command(TARGET ${LIB_NAME} POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_directory
                ${CMAKE_BINARY_DIR}/bin/RelWithDebInfo/ ${CMAKE_BINARY_DIR}/bin/
                COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_BINARY_DIR}/bin/RelWithDebInfo
                )
        add_custom_command(TARGET ${TARGET_NAME} POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_directory
                ${CMAKE_BINARY_DIR}/bin/RelWithDebInfo/ ${CMAKE_BINARY_DIR}/bin/
                COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_BINARY_DIR}/bin/RelWithDebInfo
        )
    endif ()
endif ()

# Invoke molybden keygen in development mode.
if (NOT PRODUCTION_BUILD)
    add_custom_command(TARGET ${LIB_NAME}
            POST_BUILD
            COMMAND "${MOLYBDEN_SDK_BIN_DIR}/molybden" keygen --out ${CMAKE_BINARY_DIR}
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
endif ()

# Copy the app resources directory to the application bundle.
if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/src-cpp/resources")
    add_custom_command(TARGET ${LIB_NAME} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_directory
            ${CMAKE_CURRENT_SOURCE_DIR}/src-cpp/resources ${DIST_DIR}/${RUNTIME_RESOURCES_PATH}
    )
endif()
