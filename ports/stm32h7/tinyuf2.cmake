# General settings
set(PYTHON3 python3)
set(MKDIR mkdir)
set(SED sed)
set(CP cp)
set(RM rm)

# Cross compiler
set(CROSS_COMPILE arm-none-eabi-)
set(CC ${CROSS_COMPILE}gcc)
set(OBJCOPY ${CROSS_COMPILE}objcopy)
set(SIZE ${CROSS_COMPILE}size)

# Top-level directory
set(TOP ${CMAKE_CURRENT_LIST_DIR}/../..)
# set(CURRENT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

# Board configuration
set(PORT "stm32h7") # Set default port or override with custom build
set(PORT_DIR ports/${PORT})
set(BOARD_DIR ${TOP}/${PORT_DIR}/boards/${BOARD})

if(NOT EXISTS ${BOARD_DIR})
    message(FATAL_ERROR "Invalid BOARD specified. You must provide a valid BOARD parameter with 'BOARD='" ${BOARD_DIR})
endif()

# Build directories
set(BUILD_DIR ${TOP}/_build/${BOARD})
set(BIN_DIR ${TOP}/${PORT_DIR}/_bin/${BOARD})
set(PROJECT_NAME "tinyuf2-${BOARD}")
set(OUTNAME ${PROJECT_NAME}.elf)

# C compiler flags
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DBOARD_UF2_FAMILY_ID=${UF2_FAMILY_ID}")

# Bootloader
if(NOT BUILD_APPLICATION)
    # Git version (replace with equivalent CMake function if needed)
    execute_process(
        COMMAND git describe --dirty --always --tags
        OUTPUT_VARIABLE GIT_VERSION
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DUF2_VERSION_BASE=\"\\\"${GIT_VERSION}\\\"\" -DUF2_VERSION=\"\\\"${GIT_VERSION} - ${GIT_SUBMODULE_VERSIONS}\\\"\"")

    # Bootloader source files
    list(APPEND SOURCES
        ${TOP}/src/ghostfat.c
        ${TOP}/src/images.c
        ${TOP}/src/main.c
        ${TOP}/src/msc.c
        ${TOP}/src/screen.c
        ${TOP}/src/usb_descriptors.c
    )
endif()

# Include directories
include_directories(
    ${TOP}/src
    ${TOP}/src/favicon
    ${TOP}/${PORT_DIR}
    ${TOP}/${BOARD_DIR}
)

# TinyUSB sources and includes
if(NOT BUILD_NO_TINYUSB)
    set(TINYUSB_DIR ${TOP}/lib/tinyusb/src)
    list(APPEND SOURCES
        ${TINYUSB_DIR}/tusb.c
        ${TINYUSB_DIR}/common/tusb_fifo.c
        ${TINYUSB_DIR}/device/usbd.c
        ${TINYUSB_DIR}/device/usbd_control.c
        ${TINYUSB_DIR}/class/cdc/cdc_device.c
        ${TINYUSB_DIR}/class/dfu/dfu_rt_device.c
        ${TINYUSB_DIR}/class/hid/hid_device.c
        ${TINYUSB_DIR}/class/msc/msc_device.c
        ${TINYUSB_DIR}/class/vendor/vendor_device.c
    )
    include_directories(${TINYUSB_DIR})
endif()

# Logger and Debug settings
if(DEFINED LOGGER AND LOGGER STREQUAL "rtt")
    set(RTT_SRC lib/SEGGER_RTT)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DLOGGER_RTT -DSEGGER_RTT_MODE_DEFAULT=SEGGER_RTT_MODE_BLOCK_IF_FIFO_FULL")
    include_directories(${RTT_SRC}/RTT)
    list(APPEND SOURCES ${RTT_SRC}/RTT/SEGGER_RTT.c)
elseif(DEFINED LOGGER AND LOGGER STREQUAL "swo")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DLOGGER_SWO")
endif()

message(${SOURCES})

# Add executable
add_executable(${OUTNAME} ${SOURCES})

# Linker and additional flags
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -fshort-enums -Wl,-Map=${PROJECT_NAME}.map -Wl,-cref -Wl,-gc-sections")
target_link_libraries(${OUTNAME} gcc m c)
if(NOT SKIP_NANOLIB)
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -specs=nosys.specs -specs=nano.specs")
    target_link_libraries(${OUTNAME} nosys)
endif()

# Compiler and warning flags
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -ggdb -fdata-sections -ffunction-sections -fsingle-precision-constant -fno-strict-aliasing")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wdouble-promotion -Wstrict-prototypes -Wall -Wextra -Werror -Wfatal-errors")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Werror-implicit-function-declaration -Wfloat-equal -Wundef -Wshadow -Wwrite-strings")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wno-stringop-overflow")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wsign-compare -Wmissing-format-attribute -Wunreachable-code -Wno-cast-align")
