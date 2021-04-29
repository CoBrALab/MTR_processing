#!/bin/bash
#this script is for creating MTR and B1 maps 
#TIP: create a csv with the subject ids and paths to each of the input files
#all input folders should contain raw minc images named with the following convention coil_subjectid_mt_timepoint.mnc or coil_subjectid_pd_timepoint.mnc etc. Where timepoint is a single digit!
#usage:
#mtr_processing_main.sh output_folder MT_image PD_image b1_60 b1_120 OUTPUT FOLDER SHOULD NOT HAVE A / AT THE END!
#it assumes that all 4 images were collected consecutively with no change in mouse positioning. Works with multiple MT images per mouse-coil combo but needs to be modified if want to use multiple pd images or b1 maps
#edited on nov 24, 2020 to include improved b1 bias field correction script

#don't run module load commands when on home computer
module load minc-toolkit
module load minc-toolkit-extras
source activate /home/cic/uromil/miniconda3/envs/mtr_processing_env

tmp_subject_dir=$(mktemp -d)
atlas=${QUARANTINE_PATH}/resources/Dorr_2008_Steadman_2013_Ullmann_2013_Richards_2011_Qiu_2016_Egan_2015_40micron/ex-vivo/DSURQE_40micron.mnc
atlas_for_reg=${QUARANTINE_PATH}/resources/Dorr_2008_Steadman_2013_Ullmann_2013_Richards_2011_Qiu_2016_Egan_2015_40micron/100um/DSURQE.mnc
atlas_mask=${QUARANTINE_PATH}/resources/Dorr_2008_Steadman_2013_Ullmann_2013_Richards_2011_Qiu_2016_Egan_2015_40micron/100um/DSURQE_mask.mnc


#move all of the images into a subject-specific temp directory
cp $2 $tmp_subject_dir
cp $3 $tmp_subject_dir
cp $4 $tmp_subject_dir
cp $5 $tmp_subject_dir
output=$1
temp=$(basename $2)
basename=$(basename $(echo $temp | cut -c1-7)) #extracts the coil_subjectid (assumes that they are in the form xxx_xxx)
fa=$(basename $(echo $temp | cut -c12-15)) #extract flip angle
cp /data/chamal/projects/mila/2019_Magnetization_Transfer/scripts/bias_cor_minc.py $tmp_subject_dir/bias_cor_minc.py #this is so the intermediate outputs from the b1 bias field correction get put in the tmp directory

#first, preprocess all the images. denoised versions are also created to aid with registration later on.
mkdir -m a=rwx $output/preprocessed
mkdir -m a=rwx $output/denoised
mkdir -m a=rwx $output/masks
mkdir -m a=rwx $output/transforms_subject_to_DSURQE
mkdir -m a=rwx $output/subject_specific_tissue_masks

if test -f $output/preprocessed/*${basename}*pd*; then rm $tmp_subject_dir/*pd*; fi
if test -f $output/preprocessed/*${basename}*b1*60*; then rm $tmp_subject_dir/*b1*; fi

#fix the orientation
#for file in $tmp_subject_dir/*; do /data/chamal/projects/mila/2019_Magnetization_Transfer/scripts/mouse-preprocessing-orientation.sh $file $output/preprocessed/$(basename -s .mnc $file)_processed.mnc; done
#45
#Create B1 maps
mkdir -m a=rwx $output/b1_maps
mkdir -m a=rwx $output/b1_maps/registered_b1_to_mtr
minccalc -expression 'acos(A[1]/(2*A[0]))*(180/(4*atan(1)))' $output/preprocessed/$(basename -s .mnc $4)_processed.mnc $output/preprocessed/$(basename -s .mnc $5)_processed.mnc $output/b1_maps/${basename}_b1_map.mnc

#N4 denoise only 1 mt files, and use it to create mask by registering denoised mt file to DSURQE then inverting transform, then applying inverse transforms to the DSURQE mask. This only needs to be done once per subject.
#the warped image given as an output shows the mt file in the atlas space
if [ ! -f $output/masks/*${basename}* ]; then
	/data/chamal/projects/mila/2019_Magnetization_Transfer/scripts/mouse-preprocessing-denoise-only.sh $output/preprocessed/$(basename -s .mnc $2)_processed.mnc $output/denoised/$(basename -s .mnc $2)_processed_denoised.mnc
	/data/chamal/projects/mila/2019_Magnetization_Transfer/scripts/antsRegistration_affine_SyN_rabies.sh $output/denoised/$(basename -s .mnc $2)_processed_denoised.mnc $atlas_for_reg $atlas_mask $output/transforms_subject_to_DSURQE/${basename}-DSURQE
	antsApplyTransforms -d 3 -i /data/chamal/projects/mila/2019_Magnetization_Transfer/tissue_labels/DSURQE_100micron_mask_fixed_binary.mnc -t $output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_1_inverse_NL.xfm -t [$output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_0_GenericAffine.xfm,1] -n GenericLabel -o $output/masks/${basename}_mask_nocsf.mnc --verbose -r $output/denoised/$(basename -s .mnc $2)_processed_denoised.mnc
	antsApplyTransforms -d 3 -i /data/chamal/projects/mila/2019_Magnetization_Transfer/tissue_labels/DSURQE_100micron_mask.mnc -t $output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_1_inverse_NL.xfm -t [$output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_0_GenericAffine.xfm,1] -n GenericLabel -o $output/masks/${basename}_mask_full.mnc --verbose -r $output/denoised/$(basename -s .mnc $2)_processed_denoised.mnc
else
	echo "Appropriate mask already exists"
fi
#61
#also perform registration of the b1 acquisition to the mtr map only once. This requires first doing good bias field correction of the b1_120 acquisition
if [ ! -f $output/denoised/*${basename}*b1* ]; then
	#/data/chamal/projects/mila/2019_Magnetization_Transfer/scripts/helper_scripts/iter_bias_cor.sh $output/preprocessed/$(basename -s .mnc $5)_processed.mnc $output/denoised/$(basename -s .mnc $2)_processed_denoised.mnc  $output/masks/${basename}_mask_full.mnc $output/denoised/$(basename -s .mnc $5)_processed_denoised.mnc
	python $tmp_subject_dir/bias_cor_minc.py $output/preprocessed/$(basename -s .mnc $5)_processed.mnc $output/denoised/$(basename -s .mnc $2)_processed_denoised.mnc $output/masks/${basename}_mask_full.mnc /data/chamal/projects/mila/2019_Magnetization_Transfer/scripts/helper_scripts/antsRegistration_rigid.sh $output/denoised/$(basename -s .mnc $5)_processed_denoised.mnc
else
	echo "Appropriate denoised b1 acquisition already exists"
fi

if [ ! -f $output/b1_maps/registered_b1_to_mtr/*${basename}* ]; then
#	/data/chamal/projects/mila/2019_Magnetization_Transfer/scripts/helper_scripts/antsRegistration_rigid.sh $output/denoised/$(basename -s .mnc $5)_processed_denoised.mnc $output/denoised/$(basename -s .mnc $2)_processed_denoised.mnc $output/masks/${basename}_mask_full.mnc $output/b1_maps/registered_b1_to_mtr/${basename}_b1_120-${basename}_mt_1045
	/data/chamal/projects/mila/2019_Magnetization_Transfer/scripts/antsRegistration_affine_SyN_rabies.sh $output/denoised/$(basename -s .mnc $5)_processed_denoised.mnc $output/denoised/$(basename -s .mnc $2)_processed_denoised.mnc $output/masks/${basename}_mask_full.mnc $output/b1_maps/registered_b1_to_mtr/${basename}_b1_120-${basename}_mt_1045
	antsApplyTransforms -d 3 -i $output/b1_maps/${basename}_b1_map.mnc -t $output/b1_maps/registered_b1_to_mtr/${basename}_b1_120-${basename}_mt_1045_output_0_GenericAffine.xfm -t $output/b1_maps/registered_b1_to_mtr/${basename}_b1_120-${basename}_mt_1045_output_1_NL.xfm -o $output/b1_maps/registered_b1_to_mtr/${basename}_b1_map_registered.mnc --verbose -r $output/denoised/$(basename -s .mnc $2)_processed_denoised.mnc
else
	echo "Appropriate registered b1 map already exists"
fi
#71
#warp the other masks (corpus callosum, wm, gm) to the subject file as well
antsApplyTransforms -d 3 -i /data/chamal/projects/mila/2019_Magnetization_Transfer/tissue_labels/DSURQE_100micron_gm.mnc -t $output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_1_inverse_NL.xfm -t [$output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_0_GenericAffine.xfm,1] -n GenericLabel -o $output/subject_specific_tissue_masks/${basename}_mask_gm.mnc --verbose -r $output/denoised/$(basename -s .mnc $2)_processed_denoised.mnc
antsApplyTransforms -d 3 -i /data/chamal/projects/mila/2019_Magnetization_Transfer/tissue_labels/DSURQE_100micron_wm.mnc -t $output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_1_inverse_NL.xfm -t [$output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_0_GenericAffine.xfm,1] -n GenericLabel -o $output/subject_specific_tissue_masks/${basename}_mask_wm.mnc --verbose -r $output/denoised/$(basename -s .mnc $2)_processed_denoised.mnc
antsApplyTransforms -d 3 -i /data/chamal/projects/mila/2019_Magnetization_Transfer/tissue_labels/cc_mask_100micron.mnc -t $output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_1_inverse_NL.xfm -t [$output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_0_GenericAffine.xfm,1] -n GenericLabel -o $output/subject_specific_tissue_masks/${basename}_mask_cc.mnc --verbose -r $output/denoised/$(basename -s .mnc $2)_processed_denoised.mnc

#create eroded masks to be sure that you're not including any csf in your mtr map (may affect calibration). since the original nocsf masks yield small ventricles.
mkdir -m a=rwx $output/masks_eroded
if [ ! -f $output/masks_eroded/*${basename}* ]; then
	mincmorph -erosion $output/masks/${basename}_mask_nocsf.mnc $output/masks_eroded/${basename}_mask_nocsf_eroded.mnc
else
       echo "Appropriate mask already exists"
fi
#84
#now do image denoising using non-local-means, once for pd and once for mt images
mkdir -m a=rwx $output/nonlocal_means_denoised
DenoiseImage -d 3 -i $output/preprocessed/$(basename -s .mnc $2)_processed.mnc -n Rician -x $output/masks/${basename}_mask_full.mnc --verbose -o $output/nonlocal_means_denoised/$(basename -s .mnc $2)_denoised_ants.mnc
DenoiseImage -d 3 -i $output/preprocessed/$(basename -s .mnc $3)_processed.mnc -n Rician -x $output/masks/${basename}_mask_full.mnc --verbose -o $output/nonlocal_means_denoised/$(basename -s .mnc $3)_denoised_ants.mnc

#create MTR maps
mkdir -m a=rwx $output/mtr_maps
mkdir -m a=rwx $output/mtr_maps_eroded
ImageMath 3 $output/mtr_maps_eroded/$(basename -s .mnc $2)_mtr_map_imagemath_eroded.mnc MTR $output/preprocessed/$(basename -s .mnc $3)_processed.mnc $output/preprocessed/$(basename -s .mnc $2)_processed.mnc $output/masks_eroded/${basename}_mask_nocsf_eroded.mnc
ImageMath 3 $output/mtr_maps/$(basename -s .mnc $2)_mtr_map_imagemath.mnc MTR $output/preprocessed/$(basename -s .mnc $3)_processed.mnc $output/preprocessed/$(basename -s .mnc $2)_processed.mnc $output/masks/${basename}_mask_nocsf.mnc

#create denoised MTR maps too
mkdir -m a=rwx $output/mtr_maps_denoised_ants
mkdir -m a=rwx $output/mtr_maps_denoised_ants_eroded
ImageMath 3 $output/mtr_maps_denoised_ants/$(basename -s .mnc $2)_mtr_map_imagemath_denoised.mnc MTR $output/nonlocal_means_denoised/$(basename -s .mnc $3)_denoised_ants.mnc $output/nonlocal_means_denoised/$(basename -s .mnc $2)_denoised_ants.mnc $output/masks/${basename}_mask_nocsf.mnc
ImageMath 3 $output/mtr_maps_denoised_ants_eroded/$(basename -s .mnc $2)_mtr_map_imagemath_denoised_eroded.mnc MTR $output/nonlocal_means_denoised/$(basename -s .mnc $3)_denoised_ants.mnc $output/nonlocal_means_denoised/$(basename -s .mnc $2)_denoised_ants.mnc $output/masks_eroded/${basename}_mask_nocsf_eroded.mnc
#101
#normalize b1 map using a value of 60
mkdir -m a=rwx $output/b1_maps/normalized_and_registered_b1/
minccalc -expression "A[0]/60" $output/b1_maps/registered_b1_to_mtr/${basename}_b1_map_registered.mnc $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc

#create a mask according to the b1 map (only exists where b1 map is between 0.9 and 1). Do this by first masking b1_map with no_csf eroded mask, cut off cerebellum (can be noisy) then threshold to 0.85-1.
#Do this only once per subject
mkdir -m a=rwx $output/b1_maps/tmp/
mkdir -m a=rwx $output/b1_maps/normalized_and_registered_b1/masked_norm_reg_b1/
mkdir -m a=rwx $output/b1_maps/normalized_and_registered_b1/thresholded_mask_norm_reg_b1/
if [ ! -f $output/b1_maps/normalized_and_registered_b1/thresholded_mask_norm_reg_b1/*${basename}* ]; then
	mincmath -clobber -mult $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc $output/masks_eroded/${basename}_mask_nocsf_eroded.mnc $output/b1_maps/tmp/${basename}_b1_map_reg_norm_masked_tmp.mnc
	mincmath -clobber -mult $output/b1_maps/tmp/${basename}_b1_map_reg_norm_masked_tmp.mnc /data/chamal/projects/mila/2019_Magnetization_Transfer/tissue_labels/cerebellum_antimask_large.mnc $output/b1_maps/tmp/${basename}_b1_map_reg_norm_mask_cerebellum.mnc
	mincmath -clobber -mult $output/b1_maps/tmp/${basename}_b1_map_reg_norm_mask_cerebellum.mnc /data/chamal/projects/mila/2019_Magnetization_Transfer/tissue_labels/ghosting_antimask.mnc $output/b1_maps/normalized_and_registered_b1/masked_norm_reg_b1/${basename}_b1_map_reg_norm_mask.mnc
	mincmath -clobber -const2 0.9 1 -segment $output/b1_maps/normalized_and_registered_b1/masked_norm_reg_b1/${basename}_b1_map_reg_norm_mask.mnc $output/b1_maps/normalized_and_registered_b1/thresholded_mask_norm_reg_b1/${basename}_b1_map_reg_norm_mask_thresh_0.9_to_1.mnc
else
	echo "Appropriate b1 mask already exists"
fi

#create mtr maps that are masked according to the b1 map (ie the mtr map only exists when b1 field is between 0.9 and 1)
#THIS STEP ISN'T ENTIRELY NECESSARY - JUST FOR CONVENIENCE OF VISUALIZING THE VOXEL-WISE SLOPE REGRESSION RESULTS WITHIN THE MASK
mkdir -m a=rwx $output/mtr_maps/masked_by_b1/
mkdir -m a=rwx $output/mtr_maps_eroded/masked_by_b1/
mkdir -m a=rwx $output/mtr_maps_denoised_ants/masked_by_b1/
mkdir -m a=rwx $output/mtr_maps_denoised_ants_eroded/masked_by_b1/
mincmath -mult -clobber $output/b1_maps/normalized_and_registered_b1/thresholded_mask_norm_reg_b1/${basename}_b1_map_reg_norm_mask_thresh_0.9_to_1.mnc $output/mtr_maps/$(basename -s .mnc $2)_mtr_map_imagemath.mnc $output/mtr_maps/masked_by_b1/$(basename -s .mnc $2)_mtr_map_imagemath_b1_mask.mnc
mincmath -mult -clobber $output/b1_maps/normalized_and_registered_b1/thresholded_mask_norm_reg_b1/${basename}_b1_map_reg_norm_mask_thresh_0.9_to_1.mnc $output/mtr_maps_denoised_ants_eroded/$(basename -s .mnc $2)_mtr_map_imagemath_denoised_eroded.mnc $output/mtr_maps_denoised_ants_eroded/masked_by_b1/$(basename -s .mnc $2)_mtr_map_imagemath_denoised_eroded_b1_mask.mnc
mincmath -mult -clobber $output/b1_maps/normalized_and_registered_b1/thresholded_mask_norm_reg_b1/${basename}_b1_map_reg_norm_mask_thresh_0.9_to_1.mnc $output/mtr_maps_denoised_ants/$(basename -s .mnc $2)_mtr_map_imagemath_denoised.mnc $output/mtr_maps_denoised_ants/masked_by_b1/$(basename -s .mnc $2)_mtr_map_imagemath_denoised_b1_mask.mnc
mincmath -mult -clobber $output/b1_maps/normalized_and_registered_b1/thresholded_mask_norm_reg_b1/${basename}_b1_map_reg_norm_mask_thresh_0.9_to_1.mnc $output/mtr_maps_eroded/$(basename -s .mnc $2)_mtr_map_imagemath_eroded.mnc $output/mtr_maps_eroded/masked_by_b1/$(basename -s .mnc $2)_mtr_map_imagemath_eroded_b1_mask.mnc

#130
#create summary csv with mean and std of each mtr map, masked according to b1
if [ ! -f $output/mtr_maps/masked_by_b1/calib_means_mtr_maps_b1_mask.csv ]; then
	echo subject, FA, mean, stddev >> $output/mtr_maps/masked_by_b1/calib_means_mtr_maps_b1_mask.csv
	echo subject, FA, mean, stddev >> $output/mtr_maps_eroded/masked_by_b1/calib_means_mtr_maps_eroded_b1_mask.csv
	echo subject, FA, mean, stddev >> $output/mtr_maps_denoised_ants/masked_by_b1/calib_means_mtr_maps_denoised_b1_mask.csv
	echo subject, FA, mean, stddev >> $output/mtr_maps_denoised_ants_eroded/masked_by_b1/calib_means_mtr_maps_denoised_eroded_b1_mask.csv
fi

file1=$output/mtr_maps/masked_by_b1/$(basename -s .mnc $2)_mtr_map_imagemath_b1_mask.mnc
mask1=$output/b1_maps/normalized_and_registered_b1/thresholded_mask_norm_reg_b1/${basename}_b1_map_reg_norm_mask_thresh_0.9_to_1.mnc
subject=${basename}
mean=$(mincstats -mean -quiet -mask  $mask1 -mask_floor 1 $file1)
stddev=$(mincstats -stddev -quiet -mask  $mask1 -mask_floor 1 $file1)
echo $subject, $fa, $mean, $stddev >> $output/mtr_maps/masked_by_b1/calib_means_mtr_maps_b1_mask.csv
##
file1=$output/mtr_maps_eroded/masked_by_b1/$(basename -s .mnc $2)_mtr_map_imagemath_eroded_b1_mask.mnc
mean=$(mincstats -mean -quiet -mask  $mask1 -mask_floor 1 $file1)
stddev=$(mincstats -stddev -quiet -mask  $mask1 -mask_floor 1 $file1)
echo $subject, $fa, $mean, $stddev >> $output/mtr_maps_eroded/masked_by_b1/calib_means_mtr_maps_eroded_b1_mask.csv

file1=$output/mtr_maps_denoised_ants/masked_by_b1/$(basename -s .mnc $2)_mtr_map_imagemath_denoised_b1_mask.mnc
mean=$(mincstats -mean -quiet -mask  $mask1 -mask_floor 1 $file1)
stddev=$(mincstats -stddev -quiet -mask  $mask1 -mask_floor 1 $file1)
echo $subject, $fa, $mean, $stddev  >> $output/mtr_maps_denoised_ants/masked_by_b1/calib_means_mtr_maps_denoised_b1_mask.csv

file1=$output/mtr_maps_denoised_ants_eroded/masked_by_b1/$(basename -s .mnc $2)_mtr_map_imagemath_denoised_eroded_b1_mask.mnc
mean=$(mincstats -mean -quiet -mask  $mask1 -mask_floor 1 $file1)
stddev=$(mincstats -stddev -quiet -mask  $mask1 -mask_floor 1 $file1)
echo $subject, $fa, $mean, $stddev >> $output/mtr_maps_denoised_ants_eroded/masked_by_b1/calib_means_mtr_maps_denoised_eroded_b1_mask.csv



rm -rf $tmp_subject_dir
