#!/bin/bash

find_fmax() {
    local LOW=33
    local HIGH=200
    local MID=116

    echo "Profiling core: $1" >&2

    FMAX=""
    while [ "${LOW}" -lt "${HIGH}" ]; do
        local SUCCESS=0

        echo "   Attempting Fmax ${MID}..." >&2 
        
        # Retry loop: attempt the build up to 3 times
        for attempt in {1..3}; do
            make -C impl FREQ=${MID} CPU="$1" clean toy_cpu.bit >/dev/null 2>/dev/null
            if [ $? -eq 0 ]; then
                SUCCESS=1
                break # Succeeded! Skip remaining retries
            fi
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
echo "Fmax"  >> run.log

# now run each core against each demo
for core in evos/*/cpu.v; do
    echo "Testing core: ${core}..." >&2
    echo -n "${core},"  >> run.log
    for demo in data/*.asm; do
        make -C sim clean test_cpu HEX=${demo}.hex STATE=${demo}.state CPU=../${core}
        p=`grep PASSED sim/test_cpu.log`
        if [ $? -eq 0 ]; then
            cycles=`echo ${p} | awk '{print $3}'`
            echo -n "${cycles},"  >> run.log
        else
            echo -n "failed,"  >> run.log
        fi
    done
    FMAX=$(find_fmax "../evos/0/cpu.v")
    echo "${FMAX} MHz" >> run.log
done

echo
echo
echo
cat run.log