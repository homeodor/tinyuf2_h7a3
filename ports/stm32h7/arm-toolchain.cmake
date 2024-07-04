set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR ARM)

if(MINGW OR CYGWIN OR WIN32)
    set(UTIL_SEARCH_CMD where)
elseif(UNIX OR APPLE)
    set(UTIL_SEARCH_CMD which)
endif()

set(TOOLCHAIN_PREFIX arm-none-eabi-)
set(VISUAL_GDB_TOOLCHAIN_PATH "ENV{SystemDrive}/SysGCC/arm-eabi/bin")
set(ARM_INSTALLER_PATH_MAC "/Applications/ArmGNUToolchain/*/arm-none-eabi/bin")
set(ARM_INSTALLER_PATH_WIN "$ENV{ProgramFiles\(x86\)}/Arm GNU Toolchain arm-none-eabi/*/bin")

if(NOT DEFINED ARM_TOOLCHAIN_DIR)
    if(DEFINED ENV{ARM_TOOLCHAIN_DIR})
    # use defined environment variable, if available
        set(ARM_TOOLCHAIN_DIR $ENV{ARM_TOOLCHAIN_DIR})
        message("Using custom ENV variable to find ARM toolchain")
    else()
        # if not, try to get it from PATH:
        execute_process(
        COMMAND ${UTIL_SEARCH_CMD} ${TOOLCHAIN_PREFIX}gcc
        OUTPUT_VARIABLE BINUTILS_PATH
        OUTPUT_STRIP_TRAILING_WHITESPACE
        )

        if(EXISTS ${BINUTILS_PATH})
            message("ARM toolchain found on system path")
            get_filename_component(ARM_TOOLCHAIN_DIR ${BINUTILS_PATH} DIRECTORY)
        else()
            # try some common locations

            if (APPLE)
                # ARM's installer puts the toolchain here:
                file(GLOB TOOLCHAIN_IN_APPLICATIONS ARM_INSTALLER_PATH_MAC)
                list(POP_BACK TOOLCHAIN_IN_APPLICATIONS ARM_TOOLCHAIN_DIR)
            elseif (WIN32)
                if (EXISTS VISUAL_GDB_TOOLCHAIN_PATH)
                    # use VisualGDB's toolchain if present
                    set(ARM_TOOLCHAIN_DIR VISUAL_GDB_TOOLCHAIN_PATH)
                else()
                    # if not, ARM's installer puts the toolchain here:
                    file(GLOB TOOLCHAIN_IN_PROGRAM_FILES ARM_INSTALLER_PATH_WIN)
                    list(POP_BACK TOOLCHAIN_IN_PROGRAM_FILES ARM_TOOLCHAIN_DIR)
                endif()
            else()
                message(FATAL_ERROR "Specify ARM toolchain either by setting ENV variable ARM_TOOLCHAIN_DIR or directly editing arm-toolchain.cmake")
            endif()

            if(NOT EXISTS "${ARM_TOOLCHAIN_DIR}")
                message(FATAL_ERROR "${ARM_TOOLCHAIN_DIR} ARM toolchain directory does not exist")
            endif()
        endif()
    endif()
endif()

message("Found ARM toolchain at " ${ARM_TOOLCHAIN_DIR})

set(BINUTILS_PATH ${ARM_TOOLCHAIN_DIR})

set(TOOLCHAIN_PATH_AND_PREFIX ${ARM_TOOLCHAIN_DIR}/${TOOLCHAIN_PREFIX})

set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

if (WIN32)
    set(CMAKE_C_COMPILER ${TOOLCHAIN_PATH_AND_PREFIX}gcc.exe)
    set(CMAKE_CXX_COMPILER ${TOOLCHAIN_PATH_AND_PREFIX}g++.exe)
else()
    set(CMAKE_C_COMPILER ${TOOLCHAIN_PATH_AND_PREFIX}gcc)
    set(CMAKE_CXX_COMPILER ${TOOLCHAIN_PATH_AND_PREFIX}g++)
endif()

set(CMAKE_ASM_COMPILER ${CMAKE_C_COMPILER})

set(CMAKE_OBJCOPY ${TOOLCHAIN_PATH_AND_PREFIX}objcopy CACHE INTERNAL "objcopy tool")
set(CMAKE_SIZE_UTIL ${TOOLCHAIN_PATH_AND_PREFIX}size CACHE INTERNAL "size tool")

set(CMAKE_FIND_ROOT_PATH ${ARM_TOOLCHAIN_DIR})
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
