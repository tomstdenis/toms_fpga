#ifdef APPLE_PLATFORM_BASE

uint8_t read_platform(uint16_t addr)
{
	// dummy data now...
	return 0xFF;
}

void write_platform(uint16_t addr, uint8_t val)
{
	if (addr == 0) { // only respond to one byte address
		switch (val) {
			case 0x00:  // trigger a reset
				cpu_reset();
				break;
			case 0x01:  // jump to apple2 monitor
#ifdef  BOARD_APPLE2
				cpu_jump(0xFF69);
#elif defined(BOARD_APPLE1)
				cpu_jump(0xFF00);
#endif
				break;
			case 0x02: // save state
				platform_save();
				break;
			case 0x03: // load state
				platform_load();
				break;
			case 0x04: // save and jump to monitor
				platform_save();
				write_platform(0, 0x01);
				break;
		}
	}
}

void platform_save(void)
{
	uint16_t x, y, z;
	uint8_t *tmp;

	// grab the cache (this also flushes it) memory as a scratch pad
	tmp = cache_reuse();

	// now cpu and other peripherals, they chain input/output so sizing can be flexible as long as the total is less than 4K
	x = 0;
	x = cpu_save(x);
	x = display_save(x);

	// TODO: save to SRAM to EEPROM entirely.

	// reinit the cache
	cache_init();
}

void platform_load(void)
{
	uint16_t x, y, z;
	uint8_t *tmp;

	// grab the cache (this also flushes it) memory as a scratch pad
	tmp = cache_reuse();

	// TODO: read EEPROM into SRAM

	// now cpu
	x = 0;
	x = cpu_load(x);
	x = display_load(x);

	// reinit the cache
	cache_init();
}

#endif
