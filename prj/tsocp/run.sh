#!/bin/bash

find_fmax() {
    local LOW=33
    local HIGH=200
    local MID=116

    echo "Profiling core: $1" >&2

    FMAX=""
    rm -f pnr.log tmppnr.log
    while [ "${LOW}" -lt "${HIGH}" ]; do
        local SUCCESS=0

        echo "   Attempting Fmax ${MID}..." >&2 
        
        # Retry loop: attempt the build up to 3 times
        for attempt in {1..5}; do
            make -C impl FREQ=${MID} CPU="$1" clean toy_cpu.bit 2>tmppnr.log >/dev/null
            if [ $? -eq 0 ]; then
                SUCCESS=1
                mv -f tmppnr.log  pnr.log
                break # Succeeded! Skip remaining retries
            fi
            rm -f tmppnr.log
            #echo "Attempt $attempt failed for FREQ=${MID}. Retrying..." >&2
        done
        
        if [ "${SUCCESS}" -eq 0 ]; then
            # Failed all 3 times: search lower half
            HIGH=${MID}
        else
            # Succeeded: search upper half
            FMAX=${MID}
            LOW=$((MID + 1))
        fi
        
        MID=$(( (LOW + HIGH) / 2 ))
    done
    
    echo "${FMAX}"
}

make clean

# build all demos
rm -f run.log
echo -n "core," >> run.log
for demo in data/*.asm; do
    bn=`basename ${demo}`
    echo -n "${bn},"  >> run.log
    echo "assembling ${demo}..." >&2
    python3 tools/asm.py "${demo}"
    echo "sw simulating ${demo}..." >&2
    python3 tools/sim.py "${demo}"
done
echo "Fmax,FF,COMB (LUT4),RAMW"  >> run.log

# now run each core against each demo
if [ "$1" == "" ]; then
    CORES="evos/*/cpu.v"
else
    CORES="$1"
fi

for core in ${CORES}; do
    echo "Testing core: ${core}..." >&2
    echo -n "${core},"  >> run.log
    FAIL=""
    for demo in data/*.asm; do
        make -C sim clean test_cpu HEX=${demo}.hex STATE=${demo}.state CPU=../${core}
        p=`grep PASSED sim/test_cpu.log`
        if [ $? -eq 0 ]; then
            cycles=`echo ${p} | awk '{print $3}'`
            echo -n "${cycles},"  >> run.log
        else
            echo -n "failed,"  >> run.log
            FAIL="1"
        fi
    done
    if [ "${FAIL}" != "1" ]; then
        FMAX=$(find_fmax "../${core}")
        echo -n "${FMAX} MHz," >> run.log
        FF=`grep "^Info:" pnr.log | grep TRELLIS_FF | grep "\/" | tr "/" " " | awk '{print $3;}'`
        COMB=`grep "^Info:" pnr.log | grep TRELLIS_COMB | grep "\/" | tr "/" " " | awk '{print $3;}'`
        RAMW=`grep "^Info:" pnr.log | grep TRELLIS_RAMW | grep "\/" | tr "/" " " | awk '{print $3;}'`
        echo "${FF},${COMB},${RAMW}" >> run.log
    else
        echo "skipped" >> run.log
    fi
done

echo
echo
echo
cat run.log