#----------------------------------------------------------------------------------------------
# Copyright (c) The Einsums Developers. All rights reserved.
# Licensed under the MIT License. See LICENSE.txt in the project root for license information.
#----------------------------------------------------------------------------------------------

include(Einsums_ExportTargets)

function(einsums_add_module libname modulename)
  # Retrieve arguments
  set(options CONFIG_FILES)
  set(one_value_args GLOBAL_HEADER_GEN)
  set(multi_value_args
      SOURCES
      HEADERS
      OBJECTS
      DEPENDENCIES
      MODULE_DEPENDENCIES
      CMAKE_SUBDIRS
      EXCLUDE_FROM_GLOBAL_HEADER
  )
  cmake_parse_arguments(
    ${modulename} "${options}" "${one_value_args}" "${multi_value_args}" ${ARGN}
  )
  if(${modulename}_UNPARSED_ARGUMENTS)
    message(
      AUTHOR_WARNING "Arguments were not used by the module: ${${modulename}_UNPARSED_ARGUMENTS}"
    )
  endif()

  include(Einsums_Message)
  include(Einsums_Option)

  # Global headers should be always generated except if explicitly disabled
  if("${${modulename}_GLOBAL_HEADER_GEN}" STREQUAL "")
    set(${modulename}_GLOBAL_HEADER_GEN ON)
  endif()

  string(TOUPPER ${libname} libname_upper)
  string(TOUPPER ${modulename} modulename_upper)

  string(MAKE_C_IDENTIFIER ${libname_upper} libname_upper)
  string(MAKE_C_IDENTIFIER ${modulename_upper} modulename_upper)

  # Mark the module as enabled (see einsums/libs/CMakeLists.txt)
  set(EINSUMS_ENABLED_MODULES
      ${EINSUMS_ENABLED_MODULES} ${modulename}
      CACHE INTERNAL "List of enabled einsums modules" FORCE
  )

  # Main directories of the module
  set(SOURCE_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/src")
  set(HEADER_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/include")

  einsums_debug("Add module ${modulename}: SOURCE_ROOT: ${SOURCE_ROOT}")
  einsums_debug("Add module ${modulename}: HEADER_ROOT: ${HEADER_ROOT}")

  set(all_headers ${${modulename}_HEADERS})

  # Write full path for the sources files
  list(TRANSFORM ${modulename}_SOURCES PREPEND ${SOURCE_ROOT}/ OUTPUT_VARIABLE sources)
  list(TRANSFORM ${modulename}_HEADERS PREPEND ${HEADER_ROOT}/ OUTPUT_VARIABLE headers)

  # This header generation is disabled for config module specific generated headers are included
  if(${modulename}_GLOBAL_HEADER_GEN)
    if("${PROJECT_NAME}/Modules/${modulename}.hpp" IN_LIST all_headers)
      string(
        CONCAT error_message
               "Global header generation turned on for module ${modulename} but the "
               "header \"${PROJECT_NAME}/Modules/${modulename}.hpp\" is also listed explicitly as"
               "a header. Turn off global header generation or remove the "
               "\"${PROJECT_NAME}/Modules/${modulename}.hpp\" file."
      )
      einsums_error(${error_message})
    endif()
    # Add a global include file that include all module headers
    set(global_header "${CMAKE_CURRENT_BINARY_DIR}/include/${PROJECT_NAME}/Modules/${modulename}.hpp")
    set(module_headers)
    foreach(header_file ${${modulename}_HEADERS})
      # Exclude the files specified
      if((NOT (${header_file} IN_LIST ${modulename}_EXCLUDE_FROM_GLOBAL_HEADER))
         AND (NOT ("${header_file}" MATCHES "(D|d)etail"))
      )
        set(module_headers "${module_headers}#include <${header_file}>\n")
      endif()
    endforeach(header_file)
    configure_file(
      "${PROJECT_SOURCE_DIR}/cmake/templates/GlobalModuleHeader.hpp.in" "${global_header}"
    )
    set(generated_headers ${global_header})
  endif()

  # generate configuration header for this module
  set(config_header "${CMAKE_CURRENT_BINARY_DIR}/include/${PROJECT_NAME}/${modulename}/Defines.hpp")
  einsums_write_config_defines_file(NAMESPACE ${modulename_upper} FILENAME ${config_header})
  set(generated_headers ${generated_headers} ${config_header})

  if(${modulename}_CONFIG_FILES)
    # Version file
    set(global_config_file ${CMAKE_CURRENT_BINARY_DIR}/include/${PROJECT_NAME}/Config/Version.hpp)
    configure_file(
      "${CMAKE_CURRENT_SOURCE_DIR}/cmake/templates/ConfigVersion.hpp.in" "${global_config_file}"
      @ONLY
    )
    set(generated_headers ${generated_headers} ${global_config_file})
    # Global config defines file (different from the one for each module)
    set(global_config_file ${CMAKE_CURRENT_BINARY_DIR}/include/${PROJECT_NAME}/Config/Defines.hpp)
    einsums_write_config_defines_file(
      TEMPLATE "${CMAKE_CURRENT_SOURCE_DIR}/cmake/templates/ConfigDefines.hpp.in" NAMESPACE default
      FILENAME "${global_config_file}"
    )
    set(generated_headers ${generated_headers} ${global_config_file})
  endif()

  # collect zombie generated headers
  file(GLOB_RECURSE zombie_generated_headers ${CMAKE_CURRENT_BINARY_DIR}/include/*.hpp
       ${CMAKE_CURRENT_BINARY_DIR}/include_compatibility/*.hpp
  )
  list(REMOVE_ITEM zombie_generated_headers ${generated_headers} ${compat_headers}
       ${CMAKE_CURRENT_BINARY_DIR}/include/${PROJECT_NAME}/Config/ModulesEnabled.hpp
  )
  foreach(zombie_header IN LISTS zombie_generated_headers)
    einsums_warn("Removing zombie generated header: ${zombie_header}")
    file(REMOVE ${zombie_header})
  endforeach()

  # list all specified headers
  foreach(header_file ${headers})
    einsums_debug(${header_file})
  endforeach(header_file)

  if(sources)
    set(module_is_interface_library FALSE)
  else()
    set(module_is_interface_library TRUE)
  endif()

  if(module_is_interface_library)
    set(module_library_type INTERFACE)
    set(module_public_keyword INTERFACE)
  else()
    set(module_library_type OBJECT)
    set(module_public_keyword PUBLIC)
  endif()

  # create library modules
  add_library(${libname}_${modulename} ${module_library_type} ${sources} ${${modulename}_OBJECTS})

  if(EINSUMS_WITH_CHECK_MODULE_DEPENDENCIES)
    # verify that all dependencies are from the same module category
    foreach(dep ${${modulename}_MODULE_DEPENDENCIES})
      # consider only module dependencies, not other targets
      string(FIND ${dep} "Einsums_" find_index)
      if(${find_index} EQUAL 0)
        string(SUBSTRING ${dep} 5 -1 dep) # cut off leading "einsums_"
        list(FIND _${libname}_modules ${dep} dep_index)
        if(${dep_index} EQUAL -1)
          einsums_error(
            "The module ${dep} should not be be listed in MODULE_DEPENDENCIES "
            "for module Einsums_${modulename}"
          )
        endif()
      endif()
    endforeach()
  endif()

  target_link_libraries(
    ${libname}_${modulename} ${module_public_keyword} ${${modulename}_MODULE_DEPENDENCIES}
  )
  target_link_libraries(
    ${libname}_${modulename} ${module_public_keyword} ${${modulename}_DEPENDENCIES}
  )

  target_link_libraries(
    ${libname}_${modulename} ${module_public_keyword} einsums_public_flags einsums_base_libraries
  )

  target_include_directories(
    ${libname}_${modulename} ${module_public_keyword} $<BUILD_INTERFACE:${HEADER_ROOT}>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include> $<BUILD_INTERFACE:${PROJECT_BINARY_DIR}>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
  )

  if(NOT module_is_interface_library)
    target_link_libraries(${libname}_${modulename} PRIVATE einsums_private_flags)
  endif()

  if(EINSUMS_WITH_PRECOMPILED_HEADERS)
    target_precompile_headers(${libname}_${modulename} REUSE_FROM einsums_precompiled_headers)
  endif()

  if(NOT module_is_interface_library)
    target_compile_definitions(${libname}_${modulename} PRIVATE ${libname_upper}_EXPORTS)
  endif()

  einsums_add_source_group(
    NAME ${libname}_${modulename}
    ROOT ${HEADER_ROOT}/${PROJECT_NAME}
    CLASS "Header Files"
    TARGETS ${headers}
  )
  einsums_add_source_group(
    NAME ${libname}_${modulename}
    ROOT ${SOURCE_ROOT}
    CLASS "Source Files"
    TARGETS ${sources}
  )

  if(${modulename}_GLOBAL_HEADER_GEN OR ${modulename}_CONFIG_FILES)
    einsums_add_source_group(
      NAME ${libname}_${modulename}
      ROOT ${CMAKE_CURRENT_BINARY_DIR}/include/${PROJECT_NAME}
      CLASS "Generated Files"
      TARGETS ${generated_headers}
    )
  endif()
  einsums_add_source_group(
    NAME ${libname}_${modulename}
    ROOT ${CMAKE_CURRENT_BINARY_DIR}/include/${PROJECT_NAME}
    CLASS "Generated Files"
    TARGETS ${config_header}
  )

  # capitalize string
  string(SUBSTRING ${libname} 0 1 first_letter)
  string(TOUPPER ${first_letter} first_letter)
  string(REGEX REPLACE "^.(.*)" "${first_letter}\\1" libname_cap "${libname}")

  if(NOT module_is_interface_library)
    set_target_properties(
      ${libname}_${modulename} PROPERTIES FOLDER "Core/Modules/${libname_cap}"
                                          POSITION_INDEPENDENT_CODE ON
    )
  endif()

  if(EINSUMS_WITH_UNITY_BUILD AND NOT module_is_interface_library)
    set_target_properties(${libname}_${modulename} PROPERTIES UNITY_BUILD ON)
    set_target_properties(
      ${libname}_${modulename} PROPERTIES UNITY_BUILD_CODE_BEFORE_INCLUDE
                                          "// NOLINTBEGIN(bugprone-suspicious-include)"
    )
    set_target_properties(
      einsums_${modulename} PROPERTIES UNITY_BUILD_CODE_AFTER_INCLUDE
                                       "// NOLINTEND(bugprone-suspicious-include)"
    )
  endif()

  if(MSVC)
    set_target_properties(
      ${libname}_${modulename}
      PROPERTIES COMPILE_PDB_NAME_DEBUG ${libname}_${modulename}d
                 COMPILE_PDB_NAME_RELWITHDEBINFO ${libname}_${modulename}
                 COMPILE_PDB_OUTPUT_DIRECTORY_DEBUG ${CMAKE_CURRENT_BINARY_DIR}/Debug
                 COMPILE_PDB_OUTPUT_DIRECTORY_RELWITHDEBINFO
                 ${CMAKE_CURRENT_BINARY_DIR}/RelWithDebInfo
    )
  endif()

  install(
    TARGETS ${libname}_${modulename}
    EXPORT einsums_internal_targets
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR} COMPONENT ${modulename}
  )
  einsums_export_internal_targets(${libname}_${modulename})

  # Install the headers from the source
  install(
    DIRECTORY include/
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
    COMPONENT ${modulename}
  )

  # Installing the generated header files from the build dir
  install(
    DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/include/${PROJECT_NAME}
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
    COMPONENT ${modulename}
  )

  # install PDB if needed
  if(MSVC)
    foreach(cfg DEBUG;RELWITHDEBINFO)
      einsums_get_target_property(_pdb_file ${libname}_${modulename} COMPILE_PDB_NAME_${cfg})
      einsums_get_target_property(
        _pdb_dir ${libname}_${modulename} COMPILE_PDB_OUTPUT_DIRECTORY_${cfg}
      )
      install(
        FILES ${_pdb_dir}/${_pdb_file}.pdb
        DESTINATION ${CMAKE_INSTALL_LIBDIR}
        CONFIGURATIONS ${cfg}
        OPTIONAL
      )
    endforeach()
  endif()

  # Link modules to their higher-level libraries
  target_link_libraries(${libname} PUBLIC ${libname}_${modulename})
  target_link_libraries(${libname} PRIVATE ${${modulename}_OBJECTS})

  foreach(dir ${${modulename}_CMAKE_SUBDIRS})
    add_subdirectory(${dir})
  endforeach(dir)

  include(Einsums_PrintSummary)
  einsums_create_configuration_summary("    Module configuration (${modulename}):" "${modulename}")

endfunction(einsums_add_module)
