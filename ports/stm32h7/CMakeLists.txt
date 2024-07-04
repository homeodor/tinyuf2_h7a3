# The following five lines of boilerplate have to be in your project's
# CMakeLists in this exact order for cmake to work correctly
cmake_minimum_required(VERSION 3.17)

project(tinyuf2_all LANGUAGES C ASM)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS ON)
# set(CMAKE_CXX_STANDARD 17)
# set(CMAKE_CXX_STANDARD_REQUIRED ON)
# set(CMAKE_CXX_EXTENSIONS ON)

set(BOARD "atol_integration_stand")
set(SOURCES "")

include(${CMAKE_CURRENT_LIST_DIR}/../family_support.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/boards/${BOARD}/board.cmake)

set(UF2_FAMILY_ID 0x6db66082)

#include make.mk
#include port.mk

add_link_options(
	-T${CMAKE_CURRENT_LIST_DIR}/linker/memory.ld
	-T${CMAKE_CURRENT_LIST_DIR}/linker/common.ld
	-T${CMAKE_CURRENT_LIST_DIR}/linker/${MCU}.ld
)

list(APPEND SOURCES
  ${BOARD_SOURCES}  ${PORT_SOURCES}
  ${CMAKE_CURRENT_LIST_DIR}/boards.c
  ${CMAKE_CURRENT_LIST_DIR}/board_flash.c
  ${CMAKE_CURRENT_LIST_DIR}/board_hmi.c
  ${CMAKE_CURRENT_LIST_DIR}/board_irq
)

include(${CMAKE_CURRENT_LIST_DIR}/tinyuf2.cmake)

add_custom_command(
    TARGET ${OUTNAME}
    POST_BUILD
	COMMAND ${CMAKE_OBJCOPY} ARGS -O binary ${OUTNAME} ${PROJECT_NAME}.bin
)

add_custom_command(
    TARGET ${OUTNAME}
    POST_BUILD
	COMMAND ${CMAKE_OBJCOPY} ARGS -O ihex ${OUTNAME} ${PROJECT_NAME}.hex
)

# Post build: generate bootloader_bin.c for self-update and combined.bin
# add_custom_command(TARGET app POST_BUILD
#   COMMAND ${Python_EXECUTABLE} ${UF2CONV_PY} --carray -o ${CMAKE_CURRENT_LIST_DIR}/apps/self_update/main/bootloader_bin.c ${CMAKE_BINARY_DIR}/tinyuf2.bin
#   )

# OLD SHIT

# # Must be set before including IDF project.cmake
# set(EXTRA_COMPONENT_DIRS ${TOP}/src ${CMAKE_CURRENT_LIST_DIR}/boards)
# set(SDKCONFIG_DEFAULTS ${CMAKE_CURRENT_LIST_DIR}/sdkconfig.defaults ${CMAKE_CURRENT_LIST_DIR}/boards/${BOARD}/sdkconfig)
# set(SDKCONFIG ${CMAKE_BINARY_DIR}/sdkconfig)

# include($ENV{IDF_PATH}/tools/cmake/project.cmake)

# execute_process(COMMAND git describe --dirty --always --tags
#                 OUTPUT_VARIABLE GIT_VERSION)
# string(STRIP ${GIT_VERSION} GIT_VERSION)

# execute_process(COMMAND bash "-c" "git submodule status ${TOP}/lib/tinyusb | cut -d\" \" -f3,4 | paste -s -d\" \" -"
#                 OUTPUT_VARIABLE GIT_SUBMODULE_VERSIONS)

# string(REPLACE ../ "" GIT_SUBMODULE_VERSIONS ${GIT_SUBMODULE_VERSIONS})
# string(REPLACE lib/ "" GIT_SUBMODULE_VERSIONS ${GIT_SUBMODULE_VERSIONS})
# string(STRIP ${GIT_SUBMODULE_VERSIONS} GIT_SUBMODULE_VERSIONS)

# add_compile_definitions(UF2_VERSION_BASE="${GIT_VERSION}")
# add_compile_definitions(UF2_VERSION="${GIT_VERSION} - ${GIT_SUBMODULE_VERSIONS}")

# cmake_print_variables(GIT_VERSION GIT_SUBMODULE_VERSIONS)

# project(tinyuf2)



# # -------------------------------------------------------------
# # Post build: update arduino-esp32 bootloader for debug purpose
# # -------------------------------------------------------------
# if (0)
#   set(ARDUINO_VARIANT_DIR $ENV{HOME}/code/arduino-esp32/variants/${BOARD})
#   #set(ARDUINO_VARIANT_DIR $ENV{HOME}/code/arduino-esp32/variants/adafruit_feather_esp32s3_nopsram)

#   add_custom_command(TARGET bootloader POST_BUILD
#     COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_BINARY_DIR}/bootloader/bootloader.bin ${ARDUINO_VARIANT_DIR}/bootloader-tinyuf2.bin
#     )

#   add_custom_command(TARGET app POST_BUILD
#     COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_BINARY_DIR}/tinyuf2.bin ${ARDUINO_VARIANT_DIR}/tinyuf2.bin
#     )
# endif ()
