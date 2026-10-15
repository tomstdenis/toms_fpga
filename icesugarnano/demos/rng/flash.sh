#!/bin/bash
mkdir ~/ice ; make clean ; make rng.bin ; sudo umount ~/ice ; sudo mount /dev/sdh ~/ice ; sudo make prog_icelink ; sudo umount ~/ice
