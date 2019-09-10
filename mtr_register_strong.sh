#!/bin/bash
#Script for registering DSUQRE atlas to MTR 200um scans for Mila
#Usage
#module load minc-toolkit ANTs/20190211
#./mtr_register.sh DSUQRE.mnc MTR_image.mnc /path/to/save/outputs
#antsApplyTransforms -d 3 -i DSUQRE_labels.mnc -t /path/to/save/outputs/DSUQRE_MTR_image1_NL.xfm \
# -t /path/to/save/outputs/DSUQRE_MTR_image0_GenericAffine.xfm -n GenericLabel -o /path/to/save/labels_on_MTR_image.mnc --verbose \
# -r MTR_image.mnc

set -euo pipefail
export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=${THREADS_PER_COMMAND:-$(nproc)}
export ITK_USE_THREADPOOL=1
export ITK_GLOBAL_DEFAULT_THREADER=Pool

#tmpdir=$(mktemp -d)

movingfile=$1
fixedfile=$2
outputdir=$3

movingmask="NULL"
fixedmask="NULL"

if [[ ! -s ${outputdir}/$(basename ${movingfile})-$(basename ${fixedfile})0_GenericAffine.xfm ]]; then

  antsRegistration --dimensionality 3 --verbose --minc \
    --output [${outputdir}/$(basename ${movingfile})-$(basename ${fixedfile})] \
    --use-histogram-matching 0 \
    --interpolation BSpline[5] \
    --initial-moving-transform [${fixedfile},${movingfile},0] \
   --transform Rigid[0.1] \
   --metric Mattes[${fixedfile},${movingfile},1,32,None] \
   --convergence [2025x2025x2025x2025x2025x2025x2025x2025x2025,1e-6,10] \
   --shrink-factors 8x7x6x5x4x3x2x1x1 \
   --smoothing-sigmas 3.98448927075x3.4822628776x2.97928762436x2.47510701762x1.96879525311x1.45813399545x0.936031382318x0.355182697615x0vox \
   --transform Similarity[0.1] \
   --metric Mattes[${fixedfile},${movingfile},1,32,None] \
   --convergence [2025x2025x2025x2025x2025x2025x2025x2025x2025,1e-6,10] \
   --shrink-factors 8x7x6x5x4x3x2x1x1 \
   --smoothing-sigmas 3.98448927075x3.4822628776x2.97928762436x2.47510701762x1.96879525311x1.45813399545x0.936031382318x0.355182697615x0vox \
   --transform Affine[0.1] \
   --metric Mattes[${fixedfile},${movingfile},1,32,None] \
   --convergence [2025x2025x2025x2025,1e-6,10] \
   --shrink-factors 3x2x1x1 \
   --smoothing-sigmas 1.45813399545x0.936031382318x0.355182697615x0vox
fi


  antsRegistration --dimensionality 3 --verbose --minc \
    --output [${outputdir}/$(basename ${movingfile})-$(basename ${fixedfile})] \
    --use-histogram-matching 0 \
    --interpolation BSpline[5] \
    --initial-moving-transform ${outputdir}/$(basename ${movingfile})-$(basename ${fixedfile})0_GenericAffine.xfm \
   --transform SyN[0.1,2,1] \
   --metric CC[${fixedfile},${movingfile},1,4] \
   --convergence [2025x2025x2025x2025x2025x2025x2025x2025x2025,1e-6,10] \
   --shrink-factors 8x7x6x5x4x3x2x1x1 \
   --smoothing-sigmas 3.98448927075x3.4822628776x2.97928762436x2.47510701762x1.96879525311x1.45813399545x0.936031382318x0.355182697615x0vox
