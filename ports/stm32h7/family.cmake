cmake_minimum_required(VERSION 3.17)

set (LIB_DIR ${CMAKE_CURRENT_LIST_DIR}/../../lib)

# Set paths for STM32 HAL and CMSIS
set(ST_HAL_DRIVER ${LIB_DIR}/mcu/st/stm32h7xx_hal_driver)
set(ST_CMSIS ${LIB_DIR}/mcu/st/cmsis_device_h7)
set(CMSIS_5 ${LIB_DIR}/CMSIS_5)

# Set compiler flags
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -mthumb -mabi=aapcs -mcpu=cortex-m7 -mfloat-abi=hard -mfpu=fpv5-d16 -DCFG_TUSB_MCU=OPT_MCU_STM32H7")

# Enable LTO if requested
if(DEFINED LTO_ON AND LTO_ON)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -flto")
endif()

# Suppress warnings from the vendor MCU driver
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wno-error=cast-align -Wno-error=unused-parameter -Wno-error=unused-but-set-variable -Wno-error=unused-function")

# Define source files
set(PORT_SOURCES
    ${ST_CMSIS}/Source/Templates/system_stm32h7xx.c
    ${ST_HAL_DRIVER}/Src/stm32h7xx_hal.c
    ${ST_HAL_DRIVER}/Src/stm32h7xx_hal_cortex.c
    ${ST_HAL_DRIVER}/Src/stm32h7xx_hal_rcc.c
    ${ST_HAL_DRIVER}/Src/stm32h7xx_hal_rcc_ex.c
    ${ST_HAL_DRIVER}/Src/stm32h7xx_hal_gpio.c
    ${ST_HAL_DRIVER}/Src/stm32h7xx_hal_flash.c
    ${ST_HAL_DRIVER}/Src/stm32h7xx_hal_flash_ex.c
    ${ST_HAL_DRIVER}/Src/stm32h7xx_hal_uart.c
    ${ST_HAL_DRIVER}/Src/stm32h7xx_hal_spi.c
    ${ST_HAL_DRIVER}/Src/stm32h7xx_hal_pwr.c
    ${ST_HAL_DRIVER}/Src/stm32h7xx_hal_qspi.c
    ${ST_HAL_DRIVER}/Src/stm32h7xx_hal_mdma.c
    ${ST_HAL_DRIVER}/Src/stm32h7xx_hal_pwr_ex.c
    ${CMAKE_CURRENT_LIST_DIR}/components/st7735/fonts.c
)

# Additional sources based on configuration
if(DEFINED SPI_FLASH AND SPI_FLASH STREQUAL "W25Qx_SPI")
    list(APPEND PORT_SOURCES ${CMAKE_CURRENT_LIST_DIR}/components/w25qxx/w25qxx.c)
endif()

if(DEFINED QSPI_FLASH AND QSPI_FLASH STREQUAL "W25Qx_QSPI")
    list(APPEND PORT_SOURCES ${CMAKE_CURRENT_LIST_DIR}/components/w25qxx/w25qxx_qspi.c)
endif()

if(DEFINED DISPLAY_DRV AND DISPLAY_DRV STREQUAL "ST7735")
    list(APPEND PORT_SOURCES ${CMAKE_CURRENT_LIST_DIR}/components/st7735/st7735.c)
endif()

if(NOT BUILD_NO_TINYUSB)
    list(APPEND PORT_SOURCES ${LIB_DIR}/tinyusb/src/portable/synopsys/dwc2/dcd_dwc2.c)
endif()

# Include directories
include_directories(
    ${CMAKE_SOURCE_DIR}/${BOARD_PATH}
    ${CMSIS_5}/CMSIS/Core/Include
    ${CMAKE_SOURCE_DIR}/components/st7735
    ${CMAKE_SOURCE_DIR}/components/w25qxx
    ${CMAKE_SOURCE_DIR}/${PORT_DIR}
    ${CMAKE_SOURCE_DIR}/${BOARD_DIR}
    ${ST_CMSIS}/Include
    ${ST_HAL_DRIVER}/Inc
)
