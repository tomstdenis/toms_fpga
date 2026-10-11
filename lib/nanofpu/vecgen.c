#define _GNU_SOURCE
#include <fenv.h>
#include "almostmath.c"

void print_float(char *name, uint32_t f)
{
	float *ff = (float *)&f;
	printf("%s (0x%08x, %e): sign=%u, exp=%u(0x%x), mant=%u(0x%x)\n", name, f, *ff, f >> 31, (f >> 23) & 0xFF, (f >> 23) & 0xFF, f & 0x7FFFFF, f & 0x7FFFFF);
}

int main(int argc, char **argv)
{
	FILE *vec;
	uint32_t opa, opb, res, opcode, x, *ufres;
	float *fa, *fb, fres, *fures;
	
	int command, op;
	
	fesetround(FE_TOWARDZERO);
	
	fa = (float *)&opa;
	fb = (float *)&opb;
	ufres = (uint32_t*)&fres;
	fures = (float *)&res;

#if 0	
	*fa = 4.0; print_float("4.0", opa); *fa = *fa * *fa; print_float("**2", opa); opa = myfsqrt(opa); print_float("sqrt(**2)", opa);
	*fa = 10.0; print_float("10.0", opa); *fa = *fa * *fa; print_float("**2", opa); opa = myfsqrt(opa); print_float("sqrt(**2)", opa);
	*fa = 0.25; print_float("0.25", opa); *fa = *fa * *fa; print_float("**2", opa); opa = myfsqrt(opa); print_float("sqrt(**2)", opa);
	return 0;
#endif

	if (argc == 1) {
		printf("%s: addsub | mul | div\n\r", argv[0]);
		return 0;
	}
	vec = fopen("fpu.hex", "w");
	
	if (!strcmp(argv[1], "addsub")) {
		command = 0;
	} else if (!strcmp(argv[1], "mul")) {
		command = 2;
	} else if (!strcmp(argv[1], "div")) {
		command = 3;
	} else if (!strcmp(argv[1], "fldi")) {
		command = 4;
	} else if (!strcmp(argv[1], "fsti")) {
		command = 5;
	} else if (!strcmp(argv[1], "fsqrt")) {
		command = 6;
	} else if (!strcmp(argv[1], "fcmp")) {
		command = 7;
	} else if (!strcmp(argv[1], "i8add")) {
		command = 8;
	} else if (!strcmp(argv[1], "i8sub")) {
		command = 9;
	} else if (!strcmp(argv[1], "i16add")) {
		command = 10;
	} else if (!strcmp(argv[1], "i16sub")) {
		command = 11;
	} else if (!strcmp(argv[1], "add32")) {
		command = 12;
	} else if (!strcmp(argv[1], "sub32")) {
		command = 13;
	} else if (!strcmp(argv[1], "cmp32")) {
		command = 14;
	} else if (!strcmp(argv[1], "fpmul")) {
		command = 15;
	} else if (!strcmp(argv[1], "any")) {
		command = 16;
	}
	
	for (x = 0; x < NUM_OF_TESTS; x++) {
		if (command != 16) {
			op = command;
		} else {
			op = x % 16;
		}		
		
		opa = rand_valid_float_bits();
		opb = rand_valid_float_bits();
		switch (op) {
			case 1:
			case 0: //addsub
				opcode = rand() & 1;
				res    = opcode ? myfsub(opa, opb) : myfadd(opa, opb);
				fres   = opcode ? *fa - *fb : *fa + *fb;
				break;
			case 2: //mul
				opcode = 2;
				res    = myfmul(opa, opb);
				fres   = *fa * *fb;
				break;
			case 3: //div
				opcode = 3;
				res    = myfdiv(opa, opb);
				fres   = *fa / *fb;
				break;
			case 4: //fldi
				opcode = 4;
				opb    = 0;
				opa    = (rand() << 15) ^ rand();
				res    = fldi(opa);
				fres   = (int32_t)opa;
				break;
			case 5: //fsti
				opcode = 5;
				opb    = 0;
				res    = fsti(opa);
				break;
			case 6: //fsqrt
				opcode = 6;
				opb    = 0;
				do {
					opa = rand_valid_float_bits();
					res    = myfsqrt(opa);
				} while (command == 7 && *fa <0.0);
				fres   = sqrtf(*fa);
				break;
			case 7: //cmp
				opcode = 7;
				res    = mycmp(opa, opb);
				break;
            case 8:
            case 9:
            case 10:
            case 11:
            case 12:
            case 13:
            case 14:
                opcode = op;
                res    = iaddsub(opa, opb, opcode - 8);
                break;
			case 15: //fpmul
				opcode = 15;
				res    = ((uint64_t)opa * opb) >> 16; 
				break;
		}
		
		if (opcode < 7 && opcode != 5 && *ufres != res) {
			printf("-------\nvector: opcode=%u output mismatch %x vs expt=%x\n", opcode, res, *ufres);
			printf("%e op %e == %e vs %e\n", *fa, *fb, *fures, fres);
			print_float("opa", opa);
			print_float("opb", opb);
			print_float("res", res);
			print_float("ufres", *ufres);
			printf("-------\n\n");
//			return -1;
		}
		
		fprintf(vec, "%02x%08x%08x%08x\n", opcode, res, opb, opa);
	}
	fclose(vec);
}
