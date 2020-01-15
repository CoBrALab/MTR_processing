#!/bin/bash
#this script is for creating histogram to go with mtr_map. For use on cic computer.
#all input folders should contain raw minc images named with the following convention coil_subjectid_mt.mnc or coil_subjectid_pd.mnc etc
#usage:
#histogram_creation.sh output_folder output_file mtr_map basename OUTPUT FOLDER SHOULD NOT HAVE A / AT THE END!
#basename should be coil__subjectid_mt_timepoint
#use minccalc mtr maps as input if you don't want your histogram to be cut off at 0

module load minc-toolkit
module load minc-toolkit-extras

tmp_subject_dir_new=$(mktemp -d)

filename=$2
cp $3 $tmp_subject_dir_new/map.mnc
map=$tmp_subject_dir_new/map.mnc
output=$1
#temp=$(basename $3)
basename=$(basename $4) #extracts the coil_subjectid (assumes that they are in the form xxx_xxx)

path_to_no_csf_mask=/data/chamal/projects/mila/2019_Magnetization_Transfer/Scans/Piloting/MINC/tissue_labels/labels_raw_final_no_csf.mnc
path_to_tissue_labels=/data/chamal/projects/mila/2019_Magnetization_Transfer/Scans/Piloting/MINC/tissue_labels/labels_raw_final.mnc
path_to_full_DSURQE=/data/chamal/projects/mila/2019_Magnetization_Transfer/Scans/Piloting/MINC/tissue_labels/ex-vivo/DSURQE_40micron.mnc

#transform DSURQE file to the denoised MT image, apply transforms to the no_csf mask and tissue_labels
mkdir -m a=rwx $output/mtr_histograms/transforms_DSURQE_to_subject
if [ ! -e "$output/mtr_histograms/transforms_DSURQE_to_subject/labels_raw_final_no_csf.mnc-${basename}_denoised.mnc1_NL.xfm" ]; then /data/chamal/projects/mila/2019_Magnetization_Transfer/Scans/Piloting/MINC/mtr_register_strong.sh $path_to_full_DSURQE $output/denoised/${basename}_denoised.mnc $output/mtr_histograms/transforms_DSURQE_to_subject; fi
antsApplyTransforms -d 3 -i $path_to_no_csf_mask -t $output/mtr_histograms/transforms_DSURQE_to_subject/DSURQE_40micron.mnc-${basename}_denoised.mnc1_NL.xfm -t $output/mtr_histograms/transforms_DSURQE_to_subject/DSURQE_40micron.mnc-${basename}_denoised.mnc0_GenericAffine.xfm -o $output/masks/mask_no_csf_transformed_to_${basename}.mnc --verbose -r $output/denoised/${basename}_denoised.mnc
antsApplyTransforms -d 3 -i $path_to_tissue_labels -t $output/mtr_histograms/transforms_DSURQE_to_subject/DSURQE_40micron.mnc-${basename}_denoised.mnc1_NL.xfm -t $output/mtr_histograms/transforms_DSURQE_to_subject/DSURQE_40micron.mnc-${basename}_denoised.mnc0_GenericAffine.xfm -o $output/masks/tissue_labels_transformed_to_${basename}.mnc --verbose -r $output/denoised/${basename}_denoised.mnc

#create the histogram by applying the mask to the mtr map
mincstats -histogram $output/mtr_histograms/$filename -mask $output/masks/mask_no_csf_transformed_to_${basename}.mnc -mask_binvalue 1 $map -hist_bins 200 -hist_range -1 1 -clobber

rm -rf $tmp_subject_dir_new
