_flash_origin = DEFINED(RAMCODE) ? 0x24000000 : 0x08000000;
_flash_size = 128K;

_noinit_size = 12;
_noinit_origin = 0x20000000;

/* DTCM */
_ram_origin = _noinit_origin + _noinit_size;
_ram_size = 64K - _noinit_size;
/* is actually 128K, but the app won't start with this amount. */
/* possibly an issue with the SP being at the end? */

