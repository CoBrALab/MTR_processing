tmpdir=$(mktemp -d)
cp $1 $tmpdir/EPI.mnc
cp $2 $tmpdir/anat_file.mnc
cp $3 $tmpdir/mask.mnc

EPI=$tmpdir/EPI.mnc
anat_file=$tmpdir/anat_file.mnc
mask=$tmpdir/mask.mnc
filename_template=$4


ResampleImage 3 $EPI $tmpdir/resampled.mnc 0.4x0.4x0.4 0 4
ImageMath 3 $tmpdir/null_mask.mnc ThresholdAtMean $tmpdir/resampled.mnc 0
ImageMath 3 $tmpdir/thresh_mask.mnc ThresholdAtMean $tmpdir/resampled.mnc 2
N4BiasFieldCorrection -d 3 -i $tmpdir/resampled.mnc -b 20 -s 1 -c [100x100x100x100,1e-6] -w $tmpdir/thresh_mask.mnc -x $tmpdir/null_mask.mnc -o $tmpdir/corrected.mnc -v

#iterative registration and bias correction
ResampleImage 3 $tmpdir/corrected.mnc $tmpdir/resampled100.mnc 0.2x0.2x0.2 0 4

bash /data/chamal/projects/mila/2019_Magnetization_Transfer/scripts/Rigid_registration.sh $tmpdir/resampled100.mnc $anat_file $mask $filename_template

antsApplyTransforms -d 3 -i $mask -t ${filename_template}_output_InverseComposite.h5 -r $tmpdir/resampled.mnc -o $tmpdir/resampled_mask.mnc --verbose -n GenericLabel

N4BiasFieldCorrection -d 3 -i $tmpdir/resampled.mnc -b 20 -s 1 -c [100x100x100x100,1e-6] -w $tmpdir/resampled_mask.mnc -x $tmpdir/null_mask.mnc -o $tmpdir/iter_corrected.mnc -v

ResampleImage 3 $tmpdir/iter_corrected.mnc $tmpdir/bias_cor.mnc 0.2x0.2x0.2 0 4

#cp $tmpdir/bias_cor.mnc $(dirname $filename_template)/$(basename $filename_template .mnc)_bias_cor.mnc
cp $tmpdir/bias_cor.mnc $filename_template
rm -rf $tmpdir
