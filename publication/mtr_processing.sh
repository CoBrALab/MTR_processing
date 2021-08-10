#!/bin/bash
#this script is for creating MTR and B1 maps and outputting a final MTR map that is corrected for B1 inhomogeneities.
#all input folders should contain raw minc images named with the following convention coil_subjectid_mt.mnc or coil_subjectid_pd.mnc etc.
#usage:
#mtr_processing_main.sh output_folder MT_image PD_image b1_60 b1_120
#it assumes that all 4 images were collected consecutively with no change in mouse positioning. Works with multiple MT images per mouse-coil combo but needs to be modified if want to use multiple pd images or b1 maps
#edited on Jul 14 2021 to improve syntax
module load minc-toolkit
module load minc-toolkit-extras
module load ANTs
source activate mtr_processing_env

tmp_subject_dir=$(mktemp -d)
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
scriptdir="${scriptdir%/*}"

#name the arguments
output=$1
mt=$2
pd=$3
b160=$4
b1120=$5

#move all of the images into a subject-specific temp directory
cp $2 $tmp_subject_dir
cp $3 $tmp_subject_dir
cp $4 $tmp_subject_dir
cp $5 $tmp_subject_dir

output=$1
temp=$(basename $2)
basename=$(basename $(echo $temp | cut -c1-7)) #extracts the coil_subjectid (assumes that they are in the form xxx_xxx)
coil_type=$(echo $basename | cut -c1-3)

#create output folders
mkdir -m a=rwx $output/preprocessed
mkdir -m a=rwx $output/n4_bias_corrected
mkdir -m a=rwx $output/masks
mkdir -m a=rwx $output/transforms_subject_to_DSURQE
mkdir -m a=rwx $output/subject_specific_tissue_masks
mkdir -m a=rwx $output/denoised_nonlocal_means
mkdir -m a=rwx $output/mtr_maps
mkdir -m a=rwx $output/mtr_maps/corrected_mtr_maps
mkdir -m a=rwx $output/mtr_maps_denoised
mkdir -m a=rwx $output/mtr_maps_denoised/corrected_mtr_maps_denoised
mkdir -m a=rwx $output/b1_maps
mkdir -m a=rwx $output/b1_maps/registered_b1_to_mtr
mkdir -m a=rwx $output/b1_maps/normalized_and_registered_b1

#first, preprocess all the images (fix orientation)
for file in $tmp_subject_dir/*; do $scriptdir/helper/mouse-preprocessing-orientation.sh $file $output/preprocessed/$(basename -s .mnc $file)_processed.mnc; done

#perform N4 bias field correction. The N4 bias corrected acquisitions are necessary for registration to the atlas, and for registering the b1_map to the mtr.
$scriptdir/helper/mouse-preprocessing-denoise-only.sh $output/preprocessed/$(basename -s .mnc $mt)_processed.mnc $output/n4_bias_corrected/$(basename -s .mnc $mt)_processed_n4corr.mnc

#create mask by registering mt file to DSURQE, then transforming DSURQE mask to subject
$scriptdir/helper/antsRegistration_affine_SyN.sh $output/n4_bias_corrected/$(basename -s .mnc $mt)_processed_n4corr.mnc $atlas_for_reg $atlas_mask $output/transforms_subject_to_DSURQE/${basename}-DSURQE
antsApplyTransforms -d 3 -i $atlas_nocsf_mask_100micron -t [$output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_0_GenericAffine.xfm,1] -t $output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_1_inverse_NL.xfm -n GenericLabel -o $output/masks/${basename}_mask_nocsf.mnc --verbose -r $output/n4_bias_corrected/$(basename -s .mnc $mt)_processed_n4corr.mnc
antsApplyTransforms -d 3 -i $atlas_mask_100micron -t [$output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_0_GenericAffine.xfm,1] -t $output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_1_inverse_NL.xfm -n GenericLabel -o $output/masks/${basename}_mask_full.mnc --verbose -r $output/n4_bias_corrected/$(basename -s .mnc $mt)_processed_n4corr.mnc

#warp other masks (corpus callosum, wm, gm) to the subject file as well
antsApplyTransforms -d 3 -i $atlas_gm_mask_100micron -t [$output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_0_GenericAffine.xfm,1] -t $output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_1_inverse_NL.xfm -n GenericLabel -o $output/subject_specific_tissue_masks/${basename}_mask_gm.mnc --verbose -r $output/n4_bias_corrected/$(basename -s .mnc $mt)_processed_n4corr.mnc
antsApplyTransforms -d 3 -i $atlas_wm_mask_100micron -t [$output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_0_GenericAffine.xfm,1] -t $output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_1_inverse_NL.xfm -n GenericLabel -o $output/subject_specific_tissue_masks/${basename}_mask_wm.mnc --verbose -r $output/n4_bias_corrected/$(basename -s .mnc $mt)_processed_n4corr.mnc
antsApplyTransforms -d 3 -i $atlas_cc_mask_100micron -t [$output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_0_GenericAffine.xfm,1] -t $output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_1_inverse_NL.xfm -n GenericLabel -o $output/subject_specific_tissue_masks/${basename}_mask_cc.mnc --verbose -r $output/n4_bias_corrected/$(basename -s .mnc $mt)_processed_n4corr.mnc

#now do image denoising of both mt and pd acquisitions using non-local-means
DenoiseImage -d 3 -i $output/preprocessed/$(basename -s .mnc $mt)_processed.mnc -n Rician -x $output/masks/${basename}_mask_full.mnc --verbose -o $output/denoised_nonlocal_means/$(basename -s .mnc $mt)_denoised.mnc
DenoiseImage -d 3 -i $output/preprocessed/$(basename -s .mnc $pd)_processed.mnc -n Rician -x $output/masks/${basename}_mask_full.mnc --verbose -o $output/denoised_nonlocal_means/$(basename -s .mnc $pd)_denoised.mnc

#create MTR maps (the minccalc outputs are better for histograms, otherwise use the imagemath outputs)
minccalc -expression '(A[0]- A[1])/A[0]' $output/preprocessed/$(basename -s .mnc $pd)_processed.mnc $output/preprocessed/$(basename -s .mnc $mt)_processed.mnc $output/mtr_maps/$(basename -s .mnc $mt)_mtr_map_minccalc.mnc
ImageMath 3 $output/mtr_maps/$(basename -s .mnc $mt)_mtr_map_imagemath.mnc MTR $output/preprocessed/$(basename -s .mnc $pd)_processed.mnc $output/preprocessed/$(basename -s .mnc $mt)_processed.mnc $output/masks/${basename}_mask_nocsf.mnc

#create denoised MTR maps too
ImageMath 3 $output/mtr_maps_denoised/$(basename -s .mnc $mt)_mtr_map_imagemath.mnc MTR $output/denoised_nonlocal_means/$(basename -s .mnc $pd)_denoised.mnc $output/denoised_nonlocal_means/$(basename -s .mnc $mt)_denoised.mnc $output/masks/${basename}_mask_nocsf.mnc

#create b1 maps
minccalc -expression 'acos(A[1]/(2*A[0]))*(180/(4*atan(1)))' $output/preprocessed/$(basename -s .mnc $4)_processed.mnc $output/preprocessed/$(basename -s .mnc $b1120)_processed.mnc $output/b1_maps/${basename}_b1_map.mnc

#N4 denoising of the b1 acquisitions (only need b1_120 to be denoised)
python $scriptdir/helper/bias_cor_minc.py $output/preprocessed/$(basename -s .mnc $b1120)_processed.mnc $output/n4_bias_corrected/$(basename -s .mnc $mt)_processed_n4corr.mnc $output/masks/${basename}_mask_full.mnc $scriptdir/helper/antsRegistration_rigid.sh $output/n4_bias_corrected/$(basename -s .mnc $b1120)_processed_n4corr.mnc

#register the b1 map to the MTR map
$scriptdir/helper/antsRegistration_affine_SyN.sh $output/n4_bias_corrected/$(basename -s .mnc $b1120)_processed_n4corr.mnc $output/n4_bias_corrected/$(basename -s .mnc $mt)_processed_n4corr.mnc $output/masks/${basename}_mask_full.mnc $output/b1_maps/registered_b1_to_mtr/${basename}_b1_120-${basename}_mt_1045
antsApplyTransforms -d 3 -i $output/b1_maps/${basename}_b1_map.mnc -t $output/b1_maps/registered_b1_to_mtr/${basename}_b1_120-${basename}_mt_1045_output_1_NL.xfm -t $output/b1_maps/registered_b1_to_mtr/${basename}_b1_120-${basename}_mt_1045_output_0_GenericAffine.xfm -o $output/b1_maps/registered_b1_to_mtr/${basename}_b1_map_registered.mnc --verbose -r $output/n4_bias_corrected/$(basename -s .mnc $mt)_processed_n4corr.mnc

#normalize b1 map using a value of 60
minccalc -expression "A[0]/60" $output/b1_maps/registered_b1_to_mtr/${basename}_b1_map_registered.mnc $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc

#perform the correction separately for the cryocoil (uses data from the optimized parameters) and normal coil (standard parameters)
if [ "$coil_type" == "cry" ]; then minccalc -expression 'A[0]/(1.1842766*A[1]-0.1842766)' $output/mtr_maps/$(basename -s .mnc $mt)_mtr_map_imagemath.mnc $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc $output/mtr_maps/corrected_mtr_maps/$(basename -s .mnc $mt)_mtr_map_imagemath_corrected.mnc; fi
if [ "$coil_type" == "nrm" ]; then minccalc -expression 'A[0]/(1.25844938*A[1]-0.25844938)' $output/mtr_maps/$(basename -s .mnc $mt)_mtr_map_imagemath.mnc $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc $output/mtr_maps/corrected_mtr_maps/$(basename -s .mnc $mt)_mtr_map_imagemath_corrected.mnc; fi

if [ "$coil_type" == "cry" ]; then minccalc -expression 'A[0]/(1.1842766*A[1]-0.1842766)' $output/mtr_maps_denoised/$(basename -s .mnc $mt)_mtr_map_imagemath.mnc $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc $output/mtr_maps_denoised/corrected_mtr_maps_denoised/$(basename -s .mnc $mt)_mtr_map_imagemath_denoised_corrected.mnc; fi
if [ "$coil_type" == "nrm" ]; then minccalc -expression 'A[0]/(1.25844938*A[1]-0.25844938)' $output/mtr_maps_denoised$(basename -s .mnc $mt)_mtr_map_imagemath.mnc $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc $output/mtr_maps_denoised/corrected_mtr_maps_denoised/$(basename -s .mnc $mt)_mtr_map_imagemath_denoised_corrected.mnc; fi

#after the correction, there may be a few voxels greater than 1 that correspond to noise but made it inside the mask. Set these to zero. (set values between [1,10] to 0)
ImageMath 3 $output/mtr_maps/corrected_mtr_maps/$(basename -s .mnc $mt)_mtr_map_imagemath_corrected_thresholded.mnc ReplaceVoxelValue $output/mtr_maps/corrected_mtr_maps/$(basename -s .mnc $mt)_mtr_map_imagemath_corrected.mnc 1 10 0
ImageMath 3 $output/mtr_maps_denoised/corrected_mtr_maps_denoised/$(basename -s .mnc $mt)_mtr_map_imagemath_denoised_corrected_thresholded.mnc ReplaceVoxelValue $output/mtr_maps_denoised/corrected_mtr_maps_denoised/$(basename -s .mnc $mt)_mtr_map_imagemath_denoised_corrected.mnc 1 10 0

#store summary metrics (such as the mean and standard deviation within the corpus callosum mask) in a csv. These values are later used for comparison to histology.
file1=$output/mtr_maps/corrected_mtr_maps/$(basename -s .mnc $mt)_mtr_map_imagemath_corrected_thresholded.mnc
mask1=$output/subject_specific_tissue_masks/${basename}_mask_cc.mnc
subject=${basename}
mean=$(mincstats -mean -quiet -mask  $mask1 -mask_floor 1 $file1)
stddev=$(mincstats -stddev -quiet -mask  $mask1 -mask_floor 1 $file1)
echo $subject, $mean, $stddev >> $output/mtr_means_cc_for_correlation.csv

#store the summary metrics again, but this time for the denoised versions
if [ ! -f $output/mtr_means_cc_for_correlation_denoised.csv ]; then
        echo subject, mean, stddev >> $output/mtr_means_cc_for_correlation_denoised.csv
fi

file1=$output/mtr_maps_denoised/corrected_mtr_maps_denoised/$(basename -s .mnc $mt)_mtr_map_imagemath_denoised_corrected_thresholded.mnc
mask1=$output/subject_specific_tissue_masks/${basename}_mask_cc.mnc
subject=${basename}
mean=$(mincstats -mean -quiet -mask  $mask1 -mask_floor 1 $file1)
stddev=$(mincstats -stddev -quiet -mask  $mask1 -mask_floor 1 $file1)
echo $subject, $mean, $stddev >> $output/mtr_means_cc_for_correlation_denoised.csv


rm -rf $tmp_subject_dir
