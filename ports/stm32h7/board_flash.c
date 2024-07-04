#include "board_api.h"
#include "stm32h7xx_hal.h"

#ifdef W25Qx_SPI
#include "components/w25qxx/w25qxx.h"
#endif // W25Qx_SPI

#ifdef W25Qx_QSPI
#include "components/w25qxx/w25qxx_qspi.h"
#endif // W25Qx_QSPI

#if BOARD_QSPI_FLASH_EN
QSPI_HandleTypeDef _qspi_flash;
#endif // BOARD_QSPI_FLASH_EN

#if BOARD_SPI_FLASH_EN
SPI_HandleTypeDef _spi_flash;
#endif // BOARD_SPI_FLASH_EN

//--------------------------------------------------------------------+
// Board Memory Callouts
//--------------------------------------------------------------------+
#ifdef W25Qx_SPI
uint32_t W25Qx_SPI_Transmit(uint8_t *buffer, uint16_t len, uint32_t timeout)
{
  return (uint32_t)HAL_SPI_Transmit(&_spi_flash, buffer, len, timeout);
}

uint32_t W25Qx_SPI_Receive(uint8_t *buffer, uint16_t len, uint32_t timeout)
{
  return (uint32_t)HAL_SPI_Receive(&_spi_flash, buffer, len, timeout);
}

void W25Qx_Delay(uint32_t ms)
{
  HAL_Delay(ms);
}

uint32_t W25Qx_GetTick(void)
{
  return HAL_GetTick();
}
#endif // W25Qx_SPI

//--------------------------------------------------------------------+
// Flash LL for tinyuf2
//--------------------------------------------------------------------+

extern volatile uint32_t _board_tmp_boot_addr[];
extern volatile uint32_t _board_tmp_boot_magic[];

#define TMP_BOOT_ADDR _board_tmp_boot_addr[0]
#define TMP_BOOT_MAGIC _board_tmp_boot_magic[0]

uint32_t board_get_app_start_address(void)
{
  if (TMP_BOOT_MAGIC == 0xDEADBEEFU)
  {
    return TMP_BOOT_ADDR;
  }
  else
  {
#if BOARD_QSPI_FLASH_EN
    return BOARD_QSPI_APP_ADDR;
#else
    return BOARD_PFLASH_APP_ADDR;
#endif
  }
}

void board_save_app_start_address(uint32_t addr)
{
  TMP_BOOT_MAGIC = 0xDEADBEEFU;
  TMP_BOOT_ADDR = addr;
}

void board_clear_temp_boot_addr(void)
{
  TMP_BOOT_MAGIC = 0x00U;
  TMP_BOOT_ADDR = 0x00U;
}

void board_flash_early_init(void)
{
#if BOARD_QSPI_FLASH_EN
  // QSPI is initialized early to check for executable code
  qspi_flash_init(&_qspi_flash);
  // Initialize QSPI driver
  w25qxx_Init();
  // SPI -> QPI
  w25qxx_EnterQPI();
#endif // BOARD_QSPI_FLASH_EN
}

void board_flash_init(void)
{
#if BOARD_SPI_FLASH_EN
  // Initialize SPI peripheral
  spi_flash_init(&_spi_flash);
  // Initialize SPI drivers
  W25Qx_Init();
#endif // BOARD_SPI_FLASH_EN
}

void board_flash_deinit(void)
{
#if BOARD_QSPI_FLASH_EN
  // Enable Memory Mapped Mode
  // QSPI flash will be available at 0x90000000U (readonly)
  w25qxx_Startup(w25qxx_DTRMode);
#endif // BOARD_QSPI_FLASH_EN
}

uint32_t board_flash_size(void)
{
  // TODO: how do we handle more than 1 target here?
  return 8 * 1024 * 1024;
}

void board_flash_flush(void)
{
  // TODO: do we need to implement this if there no caching involved?
  // maybe flush cached RAM here?
}

void board_flash_read(uint32_t addr, void *data, uint32_t len)
{
  TUF2_LOG1("Reading %lu byte(s) from 0x%08lx\r\n", len, addr);
#if BOARD_QSPI_FLASH_EN
  // addr += QSPI_BASE_ADDR;
  if (IS_QSPI_ADDR(addr))
  {
    (void)W25qxx_Read(data, addr - QSPI_BASE_ADDR, len);
    return;
  }
#endif

#if BOARD_AXISRAM_EN
  if (IS_AXISRAM_ADDR(addr) && IS_AXISRAM_ADDR(addr + len - 1))
  {
    memcpy(data, (void *)addr, len);
    return;
  }
#endif // BOARD_AXISRAM_EN

  if (IS_PFLASH_ADDR(addr))
  {
    memcpy(data, (void *)addr, len);
    return;
  }

  {
    // Invalid address read
    __asm("bkpt #3");
  }
}

static void write_internal_flash(uint32_t addr, const void *data, uint32_t len);

bool board_flash_write(uint32_t addr, void const *data, uint32_t len)
{
  TUF2_LOG1("Programming %lu byte(s) at 0x%08lx\r\n", len, addr);

  // For external flash, W25Qx
  // TODO: these should be configurable parameters
  // Page size = 256 bytes
  // Sector size = 4K bytes
#if (BOARD_SPI_FLASH_EN == 1U)
  if (IS_SPI_ADDR(addr) && IS_SPI_ADDR(addr + len - 1))
  {
    W25Qx_Write((uint8_t *)data, (addr - SPI_BASE_ADDR), len);
    return true;
  }
#endif

#if (BOARD_QSPI_FLASH_EN == 1)
  if (IS_QSPI_ADDR(addr) && IS_QSPI_ADDR(addr + len - 1))
  {
    // SET_BOOT_ADDR(BOARD_AXISRAM_APP_ADDR);
    // handles erasing internally
    if (W25qxx_Write((uint8_t *)data, (addr - QSPI_BASE_ADDR), len) != w25qxx_OK)
    {
      __asm("bkpt #9");
    }
    return true;
  }
#endif

#if BOARD_AXISRAM_EN
  if (IS_AXISRAM_ADDR(addr) && IS_AXISRAM_ADDR(addr + len - 1))
  {
    // This memory is cached, DCache is cleaned in dfu_complete
    SET_BOOT_ADDR(BOARD_AXISRAM_APP_ADDR);
    memcpy((void *)addr, data, len);
    return true;
  }
#endif // BOARD_AXISRAM_EN

  // This is not a good idea for the h750 port because
  // - There is only one flash bank available
  // - There is only one sector available
  // - It will also need a config section in flash to store the boot address
  if (IS_PFLASH_ADDR(addr) && IS_PFLASH_ADDR(addr + len - 1))
  {
    write_internal_flash(addr, data, len);
    return true;
  }

  // Invalid address write
  __asm("bkpt #4");
  return false;
}

#define BOARD_PFLASH_APP_SECTOR (BOARD_PFLASH_APP_ADDR - FLASH_BANK1_BASE) / FLASH_SECTOR_SIZE
#define BOARD_PFLASH_APP_LENGTH_SECTORS FLASH_SECTOR_TOTAL - BOARD_PFLASH_APP_SECTOR
#define BOARD_PFLASH_APP_BANK FLASH_BANK_1
#define FLASH_TIMEOUT_VALUE 50000U /* 50 s */

void board_flash_erase_app(void)
{
  board_flash_init();

#if BOARD_QSPI_FLASH_EN
  TUF2_LOG1("Erasing QSPI Flash\r\n");
  // Erase QSPI Flash
  (void)W25qxx_EraseChip();
#elif BOARD_SPI_FLASH_EN
  TUF2_LOG1("Erasing SPI Flash\r\n");
  // Erase QSPI Flash
  (void)W25Qx_Erase_Chip();
#else

#if (BOARD_PFLASH_APP_ADDR % FLASH_SECTOR_SIZE != 0)
#error "PFLASH_APP_ADDR must be a multiple of FLASH_SECTOR_SIZE"
#endif

  if (HAL_FLASH_Unlock() != HAL_OK)
  {
    __asm("bkpt #75");
  }
  FLASH_EraseInitTypeDef EraseInitStruct;
  EraseInitStruct.TypeErase = FLASH_TYPEERASE_SECTORS;
  EraseInitStruct.VoltageRange = 0;
  EraseInitStruct.Sector = BOARD_PFLASH_APP_SECTOR;
  EraseInitStruct.NbSectors = BOARD_PFLASH_APP_LENGTH_SECTORS;
  EraseInitStruct.Banks = BOARD_PFLASH_APP_BANK;
  uint32_t error = 0;

  if (HAL_FLASHEx_Erase(&EraseInitStruct, &error) != HAL_OK)
  {
    __asm("bkpt #76");
  }

  if (HAL_FLASH_Lock() != HAL_OK)
  {
    __asm("bkpt #77");
  }
#endif

  // TODO: Implement PFLASH erase for non-tinyuf2 sectors
  board_reset();
}

static uint32_t get_banks(uint32_t addr)
{
#if !defined(DUAL_BANK)
  return IS_FLASH_PROGRAM_ADDRESS_BANK1(addr) ? FLASH_BANK_1 : 0;
#else
  return IS_FLASH_PROGRAM_ADDRESS_BANK1(addr) ? FLASH_BANK_1 : IS_FLASH_PROGRAM_ADDRESS_BANK2(addr) ? FLASH_BANK_2
                                                                                                    : 0;
#endif
}

static int get_sector_number(uint32_t addr)
{
  uint32_t bank = get_banks(addr);
  if (bank == FLASH_BANK_1)
  {
    return (addr - FLASH_BANK1_BASE) / FLASH_SECTOR_SIZE;
  }
#if defined(DUAL_BANK)
  else if (bank == FLASH_BANK_2)
  {
    return (addr - FLASH_BANK2_BASE) / FLASH_SECTOR_SIZE;
  }
#endif
  return -1;
}

static uint32_t get_sector_address(uint32_t bank, uint32_t sector)
{
  return (bank == 0 || bank > FLASH_BANK_2) ? 0 : ((bank == FLASH_BANK_1 ? FLASH_BANK1_BASE : FLASH_BANK2_BASE) + sector * FLASH_SECTOR_SIZE);
}

static void write_internal_flash(uint32_t addr, const void *data, uint32_t len)
{
  const int sector = get_sector_number(addr);
  const uint32_t bank = get_banks(addr);

  if (addr % sizeof(uint32_t) != 0 ||
      sector < 0 ||
      bank == 0 ||
      sector != get_sector_number(addr + len - 1) ||
      bank != get_banks(addr + len - 1))
  {
    __asm("bkpt #70");
    // each write MUST be within a single sector and a single bank
  }

  // we'll need this to copy data
  const uint32_t sector_base_address = get_sector_address(bank, sector);

  // Save the whole sector into the buffer
  uint32_t buffer[FLASH_SECTOR_SIZE / sizeof(uint32_t)];
  FLASH_WaitForLastOperation((uint32_t)FLASH_TIMEOUT_VALUE, bank);
  board_flash_read(sector_base_address, buffer, FLASH_SECTOR_SIZE);
  FLASH_WaitForLastOperation((uint32_t)FLASH_TIMEOUT_VALUE, bank);

  if (HAL_FLASH_Unlock() != HAL_OK)
  {
    __asm("bkpt #71");
  }

  // Erase the sector
  {
    HAL_FLASH_OB_Unlock();
    FLASH_OBProgramInitTypeDef flashInit;
    HAL_FLASHEx_OBGetConfig(&flashInit);
    flashInit.Banks = FLASH_BANK_BOTH;
    flashInit.RDPLevel = OB_RDP_LEVEL_0;
    flashInit.SecureAreaConfig = OB_SECURE_RDP_NOT_ERASE;
    HAL_FLASHEx_OBProgram(&flashInit);
    HAL_FLASH_OB_Lock();

    FLASH_EraseInitTypeDef EraseInitStruct;
    EraseInitStruct.TypeErase = FLASH_TYPEERASE_SECTORS;
    EraseInitStruct.VoltageRange = 0;
    EraseInitStruct.Sector = sector;
    EraseInitStruct.NbSectors = 1;
    EraseInitStruct.Banks = bank;
    uint32_t error = 0;

    if (HAL_FLASHEx_Erase(&EraseInitStruct, &error) != HAL_OK)
    {
      __asm("bkpt #72");
    }
  }

  uint32_t target_address = sector_base_address;
  uint32_t target_offset = addr - sector_base_address;

  // Replace the data in the buffer
  memcpy((void *)buffer + target_offset, data, len);

  uint32_t buffer_address = (uint32_t)(buffer);

  // Write the buffer back in 4x4 bytes, as is per FLASH_NB_32BITWORD_IN_FLASHWORD
  for (size_t i = 0; i < FLASH_SECTOR_SIZE / (sizeof(uint32_t) * FLASH_NB_32BITWORD_IN_FLASHWORD); i++)
  {
    const HAL_StatusTypeDef result = HAL_FLASH_Program(FLASH_TYPEPROGRAM_FLASHWORD,
                                                       target_address,
                                                       buffer_address);

    if (result != HAL_OK)
    {
      __asm("bkpt #73");
    }

    buffer_address += FLASH_NB_32BITWORD_IN_FLASHWORD * sizeof(uint32_t);
    target_address += FLASH_NB_32BITWORD_IN_FLASHWORD * sizeof(uint32_t);
  }

  if (HAL_FLASH_Lock() != HAL_OK)
  {
    __asm("bkpt #74");
  }
}
