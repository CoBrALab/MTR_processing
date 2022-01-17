#!/bin/bash
#this script is for processing MTR data and extracting mean and std values within rois to calculate SNR in dorsal and ventral regions
#usage:
#mtr_processing_param_opt.sh output_folder MT_image PD_image mask_for_calc_SNR WM_mask_for_calc_CNR

#name the MT_image in the form ccx_001_mt_6_v1.mnc (where ccx indicates cryocoil, 001 is subjectID, mt_6 refers to the 6th combo
#of parameters attempted and v1 means that mouse positioning has not been altered since the beginning. If necessary to give a mouse a break outside scanner, v2 will refer to new positioning)

#it assumes that mt and pd images were collected consecutively with no change in mouse positioning
#edited on July 20, 2021 to include generation of mean values within mask

module load minc-toolkit
module load minc-toolkit-extras
module load ANTs
source activate mtr_processing_env

#load atlases, masks and labels
atlas=${QUARANTINE_PATH}/resources/Dorr_2008_Steadman_2013_Ullmann_2013_Richards_2011_Qiu_2016_Egan_2015_40micron/ex-vivo/DSURQE_40micron.mnc
atlas_for_reg=${QUARANTINE_PATH}/resources/Dorr_2008_Steadman_2013_Ullmann_2013_Richards_2011_Qiu_2016_Egan_2015_40micron/100um/DSURQE.mnc
atlas_applytransforms=/data/chamal/projects/mila/2019_MTR_on_Cryoprobe/resources_tissue_labels/DSURQE_200micron_masked.mnc
atlas_mask=${QUARANTINE_PATH}/resources/Dorr_2008_Steadman_2013_Ullmann_2013_Richards_2011_Qiu_2016_Egan_2015_40micron/100um/DSURQE_mask.mnc

atlas_nocsf_mask_100micron=/data/chamal/projects/mila/2019_MTR_on_Cryoprobe/resources_tissue_labels/DSURQE_100micron_mask_fixed_binary.mnc
atlas_mask_100micron=/data/chamal/projects/mila/2019_MTR_on_Cryoprobe/resources_tissue_labels/DSURQE_100micron_mask.mnc
atlas_gm_mask_100micron=/data/chamal/projects/mila/2019_MTR_on_Cryoprobe/resources_tissue_labels/DSURQE_100micron_gm.mnc
atlas_wm_mask_100micron=/data/chamal/projects/mila/2019_MTR_on_Cryoprobe/resources_tissue_labels/DSURQE_100micron_wm.mnc
atlas_cc_mask_100micron=/data/chamal/projects/mila/2019_MTR_on_Cryoprobe/resources_tissue_labels/cc_mask_100micron.mnc

#get the path to the folder where the script is located. If code was downloaded from github, all other necessary helper scripts should be located in folders relative to this one.
wdir="$PWD"; [ "$PWD" = "/" ] && wdir=""
case "$0" in
  /*) scriptdir="${0}";;
  *) scriptdir="$wdir/${0#./}";;
esac
scriptdir="${scriptdir%/*}/../../"

tmp_subject_dir=$(mktemp -d)

#name the arguments
output=$1
mt=$2
pd=$3

#move all of the images into a subject-specific temp directory
cp $2 $tmp_subject_dir
cp $3 $tmp_subject_dir
output=$1
temp=$(basename $2)
basename=$(basename $(echo $temp | cut -c1-7)) #extracts the coil_subjectid (assumes that they are in the form xxx_xxx)
version=$(basename -s .mnc $(echo $temp | cut -d "_" -f 5))
scan_num=$(basename -s .mnc $(echo $temp | cut -d "_" -f 4))

#create output folders
mkdir -m a=rwx $output/preprocessed
mkdir -m a=rwx $output/mtr_maps

###################################################################Standard processing and mask creation ###########################################
#first, preprocess all the images (fix orientation)
#for file in $tmp_subject_dir/*; do $scriptdir/helper/mouse-preprocessing-orientation.sh $file $output/preprocessed/$(basename -s .mnc $file)_processed.mnc; done

############################################################MTR map creation using mt acquisitions in PD space #################################
ImageMath 3 $output/mtr_maps/$(basename -s .mnc $mt)_mtr_map_imagemath.mnc MTR $pd $mt



rm -rf $tmp_subject_dir
