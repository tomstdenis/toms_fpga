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
	volatile char *p = 0x400;
	*p++ = 'A';
	*p++ = 'B';
	*p++ = 'C';
	for (;;);
}
