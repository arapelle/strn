
list(PREPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR})
include(Project)
list(POP_FRONT CMAKE_MODULE_PATH)

function(add_cpp_library_examples)
    set(example_output_dir ${CMAKE_BUILD_TYPE})

    get_property(project_targets DIRECTORY ${PROJECT_SOURCE_DIR} PROPERTY BUILDSYSTEM_TARGETS)
    foreach(target ${project_targets})
        get_target_property(target_type ${target} TYPE)
        if(${target_type} STREQUAL "SHARED_LIBRARY" OR ${target_type} STREQUAL "STATIC_LIBRARY")
            set(tested_lib ${target})
            break()
        endif()
    endforeach()

    if(tested_lib)
        file(GLOB cpp_program_files "*.cpp")
        foreach(filename ${cpp_program_files})
            get_filename_component(example_program_name ${filename} NAME_WE)
            add_executable(${example_program_name} ${filename})
            set_target_properties(${example_program_name} PROPERTIES RUNTIME_OUTPUT_DIRECTORY ${example_output_dir})
            target_link_libraries(${example_program_name} $<TARGET_NAME:${tested_lib}>)
            target_include_directories(${example_program_name} PUBLIC
                $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include>
                $<BUILD_INTERFACE:${PROJECT_BINARY_DIR}/include>)
        endforeach()
    endif()
endfunction()

function(add_cpp_library_tests)
    set(test_output_dir ${CMAKE_BUILD_TYPE})

    get_property(project_targets DIRECTORY ${PROJECT_SOURCE_DIR} PROPERTY BUILDSYSTEM_TARGETS)
    foreach(target ${project_targets})
        get_target_property(target_type ${target} TYPE)
        if(${target_type} STREQUAL "SHARED_LIBRARY" OR ${target_type} STREQUAL "STATIC_LIBRARY")
            set(tested_lib ${target})
            break()
        endif()
    endforeach()

    if(tested_lib)
        file(GLOB cpp_program_files "*.cpp")
        foreach(filename ${cpp_program_files})
            get_filename_component(test_program_name ${filename} NAME_WE)
            add_executable(${test_program_name} ${filename})
            set_target_properties(${test_program_name} PROPERTIES RUNTIME_OUTPUT_DIRECTORY ${test_output_dir})
            target_link_libraries(${test_program_name} $<TARGET_NAME:${tested_lib}>)
            target_include_directories(${test_program_name} PUBLIC
                $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include>
                $<BUILD_INTERFACE:${PROJECT_BINARY_DIR}/include>)
            add_test("${test_program_name}" ${test_output_dir}/${test_program_name})
        endforeach()
    endif()
endfunction()

function(generate_verbose_public_library_config_file package_config_file)
    generate_basic_package_config_file(package_config_file)
    file(APPEND ${package_config_file}
         "
get_target_property(${PROJECT_NAME}-CONFS ${PROJECT_NAME} IMPORTED_CONFIGURATIONS)
if(${PROJECT_NAME}-CONFS)
    foreach(${PROJECT_NAME}-CONF ${${PROJECT_NAME}-CONFS})
        # Get shared
        get_target_property(shared-path ${PROJECT_NAME} IMPORTED_LOCATION_${${PROJECT_NAME}-CONF})
        get_filename_component(shared-name ${shared-path} NAME)
        # Get static
        get_target_property(static-path ${PROJECT_NAME}-static IMPORTED_LOCATION_${${PROJECT_NAME}-CONF})
        get_filename_component(static-name ${static-path} NAME)
        message(STATUS \"Found strn ${strn-CONF}: (found version \\\"${PROJECT_VERSION}\\\"): ${shared-name} ${static-name}\")
    endforeach()
endif()
")
endfunction()

function(add_public_cpp_library)
    #----------------------------------------#
    # Declare args
    set(options "BASIC_PACKAGE_CONFIG_FILE;VERBOSE_PACKAGE_CONFIG_FILE")
    set(params "CXX_STANDARD;INPUT_VERSION_HEADER;VERSION_HEADER;INPUT_PACKAGE_CONFIG_FILE")
    set(lists "")
    # Parse args
    cmake_parse_arguments(PARSE_ARGV 0 "FARG" "${options}" "${params}" "${lists}")
    # Set default value if needed
    if(NOT FARG_CXX_STANDARD)
        set(FARG_CXX_STANDARD 17)
    endif()
    # Check args values
    if(NOT FARG_BASIC_PACKAGE_CONFIG_FILE AND NOT FARG_VERBOSE_PACKAGE_CONFIG_FILE AND NOT FARG_INPUT_PACKAGE_CONFIG_FILE)
        message(FATAL_ERROR "Package config file argument is missing. [BASIC_PACKAGE_CONFIG_FILE|VERBOSE_PACKAGE_CONFIG_FILE|INPUT_PACKAGE_CONFIG_FILE]")
    endif()
    #----------------------------------------#

    # Configure C++ standard
    set(CMAKE_CXX_STANDARD ${FARG_CXX_STANDARD})
    set(CMAKE_CXX_STANDARD_REQUIRED ON)

    #-----
    ## PROJECT CONF

    # OPTIONS
    option(${PROJECT_NAME}_BUILD_SHARED_LIB "Indicates if we build a SHARED library." ON)
    option(${PROJECT_NAME}_BUILD_STATIC_LIB "Indicates if we build a STATIC library." ON)
    if(EXISTS "${PROJECT_SOURCE_DIR}/test/CMakeLists.txt")
        option(${PROJECT_NAME}_BUILD_TESTS "Indicates if we build the tests or not." OFF)
    endif()
    if(EXISTS "${PROJECT_SOURCE_DIR}/example/CMakeLists.txt")
        option(${PROJECT_NAME}_BUILD_EXAMPLES "Indicates if we build the examples or not." OFF)
    endif()

    # OUTPUT PATHS
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BUILD_TYPE}/bin)
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BUILD_TYPE}/lib)
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BUILD_TYPE}/lib)

    # PRINT STATUS
    message(STATUS "PROJECT : ${PROJECT_NAME} v${PROJECT_VERSION}")
    message(STATUS "BUILD   : ${CMAKE_BUILD_TYPE}")
    message(STATUS "CPPCOMP : ${CMAKE_CXX_COMPILER} ${CMAKE_CXX_COMPILER_VERSION}")

    if(NOT ${${PROJECT_NAME}_BUILD_SHARED_LIB} AND NOT ${${PROJECT_NAME}_BUILD_STATIC_LIB})
        message(FATAL_ERROR "You did not choose which target(s) to build (SHARED, STATIC).")
    endif()

    #-----

    # GENERATE HEADER VERSION FILE
    if(FARG_VERSION_HEADER)
        if(IS_ABSOLUTE ${FARG_VERSION_HEADER})
            message(FATAL_ERROR "Provide a relative path for generated version file!")
        endif()
        generate_version_header(INPUT_VERSION_HEADER ${FARG_INPUT_VERSION_HEADER}
                                VERSION_HEADER ${PROJECT_BINARY_DIR}/include/${PROJECT_NAME}/${FARG_VERSION_HEADER})
    endif()

    #-----

    include(GNUInstallDirs)

    # ADD TARGET LIBRARY
    set(project_object_target ${PROJECT_NAME}-object)
    set(project_shared_target ${PROJECT_NAME})
    set(project_static_target ${PROJECT_NAME}-static)
    set(export_name ${PROJECT_NAME})

    file(GLOB_RECURSE target_header_files include/*)
    file(GLOB_RECURSE target_src_files src/*)
    add_library(${project_object_target} OBJECT ${target_header_files} ${target_src_files})
    target_include_directories(${project_object_target} PUBLIC
        $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include>
        $<BUILD_INTERFACE:${PROJECT_BINARY_DIR}/include>)
    set_property(TARGET ${project_object_target} PROPERTY POSITION_INDEPENDENT_CODE 1)
    if(MSVC)
        target_compile_options(${project_object_target} PRIVATE /Wall)
    elseif(CMAKE_COMPILER_IS_GNUCC OR CMAKE_COMPILER_IS_GNUCXX)
        target_compile_options(${project_object_target} PRIVATE -Wall -Wextra -pedantic)
    endif()

    if(${${PROJECT_NAME}_BUILD_SHARED_LIB})
        add_library(${project_shared_target} SHARED $<TARGET_OBJECTS:${project_object_target}>)
        target_include_directories(${project_shared_target} PUBLIC $<INSTALL_INTERFACE:include>)
        set_target_properties(${project_shared_target} PROPERTIES DEBUG_POSTFIX "-d" SOVERSION ${PROJECT_VERSION})
        set(project_targets ${project_targets} ${project_shared_target})
    endif()

    if(${${PROJECT_NAME}_BUILD_STATIC_LIB})
        add_library(${project_static_target} STATIC $<TARGET_OBJECTS:${project_object_target}>)
        target_include_directories(${project_static_target} PUBLIC $<INSTALL_INTERFACE:include>)
        set_target_properties(${project_static_target} PROPERTIES DEBUG_POSTFIX "-d")
        set(project_targets ${project_targets} ${project_static_target})
    endif()

    #-----

    # EXAMPLES
    if(EXISTS "${PROJECT_SOURCE_DIR}/example/CMakeLists.txt" AND ${${PROJECT_NAME}_BUILD_EXAMPLES})
        add_subdirectory(example)
    endif()

    #-----

    # TESTS
    if(EXISTS "${PROJECT_SOURCE_DIR}/test/CMakeLists.txt" AND ${${PROJECT_NAME}_BUILD_TESTS})
        enable_testing()
        add_subdirectory(test)
    endif()

    #-----

    # INSTALL
    include(CMakePackageConfigHelpers)

    set(relative_install_cmake_package_dir "${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME}")
    set(install_cmake_package_dir "${CMAKE_INSTALL_PREFIX}/${relative_install_cmake_package_dir}")

    install(TARGETS ${project_targets} EXPORT ${export_name})
    install(DIRECTORY include/${PROJECT_NAME} DESTINATION include)
    install(DIRECTORY ${PROJECT_BINARY_DIR}/include/${PROJECT_NAME} DESTINATION include)
    install(EXPORT ${export_name} DESTINATION ${relative_install_cmake_package_dir})

    if(FARG_BASIC_PACKAGE_CONFIG_FILE)
        generate_basic_package_config_file(${PROJECT_BINARY_DIR}/${PROJECT_NAME}-config.cmake)
    elseif(FARG_VERBOSE_PACKAGE_CONFIG_FILE)
        generate_verbose_public_library_config_file(${PROJECT_BINARY_DIR}/${PROJECT_NAME}-config.cmake)
    elseif(FARG_INPUT_PACKAGE_CONFIG_FILE)
        configure_package_config_file(${FARG_INPUT_PACKAGE_CONFIG_FILE}
            "${PROJECT_BINARY_DIR}/${PROJECT_NAME}-config.cmake"
            INSTALL_DESTINATION ${relative_install_cmake_package_dir}
            NO_SET_AND_CHECK_MACRO
            NO_CHECK_REQUIRED_COMPONENTS_MACRO)
    endif()

    write_basic_package_version_file("${PROJECT_BINARY_DIR}/${PROJECT_NAME}-config-version.cmake"
        VERSION ${PROJECT_VERSION}
        COMPATIBILITY SameMajorVersion)

    install(FILES
        ${PROJECT_BINARY_DIR}/${PROJECT_NAME}-config.cmake
        ${PROJECT_BINARY_DIR}/${PROJECT_NAME}-config-version.cmake
        DESTINATION ${install_cmake_package_dir})

    install_cmake_uninstall_script(${install_cmake_package_dir})
endfunction()
