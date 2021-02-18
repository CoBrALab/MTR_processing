#!/bin/bash
#Script to do optimal preprocessing on in-vivo/ex-vivo structural scans
#Taken using the CIC Bruker 7T
#usage:
#mouse-preprocessing-orientation.sh input.mnc output.mnc

#Operations
# swaps zy to re-orient mouse
# flips x to fix left-right mixup
# centers brain in space

set -euo pipefail
set -v

tmpdir=$(mktemp -d)

cp $1 $tmpdir/input.mnc

input=$tmpdir/input.mnc
output=$2

minc_modify_header $input -sinsert :history=‘’

volmash -swap zy $input $tmpdir/mash.mnc
volflip $tmpdir/mash.mnc $tmpdir/flip.mnc

clean_and_center_minc.pl $tmpdir/flip.mnc $tmpdir/centered.mnc

cp $tmpdir/centered.mnc $output

rm -rf $tmpdir
