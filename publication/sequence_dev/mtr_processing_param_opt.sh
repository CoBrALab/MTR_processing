#!/bin/bash
#this script is for processing MTR data and extracting mean and std values within rois to calculate SNR in dorsal and ventral regions
#usage:
#mtr_processing_param_opt.sh output_folder MT_image PD_image mask_for_calc_SNR WM_mask_for_calc_CNR

#name the MT_image in the form ccx_001_mt_6_v1.mnc (where ccx indicates cryocoil, 001 is subjectID, mt_6 refers to the 6th combo
#of parameters attempted and v1 means that mouse positioning has not been altered since the beginning. If necessary to give a mouse a break outside scanner, v2 will refer to new positioning)

#it assumes that mt and pd images were collected consecutively with no change in mouse positioning
#edited on July 20, 2021 to include generation of mean values within mask

module load minc-toolkit
module load minc-toolkit-extras
module load ANTs
source activate mtr_processing_env

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
scriptdir="${scriptdir%/*}/../../"

tmp_subject_dir=$(mktemp -d)

#name the arguments
output=$1
mt=$2
pd=$3
mask1=$4
mask_wm=$5

#move all of the images into a subject-specific temp directory
cp $2 $tmp_subject_dir
cp $3 $tmp_subject_dir
output=$1
temp=$(basename $2)
basename=$(basename $(echo $temp | cut -c1-7)) #extracts the coil_subjectid (assumes that they are in the form xxx_xxx)
version=$(basename -s .mnc $(echo $temp | cut -d "_" -f 5))
scan_num=$(basename -s .mnc $(echo $temp | cut -d "_" -f 4))

#create output folders
mkdir -m a=rwx $output/preprocessed
mkdir -m a=rwx $output/n4_bias_corrected
mkdir -m a=rwx $output/transforms_subject_to_DSURQE
mkdir -m a=rwx $output/masks
mkdir -m a=rwx $output/transforms_subject_to_DSURQE
mkdir -m a=rwx $output/transforms_subject_mt_to_pd
mkdir -m a=rwx $output/preprocessed_pd_space
mkdir -m a=rwx $output/mtr_maps

###################################################################Standard processing and mask creation ###########################################
#first, preprocess all the images (fix orientation)
#for file in $tmp_subject_dir/*; do $scriptdir/helper/mouse-preprocessing-orientation.sh $file $output/preprocessed/$(basename -s .mnc $file)_processed.mnc; done

#perform N4 bias field correction. The N4 bias corrected acquisitions are necessary for registration to the atlas
#$scriptdir/helper/mouse-preprocessing-denoise-only.sh $output/preprocessed/$(basename -s .mnc $mt)_processed.mnc $output/n4_bias_corrected/$(basename -s .mnc $mt)_processed_n4corr.mnc
if [ ! -f $output/n4_bias_corrected/*pd*${version}* ]; then
  $scriptdir/helper/mouse-preprocessing-denoise-only.sh $output/preprocessed/$(basename -s .mnc $pd)_processed.mnc $output/n4_bias_corrected/$(basename -s .mnc $pd)_processed_n4corr.mnc
fi

#create mask by registering mt file to DSURQE, then transforming DSURQE mask to subject (do this only once for each version)
if [ ! -f $output/transforms_subject_to_DSURQE/*${basename}_${version}* ]; then
      $scriptdir/helper/antsRegistration_affine_SyN.sh $output/n4_bias_corrected/$(basename -s .mnc $mt)_processed_n4corr.mnc $atlas_for_reg $atlas_mask $output/transforms_subject_to_DSURQE/${basename}_${version}-DSURQE
      antsApplyTransforms -d 3 -i $atlas_nocsf_mask_100micron -t [$output/transforms_subject_to_DSURQE/${basename}_${version}-DSURQE_output_0_GenericAffine.xfm,1] -t $output/transforms_subject_to_DSURQE/${basename}_${version}-DSURQE_output_1_inverse_NL.xfm -n GenericLabel -o $output/masks/${basename}_${version}_mask_nocsf.mnc --verbose -r $output/n4_bias_corrected/$(basename -s .mnc $mt)_processed_n4corr.mnc
      antsApplyTransforms -d 3 -i $atlas_mask_100micron -t [$output/transforms_subject_to_DSURQE/${basename}_${version}-DSURQE_output_0_GenericAffine.xfm,1] -t $output/transforms_subject_to_DSURQE/${basename}_${version}-DSURQE_output_1_inverse_NL.xfm -n GenericLabel -o $output/masks/${basename}_${version}_mask_full.mnc --verbose -r $output/n4_bias_corrected/$(basename -s .mnc $mt)_processed_n4corr.mnc

      #warp other masks (corpus callosum, wm, gm) to the subject file as well
      antsApplyTransforms -d 3 -i $atlas_gm_mask_100micron -t [$output/transforms_subject_to_DSURQE/${basename}_${version}-DSURQE_output_0_GenericAffine.xfm,1] -t $output/transforms_subject_to_DSURQE/${basename}_${version}-DSURQE_output_1_inverse_NL.xfm -n GenericLabel -o $output/subject_specific_tissue_masks/${basename}_${version}_mask_gm.mnc --verbose -r $output/n4_bias_corrected/$(basename -s .mnc $mt)_processed_n4corr.mnc
      antsApplyTransforms -d 3 -i $atlas_wm_mask_100micron -t [$output/transforms_subject_to_DSURQE/${basename}_${version}-DSURQE_output_0_GenericAffine.xfm,1] -t $output/transforms_subject_to_DSURQE/${basename}_${version}-DSURQE_output_1_inverse_NL.xfm -n GenericLabel -o $output/subject_specific_tissue_masks/${basename}_${version}_mask_wm.mnc --verbose -r $output/n4_bias_corrected/$(basename -s .mnc $mt)_processed_n4corr.mnc
      antsApplyTransforms -d 3 -i $atlas_cc_mask_100micron -t [$output/transforms_subject_to_DSURQE/${basename}_${version}-DSURQE_output_0_GenericAffine.xfm,1] -t $output/transforms_subject_to_DSURQE/${basename}_${version}-DSURQE_output_1_inverse_NL.xfm -n GenericLabel -o $output/subject_specific_tissue_masks/${basename}_${version}_mask_cc.mnc --verbose -r $output/n4_bias_corrected/$(basename -s .mnc $mt)_processed_n4corr.mnc
fi

############################################################### Registration of all MT acquisitions within a single subject (register to the PD) ####################################
#register mt-w images to the pd-w image for each version (this is because the mouse may have moved from scan to scan as the sessions were long. Still want MTR maps to be meaningful)
#$scriptdir/helper/antsRegistration_affine_SyN.sh $output/n4_bias_corrected/$(basename -s .mnc $mt)_processed_n4corr.mnc $output/n4_bias_corrected/$(basename -s .mnc $pd)_processed_n4corr.mnc $output/masks_native_space/${basename}_mask_full.mnc $output/transforms_subject_mt_to_pd/$(basename -s .mnc $mt)-pd

#Apply transforms to the processed mt images to bring them all into pd space
#antsApplyTransforms -d 3 -i $output/preprocessed/$(basename -s .mnc $mt)_processed.mnc -t $output/transforms_subject_mt_to_pd/$(basename -s .mnc $mt)-pd_output_1_NL.xfm -t $output/transforms_subject_mt_to_pd/$(basename -s .mnc $mt)-pd_output_0_GenericAffine.xfm -o $output/preprocessed_pd_space/$(basename -s .mnc $mt)_processed_pd_space.mnc --verbose -r $output/n4_bias_corrected/$(basename -s .mnc $pd)_processed_n4corr.mnc

############################################################MTR map creation using mt acquisitions in PD space #################################
#ImageMath 3 $output/mtr_maps/$(basename -s .mnc $mt)_mtr_map_imagemath.mnc MTR $output/preprocessed/$(basename -s .mnc $pd)_processed.mnc $output/preprocessed_pd_space/$(basename -s .mnc $mt)_processed_pd_space.mnc $output/masks/${basename}_${version}_mask_nocsf.mnc


############################################################ Extract mean and std within masks for the purpose of calculating SNR ############################
if [ ! -f $output/snr_param_opt.csv ]; then
      echo Scan,region,mean_MTR_gm,mean_pd,stddev_background,MTR_wm,file_mtr,file_pd,mask_file,mask_background,mask_wm >> $output/snr_param_opt.csv

fi
backgroundmask=/data/chamal/projects/mila/2019_MTR_on_Cryoprobe/2_cryocoil_sequence_dev/raw_data/manually_drawn_rois_for_snr_calculation/SNR_background_labels.mnc
#Upper ROI
MTR_top=$(mincstats -mean -quiet -mask  $mask1 -mask_binvalue 3 $output/mtr_maps/$(basename -s .mnc $mt)_mtr_map_imagemath.mnc)
mean_pd_top=$(mincstats -mean -quiet -mask  $mask1 -mask_binvalue 3 $output/preprocessed/$(basename -s .mnc $pd)_processed.mnc)

#mean in lower ROI
MTR_bottom=$(mincstats -mean -quiet -mask  $mask1 -mask_binvalue 2 $output/mtr_maps/$(basename -s .mnc $mt)_mtr_map_imagemath.mnc)
mean_pd_bottom=$(mincstats -mean -quiet -mask  $mask1 -mask_binvalue 2 $output/preprocessed/$(basename -s .mnc $pd)_processed.mnc)

#stddev in the background of the PD-w acquisition
stddev_back=$(mincstats -stddev -quiet -mask  $backgroundmask -mask_binvalue 1 $output/preprocessed/$(basename -s .mnc $pd)_processed.mnc)
MTR_wm=$(mincstats -mean -quiet -mask  $mask_wm -mask_binvalue 1 $output/mtr_maps/$(basename -s .mnc $mt)_mtr_map_imagemath.mnc)

echo ${scan_num},top,$MTR_top,$mean_pd_top,$stddev_back,$MTR_wm,$output/mtr_maps/$(basename -s .mnc $mt)_mtr_map_imagemath.mnc,$output/preprocessed/$(basename -s .mnc $pd)_processed.mnc,$mask1,$backgroundmask,$mask_wm>> $output/snr_param_opt.csv
echo ${scan_num},bottom,$MTR_bottom,$mean_pd_bottom,$stddev_back,$MTR_wm,$output/mtr_maps/$(basename -s .mnc $mt)_mtr_map_imagemath.mnc,$output/preprocessed/$(basename -s .mnc $pd)_processed.mnc,$mask1,$backgroundmask,$mask_wm >> $output/snr_param_opt.csv


rm -rf $tmp_subject_dir
