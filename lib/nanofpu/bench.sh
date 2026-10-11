#!/bin/bash

# yosys -p " read_verilog fmul.v ; chparam -set FOO=4 ; synth_ice40 " | tail -n 30
rm -rf sizing
mkdir -p sizing

TL=30
KEEP=`expr ${TL} - 3`

# nanofpu sizing in fieldable configs
echo -n "Sizing cores: ecp5_full, "
yosys -p " read_verilog sizing_ecp5_full.v ; synth_ecp5 " | tail -n 45 | head -n 40 > sizing/nanofpu_ecp5_full.txt
echo -n "ecp5_fmac, "
yosys -p " read_verilog sizing_ecp5_fmac.v ; synth_ecp5 " | tail -n 45 | head -n 40 > sizing/nanofpu_ecp5_fmac.txt
echo -n "ice40_full, "
yosys -p " read_verilog sizing_ice40_full.v ; synth_ice40 " | tail -n 45 | head -n 40 > sizing/nanofpu_ice40_full.txt
echo "ice40_fmac"
yosys -p " read_verilog sizing_ice40_fmac.v ; synth_ice40 " | tail -n 45 | head -n 40 > sizing/nanofpu_ice40_fmac.txt

make clean
make vecgen test_nanofpu.pass
grep -v Running *log > lt1k_timing.txt
make clean

for arch in ice40 ecp5 gowin; do

	# iaddsub
	echo "intaddsub ${arch}"
	yosys -p " read_verilog intaddsub.v ; synth_${arch} " | tail -n ${TL} | head -n ${KEEP} > sizing/${arch}_intaddsub.log	

	# fpmul16
	for dsp in 0 1; do
		echo "fpmul16 ${arch} dsp=${dsp}"
		yosys -p " read_verilog fpmul16.v ; chparam -set DSP_MULT ${dsp} ; synth_${arch} " | tail -n ${TL} | head -n ${KEEP} > sizing/${arch}_fpmul16_dsp${dsp}.log
	done

	# faddsub
	for bigstep in 0 1; do
		for barrel in 0 1; do
			for twostage in 0 1; do
				echo "faddsub ${arch} barrel=${barrel} twostage=${twostage} bigstep=${bigstep}"
				yosys -p " read_verilog faddsub.v ; chparam -set USE_BIG_STEP ${bigstep} ; chparam -set USE_BARREL ${barrel} ; chparam -set USE_TWO_STAGE_CMP ${twostage} ; synth_${arch} " | tail -n ${TL} | head -n ${KEEP} > sizing/${arch}_faddsub_bar${barrel}_cmp${twostage}_bigstep${bigstep}.log
			done
		done
	done
	
	# fcmp
	echo "fcmp ${arch}"
	yosys -p " read_verilog fcmp.v ; synth_${arch} " | tail -n ${TL} | head -n ${KEEP} > sizing/${arch}_fcmp.log

	# fdiv
	for twobit in 0 1; do
		for twostage in 0 1; do
			for barrel in 0 1; do
				echo "fdiv ${arch} twobit=${twobit} barrel=${barrel} twostage=${twostage}"
				yosys -p " read_verilog fdiv.v ; chparam -set USE_2BIT_DIV ${twobit} ; chparam -set USE_TWO_STAGE_CMP ${twostage} ; chparam -set USE_BARREL ${barrel} ; synth_${arch} -top fdiv " | tail -n ${TL} | head -n ${KEEP} > sizing/${arch}_fdiv_2bit${twobit}_barrel${barrel}_cmp${twostage}.log
			done
		done
	done

	#fldi
	for bigshift in 0 1; do
		echo "fldi ${arch} bigshift=${bigshift}"
		yosys -p " read_verilog fldi.v ; chparam -set USE_BIG_SHIFT ${bigshift} ; synth_${arch} " | tail -n ${TL} | head -n ${KEEP} > sizing/${arch}_fldi_shift${bigshift}.log
	done

	#fmul
	for twostage in 0 1; do
		for dsp in 0 1 2 3; do
			echo "fmul ${arch} dsp=${dsp} twostage=${twostage}"
			yosys -p " read_verilog fmul.v ; chparam -set USE_TWO_STAGE_CMP ${twostage} ; chparam -set USE_MULT ${dsp} ; synth_${arch} " | tail -n ${TL} | head -n ${KEEP} > sizing/${arch}_fmul_dsp${dsp}_cmp${twostage}.log
		done
	done

	#fsqrt
	for stages in 0 1 2; do
		echo "fsqrt ${arch} stages=${stages}"
		yosys -p " read_verilog fsqrt.v ; chparam -set STAGES ${stages} ; synth_${arch} " | tail -n ${TL} | head -n ${KEEP} > sizing/${arch}_fsqrt_stages${stages}.log
	done
	
	#fsti
	for barrel in 0 1; do
		echo "fsti ${arch} barrel=${barrel}"
		yosys -p " read_verilog fsti.v ; chparam -set USE_BARREL ${barrel} ; synth_${arch} " | tail -n ${TL} | head -n ${KEEP} > sizing/${arch}_fsti_barrel${barrel}.log
	done
	
done
