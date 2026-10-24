all: disk.img fat32_test

fat32_test: fat32_test.c ../fat32.c
	gcc -I../../inc -DHOSTPC fat32_test.c ../fat32.c -o fat32_test

disk.img:
	mkdir disk
	mkdir disk/LIB
	mkdir disk/INC
	cp -vf ../*.c disk/LIB
	cp -vf ../../inc/*.h disk/INC
	echo "hello tom" > disk/README.TXT
	truncate --size 128M disk.img
	mkfs.fat -F 32 disk.img
	mcopy -s -i disk.img disk/* ::/

.PHONY: clean
clean:
	rm -rf disk disk.img fat32_test
