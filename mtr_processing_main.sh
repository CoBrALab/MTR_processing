#!/bin/bash
#this script is for creating MTR and B1 maps and outputting a final MTR map that is corrected for B1 inhomogeneities. For use on cic computer.
#TIP: create a csv with the subject ids and paths to each of the input files
#all input folders should contain raw minc images named with the following convention coil_subjectid_mt.mnc or coil_subjectid_pd.mnc etc.
#usage:
#mtr_processing_full_analysis.sh output_folder MT_image PD_image b1_60 b1_120 OUTPUT FOLDER SHOULD NOT HAVE A / AT THE END!
#it assumes that all 4 images were collected consecutively with no change in mouse positioning. Works with multiple MT images per mouse-coil combo but needs to be modified if want to use multiple pd images or b1 maps
#edited on Dec 13, 2020 to incorporate the new room-temp coil slope
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
coil_type=$(echo $basename | cut -c1-3)

#first, preprocess all the images. denoised versions are also created to aid with registration later on.
mkdir -m a=rwx $output/preprocessed
mkdir -m a=rwx $output/denoised
mkdir -m a=rwx $output/masks
mkdir -m a=rwx $output/transforms_subject_to_DSURQE
mkdir -m a=rwx $output/subject_specific_tissue_masks

if test -f $output/preprocessed/*${basename}*pd*; then rm $tmp_subject_dir/*pd*; fi
if test -f $output/preprocessed/*${basename}*b1*60*; then rm $tmp_subject_dir/*b1*; fi

for file in $tmp_subject_dir/*; do /data/chamal/projects/mila/2019_Magnetization_Transfer/scripts/mouse-preprocessing-orientation.sh $file $output/preprocessed/$(basename -s .mnc $file)_processed.mnc; done

#denoise the mt file. The N4 denoised acquisitions are necessary for registration to the atlas, and for registering the b1_map to the mtr.
/data/chamal/projects/mila/2019_Magnetization_Transfer/scripts/mouse-preprocessing-denoise-only.sh $output/preprocessed/$(basename -s .mnc $2)_processed.mnc $output/denoised/$(basename -s .mnc $2)_processed_denoised.mnc

#create mask by registering mt file to DSURQE, then transforming DSURQE mask to subject
/data/chamal/projects/mila/2019_Magnetization_Transfer/scripts/antsRegistration_affine_SyN.sh $output/denoised/$(basename -s .mnc $2)_processed_denoised.mnc $atlas_for_reg $atlas_mask $output/transforms_subject_to_DSURQE/${basename}-DSURQE
antsApplyTransforms -d 3 -i /data/chamal/projects/mila/2019_Magnetization_Transfer/tissue_labels/DSURQE_100micron_mask_fixed_binary_better.mnc -t $output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_1_inverse_NL.xfm -t [$output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_0_GenericAffine.xfm,1] -n GenericLabel -o $output/masks/${basename}_mask_nocsf.mnc --verbose -r $output/denoised/$(basename -s .mnc $2)_processed_denoised.mnc
antsApplyTransforms -d 3 -i /data/chamal/projects/mila/2019_Magnetization_Transfer/tissue_labels/DSURQE_100micron_mask.mnc -t $output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_1_inverse_NL.xfm -t [$output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_0_GenericAffine.xfm,1] -n GenericLabel -o $output/masks/${basename}_mask_full.mnc --verbose -r $output/denoised/$(basename -s .mnc $2)_processed_denoised.mnc

#N4 denoising of the b1 acquisitions (only need b1_120 to be denoised)
python $tmp_subject_dir/bias_cor_minc.py $output/preprocessed/$(basename -s .mnc $5)_processed.mnc $output/denoised/$(basename -s .mnc $2)_processed_denoised.mnc $output/masks/${basename}_mask_full.mnc /data/chamal/projects/mila/2019_Magnetization_Transfer/scripts/helper_scripts/antsRegistration_rigid.sh $output/denoised/$(basename -s .mnc $5)_processed_denoised.mnc

#warp the other masks (corpus callosum, wm, gm) to the subject file as well
antsApplyTransforms -d 3 -i /data/chamal/projects/mila/2019_Magnetization_Transfer/tissue_labels/DSURQE_100micron_gm_better.mnc -t $output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_1_inverse_NL.xfm -t [$output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_0_GenericAffine.xfm,1] -n GenericLabel -o $output/subject_specific_tissue_masks/${basename}_mask_gm.mnc --verbose -r $output/denoised/$(basename -s .mnc $2)_processed_denoised.mnc
antsApplyTransforms -d 3 -i /data/chamal/projects/mila/2019_Magnetization_Transfer/tissue_labels/DSURQE_100micron_wm_better.mnc -t $output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_1_inverse_NL.xfm -t [$output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_0_GenericAffine.xfm,1] -n GenericLabel -o $output/subject_specific_tissue_masks/${basename}_mask_wm.mnc --verbose -r $output/denoised/$(basename -s .mnc $2)_processed_denoised.mnc
antsApplyTransforms -d 3 -i /data/chamal/projects/mila/2019_Magnetization_Transfer/tissue_labels/cc_mask_100micron_better.mnc -t $output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_1_inverse_NL.xfm -t [$output/transforms_subject_to_DSURQE/${basename}-DSURQE_output_0_GenericAffine.xfm,1] -n GenericLabel -o $output/subject_specific_tissue_masks/${basename}_mask_cc.mnc --verbose -r $output/denoised/$(basename -s .mnc $2)_processed_denoised.mnc

#create MTR maps
mkdir -m a=rwx $output/mtr_maps
minccalc -expression '(A[0]- A[1])/A[0]' $output/preprocessed/$(basename -s .mnc $3)_processed.mnc $output/preprocessed/$(basename -s .mnc $2)_processed.mnc $output/mtr_maps/$(basename -s .mnc $2)_mtr_map_minccalc.mnc
ImageMath 3 $output/mtr_maps/$(basename -s .mnc $2)_mtr_map_imagemath.mnc MTR $output/preprocessed/$(basename -s .mnc $3)_processed.mnc $output/preprocessed/$(basename -s .mnc $2)_processed.mnc $output/masks/${basename}_mask_nocsf.mnc

#create b1 maps
mkdir -m a=rwx $output/b1_maps
minccalc -expression 'acos(A[1]/(2*A[0]))*(180/(4*atan(1)))' $output/preprocessed/$(basename -s .mnc $4)_processed.mnc $output/preprocessed/$(basename -s .mnc $5)_processed.mnc $output/b1_maps/${basename}_b1_map.mnc

#register the b1 map to the MTR map
mkdir -m a=rwx $output/b1_maps/registered_b1_to_mtr
/data/chamal/projects/mila/2019_Magnetization_Transfer/scripts/antsRegistration_affine_SyN_rabies.sh $output/denoised/$(basename -s .mnc $5)_processed_denoised.mnc $output/denoised/$(basename -s .mnc $2)_processed_denoised.mnc $output/masks/${basename}_mask_full.mnc $output/b1_maps/registered_b1_to_mtr/${basename}_b1_120-${basename}_mt_1045
antsApplyTransforms -d 3 -i $output/b1_maps/${basename}_b1_map.mnc -t $output/b1_maps/registered_b1_to_mtr/${basename}_b1_120-${basename}_mt_1045_output_0_GenericAffine.xfm -t $output/b1_maps/registered_b1_to_mtr/${basename}_b1_120-${basename}_mt_1045_output_1_NL.xfm -o $output/b1_maps/registered_b1_to_mtr/${basename}_b1_map_registered.mnc --verbose -r $output/denoised/$(basename -s .mnc $2)_processed_denoised.mnc

#normalize b1 map using a value of 60
mkdir -m a=rwx $output/b1_maps/normalized_and_registered_b1
minccalc -expression "A[0]/60" $output/b1_maps/registered_b1_to_mtr/${basename}_b1_map_registered.mnc $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc

#perform the correction separately for the cryocoil (uses data from the optimized parameters) and normal coil (standard parameters)
mkdir -m a=rwx $output/mtr_maps/corrected_mtr_maps
if [ "$coil_type" == "cry" ]; then minccalc -expression 'A[0]/(1.1842766*A[1]-0.1842766)' $output/mtr_maps/$(basename -s .mnc $2)_mtr_map_imagemath.mnc $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc $output/mtr_maps/corrected_mtr_maps/$(basename -s .mnc $2)_mtr_map_imagemath_corrected.mnc; fi
if [ "$coil_type" == "nrm" ]; then minccalc -expression 'A[0]/(1.25844938*A[1]-0.25844938)' $output/mtr_maps/$(basename -s .mnc $2)_mtr_map_imagemath.mnc $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc $output/mtr_maps/corrected_mtr_maps/$(basename -s .mnc $2)_mtr_map_imagemath_corrected.mnc; fi

mkdir -m a=rwx $output/mtr_maps_denoised_ants/corrected_mtr_maps_denoised_ants
if [ "$coil_type" == "cry" ]; then minccalc -expression 'A[0]/(1.1842766*A[1]-0.1842766)' $output/mtr_maps_denoised_ants/$(basename -s .mnc $2)_mtr_map_imagemath.mnc $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc $output/mtr_maps_denoised_ants/corrected_mtr_maps_denoised_ants/$(basename -s .mnc $2)_mtr_map_imagemath_denoised_corrected.mnc; fi
if [ "$coil_type" == "nrm" ]; then minccalc -expression 'A[0]/(1.25844938*A[1]-0.25844938)' $output/mtr_maps_denoised_ants/$(basename -s .mnc $2)_mtr_map_imagemath.mnc $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc $output/mtr_maps_denoised_ants/corrected_mtr_maps_denoised_ants/$(basename -s .mnc $2)_mtr_map_imagemath_denoised_corrected.mnc; fi

#after the correction, there may be a few voxels greater than 1 that correspond to noise but made it inside the mask. Set these to zero. (set values between [1,10] to 0)
ImageMath 3 $output/mtr_maps/corrected_mtr_maps/$(basename -s .mnc $2)_mtr_map_imagemath_corrected_thresholded.mnc ReplaceVoxelValue $output/mtr_maps/corrected_mtr_maps/$(basename -s .mnc $2)_mtr_map_imagemath_corrected.mnc 1 10 0
ImageMath 3 $output/mtr_maps_denoised_ants/corrected_mtr_maps_denoised_ants/$(basename -s .mnc $2)_mtr_map_imagemath_denoised_corrected_thresholded.mnc ReplaceVoxelValue $output/mtr_maps_denoised_ants/corrected_mtr_maps_denoised_ants/$(basename -s .mnc $2)_mtr_map_imagemath_denoised_corrected.mnc 1 10 0

rm -rf $tmp_subject_dir
