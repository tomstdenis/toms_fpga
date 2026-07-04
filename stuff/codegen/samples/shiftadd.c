typedef unsigned short uint16_t;

uint16_t shiftadd(uint16_t a, uint16_t b, uint16_t c, uint16_t d)
{
	uint16_t r;
	r = 0;
	while (b) {
		if (b&1) r += a;
		b >>= 1;
		a <<= 1;
	}
	return (r + c) / d;
}
