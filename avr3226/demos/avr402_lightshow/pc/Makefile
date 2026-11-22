upload: upload.c
	gcc -O2 -Wall upload.c -o upload

.PHONY: demo
demo: upload
	./upload  /dev/ttyUSB1 16 test.r 0 1 50 2
	./upload  /dev/ttyUSB1 16 test.g 1 2 50 2
	./upload  /dev/ttyUSB1 16 test.b 2 3 50 2
	./upload  /dev/ttyUSB1 16 test.rgb 3 0 100 2

.PHONY: clean
clean:	
	rm -f upload
