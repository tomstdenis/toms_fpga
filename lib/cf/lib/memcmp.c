int memcmp(unsigned char *a, unsigned char *b, unsigned len)
{
	while (len--) {
		if (*a++ ^ *b++) { return 1; }
	}
	return 0;
}
