#!/bin/bash
#this script is for creating MTR and B1 maps and outputting a final MTR map that is corrected for B1 inhomogeneities.
#all input folders should contain raw nifti images named with the following naming format: sub-HAR001_acq-cryo_flip-990_MTw.nii.gz
#usage:
#mtr_processing_main.sh output_folder MT_image PD_image b1_60 b1_120
#it assumes that all 4 images were collected consecutively with no change in mouse positioning. Works with multiple MT images per mouse-coil combo but needs to be modified if want to use multiple pd images or b1 maps
#edited on Jan 20 2022 to handle raw nifti inputs
module load minc-toolkit
module load minc-toolkit-extras
module load ANTs
source activate mtr_processing_env

#load atlases, masks and labels
atlas_for_reg=${QUARANTINE_PATH}/resources/Dorr_2008_Steadman_2013_Ullmann_2013_Richards_2011_Qiu_2016_Egan_2015_40micron/100um/DSURQE.mnc
atlas_mask=${QUARANTINE_PATH}/resources/Dorr_2008_Steadman_2013_Ullmann_2013_Richards_2011_Qiu_2016_Egan_2015_40micron/100um/DSURQE_mask.mnc

atlas_nocsf_mask=/data/chamal/projects/mila/2019_MTR_on_Cryoprobe/resources_tissue_labels/DSURQE_100micron_mask_fixed_binary.mnc
atlas_full_mask=/data/chamal/projects/mila/2019_MTR_on_Cryoprobe/resources_tissue_labels/DSURQE_100micron_mask.mnc
atlas_gm_mask=/data/chamal/projects/mila/2019_MTR_on_Cryoprobe/resources_tissue_labels/DSURQE_100micron_gm.mnc
atlas_wm_mask=/data/chamal/projects/mila/2019_MTR_on_Cryoprobe/resources_tissue_labels/DSURQE_100micron_wm.mnc
atlas_cc_mask=/data/chamal/projects/mila/2019_MTR_on_Cryoprobe/resources_tissue_labels/cc_mask_100micron.mnc

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
tmp_nii_subject_dir=$(mktemp -d)
cp $2 $tmp_nii_subject_dir
cp $3 $tmp_nii_subject_dir
cp $4 $tmp_nii_subject_dir
cp $5 $tmp_nii_subject_dir

temp=$(basename $mt)
subject=$(echo $temp | grep -oP '(?<=sub-).*?(?=_)' ) #extract subjectID
coil_type=$(echo $temp | grep -oP '(?<=acq-).*?(?=_)' ) #extract coil type
basename=$(echo $temp | grep -oP '(?<=).*?(?=_MTw)' )

#convert from nifti to minc
mkdir -m a=rwx $output/raw_minc
for file in $tmp_nii_subject_dir/*; do 
        nii2mnc -noscanrange $file $output/raw_minc/$(basename -s .nii.gz $file).mnc;  
done
############################################################### Mask creation ##########################
mkdir -m a=rwx $output/n4_bias_corrected
mkdir -m a=rwx $output/masks
mkdir -m a=rwx $output/transforms_subject_to_DSURQE
mkdir -m a=rwx $output/masks_tissue_type

#perform N4 bias field correction. The N4 bias corrected acquisitions are necessary for registration to the atlas, and for registering the b1_map to the mtr.
$scriptdir/helper/mouse-preprocessing-N4corr.sh $output/raw_minc/$(basename -s .nii.gz $mt).mnc $output/n4_bias_corrected/$(basename -s .nii.gz $mt)_N4corr.mnc

#create mask by registering mt file to DSURQE, then transforming DSURQE mask to subject
$scriptdir/helper/antsRegistration_affine_SyN.sh $output/n4_bias_corrected/$(basename -s .nii.gz $mt)_N4corr.mnc $atlas_for_reg $atlas_mask \
        $output/transforms_subject_to_DSURQE/$(basename -s .nii.gz $mt)-DSURQE
antsApplyTransforms -d 3 -i  $atlas_nocsf_mask \
        -t [$output/transforms_subject_to_DSURQE/$(basename -s .nii.gz $mt)-DSURQE_output_0_GenericAffine.xfm,1] \
        -t $output/transforms_subject_to_DSURQE/$(basename -s .nii.gz $mt)-DSURQE_output_1_inverse_NL.xfm -n GenericLabel \
        -o $output/masks/${basename}_mask_nocsf.mnc --verbose \
        -r $output/n4_bias_corrected/$(basename -s .nii.gz $mt)_N4corr.mnc
antsApplyTransforms -d 3 -i  $atlas_full_mask \
        -t [$output/transforms_subject_to_DSURQE/$(basename -s .nii.gz $mt)-DSURQE_output_0_GenericAffine.xfm,1] \
        -t $output/transforms_subject_to_DSURQE/$(basename -s .nii.gz $mt)-DSURQE_output_1_inverse_NL.xfm -n GenericLabel \
        -o $output/masks/${basename}_mask_full.mnc --verbose \
        -r $output/n4_bias_corrected/$(basename -s .nii.gz $mt)_N4corr.mnc
antsApplyTransforms -d 3 -i  $atlas_gm_mask \
        -t [$output/transforms_subject_to_DSURQE/$(basename -s .nii.gz $mt)-DSURQE_output_0_GenericAffine.xfm,1] \
        -t $output/transforms_subject_to_DSURQE/$(basename -s .nii.gz $mt)-DSURQE_output_1_inverse_NL.xfm -n GenericLabel \
        -o $output/masks_tissue_type/${basename}_mask_gm.mnc --verbose \
        -r $output/n4_bias_corrected/$(basename -s .nii.gz $mt)_N4corr.mnc
antsApplyTransforms -d 3 -i  $atlas_wm_mask \
        -t [$output/transforms_subject_to_DSURQE/$(basename -s .nii.gz $mt)-DSURQE_output_0_GenericAffine.xfm,1] \
        -t $output/transforms_subject_to_DSURQE/$(basename -s .nii.gz $mt)-DSURQE_output_1_inverse_NL.xfm -n GenericLabel \
        -o $output/masks_tissue_type/${basename}_mask_wm.mnc --verbose \
        -r $output/n4_bias_corrected/$(basename -s .nii.gz $mt)_N4corr.mnc
antsApplyTransforms -d 3 -i  $atlas_cc_mask \
        -t [$output/transforms_subject_to_DSURQE/$(basename -s .nii.gz $mt)-DSURQE_output_0_GenericAffine.xfm,1] \
        -t $output/transforms_subject_to_DSURQE/$(basename -s .nii.gz $mt)-DSURQE_output_1_inverse_NL.xfm -n GenericLabel \
        -o $output/masks_tissue_type/${basename}_mask_cc.mnc --verbose \
        -r $output/n4_bias_corrected/$(basename -s .nii.gz $mt)_N4corr.mnc

############################################################################## Creating MTR maps ########################################
mkdir -m a=rwx $output/denoised_nonlocal_means
mkdir -m a=rwx $output/mtr_maps
mkdir -m a=rwx $output/mtr_maps/mtr_maps_raw/
mkdir -m a=rwx $output/mtr_maps/mtr_maps_denoised/

#now do image denoising of both mt and pd acquisitions using non-local-means
DenoiseImage -d 3 -i $output/raw_minc/$(basename -s .nii.gz $mt).mnc -n Rician -x $output/masks/${basename}_mask_full.mnc \
        --verbose -o $output/denoised_nonlocal_means/$(basename -s .nii.gz $mt)_denoised.mnc
DenoiseImage -d 3 -i $output/raw_minc/$(basename -s .nii.gz $pd).mnc -n Rician -x $output/masks/${basename}_mask_full.mnc \
        --verbose -o $output/denoised_nonlocal_means/$(basename -s .nii.gz $pd)_denoised.mnc

#create MTR maps from the denoised acquisitions
ImageMath 3 $output/mtr_maps/mtr_maps_raw/${basename}_mtr_map.mnc MTR $output/raw_minc/$(basename -s .nii.gz $pd).mnc \
        $output/raw_minc/$(basename -s .nii.gz $mt).mnc $output/masks/${basename}_mask_nocsf.mnc
ImageMath 3 $output/mtr_maps/mtr_maps_denoised/${basename}_mtr_map_denoised.mnc MTR $output/denoised_nonlocal_means/$(basename -s .nii.gz $pd)_denoised.mnc \
        $output/denoised_nonlocal_means/$(basename -s .nii.gz $mt)_denoised.mnc $output/masks/${basename}_mask_nocsf.mnc; 

############################################################################# Creating B1 maps ###############################################
mkdir -m a=rwx $output/b1_maps
mkdir -m a=rwx $output/b1_maps/registered_b1_to_mtr
mkdir -m a=rwx $output/b1_maps/registered_and_normalized_b1

#create b1 maps
minccalc -expression 'acos(A[1]/(2*A[0]))*(180/(4*atan(1)))' $output/raw_minc/$(basename -s .nii.gz $b160).mnc \
        $output/raw_minc/$(basename -s .nii.gz $b1120).mnc $output/b1_maps/${basename}_b1_map.mnc

#N4 denoising of the b1 acquisitions (only need b1_120 to be denoised)
python $scriptdir/helper/bias_cor_minc.py $output/raw_minc/$(basename -s .nii.gz $b1120).mnc $output/n4_bias_corrected/$(basename -s .nii.gz $mt)_N4corr.mnc \
        $output/masks/${basename}_mask_full.mnc $scriptdir/helper/antsRegistration_rigid.sh $output/n4_bias_corrected/$(basename -s .nii.gz $b1120)_N4corr.mnc

#register the denoised b1 acquisition to mt
$scriptdir/helper/antsRegistration_affine_SyN.sh $output/n4_bias_corrected/$(basename -s .nii.gz $b1120)_N4corr.mnc \
        $output/n4_bias_corrected/$(basename -s .nii.gz $mt)_N4corr.mnc $output/masks/${basename}_mask_full.mnc \
        $output/b1_maps/registered_b1_to_mtr/${basename}_B1120-to-MT

#Apply transforms to the B1 map to put it in mt space
antsApplyTransforms -d 3 -i $output/b1_maps/${basename}_b1_map.mnc -t $output/b1_maps/registered_b1_to_mtr/${basename}_B1120-to-MT_output_1_NL.xfm \
        -t $output/b1_maps/registered_b1_to_mtr/${basename}_B1120-to-MT_output_0_GenericAffine.xfm -o $output/b1_maps/registered_b1_to_mtr/${basename}_b1_map_registered.mnc \
        --verbose -r $output/n4_bias_corrected/$(basename -s .nii.gz $mt)_N4corr.mnc

#normalize b1 map using a value of 60
minccalc -expression "A[0]/60" $output/b1_maps/registered_b1_to_mtr/${basename}_b1_map_registered.mnc \
        $output/b1_maps/registered_and_normalized_b1/${basename}_b1_map_registered_norm.mnc

########################################################################### Perform the correction ###############################################
mkdir -m a=rwx $output/mtr_maps/mtr_maps_denoised_corrected/

#perform the correction separately for the cryocoil. Currently don't have ex-vivo data for room-temperature coils.
if [ "$coil_type" == "cryo" ]; then minccalc -expression 'A[0]/(0.39521599*A[1]+0.60478401)' \
        $output/mtr_maps/mtr_maps_denoised/${basename}_mtr_map_denoised.mnc $output/b1_maps/registered_and_normalized_b1/${basename}_b1_map_registered_norm.mnc \
        $output/mtr_maps/mtr_maps_denoised_corrected/${basename}_mtr_map_denoised_corrected.mnc; fi

###################################################################### Produce outputs to facilitate group comparison ################
mkdir -m a=rwx $output/niftis_for_dbm/
mkdir -m a=rwx $output/niftis_for_dbm/n4_bias_corrected_masked_mnc/
mkdir -m a=rwx $output/niftis_for_dbm/n4_bias_corrected_masked_nii/
mkdir -m a=rwx $output/niftis_for_dbm/mtr_maps_denoised_corrected_nii/

mincmath -mult $output/n4_bias_corrected/$(basename -s .nii.gz $mt)_N4corr.mnc $output/masks/${basename}_mask_full.mnc \
        $output/niftis_for_dbm/n4_bias_corrected_masked_mnc/$(basename -s .nii.gz $mt)_N4corr_masked.mnc

rm -rf $tmp_nii_subject_dir

