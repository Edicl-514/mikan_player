cmake_minimum_required(VERSION 3.21)
project(mikan_libtorrent LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(MIKAN_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../..")
set(MIKAN_LIBTORRENT_SOURCE_DIR "${MIKAN_REPO_ROOT}/third_party/libtorrent")

if(NOT EXISTS "${MIKAN_LIBTORRENT_SOURCE_DIR}/CMakeLists.txt")
  message(FATAL_ERROR "third_party/libtorrent was not found")
endif()

if(NOT EXISTS "${MIKAN_LIBTORRENT_SOURCE_DIR}/deps/try_signal/try_signal.hpp")
  message(FATAL_ERROR "libtorrent submodules are missing. Run: git -C third_party/libtorrent submodule update --init --recursive")
endif()

set(BUILD_SHARED_LIBS OFF CACHE BOOL "Build libtorrent as static library" FORCE)
set(build_tests OFF CACHE BOOL "Build libtorrent tests" FORCE)
set(build_examples OFF CACHE BOOL "Build libtorrent examples" FORCE)
set(build_tools OFF CACHE BOOL "Build libtorrent tools" FORCE)
set(python-bindings OFF CACHE BOOL "Build libtorrent Python bindings" FORCE)
set(python-egg-info OFF CACHE BOOL "Build libtorrent Python egg info" FORCE)

add_subdirectory("${MIKAN_LIBTORRENT_SOURCE_DIR}" "${CMAKE_BINARY_DIR}/libtorrent-build")

if(WIN32)
  target_compile_definitions(torrent-rasterbar PRIVATE _WIN32_WINNT=0x0A00)
endif()

add_library(mikan_libtorrent SHARED
  src/mikan_libtorrent.cpp
)

target_include_directories(mikan_libtorrent
  PUBLIC
    "${CMAKE_CURRENT_LIST_DIR}/include"
)

target_link_libraries(mikan_libtorrent
  PRIVATE
    torrent-rasterbar
)

# cpp-httplib system dependencies
if(WIN32)
  target_link_libraries(mikan_libtorrent PRIVATE ws2_32 crypt32)
else()
  find_package(Threads REQUIRED)
  target_link_libraries(mikan_libtorrent PRIVATE Threads::Threads)
endif()

target_compile_definitions(mikan_libtorrent PRIVATE MIKAN_LIBTORRENT_BUILDING)
if(WIN32)
  target_compile_definitions(mikan_libtorrent PRIVATE
    _WIN32_WINNT=0x0A00
    WIN32_LEAN_AND_MEAN
    NOMINMAX
  )
endif()

if(MSVC)
  target_compile_options(mikan_libtorrent PRIVATE /W4 /EHsc)
else()
  target_compile_options(mikan_libtorrent PRIVATE -Wall -Wextra -Wpedantic)
endif()
