#!/bin/bash
#this script is for creating MTR and B1 maps and outputting a final MTR map that is corrected for B1 inhomogeneities. For use on cic computer.
#TIP: create a csv with the subject ids and paths to each of the input files
#all input folders should contain raw minc images named with the following convention coil_subjectid_mt_timepoint.mnc or coil_subjectid_pd_timepoint.mnc etc. Where timepoint is a single digit!
#usage:
#mtr_processing_main.sh output_folder MT_image PD_image b1_60 b1_120 OUTPUT FOLDER SHOULD NOT HAVE A / AT THE END!
#it assumes that all 4 images were collected consecutively with no change in mouse positioning. Works with multiple MT images per mouse-coil combo but needs to be modified if want to use multiple pd images or b1 maps

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
coil_type=$(echo $basename | cut -c1-3)

#first, preprocess all the images. denoised versions are also created to aid with registration later on.
mkdir -m a=rwx $output/preprocessed
mkdir -m a=rwx $output/denoised
mkdir -m a=rwx $output/masks

if test -f $output/preprocessed/*${basename}*pd*; then rm $tmp_subject_dir/*pd*; fi
if test -f $output/preprocessed/*${basename}*b1*60*; then rm $tmp_subject_dir/*b1*; fi

for file in $tmp_subject_dir/*; do /data/chamal/projects/mila/2019_Magnetization_Transfer/scripts/mouse-preprocessing-orientation.sh $file $output/preprocessed/$(basename -s .mnc $file)_processed.mnc; done
for file in $output/preprocessed/*; do if [[ "$file" != *b1* ]]; then /data/chamal/projects/mila/2019_Magnetization_Transfer/scripts/mouse-preprocessing-denoise-only.sh $file $output/denoised/$(basename -s .mnc $file)_denoised.mnc; fi; done
/data/chamal/projects/mila/2019_Magnetization_Transfer/scripts/mouse-preprocessing-mask.sh $output/denoised/$(basename -s .mnc $2)_denoised.mnc $output/masks/${basename}_mask.mnc
for file in $output/preprocessed/*${basename}*b1*; do /data/chamal/projects/mila/2019_Magnetization_Transfer/scripts/iter_bias_cor.sh $file $output/denoised/$(basename -s .mnc $2)_denoised.mnc $output/masks/${basename}_mask.mnc $output/denoised/$(basename -s .mnc $file)_denoised.mnc; done

#create MTR maps
mkdir -m a=rwx $output/mtr_maps
tmp_mtr_minccalc_dir=$(mktemp -d)
minccalc -expression '(A[0]- A[1])/A[0]' $output/preprocessed/$(basename -s .mnc $3)_processed.mnc $output/preprocessed/$(basename -s .mnc $2)_processed.mnc $tmp_mtr_minccalc_dir/$(basename -s .mnc $2)_mtr_map_minccalc.mnc
ImageMath 3 $output/mtr_maps/$(basename -s .mnc $2)_mtr_map_imagemath.mnc MTR $output/preprocessed/$(basename -s .mnc $3)_processed.mnc $output/preprocessed/$(basename -s .mnc $2)_processed.mnc $output/masks/${basename}_mask.mnc

#create b1 maps
mkdir -m a=rwx $output/b1_maps
minccalc -expression 'acos(A[1]/(2*A[0]))*(180/(4*atan(1)))' $output/preprocessed/$(basename -s .mnc $4)_processed.mnc $output/preprocessed/$(basename -s .mnc $5)_processed.mnc $output/b1_maps/${basename}_b1_map.mnc

#register the b1 map to the MTR map
/data/chamal/projects/mila/2019_Magnetization_Transfer/scripts/mtr_register_strong.sh $output/denoised/$(basename -s .mnc $4)_denoised.mnc $output/denoised/$(basename -s .mnc $2)_denoised.mnc  $output/b1_maps/registered_b1_to_mtr/
antsApplyTransforms -d 3 -i $output/b1_maps/${basename}_b1_map.mnc -t $output/b1_maps/registered_b1_to_mtr/$(basename -s .mnc $4)_denoised.mnc-$(basename -s .mnc $2)_denoised.mnc1_NL.xfm -t $output/b1_maps/registered_b1_to_mtr/$(basename -s .mnc $4)_denoised.mnc-$(basename -s .mnc $2)_denoised.mnc0_GenericAffine.xfm -o $output/b1_maps/registered_b1_to_mtr/${basename}_b1_map_registered.mnc --verbose -r $output/denoised/$(basename -s .mnc $2)_denoised.mnc

#normalize b1 map using a value of 60
minccalc -expression "A[0]/60" $output/b1_maps/registered_b1_to_mtr/${basename}_b1_map_registered.mnc $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc

#perform the correction separately for the cryocoil(uses calib values for optimized param, but not for the extended range) and normal coil
tmp_mtr_minccalc_corr_dir=$(mktemp -d)
if [ "$coil_type" == "nrm" ]; then minccalc -expression 'A[0]/(1.38396756*A[1]-0.31847942)' $tmp_mtr_minccalc_dir/$(basename -s .mnc $2)_mtr_map_minccalc.mnc $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc $tmp_mtr_minccalc_corr_dir/$(basename -s .mnc $2)_mtr_map_minccalc_corrected.mnc; fi
if [ "$coil_type" == "cry" ]; then minccalc -expression 'A[0]/(1.45501874*A[1]-0.45320295)' $tmp_mtr_minccalc_dir/$(basename -s .mnc $2)_mtr_map_minccalc.mnc $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc $tmp_mtr_minccalc_corr_dir/$(basename -s .mnc $2)_mtr_map_minccalc_corrected.mnc; fi
if [ "$coil_type" == "nrm" ]; then minccalc -expression 'A[0]/(1.38396756*A[1]-0.31847942)' $output/mtr_maps/$(basename -s .mnc $2)_mtr_map_imagemath.mnc $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc $output/mtr_maps/corrected_mtr_maps/$(basename -s .mnc $2)_mtr_map_imagemath_corrected.mnc; fi
if [ "$coil_type" == "cry" ]; then minccalc -expression 'A[0]/(1.45501874*A[1]-0.45320295)' $output/mtr_maps/$(basename -s .mnc $2)_mtr_map_imagemath.mnc $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc $output/mtr_maps/corrected_mtr_maps/$(basename -s .mnc $2)_mtr_map_imagemath_corrected.mnc; fi

#make mtr histograms using no csf mask-requires registration of DSURQE no csf labels to the mt map
mkdir -m a=rwx $output/mtr_histograms
/data/chamal/projects/mila/2019_Magnetization_Transfer/scripts/histogram_creation.sh $output $(basename -s .mnc $2)_hist.txt $tmp_mtr_minccalc_corr_dir/$(basename -s .mnc $2)_mtr_map_minccalc_corrected.mnc $(basename -s .mnc $2)

rm -rf $tmp_subject_dir
rm -rf $tmp_mtr_minccalc_dir
rm -rf $tmp_mtr_minccalc_corr_dir
