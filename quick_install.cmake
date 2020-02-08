# cmake -P quick_install.cmake

set(project "strn")

if(WIN32)
    set(temp_dir $ENV{TEMP})
elseif(UNIX)
    set(temp_dir /tmp)
else()
    message(FATAL_ERROR "No temporary directory found!")
endif()

file(TO_NATIVE_PATH "/" path_sep)
set(src_dir ${CMAKE_CURRENT_LIST_DIR})
set(build_dir ${temp_dir}${path_sep}${project}-build)
set(error_file ${build_dir}${path_sep}quick_install_error)

if(EXISTS ${error_file})
    file(REMOVE_RECURSE ${build_dir})
endif()

execute_process(COMMAND ${CMAKE_COMMAND} -S ${src_dir} -B ${build_dir}  RESULT_VARIABLE cmd_res)
if(NOT cmd_res EQUAL 0)
    file(TOUCH ${error_file})
else()
    execute_process(COMMAND ${CMAKE_COMMAND} --build ${build_dir}  RESULT_VARIABLE cmd_res)
    if(NOT cmd_res EQUAL 0)
        file(TOUCH ${error_file})
    else()
        execute_process(COMMAND ${CMAKE_COMMAND} --install ${build_dir})
    endif()
endif()
