#ifndef LT1000_ENV_H
#define LT1000_ENV_H

#define MAXENVSTR 256

__attribute__((packed)) struct lt1000_env {
	uint8_t cwd[MAXENVSTR];						// current working directory
	uint8_t comm[MAXENVSTR];					// command name
	uint8_t cmdline[MAXENVSTR];					// command line
	uint8_t envstr[MAXENVSTR];					// environment variables
};

__attribute__((packed)) struct lt1000_chk_env  {
	struct lt1000_env env;
	uint8_t padding[4096 - 4 - sizeof(struct lt1000_env)];
	uint32_t chksum;
};

// create a blank valid environment
void lt1000_env_init(struct lt1000_chk_env *env);

// update a field (pass NULL to ignore)
void lt1000_env_update(struct lt1000_chk_env *env, uint8_t *cwd, uint8_t *comm, uint8_t *cmdline, uint8_t *envstr);

// validate the checksum, returns 0 on OK
int lt1000_env_validate(struct lt1000_chk_env *env);

#endif
