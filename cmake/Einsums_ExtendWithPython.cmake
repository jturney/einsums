function(einsums_extend_with_python target)
  if (APPLE)
    target_link_options(${target} PUBLIC -undefined dynamic_lookup)
  endif ()

  target_link_libraries(${target} PRIVATE Python3::Module)
  target_link_libraries(${target} PRIVATE pybind11::module pybind11::lto pybind11::windows_extras)

  if (MSVC)
    target_link_libraries(${target} PRIVATE pybind11::windows_extras)
  endif ()

  if (NOT MSVC AND NOT ${CMAKE_BUILD_TYPE} MATCHES Debug|RelWithDebInfo)
    # Strip unnecessary sections of the binary on Linux/macOS
    pybind11_strip(${target})
  endif ()
  pybind11_extension(${target})

  set_target_properties(${target} PROPERTIES PREFIX "" DEBUG_POSTFIX "")
endfunction()
