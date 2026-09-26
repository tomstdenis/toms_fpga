#include "lt1000.h"

static uint32_t chksum(const uint8_t *data, uint32_t len)
{
	uint32_t r;
	
	r = 0x4C54316B; // LT1k
	while (len--) {
		r += *data++;
		r = (r << 7) | (r >> 25);
	}
	return r;
}

static void strcopy(char *dst, char *src, int len)
{
	while (*src && len > 2) {
		*dst++ = *src++;
		--len;
	}
	*dst++ = 0;
}

void lt1000_env_init(struct lt1000_chk_env *env)
{
	memset(env, 0, sizeof *env);
	env->chksum = chksum((uint8_t *)env, 4092);
}

void lt1000_env_update(struct lt1000_chk_env *env, uint8_t *cwd, uint8_t *comm, uint8_t *cmdline, uint8_t *envstr)
{
	if (cwd) {
		memset(env->env.cwd, 0, sizeof(env->env.cwd));
		strcopy(env->env.cwd, cwd, sizeof(env->env.cwd));
	}
	if (comm) {
		memset(env->env.comm, 0, sizeof(env->env.comm));
		strcopy(env->env.comm, comm, sizeof(env->env.comm));
	}
	if (cmdline) {
		memset(env->env.cmdline, 0, sizeof(env->env.cmdline));
		strcopy(env->env.cmdline, cmdline, sizeof(env->env.cmdline));
	}
	if (envstr) {
		memset(env->env.envstr, 0, sizeof(env->env.envstr));
		strcopy(env->env.envstr, envstr, sizeof(env->env.envstr));
	}

	env->chksum = chksum((uint8_t *)env, 4092);
}

int lt1000_env_validate(struct lt1000_chk_env *env)
{
	return (env->chksum == chksum((uint8_t *)env, 4092)) ? 0 : -1;
}

