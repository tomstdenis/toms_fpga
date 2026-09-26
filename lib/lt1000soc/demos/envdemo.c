#include "lt1000.h"

void main(void)
{
	printf("env valid: %d\r\n", lt1000_env_validate(ENV_ADDR));
	printf("cwd    : [%s]\n\r", ENV_ADDR->env.cwd);
	printf("comm   : [%s]\n\r", ENV_ADDR->env.comm);
	printf("cmdline: [%s]\n\r", ENV_ADDR->env.cmdline);
	printf("envstr : [%s]\n\r", ENV_ADDR->env.envstr);
}
