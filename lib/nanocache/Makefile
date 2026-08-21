trace.hex: gen
	@./gen
	
gen: gen.c
	@gcc -g3 -Wall gen.c -o gen

.PHONY: clean
clean:
	@rm -f gen trace.hex
