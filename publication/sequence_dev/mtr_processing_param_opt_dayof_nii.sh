#!/bin/bash
#this script is for processing MTR data  that is in nifti format. This is necessary (At least for now) since the brkraw conversion properly accounts for scaling slopes produced during absolute mapping, whereas dcm format does not.
#usage:
#mtr_processing_param_opt.sh output_folder MT_image PD_image

#name the MT_image in the form ccx_001_mt_6_v1.mnc (where ccx indicates cryocoil, 001 is subjectID, mt_6 refers to the 6th combo
#of parameters attempted and v1 means that mouse positioning has not been altered since the beginning. If necessary to give a mouse a break outside scanner, v2 will refer to new positioning)

#it assumes that mt and pd images were collected consecutively with no change in mouse positioning
#edited on oct 10, 2021

module load minc-toolkit
module load ANTs
source activate mtr_processing_env

#name the arguments
output=$1
mt=$2
pd=$3

#create MTR map using niftis
ImageMath 3 $output/$(basename -s .nii.gz $mt)_mtr_map_imagemath_pd6.nii.gz MTR $pd $mt

########################################################### Convert MTR from nifti to minc ############################################
nii2mnc $output/$(basename -s .nii.gz $mt)_mtr_map_imagemath.nii.gz $output/$(basename -s .nii.gz $mt)_mtr_map_imagemath.mnc

