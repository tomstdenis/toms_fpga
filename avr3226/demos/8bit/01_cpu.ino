#ifdef HOSTPC
uint32_t cpu_cycles;
#else
uint16_t cpu_cycles;
#endif

void cpu_init()
{
	cpu_cycles = 0;
#ifdef CPU_6502
	init_6502();
#endif
#ifdef CPU_RISCV32IM
	init_riscv();
#endif
}

void cpu_step(uint16_t steps)
{
#ifdef CPU_6502
#ifdef TRACE
	trace_6502();
#endif
	step_6502(steps);
#endif
#ifdef CPU_RISCV32IM
#ifdef TRACE
	trace_riscv();
#endif
	step_riscv(steps);
#endif
}

void cpu_int(uint8_t sig)
{
#ifdef CPU_6502
	int_6502(sig);
#endif
#ifdef CPU_RISCV32IM
	int_riscv(sig);
#endif
}

void cpu_reset(void)
{
#ifdef CPU_6502
	reset_6502();
#endif
#ifdef CPU_RISCV32IM
	reset_riscv();
#endif
}

void cpu_jump(cache_addr_t addr)
{
#ifdef CPU_6502
	jump_6502(addr);
#endif
#ifdef CPU_RISCV32IM
	jump_riscv(addr);
#endif
}

uint16_t cpu_save(uint16_t offset)
{
#ifdef CPU_6502
	return save_6502(offset);
#endif
#ifdef CPU_RISCV32IM
	return save_riscv(offset);
#endif
}

uint16_t cpu_load(uint16_t offset)
{
#ifdef CPU_6502
	return load_6502(offset);
#endif
#ifdef CPU_RISCV32IM
	return load_riscv(offset);
#endif
}
