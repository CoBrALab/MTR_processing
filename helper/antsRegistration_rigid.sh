#!/bin/bash

set -euo pipefail

movingfile1=$1
fixedfile1=$2
movingmask=NULL
fixedmask=$3
_arg_outputbasename=$4

fixed_minimum_resolution=$(python -c "print(min([abs(x) for x in [float(x) for x in \"$(PrintHeader ${fixedfile1} 1)\".split(\"x\")]]))")
fixed_maximum_resolution=$(python -c "print(max([ a*b for a,b in zip([abs(x) for x in [float(x) for x in \"$(PrintHeader ${fixedfile1} 1)\".split(\"x\")]],[abs(x) for x in [float(x) for x in \"$(PrintHeader ${fixedfile1} 2)\".split(\"x\")]])]))")

#set a minimal number of slices for evaluating iteration parameters
ratio=$(python -c "print(int(${fixed_maximum_resolution} / ${fixed_minimum_resolution}))")
if (( 190 > $ratio )); then
  steps=$(ants_generate_iterations.py --min 0.1 --max 19.0 --output multilevel-halving)
else
  steps=$(ants_generate_iterations.py --min ${fixed_minimum_resolution} --max ${fixed_maximum_resolution} --output multilevel-halving)
fi

echo "import sys; str=sys.argv[1]; print(str.split('--transform Similarity')[0][:-3])" > parse_steps.py
parsed_steps=$(python parse_steps.py "$steps")
rm parse_steps.py

antsRegistration --dimensionality 3 --verbose --minc \
  --output [ ${_arg_outputbasename}_output_,${_arg_outputbasename}_output_warped_image.mnc ] \
  --use-histogram-matching 1 \
  --initial-moving-transform [ ${fixedfile1},${movingfile1},1 ] \
  $(eval echo ${parsed_steps})
