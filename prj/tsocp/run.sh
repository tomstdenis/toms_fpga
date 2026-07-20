#!/bin/bash

find_fmax() {
    local LOW=33
    local HIGH=200
    local MID=116

    echo "Profiling core: $1" >&2

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
            LOW=$((MID + 1))
        fi
        
        MID=$(( (LOW + HIGH) / 2 ))
    done
    
    echo "${LOW}"
}

FMAX=$(find_fmax "../evos/0/cpu.v")
echo "Fmax of this core is: ${FMAX}"