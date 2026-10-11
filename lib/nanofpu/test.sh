#!/bin/bash

rm timings/*

HANDLE_INVALID_OP=0
USE_FMUL_DSP=0
USE_FMUL_TWO_STAGE_CMP=0
USE_FDIV_BARREL=0
USE_FDIV_TWO_STAGE_CMP=0
USE_FDIV_2BIT_DIV=0
USE_FADDSUB_BARREL=0
USE_FADDSUB_BIG_STEP=0
USE_FADDSUB_TWO_STAGE_CMP=0
USE_FSTI_BARREL=0
USE_FLDI_BIG_STEP=0
USE_FSQRT_STAGES=0
USE_FPMUL16_DSP_MULT=0
NUM=0

test_cmd() {
    def="-D HANDLE_INVALID_OP=${HANDLE_INVALID_OP}"
    def="${def} -D USE_FMUL_DSP=${USE_FMUL_DSP}"
    def="${def} -D USE_FMUL_TWO_STAGE_CMP=${USE_FMUL_TWO_STAGE_CMP}"
    def="${def} -D USE_FDIV_BARREL=${USE_FDIV_BARREL}"
    def="${def} -D USE_FDIV_TWO_STAGE_CMP=${USE_FDIV_TWO_STAGE_CMP}"
    def="${def} -D USE_FDIV_2BIT_DIV=${USE_FDIV_2BIT_DIV}"
    def="${def} -D USE_FADDSUB_BARREL=${USE_FADDSUB_BARREL}"
    def="${def} -D USE_FADDSUB_TWO_STAGE_CMP=${USE_FADDSUB_TWO_STAGE_CMP}"
    def="${def} -D USE_FADDSUB_BIG_STEP=${USE_FADDSUB_BIG_STEP}"
    def="${def} -D USE_FSTI_BARREL=${USE_FSTI_BARREL}"
    def="${def} -D USE_FLDI_BIG_STEP=${USE_FLDI_BIG_STEP}"
    def="${def} -D USE_FSQRT_STAGES=${USE_FSQRT_STAGES}"
    def="${def} -D USE_FPMUL16_DSP_MULT=${USE_FPMUL16_DSP_MULT} -D EXTERNAL_PARAM -D NUM_OF_TESTS=100000"

    echo "Testing [${def}]..."
    make clean
    make vecgen
    ./vecgen any >/dev/null
    iverilog ${F} -D MODEL_SIM ${def} -o sim.vvp nanofpu_tb.v
    vvp sim.vvp -fst > test.log
    if [ $? != 0 ]; then
        cat test.log
        echo "Failed [${def}]..."
        exit 1
    fi
    echo "Defines:" > timings/test_${NUM}.log
    for d in ${def}; do
        if [ "${d}"  != "-D" ]; then
            echo "   ${d}" >> timings/test_${NUM}.log
        fi
    done
    grep -v "Running" test.log >> timings/test_${NUM}.log
    rm test.log
    NUM=`expr ${NUM} + 1`
}

make clean

for HANDLE_INVALID_OP in 0 1; do
    test_cmd
done

# so far these options have no overlap so the zero test case for most options is already
# tested above.  If any option does overlap make sure you iterate over all combinations as a n-tuple

for USE_FMUL_DSP in 1 2 3; do
    test_cmd
done
for USE_FMUL_TWO_STAGE_CMP in 1; do
    test_cmd
done
for USE_FDIV_BARREL in 1; do
    test_cmd
done
for USE_FDIV_TWO_STAGE_CMP in 1; do
    test_cmd
done
for USE_FDIV_2BIT_DIV in 1; do
    test_cmd
done
for USE_FADDSUB_BARREL in 1; do
    test_cmd
done
for USE_FADDSUB_TWO_STAGE_CMP in 1; do
    test_cmd
done
for USE_FADDSUB_BIG_STEP in 1; do
    test_cmd
done
for USE_FSTI_BARREL in 1; do
    test_cmd
done
for USE_FLDI_BIG_STEP in 1; do
    test_cmd
done
for USE_FSQRT_STAGES in 1 2; do
    test_cmd
done
for USE_FPMUL16_DSP_MULT in 1; do
    test_cmd
done
