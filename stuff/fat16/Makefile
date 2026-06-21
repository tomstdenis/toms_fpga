demo: demo.c fat16.c fat16.h populate_fs

	gcc demo.c fat16.c -o demo

test.fs:
	rm -f test.fs
	truncate --size 32M test.fs
	mkfs.fat -F 16 test.fs

.PHONY: populate_fs
populate_fs: test.fs
	@echo "Creating temporary mount point..."
	mkdir -p mnt_test
	
	@echo "Mounting test.fs..."
	sudo mount -o loop,uid=$$(id -u),gid=$$(id -g) test.fs mnt_test
	
	@echo "Creating file in root directory..."
	echo "root file content" | sudo echo "root file" >  mnt_test/ROOT.TXT 
	dd if=/dev/urandom ibs=8192 count=1 of=mnt_test/RND.BIN
	
	@echo "Creating directory and a file inside it..."
	sudo mkdir -p mnt_test/SUBDIR
	echo "sub directory file content" | sudo tee mnt_test/SUBDIR/SUBFILE.TXT > /dev/null
	
	ls -lR mnt_test
	
	@echo "Unmounting test.fs..."
	sudo umount mnt_test
	rmdir mnt_test
	@echo "Done! test.fs is populated and unmounted."	

.PHONY: clean
clean:
	rm -f demo test.fs
