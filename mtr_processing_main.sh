#!/bin/bash
#this script is for creating MTR and B1 maps and outputting a final MTR map that is corrected for B1 inhomogeneities. For use on cic computer.
#TIP: create a csv with the subject ids and paths to each of the input files
#all input folders should contain raw minc images named with the following convention coil_subjectid_mt.mnc or coil_subjectid_pd.mnc etc.
#usage:
#mtr_processing_main.sh output_folder MT_image PD_image b1_60 b1_120 OUTPUT FOLDER SHOULD NOT HAVE A / AT THE END!
#it assumes that all 4 images were collected consecutively with no change in mouse positioning. Works with multiple MT images per mouse-coil combo but needs to be modified if want to use multiple pd images or b1 maps

#loop through all subjects when applying the command, but direct the outputs of the script into different directories based on the type of output.

module load minc-toolkit
module load minc-toolkit-extras

tmp_subject_dir=$(mktemp -d)
atlas=${QUARANTINE_PATH}/resources/Dorr_2008_Steadman_2013_Ullmann_2013_Richards_2011_Qiu_2016_Egan_2015_40micron/ex-vivo/DSURQE_40micron.mnc

#move all of the images into a subject-specific temp directory
cp $2 $tmp_subject_dir
cp $3 $tmp_subject_dir
cp $4 $tmp_subject_dir
cp $5 $tmp_subject_dir
output=$1
temp=$(basename $2)
basename=$(basename $(echo $temp | cut -c1-7)) #extracts the coil_subjectid (assumes that they are in the form xxx_xxx)

#first, preprocess all the images. denoised versions are also created to aid with registration later on.
mkdir -m a=rwx $output/preprocessed
mkdir -m a=rwx $output/denoised
mkdir -m a=rwx $output/masks

if test -f $output/preprocessed/*${basename}*pd*; then rm $tmp_subject_dir/*pd*; fi
if test -f $output/preprocessed/*${basename}*b1*60*; then rm $tmp_subject_dir/*b1*; fi

for file in $tmp_subject_dir/*; do /data/chamal/projects/mila/2019_Magnetization_Transfer/Scans/Piloting/MINC/mouse-preprocessing-orientation.sh $file $output/preprocessed/$(basename -s .mnc $file)_processed.mnc; done
for file in $tmp_subject_dir/*; do if [[ "$file" != *b1* ]]; then /data/chamal/projects/mila/2019_Magnetization_Transfer/Scans/Piloting/MINC/mouse-preprocessing-denoise-only.sh $file $output/denoised/$(basename -s .mnc $file)_denoised.mnc; fi; done
/data/chamal/projects/mila/2019_Magnetization_Transfer/Scans/Piloting/MINC/mouse-preprocessing-mask.sh $output/preprocessed/$(basename -s .mnc $3)_processed.mnc $output/masks/${basename}_mask.mnc
for file in $output/preprocessed/*b1*; do /data/chamal/projects/mila/2019_Magnetization_Transfer/Scans/Piloting/MINC/iter_bias_cor.sh $file $output/denoised/$(basename -s .mnc $2)_denoised.mnc $output/masks/${basename}_mask.mnc $output/denoised/$(basename -s .mnc $file)_denoised.mnc; done

#create MTR maps
mkdir -m a=rwx $output/mtr_maps
minccalc -expression '(A[0]- A[1])/A[0]' $output/preprocessed/$(basename -s .mnc $3)_processed.mnc $output/preprocessed/$(basename -s .mnc $2)_processed.mnc $output/mtr_maps/$(basename -s .mnc $2)_mtr_map_minccalc.mnc
ImageMath 3 $output/mtr_maps/$(basename -s .mnc $2)_mtr_map_imagemath.mnc MTR $output/preprocessed/$(basename -s .mnc $3)_processed.mnc $output/preprocessed/$(basename -s .mnc $2)_processed.mnc $output/masks/${basename}_mask.mnc

#create b1 maps
mkdir -m a=rwx $output/b1_maps
minccalc -expression 'acos(A[1]/(2*A[0]))*(180/(4*atan(1)))' $output/preprocessed/$(basename -s .mnc $4)_processed.mnc $output/preprocessed/$(basename -s .mnc $5)_processed.mnc $output/b1_maps/${basename}_b1_map.mnc

#register the b1 map to the MTR map
/data/chamal/projects/mila/2019_Magnetization_Transfer/Scans/Piloting/MINC/mtr_register_strong.sh $output/denoised/${basename}_b1_60_processed_denoised.mnc $output/denoised/$(basename -s .mnc $2)_denoised.mnc  $output/b1_maps/
antsApplyTransforms -d 3 -i $output/b1_maps/${basename}_b1_map.mnc -t $output/b1_maps/${basename}_b1_60_processed_denoised.mnc-$(basename -s .mnc $2)_denoised.mnc1_NL.xfm -t $output/b1_maps/${basename}_b1_60_processed_denoised.mnc-$(basename -s .mnc $2)_denoised.mnc0_GenericAffine.xfm -o $output/b1_maps/${basename}_b1_map_registered.mnc --verbose -r $output/denoised/$(basename -s .mnc $2)_denoised.mnc

#perform the correction
minccalc -expression 'A[0]/(1.31900053*A[1]-0.32723938)' $output/mtr_maps/$(basename -s .mnc $2)_mtr_map_minccalc.mnc $output/b1_maps/b1_map_norm.mnc $output/mtr_maps/$(basename -s .mnc $2)_mtr_map_minccalc_corrected.mnc

#make mtr histograms using no csf mask-requires registration of mt to DSURQE
mkdir -m a=rwx $output/mtr_histograms
path_to_no_csf_mask=/data/chamal/projects/mila/2019_Magnetization_Transfer/Scans/Piloting/MINC/tissue_labels/labels_raw_final_no_csf.mnc
/data/chamal/projects/mila/2019_Magnetization_Transfer/Scans/Piloting/MINC/mtr_register_strong.sh $path_to_no_csf_mask $output/denoised/$(basename -s .mnc $2)_denoised.mnc $output/mtr_histograms/ $output/mtr_histograms/
antsApplyTransforms -d 3 -i $path_to_no_csf_mask -t $output/mtr_histograms/labels_raw_final_no_csf.mnc-$(basename -s .mnc $2)_denoised.mnc1_NL.xfm -t $output/mtr_histograms/labels_raw_final_no_csf.mnc-$(basename -s .mnc $2)_denoised.mnc0_GenericAffine.xfm -o $output/mtr_histograms/labels_no_csf_transformed_to_${basename}.mnc --verbose -r $output/denoised/$(basename -s .mnc $2)_denoised.mnc
mincstats -histogram $output/mtr_histograms/$(basename -s .mnc $2)_hist.txt -mask $output/mtr_histograms/labels_no_csf_transformed_to_${basename}.mnc -mask_binvalue 1 $output/mtr_maps/$(basename -s .mnc $2)_mtr_map_minccalc.mnc -hist_bins 200 -hist_range -1 1
