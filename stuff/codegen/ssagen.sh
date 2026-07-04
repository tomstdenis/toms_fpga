#!/bin/bash

mkdir -p ssa
for f in samples/*.c; do
	b=`basename ${f} | sed -e 's/[.]c/.ll/'`
	clang -S -emit-llvm -Os  -ffreestanding -nostdlib $f -o ssa/${b}
done
