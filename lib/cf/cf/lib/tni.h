#ifndef TNI_H_
#define TNI_H_

#define TNI    FCB		// asm prefix 

#define CPUID  $ED		// [15:8] = TOP version, [7:0] = CF version
#define RDTSC  $EE		// A = cycle counter[15:0]
#define TAR0   $EF		// R0 = A
#define TAR1   $F0		// R1 = A
#define TR0A   $F1		// A = R0
#define TR1A   $F2		// A = R1
#define SWAPR0 $F3		// swap A and R0
#define SWAPR1 $F4		// swap A and R1
#define DECR0A $F5		// dec R0, A = R0
#define DECR1A $F6		// dec R1, A = R1
#define ADAR0  $F7		// R0 = R0 + A
#define ADAR1  $F8		// R1 = R1 + A
#define INCR0I $F9		// inc R0, INDEX = R0
#define INCR1I $FA		// inc R1, INDEX = R1

#endif
