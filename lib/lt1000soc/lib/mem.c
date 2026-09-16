#include "lt1000.h"

extern uint32_t __tcm_code_start, __tcm_code_end, __tcm_code_load_start;

void load_tcm_code(void)
{
	uint32_t size = (uint32_t)&__tcm_code_end - (uint32_t)&__tcm_code_start;
    if (size) memcpy((void*)(intptr_t)TCM_ADDR, &__tcm_code_load_start, size);
}
