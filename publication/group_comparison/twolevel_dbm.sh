#to run, simply type twolevel_dbm.sh into terminal
#to check that it's running, use qstat
module load anaconda/5.1.0-python3 minc-toolkit/1.9.17 qbatch/2.1.3 ANTs

#example: twolevel_dbm.sh 1level /data/scratch/mila/cuprizone_validation_final/mtr_maps_denoised_ants/corrected_mtr_maps_denoised_ants/niifti_files_for_group_comparison/nifti_file_input_list.csv

num_levels=$1
nifti_file_input_csv=$2
template=$template_anat
downsampled_atlas=/data/chamal/projects/mila/2019_MTR_on_Cryoprobe/resources_tissue_labels/DSURQE_200micron_masked.nii.gz

#get the path to the folder where the script is located. If code was downloaded from github, all other necessary helper scripts should be located in folders relative to this one.
wdir="$PWD"; [ "$PWD" = "/" ] && wdir=""
case "$0" in
  /*) scriptdir="${0}";;
  *) scriptdir="$wdir/${0#./}";;
esac
scriptdir="${scriptdir%/*}/../../"

mkdir -p ants_dbm
cd ants_dbm

$scriptdir/publication/group_comparison/twolevel_dbm.py --rigid-model-target $downsampled_atlas \
--no-N4 --transform SyN --float --average-type normmean --gradient-step 0.25 --model-iterations 3 \
--modelbuild-command antsMultivariateTemplateConstruction2.sh --cluster-type sge --skip-dbm \
$num_levels $nifti_file_input_csv

cd ..
