#!/bin/bash
#this script is for creating MTR and B1 maps for the purpose of performing a B1-MTR linear regression
#TIP: create a csv with the subject ids and paths to each of the input files
#all input folders should contain raw minc images named with the following convention coil_subjectid_mt_timepoint.mnc or coil_subjectid_pd_timepoint.mnc etc. Where timepoint is a single digit!
#usage:
#mtr_processing_main.sh output_folder MT_image1 MT_image2 MT_image3 MT_image4 MT_image5 MT_image6 PD_image b1_60 b1_120
# OUTPUT FOLDER SHOULD NOT HAVE A / AT THE END!
#it assumes that all images were collected consecutively with no change in mouse positioning. Works with multiple MT images per mouse-coil combo but needs to be modified if want to use multiple pd images or b1 maps
#edited on july 7, 2021 to perform registration of all 6 acquisitions from a single subject to each other. This requires taking all 6 acquisitions as input. Do this after the MTR calculation. This will permit an accurate voxelwise linear regression.

module load minc-toolkit
module load minc-toolkit-extras
module load ANTs
source activate /home/cic/uromil/miniconda3/envs/mtr_processing_env

tmp_b1_subject_dir=$(mktemp -d)
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
shift
pd=$1
b160=$2
b1120=$3
mt1=$4
mt2=$5
mt3=$6
mt4=$7
mt5=$8
mt6=$9

cp $1 $tmp_subject_dir
cp $4 $tmp_subject_dir
cp $5 $tmp_subject_dir
cp $6 $tmp_subject_dir
cp $7 $tmp_subject_dir
cp $8 $tmp_subject_dir
cp $9 $tmp_subject_dir
cp $2 $tmp_b1_subject_dir
cp $3 $tmp_b1_subject_dir

temp=$(basename $mt1)
basename=$(basename $(echo $temp | cut -c1-7)) #extracts the coil_subjectid (assumes that they are in the form xxx_xxx)
fa=$(basename $(echo $temp | cut -c12-15)) #extract flip angle
coil_type=$(echo $basename | cut -c1-3)

#first, preprocess all the images. denoised versions are also created to aid with registration later on.
mkdir -m a=rwx $output/preprocessed
mkdir -m a=rwx $output/n4_bias_corrected
mkdir -m a=rwx $output/transforms_subject_to_DSURQE
mkdir -m a=rwx $output/masks_native_space
mkdir -m a=rwx $output/denoised_nonlocal_means
mkdir -m a=rwx $output/mtr_maps_native_space
mkdir -m a=rwx $output/mtr_maps_native_space/mtr_maps_native_space_denoised
mkdir -m a=rwx $output/mtr_maps_native_space/mtr_maps_native_space_nifti
mkdir -m a=rwx $output/mtr_maps_native_space/mtr_maps_native_space_denoised_nifti
mkdir -m a=rwx $output/transforms_subject_acq_to_mt1/
mkdir -m a=rwx $output/mtr_maps_mt1_space
mkdir -m a=rwx $output/mtr_maps_mt1_space/mtr_maps_mt1_space_denoised
mkdir -m a=rwx $output/mtr_maps_mt1_space/mtr_maps_mt1_space_denoised_normalized
mkdir -m a=rwx $output/mtr_maps_mt1_space/mtr_maps_mt1_space_denoised_normalized_masked_thresholded
mkdir -m a=rwx $output/mtr_maps_mt1_space/mtr_maps_mt1_space_normalized
mkdir -m a=rwx $output/mtr_maps_mt1_space/mtr_maps_mt1_space_normalized_masked_thresholded

mkdir -m a=rwx $output/masks_DSURQE

#fix the orientation
#for file in $tmp_subject_dir/*; do $scriptdir/helper/mouse-preprocessing-orientation.sh $file $output/preprocessed/$(basename -s .mnc $file)_processed.mnc; done
#for file in $tmp_b1_subject_dir/*; do $scriptdir/helper/mouse-preprocessing-orientation.sh $file $output/preprocessed/$(basename -s .mnc $file)_processed.mnc; done

############################################################# Registration of all MT and PD acquisitions to the DSURQE atlas ################################################
#N4 bias field correct all the MT-w images, and the PD-w image. This is to aid with registration, and will not be used during the computation of MTR maps.
#for file in $tmp_subject_dir/*; do $scriptdir/helper/mouse-preprocessing-denoise-only.sh $output/preprocessed/$(basename -s .mnc $file)_processed.mnc $output/n4_bias_corrected/$(basename -s .mnc $file)_processed_denoised.mnc; done

#register a single N4 corrected MT-w to DSURQE atlas
#$scriptdir/helper/antsRegistration_affine_SyN.sh $output/n4_bias_corrected/$(basename -s .mnc $mt1)_processed_denoised.mnc $atlas_for_reg $atlas_mask $output/transforms_subject_to_DSURQE/$(basename -s .mnc $mt1)-DSURQE

#Bring masks from DSURQE space into native space to help with non-local means denoising
#antsApplyTransforms -d 3 -i /data/chamal/projects/mila/2019_MTR_on_Cryoprobe/resources_tissue_labels/DSURQE_100micron_mask_fixed_binary.mnc -t [$output/transforms_subject_to_DSURQE/$(basename -s .mnc $mt1)-DSURQE_output_0_GenericAffine.xfm,1] -t $output/transforms_subject_to_DSURQE/$(basename -s .mnc $mt1)-DSURQE_output_1_inverse_NL.xfm -n GenericLabel -o $output/masks_native_space/${basename}_mask_nocsf.mnc --verbose -r $output/n4_bias_corrected/$(basename -s .mnc $mt1)_processed_denoised.mnc
#antsApplyTransforms -d 3 -i /data/chamal/projects/mila/2019_MTR_on_Cryoprobe/resources_tissue_labels/DSURQE_100micron_mask.mnc -t [$output/transforms_subject_to_DSURQE/$(basename -s .mnc $mt1)-DSURQE_output_0_GenericAffine.xfm,1] -t $output/transforms_subject_to_DSURQE/$(basename -s .mnc $mt1)-DSURQE_output_1_inverse_NL.xfm -n GenericLabel -o $output/masks_native_space/${basename}_mask_full.mnc --verbose -r $output/n4_bias_corrected/$(basename -s .mnc $mt1)_processed_denoised.mnc
#antsApplyTransforms -d 3 -i /data/chamal/projects/mila/2019_MTR_on_Cryoprobe/resources_tissue_labels/DSURQE_100micron_gm.mnc -t [$output/transforms_subject_to_DSURQE/$(basename -s .mnc $mt1)-DSURQE_output_0_GenericAffine.xfm,1] -t $output/transforms_subject_to_DSURQE/$(basename -s .mnc $mt1)-DSURQE_output_1_inverse_NL.xfm -n GenericLabel -o $output/masks_native_space/${basename}_mask_gm.mnc --verbose -r $output/n4_bias_corrected/$(basename -s .mnc $2)_processed_denoised.mnc
#antsApplyTransforms -d 3 -i /data/chamal/projects/mila/2019_MTR_on_Cryoprobe/resources_tissue_labels/DSURQE_100micron_wm.mnc -t [$output/transforms_subject_to_DSURQE/$(basename -s .mnc $mt1)-DSURQE_output_0_GenericAffine.xfm,1] -t $output/transforms_subject_to_DSURQE/$(basename -s .mnc $mt1)-DSURQE_output_1_inverse_NL.xfm -n GenericLabel -o $output/masks_native_space/${basename}_mask_wm.mnc --verbose -r $output/n4_bias_corrected/$(basename -s .mnc $2)_processed_denoised.mnc
#antsApplyTransforms -d 3 -i /data/chamal/projects/mila/2019_MTR_on_Cryoprobe/resources_tissue_labels/cc_mask_100micron.mnc -t [$output/transforms_subject_to_DSURQE/$(basename -s .mnc $mt1)-DSURQE_output_0_GenericAffine.xfm,1] -t $output/transforms_subject_to_DSURQE/$(basename -s .mnc $mt1)-DSURQE_output_1_inverse_NL.xfm -n GenericLabel -o $output/masks_native_space/${basename}_mask_cc.mnc --verbose -r $output/n4_bias_corrected/$(basename -s .mnc $2)_processed_denoised.mnc

#create eroded masks to be sure that you're not including any csf in your mtr map (may affect calibration). since the original nocsf masks yield small ventricles.
#mincmorph -erosion $output/masks_native_space/${basename}_mask_nocsf.mnc $output/masks_native_space/${basename}_mask_nocsf_eroded.mnc

#Denoise the mt and pd acquisitions using non-local means denoising
#for file in $tmp_subject_dir/*; do DenoiseImage -d 3 -i $output/preprocessed/$(basename -s .mnc $file)_processed.mnc -n Rician -x $output/masks_native_space/${basename}_mask_full.mnc --verbose -o $output/denoised_nonlocal_means/$(basename -s .mnc $file)_denoised_ants.mnc; done

#Create MTR maps in native space
#for file in $tmp_subject_dir/*mt*; do ImageMath 3 $output/mtr_maps_native_space/$(basename -s .mnc $file)_mtr_map_imagemath.mnc MTR $output/preprocessed/$(basename -s .mnc $pd)_processed.mnc $output/preprocessed/$(basename -s .mnc $file)_processed.mnc $output/masks_native_space/${basename}_mask_full.mnc; done
#for file in $tmp_subject_dir/*mt*; do ImageMath 3 $output/mtr_maps_native_space/mtr_maps_native_space_denoised/$(basename -s .mnc $file)_mtr_map_imagemath_denoised.mnc MTR $output/denoised_nonlocal_means/$(basename -s .mnc $pd)_denoised_ants.mnc $output/denoised_nonlocal_means/$(basename -s .mnc $file)_denoised_ants.mnc $output/masks_native_space/${basename}_mask_full.mnc; done

#convert the MTR maps to nifti for input into twolevel_dbm.
#for file in $tmp_subject_dir/*mt*; do mnc2nii $output/mtr_maps_native_space/$(basename -s .mnc $file)_mtr_map_imagemath.mnc $output/mtr_maps_native_space/mtr_maps_native_space_nifti/$(basename -s .mnc $file)_mtr_map_imagemath.nii; done
#for file in $tmp_subject_dir/*mt*; do mnc2nii $output/mtr_maps_native_space/mtr_maps_native_space_denoised/$(basename -s .mnc $file)_mtr_map_imagemath_denoised.mnc $output/mtr_maps_native_space/mtr_maps_native_space_denoised_nifti/$(basename -s .mnc $file)_mtr_map_imagemath_denoised.nii; done

#put the file names in a csv
if [ ! -f $output/mtr_map_nifti_list_for_dbm.csv ]; then
        echo subject, acq, path >> $output/mtr_map_nifti_list_for_dbm.csv
        echo subject, acq, path >> $output/mtr_map_denoised_nifti_list_for_dbm.csv
fi
for file in $tmp_subject_dir/*mt*; do echo ${basename}, $file, $output/mtr_maps_native_space/mtr_maps_native_space_nifti/$(basename -s .mnc $file)_mtr_map_imagemath.nii >> $output/mtr_map_nifti_list_for_dbm.csv; done
for file in $tmp_subject_dir/*mt*; do echo ${basename}, $file, $output/mtr_maps_native_space/mtr_maps_native_space_denoised_nifti/$(basename -s .mnc $file)_mtr_map_imagemath_denoised.nii >> $output/mtr_map_denoised_nifti_list_for_dbm.csv; done

############################################################# Mask creation ################################################3
#copy DSURQE masks into a convenient folder
#rsync -avz $atlas_nocsf_mask $output/masks_DSURQE/DSURQE_mask_no_csf.mnc
#rsync -avz $atlas_mask_200micron $output/masks_DSURQE/DSURQE_mask_full.mnc
#rsync -avz $atlas_gm_mask $output/masks_DSURQE/DSURQE_mask_gm.mnc
#rsync -avz $atlas_wm_mask $output/masks_DSURQE/DSURQE_mask_wm.mnc
#rsync -avz $atlas_cc_mask $output/masks_DSURQE/DSURQE_mask_cc.mnc
#mincmorph -erosion $output/masks_DSURQE/DSURQE_mask_no_csf.mnc $output/masks_DSURQE/DSURQE_mask_no_csf_eroded.mnc

############################################################### Registration of all MT and PD acquisition within a single subject (register to MT1, which has largest FA) ####################################
#register all other mt-w images and pd-w image to the mt-w image with largest FA (mt1)
#$scriptdir/helper/antsRegistration_affine_SyN.sh $output/n4_bias_corrected/$(basename -s .mnc $mt2)_processed_denoised.mnc $output/n4_bias_corrected/$(basename -s .mnc $mt1)_processed_denoised.mnc $output/masks_native_space/${basename}_mask_full.mnc $output/transforms_subject_acq_to_mt1/${basename}_mt2-mt1
#$scriptdir/helper/antsRegistration_affine_SyN.sh $output/n4_bias_corrected/$(basename -s .mnc $mt3)_processed_denoised.mnc $output/n4_bias_corrected/$(basename -s .mnc $mt1)_processed_denoised.mnc $output/masks_native_space/${basename}_mask_full.mnc $output/transforms_subject_acq_to_mt1/${basename}_mt3-mt1
#$scriptdir/helper/antsRegistration_affine_SyN.sh $output/n4_bias_corrected/$(basename -s .mnc $mt4)_processed_denoised.mnc $output/n4_bias_corrected/$(basename -s .mnc $mt1)_processed_denoised.mnc $output/masks_native_space/${basename}_mask_full.mnc $output/transforms_subject_acq_to_mt1/${basename}_mt4-mt1
#$scriptdir/helper/antsRegistration_affine_SyN.sh $output/n4_bias_corrected/$(basename -s .mnc $mt5)_processed_denoised.mnc $output/n4_bias_corrected/$(basename -s .mnc $mt1)_processed_denoised.mnc $output/masks_native_space/${basename}_mask_full.mnc $output/transforms_subject_acq_to_mt1/${basename}_mt5-mt1
#$scriptdir/helper/antsRegistration_affine_SyN.sh $output/n4_bias_corrected/$(basename -s .mnc $mt6)_processed_denoised.mnc $output/n4_bias_corrected/$(basename -s .mnc $mt1)_processed_denoised.mnc $output/masks_native_space/${basename}_mask_full.mnc $output/transforms_subject_acq_to_mt1/${basename}_mt6-mt1
#$scriptdir/helper/antsRegistration_affine_SyN.sh $output/n4_bias_corrected/$(basename -s .mnc $pd)_processed_denoised.mnc $output/n4_bias_corrected/$(basename -s .mnc $mt1)_processed_denoised.mnc $output/masks_native_space/${basename}_mask_full.mnc $output/transforms_subject_acq_to_mt1/${basename}_pd-mt1

#Apply transforms to the MTR maps to bring them all into mt1 space
antsApplyTransforms -d 3 -i $output/mtr_maps_native_space/mtr_maps_native_space_denoised/$(basename -s .mnc $mt2)_mtr_map_imagemath_denoised.mnc -t $output/transforms_subject_acq_to_mt1/${basename}_mt2-mt1_output_1_NL.xfm -t $output/transforms_subject_acq_to_mt1/${basename}_mt2-mt1_output_0_GenericAffine.xfm -o $output/mtr_maps_mt1_space/mtr_maps_mt1_space_denoised/$(basename -s .mnc $mt2)_mtr_map_imagemath_denoised_mt1_space.mnc --verbose -r $output/n4_bias_corrected/$(basename -s .mnc $mt1)_processed_denoised.mnc
antsApplyTransforms -d 3 -i $output/mtr_maps_native_space/mtr_maps_native_space_denoised/$(basename -s .mnc $mt3)_mtr_map_imagemath_denoised.mnc -t $output/transforms_subject_acq_to_mt1/${basename}_mt3-mt1_output_1_NL.xfm -t $output/transforms_subject_acq_to_mt1/${basename}_mt3-mt1_output_0_GenericAffine.xfm -o $output/mtr_maps_mt1_space/mtr_maps_mt1_space_denoised/$(basename -s .mnc $mt3)_mtr_map_imagemath_denoised_mt1_space.mnc --verbose -r $output/n4_bias_corrected/$(basename -s .mnc $mt1)_processed_denoised.mnc
antsApplyTransforms -d 3 -i $output/mtr_maps_native_space/mtr_maps_native_space_denoised/$(basename -s .mnc $mt4)_mtr_map_imagemath_denoised.mnc -t $output/transforms_subject_acq_to_mt1/${basename}_mt4-mt1_output_1_NL.xfm -t $output/transforms_subject_acq_to_mt1/${basename}_mt4-mt1_output_0_GenericAffine.xfm -o $output/mtr_maps_mt1_space/mtr_maps_mt1_space_denoised/$(basename -s .mnc $mt4)_mtr_map_imagemath_denoised_mt1_space.mnc --verbose -r $output/n4_bias_corrected/$(basename -s .mnc $mt1)_processed_denoised.mnc
antsApplyTransforms -d 3 -i $output/mtr_maps_native_space/mtr_maps_native_space_denoised/$(basename -s .mnc $mt5)_mtr_map_imagemath_denoised.mnc -t $output/transforms_subject_acq_to_mt1/${basename}_mt5-mt1_output_1_NL.xfm -t $output/transforms_subject_acq_to_mt1/${basename}_mt5-mt1_output_0_GenericAffine.xfm -o $output/mtr_maps_mt1_space/mtr_maps_mt1_space_denoised/$(basename -s .mnc $mt5)_mtr_map_imagemath_denoised_mt1_space.mnc --verbose -r $output/n4_bias_corrected/$(basename -s .mnc $mt1)_processed_denoised.mnc
antsApplyTransforms -d 3 -i $output/mtr_maps_native_space/mtr_maps_native_space_denoised/$(basename -s .mnc $mt6)_mtr_map_imagemath_denoised.mnc -t $output/transforms_subject_acq_to_mt1/${basename}_mt6-mt1_output_1_NL.xfm -t $output/transforms_subject_acq_to_mt1/${basename}_mt6-mt1_output_0_GenericAffine.xfm -o $output/mtr_maps_mt1_space/mtr_maps_mt1_space_denoised/$(basename -s .mnc $mt6)_mtr_map_imagemath_denoised_mt1_space.mnc --verbose -r $output/n4_bias_corrected/$(basename -s .mnc $mt1)_processed_denoised.mnc
cp $output/mtr_maps_native_space/mtr_maps_native_space_denoised/$(basename -s .mnc $mt1)_mtr_map_imagemath_denoised.mnc $output/mtr_maps_mt1_space/mtr_maps_mt1_space_denoised/$(basename -s .mnc $mt1)_mtr_map_imagemath_denoised_mt1_space.mnc
antsApplyTransforms -d 3 -i $output/mtr_maps_native_space/$(basename -s .mnc $mt2)_mtr_map_imagemath.mnc -t $output/transforms_subject_acq_to_mt1/${basename}_mt2-mt1_output_1_NL.xfm -t $output/transforms_subject_acq_to_mt1/${basename}_mt2-mt1_output_0_GenericAffine.xfm -o $output/mtr_maps_mt1_space/$(basename -s .mnc $mt2)_mtr_map_imagemath_mt1_space.mnc --verbose -r $output/preprocessed/$(basename -s .mnc $mt1)_processed.mnc
antsApplyTransforms -d 3 -i $output/mtr_maps_native_space/$(basename -s .mnc $mt3)_mtr_map_imagemath.mnc -t $output/transforms_subject_acq_to_mt1/${basename}_mt3-mt1_output_1_NL.xfm -t $output/transforms_subject_acq_to_mt1/${basename}_mt3-mt1_output_0_GenericAffine.xfm -o $output/mtr_maps_mt1_space/$(basename -s .mnc $mt3)_mtr_map_imagemath_mt1_space.mnc --verbose -r $output/preprocessed/$(basename -s .mnc $mt1)_processed.mnc
antsApplyTransforms -d 3 -i $output/mtr_maps_native_space/$(basename -s .mnc $mt4)_mtr_map_imagemath.mnc -t $output/transforms_subject_acq_to_mt1/${basename}_mt4-mt1_output_1_NL.xfm -t $output/transforms_subject_acq_to_mt1/${basename}_mt4-mt1_output_0_GenericAffine.xfm -o $output/mtr_maps_mt1_space/$(basename -s .mnc $mt4)_mtr_map_imagemath_mt1_space.mnc --verbose -r $output/preprocessed/$(basename -s .mnc $mt1)_processed.mnc
antsApplyTransforms -d 3 -i $output/mtr_maps_native_space/$(basename -s .mnc $mt5)_mtr_map_imagemath.mnc -t $output/transforms_subject_acq_to_mt1/${basename}_mt5-mt1_output_1_NL.xfm -t $output/transforms_subject_acq_to_mt1/${basename}_mt5-mt1_output_0_GenericAffine.xfm -o $output/mtr_maps_mt1_space/$(basename -s .mnc $mt5)_mtr_map_imagemath_mt1_space.mnc --verbose -r $output/preprocessed/$(basename -s .mnc $mt1)_processed.mnc
antsApplyTransforms -d 3 -i $output/mtr_maps_native_space/$(basename -s .mnc $mt6)_mtr_map_imagemath.mnc -t $output/transforms_subject_acq_to_mt1/${basename}_mt6-mt1_output_1_NL.xfm -t $output/transforms_subject_acq_to_mt1/${basename}_mt6-mt1_output_0_GenericAffine.xfm -o $output/mtr_maps_mt1_space/$(basename -s .mnc $mt6)_mtr_map_imagemath_mt1_space.mnc --verbose -r $output/preprocessed/$(basename -s .mnc $mt1)_processed.mnc
cp $output/mtr_maps_native_space/$(basename -s .mnc $mt1)_mtr_map_imagemath.mnc $output/mtr_maps_mt1_space/$(basename -s .mnc $mt1)_mtr_map_imagemath_mt1_space.mnc

#normalize MTR maps (voxelwise division by mt1)
for file in $tmp_subject_dir/*mt*; do mincmath -clobber -nan -div $output/mtr_maps_mt1_space/$(basename -s .mnc $file)_mtr_map_imagemath_mt1_space.mnc $output/mtr_maps_mt1_space/$(basename -s .mnc $mt1)_mtr_map_imagemath_mt1_space.mnc $output/mtr_maps_mt1_space/mtr_maps_mt1_space_normalized/$(basename -s .mnc $file)_mtr_map_imagemath_mt1_space_normalized.mnc; done
for file in $tmp_subject_dir/*mt*; do mincmath -clobber -nan -div $output/mtr_maps_mt1_space/mtr_maps_mt1_space_denoised/$(basename -s .mnc $file)_mtr_map_imagemath_denoised_mt1_space.mnc $output/mtr_maps_mt1_space/mtr_maps_mt1_space_denoised/$(basename -s .mnc $mt1)_mtr_map_imagemath_denoised_mt1_space.mnc $output/mtr_maps_mt1_space/mtr_maps_mt1_space_denoised_normalized/$(basename -s .mnc $file)_mtr_map_imagemath_denoised_mt1_space_normalized.mnc; done

#apply eroded nocsf mask to normalized mtr maps in mt1 space
for file in $tmp_subject_dir/*mt*; do mincmath -mult $output/masks_native_space/${basename}_mask_nocsf_eroded.mnc $output/mtr_maps_mt1_space/mtr_maps_mt1_space_normalized/$(basename -s .mnc $file)_mtr_map_imagemath_mt1_space_normalized.mnc $output/mtr_maps_mt1_space/mtr_maps_mt1_space_normalized_masked_thresholded/$(basename -s .mnc $file)_mtr_map_imagemath_mt1_space_normalized_masked.mnc; done
for file in $tmp_subject_dir/*mt*; do mincmath -mult $output/masks_native_space/${basename}_mask_nocsf_eroded.mnc $output/mtr_maps_mt1_space/mtr_maps_mt1_space_denoised_normalized/$(basename -s .mnc $file)_mtr_map_imagemath_denoised_mt1_space_normalized.mnc $output/mtr_maps_mt1_space/mtr_maps_mt1_space_denoised_normalized_masked_thresholded/$(basename -s .mnc $file)_mtr_map_imagemath_denoised_mt1_space_normalized_masked.mnc; done

#threshold the normalized MTR maps
for file in $tmp_subject_dir/*mt*; do ImageMath 3 $output/mtr_maps_mt1_space/mtr_maps_mt1_space_denoised_normalized_masked_thresholded/$(basename -s .mnc $file)_mtr_map_imagemath_denoised_mt1_space_normalized_masked_thresh.mnc ReplaceVoxelValue $output/mtr_maps_mt1_space/mtr_maps_mt1_space_denoised_normalized_masked_thresholded/$(basename -s .mnc $file)_mtr_map_imagemath_denoised_mt1_space_normalized_masked.mnc 3 10000 nan; done
for file in $tmp_subject_dir/*mt*; do ImageMath 3 $output/mtr_maps_mt1_space/mtr_maps_mt1_space_normalized_masked_thresholded/$(basename -s .mnc $file)_mtr_map_imagemath_mt1_space_normalized_masked_thresh.mnc ReplaceVoxelValue $output/mtr_maps_mt1_space/mtr_maps_mt1_space_normalized_masked_thresholded/$(basename -s .mnc $file)_mtr_map_imagemath_mt1_space_normalized_masked.mnc 3 10000 nan; done
############################################################### Registration of B1 acquisitions to MT within subject (register to MT1, which has largest FA) ####################################

#perform bias field correction of the b1_120 acquisition first (assumes that the mask registered to mt1 applies well to b1-120 as well)
#python $scriptdir/helper/bias_cor_minc.py $output/preprocessed/$(basename -s .mnc $b1120)_processed.mnc $output/n4_bias_corrected/$(basename -s .mnc $mt1)_processed_denoised.mnc $output/masks_native_space/${basename}_mask_full.mnc $scriptdir/helper/antsRegistration_rigid.sh $output/n4_bias_corrected/$(basename -s .mnc $b1120)_processed_denoised.mnc

#register the denoised b1 acquisition to mt1
mkdir -m a=rwx $output/b1_maps/
mkdir -m a=rwx $output/b1_maps/registered_b1_to_mtr
#$scriptdir/helper/antsRegistration_affine_SyN.sh $output/n4_bias_corrected/$(basename -s .mnc $b1120)_processed_denoised.mnc $output/n4_bias_corrected/$(basename -s .mnc $mt1)_processed_denoised.mnc $output/masks_native_space/${basename}_mask_full.mnc $output/b1_maps/registered_b1_to_mtr/${basename}_b1_120-${basename}_mt_1045

#Create B1 maps
#minccalc -expression 'acos(A[1]/(2*A[0]))*(180/(4*atan(1)))' $output/preprocessed/$(basename -s .mnc $b160)_processed.mnc $output/preprocessed/$(basename -s .mnc $b1120)_processed.mnc $output/b1_maps/${basename}_b1_map.mnc

#Apply transforms to the B1 map to put it in mt1 space, then again to put it in DSURQE space
#antsApplyTransforms -d 3 -i $output/b1_maps/${basename}_b1_map.mnc -t $output/b1_maps/registered_b1_to_mtr/${basename}_b1_120-${basename}_mt_1045_output_1_NL.xfm -t $output/b1_maps/registered_b1_to_mtr/${basename}_b1_120-${basename}_mt_1045_output_0_GenericAffine.xfm -o $output/b1_maps/registered_b1_to_mtr/${basename}_b1_map_registered.mnc --verbose -r $output/n4_bias_corrected/$(basename -s .mnc $mt1)_processed_denoised.mnc
#mkdir -m a=rwx $output/b1_maps/registered_b1_to_mtr_dsurqe
#antsApplyTransforms -d 3 -i $output/b1_maps/${basename}_b1_map.mnc -t $output/transforms_subject_to_DSURQE/$(basename -s .mnc $mt1)-DSURQE_output_1_inverse_NL.xfm -t $output/transforms_subject_to_DSURQE/$(basename -s .mnc $mt1)-DSURQE_output_0_GenericAffine.xfm -t $output/b1_maps/registered_b1_to_mtr/${basename}_b1_120-${basename}_mt_1045_output_1_NL.xfm -t $output/b1_maps/registered_b1_to_mtr/${basename}_b1_120-${basename}_mt_1045_output_0_GenericAffine.xfm -o $output/b1_maps/registered_b1_to_mtr_dsurqe/${basename}_b1_map_registered_dsurqe.mnc --verbose -r $output/mtr_maps_denoised_eroded_DSURQE_space/$(basename -s .mnc $file)_mtr_map_imagemath_denoised_eroded_DSURQE_space.mnc

#normalize b1 map using a value of 60
#mkdir -m a=rwx $output/b1_maps/normalized_and_registered_b1/
#minccalc -expression "A[0]/60" $output/b1_maps/registered_b1_to_mtr/${basename}_b1_map_registered.mnc $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc
#mkdir -m a=rwx $output/b1_maps/normalized_and_registered_b1_dsurqe/
#minccalc -expression "A[0]/60" $output/b1_maps/registered_b1_to_mtr_dsurqe/${basename}_b1_map_registered_dsurqe.mnc $output/b1_maps/normalized_and_registered_b1_dsurqe/${basename}_b1_map_registered_norm_dsurqe.mnc
######################################################################### Create mask based on B1 field strength ###############################################################

#create a mask according to the b1 map (only exists where b1 map is between 0.8 and 1). Do this by first masking b1_map with no_csf eroded mask, cut off cerebellum (can be noisy) then threshold to 0.8-1.
#mkdir -m a=rwx $output/b1_maps/tmp/
#mkdir -m a=rwx $output/b1_maps/normalized_and_registered_b1/masked_norm_reg_b1/
#mkdir -m a=rwx $output/b1_maps/normalized_and_registered_b1/thresholded_mask_norm_reg_b1/
#mincmath -clobber -mult $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc $output/masks_native_space/${basename}_mask_nocsf_eroded.mnc $output/b1_maps/tmp/${basename}_b1_map_reg_norm_masked_tmp.mnc
#mincmath -clobber -mult $output/b1_maps/tmp/${basename}_b1_map_reg_norm_masked_tmp.mnc /data/chamal/projects/mila/2019_MTR_on_Cryoprobe/resources_tissue_labels/cerebellum_antimask_large.mnc $output/b1_maps/tmp/${basename}_b1_map_reg_norm_mask_cerebellum.mnc
#mincmath -clobber -mult $output/b1_maps/tmp/${basename}_b1_map_reg_norm_mask_cerebellum.mnc /data/chamal/projects/mila/2019_MTR_on_Cryoprobe/resources_tissue_labels/ghosting_antimask.mnc $output/b1_maps/normalized_and_registered_b1/masked_norm_reg_b1/${basename}_b1_map_reg_norm_mask.mnc
#mincmath -clobber -const2 0.8 1 -segment $output/b1_maps/normalized_and_registered_b1/masked_norm_reg_b1/${basename}_b1_map_reg_norm_mask.mnc $output/b1_maps/normalized_and_registered_b1/thresholded_mask_norm_reg_b1/${basename}_b1_map_reg_norm_mask_thresh_0.8_to_1.mnc

#put the file names in a csv
if [ ! -f $output/mtr_b1_list_for_lin_regr.csv ]; then
        echo subjectID, coil_type, FA, B1_norm, MTR_norm, B1_map, mask_nocsf, mask_b1 >> $output/mtr_b1_list_for_lin_regr.csv
        echo subjectID, coil_type, FA, B1_norm, MTR_norm, B1_map, mask_nocsf, mask_b1 >> $output/mtr_b1_list_for_lin_regr_denoised.csv
fi
#check if there are 6 acquisitions by checking if the 9th argument is an empty string
if [ -z "$9" ]; then
  echo ${basename}, $coil_type, 1045, 1, $output/mtr_maps_mt1_space/mtr_maps_mt1_space_normalized/$(basename -s .mnc $mt1)_mtr_map_imagemath_eroded_mt1_space_normalized.mnc, $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc, $output/masks_native_space/${basename}_mask_nocsf.mnc, $output/b1_maps/normalized_and_registered_b1/thresholded_mask_norm_reg_b1/${basename}_b1_map_reg_norm_mask_thresh_0.8_to_1.mnc >>   $output/mtr_b1_list_for_lin_regr.csv
  echo ${basename}, $coil_type, 980, 0.938, $output/mtr_maps_mt1_space/mtr_maps_mt1_space_normalized/$(basename -s .mnc $mt2)_mtr_map_imagemath_eroded_mt1_space_normalized.mnc, $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc, $output/masks_native_space/${basename}_mask_nocsf.mnc, $output/b1_maps/normalized_and_registered_b1/thresholded_mask_norm_reg_b1/${basename}_b1_map_reg_norm_mask_thresh_0.8_to_1.mnc >>   $output/mtr_b1_list_for_lin_regr.csv
  echo ${basename}, $coil_type, 915, 0.876, $output/mtr_maps_mt1_space/mtr_maps_mt1_space_normalized/$(basename -s .mnc $mt3)_mtr_map_imagemath_eroded_mt1_space_normalized.mnc, $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc, $output/masks_native_space/${basename}_mask_nocsf.mnc, $output/b1_maps/normalized_and_registered_b1/thresholded_mask_norm_reg_b1/${basename}_b1_map_reg_norm_mask_thresh_0.8_to_1.mnc >>   $output/mtr_b1_list_for_lin_regr.csv
  echo ${basename}, $coil_type, 850, 0.813, $output/mtr_maps_mt1_space/mtr_maps_mt1_space_normalized/$(basename -s .mnc $mt4)_mtr_map_imagemath_eroded_mt1_space_normalized.mnc, $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc, $output/masks_native_space/${basename}_mask_nocsf.mnc, $output/b1_maps/normalized_and_registered_b1/thresholded_mask_norm_reg_b1/${basename}_b1_map_reg_norm_mask_thresh_0.8_to_1.mnc >>   $output/mtr_b1_list_for_lin_regr.csv
  echo ${basename}, $coil_type, 785, 0.751, $output/mtr_maps_mt1_space/mtr_maps_mt1_space_normalized/$(basename -s .mnc $mt5)_mtr_map_imagemath_eroded_mt1_space_normalized.mnc, $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc, $output/masks_native_space/${basename}_mask_nocsf.mnc, $output/b1_maps/normalized_and_registered_b1/thresholded_mask_norm_reg_b1/${basename}_b1_map_reg_norm_mask_thresh_0.8_to_1.mnc >>   $output/mtr_b1_list_for_lin_regr.csv

else
  echo ${basename}, $coil_type, 1045, 1, $output/mtr_maps_mt1_space/mtr_maps_mt1_space_normalized/$(basename -s .mnc $mt1)_mtr_map_imagemath_eroded_mt1_space_normalized.mnc, $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc, $output/masks_native_space/${basename}_mask_nocsf.mnc, $output/b1_maps/normalized_and_registered_b1/thresholded_mask_norm_reg_b1/${basename}_b1_map_reg_norm_mask_thresh_0.8_to_1.mnc >>   $output/mtr_b1_list_for_lin_regr.csv
  echo ${basename}, $coil_type, 1000, 0.957, $output/mtr_maps_mt1_space/mtr_maps_mt1_space_normalized/$(basename -s .mnc $mt2)_mtr_map_imagemath_eroded_mt1_space_normalized.mnc, $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc, $output/masks_native_space/${basename}_mask_nocsf.mnc, $output/b1_maps/normalized_and_registered_b1/thresholded_mask_norm_reg_b1/${basename}_b1_map_reg_norm_mask_thresh_0.8_to_1.mnc >>   $output/mtr_b1_list_for_lin_regr.csv
  echo ${basename}, $coil_type, 955, 0.914, $output/mtr_maps_mt1_space/mtr_maps_mt1_space_normalized/$(basename -s .mnc $mt3)_mtr_map_imagemath_eroded_mt1_space_normalized.mnc, $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc, $output/masks_native_space/${basename}_mask_nocsf.mnc, $output/b1_maps/normalized_and_registered_b1/thresholded_mask_norm_reg_b1/${basename}_b1_map_reg_norm_mask_thresh_0.8_to_1.mnc >>   $output/mtr_b1_list_for_lin_regr.csv
  echo ${basename}, $coil_type, 910, 0.871, $output/mtr_maps_mt1_space/mtr_maps_mt1_space_normalized/$(basename -s .mnc $mt4)_mtr_map_imagemath_eroded_mt1_space_normalized.mnc, $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc, $output/masks_native_space/${basename}_mask_nocsf.mnc, $output/b1_maps/normalized_and_registered_b1/thresholded_mask_norm_reg_b1/${basename}_b1_map_reg_norm_mask_thresh_0.8_to_1.mnc >>   $output/mtr_b1_list_for_lin_regr.csv
  echo ${basename}, $coil_type, 865, 0.828, $output/mtr_maps_mt1_space/mtr_maps_mt1_space_normalized/$(basename -s .mnc $mt5)_mtr_map_imagemath_eroded_mt1_space_normalized.mnc, $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc, $output/masks_native_space/${basename}_mask_nocsf.mnc, $output/b1_maps/normalized_and_registered_b1/thresholded_mask_norm_reg_b1/${basename}_b1_map_reg_norm_mask_thresh_0.8_to_1.mnc >>   $output/mtr_b1_list_for_lin_regr.csv
  echo ${basename}, $coil_type, 820, 0.785, $output/mtr_maps_mt1_space/mtr_maps_mt1_space_normalized/$(basename -s .mnc $mt6)_mtr_map_imagemath_eroded_mt1_space_normalized.mnc, $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc, $output/masks_native_space/${basename}_mask_nocsf.mnc, $output/b1_maps/normalized_and_registered_b1/thresholded_mask_norm_reg_b1/${basename}_b1_map_reg_norm_mask_thresh_0.8_to_1.mnc >>   $output/mtr_b1_list_for_lin_regr.csv
fi
#do the same for denoised data
if [ -z "$9" ]; then
  echo ${basename}, $coil_type, 1045, 1, $output/mtr_maps_mt1_space/mtr_maps_mt1_space_denoised_normalized/$(basename -s .mnc $mt1)_mtr_map_imagemath_denoised_eroded_mt1_space_normalized.mnc, $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc, $output/masks_native_space/${basename}_mask_nocsf.mnc, $output/b1_maps/normalized_and_registered_b1/thresholded_mask_norm_reg_b1/${basename}_b1_map_reg_norm_mask_thresh_0.8_to_1.mnc >>   $output/mtr_b1_list_for_lin_regr_denoised.csv
  echo ${basename}, $coil_type, 980, 0.938, $output/mtr_maps_mt1_space/mtr_maps_mt1_space_denoised_normalized/$(basename -s .mnc $mt2)_mtr_map_imagemath_denoised_eroded_mt1_space_normalized.mnc, $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc, $output/masks_native_space/${basename}_mask_nocsf.mnc, $output/b1_maps/normalized_and_registered_b1/thresholded_mask_norm_reg_b1/${basename}_b1_map_reg_norm_mask_thresh_0.8_to_1.mnc >>   $output/mtr_b1_list_for_lin_regr_denoised.csv
  echo ${basename}, $coil_type, 915, 0.876, $output/mtr_maps_mt1_space/mtr_maps_mt1_space_denoised_normalized/$(basename -s .mnc $mt3)_mtr_map_imagemath_denoised_eroded_mt1_space_normalized.mnc, $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc, $output/masks_native_space/${basename}_mask_nocsf.mnc, $output/b1_maps/normalized_and_registered_b1/thresholded_mask_norm_reg_b1/${basename}_b1_map_reg_norm_mask_thresh_0.8_to_1.mnc >>   $output/mtr_b1_list_for_lin_regr_denoised.csv
  echo ${basename}, $coil_type, 850, 0.813, $output/mtr_maps_mt1_space/mtr_maps_mt1_space_denoised_normalized/$(basename -s .mnc $mt4)_mtr_map_imagemath_denoised_eroded_mt1_space_normalized.mnc, $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc, $output/masks_native_space/${basename}_mask_nocsf.mnc, $output/b1_maps/normalized_and_registered_b1/thresholded_mask_norm_reg_b1/${basename}_b1_map_reg_norm_mask_thresh_0.8_to_1.mnc >>   $output/mtr_b1_list_for_lin_regr_denoised.csv
  echo ${basename}, $coil_type, 785, 0.751, $output/mtr_maps_mt1_space/mtr_maps_mt1_space_denoised_normalized/$(basename -s .mnc $mt5)_mtr_map_imagemath_denoised_eroded_mt1_space_normalized.mnc, $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc, $output/masks_native_space/${basename}_mask_nocsf.mnc, $output/b1_maps/normalized_and_registered_b1/thresholded_mask_norm_reg_b1/${basename}_b1_map_reg_norm_mask_thresh_0.8_to_1.mnc >>   $output/mtr_b1_list_for_lin_regr_denoised.csv

else
  echo ${basename}, $coil_type, 1045, 1, $output/mtr_maps_mt1_space/mtr_maps_mt1_space_denoised_normalized/$(basename -s .mnc $mt1)_mtr_map_imagemath_denoised_eroded_mt1_space_normalized.mnc, $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc, $output/masks_native_space/${basename}_mask_nocsf.mnc, $output/b1_maps/normalized_and_registered_b1/thresholded_mask_norm_reg_b1/${basename}_b1_map_reg_norm_mask_thresh_0.8_to_1.mnc >>   $output/mtr_b1_list_for_lin_regr_denoised.csv
  echo ${basename}, $coil_type, 1000, 0.957, $output/mtr_maps_mt1_space/mtr_maps_mt1_space_denoised_normalized/$(basename -s .mnc $mt2)_mtr_map_imagemath_denoised_eroded_mt1_space_normalized.mnc, $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc, $output/masks_native_space/${basename}_mask_nocsf.mnc, $output/b1_maps/normalized_and_registered_b1/thresholded_mask_norm_reg_b1/${basename}_b1_map_reg_norm_mask_thresh_0.8_to_1.mnc >>   $output/mtr_b1_list_for_lin_regr_denoised.csv
  echo ${basename}, $coil_type, 955, 0.914, $output/mtr_maps_mt1_space/mtr_maps_mt1_space_denoised_normalized/$(basename -s .mnc $mt3)_mtr_map_imagemath_denoised_eroded_mt1_space_normalized.mnc, $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc, $output/masks_native_space/${basename}_mask_nocsf.mnc, $output/b1_maps/normalized_and_registered_b1/thresholded_mask_norm_reg_b1/${basename}_b1_map_reg_norm_mask_thresh_0.8_to_1.mnc >>   $output/mtr_b1_list_for_lin_regr_denoised.csv
  echo ${basename}, $coil_type, 910, 0.871, $output/mtr_maps_mt1_space/mtr_maps_mt1_space_denoised_normalized/$(basename -s .mnc $mt4)_mtr_map_imagemath_denoised_eroded_mt1_space_normalized.mnc, $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc, $output/masks_native_space/${basename}_mask_nocsf.mnc, $output/b1_maps/normalized_and_registered_b1/thresholded_mask_norm_reg_b1/${basename}_b1_map_reg_norm_mask_thresh_0.8_to_1.mnc >>   $output/mtr_b1_list_for_lin_regr_denoised.csv
  echo ${basename}, $coil_type, 865, 0.828, $output/mtr_maps_mt1_space/mtr_maps_mt1_space_denoised_normalized/$(basename -s .mnc $mt5)_mtr_map_imagemath_denoised_eroded_mt1_space_normalized.mnc, $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc, $output/masks_native_space/${basename}_mask_nocsf.mnc, $output/b1_maps/normalized_and_registered_b1/thresholded_mask_norm_reg_b1/${basename}_b1_map_reg_norm_mask_thresh_0.8_to_1.mnc >>   $output/mtr_b1_list_for_lin_regr_denoised.csv
  echo ${basename}, $coil_type, 820, 0.785, $output/mtr_maps_mt1_space/mtr_maps_mt1_space_denoised_normalized/$(basename -s .mnc $mt6)_mtr_map_imagemath_denoised_eroded_mt1_space_normalized.mnc, $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc, $output/masks_native_space/${basename}_mask_nocsf.mnc, $output/b1_maps/normalized_and_registered_b1/thresholded_mask_norm_reg_b1/${basename}_b1_map_reg_norm_mask_thresh_0.8_to_1.mnc >>   $output/mtr_b1_list_for_lin_regr_denoised.csv
fi

rm -rf $tmp_subject_dir
rm -rf $tmp_b1_subject_dir
