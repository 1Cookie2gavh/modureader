# Keep the plugin ABI/build setup, without its startup location subscription.
if(NOT TARGET permission_handler_windows_plugin)
  message(FATAL_ERROR "Expected permission_handler_windows_plugin target")
endif()
get_target_property(MODU_PERMISSION_SOURCE_DIR permission_handler_windows_plugin SOURCE_DIR)
set_property(TARGET permission_handler_windows_plugin PROPERTY SOURCES
  "${CMAKE_CURRENT_LIST_DIR}/../../third_party/permission_handler_windows/permission_handler_windows_plugin.cpp")
target_include_directories(permission_handler_windows_plugin PRIVATE
  "${MODU_PERMISSION_SOURCE_DIR}"
  "${MODU_PERMISSION_SOURCE_DIR}/include")
