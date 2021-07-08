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
source activate /home/cic/uromil/miniconda3/envs/mtr_processing_env

tmp_b1_subject_dir=$(mktemp -d)
tmp_subject_dir=$(mktemp -d)

atlas=${QUARANTINE_PATH}/resources/Dorr_2008_Steadman_2013_Ullmann_2013_Richards_2011_Qiu_2016_Egan_2015_40micron/ex-vivo/DSURQE_40micron.mnc
atlas_for_reg=${QUARANTINE_PATH}/resources/Dorr_2008_Steadman_2013_Ullmann_2013_Richards_2011_Qiu_2016_Egan_2015_40micron/100um/DSURQE.mnc
atlas_mask=${QUARANTINE_PATH}/resources/Dorr_2008_Steadman_2013_Ullmann_2013_Richards_2011_Qiu_2016_Egan_2015_40micron/100um/DSURQE_mask.mnc


#move all of the images into a subject-specific temp directory
output=$1
mt1=$2
mt2=$3
mt3=$4
mt4=$5
mt5=$6
mt6=$7
pd=$8
b160=$9
b1120=$10

cp $2 $tmp_subject_dir
cp $3 $tmp_subject_dir
cp $4 $tmp_subject_dir
cp $5 $tmp_subject_dir
cp $6 $tmp_subject_dir
cp $7 $tmp_subject_dir
cp $8 $tmp_subject_dir
cp $9 $tmp_b1_subject_dir
cp $10 $tmp_b1_subject_dir

temp=$(basename $mt1)
basename=$(basename $(echo $temp | cut -c1-7)) #extracts the coil_subjectid (assumes that they are in the form xxx_xxx)
fa=$(basename $(echo $temp | cut -c12-15)) #extract flip angle
cp /data/chamal/projects/mila/2019_MTR_on_Cryoprobe/scripts_from_github/preprocess/bias_cor_minc.py $tmp_subject_dir/bias_cor_minc.py #this is so the intermediate outputs from the b1 bias field correction get put in the tmp directory

#first, preprocess all the images. denoised versions are also created to aid with registration later on.
mkdir -m a=rwx $output/preprocessed
mkdir -m a=rwx $output/denoised

rm -rf $tmp_subject_dir
