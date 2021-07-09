#!/bin/bash
#this script is for creating MTR and B1 maps for the purpose of performing a B1-MTR linear regression
#TIP: create a csv with the subject ids and paths to each of the input files
#all input folders should contain raw minc images named with the following convention coil_subjectid_mt_timepoint.mnc or coil_subjectid_pd_timepoint.mnc etc. Where timepoint is a single digit!
#usage:
#mtr_processing_main.sh output_folder MT_image1 MT_image2 MT_image3 MT_image4 MT_image5 MT_image6 PD_image b1_60 b1_120
# OUTPUT FOLDER SHOULD NOT HAVE A / AT THE END!
#it assumes that all 4 images were collected consecutively with no change in mouse positioning. Works with multiple MT images per mouse-coil combo but needs to be modified if want to use multiple pd images or b1 maps
#edited on july 7, 2021 to perform registration of all 6 acquisitions from a single subject to each other. This requires taking all 6 acquisitions as input. Do this after the MTR calculation. This will permit an accurate voxelwise linear regression.

module load minc-toolkit
module load minc-toolkit-extras
module load ANTs
source activate /home/cic/uromil/miniconda3/envs/mtr_processing_env

tmp_b1_subject_dir=$(mktemp -d)
tmp_subject_dir=$(mktemp -d)

atlas=${QUARANTINE_PATH}/resources/Dorr_2008_Steadman_2013_Ullmann_2013_Richards_2011_Qiu_2016_Egan_2015_40micron/ex-vivo/DSURQE_40micron.mnc
atlas_for_reg=${QUARANTINE_PATH}/resources/Dorr_2008_Steadman_2013_Ullmann_2013_Richards_2011_Qiu_2016_Egan_2015_40micron/100um/DSURQE.mnc
atlas_mask=${QUARANTINE_PATH}/resources/Dorr_2008_Steadman_2013_Ullmann_2013_Richards_2011_Qiu_2016_Egan_2015_40micron/100um/DSURQE_mask.mnc


#move all of the images into a subject-specific temp directory
output=$1
shift
mt1=$1
mt2=$2
mt3=$3
mt4=$4
mt5=$5
mt6=$6
pd=$7
b160=$8
b1120=$9

cp $1 $tmp_subject_dir
cp $2 $tmp_subject_dir
cp $3 $tmp_subject_dir
cp $4 $tmp_subject_dir
cp $5 $tmp_subject_dir
cp $6 $tmp_subject_dir
cp $7 $tmp_subject_dir
cp $8 $tmp_b1_subject_dir
cp $9 $tmp_b1_subject_dir

temp=$(basename $mt1)
basename=$(basename $(echo $temp | cut -c1-7)) #extracts the coil_subjectid (assumes that they are in the form xxx_xxx)
fa=$(basename $(echo $temp | cut -c12-15)) #extract flip angle
cp /data/chamal/projects/mila/2019_MTR_on_Cryoprobe/scripts_from_github/preprocess/bias_cor_minc.py $tmp_subject_dir/bias_cor_minc.py #this is so the intermediate outputs from the b1 bias field correction get put in the tmp directory

#first, preprocess all the images. denoised versions are also created to aid with registration later on.
mkdir -m a=rwx $output/preprocessed
mkdir -m a=rwx $output/denoised

#fix the orientation
#for file in $tmp_subject_dir/*; do /data/chamal/projects/mila/2019_MTR_on_Cryoprobe/scripts_from_github/preprocess/mouse-preprocessing-orientation.sh $file $output/preprocessed/$(basename -s .mnc $file)_processed.mnc; done
#for file in $tmp_b1_subject_dir/*; do /data/chamal/projects/mila/2019_MTR_on_Cryoprobe/scripts_from_github/preprocess/mouse-preprocessing-orientation.sh $file $output/preprocessed/$(basename -s .mnc $file)_processed.mnc; done

############################################################# Mask creation ################################################3
#mkdir -m a=rwx $output/masks
#mkdir -m a=rwx $output/subject_specific_tissue_masks
#mkdir -m a=rwx $output/transforms_subject_to_DSURQE

#N4 bias field correct all the MT-w images, and the PD-w image. This is to aid with registration, and will not be used during the computation of MTR maps.
#for file in $tmp_subject_dir/*; do /data/chamal/projects/mila/2019_MTR_on_Cryoprobe/scripts_from_github/preprocess/mouse-preprocessing-denoise-only.sh $output/preprocessed/$(basename -s .mnc $file)_processed.mnc $output/denoised/$(basename -s .mnc $file)_processed_denoised.mnc; done

#obtain whole-brain and nocsf masks in the mt1 space by registering to the DSURQE atlas, then inverting transform, then applying inverse transforms to the DSURQE mask
#/data/chamal/projects/mila/2019_MTR_on_Cryoprobe/scripts_from_github/preprocess/antsRegistration_affine_SyN.sh $output/denoised/$(basename -s .mnc $mt1)_processed_denoised.mnc $atlas_for_reg $atlas_mask $output/transforms_subject_to_DSURQE/${basename}-DSURQE
#antsApplyTransforms -d 3 -i /data/chamal/projects/mila/2019_MTR_on_Cryoprobe/resources_tissue_labels/DSURQE_100micron_mask_fixed_binary.mnc -t $output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_1_inverse_NL.xfm -t [$output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_0_GenericAffine.xfm,1] -n GenericLabel -o $output/masks/${basename}_mask_nocsf.mnc --verbose -r $output/denoised/$(basename -s .mnc $mt1)_processed_denoised.mnc
#antsApplyTransforms -d 3 -i /data/chamal/projects/mila/2019_MTR_on_Cryoprobe/resources_tissue_labels/DSURQE_100micron_mask.mnc -t $output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_1_inverse_NL.xfm -t [$output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_0_GenericAffine.xfm,1] -n GenericLabel -o $output/masks/${basename}_mask_full.mnc --verbose -r $output/denoised/$(basename -s .mnc $mt1)_processed_denoised.mnc

#warp the other masks (corpus callosum, wm, gm) to the subject file as well
#antsApplyTransforms -d 3 -i /data/chamal/projects/mila/2019_MTR_on_Cryoprobe/resources_tissue_labels/DSURQE_100micron_gm.mnc -t $output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_1_inverse_NL.xfm -t [$output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_0_GenericAffine.xfm,1] -n GenericLabel -o $output/subject_specific_tissue_masks/${basename}_mask_gm.mnc --verbose -r $output/denoised/$(basename -s .mnc $2)_processed_denoised.mnc
#antsApplyTransforms -d 3 -i /data/chamal/projects/mila/2019_MTR_on_Cryoprobe/resources_tissue_labels/DSURQE_100micron_wm.mnc -t $output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_1_inverse_NL.xfm -t [$output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_0_GenericAffine.xfm,1] -n GenericLabel -o $output/subject_specific_tissue_masks/${basename}_mask_wm.mnc --verbose -r $output/denoised/$(basename -s .mnc $2)_processed_denoised.mnc
#antsApplyTransforms -d 3 -i /data/chamal/projects/mila/2019_MTR_on_Cryoprobe/resources_tissue_labels/cc_mask_100micron.mnc -t $output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_1_inverse_NL.xfm -t [$output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_0_GenericAffine.xfm,1] -n GenericLabel -o $output/subject_specific_tissue_masks/${basename}_mask_cc.mnc --verbose -r $output/denoised/$(basename -s .mnc $2)_processed_denoised.mnc

#create eroded masks to be sure that you're not including any csf in your mtr map (may affect calibration). since the original nocsf masks yield small ventricles.
#mkdir -m a=rwx $output/masks_eroded
#mincmorph -erosion $output/masks/${basename}_mask_nocsf.mnc $output/masks_eroded/${basename}_mask_nocsf_eroded.mnc

############################################################### Registration of all MT and PD acquisition within a single subject (register to MT1, which has largest FA) ####################################
mkdir -m a=rwx $output/transforms_subject_acq_to_mt1

#register all other mt-w images and pd-w image to the mt-w image with largest FA (mt1)
#/data/chamal/projects/mila/2019_MTR_on_Cryoprobe/scripts_from_github/preprocess/antsRegistration_affine_SyN.sh $output/denoised/$(basename -s .mnc $mt2)_processed_denoised.mnc $output/denoised/$(basename -s .mnc $mt1)_processed_denoised.mnc $output/masks/${basename}_mask_full.mnc $output/transforms_subject_acq_to_mt1/${basename}_mt2-mt1
#/data/chamal/projects/mila/2019_MTR_on_Cryoprobe/scripts_from_github/preprocess/antsRegistration_affine_SyN.sh $output/denoised/$(basename -s .mnc $mt3)_processed_denoised.mnc $output/denoised/$(basename -s .mnc $mt1)_processed_denoised.mnc $output/masks/${basename}_mask_full.mnc $output/transforms_subject_acq_to_mt1/${basename}_mt3-mt1
#/data/chamal/projects/mila/2019_MTR_on_Cryoprobe/scripts_from_github/preprocess/antsRegistration_affine_SyN.sh $output/denoised/$(basename -s .mnc $mt4)_processed_denoised.mnc $output/denoised/$(basename -s .mnc $mt1)_processed_denoised.mnc $output/masks/${basename}_mask_full.mnc $output/transforms_subject_acq_to_mt1/${basename}_mt4-mt1
#/data/chamal/projects/mila/2019_MTR_on_Cryoprobe/scripts_from_github/preprocess/antsRegistration_affine_SyN.sh $output/denoised/$(basename -s .mnc $mt5)_processed_denoised.mnc $output/denoised/$(basename -s .mnc $mt1)_processed_denoised.mnc $output/masks/${basename}_mask_full.mnc $output/transforms_subject_acq_to_mt1/${basename}_mt5-mt1
#/data/chamal/projects/mila/2019_MTR_on_Cryoprobe/scripts_from_github/preprocess/antsRegistration_affine_SyN.sh $output/denoised/$(basename -s .mnc $mt6)_processed_denoised.mnc $output/denoised/$(basename -s .mnc $mt1)_processed_denoised.mnc $output/masks/${basename}_mask_full.mnc $output/transforms_subject_acq_to_mt1/${basename}_mt6-mt1
#/data/chamal/projects/mila/2019_MTR_on_Cryoprobe/scripts_from_github/preprocess/antsRegistration_affine_SyN.sh $output/denoised/$(basename -s .mnc $pd)_processed_denoised.mnc $output/denoised/$(basename -s .mnc $mt1)_processed_denoised.mnc $output/masks/${basename}_mask_full.mnc $output/transforms_subject_acq_to_mt1/${basename}_pd-mt1

#Denoise the mt and pd acquisitions using non-local means denoising 
#mkdir -m a=rwx $output/nonlocal_means_denoised
#for file in $tmp_subject_dir/*; do DenoiseImage -d 3 -i $output/preprocessed/$(basename -s .mnc $file)_processed.mnc -n Rician -x $output/masks/${basename}_mask_full.mnc --verbose -o $output/nonlocal_means_denoised/$(basename -s .mnc $file)_denoised_ants.mnc; done

#Create MTR maps in native space
#mkdir -m a=rwx $output/mtr_maps_denoised_ants_eroded_native_space
#for file in $tmp_subject_dir/*mt*; do ImageMath 3 $output/mtr_maps_denoised_ants_eroded_native_space/$(basename -s .mnc $file)_mtr_map_imagemath_denoised_eroded.mnc MTR $output/nonlocal_means_denoised/$(basename -s .mnc $pd)_denoised_ants.mnc $output/nonlocal_means_denoised/$(basename -s .mnc $file)_denoised_ants.mnc $output/masks_eroded/${basename}_mask_nocsf_eroded.mnc; done

#Apply transforms to the MTR maps to bring them all into mt1 space
mkdir -m a=rwx $output/mtr_maps_denoised_ants_eroded_mt1_space
#antsApplyTransforms -d 3 -i $output/mtr_maps_denoised_ants_eroded_native_space/$(basename -s .mnc $mt2)_mtr_map_imagemath_denoised_eroded.mnc -t $output/transforms_subject_acq_to_mt1/${basename}_mt2-mt1_output_0_GenericAffine.xfm -t $output/transforms_subject_acq_to_mt1/${basename}_mt2-mt1_output_1_NL.xfm -o $output/mtr_maps_denoised_ants_eroded_mt1_space/$(basename -s .mnc $mt2)_mtr_map_imagemath_denoised_eroded_mt1_space.mnc --verbose -r $output/denoised/$(basename -s .mnc $mt1)_processed_denoised.mnc
#antsApplyTransforms -d 3 -i $output/mtr_maps_denoised_ants_eroded_native_space/$(basename -s .mnc $mt3)_mtr_map_imagemath_denoised_eroded.mnc -t $output/transforms_subject_acq_to_mt1/${basename}_mt3-mt1_output_0_GenericAffine.xfm -t $output/transforms_subject_acq_to_mt1/${basename}_mt3-mt1_output_1_NL.xfm -o $output/mtr_maps_denoised_ants_eroded_mt1_space/$(basename -s .mnc $mt3)_mtr_map_imagemath_denoised_eroded_mt1_space.mnc --verbose -r $output/denoised/$(basename -s .mnc $mt1)_processed_denoised.mnc
#antsApplyTransforms -d 3 -i $output/mtr_maps_denoised_ants_eroded_native_space/$(basename -s .mnc $mt4)_mtr_map_imagemath_denoised_eroded.mnc -t $output/transforms_subject_acq_to_mt1/${basename}_mt4-mt1_output_0_GenericAffine.xfm -t $output/transforms_subject_acq_to_mt1/${basename}_mt4-mt1_output_1_NL.xfm -o $output/mtr_maps_denoised_ants_eroded_mt1_space/$(basename -s .mnc $mt4)_mtr_map_imagemath_denoised_eroded_mt1_space.mnc --verbose -r $output/denoised/$(basename -s .mnc $mt1)_processed_denoised.mnc
#antsApplyTransforms -d 3 -i $output/mtr_maps_denoised_ants_eroded_native_space/$(basename -s .mnc $mt5)_mtr_map_imagemath_denoised_eroded.mnc -t $output/transforms_subject_acq_to_mt1/${basename}_mt5-mt1_output_0_GenericAffine.xfm -t $output/transforms_subject_acq_to_mt1/${basename}_mt5-mt1_output_1_NL.xfm -o $output/mtr_maps_denoised_ants_eroded_mt1_space/$(basename -s .mnc $mt5)_mtr_map_imagemath_denoised_eroded_mt1_space.mnc --verbose -r $output/denoised/$(basename -s .mnc $mt1)_processed_denoised.mnc
#antsApplyTransforms -d 3 -i $output/mtr_maps_denoised_ants_eroded_native_space/$(basename -s .mnc $mt6)_mtr_map_imagemath_denoised_eroded.mnc -t $output/transforms_subject_acq_to_mt1/${basename}_mt6-mt1_output_0_GenericAffine.xfm -t $output/transforms_subject_acq_to_mt1/${basename}_mt6-mt1_output_1_NL.xfm -o $output/mtr_maps_denoised_ants_eroded_mt1_space/$(basename -s .mnc $mt6)_mtr_map_imagemath_denoised_eroded_mt1_space.mnc --verbose -r $output/denoised/$(basename -s .mnc $mt1)_processed_denoised.mnc
#cp $output/mtr_maps_denoised_ants_eroded_native_space/$(basename -s .mnc $mt1)_mtr_map_imagemath_denoised_eroded.mnc $output/mtr_maps_denoised_ants_eroded_mt1_space/$(basename -s .mnc $mt1)_mtr_map_imagemath_denoised_eroded_mt1_space.mnc

############################################################### Registration of B1 acquisitions to MT within subject (register to MT1, which has largest FA) ####################################

#perform bias field correction of the b1_120 acquisition first (assumes that the mask registered to mt1 applies well to b1-120 as well)
python $tmp_subject_dir/bias_cor_minc.py $output/preprocessed/$(basename -s .mnc $b1120)_processed.mnc $output/denoised/$(basename -s .mnc $mt1)_processed_denoised.mnc $output/masks/${basename}_mask_full.mnc /data/chamal/projects/mila/2019_MTR_on_Cryoprobe/scripts_from_github/preprocess/antsRegistration_rigid.sh $output/denoised/$(basename -s .mnc $b1120)_processed_denoised.mnc

#register the denoised b1 acquisition to mt1
mkdir -m a=rwx $output/b1_maps
mkdir -m a=rwx $output/b1_maps/registered_b1_to_mtr
/data/chamal/projects/mila/2019_MTR_on_Cryoprobe/scripts_from_github/preprocess/antsRegistration_affine_SyN.sh $output/denoised/$(basename -s .mnc $b1120)_processed_denoised.mnc $output/denoised/$(basename -s .mnc $mt1)_processed_denoised.mnc $output/masks/${basename}_mask_full.mnc $output/b1_maps/registered_b1_to_mtr/${basename}_b1_120-${basename}_mt_1045

#Create B1 maps
minccalc -expression 'acos(A[1]/(2*A[0]))*(180/(4*atan(1)))' $output/preprocessed/$(basename -s .mnc $b160)_processed.mnc $output/preprocessed/$(basename -s .mnc $b1120)_processed.mnc $output/b1_maps/${basename}_b1_map.mnc

#Apply transforms to the B1 map
antsApplyTransforms -d 3 -i $output/b1_maps/${basename}_b1_map.mnc -t $output/b1_maps/registered_b1_to_mtr/${basename}_b1_120-${basename}_mt_1045_output_0_GenericAffine.xfm -t $output/b1_maps/registered_b1_to_mtr/${basename}_b1_120-${basename}_mt_1045_output_1_NL.xfm -o $output/b1_maps/registered_b1_to_mtr/${basename}_b1_map_registered.mnc --verbose -r $output/denoised/$(basename -s .mnc $mt1)_processed_denoised.mnc

#normalize b1 map using a value of 60
mkdir -m a=rwx $output/b1_maps/normalized_and_registered_b1/
minccalc -expression "A[0]/60" $output/b1_maps/registered_b1_to_mtr/${basename}_b1_map_registered.mnc $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc
######################################################################### Create mask based on B1 field strength ###############################################################

#create a mask according to the b1 map (only exists where b1 map is between 0.8 and 1). Do this by first masking b1_map with no_csf eroded mask, cut off cerebellum (can be noisy) then threshold to 0.8-1.
mkdir -m a=rwx $output/b1_maps/tmp/
mkdir -m a=rwx $output/b1_maps/normalized_and_registered_b1/masked_norm_reg_b1/
mkdir -m a=rwx $output/b1_maps/normalized_and_registered_b1/thresholded_mask_norm_reg_b1/
mincmath -clobber -mult $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc $output/masks_eroded/${basename}_mask_nocsf_eroded.mnc $output/b1_maps/tmp/${basename}_b1_map_reg_norm_masked_tmp.mnc
mincmath -clobber -mult $output/b1_maps/tmp/${basename}_b1_map_reg_norm_masked_tmp.mnc /data/chamal/projects/mila/2019_Magnetization_Transfer/tissue_labels/cerebellum_antimask_large.mnc $output/b1_maps/tmp/${basename}_b1_map_reg_norm_mask_cerebellum.mnc
mincmath -clobber -mult $output/b1_maps/tmp/${basename}_b1_map_reg_norm_mask_cerebellum.mnc /data/chamal/projects/mila/2019_Magnetization_Transfer/tissue_labels/ghosting_antimask.mnc $output/b1_maps/normalized_and_registered_b1/masked_norm_reg_b1/${basename}_b1_map_reg_norm_mask.mnc
mincmath -clobber -const2 0.8 1 -segment $output/b1_maps/normalized_and_registered_b1/masked_norm_reg_b1/${basename}_b1_map_reg_norm_mask.mnc $output/b1_maps/normalized_and_registered_b1/thresholded_mask_norm_reg_b1/${basename}_b1_map_reg_norm_mask_thresh_0.9_to_1.mnc

rm -rf $tmp_subject_dir
rm -rf $tmp_b1_subject_dir
