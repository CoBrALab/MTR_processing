#!/bin/bash
#this script is for processing MTR data and extracting mean and std values within rois to calculate SNR in dorsal and ventral regions
#usage:
#mtr_processing_param_opt.sh output_folder MT_image PD_image mask_for_calc_SNR WM_mask_for_calc_CNR background_mask

#name the MT_image in the form ccx_001_mt_6_v1.mnc (where ccx indicates cryocoil, 001 is subjectID, mt_6 refers to the 6th combo
#of parameters attempted and v1 means that mouse positioning has not been altered since the beginning. If necessary to give a mouse a break outside scanner, v2 will refer to new positioning)

#it assumes that mt and pd images were collected consecutively with no change in mouse positioning
#edited on July 20, 2021 to include generation of mean values within mask

module load minc-toolkit
module load minc-toolkit-extras
module load ANTs
source activate mtr_processing_env

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
mask1=$4
mask_wm=$5
backgroundmask=$6

#move all of the images into a subject-specific temp directory
cp $2 $tmp_subject_dir
cp $3 $tmp_subject_dir
output=$1
temp=$(basename $2)
basename=$(basename $(echo $temp | cut -c1-7)) #extracts the coil_subjectid (assumes that they are in the form xxx_xxx)
version=$(basename -s .mnc $(echo $temp | cut -d "_" -f 5))
scan_num=$(basename -s .mnc $(echo $temp | cut -d "_" -f 6))
subject=$(basename -s .mnc $(echo $temp | cut -d "_" -f 4))

####################################################### Convert pd file to minc (maybe don't need to save) ############################333
mkdir -m a=rwx $output/nii2mnc_noscanrange
nii2mnc -noscanrange $pd $output/pd_files_minc/$(basename -s .nii.gz $pd).mnc
#nii2mnc -noscanrange $pd $output/nii2mnc_noscanrange/$(basename -s .nii.gz $pd).mnc
#nii2mnc -noscanrange $mt $output/nii2mnc_noscanrange/$(basename -s .nii.gz $mt).mnc

############################################################MTR map creation using niftis #################################
#ImageMath 3 $output/$(basename -s .nii.gz $mt)_mtr_map_imagemath.nii.gz MTR $pd $mt

########################################################### Convert MTR from nifti to minc ############################################
#nii2mnc $output/$(basename -s .nii.gz $mt)_mtr_map_imagemath.nii.gz $output/$(basename -s .nii.gz $mt)_mtr_map_imagemath.mnc

############################################################ Extract mean and std within masks for the purpose of calculating SNR ############################
if [ ! -f $output/snr_param_opt.csv ]; then
      echo Subject,Scan,region,mean_MTR_gm,mean_pd,stddev_background,MTR_wm,file_mtr,file_pd,mask_file,mask_background,mask_wm >> $output/snr_param_opt.csv

fi
#Upper ROI
MTR_top=$(mincstats -mean -quiet -mask  $mask1 -mask_binvalue 1 $output/$(basename -s .nii.gz $mt)_mtr_map_imagemath.mnc)
mean_pd_top=$(mincstats -mean -quiet -mask  $mask1 -mask_binvalue 1 $output/pd_files_minc/$(basename -s .nii.gz $pd).mnc)

#mean in lower ROI
MTR_bottom=$(mincstats -mean -quiet -mask  $mask1 -mask_binvalue 2 $output/$(basename -s .nii.gz $mt)_mtr_map_imagemath.mnc)
mean_pd_bottom=$(mincstats -mean -quiet -mask  $mask1 -mask_binvalue 2 $output/pd_files_minc/$(basename -s .nii.gz $pd).mnc)

#stddev in the background of the PD-w acquisition
stddev_back=$(mincstats -stddev -quiet -mask  $backgroundmask -mask_binvalue 1 $output/pd_files_minc/$(basename -s .nii.gz $pd).mnc)
MTR_wm=$(mincstats -mean -quiet -mask  $mask_wm -mask_binvalue 1 $output/$(basename -s .nii.gz $mt)_mtr_map_imagemath.mnc)

echo $subject,${scan_num},top,$MTR_top,$mean_pd_top,$stddev_back,$MTR_wm,$output/$(basename -s .nii.gz $mt)_mtr_map_imagemath.mnc,$pd,$mask1,$backgroundmask,$mask_wm>> $output/snr_param_opt.csv
echo $subject,${scan_num},bottom,$MTR_bottom,$mean_pd_bottom,$stddev_back,$MTR_wm,$output/$(basename -s .nii.gz $mt)_mtr_map_imagemath.mnc,$pd,$mask1,$backgroundmask,$mask_wm >> $output/snr_param_opt.csv


rm -rf $tmp_subject_dir
