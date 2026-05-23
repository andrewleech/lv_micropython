# Extract c_module() entries from MICROPY_FROZEN_MANIFEST and append them to
# USER_C_MODULES, so the subsequent include of py/usermod.cmake picks them up.

# MICROPY_USER_FROZEN_MANIFEST lets the rp2/esp32 port CMakeLists.txt preserve
# a command-line FROZEN_MANIFEST through board-config inclusion.
if (MICROPY_USER_FROZEN_MANIFEST)
    set(MICROPY_FROZEN_MANIFEST ${MICROPY_USER_FROZEN_MANIFEST})
endif()

# Extract C module paths from manifest if MICROPY_FROZEN_MANIFEST is set.
if (MICROPY_FROZEN_MANIFEST)
    # MICROPY_LIB_DIR is set in py.cmake (included before this file).
    # Set default path variables to be passed to makemanifest.py. These will be
    # available in path substitutions. Additional variables can be set per-board
    # in mpconfigboard.cmake or on the cmake command line.
    if(NOT DEFINED MICROPY_MANIFEST_PORT_DIR)
        set(MICROPY_MANIFEST_PORT_DIR ${MICROPY_PORT_DIR})
    endif()
    if(NOT DEFINED MICROPY_MANIFEST_BOARD_DIR)
        set(MICROPY_MANIFEST_BOARD_DIR ${MICROPY_BOARD_DIR})
    endif()
    if(NOT DEFINED MICROPY_MANIFEST_MPY_DIR)
        set(MICROPY_MANIFEST_MPY_DIR ${MICROPY_DIR})
    endif()
    if(NOT DEFINED MICROPY_MANIFEST_MPY_LIB_DIR)
        set(MICROPY_MANIFEST_MPY_LIB_DIR ${MICROPY_LIB_DIR})
    endif()

    # Find all MICROPY_MANIFEST_* variables and turn them into command line arguments.
    get_cmake_property(_manifest_vars VARIABLES)
    list(FILTER _manifest_vars INCLUDE REGEX "MICROPY_MANIFEST_.*")
    set(_manifest_var_args)
    foreach(_manifest_var IN LISTS _manifest_vars)
        list(APPEND _manifest_var_args "-v")
        string(REGEX REPLACE "MICROPY_MANIFEST_(.*)" "\\1" _manifest_var_name ${_manifest_var})
        list(APPEND _manifest_var_args "${_manifest_var_name}=${${_manifest_var}}")
    endforeach()

    # Skip during UPDATE_SUBMODULES as micropython-lib may not be initialised
    # yet and require() would fail.
    if (EXISTS ${MICROPY_FROZEN_MANIFEST} AND NOT UPDATE_SUBMODULES)
        if (NOT Python3_EXECUTABLE)
            find_package(Python3 REQUIRED COMPONENTS Interpreter)
        endif()

        execute_process(
            COMMAND "${Python3_EXECUTABLE}" "${MICROPY_DIR}/tools/makemanifest.py"
                --list-c-modules ${_manifest_var_args} "${MICROPY_FROZEN_MANIFEST}"
            OUTPUT_VARIABLE MANIFEST_C_MODULES
            ERROR_VARIABLE MANIFEST_ERROR
            OUTPUT_STRIP_TRAILING_WHITESPACE
            RESULT_VARIABLE MANIFEST_RESULT
        )

        # SEND_ERROR (not FATAL_ERROR) so other configure-time errors still surface.
        if (NOT MANIFEST_RESULT EQUAL 0)
            message(SEND_ERROR "Failed to extract C modules from manifest: ${MICROPY_FROZEN_MANIFEST}\nError: ${MANIFEST_ERROR}")
        endif()

        # De-dup in case the same path was also passed on the command line.
        if (MANIFEST_C_MODULES)
            string(REPLACE "\n" ";" MANIFEST_C_MODULES_LIST "${MANIFEST_C_MODULES}")
            list(APPEND USER_C_MODULES ${MANIFEST_C_MODULES_LIST})
            list(REMOVE_DUPLICATES USER_C_MODULES)
        endif()
    endif()
endif()
