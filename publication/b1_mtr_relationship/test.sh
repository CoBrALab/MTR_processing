#!/bin/bash
#this script is for creating MTR and B1 maps for the purpose of performing a B1-MTR linear regression
#all input folders should contain raw nifti images named with the following naming format: sub-HAR001_acq-cryo_flip-990_MTw.nii.gz
#usage:
#mtr_processing_main.sh output_folder PDw B1_60 B1_120 MT1 MT2 MT3 MT4 MT5 MT6 MT7 MT8 MT9
#it assumes that all images were collected consecutively with no change in mouse positioning.
#edited on jan 11, 2022 to use raw niftis instead of minc as input, remove reg of all mt acq to each other

module load minc-toolkit
module load minc-toolkit-extras
module load ANTs
source activate /home/cic/uromil/miniconda3/envs/mtr_processing_env

tmp_mnc_b1_subject_dir=$(mktemp -d)
tmp_mnc_subject_dir=$(mktemp -d)
tmp_nii_subject_dir=$(mktemp -d)
tmp_nii_b1_subject_dir=$(mktemp -d)

#load atlases, masks and labels
atlas_for_reg=${QUARANTINE_PATH}/resources/Dorr_2008_Steadman_2013_Ullmann_2013_Richards_2011_Qiu_2016_Egan_2015_40micron/100um/DSURQE.mnc
atlas_mask=${QUARANTINE_PATH}/resources/Dorr_2008_Steadman_2013_Ullmann_2013_Richards_2011_Qiu_2016_Egan_2015_40micron/100um/DSURQE_mask.mnc
atlas_full_mask=/data/chamal/projects/mila/2019_MTR_on_Cryoprobe/resources_tissue_labels/DSURQE_100micron_mask.mnc
atlas_nocsf_mask=/data/chamal/projects/mila/2019_MTR_on_Cryoprobe/resources_tissue_labels/DSURQE_100micron_mask_fixed_binary.mnc
atlas_gm_mask=/data/chamal/projects/mila/2019_MTR_on_Cryoprobe/resources_tissue_labels/DSURQE_100micron_gm.mnc
atlas_wm_mask=/data/chamal/projects/mila/2019_MTR_on_Cryoprobe/resources_tissue_labels/DSURQE_100micron_wm.mnc
atlas_cc_mask=/data/chamal/projects/mila/2019_MTR_on_Cryoprobe/resources_tissue_labels/cc_mask_100micron.mnc
cerebellum_antimask=/data/chamal/projects/mila/2019_MTR_on_Cryoprobe/resources_tissue_labels/DSURQE_100micron_cerebellum_antimask.mnc

#get the path to the folder where the script is located. If code was downloaded from github, all other necessary helper scripts should be located in folders relative to this one.
wdir="$PWD"; [ "$PWD" = "/" ] && wdir=""
case "$0" in
    /*) scriptdir="${0}";;
    *) scriptdir="$wdir/${0#./}";;
esac
scriptdir="${scriptdir%/*}/../../"

#move all of the images into a subject-specific temp directory
output=$1
pd=$2
b160=$3
b1120=$4
cp $2 $tmp_nii_subject_dir | cp $3 $tmp_nii_b1_subject_dir | cp $4 $tmp_nii_b1_subject_dir

shift 4
mt1=$1
cp $1 $tmp_nii_subject_dir | cp $2 $tmp_nii_subject_dir | cp $3 $tmp_nii_subject_dir | cp $4 $tmp_nii_subject_dir
cp $5 $tmp_nii_subject_dir | cp $6 $tmp_nii_subject_dir | cp $7 $tmp_nii_subject_dir | cp $8 $tmp_nii_subject_dir | cp $9 $tmp_nii_subject_dir

temp=$(basename $mt1)
subject=$(echo $temp | grep -oP '(?<=sub-).*?(?=_)' ) #extract subjectID
fa_mt1=$(echo $temp | grep -oP '(?<=flip-).*?(?=_MTw)' ) #extract flip angle of mt1
coil_type=$(echo $temp | grep -oP '(?<=acq-).*?(?=_)' ) #extract coil type
basename=$(echo $temp | grep -oP '(?<=).*?(?=_flip)' )

mkdir -m a=rwx $output/raw_minc
mkdir -m a=rwx $output/n4_bias_corrected
mkdir -m a=rwx $output/transforms_subject_to_DSURQE
mkdir -m a=rwx $output/masks_native_space
mkdir -m a=rwx $output/raw_minc_mt1_space
mkdir -m a=rwx $output/transforms_subject_acq_to_mt1
mkdir -m a=rwx $output/denoised_nonlocal_means
mkdir -m a=rwx $output/mtr_maps
mkdir -m a=rwx $output/mtr_maps/mtr_maps_denoised
mkdir -m a=rwx $output/mtr_maps/mtr_maps_raw

#convert from nifti to minc
for file in $tmp_nii_subject_dir/*; do 
        nii2mnc -noscanrange $file $output/raw_minc/$(basename -s .nii.gz $file).mnc; 
        cp $output/raw_minc/$(basename -s .nii.gz $file).mnc $tmp_mnc_subject_dir; 
done
for file in $tmp_nii_b1_subject_dir/*; do 
        nii2mnc -noscanrange $file $output/raw_minc/$(basename -s .nii.gz $file).mnc; 
        cp $output/raw_minc/$(basename -s .nii.gz $file).mnc $tmp_mnc_b1_subject_dir; 
done


############################################################### Registration of B1 acquisitions to MT within subject (register to MT1, which has largest FA) ####################################
mkdir -m a=rwx $output/b1_maps/
mkdir -m a=rwx $output/b1_maps/registered_b1_to_mtr
mkdir -m a=rwx $output/b1_maps/registered_and_normalized_b1

#perform bias field correction of the b1_120 acquisition first (assumes that the mask registered to mt1 applies well to b1-120 as well)
python $scriptdir/helper/bias_cor_minc.py $output/raw_minc/$(basename -s .nii.gz $b1120).mnc $output/n4_bias_corrected/$(basename -s .nii.gz $mt1)_N4corr.mnc \
$output/masks_native_space/${basename}_mask_full.mnc $scriptdir/helper/antsRegistration_rigid.sh $output/n4_bias_corrected/$(basename -s .nii.gz $b1120)_N4corr.mnc
rm -rf $output/n4_bias_corrected/$(basename -s .nii.gz $b1120)_resampled_mask.mnc

#register the denoised b1 acquisition to mt1
$scriptdir/helper/antsRegistration_affine_SyN.sh $output/n4_bias_corrected/$(basename -s .nii.gz $b1120)_N4corr.mnc \
$output/n4_bias_corrected/$(basename -s .nii.gz $mt1)_N4corr.mnc $output/masks_native_space/${basename}_mask_full.mnc \
$output/transforms_subject_acq_to_mt1/${basename}_B1120-to-${fa_mt1}

#Create B1 maps
minccalc -expression 'acos(A[1]/(2*A[0]))*(180/(4*atan(1)))' $output/raw_minc/$(basename -s .nii.gz $b160).mnc \
$output/raw_minc/$(basename -s .nii.gz $b1120).mnc $output/b1_maps/${basename}_b1_map.mnc

#Apply transforms to the B1 map to put it in mt1 space
antsApplyTransforms -d 3 -i $output/b1_maps/${basename}_b1_map.mnc -t $output/transforms_subject_acq_to_mt1/${basename}_B1120-to-${fa_mt1}_output_1_NL.xfm \
-t $output/transforms_subject_acq_to_mt1/${basename}_B1120-to-${fa_mt1}_output_0_GenericAffine.xfm -o $output/b1_maps/registered_b1_to_mtr/${basename}_b1_map_registered.mnc \
--verbose -r $output/n4_bias_corrected/$(basename -s .nii.gz $mt1)_N4corr.mnc

#normalize b1 map using a value of 60
minccalc -expression "A[0]/60" $output/b1_maps/registered_b1_to_mtr/${basename}_b1_map_registered.mnc $output/b1_maps/registered_and_normalized_b1/${basename}_b1_map_registered_norm.mnc

######################################################################### Create mask based on B1 field strength ###############################################################
mkdir -m a=rwx $output/b1_maps/tmp/
mkdir -m a=rwx $output/b1_maps/mask_from_b1_map

#create a mask according to the b1 map (only exists where b1 map is between 0.8 and 1). Do this by first masking b1_map with no_csf eroded mask, cut off cerebellum (can be noisy) then threshold to 0.8-1.
mincmath -clobber -mult $output/b1_maps/registered_and_normalized_b1/${basename}_b1_map_registered_norm.mnc \
$output/masks_native_space/${basename}_mask_nocsf_eroded.mnc $output/b1_maps/tmp/${basename}_b1_map_reg_norm_masked_tmp.mnc

mincmath -clobber -mult $output/b1_maps/tmp/${basename}_b1_map_reg_norm_masked_tmp.mnc $cerebellum_antimask \
$output/b1_maps/mask_from_b1_map/${basename}_b1_map_reg_norm_mask_cerebellum.mnc

mincmath -clobber -const2 0.8 1 -segment $output/b1_maps/mask_from_b1_map/${basename}_b1_map_reg_norm_masked.mnc \
$output/b1_maps/mask_from_b1_map/${basename}_b1_map_reg_norm_mask_thresh_0.8_to_1.mnc

rm -rf $output/b1_maps/tmp/
rm -rf $tmp_nii_subject_dir
rm -rf $tmp_nii_b1_subject_dir
rm -rf $tmp_mnc_subject_dir
rm -rf $tmp_mnc_b1_subject_dir