#!/bin/bash

# yosys -p " read_verilog fmul.v ; chparam -set FOO=4 ; synth_ice40 " | tail -n 30
rm -rf sizing
mkdir -p sizing

TL=30

for arch in ice40 ecp5 gowin; do

	# faddsub
	for barrel in 0 1; do
		for twostage in 0 1; do
			echo "faddsub ${arch} barrel=${barrel} twostage=${twostage}"
			yosys -p " read_verilog faddsub.v ; chparam -set USE_BARREL ${barrel} ; chparam -set USE_TWO_STAGE_CMP ${twostage} ; synth_${arch} " | tail -n ${TL} > sizing/${arch}_faddsub_bar${barrel}_cmp${twostage}.log
		done
	done
	
	# fcmp
	echo "fcmp ${arch}"
	yosys -p " read_verilog fcmp.v ; synth_${arch} " | tail -n ${TL} > sizing/${arch}_fcmp.log

	# fdiv
	echo "fdiv ${arch}"
	yosys -p " read_verilog fdiv.v ; synth_${arch} " | tail -n ${TL} > sizing/${arch}_fdiv.log

	#fldi
	for bigshift in 0 1; do
		echo "fldi ${arch} bigshift=${bigshift}"
		yosys -p " read_verilog fldi.v ; chparam -set USE_BIG_SHIFT ${bigshift} ; synth_${arch} " | tail -n ${TL} > sizing/${arch}_fldi_shift${bigshift}.log
	done

	#fmul
	for dsp in 0 1 2 3; do
		echo "fmul ${arch} dsp=${dsp}"
		yosys -p " read_verilog fmul.v ; chparam -set USE_MULT ${dsp} ; synth_${arch} " | tail -n ${TL} > sizing/${arch}_fmul_dsp${dsp}.log
	done

	#fsqrt
	for stages in 0 1 2; do
		echo "fsqrt ${arch} stages=${stages}"
		yosys -p " read_verilog fsqrt.v ; chparam -set STAGES ${stages} ; synth_${arch} " | tail -n ${TL} > sizing/${arch}_fsqrt_stages${stages}.log
	done
	
	#fsti
	for barrel in 0 1; do
		echo "fsti ${arch} barrel=${barrel}"
		yosys -p " read_verilog fsti.v ; chparam -set USE_BARREL ${barrel} ; synth_${arch} " | tail -n ${TL} > sizing/${arch}_fsti_barrel${barrel}.log
	done
	
	# iadd
	echo "iadd ${arch}"
	yosys -p " read_verilog intaddsub.v ; synth_${arch} " | tail -n ${TL} > sizing/${arch}_iadd.log
	
done
