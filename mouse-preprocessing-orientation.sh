#!/bin/bash
#Script to do optimal preprocessing on in-vivo/ex-vivo structural scans
#Taken using the CIC Bruker 7T
#usage:
#mouse-preprocessing-v2.sh input.mnc output.mnc

#Operations
# swaps zy to re-orient mouse
# flips x to fix left-right mixup
# centers brain in space

set -euo pipefail
set -v
REGTARGET=${QUARANTINE_PATH}/resources/DSUR_2016/DSUR_40micron_average.mnc
REGMASK=${QUARANTINE_PATH}/resources/DSUR_2016/DSUR_40micron_mask_version2.mnc

tmpdir=$(mktemp -d)

cp $1 $tmpdir/input.mnc

input=$tmpdir/input.mnc
output=$2

minc_modify_header $input -sinsert :history=‘’

volmash -swap zy $input $tmpdir/mash.mnc
volflip $tmpdir/mash.mnc $tmpdir/flip.mnc

clean_and_center_minc.pl $tmpdir/flip.mnc $tmpdir/centered.mnc

minccalc -byte -unsigned -expression 'A[0]?1:1' $tmpdir/centered.mnc $tmpdir/fullmask.mnc

antsRegistration --dimensionality 3 --float 0 --collapse-output-transforms 1 --verbose --minc \
--output $tmpdir/trans \
--use-histogram-matching 0 \
--transform Rigid[0.1] --metric Mattes[$tmpdir/centered.mnc,${REGTARGET},1] --convergence [2000x2000,1e-6,10,1] --shrink-factors 6x4 --smoothing-sigmas 3x2 --masks [NULL,NULL] \
--transform Similarity[0.1] --metric Mattes[$tmpdir/centered.mnc,${REGTARGET},1] --convergence [2000x2000,1e-6,10,1] --shrink-factors 4x2 --smoothing-sigmas 2x1 --masks [NULL,NULL] \
--transform Affine[0.1]     --metric Mattes[$tmpdir/centered.mnc,${REGTARGET},1] --convergence [2000x2000,1e-6,10,1] --shrink-factors 2x1 --smoothing-sigmas 2x1 --masks [NULL,NULL]  \
--transform Affine[0.1]     --metric Mattes[$tmpdir/centered.mnc,${REGTARGET},1] --convergence [2000x2000,1e-6,10,1] --shrink-factors 2x1 --smoothing-sigmas 1x0.5 --masks [NULL,${REGMASK}]

antsApplyTransforms -d 3 -i ${REGMASK} -o $tmpdir/mask.mnc -t $tmpdir/trans0_GenericAffine.xfm -r $tmpdir/centered.mnc -n NearestNeighbor

xfminvert $tmpdir/trans0_GenericAffine.xfm $tmpdir/trans0_GenericAffine_inverse.xfm
param2xfm $(xfm2param $tmpdir/trans0_GenericAffine_inverse.xfm | grep -E 'scale|shear') $tmpdir/scale.xfm
xfminvert $tmpdir/scale.xfm $tmpdir/unscale.xfm
xfmconcat $tmpdir/trans0_GenericAffine_inverse.xfm $tmpdir/unscale.xfm $tmpdir/lsq6.xfm

#cp $tmpdir/mask.mnc $(dirname $output)/$(basename $output .mnc)_mask.mnc
cp $tmpdir/centered.mnc $output

rm -rf $tmpdir
