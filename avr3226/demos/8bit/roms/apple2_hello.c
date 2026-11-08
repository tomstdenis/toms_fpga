/*
** Fancy hello world program using cc65.
**
** Ullrich von Bassewitz (ullrich@von-bassewitz.de)
**
*/
/*****************************************************************************/
/*                                   Code                                    */
/*****************************************************************************/

void main (void)
{
	volatile unsigned char *p = (unsigned char*)0x400;
	unsigned x;
	for (x = 0; x < 0x100; x++) {
		*p++ = x;
	}
	for (;;);
}
