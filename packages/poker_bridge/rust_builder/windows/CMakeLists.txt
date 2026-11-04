# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "rust_lib_poker_bridge")
project(${PROJECT_NAME} LANGUAGES CXX)

include("../cargokit/cmake/cargokit.cmake")
# The Rust crate is in packages/poker_bridge/rust, not in the app. This CMake file is built through
# the app's .plugin_symlinks folder, and on Windows ".." there is resolved on the path as written
# (not through the link), so the way back is counted from the app's own folder:
#   <repo>/app/windows/flutter/ephemeral/.plugin_symlinks/rust_lib_poker_bridge/windows
#   six levels up is <repo>/app, one more is <repo>.
# The generated default (six levels, then "rust") looks for <repo>/app/rust and fails.
apply_cargokit(${PROJECT_NAME} ../../../../../../../packages/poker_bridge/rust rust_lib_poker_bridge "")

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(rust_lib_poker_bridge_bundled_libraries
  "${${PROJECT_NAME}_cargokit_lib}"
  PARENT_SCOPE
)
