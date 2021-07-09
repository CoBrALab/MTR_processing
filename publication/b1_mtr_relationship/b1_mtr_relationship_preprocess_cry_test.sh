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


############################################################### Registration of B1 acquisitions to MT within subject (register to MT1, which has largest FA) ####################################

#perform bias field correction of the b1_120 acquisition first (assumes that the mask registered to mt1 applies well to b1-120 as well)
python $tmp_subject_dir/bias_cor_minc.py $output/preprocessed/$(basename -s .mnc $b1120)_processed.mnc $output/denoised/$(basename -s .mnc $b1120)_processed_denoised.mnc $output/masks/${basename}_mask_full.mnc /data/chamal/projects/mila/2019_Magnetization_Transfer/scripts/helper_scripts/antsRegistration_rigid.sh $output/denoised/$(basename -s .mnc $b1120)_processed_denoised.mnc

#register the denoised b1 acquisition to mt1
#mkdir -m a=rwx $output/b1_maps
#mkdir -m a=rwx $output/b1_maps/registered_b1_to_mtr
#/data/chamal/projects/mila/2019_MTR_on_Cryoprobe/scripts_from_github/preprocess/antsRegistration_affine_SyN.sh $output/denoised/$(basename -s .mnc $b1120)_processed_denoised.mnc $output/denoised/$(basename -s .mnc $mt1)_processed_denoised.mnc $output/masks/${basename}_mask_full.mnc $output/b1_maps/registered_b1_to_mtr/${basename}_b1_120-${basename}_mt_1045

#Create B1 maps
#minccalc -expression 'acos(A[1]/(2*A[0]))*(180/(4*atan(1)))' $output/preprocessed/$(basename -s .mnc $b160)_processed.mnc $output/preprocessed/$(basename -s .mnc $b1120)_processed.mnc $output/b1_maps/${basename}_b1_map.mnc

#Apply transforms to the B1 map
#antsApplyTransforms -d 3 -i $output/b1_maps/${basename}_b1_map.mnc -t $output/b1_maps/registered_b1_to_mtr/${basename}_b1_120-${basename}_mt_1045_output_0_GenericAffine.xfm -t $output/b1_maps/registered_b1_to_mtr/${basename}_b1_120-${basename}_mt_1045_output_1_NL.xfm -o $output/b1_maps/registered_b1_to_mtr/${basename}_b1_map_registered.mnc --verbose -r $output/denoised/$(basename -s .mnc $mt1)_processed_denoised.mnc

#normalize b1 map using a value of 60
#mkdir -m a=rwx $output/b1_maps/normalized_and_registered_b1/
#minccalc -expression "A[0]/60" $output/b1_maps/registered_b1_to_mtr/${basename}_b1_map_registered.mnc $output/b1_maps/normalized_and_registered_b1/${basename}_b1_map_registered_norm.mnc
######################################################################### Create mask based on B1 field strength ###############################################################

rm -rf $tmp_subject_dir
rm -rf $tmp_b1_subject_dir
