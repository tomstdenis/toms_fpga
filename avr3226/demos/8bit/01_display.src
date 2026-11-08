void display_init(void)
{
#ifdef BOARD_APPLE2
	display_apple2_init();
#endif
}

void display_draw(void)
{
#ifdef BOARD_APPLE2
	display_apple2_draw();
#endif
}

uint16_t display_load(uint16_t offset)
{
#ifdef BOARD_APPLE2
	return display_apple2_load(offset);
#endif
	return offset;
}

uint16_t display_save(uint16_t offset)
{
#ifdef BOARD_APPLE2
	return display_apple2_save(offset);
#endif
	return offset;
}
