#!/bin/bash
#this script is for converting the outputs from mtr_processing_main.sh into niftis for the purpose of input to twolevel_dbm.sh
#the output folder is thus the analysis folder
module load anaconda/5.1.0-python3 minc-toolkit/1.9.17 qbatch/2.1.3 ANTs

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

downsampled_atlas=/data/chamal/projects/mila/2019_MTR_on_Cryoprobe/resources_tissue_labels/DSURQE_200micron_masked.nii.gz
derivatives_folder=$output/../2_derivatives
temp=$(basename $mt)
subject=$(echo $temp | grep -oP '(?<=sub-).*?(?=_)' ) #extract subjectID
coil_type=$(echo $temp | grep -oP '(?<=acq-).*?(?=_)' ) #extract coil type
basename=$(echo $temp | grep -oP '(?<=).*?(?=_MTw)' )

###################################################################### Convert DBM inputs to niftis ################
#mkdir -m a=rwx $output/dbm_inputs/N4corr_to_register
#mkdir -m a=rwx $output/dbm_inputs/mtr_maps_to_warp

#mask the N4_corr images, then convert them to nifti - these will be inputs to dbm
#mincmath -mult $derivatives_folder/n4_bias_corrected/$(basename -s .nii.gz $mt)_N4corr.mnc $derivatives_folder/masks/${basename}_mask_full.mnc \
#        $output/dbm_inputs/N4corr_to_register/$(basename -s .nii.gz $mt)_N4corr_masked.mnc

#it looks like the voxel values are preserved. Trying with noscanrange gives weird filename errors
#mnc2nii $output/dbm_inputs/N4corr_to_register/$(basename -s .nii.gz $mt)_N4corr_masked.mnc $output/dbm_inputs/N4corr_to_register/$(basename -s .nii.gz $mt)_N4corr_masked.nii
#rm -rf $output/dbm_inputs/N4corr_to_register/*.mnc

#convert the mtr maps that I want to transform to common space into nifti
#mnc2nii $derivatives_folder/mtr_maps/mtr_maps_denoised_corrected/${basename}_mtr_map_denoised_corrected.mnc  $output/dbm_inputs/mtr_maps_to_warp/${basename}_mtr_map_denoised_corrected.nii

########################################################## Store outputs in filelist #############################################
#for file in $output/dbm_inputs/N4corr_to_register/*.nii; do
#    echo $file; 
#done > $output/dbm_inputs/N4corr_to_register/dbm_input_nifti_filelist.csv

######################################################### Run the dbm model building #######################
 if test -f "$output/ants_dbm/output/secondlevel/COMPLETE"; then 
        mkdir -p $output/ants_dbm;
        cd $output/ants_dbm;
        $scriptdir/publication/group_comparison/twolevel_dbm.py --rigid-model-target $downsampled_atlas \
                --no-N4 --transform SyN --float --average-type normmean --gradient-step 0.25 --model-iterations 3 \
                --modelbuild-command antsMultivariateTemplateConstruction2.sh --cluster-type sge --skip-dbm \
                1level $output/dbm_inputs/N4corr_to_register/dbm_input_nifti_filelist.csv;
fi

################################################ Apply the transforms to commonspace on the MTR maps ################
mkdir -m a=rwx $output/warped_mtr_maps/minc
mkdir -m a=rwx $output/warped_mtr_maps/nifti

cd $output/ants_dbm/output/secondlevel/
exact_affine_transform_name=*secondlevel_${basename}_MTw_N4corr_masked*GenericAffine.mat
exact_inverseNL_transform_name=*secondlevel_${basename}_MTw_N4corr_masked*InverseWarp.nii.gz
get_i=$(echo $exact_inverseNL_transform_name | grep -oP '(?<=masked).*?(?=Inverse)' )
exact_NL_transform_name=secondlevel_$(basename -s .nii.gz $mt)_N4corr_masked${get_i}Warp.nii.gz

antsApplyTransforms -d 3 -i $output/dbm_inputs/mtr_maps_to_warp/${basename}_mtr_map_denoised_corrected.nii \
        -t $output/ants_dbm/output/secondlevel/$exact_NL_transform_name \
        -t $output/ants_dbm/output/secondlevel/$exact_affine_transform_name \
        -r $downsampled_atlas \
        --verbose -o $output/warped_mtr_maps/nifti/${basename}_mtr_map_denoised_corrected_WARPED.nii.gz

#convert the warped MTR map to mnc
nii2mnc$output/warped_mtr_maps/nifti/${basename}_mtr_map_denoised_corrected_WARPED.nii.gz $output/warped_mtr_maps/minc/${basename}_mtr_map_denoised_corrected_WARPED.mnc

