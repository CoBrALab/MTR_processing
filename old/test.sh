#!/bin/bash
#this script is for creating MTR and B1 maps for the purpose of performing a B1-MTR linear regression
#TIP: create a csv with the subject ids and paths to each of the input files
#all input folders should contain raw minc images named with the following convention coil_subjectid_mt_timepoint.mnc or coil_subjectid_pd_timepoint.mnc etc. Where timepoint is a single digit!
#usage:
#mtr_processing_main.sh output_folder PD_image b1_60 b1_120 MT_image1 MT_image2 MT_image3 MT_image4 MT_image5 MT_image6
# OUTPUT FOLDER SHOULD NOT HAVE A / AT THE END!
#it assumes that all 4 images were collected consecutively with no change in mouse positioning. Works with multiple MT images per mouse-coil combo but needs to be modified if want to use multiple pd images or b1 maps
#edited on july 7, 2021 to perform registration of all 6 acquisitions from a single subject to each other. This requires taking all 6 acquisitions as input. Do this after the MTR calculation. This will permit an accurate voxelwise linear regression.

module load minc-toolkit
module load minc-toolkit-extras
module load ANTs
source activate /home/cic/uromil/miniconda3/envs/mtr_processing_env

tmp_subject_dir=$(mktemp -d)

#load atlases, masks and labels
atlas_for_reg=${QUARANTINE_PATH}/resources/Dorr_2008_Steadman_2013_Ullmann_2013_Richards_2011_Qiu_2016_Egan_2015_40micron/100um/DSURQE.mnc
atlas_applytransforms=/data/chamal/projects/mila/2019_MTR_on_Cryoprobe/resources_tissue_labels/DSURQE_200micron_masked.mnc
atlas_mask=${QUARANTINE_PATH}/resources/Dorr_2008_Steadman_2013_Ullmann_2013_Richards_2011_Qiu_2016_Egan_2015_40micron/100um/DSURQE_mask.mnc
atlas_mask_200micron=/data/chamal/projects/mila/2019_MTR_on_Cryoprobe/resources_tissue_labels/DSURQE_200micron_mask_binary.mnc
atlas_nocsf_mask=/data/chamal/projects/mila/2019_MTR_on_Cryoprobe/resources_tissue_labels/DSURQE_200micron_mask_nocsf_binary.mnc
atlas_gm_mask=/data/chamal/projects/mila/2019_MTR_on_Cryoprobe/resources_tissue_labels/DSURQE_200micron_gm_binary.mnc
atlas_wm_mask=/data/chamal/projects/mila/2019_MTR_on_Cryoprobe/resources_tissue_labels/DSURQE_200micron_wm_binary.mnc
atlas_cc_mask=/data/chamal/projects/mila/2019_MTR_on_Cryoprobe/resources_tissue_labels/cc_mask_200micron_binary.mnc

#get the path to the folder where the script is located. If code was downloaded from github, all other necessary helper scripts should be located in folders relative to this one.
wdir="$PWD"; [ "$PWD" = "/" ] && wdir=""
case "$0" in
  /*) scriptdir="${0}";;
  *) scriptdir="$wdir/${0#./}";;
esac
scriptdir="${scriptdir%/*}/../../"

#move all of the images into a subject-specific temp directory
output=$1
mt=$2
pd=$3
b160=$4
b1120=$5



cp $2 $tmp_subject_dir
cp $3 $tmp_subject_dir
cp $4 $tmp_subject_dir
cp $5 $tmp_subject_dir

temp=$(basename $mt)
basename=$(basename $(echo $temp | cut -c1-7)) #extracts the coil_subjectid (assumes that they are in the form xxx_xxx)
fa=$(basename $(echo $temp | cut -c12-15)) #extract flip angle
coil_type=$(echo $basename | cut -c1-3)

#first, preprocess all the images. denoised versions are also created to aid with registration later on.
mkdir -m a=rwx $output/preprocessed
mkdir -m a=rwx $output/mtr_maps_native_space
mkdir -m a=rwx $output/b1_maps
mkdir -m a=rwx $output/denoised

#fix the orientation
#for file in $tmp_subject_dir/*; do $scriptdir/helper/mouse-preprocessing-orientation.sh $file $output/preprocessed/$(basename -s .mnc $file)_processed.mnc; done

#Create MTR maps in native space
#ImageMath 3 $output/mtr_maps_native_space/$(basename -s .mnc $mt)_mtr_map_imagemath.mnc MTR $output/preprocessed/$(basename -s .mnc $pd)_processed.mnc $output/preprocessed/$(basename -s .mnc $mt)_processed.mnc $output/masks/${basename}_mask_nocsf.mnc

#create b1 maps
#minccalc -expression 'acos(A[1]/(2*A[0]))*(180/(4*atan(1)))' $output/preprocessed/$(basename -s .mnc $b160)_processed.mnc $output/preprocessed/$(basename -s .mnc $b1120)_processed.mnc $output/b1_maps/${basename}_b1_map.mnc

#calculate difference with original (percentile mapping ) mtr maps
#mincmath -sub $output/mtr_maps_native_space/$(basename -s .mnc $mt)_mtr_map_imagemath.mnc /data/chamal/projects/mila/2019_MTR_on_Cryoprobe/5_cuprizone_validation/derivatives/mri/mtr_maps/${basename}_mt_2_mtr_map_imagemath.mnc $output/mtr_maps_difference_with_percentile_mapping/${basename}_difference_mtr_abs_percentile.mnc
#mincmath -sub $output/b1_maps/${basename}_b1_map.mnc /data/chamal/projects/mila/2019_MTR_on_Cryoprobe/5_cuprizone_validation/derivatives/mri/b1_maps/${basename}_b1_map.mnc $output/b1_maps_difference_with_percentile_mapping/${basename}_difference_b1_abs_percentile.mnc

#denoise the mt and b1 file. The N4 denoised acquisitions are necessary for registering the b1_map to the mtr.
#~/MTR_processing/helper/mouse-preprocessing-denoise-only.sh $output/preprocessed/$(basename -s .mnc $mt)_processed.mnc $output/denoised/$(basename -s .mnc $mt)_processed_denoised.mnc
#python ~/MTR_processing/helper/bias_cor_minc.py $output/preprocessed/$(basename -s .mnc $b1120)_processed.mnc $output/denoised/$(basename -s .mnc $mt)_processed_denoised.mnc $output/masks/${basename}_mask_full.mnc ~/MTR_processing/helper/antsRegistration_rigid.sh $output/denoised/$(basename -s .mnc $b1120)_processed_denoised.mnc

#register the b1 map to the MTR map
#mkdir -m a=rwx $output/b1_maps/registered_b1_to_mtr
#~/MTR_processing/helper/antsRegistration_affine_SyN.sh $output/denoised/$(basename -s .mnc $5)_processed_denoised.mnc $output/denoised/$(basename -s .mnc $2)_processed_denoised.mnc $output/masks/${basename}_mask_full.mnc $output/b1_maps/registered_b1_to_mtr/${basename}_b1_120-${basename}_mt_1045
#antsApplyTransforms -d 3 -i $output/b1_maps/${basename}_b1_map.mnc -t $output/b1_maps/registered_b1_to_mtr/${basename}_b1_120-${basename}_mt_1045_output_1_NL.xfm -t $output/b1_maps/registered_b1_to_mtr/${basename}_b1_120-${basename}_mt_1045_output_0_GenericAffine.xfm -o $output/b1_maps/registered_b1_to_mtr/${basename}_b1_map_registered.mnc --verbose -r $output/denoised/$(basename -s .mnc $2)_processed_denoised.mnc

#normalize b1 map using a value of 60
#mkdir -m a=rwx $output/b1_maps/normalized_and_registered_b1
#minccalc -expression "A[0]/60" $output/b1_maps/registered_b1_to_mtr/${basename}_b1_map_registered.mnc $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc

#perform the correction separately for the cryocoil (uses data from the optimized parameters) and normal coil (standard parameters)
#mkdir -m a=rwx $output/mtr_maps_native_space/corrected_mtr_maps
#if [ "$coil_type" == "cry" ]; then minccalc -expression 'A[0]/(1.1842766*A[1]-0.1842766)' $output/mtr_maps_native_space/$(basename -s .mnc $2)_mtr_map_imagemath.mnc $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc $output/mtr_maps_native_space/corrected_mtr_maps/$(basename -s .mnc $2)_mtr_map_imagemath_corrected.mnc; fi
#if [ "$coil_type" == "nrm" ]; then minccalc -expression 'A[0]/(1.25844938*A[1]-0.25844938)' $output/mtr_maps_native_space/$(basename -s .mnc $2)_mtr_map_imagemath.mnc $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc $output/mtr_maps_native_space/corrected_mtr_maps/$(basename -s .mnc $2)_mtr_map_imagemath_corrected.mnc; fi

#calculate difference with original (percentile mapping ) corrected mtr maps
mincmath -sub $output/mtr_maps_native_space/corrected_mtr_maps/$(basename -s .mnc $mt)_mtr_map_imagemath_corrected.mnc /data/chamal/projects/mila/2019_MTR_on_Cryoprobe/5_cuprizone_validation/derivatives/mri/mtr_maps/corrected_mtr_maps/${basename}_mt_2_mtr_map_imagemath_corrected.mnc $output/mtr_maps_difference_with_percentile_mapping/${basename}_difference_corrected_mtr_abs_percentile.mnc
